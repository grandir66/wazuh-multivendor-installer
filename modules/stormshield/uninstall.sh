#!/bin/bash
# Stormshield Module Uninstaller

set -e

WAZUH_DIR="/var/ossec"
OSSEC_CONF="${WAZUH_DIR}/etc/ossec.conf"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Uninstalling Stormshield Module"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ============================================
# Stop and Remove Service
# ============================================

echo ""
echo "▶ Removing systemd service..."

if systemctl is-active --quiet stormshield-decoder 2>/dev/null; then
    systemctl stop stormshield-decoder
    echo "  ✓ Stopped stormshield-decoder service"
fi

if systemctl is-enabled --quiet stormshield-decoder 2>/dev/null; then
    systemctl disable stormshield-decoder
    echo "  ✓ Disabled stormshield-decoder service"
fi

if [ -f /etc/systemd/system/stormshield-decoder.service ]; then
    rm -f /etc/systemd/system/stormshield-decoder.service
    systemctl daemon-reload
    echo "  ✓ Removed service file"
fi

# ============================================
# Remove Python Decoder
# ============================================

echo ""
echo "▶ Removing Python decoder..."

if [ -f "${WAZUH_DIR}/integrations/stormshield-decoder.py" ]; then
    rm -f "${WAZUH_DIR}/integrations/stormshield-decoder.py"
    echo "  ✓ Removed stormshield-decoder.py"
fi

# ============================================
# Remove Decoders and Rules
# ============================================

echo ""
echo "▶ Removing decoders and rules..."

if [ -f "${WAZUH_DIR}/etc/decoders/stormshield_decoders.xml" ]; then
    rm -f "${WAZUH_DIR}/etc/decoders/stormshield_decoders.xml"
    echo "  ✓ Removed stormshield_decoders.xml"
fi

if [ -f "${WAZUH_DIR}/etc/rules/stormshield_rules.xml" ]; then
    rm -f "${WAZUH_DIR}/etc/rules/stormshield_rules.xml"
    echo "  ✓ Removed stormshield_rules.xml"
fi

# ============================================
# Remove Log File
# ============================================

echo ""
echo "▶ Removing log files..."

if [ -f /var/log/stormshield-decoder.log ]; then
    rm -f /var/log/stormshield-decoder.log
    echo "  ✓ Removed /var/log/stormshield-decoder.log"
fi

# Remove old rsyslog artifacts if present
if [ -f /etc/rsyslog.d/10-stormshield.conf ]; then
    rm -f /etc/rsyslog.d/10-stormshield.conf
    systemctl restart rsyslog 2>/dev/null || true
    echo "  ✓ Removed rsyslog configuration"
fi

if [ -d /var/log/stormshield ]; then
    rm -rf /var/log/stormshield
    echo "  ✓ Removed /var/log/stormshield directory"
fi

# ============================================
# Optionally Remove ossec.conf Changes
# ============================================

echo ""
if grep -q "<port>5515</port>" "${OSSEC_CONF}" 2>/dev/null; then
    read -p "▶ Remove port 5515 remote section from ossec.conf? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Create backup
        cp "${OSSEC_CONF}" "${OSSEC_CONF}.bak.$(date +%Y%m%d%H%M%S)"
        
        # Remove the remote section for port 5515
        python3 << 'PYEOF'
import re

conf_file = "/var/ossec/etc/ossec.conf"
with open(conf_file, 'r') as f:
    content = f.read()

# Pattern to match <remote> section with port 5515
pattern = r'\s*<remote>\s*<connection>syslog</connection>\s*<port>5515</port>.*?</remote>\s*'
new_content = re.sub(pattern, '\n', content, flags=re.DOTALL)

with open(conf_file, 'w') as f:
    f.write(new_content)

print("  ✓ Removed port 5515 remote section")
PYEOF
    else
        echo "  Skipping... Port 5515 remote section remains in ossec.conf"
    fi
fi

# ============================================
# Summary
# ============================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Stormshield Module Uninstalled Successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  NOTE: Restart Wazuh Manager to apply changes:"
echo "    sudo systemctl restart wazuh-manager"
echo ""
