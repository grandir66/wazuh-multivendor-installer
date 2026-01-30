#!/bin/bash
# Stormshield Module Custom Installer
# Installs Python decoder, systemd service, and configures Wazuh

set -e

WAZUH_DIR="/var/ossec"
OSSEC_CONF="${WAZUH_DIR}/etc/ossec.conf"
MODULE_DIR="$(dirname "$0")"
LISTEN_PORT=5514
FORWARD_PORT=5515

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installing Stormshield Module"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ============================================
# Check Prerequisites
# ============================================

echo ""
echo "▶ Checking prerequisites..."

# Check for Python3
if ! command -v python3 &> /dev/null; then
    echo "  ✗ Python3 is required but not installed"
    echo "    Install with: apt install python3"
    exit 1
fi
echo "  ✓ Python3 found: $(python3 --version 2>&1)"

# Check Python modules (socket, re, json are built-in, no external deps needed)
echo "  ✓ Python modules: socket, re, json (built-in)"

# Check if port 5514 is already in use
if ss -uln | grep -q ":${LISTEN_PORT} " 2>/dev/null; then
    EXISTING_PROC=$(ss -ulnp | grep ":${LISTEN_PORT} " | head -1)
    if echo "$EXISTING_PROC" | grep -q "stormshield-decoder"; then
        echo "  ✓ Port ${LISTEN_PORT} already used by stormshield-decoder"
    elif echo "$EXISTING_PROC" | grep -q "wazuh-remoted"; then
        echo "  ⚠ Port ${LISTEN_PORT} used by wazuh-remoted"
        echo "    Will need to remove <remote> section for port ${LISTEN_PORT} from ossec.conf"
        echo ""
        read -p "    Remove Wazuh remote listener on port ${LISTEN_PORT}? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "    Removing port ${LISTEN_PORT} remote section..."
            # Create backup
            cp "${OSSEC_CONF}" "${OSSEC_CONF}.bak.$(date +%Y%m%d%H%M%S)"
            # Remove the remote section for port 5514 using Python for safe XML handling
            python3 << 'PYEOF'
import re
import sys

conf_file = "/var/ossec/etc/ossec.conf"
with open(conf_file, 'r') as f:
    content = f.read()

# Pattern to match <remote> section with port 5514
pattern = r'<remote>\s*<connection>syslog</connection>\s*<port>5514</port>.*?</remote>\s*'
new_content = re.sub(pattern, '', content, flags=re.DOTALL)

with open(conf_file, 'w') as f:
    f.write(new_content)

print("    ✓ Removed port 5514 remote section")
PYEOF
        else
            echo "    Skipping... You may need to change the listen port manually"
        fi
    else
        echo "  ⚠ Port ${LISTEN_PORT} already in use by another process"
        echo "    ${EXISTING_PROC}"
        echo ""
        read -p "    Continue anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
else
    echo "  ✓ Port ${LISTEN_PORT} available"
fi

# Check if port 5515 is configured in ossec.conf
if grep -q "<port>${FORWARD_PORT}</port>" "${OSSEC_CONF}" 2>/dev/null; then
    echo "  ✓ Port ${FORWARD_PORT} already configured in ossec.conf"
else
    echo "  ⚠ Port ${FORWARD_PORT} not configured in ossec.conf"
    echo ""
    read -p "    Add remote listener on port ${FORWARD_PORT}? [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo "    Adding port ${FORWARD_PORT} remote section..."
        # Create backup
        cp "${OSSEC_CONF}" "${OSSEC_CONF}.bak.$(date +%Y%m%d%H%M%S)"
        
        # Add remote section before </ossec_config> using Python
        python3 << 'PYEOF'
import sys

conf_file = "/var/ossec/etc/ossec.conf"
with open(conf_file, 'r') as f:
    content = f.read()

# Check if already exists
if '<port>5515</port>' in content:
    print("    ✓ Port 5515 already configured")
    sys.exit(0)

# New remote section
new_section = """
  <remote>
    <connection>syslog</connection>
    <port>5515</port>
    <protocol>udp</protocol>
    <allowed-ips>127.0.0.1</allowed-ips>
  </remote>

"""

# Find the last </ossec_config> and insert before it
# We need to find the LAST occurrence
last_pos = content.rfind('</ossec_config>')
if last_pos == -1:
    print("    ✗ Could not find </ossec_config> tag")
    sys.exit(1)

