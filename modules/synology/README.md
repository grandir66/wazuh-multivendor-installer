# Synology NAS Module

JSON-based Wazuh integration for Synology DSM with a Python decoder that converts syslog to structured JSON data.

## Features

### File Access Monitoring
- SMB/CIFS Connections - Tracks SMB1, SMB2, SMB3 protocol usage
- FileStation Operations - Web interface file access
- WinFile Operations - Windows SMB client file access
- File Operations - Read, write, delete, rename tracking

### Security Detection
- SMB1 Usage Alert - Warns about insecure protocol
- After-Hours Access - Detects access outside business hours
- Weekend Access - Detects weekend file access
- Ransomware Detection - Mass file deletion alerts
- Data Exfiltration - Mass file read alerts
- Sensitive File Access - Monitors access to password/credential files
- Administrative Share Access - Monitors admin/backup/system shares

### MITRE ATT&CK Mapping

| Technique | Description |
|-----------|-------------|
| T1485 | Data Destruction |
| T1486 | Data Encrypted for Impact |
| T1039 | Data from Network Shared Drive |
| T1005 | Data from Local System |

## How It Works

```
Synology DSM → Syslog (UDP 9513) → Python Decoder → JSON → Wazuh
```

The Python decoder:
1. Receives raw syslog on UDP port 9513
2. Parses the log format and extracts fields
3. Converts to structured JSON
4. Forwards to Wazuh via local syslog

## Configuration on Synology

1. Control Panel → Log Center → Archive
2. Enable: Archive logs to syslog server
3. Server: `<Wazuh Server IP>`
4. Port: `9513`
5. Protocol: `UDP`
6. Format: `BSD (RFC 3164)`

## Detection Rules

| Rule ID | Level | Description |
|---------|-------|-------------|
| 100120 | 3 | Connection event |
| 100130 | 3 | FileStation operation |
| 100140 | 3 | WinFile operation |
| 100145 | 5 | SMB1 (insecure) access |
| 100150 | 4 | File write |
| 100151 | 6 | File delete |
| 100152 | 3 | File read |
| 100172 | 6 | After-hours access |
| 100173 | 5 | Weekend access |
| 100180 | 10 | Ransomware alert |
| 100181 | 8 | Data exfiltration |
| 100190 | 7 | Sensitive file access |
| 100195 | 6 | Admin share access |

## Requirements

- Python 3
- Port 9513/UDP open on Wazuh server
- Synology DSM 6.x or 7.x

## Files

- `synology_json_rules.xml` - Wazuh detection rules
- `synology-decoder.service` - Systemd service file
- `files/synology-json-decoder.py` - Python decoder script

## Firewall Configuration

```bash
# Ubuntu/Debian
ufw allow 9513/udp

# RHEL/CentOS
firewall-cmd --add-port=9513/udp --permanent
firewall-cmd --reload
```

## Monitoring

```bash
# Check service status
systemctl status synology-decoder

# View decoder logs
tail -f /var/log/synology-decoder.log

# View Wazuh alerts
tail -f /var/ossec/logs/alerts/alerts.json | grep synology
```
