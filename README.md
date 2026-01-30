# Wazuh Multi-Vendor Integration Installer

A modular installation system for integrating multiple device types with Wazuh SIEM. Supports NAS devices (Synology, QNAP), network equipment (Mikrotik), firewalls (Stormshield), and is designed to be easily extensible for additional vendors.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Wazuh](https://img.shields.io/badge/wazuh-4.x-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)

## Features

- **Modular Architecture**: Each device type is a self-contained module
- **Interactive Menu**: Easy-to-use text-based interface
- **Command Line Support**: Scriptable for automation
- **Status Tracking**: Shows which modules are installed
- **Safe Installation**: Tests configuration before applying
- **Dashboard Import**: Automated dashboard deployment
- **Extensible Design**: Add new modules easily

## Supported Modules

| Module | Category | Description | Rule IDs |
|--------|----------|-------------|----------|
| **Synology NAS** | NAS | JSON-based log integration with Python decoder | 100100-100199 |
| **Mikrotik RouterOS** | Network | DHCP, VPN, Firewall, and system change monitoring | 100200-100299 |
| **QNAP NAS** | NAS | QTS syslog integration with file/SSH monitoring | 100300-100399 |
| **Stormshield Firewall** | Firewall | Admin access, VPN, IPS alerts, config changes | 100400-100499 |

## Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/grandir66/wazuh-multivendor-installer.git
cd wazuh-multivendor-installer

# Make executable
chmod +x install.sh

# Run interactive installer (as root)
sudo ./install.sh
```

### Interactive Menu

The installer provides an easy-to-use menu:

```
╔══════════════════════════════════════════════════════════════════╗
║     Wazuh Multi-Vendor Integration Installer                     ║
╚══════════════════════════════════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Available Modules
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  #   Module                Status      Category     Description
  ─────────────────────────────────────────────────────────────────────────
  1   Synology NAS          Not Installed NAS        Synology DSM JSON-based log...
  2   QNAP NAS              Not Installed NAS        QNAP QTS syslog integration...
  3   Mikrotik RouterOS     Not Installed Network    Mikrotik router monitoring...

  Options:
  ─────────────────────────────────────────────────────────────────────────
  [I] Install modules       [U] Uninstall modules
  [D] Install dashboards    [T] Test configuration
  [R] Restart Wazuh         [A] Install ALL modules
  [S] Status summary        [Q] Quit
```

### Command Line Usage

```bash
# List available modules
sudo ./install.sh --list

# Install specific module
sudo ./install.sh --install mikrotik

# Install multiple modules
sudo ./install.sh --install synology,qnap,mikrotik

# Install all modules
sudo ./install.sh --all

# Uninstall a module
sudo ./install.sh --uninstall mikrotik

# Import dashboards only
sudo ./install.sh --dashboards

# Show status
sudo ./install.sh --status
```

## Module Details

### Synology NAS

Monitors Synology DSM via a Python JSON decoder that converts syslog to structured data.

**Features:**
- SMB/CIFS connection tracking (SMB1, SMB2, SMB3)
- FileStation operations (web interface)
- WinFile operations (Windows SMB)
- After-hours access alerts
- Ransomware detection (mass deletions)
- Data exfiltration detection (mass reads)
- Sensitive file access alerts

**Requirements:**
- Python 3
- Port 9513/UDP open
- Synology configured to send syslog

**Configuration on Synology:**
1. Control Panel → Log Center → Archive
2. Server: `<Wazuh Server IP>`
3. Port: `9513`
4. Protocol: `UDP`
5. Format: `BSD (RFC 3164)`

### QNAP NAS

Monitors QNAP QTS via native syslog decoders.

**Features:**
- File operations (read, write, delete, rename, move)
- SMB/Samba access tracking
- HTTP/HTTPS web access
- FTP/AFP access
- SSH login monitoring
- Brute force detection
- Ransomware detection
- Data exfiltration detection

**Configuration on QNAP:**
1. Control Panel → System Logs → Syslog Client
2. Enable: Remote archiving (syslog)
3. Server: `<Wazuh Server IP>`
4. Port: `514`

### Mikrotik RouterOS

Comprehensive monitoring for Mikrotik routers via syslog.

**Features:**
- User authentication (SSH, Winbox, API)
- VPN connections (WireGuard, OpenVPN)
- Firewall rule changes (Filter, NAT, Mangle, Raw)
- DHCP server monitoring
- System configuration changes
- Brute force detection
- MITRE ATT&CK mapping

**Configuration on Mikrotik:**
```routeros
# Create syslog action
/system logging action add name=wazuh target=remote remote=<WAZUH_IP>:514

# Configure topics
/system logging add action=wazuh topics=system
/system logging add action=wazuh topics=info
/system logging add action=wazuh topics=warning
/system logging add action=wazuh topics=error
/system logging add action=wazuh topics=dhcp
/system logging add action=wazuh topics=firewall
/system logging add action=wazuh topics=account
```

### Stormshield Firewall

Complete monitoring for Stormshield SNS firewalls via syslog (WELF format).

**Features:**
- Admin authentication and session tracking
- VPN monitoring (IPsec, SSL VPN)
- IPS/IDS alarms with priority levels
- Configuration change detection
- Firewall rule modifications
- Brute force detection
- MITRE ATT&CK mapping

**Configuration on Stormshield:**
1. Go to **Configuration > Notifications > Logs - Syslog - IPFIX**
2. Add Syslog server: `<WAZUH_IP>:514`
3. Enable log types: l_server, l_auth, l_vpn, l_alarm, l_system

## Dashboards

The installer includes pre-built dashboards:

| Dashboard | Description |
|-----------|-------------|
| **Synology Dashboard** | File operations, user activity, SMB protocol usage |
| **Mikrotik Dashboard** | Security metrics, DHCP, VPN, firewall changes |
| **Stormshield Dashboard** | IPS alerts, VPN, admin activity, blocked traffic |
| **Log Explorer v2** | Dynamic filtering by agent, decoder, rule level |
| **Source Manager** | Multi-vendor filtering (NAS, Firewall, Hypervisor) |

### Importing Dashboards

Via installer menu:
1. Select `[D] Install dashboards`
2. Enter Wazuh Dashboard URL (e.g., `https://wazuh.example.com`)
3. Enter username and password

Via command line:
```bash
sudo ./install.sh --dashboards
```

**Note:** Passwords with special characters (!, $, @, etc.) are fully supported.

## Adding New Modules

The installer is designed to be extensible. To add a new module:

### 1. Create Module Directory

```bash
mkdir -p modules/mydevice/files
```

### 2. Create Manifest File

Create `modules/mydevice/manifest.conf`:

```ini
# Module Manifest
name=My Device
description=Short description of the module
version=1.0.0
category=Category (NAS, Network, Security, etc.)
author=Your Name

# Rule ID range (to avoid conflicts)
rule_id_start=100400
rule_id_end=100499

# Dependencies
requires_python=no
requires_systemd=no

# Tags for filtering
tags=device,type,keywords
```

### 3. Add Decoder and Rules

Create XML files in the module directory:
- `modules/mydevice/mydevice_decoders.xml`
- `modules/mydevice/mydevice_rules.xml`

### 4. (Optional) Custom Install Script

For complex installations, create `modules/mydevice/install.sh`:

```bash
#!/bin/bash
# Custom installation logic
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Your installation steps here
# ...

echo "  My Device module installed"
```

### 5. (Optional) Check Installed Script

Create `modules/mydevice/check-installed.sh`:

```bash
#!/bin/bash
# Exit 0 = installed, Exit 1 = not installed

if [ -f "/var/ossec/etc/rules/mydevice_rules.xml" ]; then
    exit 0
fi
exit 1
```

## Rule ID Allocation

To avoid conflicts, rule IDs are allocated in ranges:

| Range | Module |
|-------|--------|
| 100100-100199 | Synology NAS |
| 100200-100299 | Mikrotik RouterOS |
| 100300-100399 | QNAP NAS |
| 100400-100499 | Stormshield Firewall |
| 100500-100599 | Reserved (future) |
| 100600-100699 | Reserved (future) |

When adding new modules, use the next available range.

## File Structure

```
wazuh-multivendor-installer/
├── install.sh                    # Main installer script
├── deploy-dashboards.sh          # Standalone dashboard importer
├── README.md                     # This file
├── modules/
│   ├── synology/
│   │   ├── manifest.conf         # Module metadata
│   │   ├── README.md             # Module documentation
│   │   ├── install.sh            # Custom installer
│   │   ├── uninstall.sh          # Custom uninstaller
│   │   ├── check-installed.sh    # Installation check
│   │   ├── synology_json_rules.xml
│   │   ├── synology-decoder.service
│   │   └── files/
│   │       └── synology-json-decoder.py
│   ├── qnap/
│   │   ├── manifest.conf
│   │   ├── README.md
│   │   ├── qnap_decoders.xml
│   │   └── qnap_rules.xml
│   ├── mikrotik/
│   │   ├── manifest.conf
│   │   ├── README.md
│   │   ├── mikrotik_decoders.xml
│   │   ├── mikrotik_rules.xml
│   │   └── script.rsc            # WireGuard monitoring
│   └── stormshield/
│       ├── manifest.conf
│       ├── README.md
│       ├── stormshield_decoders.xml
│       └── stormshield_rules.xml
└── dashboards/
    ├── synology-dashboard.ndjson
    ├── mikrotik-dashboard.ndjson
    ├── stormshield-dashboard.ndjson
    ├── log-explorer-v2-dashboard.ndjson
    └── source-manager-dashboard.ndjson
```

## Troubleshooting

### Wazuh won't start after installation

1. Check configuration:
   ```bash
   /var/ossec/bin/wazuh-logtest-legacy -t
   ```

2. View error logs:
   ```bash
   tail -100 /var/ossec/logs/ossec.log
   ```

3. Uninstall problematic module:
   ```bash
   sudo ./install.sh --uninstall modulename
   ```

### Synology decoder not receiving logs

1. Check service status:
   ```bash
   systemctl status synology-decoder
   ```

2. Check port is listening:
   ```bash
   ss -uln | grep 9513
   ```

3. Check firewall:
   ```bash
   ufw allow 9513/udp
   ```

### Dashboard import fails

1. Verify URL is correct (include https://)
2. Check credentials are correct
3. Ensure Wazuh Dashboard is accessible
4. For passwords with special characters, the installer handles them automatically

### Module not detected as installed

Run the check script manually:
```bash
bash modules/modulename/check-installed.sh && echo "Installed" || echo "Not installed"
```

## Changelog

### v1.0.0
- Initial release
- Synology NAS module (JSON decoder)
- QNAP NAS module (syslog)
- Mikrotik RouterOS module
- Interactive menu system
- Command line interface
- Dashboard auto-import
- Special character password support

## Authors

- **Riccardo Grandi** ([@grandir66](https://github.com/grandir66))

## Contributing

Contributions are welcome! To add support for a new device:

1. Fork the repository
2. Create your module following the guide above
3. Test thoroughly
4. Submit a pull request

## License

This project is open source under the MIT License.

## Acknowledgments

- [Wazuh](https://wazuh.com) - Open source security monitoring
- [angolo40](https://github.com/angolo40) - Original Mikrotik integration

---

**Star this repo if it helped you!** ⭐
