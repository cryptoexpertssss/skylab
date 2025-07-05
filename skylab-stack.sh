#!/usr/bin/bash

###############################################################################
# 🚀 SkyLab Stack Manager
# 
# Complete Docker Compose stack management for home lab environment
# Manages all containerized services with profiles and easy deployment
###############################################################################

# Colors for output
colorRed='\033[31m'
colorGreen='\033[32m'
colorYellow='\033[33m'
colorBlue='\033[34m'
colorMagenta='\033[35m'
colorCyan='\033[36m'
colorReset='\033[0m'
colorBold='\033[1m'
colorDim='\033[2m'

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
ENV_FILE="$SCRIPT_DIR/.env"
ENV_EXAMPLE="$SCRIPT_DIR/.env.example"

# Check if running as root or with sudo privileges
if [[ $EUID -eq 0 ]]; then
    sudo_cmd=""
else
    if command -v sudo >/dev/null 2>&1; then
        if sudo -n true 2>/dev/null; then
            sudo_cmd="sudo"
        else
            echo -e "${colorRed}This script requires sudo privileges for some operations.${colorReset}"
            sudo_cmd="sudo"
        fi
    else
        echo -e "${colorRed}Sudo is not installed and not running as root.${colorReset}"
        sudo_cmd=""
    fi
fi

# Logging function
Show() {
    local timestamp=$(date '+%H:%M:%S')
    case $1 in
    0) echo -e "${colorDim}[$timestamp]${colorReset} [${colorGreen}✓${colorReset}] $2" ;;
    1) echo -e "${colorDim}[$timestamp]${colorReset} [${colorRed}✗${colorReset}] $2" ;;
    2) echo -e "${colorDim}[$timestamp]${colorReset} [${colorYellow}!${colorReset}] $2" ;;
    3) echo -e "${colorDim}[$timestamp]${colorReset} [${colorYellow}⚠${colorReset}] $2" ;;
    4) echo -e "${colorDim}[$timestamp]${colorReset} [${colorCyan}🔄${colorReset}] $2" ;;
    *) echo -e "${colorDim}[$timestamp]${colorReset} [${colorBlue}ℹ${colorReset}] $2" ;;
    esac
}

# Banner
show_banner() {
    echo -e "${colorCyan}${colorBold}"
    echo "    ╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "    ║                    🚀 SkyLab Stack Manager 🚀                             ║"
    echo "    ╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${colorReset}"
    echo -e "${colorDim}Complete home lab environment management...${colorReset}\n"
}

# Check prerequisites
check_prerequisites() {
    Show 4 "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker >/dev/null 2>&1; then
        Show 1 "Docker is not installed. Please install Docker first."
        return 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
        Show 1 "Docker Compose is not installed. Please install Docker Compose first."
        return 1
    fi
    
    # Check if Docker is running
    if ! ${sudo_cmd} docker info >/dev/null 2>&1; then
        Show 1 "Docker is not running. Please start Docker service."
        return 1
    fi
    
    # Check compose file
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        Show 1 "Docker Compose file not found: $COMPOSE_FILE"
        return 1
    fi
    
    Show 0 "Prerequisites check completed."
    return 0
}

# Setup environment
setup_environment() {
    Show 4 "Setting up environment..."
    
    # Create .env file if it doesn't exist
    if [[ ! -f "$ENV_FILE" ]]; then
        if [[ -f "$ENV_EXAMPLE" ]]; then
            Show 4 "Creating .env file from template..."
            cp "$ENV_EXAMPLE" "$ENV_FILE"
            
            # Auto-detect server IP
            local server_ip=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')
            if [[ -n "$server_ip" ]]; then
                sed -i "s/SERVER_IP=.*/SERVER_IP=$server_ip/" "$ENV_FILE" 2>/dev/null || true
                Show 2 "Auto-detected server IP: $server_ip"
            fi
            
            Show 3 "Please review and customize the .env file before proceeding."
            Show 2 "Configuration file created: $ENV_FILE"
        else
            Show 1 "Environment template not found: $ENV_EXAMPLE"
            return 1
        fi
    fi
    
    # Create necessary directories
    Show 4 "Creating directory structure..."
    local dirs=("config" "data" "backups" "config/filebrowser" "config/pivpn" "config/nginx-proxy-manager" "config/heimdall" "data/filebrowser" "data/pivpn/clients" "data/portainer" "data/nginx-proxy-manager" "data/uptime-kuma" "data/pihole/etc" "data/pihole/dnsmasq" "data/heimdall")
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$SCRIPT_DIR/$dir"
    done
    
    Show 0 "Environment setup completed."
}

