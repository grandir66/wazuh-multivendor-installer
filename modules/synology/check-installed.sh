#!/bin/bash
#
# Check if Synology module is installed
# Exit 0 = installed, Exit 1 = not installed
#

# Check all components
DECODER="/usr/local/bin/synology-json-decoder.py"
SERVICE="/etc/systemd/system/synology-decoder.service"
RULES="/var/ossec/etc/rules/synology_json_rules.xml"

if [ -f "$DECODER" ] && [ -f "$SERVICE" ] && [ -f "$RULES" ]; then
    if systemctl is-active --quiet synology-decoder 2>/dev/null; then
        exit 0
    fi
fi

exit 1
