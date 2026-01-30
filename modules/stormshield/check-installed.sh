#!/bin/bash
# Check if Stormshield module is installed

WAZUH_DIR="/var/ossec"

# Check all components
decoder_installed=false
rules_installed=false
python_installed=false
service_running=false

if [ -f "${WAZUH_DIR}/etc/decoders/stormshield_decoders.xml" ]; then
    decoder_installed=true
fi

if [ -f "${WAZUH_DIR}/etc/rules/stormshield_rules.xml" ]; then
    rules_installed=true
fi

if [ -f "${WAZUH_DIR}/integrations/stormshield-decoder.py" ]; then
    python_installed=true
fi

if systemctl is-active --quiet stormshield-decoder 2>/dev/null; then
    service_running=true
fi

# Module is installed if all components are present
if [ "$decoder_installed" = true ] && [ "$rules_installed" = true ] && [ "$python_installed" = true ]; then
    if [ "$service_running" = true ]; then
        echo "installed"
    else
        echo "installed-stopped"
    fi
else
    echo "not-installed"
fi
