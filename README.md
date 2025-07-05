# 🚀 SkyLab - Complete Home Lab Stack

A comprehensive, containerized home lab environment that provides essential services for self-hosting, VPN access, monitoring, and network management.

## 📋 Table of Contents

- [Overview](#overview)
- [Services Included](#services-included)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Configuration](#configuration)
- [Service Profiles](#service-profiles)
- [Management](#management)
- [Access URLs](#access-urls)
- [Backup & Restore](#backup--restore)
- [Troubleshooting](#troubleshooting)
- [Security Considerations](#security-considerations)

## 🎯 Overview

SkyLab is a Docker Compose-based home lab stack that provides:

- **File Management**: Web-based file browser with secure access
- **VPN Server**: Containerized OpenVPN for secure remote access
- **Reverse Proxy**: Nginx Proxy Manager for SSL termination and routing
- **Monitoring**: Uptime monitoring and service health checks
- **DNS Filtering**: Pi-hole for network-wide ad blocking
- **Dashboard**: Centralized application dashboard
- **Container Management**: Portainer for Docker administration
- **Auto-Updates**: Watchtower for automatic container updates

## 🛠 Services Included

### Core Services (Always Deployed)

| Service | Description | Default Port | Container |
|---------|-------------|--------------|----------|
| **Filebrowser** | Web-based file manager | 8080 | `filebrowser/filebrowser` |
| **PiVPN** | OpenVPN server | 1194/UDP, 8443 | `dperson/openvpn` |
| **Watchtower** | Automatic container updates | - | `containrrr/watchtower` |
| **Portainer** | Docker management UI | 9000 | `portainer/portainer-ce` |

### Optional Services (Profile-Based)

| Service | Profile | Description | Default Port |
|---------|---------|-------------|-------------|
| **Nginx Proxy Manager** | `proxy` | Reverse proxy with SSL | 80, 443, 81 |
| **Uptime Kuma** | `monitoring` | Service monitoring | 3001 |
| **Pi-hole** | `dns` | DNS-based ad blocker | 53, 8053 |
| **Heimdall** | `dashboard` | Application dashboard | 8090 |

## 🚀 Quick Start

1. **Clone or download** the SkyLab files to your server
2. **Make the stack manager executable**:
   ```bash
   chmod +x skylab-stack.sh
   ```
3. **Run initial setup**:
   ```bash
   ./skylab-stack.sh setup
   ```
4. **Deploy core services**:
   ```bash
   ./skylab-stack.sh deploy
   ```
5. **Check status**:
   ```bash
   ./skylab-stack.sh status
   ```

## 📦 Installation

### Prerequisites

- **Docker** (20.10+)
- **Docker Compose** (v2.0+)
- **Linux/Unix environment** (Ubuntu, Debian, CentOS, etc.)
- **Sudo privileges** for Docker operations
- **Internet connection** for image downloads

### System Requirements

- **RAM**: Minimum 2GB, Recommended 4GB+
- **Storage**: Minimum 10GB free space
- **Network**: Static IP recommended for VPN functionality

### Installation Steps

1. **Install Docker** (if not already installed):
   ```bash
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   sudo usermod -aG docker $USER
   ```

2. **Download SkyLab**:
   ```bash
   git clone <repository-url> skylab
   cd skylab
   ```

3. **Make scripts executable**:
   ```bash
   chmod +x *.sh
   ```

4. **Run setup**:
   ```bash
   ./skylab-stack.sh setup
   ```

## ⚙️ Configuration

### Environment Variables

The `.env` file contains all configuration options:

```bash
# Server Configuration
SERVER_IP=your.server.ip
TIMEZONE=America/New_York
PUID=1000
PGID=1000

# Security
PIHOLE_PASSWORD=secure_password_here
FILEBROWSER_PASSWORD=secure_password_here

# Network
DOCKER_SUBNET=172.20.0.0/16

# Service Ports
FILEBROWSER_PORT=8080
PORTAINER_PORT=9000
NGINX_HTTP_PORT=80
NGINX_HTTPS_PORT=443
NGINX_ADMIN_PORT=81
UPTIME_KUMA_PORT=3001
PIHOLE_DNS_PORT=53
PIHOLE_WEB_PORT=8053
HEIMDALL_PORT=8090

# VPN Configuration
VPN_PORT=1194
VPN_PROTOCOL=udp
VPN_ADMIN_PORT=8443

# Backup Settings
BACKUP_RETENTION_DAYS=30

# Monitoring
WATCHTOWER_SCHEDULE=0 0 4 * * *
```

### Customization

1. **Edit `.env` file** to match your environment
2. **Modify `docker-compose.yml`** for advanced configurations
3. **Adjust service profiles** in the compose file

## 🎭 Service Profiles

SkyLab uses Docker Compose profiles to organize services:

### Core Profile (Default)
```bash
./skylab-stack.sh deploy core
```
Includes: Filebrowser, PiVPN, Watchtower, Portainer

### Proxy Profile
```bash
./skylab-stack.sh deploy core proxy
```
Adds: Nginx Proxy Manager for reverse proxy and SSL

### Monitoring Profile
```bash
./skylab-stack.sh deploy core monitoring
```
Adds: Uptime Kuma for service monitoring

### DNS Profile
```bash
./skylab-stack.sh deploy core dns
```
Adds: Pi-hole for network-wide ad blocking

### Dashboard Profile
```bash
./skylab-stack.sh deploy core dashboard
```
Adds: Heimdall application dashboard

### Full Stack
```bash
./skylab-stack.sh deploy core proxy monitoring dns dashboard
```
Deploys all available services

## 🎮 Management

### Stack Manager Commands

```bash
# Setup and deployment
./skylab-stack.sh setup                    # Initial environment setup
./skylab-stack.sh deploy [profiles]        # Deploy with specified profiles
./skylab-stack.sh start [profiles]         # Alias for deploy

# Control
./skylab-stack.sh stop                     # Stop all services
./skylab-stack.sh restart [profiles]       # Restart with profiles
./skylab-stack.sh update                   # Update all services

# Monitoring
./skylab-stack.sh status                   # Show service status and URLs
./skylab-stack.sh logs [service] [lines]   # Show logs

# Maintenance
./skylab-stack.sh backup                   # Create configuration backup
```

### Individual Service Management

```bash
# PiVPN Management
./pivpn-manager.sh status                  # Check VPN status
./pivpn-manager.sh add-client <name>       # Add VPN client
./pivpn-manager.sh list-clients            # List VPN clients
./pivpn-manager.sh remove-client <name>    # Remove VPN client
./pivpn-manager.sh logs                    # Show VPN logs

# Docker Compose Commands
docker-compose ps                          # List running services
docker-compose logs -f [service]           # Follow logs
docker-compose restart [service]           # Restart specific service
```

## 🌐 Access URLs

After deployment, services are accessible at:

| Service | URL | Default Credentials |
|---------|-----|--------------------|
| **Filebrowser** | `http://your-ip:8080` | admin / (generated) |
| **PiVPN Admin** | `http://your-ip:8443` | - |
| **Portainer** | `http://your-ip:9000` | (setup required) |
| **Nginx Proxy Manager** | `http://your-ip:81` | admin@example.com / changeme |
| **Uptime Kuma** | `http://your-ip:3001` | (setup required) |
| **Pi-hole** | `http://your-ip:8053/admin` | admin / (from .env) |
| **Heimdall** | `http://your-ip:8090` | - |

## 💾 Backup & Restore

### Automatic Backups

```bash
# Create backup
./skylab-stack.sh backup

# Backups are stored in: ./backups/skylab-backup-YYYYMMDD-HHMMSS.tar.gz
```

### Manual Backup

```bash
# Backup configuration and data
tar -czf skylab-backup-$(date +%Y%m%d).tar.gz config/ data/ .env docker-compose.yml
```

### Restore

```bash
# Extract backup
tar -xzf skylab-backup-YYYYMMDD.tar.gz

# Stop services
./skylab-stack.sh stop

# Restore files
cp -r backup-folder/* ./

# Restart services
./skylab-stack.sh deploy
```

## 🔧 Troubleshooting

### Common Issues

#### Services Won't Start
```bash
# Check Docker status
sudo systemctl status docker

# Check logs
./skylab-stack.sh logs [service]

# Check port conflicts
sudo netstat -tulpn | grep :[port]
```

#### Permission Issues
```bash
# Fix ownership
sudo chown -R $USER:$USER ./config ./data

# Fix permissions
chmod -R 755 ./config ./data
```

#### Network Issues
```bash
# Check Docker networks
docker network ls

# Recreate network
docker-compose down
docker network prune
docker-compose up -d
```

#### VPN Connection Issues
```bash
# Check VPN logs
./pivpn-manager.sh logs

# Verify port forwarding
sudo ufw allow 1194/udp

# Check client configuration
./pivpn-manager.sh list-clients
```

### Log Locations

- **Stack logs**: `./skylab-stack.sh logs`
- **Individual service**: `docker-compose logs [service]`
- **System logs**: `/var/log/syslog`

## 🔒 Security Considerations

### Essential Security Steps

1. **Change default passwords** in `.env` file
2. **Use strong passwords** for all services
3. **Enable firewall** and configure port access
4. **Regular updates** via Watchtower
5. **Monitor access logs** regularly
6. **Use SSL certificates** via Nginx Proxy Manager
7. **Backup configurations** regularly

### Firewall Configuration

```bash
# Enable UFW
sudo ufw enable

# Allow SSH
sudo ufw allow ssh

# Allow web services
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8080/tcp

# Allow VPN
sudo ufw allow 1194/udp

# Check status
sudo ufw status
```

### SSL/TLS Setup

1. **Use Nginx Proxy Manager** for automatic SSL certificates
2. **Configure Let's Encrypt** for free SSL certificates
3. **Force HTTPS** for all web services
4. **Regular certificate renewal** (automatic with NPM)

## 📚 Additional Resources

- **Docker Documentation**: https://docs.docker.com/
- **Docker Compose Reference**: https://docs.docker.com/compose/
- **Service Documentation**: Check individual service GitHub repositories
- **Community Support**: Create issues in the project repository

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**SkyLab** - Your complete home lab solution! 🚀