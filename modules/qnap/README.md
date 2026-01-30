# QNAP NAS Module

Native syslog integration for QNAP QTS with file access monitoring, authentication tracking, and security detection.

## Features

### File Access Monitoring
- File Operations - Read, write, delete, rename, move
- SMB/Samba Access - Windows file sharing
- HTTP/HTTPS Access - Web interface file access
- FTP Access - FTP file transfers
- AFP Access - Apple file sharing

### Authentication Monitoring
- SSH Login Success/Failure
- Web Login Success/Failure
- Brute Force Detection

### System Events
- System Startup/Shutdown
- Firmware Updates

### Security Detection
- Brute Force Detection - SSH and Web login attempts
- Ransomware Detection - Mass file deletions
- Data Exfiltration - Mass file reads
- After-Hours Access - Outside business hours
- Weekend Access - Saturday/Sunday activity

### MITRE ATT&CK Mapping

| Technique | Description |
|-----------|-------------|
| T1110 | Brute Force |
| T1485 | Data Destruction |
| T1486 | Data Encrypted for Impact |
| T1039 | Data from Network Shared Drive |
| T1005 | Data from Local System |

## Configuration on QNAP

1. Control Panel → System Logs → Syslog Client
2. Enable: Remote archiving (syslog)
3. Server: `<Wazuh Server IP>`
4. Port: `514`
5. Protocol: `UDP`

## Detection Rules

| Rule ID | Level | Category | Description |
|---------|-------|----------|-------------|
| 100300 | 3 | Base | Connection log event |
| 100310 | 5 | File | Write operation |
| 100311 | 4 | File | Read operation |
| 100312 | 7 | File | Delete operation |
| 100320 | 4 | Protocol | SMB/Samba access |
| 100321 | 4 | Protocol | Web access |
| 100330 | 5 | Auth | SSH login success |
| 100331 | 8 | Auth | SSH login failure |
| 100332 | 5 | Auth | Web login success |
| 100333 | 7 | Auth | Web login failure |
| 100340-342 | 8-10 | System | System events |
| 100350-353 | 8-12 | Attack | Security alerts |
| 100360-361 | 5-6 | Anomaly | Time-based alerts |

## Dashboard Queries

### All QNAP Events
```
rule.groups:qnap
```

### Authentication Events
```
rule.id:(100330 OR 100331 OR 100332 OR 100333)
```

### File Operations
```
rule.id:(100310 OR 100311 OR 100312)
```

### Security Alerts
```
rule.level:>=8 AND rule.groups:qnap
```

## Files

- `qnap_decoders.xml` - Decoders for parsing QNAP logs
- `qnap_rules.xml` - Detection rules with MITRE mapping

## Tested On

- QTS 5.x
- Wazuh 4.8.0+