new_content = content[:last_pos] + new_section + content[last_pos:]

with open(conf_file, 'w') as f:
    f.write(new_content)

print("    ✓ Added port 5515 remote section")
PYEOF
    else
        echo "    Skipping... You will need to configure this manually"
    fi
fi

# ============================================
# Install Python Decoder
# ============================================

echo ""
echo "▶ Installing Python decoder..."

# Create integrations directory if needed
mkdir -p "${WAZUH_DIR}/integrations"

# Copy Python decoder
cp "${MODULE_DIR}/files/stormshield-decoder.py" "${WAZUH_DIR}/integrations/"
chmod +x "${WAZUH_DIR}/integrations/stormshield-decoder.py"
chown root:wazuh "${WAZUH_DIR}/integrations/stormshield-decoder.py"
echo "  ✓ Installed stormshield-decoder.py"

# ============================================
# Install Systemd Service
# ============================================

echo ""
echo "▶ Installing systemd service..."

# Stop existing service if running
if systemctl is-active --quiet stormshield-decoder 2>/dev/null; then
    systemctl stop stormshield-decoder
fi

# Install service file
cp "${MODULE_DIR}/files/stormshield-decoder.service" /etc/systemd/system/
systemctl daemon-reload
echo "  ✓ Installed stormshield-decoder.service"

# Enable and start service
systemctl enable stormshield-decoder
systemctl start stormshield-decoder
echo "  ✓ Service enabled and started"

# Verify service is running
sleep 1
if systemctl is-active --quiet stormshield-decoder; then
    echo "  ✓ Service status: running"
else
    echo "  ⚠ Service status: not running"
    echo "    Check logs: journalctl -u stormshield-decoder -n 20"
fi

# ============================================
# Install Decoders and Rules
# ============================================

echo ""
echo "▶ Installing decoders and rules..."

# Copy decoders
cp "${MODULE_DIR}/stormshield_decoders.xml" "${WAZUH_DIR}/etc/decoders/"
chown root:wazuh "${WAZUH_DIR}/etc/decoders/stormshield_decoders.xml"
chmod 640 "${WAZUH_DIR}/etc/decoders/stormshield_decoders.xml"
echo "  ✓ Installed stormshield_decoders.xml"

# Copy rules
cp "${MODULE_DIR}/stormshield_rules.xml" "${WAZUH_DIR}/etc/rules/"
chown root:wazuh "${WAZUH_DIR}/etc/rules/stormshield_rules.xml"
chmod 640 "${WAZUH_DIR}/etc/rules/stormshield_rules.xml"
echo "  ✓ Installed stormshield_rules.xml"

# ============================================
# Remove old rsyslog config if present
# ============================================

if [ -f /etc/rsyslog.d/10-stormshield.conf ]; then
    echo ""
    echo "▶ Removing old rsyslog configuration..."
    rm -f /etc/rsyslog.d/10-stormshield.conf
    systemctl restart rsyslog 2>/dev/null || true
    echo "  ✓ Removed /etc/rsyslog.d/10-stormshield.conf"
fi

if [ -d /var/log/stormshield ]; then
    rm -rf /var/log/stormshield
    echo "  ✓ Removed /var/log/stormshield"
fi

# ============================================
# Summary
# ============================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Stormshield Module Installed Successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Architecture:"
echo "    Stormshield ──UDP:${LISTEN_PORT}──▶ stormshield-decoder.py ──UDP:${FORWARD_PORT}──▶ Wazuh"
echo ""
echo "  Decoder Service:"
echo "    Status: $(systemctl is-active stormshield-decoder 2>/dev/null || echo 'unknown')"
echo "    Logs:   /var/log/stormshield-decoder.log"
echo "    Check:  journalctl -u stormshield-decoder -f"
echo ""
echo "  Configure Stormshield to send syslog to:"
echo "    Server: $(hostname -I | awk '{print $1}')"
echo "    Port:   ${LISTEN_PORT}"
echo "    Protocol: UDP"
echo "    Format: WELF or RFC5424"
echo ""
echo "  NOTE: Restart Wazuh Manager to apply changes:"
echo "    sudo systemctl restart wazuh-manager"
echo ""
