# SkyLab Homepage

A modern, hacker-themed dashboard for your SkyLab homelab environment.

## Features

- 🎯 **Centralized Access** - Quick links to all your homelab services
- 🎨 **Hacker Aesthetic** - Matrix-style background with terminal vibes
- 📱 **Responsive Design** - Works on desktop, tablet, and mobile
- ⚡ **Real-time Status** - Live system information and uptime
- 🔧 **Easy Customization** - Simple HTML/CSS/JS for modifications

## Quick Start

### Option 1: Python Server (Recommended)

```bash
# Navigate to homepage directory
cd /path/to/skylab/homepage

# Start the server
python3 server.py

# Access at http://localhost:8888
```

### Option 2: Docker Container

```bash
# Build and run with Docker
docker run -d \
  --name skylab-homepage \
  --restart unless-stopped \
  -p 8888:80 \
  -v $(pwd):/usr/share/nginx/html:ro \
  nginx:alpine
```

### Option 3: Add to Docker Compose

Add this service to your `docker-compose.yml`:

```yaml
services:
  homepage:
    image: nginx:alpine
    container_name: skylab-homepage
    restart: unless-stopped
    ports:
      - "8888:80"
    volumes:
      - ./homepage:/usr/share/nginx/html:ro
    networks:
      - skylab-network
```

## Customization

### Adding New Services

To add a new service card, edit `index.html` and add a new service card in the `services-grid` section:

```html
<div class="service-card">
    <div class="status-indicator"></div>
    <div class="service-header">
        <div class="service-icon">🔧</div>
        <div class="service-name">Your Service</div>
    </div>
    <div class="service-description">
        Description of your service functionality.
    </div>
    <a href="http://localhost:PORT" class="service-url" target="_blank">ACCESS PORTAL</a>
</div>
```

### Changing Colors

The color scheme can be modified in the CSS section:

- Primary Green: `#00ff41`
- Secondary Blue: `#00ccff`
- Background: `#0a0a0a` to `#16213e` gradient

### Updating Service URLs

Modify the `href` attributes in the service cards to match your actual service URLs and ports.

## Service List

The homepage includes quick access to these SkyLab services:

| Service | Default Port | Description |
|---------|-------------|-------------|
| Filebrowser | 8080 | Web-based file management |
| AdGuard Home | 3000 | DNS ad blocker |
| Portainer | 9000 | Docker management |
| Nginx Proxy Manager | 81 | Reverse proxy management |
| Uptime Kuma | 3001 | Service monitoring |
| Pi-hole | 8053 | Network ad blocking |
| Heimdall | 8090 | Application dashboard |
| Watchtower | - | Automatic updates (background) |

## Integration with SkyLab

### Auto-start with System

Create a systemd service to start the homepage automatically:

```bash
# Create service file
sudo tee /etc/systemd/system/skylab-homepage.service > /dev/null <<EOF
[Unit]
Description=SkyLab Homepage Server
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/skylab/homepage
ExecStart=/usr/bin/python3 /home/ubuntu/skylab/homepage/server.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
sudo systemctl enable skylab-homepage
sudo systemctl start skylab-homepage
```

### Add to SkyLab Script

You can integrate the homepage into the main SkyLab installation by adding this function to `skylab.sh`:

```bash
Install_Homepage() {
    Show 2 "Installing SkyLab Homepage..."
    
    # Create homepage directory
    mkdir -p "$HOME/skylab/homepage"
    
    # Copy homepage files (if they exist)
    if [[ -f "homepage/index.html" ]]; then
        cp homepage/* "$HOME/skylab/homepage/"
        chmod +x "$HOME/skylab/homepage/server.py"
        
        Show 0 "Homepage installed successfully"
        Show 2 "Access at: http://localhost:8888"
    else
        Show 3 "Homepage files not found, skipping..."
    fi
}
```

## Troubleshooting

### Port Already in Use

If port 8888 is already in use, modify the `PORT` variable in `server.py`:

```python
PORT = 8889  # Change to any available port
```

### Service URLs Not Working

1. Verify services are running: `docker ps`
2. Check service ports in `docker-compose.yml`
3. Update URLs in `index.html` to match your configuration

### Permission Issues

Make sure the server script is executable:

```bash
chmod +x server.py
```

## Security Notes

- The homepage is designed for internal network use
- Consider using a reverse proxy (like Nginx Proxy Manager) for external access
- The Python server includes basic security headers
- For production use, consider using a proper web server like Nginx

## Contributing

Feel free to customize and improve the homepage:

1. Fork the repository
2. Make your changes
3. Test thoroughly
4. Submit a pull request

## License

This homepage is part of the SkyLab project and follows the same license terms.