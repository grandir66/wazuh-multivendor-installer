#!/bin/bash
#
# Synology NAS Module - Custom Installer
# This module requires Python decoder and systemd service
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Paths
DECODER_SRC="${SCRIPT_DIR}/files/synology-json-decoder.py"
SERVICE_SRC="${SCRIPT_DIR}/synology-decoder.service"
RULES_SRC="${SCRIPT_DIR}/synology_json_rules.xml"

DECODER_DEST="/usr/local/bin/synology-json-decoder.py"
SERVICE_DEST="/etc/systemd/system/synology-decoder.service"
RULES_DEST="/var/ossec/etc/rules/synology_json_rules.xml"

# Check Python3
if ! command -v python3 &> /dev/null; then
    echo "  Installing Python 3..."
    if command -v apt-get &> /dev/null; then
        apt-get update -qq && apt-get install -y python3 >/dev/null
    elif command -v yum &> /dev/null; then
        yum install -y python3 >/dev/null
    elif command -v dnf &> /dev/null; then
        dnf install -y python3 >/dev/null
    else
        echo "  ERROR: Unable to install Python 3 automatically"
        exit 1
    fi
fi

# Check port 9513
if ss -uln 2>/dev/null | grep -q ":9513 "; then
    echo "  WARNING: Port 9513 already in use"
fi

# Install Python decoder
cp "$DECODER_SRC" "$DECODER_DEST"
chmod +x "$DECODER_DEST"
chown root:root "$DECODER_DEST"

# Install systemd service
cp "$SERVICE_SRC" "$SERVICE_DEST"
chmod 644 "$SERVICE_DEST"
chown root:root "$SERVICE_DEST"

systemctl daemon-reload
systemctl enable synology-decoder
systemctl start synology-decoder

# Install Wazuh rules
cp "$RULES_SRC" "$RULES_DEST"
chmod 640 "$RULES_DEST"
chown root:wazuh "$RULES_DEST"

echo "  Synology module installed"
echo "  - Decoder: $DECODER_DEST"
echo "  - Service: synology-decoder (port 9513/UDP)"
echo "  - Rules: $RULES_DEST"
