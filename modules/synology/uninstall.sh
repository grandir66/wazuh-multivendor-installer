#!/bin/bash
#
# Synology NAS Module - Uninstaller
#

set -e

# Stop and remove service
if systemctl is-active --quiet synology-decoder 2>/dev/null; then
    systemctl stop synology-decoder
fi

if systemctl is-enabled --quiet synology-decoder 2>/dev/null; then
    systemctl disable synology-decoder
fi

rm -f /etc/systemd/system/synology-decoder.service
systemctl daemon-reload

# Remove decoder
rm -f /usr/local/bin/synology-json-decoder.py

# Remove rules
rm -f /var/ossec/etc/rules/synology_json_rules.xml

echo "  Synology module uninstalled"
