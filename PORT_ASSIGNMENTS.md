# SkyLab Port Assignments

This document lists all port assignments for SkyLab services to prevent conflicts.

## Core Services (Always Deployed)

| Service | Container Port | Host Port | Protocol | Description |
|---------|---------------|-----------|----------|-------------|
| **Filebrowser** | 80 | 8080 | HTTP | Web-based file management |
| **AdGuard Home** | 80 | 3000 | HTTP | Web interface |
| **AdGuard Home** | 53 | 5353 | TCP/UDP | DNS server (changed from 53 to avoid conflicts) |
| **SkyLab Homepage** | 80 | 8888 | HTTP | Homelab dashboard |
| **Portainer** | 9000 | 9000 | HTTP | Docker management UI |
| **Portainer** | 9443 | 9443 | HTTPS | Docker management UI (SSL) |
| **Watchtower** | - | - | - | Background service (no exposed ports) |

## Optional Services (Profile-Based)

| Service | Container Port | Host Port | Protocol | Description |
|---------|---------------|-----------|----------|-------------|
| **Nginx Proxy Manager** | 80 | 80 | HTTP | Reverse proxy |
| **Nginx Proxy Manager** | 443 | 443 | HTTPS | Reverse proxy (SSL) |
| **Nginx Proxy Manager** | 81 | 81 | HTTP | Admin interface |
| **Uptime Kuma** | 3001 | 3001 | HTTP | Service monitoring |
| **Pi-hole** | 53 | 53 | TCP/UDP | DNS server |
| **Pi-hole** | 80 | 8053 | HTTP | Web interface |
| **Heimdall** | 80 | 8090 | HTTP | Application dashboard |
| **Heimdall** | 443 | 8091 | HTTPS | Application dashboard (SSL) |

## Port Conflict Resolution

### Fixed Conflicts:
1. **AdGuard DNS Port**: Changed from 53 to 5353 to avoid conflicts with system DNS
2. **Pi-hole Web Interface**: Corrected documentation from 8081 to 8053
3. **Heimdall Dashboard**: Corrected documentation from 8082 to 8090

### Port Ranges Used:
- **80-443**: Standard HTTP/HTTPS (Nginx Proxy Manager)
- **3000-3001**: Application interfaces (AdGuard, Uptime Kuma)
- **5353**: DNS services (AdGuard)
- **8000-8999**: Web interfaces (Filebrowser: 8080, Pi-hole: 8053, Heimdall: 8090, Homepage: 8888)
- **9000-9999**: Management interfaces (Portainer: 9000, 9443)

### Available Ports:
- 8081, 8082, 8083-8087, 8089, 8091-8887, 8889-8999 (excluding those listed above)

## Notes:
- All services use the `skylab` Docker network for internal communication
- Port conflicts are automatically detected during installation
- Services can be accessed via `http://your-server-ip:port`
- SSL certificates can be managed through Nginx Proxy Manager