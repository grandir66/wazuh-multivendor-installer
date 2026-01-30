# Mikrotik RouterOS Module

Complete Wazuh integration for Mikrotik RouterOS with advanced security monitoring, DHCP tracking, and configuration change detection.

## Features

### Security Monitoring
- User Authentication - Login/logout tracking via SSH, Winbox, API
- Brute Force Detection - Multiple login failure alerts
- VPN Monitoring - WireGuard and OpenVPN connection tracking
- Firewall Changes - Filter, NAT, Mangle, Raw rule modifications
- User Management - Account creation, password changes, deletions

### DHCP Monitoring
- Lease Tracking - Assigned and released IP addresses
- Pool Exhaustion - Alerts when DHCP can't assign addresses
- Attack Detection - DHCP starvation attack correlation rules
- Client Tracking - MAC address and hostname logging

### System Configuration Changes
- Firewall Rules - Filter, NAT, Mangle, Raw modifications
- Network Changes - IP addresses, routes, interfaces
- Scripts & Scheduler - Automation changes detection
- Backup/Export - Configuration backup and export tracking
- System Events - Reboot, upgrade notifications

### MITRE ATT&CK Mapping

| Technique | Description |
|-----------|-------------|
| T1110 | Brute Force |
| T1136 | Create Account |
| T1562.004 | Disable or Modify Firewall |
| T1059 | Command and Scripting |
| T1053 | Scheduled Task |
| T1005 | Data from Local System |
| T1557 | DHCP Spoofing |
| T1498 | Network Denial of Service |

## Configuration on Mikrotik

### Basic Syslog Setup

```routeros
# Create remote logging action
/system logging action add name=wazuh target=remote remote=YOUR_WAZUH_IP:514

# Configure topics to send
/system logging add action=wazuh topics=system
/system logging add action=wazuh topics=info
/system logging add action=wazuh topics=warning
/system logging add action=wazuh topics=error
/system logging add action=wazuh topics=dhcp
/system logging add action=wazuh topics=firewall
/system logging add action=wazuh topics=account
```

Replace `YOUR_WAZUH_IP` with your Wazuh server IP address.

### WireGuard Monitoring Script

For WireGuard peer connection tracking, import the `script.rsc` file:

```routeros
/import script.rsc
```

**Note:** Assign a unique `comment` to each WireGuard peer for proper identification.

## Detection Rules

| Rule ID | Level | Category | Description |
|---------|-------|----------|-------------|
| 100200 | 10 | Generic | Mikrotik log with details |
| 100201 | 12 | Auth | User login |
| 100202 | 11 | Auth | Login failure |
| 100203 | 10 | VPN | WireGuard connection |
| 100204 | 10 | VPN | OpenVPN connection |
| 100205 | 12 | Firewall | Filter rule change |
| 100210-100218 | 3-10 | DHCP | DHCP events |
| 100220-100234 | 6-10 | Config | Configuration changes |
| 100240-100242 | 10-12 | Attack | Security alerts |

## Dashboard Queries

### All Mikrotik Events
```
rule.groups:mikrotik
```

### Authentication Events
```
rule.id:(100201 OR 100202)
```

### DHCP Activity
```
rule.id:(100210 OR 100211 OR 100212)
```

### Firewall Changes
```
rule.id:(100205 OR 100206 OR 100221 OR 100222)
```

### Security Alerts (High Priority)
```
rule.level:>=10 AND rule.groups:mikrotik
```

## Files

- `mikrotik_decoders.xml` - 24 decoders for parsing Mikrotik logs
- `mikrotik_rules.xml` - 43 detection rules with MITRE mapping
- `script.rsc` - WireGuard monitoring script for RouterOS

## Tested On

- RouterOS 7.15.1+
- Wazuh 4.8.0+

## Original Project

Based on [angolo40/WazuhMikrotik](https://github.com/angolo40/WazuhMikrotik)
