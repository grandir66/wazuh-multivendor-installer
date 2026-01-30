#!/usr/bin/env python3
"""
Stormshield WELF to JSON Decoder for Wazuh
Converts Stormshield firewall WELF logs to JSON format for native Wazuh JSON decoder

Author: Riccardo Grandi
Version: 1.0.0
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
LISTEN_PORT = 5514
FORWARD_IP = '127.0.0.1'
FORWARD_PORT = 5515  # Wazuh listens here

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/stormshield-decoder.log'),
        logging.StreamHandler(sys.stdout)
    ]
)

logger = logging.getLogger(__name__)

# Regex pattern to extract key=value or key="value" pairs from WELF format
WELF_PATTERN = re.compile(r'(\w+)=(?:"([^"]*)"|(\S+))')

# Pattern to extract IP from admin login message
ADMIN_IP_PATTERN = re.compile(r'administrative intervention \((\d+\.\d+\.\d+\.\d+)\)')

# Fields to always include in output (with proper names for Wazuh)
FIELD_MAPPING = {
    'time': 'time',
    'fw': 'fw',
    'tz': 'tz',
    'startime': 'startime',
    'pri': 'pri',
    'confid': 'confid',
    'slotlevel': 'slotlevel',
    'ruleid': 'ruleid',
    'rulename': 'rulename',
    'srcif': 'srcif',
    'srcifname': 'srcifname',
    'dstif': 'dstif',
    'dstifname': 'dstifname',
    'ipproto': 'ipproto',
    'proto': 'proto',
    'src': 'srcip',
    'srcport': 'srcport',
    'srcportname': 'srcportname',
    'srcname': 'srcname',
    'srcmac': 'srcmac',
    'srccontinent': 'srccontinent',
    'srccountry': 'srccountry',
    'srchostrep': 'srchostrep',
    'dst': 'dstip',
    'dstport': 'dstport',
    'dstportname': 'dstportname',
    'dstname': 'dstname',
    'dstcontinent': 'dstcontinent',
    'dstcountry': 'dstcountry',
    'dsthostrep': 'dsthostrep',
    'dstiprep': 'dstiprep',
    'modsrc': 'modsrc',
    'modsrcport': 'modsrcport',
    'origdst': 'origdst',
    'origdstport': 'origdstport',
    'ipv': 'ipv',
    'action': 'action',
    'msg': 'msg',
    'class': 'class',
    'classification': 'classification',
    'alarmid': 'alarmid',
    'target': 'target',
    'risk': 'risk',
    'sensible': 'sensible',
    'sent': 'sent',
    'rcvd': 'rcvd',
    'duration': 'duration',
    'logtype': 'logtype',
    'user': 'user',
    'address': 'address',
    'sessionid': 'sessionid',
    'method': 'method',
    'domain': 'domain',
    'error': 'error',
    'totp': 'totp',
    'tunnel': 'tunnel',
    'phase': 'phase',
    'vpntype': 'vpntype',
    'icmptype': 'icmptype',
    'icmpcode': 'icmpcode',
}


def parse_welf(log_line):
    """
    Parse WELF format (key=value pairs) into a dictionary
    
    Args:
        log_line: Raw WELF log line from Stormshield
        
    Returns:
        dict: Parsed key-value pairs
    """
    result = {}
    
    for match in WELF_PATTERN.finditer(log_line):
        key = match.group(1)
        # Value is either in group 2 (quoted) or group 3 (unquoted)
        value = match.group(2) if match.group(2) is not None else match.group(3)
        
        # Map to standard field name if available
        mapped_key = FIELD_MAPPING.get(key, key)
        result[mapped_key] = value
    
    return result


def process_log(log_line):
    """
    Process Stormshield log line and convert to JSON format
    
    Args:
        log_line: Raw syslog line from Stormshield
        
    Returns:
        str: JSON formatted log for Wazuh
    """
    # Check if this is a Stormshield log (contains id=firewall)
    if 'id=firewall' not in log_line:
        logger.debug(f"Not a Stormshield log, passing through")
        return log_line
    
    # Parse WELF format
    fields = parse_welf(log_line)
    
    if not fields:
        logger.warning(f"Failed to parse WELF format")
        return log_line
    
    # Extract IP from admin login message if present
    msg = fields.get('msg', '')
    if 'administrative intervention' in msg:
        ip_match = ADMIN_IP_PATTERN.search(msg)
        if ip_match:
            fields['address'] = ip_match.group(1)
            fields['srcip'] = ip_match.group(1)
    
    # Ensure address is populated from srcip if not set (for consistency)
    if not fields.get('address') and fields.get('srcip'):
        fields['address'] = fields.get('srcip')
    
    # Build JSON event
    event = {
        "integration": "stormshield",
        "stormshield": fields
    }
    
    # Add metadata
    logtype = fields.get('logtype', 'unknown')
    action = fields.get('action', '')
    srcip = fields.get('srcip', '')
    dstip = fields.get('dstip', '')
    user = fields.get('user', '')
    address = fields.get('address', '')
    
    json_log = json.dumps(event)
    
    # Log summary based on log type
    if logtype == 'alarm':
        logger.info(f"🚨 ALARM: {srcip} → {dstip} | {action} | {msg}")
    elif logtype == 'auth':
        logger.info(f"🔐 AUTH: {user}@{address} | error={fields.get('error', 'none')}")
    elif logtype == 'vpn':
        logger.info(f"🔒 VPN: {srcip} → {dstip} | {msg}")
    elif logtype == 'server':
        logger.info(f"👤 ADMIN: {user}@{address} | {msg}")
    elif logtype == 'system' and 'administrative' in msg:
        logger.info(f"🔑 LOGIN: {user}@{address} | {msg}")
    elif logtype in ('connection', 'filter'):
        logger.info(f"🌐 {logtype.upper()}: {srcip}:{fields.get('srcport', '')} → {dstip}:{fields.get('dstport', '')} | {action}")
    else:
        logger.info(f"📋 {logtype.upper()}: {fields.get('fw', '')} | {msg or action}")
    
    return json_log


def main():
    """Main decoder loop"""
    logger.info("=" * 60)
    logger.info("STORMSHIELD WELF → JSON DECODER FOR WAZUH")
    logger.info("=" * 60)
    logger.info(f"Listen: {LISTEN_IP}:{LISTEN_PORT} (UDP)")
    logger.info(f"Forward: {FORWARD_IP}:{FORWARD_PORT} (UDP)")
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
    
    logger.info("✓ Ready - waiting for Stormshield logs...")
    
    msg_count = 0
    while True:
        try:
            data, addr = sock.recvfrom(65535)  # Max UDP packet size
            msg_count += 1
            
            # Decode and clean the log line
            log_line = data.decode('utf-8', errors='replace').strip()
            
            # Remove BOM if present
            if log_line.startswith('\ufeff'):
                log_line = log_line[1:]
            
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
