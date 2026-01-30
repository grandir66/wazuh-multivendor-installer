# Stormshield Firewall Module

Complete Wazuh integration for Stormshield Network Security (SNS) firewalls with admin access monitoring, VPN tracking, IPS alerts, and configuration change detection.

## Features

### Authentication Monitoring
- Admin login success/failure
- Session tracking (open/close)
- Brute force detection
- After-hours/weekend login alerts

### VPN Monitoring
- IPsec tunnel establishment/termination
- IKE Phase 1/2 negotiation
- SSL VPN connections
- VPN authentication failures
- VPN brute force detection

### Configuration Change Detection
- Firewall rule added/modified/removed
- NAT configuration changes
- Network object modifications
- Security policy activation
- Backup creation
- Firmware updates

### IPS/IDS Alerts
- All IPS alarms with priority levels
- Port scan detection
- Attack detection
- Malware detection
- Flood/DoS detection
- Intrusion attempts

### System Events
- System startup/shutdown
- HA failover
- License warnings
- Disk/storage alerts
- Interface state changes
- Certificate events

### MITRE ATT&CK Mapping

| Technique | Description | Rules |
|-----------|-------------|-------|
| T1078 | Valid Accounts | 100410, 100412 |
| T1110 | Brute Force | 100411, 100414, 100424, 100425 |
| T1562.004 | Disable/Modify Firewall | 100431-100434 |
| T1005 | Data from Local System | 100436 |
| T1046 | Network Service Scanning | 100444 |
| T1204 | User Execution (Malware) | 100446 |
| T1498 | Network DoS | 100447 |

## Configuration on Stormshield

### Enable Syslog Export

1. Go to **Configuration > Notifications > Logs - Syslog - IPFIX**
2. Click **Add** to create a new Syslog server
3. Configure:
   - **Server**: `<WAZUH_SERVER_IP>`
   - **Port**: `514`
   - **Protocol**: `UDP` or `TCP`
   - **Format**: `WELF` (default)

### Enable Required Log Types

Ensure these log types are enabled:
- **l_server** - Administration events
- **l_auth** - Authentication events
- **l_vpn** - VPN events
- **l_alarm** - IPS/IDS alarms
- **l_system** - System events
- **l_filter** - Firewall filter events (optional, high volume)

### Wazuh Manager Configuration

Add to `/var/ossec/etc/ossec.conf`:

```xml
<remote>
  <connection>syslog</connection>
  <port>514</port>
  <protocol>udp</protocol>
  <allowed-ips>YOUR_STORMSHIELD_IP</allowed-ips>
</remote>
```

Replace `YOUR_STORMSHIELD_IP` with your firewall's IP address.

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
| 100434 | 8 | NAT configuration changed |
| 100436 | 6 | Backup created |
| 100437 | 10 | Firmware update |

### IPS/IDS Alarms (100440-100449)
| Rule ID | Level | Description |
|---------|-------|-------------|
| 100440 | 7 | IPS alarm |
| 100441 | 12 | Critical alarm (pri=0) |
| 100442 | 11 | High priority alarm |
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
| 100453 | 8 | License warning |
| 100454 | 8 | Disk/storage warning |

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
rule.groups:stormshield
```

### Blocked Traffic
```
rule.id:100402
```

### Authentication Events
```
rule.id:(100410 OR 100411 OR 100414)
```

### VPN Events
```
rule.groups:vpn AND rule.groups:stormshield
```

### IPS Alarms
```
rule.groups:ids AND rule.groups:stormshield
```

### Configuration Changes
```
rule.groups:config_change AND rule.groups:stormshield
```

### High Priority Alerts (Level >= 10)
```
rule.level:>=10 AND rule.groups:stormshield
```

## Files

- `stormshield_decoders.xml` - WELF format decoders (40+ fields)
- `stormshield_rules.xml` - Detection rules (45+ rules)
- `manifest.conf` - Module metadata

## Log Format

Stormshield uses WELF (Weapon Event Log Format):

```
id=firewall time="2024-01-15 10:30:00" fw="SNS-01" tz=+0100 logtype=alarm pri=2 srcif="Ethernet0" src=192.168.1.100 srcport=54321 dst=10.0.0.1 dstport=22 ipproto=tcp action=block msg="SSH brute force attempt" alarmid=123
```

## Tested On

- Stormshield SNS 4.x, 5.x
- Wazuh 4.8.0+

## Acknowledgments

Based on [FryggFR/Wazuh-Stormshield](https://github.com/FryggFR/Wazuh-Stormshield), extended with additional fields, rules, and MITRE ATT&CK mapping.