# Get available profiles
get_profiles() {
    echo "core proxy monitoring dns dashboard"
}

# Show service status
show_status() {
    Show 4 "Checking service status..."
    
    if [[ ! -f "$ENV_FILE" ]]; then
        Show 3 "Environment not configured. Run 'setup' first."
        return 1
    fi
    
    echo -e "\n${colorBold}${colorCyan}📊 SKYLAB STACK STATUS${colorReset}"
    echo -e "${colorDim}═══════════════════════════════════════${colorReset}"
    
    # Use docker-compose or docker compose based on availability
    local compose_cmd="docker-compose"
    if ! command -v docker-compose >/dev/null 2>&1; then
        compose_cmd="docker compose"
    fi
    
    cd "$SCRIPT_DIR"
    ${sudo_cmd} $compose_cmd ps 2>/dev/null || {
        echo -e "${colorDim}  No services running or compose file not found.${colorReset}"
        return 1
    }
    
    echo -e "${colorDim}═══════════════════════════════════════${colorReset}"
    
    # Show access URLs
    echo -e "\n${colorBold}${colorYellow}🌐 ACCESS URLS${colorReset}"
    echo -e "${colorDim}═══════════════════════════════════════${colorReset}"
    
    local server_ip=$(grep "^SERVER_IP=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2 || echo "localhost")
    
    # Core services
    if ${sudo_cmd} docker ps --format "table {{.Names}}" | grep -q "filebrowser"; then
        echo -e "${colorGreen}•${colorReset} Filebrowser: ${colorBlue}http://$server_ip:8080${colorReset}"
    fi
    
    if ${sudo_cmd} docker ps --format "table {{.Names}}" | grep -q "pivpn"; then
        echo -e "${colorGreen}•${colorReset} PiVPN Admin: ${colorBlue}http://$server_ip:8443${colorReset}"
    fi
    
    # Optional services
    if ${sudo_cmd} docker ps --format "table {{.Names}}" | grep -q "portainer"; then
        echo -e "${colorGreen}•${colorReset} Portainer: ${colorBlue}http://$server_ip:9000${colorReset}"
    fi
    
    if ${sudo_cmd} docker ps --format "table {{.Names}}" | grep -q "nginx-proxy-manager"; then
        echo -e "${colorGreen}•${colorReset} Nginx Proxy Manager: ${colorBlue}http://$server_ip:81${colorReset}"
    fi
    
    if ${sudo_cmd} docker ps --format "table {{.Names}}" | grep -q "uptime-kuma"; then
        echo -e "${colorGreen}•${colorReset} Uptime Kuma: ${colorBlue}http://$server_ip:3001${colorReset}"
    fi
    
    if ${sudo_cmd} docker ps --format "table {{.Names}}" | grep -q "pihole"; then
        echo -e "${colorGreen}•${colorReset} Pi-hole: ${colorBlue}http://$server_ip:8053/admin${colorReset}"
    fi
    
    if ${sudo_cmd} docker ps --format "table {{.Names}}" | grep -q "heimdall"; then
        echo -e "${colorGreen}•${colorReset} Heimdall: ${colorBlue}http://$server_ip:8090${colorReset}"
    fi
    
    echo -e "${colorDim}═══════════════════════════════════════${colorReset}"
}

# Deploy stack
deploy_stack() {
    local profiles="$1"
    
    Show 4 "Deploying SkyLab stack..."
    
    if [[ -z "$profiles" ]]; then
        profiles="core"
        Show 2 "No profiles specified, deploying core services only."
    fi
    
    Show 2 "Deploying profiles: $profiles"
    
    cd "$SCRIPT_DIR"
    
    # Use docker-compose or docker compose based on availability
    local compose_cmd="docker-compose"
    if ! command -v docker-compose >/dev/null 2>&1; then
        compose_cmd="docker compose"
    fi
    
    # Build profile arguments
    local profile_args=""
    for profile in $profiles; do
        if [[ "$profile" != "core" ]]; then
            profile_args="$profile_args --profile $profile"
        fi
    done
    
    # Deploy services
    Show 4 "Starting services..."
    ${sudo_cmd} $compose_cmd $profile_args up -d
    
    if [[ $? -eq 0 ]]; then
        Show 0 "Stack deployed successfully!"
        sleep 3
        show_status
    else
        Show 1 "Failed to deploy stack."
        return 1
    fi
}

# Stop stack
stop_stack() {
    Show 4 "Stopping SkyLab stack..."
    
    cd "$SCRIPT_DIR"
    
    local compose_cmd="docker-compose"
    if ! command -v docker-compose >/dev/null 2>&1; then
        compose_cmd="docker compose"
    fi
    
    ${sudo_cmd} $compose_cmd down
    
    if [[ $? -eq 0 ]]; then
        Show 0 "Stack stopped successfully."
    else
        Show 1 "Failed to stop stack."
        return 1
    fi
}

# Update stack
update_stack() {
    Show 4 "Updating SkyLab stack..."
    
    cd "$SCRIPT_DIR"
    
    local compose_cmd="docker-compose"
    if ! command -v docker-compose >/dev/null 2>&1; then
        compose_cmd="docker compose"
    fi
    
    # Pull latest images
    Show 4 "Pulling latest images..."
    ${sudo_cmd} $compose_cmd pull
    
    # Recreate containers with new images
    Show 4 "Recreating containers..."
    ${sudo_cmd} $compose_cmd up -d --force-recreate
    
    if [[ $? -eq 0 ]]; then
        Show 0 "Stack updated successfully!"
        show_status
    else
        Show 1 "Failed to update stack."
        return 1
    fi
}

# Show logs
show_logs() {
    local service="$1"
    local lines="${2:-50}"
    
    cd "$SCRIPT_DIR"
    
    local compose_cmd="docker-compose"
    if ! command -v docker-compose >/dev/null 2>&1; then
        compose_cmd="docker compose"
    fi
    
    if [[ -n "$service" ]]; then
        Show 4 "Showing logs for service: $service"
        ${sudo_cmd} $compose_cmd logs --tail="$lines" -f "$service"
    else
        Show 4 "Showing logs for all services"
        ${sudo_cmd} $compose_cmd logs --tail="$lines" -f
    fi
}

# Backup configuration
backup_config() {
    local backup_name="skylab-backup-$(date +%Y%m%d-%H%M%S)"
    local backup_dir="$SCRIPT_DIR/backups/$backup_name"
    
    Show 4 "Creating backup: $backup_name"
    
    mkdir -p "$backup_dir"
    
    # Backup configuration files
    cp -r "$SCRIPT_DIR/config" "$backup_dir/" 2>/dev/null || true
    cp -r "$SCRIPT_DIR/data" "$backup_dir/" 2>/dev/null || true
    cp "$SCRIPT_DIR/.env" "$backup_dir/" 2>/dev/null || true
    cp "$SCRIPT_DIR/docker-compose.yml" "$backup_dir/" 2>/dev/null || true
    
    # Create archive
    cd "$SCRIPT_DIR/backups"
    tar -czf "$backup_name.tar.gz" "$backup_name" 2>/dev/null
    rm -rf "$backup_name"
    
    Show 0 "Backup created: $SCRIPT_DIR/backups/$backup_name.tar.gz"
}

# Show help
show_help() {
    echo -e "${colorBold}SkyLab Stack Manager${colorReset}"
    echo -e "${colorDim}Complete Docker Compose stack management for home lab${colorReset}\n"
    
    echo -e "${colorBold}Usage:${colorReset}"
    echo -e "  $0 [command] [options]\n"
    
    echo -e "${colorBold}Commands:${colorReset}"
    echo -e "  ${colorGreen}setup${colorReset}                    Initial environment setup"
    echo -e "  ${colorGreen}deploy${colorReset} [profiles]        Deploy stack with specified profiles"
    echo -e "  ${colorGreen}start${colorReset} [profiles]         Alias for deploy"
    echo -e "  ${colorGreen}stop${colorReset}                     Stop all services"
    echo -e "  ${colorGreen}restart${colorReset} [profiles]       Restart stack with profiles"
    echo -e "  ${colorGreen}update${colorReset}                   Update all services to latest images"
    echo -e "  ${colorGreen}status${colorReset}                   Show service status and URLs"
    echo -e "  ${colorGreen}logs${colorReset} [service] [lines]   Show logs (default: all services, 50 lines)"
    echo -e "  ${colorGreen}backup${colorReset}                   Create configuration backup"
    echo -e "  ${colorGreen}help${colorReset}                     Show this help message\n"
    
    echo -e "${colorBold}Available Profiles:${colorReset}"
    echo -e "  ${colorYellow}core${colorReset}                     Essential services (filebrowser, pivpn, watchtower)"
    echo -e "  ${colorYellow}proxy${colorReset}                    Nginx Proxy Manager for reverse proxy"
    echo -e "  ${colorYellow}monitoring${colorReset}               Uptime Kuma for service monitoring"
    echo -e "  ${colorYellow}dns${colorReset}                      Pi-hole for network-wide ad blocking"
    echo -e "  ${colorYellow}dashboard${colorReset}                Heimdall application dashboard\n"
    
    echo -e "${colorBold}Examples:${colorReset}"
    echo -e "  ${colorDim}$0 setup${colorReset}                           # Initial setup"
    echo -e "  ${colorDim}$0 deploy${colorReset}                          # Deploy core services only"
    echo -e "  ${colorDim}$0 deploy core proxy monitoring${colorReset}    # Deploy with multiple profiles"
    echo -e "  ${colorDim}$0 logs filebrowser${colorReset}                # Show filebrowser logs"
    echo -e "  ${colorDim}$0 backup${colorReset}                          # Create backup\n"
    
    echo -e "${colorBold}Configuration:${colorReset}"
    echo -e "  Edit ${colorYellow}.env${colorReset} file to customize settings"
    echo -e "  Edit ${colorYellow}docker-compose.yml${colorReset} to modify services\n"
}

# Main execution
main() {
    case "${1:-}" in
        "setup")
            show_banner
            check_prerequisites || exit 1
            setup_environment
            ;;
        "deploy"|"start")
            show_banner
            check_prerequisites || exit 1
            setup_environment
            deploy_stack "${*:2}"
            ;;
        "stop")
            show_banner
            check_prerequisites || exit 1
            stop_stack
            ;;
        "restart")
            show_banner
            check_prerequisites || exit 1
            stop_stack
            deploy_stack "${*:2}"
            ;;
        "update")
            show_banner
            check_prerequisites || exit 1
            update_stack
            ;;
        "status")
            show_banner
            check_prerequisites || exit 1
            show_status
            ;;
        "logs")
            check_prerequisites || exit 1
            show_logs "$2" "$3"
            ;;
        "backup")
            show_banner
            backup_config
            ;;
        "help"|"--help"|"")
            show_banner
            show_help
            ;;
        *)
            show_banner
            echo -e "${colorRed}Unknown command: $1${colorReset}\n"
            show_help
            exit 1
            ;;
    esac
}

main "$@"