# Stormshield Firewall Module

Complete Wazuh integration for Stormshield Network Security (SNS) firewalls using a Python decoder for reliable WELF parsing.

## Architecture

```
Stormshield ──UDP:5514──▶ stormshield-decoder.py ──UDP:5515──▶ Wazuh Manager
   (WELF)                    (converts to JSON)                 (JSON decoder)
```

The Python decoder:
1. Receives raw WELF logs on UDP port 5514
2. Parses all key=value fields reliably
3. Converts to JSON format
4. Forwards to Wazuh on port 5515

This approach bypasses Wazuh's regex limitations and provides complete field extraction.

## Features

### Authentication Monitoring
- Admin login success/failure
- Session tracking (open/close)
- Brute force detection
- After-hours/weekend login alerts

### VPN Monitoring
- IPsec tunnel establishment/termination
- SSL VPN connections
- VPN authentication failures
- VPN brute force detection

### Configuration Change Detection
- Firewall rule added/modified/removed
- Security policy changes
- Firmware updates

### IPS/IDS Alerts
- All IPS alarms with priority levels
- Port scan detection
- Attack detection
- Malware detection
- Flood/DoS detection

### System Events
- System startup/shutdown
- HA failover

### MITRE ATT&CK Mapping

| Technique | Description | Rules |
|-----------|-------------|-------|
| T1078 | Valid Accounts | 100410, 100412 |
| T1110 | Brute Force | 100411, 100414, 100424, 100425 |
| T1562.004 | Disable/Modify Firewall | 100431-100433 |
| T1046 | Network Service Scanning | 100444 |
| T1204 | User Execution (Malware) | 100446 |
| T1498 | Network DoS | 100447 |

## Installation

The module is installed automatically via the main installer:

```bash
sudo ./install.sh
# Select [I] Install, then choose Stormshield
```

### Manual Installation

```bash
# 1. Copy Python decoder
sudo cp files/stormshield-decoder.py /var/ossec/integrations/
sudo chmod +x /var/ossec/integrations/stormshield-decoder.py

# 2. Install systemd service
sudo cp files/stormshield-decoder.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable stormshield-decoder
sudo systemctl start stormshield-decoder

# 3. Configure Wazuh to receive JSON logs
# Add to /var/ossec/etc/ossec.conf:
#   <remote>
#     <connection>syslog</connection>
#     <port>5515</port>
#     <protocol>udp</protocol>
#     <allowed-ips>127.0.0.1</allowed-ips>
#   </remote>

# 4. Copy decoders and rules
sudo cp stormshield_decoders.xml /var/ossec/etc/decoders/
sudo cp stormshield_rules.xml /var/ossec/etc/rules/

# 5. Restart Wazuh
sudo systemctl restart wazuh-manager
```

## Configuration on Stormshield

### Enable Syslog Export

1. Go to **Configuration > Notifications > Logs - Syslog - IPFIX**
2. Click **Add** to create a new Syslog server
3. Configure:
   - **Server**: `<WAZUH_SERVER_IP>`
   - **Port**: `5514`
   - **Protocol**: `UDP`
   - **Format**: `WELF` or `RFC5424` (both work)

### Enable Required Log Types

Enable these log types:
- **l_server** - Administration events
- **l_auth** - Authentication events
- **l_vpn** - VPN events
- **l_alarm** - IPS/IDS alarms
- **l_system** - System events
- **l_filter** - Firewall filter events (optional, high volume)
- **l_connection** - Connection events (optional, high volume)

## Detection Rules

### Base Rules (100400-100409)
| Rule ID | Level | Description |
|---------|-------|-------------|
| 100400 | 3 | Stormshield event (grouping) |
| 100401 | 3 | Traffic passed |
| 100402 | 5 | Traffic blocked |

### Authentication (100410-100419)
| Rule ID | Level | Description |
|---------|-------|-------------|
| 100410 | 3 | Login success |
| 100411 | 8 | Login failure |
| 100412 | 5 | Admin session opened |
| 100413 | 3 | Admin session closed |
| 100414 | 12 | Brute force attack |
| 100415 | 10 | After-hours admin login |

### VPN (100420-100429)
| Rule ID | Level | Description |
|---------|-------|-------------|
| 100420 | 5 | IPsec tunnel established |
| 100421 | 5 | IPsec tunnel terminated |
| 100422 | 5 | SSL VPN connected |
| 100423 | 3 | SSL VPN disconnected |
| 100424 | 8 | VPN auth failure |
| 100425 | 10 | VPN brute force |

### Configuration Changes (100430-100439)
| Rule ID | Level | Description |
|---------|-------|-------------|
| 100430 | 8 | Configuration modified |
| 100431 | 8 | Firewall rule added |
| 100432 | 10 | Firewall rule removed |
| 100433 | 8 | Firewall rule modified |
| 100437 | 10 | Firmware update |

### IPS/IDS Alarms (100440-100449)
| Rule ID | Level | Description |
|---------|-------|-------------|
| 100440 | 7 | IPS alarm |
| 100441 | 12 | Critical alarm (pri=0) |
| 100442 | 11 | High priority alarm (pri=1) |
| 100443 | 10 | Critical alarm (pri=2) |
| 100444 | 8 | Port scan detected |
| 100445 | 10 | Attack detected |
| 100446 | 10 | Malware detected |
| 100447 | 8 | Flood/DoS attack |

### System Events (100450-100459)
| Rule ID | Level | Description |
|---------|-------|-------------|
| 100450 | 10 | System startup |
| 100451 | 10 | System shutdown |
| 100452 | 10 | HA failover |

### Correlation Rules (100460-100469)
| Rule ID | Level | Description |
|---------|-------|-------------|
| 100460 | 10 | Multiple blocks from same IP |
| 100461 | 12 | Rapid config changes |
| 100462 | 10 | Multiple IPS alarms from same IP |
| 100463 | 8 | Weekend admin login |

## Dashboard Queries

### All Stormshield Events
```
stormshield.fw:*
```

### Blocked Traffic
```
stormshield.action:block
```

### Authentication Events
```
stormshield.logtype:auth
```

### VPN Events
```
stormshield.logtype:vpn
```

### IPS Alarms
```
stormshield.logtype:alarm
```

### Configuration Changes
```
stormshield.logtype:server
```

### High Priority Alerts (Level >= 10)
```
rule.level:>=10 AND stormshield.fw:*
```

## Monitoring

### Check decoder status
```bash
sudo systemctl status stormshield-decoder
```

### View decoder logs
```bash
sudo tail -f /var/log/stormshield-decoder.log
```

### Test log processing
```bash
# Send a test log
echo 'id=firewall time="2024-01-01 12:00:00" fw="TEST" logtype="alarm" action="block" msg="Test"' | nc -u localhost 5514
```

## Files

- `files/stormshield-decoder.py` - Python WELF-to-JSON decoder
- `files/stormshield-decoder.service` - Systemd service
- `stormshield_decoders.xml` - Wazuh JSON decoder
- `stormshield_rules.xml` - Detection rules (40+ rules)
- `manifest.conf` - Module metadata

## Tested On

- Stormshield SNS 4.x, 5.x
- Wazuh 4.8.0+
- Python 3.8+

## Acknowledgments

Inspired by [FryggFR/Wazuh-Stormshield](https://github.com/FryggFR/Wazuh-Stormshield).
