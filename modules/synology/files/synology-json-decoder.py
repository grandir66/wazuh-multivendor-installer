#!/usr/bin/env python3
"""
Synology to JSON Decoder for Wazuh
Converts Synology NAS syslog to JSON format for native Wazuh JSON decoder

Author: Riccardo Malagoli
Version: 1.0.2
License: MIT
"""

import socket
import re
import sys
import logging
import json
from datetime import datetime

# Configuration
LISTEN_IP = '0.0.0.0'
LISTEN_PORT = 9513
FORWARD_IP = '127.0.0.1'
FORWARD_PORT = 9514

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/synology-decoder.log'),
        logging.StreamHandler(sys.stdout)
    ]
)

logger = logging.getLogger(__name__)

# Regex patterns for different Synology log types
PATTERN_WINFILE = re.compile(
    r'WinFileService Event: (\w+), Path: ([^,]+), File/Folder: ([^,]+), Size: ([^,]+), User: ([^,]+), IP: ([\d.]+)'
)

PATTERN_CONNECTION = re.compile(
    r'Connection: User \[([^]]+)\] from \[([^(]+)\(([^)]+)\)\] via \[([^]]+)\] accessed shared folder \[([^]]+)\]'
)

PATTERN_FILESTATION = re.compile(
    r'FileStation Event: (\w+), Path: (\S+), Size: (\d+) Bytes, User: ([^,]+), IP: ([\d.]+)'
)

def extract_domain_user(user_str):
    """
    Extract domain and username from DOMAIN\\user format

    Args:
        user_str: User string in format "DOMAIN\\user" or just "user"

    Returns:
        tuple: (domain, username) - domain is None if not present
    """
    if '\\' in user_str:
        parts = user_str.split('\\', 1)
        return parts[0].strip(), parts[1].strip()
    return None, user_str.strip()

def process_log(log_line):
    """
    Process Synology log line and convert to JSON format

    Args:
        log_line: Raw syslog line from Synology

    Returns:
        str: JSON formatted log for Wazuh
    """

    # Try WinFileService pattern
    match = PATTERN_WINFILE.search(log_line)
    if match:
        action, path, filetype, size, user, srcip = match.groups()
        user = user.strip()
        domain, username = extract_domain_user(user)

        event = {
            "integration": "synology",
            "synology": {
                "type": "winfile",
                "action": action,
                "path": path,
                "filetype": filetype,
                "size": size,
                "srcip": srcip,
                "user": username
            }
        }
        if domain:
            event["synology"]["domain"] = domain

        json_log = json.dumps(event)
        logger.info(f"✅ WINFILE: {username}@{srcip} {action} {path}")
        return json_log

    # Try Connection pattern
    match = PATTERN_CONNECTION.search(log_line)
    if match:
        user, computer, srcip, protocol, share = match.groups()
        user = user.strip()
        domain, username = extract_domain_user(user)
        computer = computer.strip()
        protocol = protocol.strip()
        share = share.strip('.')

        event = {
            "integration": "synology",
            "synology": {
                "type": "connection",
                "srcip": srcip,
                "computer": computer,
                "protocol": protocol,
                "share": share,
                "user": username,
                "action": "Access"
            }
        }
        if domain:
            event["synology"]["domain"] = domain

        json_log = json.dumps(event)
        logger.info(f"✅ CONNECTION: {username}@{srcip} → {share} via {protocol}")
        return json_log

    # Try FileStation pattern
    match = PATTERN_FILESTATION.search(log_line)
    if match:
        action, path, size, user, srcip = match.groups()
        user = user.strip()
        domain, username = extract_domain_user(user)

        event = {
            "integration": "synology",
            "synology": {
                "type": "filestation",
                "action": action,
                "path": path,
                "size": size,
                "srcip": srcip,
                "user": username
            }
        }
        if domain:
            event["synology"]["domain"] = domain

        json_log = json.dumps(event)
        logger.info(f"✅ FILESTATION: {username}@{srcip} {action} {path}")
        return json_log

    # No pattern matched - pass through original log
    logger.debug(f"⚠️  No pattern matched - passing through")
    return log_line

def main():
    """Main decoder loop"""
    logger.info("=" * 60)
    logger.info("SYNOLOGY → JSON DECODER FOR WAZUH")
    logger.info("=" * 60)
    logger.info(f"Listen: {LISTEN_IP}:{LISTEN_PORT}")
    logger.info(f"Forward: {FORWARD_IP}:{FORWARD_PORT}")
    logger.info("Output: JSON format (Wazuh native decoder)")
    logger.info("=" * 60)

    # Create UDP socket
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

    try:
        sock.bind((LISTEN_IP, LISTEN_PORT))
    except OSError as e:
        logger.error(f"❌ Failed to bind to {LISTEN_IP}:{LISTEN_PORT}")
        logger.error(f"   Error: {e}")
        logger.error(f"   Check if port is already in use: sudo ss -uln | grep {LISTEN_PORT}")
        sys.exit(1)

    logger.info("✓ Ready - waiting for logs...")

    msg_count = 0
    while True:
        try:
            data, addr = sock.recvfrom(8192)
            msg_count += 1
            log_line = data.decode('utf-8', errors='replace').strip()

            # Process and convert to JSON
            json_log = process_log(log_line)

            # Forward to Wazuh
            fwd = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            fwd.sendto(json_log.encode('utf-8'), (FORWARD_IP, FORWARD_PORT))
            fwd.close()

        except KeyboardInterrupt:
            logger.info(f"\nShutdown requested. Total messages processed: {msg_count}")
            break
        except Exception as e:
            logger.error(f"❌ ERROR processing message: {e}")
            continue

    sock.close()
    logger.info("Decoder stopped")

if __name__ == '__main__':
    main()
