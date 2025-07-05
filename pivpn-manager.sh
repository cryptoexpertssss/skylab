#!/usr/bin/bash

###############################################################################
# 🔐 PiVPN Container Management Script
# 
# This script provides easy management for the containerized PiVPN OpenVPN server
# Part of the SkyLab ecosystem
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

# Check if running as root or with sudo privileges
if [[ $EUID -eq 0 ]]; then
    sudo_cmd=""
else
    if command -v sudo >/dev/null 2>&1; then
        if sudo -n true 2>/dev/null; then
            sudo_cmd="sudo"
        else
            echo -e "${colorRed}This script requires sudo privileges. Please run with sudo.${colorReset}"
            exit 1
        fi
    else
        echo -e "${colorRed}Sudo is not installed and not running as root.${colorReset}"
        exit 1
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
echo -e "${colorCyan}${colorBold}"
echo "    ╔══════════════════════════════════════════════════════════════════════════════╗"
echo "    ║                    🔐 PiVPN Container Manager 🔐                           ║"
echo "    ╚══════════════════════════════════════════════════════════════════════════════╝"
echo -e "${colorReset}"
echo -e "${colorDim}Managing your containerized OpenVPN server...${colorReset}\n"

# Function to check if PiVPN container exists
check_container() {
    if ${sudo_cmd} docker ps -a --format "table {{.Names}}" | grep -q "pivpn"; then
        return 0
    else
        return 1
    fi
}

# Function to check if PiVPN container is running
check_running() {
    if ${sudo_cmd} docker ps --format "table {{.Names}}" | grep -q "pivpn"; then
        return 0
    else
        return 1
    fi
}

# Function to show status
show_status() {
    echo -e "\n${colorBold}${colorCyan}📊 PIVPN STATUS REPORT${colorReset}"
    echo -e "${colorDim}═══════════════════════════════════════${colorReset}"
    
    # Container status
    if check_container; then
        if check_running; then
            echo -e "${colorGreen}✓${colorReset} PiVPN Container: Running"
            container_id=$(${sudo_cmd} docker ps --format "table {{.ID}}\t{{.Names}}" | grep pivpn | awk '{print $1}')
            echo -e "${colorDim}  Container ID: $container_id${colorReset}"
            
            # Get container IP and ports
            container_ip=$(${sudo_cmd} docker inspect pivpn --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
            echo -e "${colorDim}  Container IP: $container_ip${colorReset}"
        else
            echo -e "${colorYellow}⚠${colorReset} PiVPN Container: Stopped"
        fi
    else
        echo -e "${colorRed}✗${colorReset} PiVPN Container: Not found"
    fi
    
    # Port status
    if ${sudo_cmd} netstat -tuln 2>/dev/null | grep -q ":1194 "; then
        echo -e "${colorGreen}✓${colorReset} OpenVPN Port (1194/UDP): Open"
    else
        echo -e "${colorRed}✗${colorReset} OpenVPN Port (1194/UDP): Not listening"
    fi
    
    if ${sudo_cmd} netstat -tuln 2>/dev/null | grep -q ":8443 "; then
        echo -e "${colorGreen}✓${colorReset} Admin Port (8443/TCP): Open"
    else
        echo -e "${colorRed}✗${colorReset} Admin Port (8443/TCP): Not listening"
    fi
    
    # Directory status
    if [[ -d "/opt/pivpn" ]]; then
        echo -e "${colorGreen}✓${colorReset} Config Directory: Present"
        client_count=$(ls -1 /opt/pivpn/clients/*.ovpn 2>/dev/null | wc -l)
        echo -e "${colorDim}  Client configs: $client_count${colorReset}"
    else
        echo -e "${colorRed}✗${colorReset} Config Directory: Missing"
    fi
    
    echo -e "${colorDim}═══════════════════════════════════════${colorReset}"
}

# Function to start PiVPN
start_pivpn() {
    Show 4 "Starting PiVPN container..."
    
    if ! check_container; then
        Show 1 "PiVPN container does not exist. Please run the main installation script first."
        return 1
    fi
    
    if check_running; then
        Show 2 "PiVPN container is already running."
        return 0
    fi
    
    ${sudo_cmd} docker start pivpn
    sleep 3
    
    if check_running; then
        Show 0 "PiVPN started successfully."
        return 0
    else
        Show 1 "Failed to start PiVPN container."
        return 1
    fi
}

# Function to stop PiVPN
stop_pivpn() {
    Show 4 "Stopping PiVPN container..."
    
    if ! check_running; then
        Show 2 "PiVPN container is not running."
        return 0
    fi
    
    ${sudo_cmd} docker stop pivpn
    Show 0 "PiVPN stopped successfully."
}

# Function to restart PiVPN
restart_pivpn() {
    Show 4 "Restarting PiVPN container..."
    
    if ! check_container; then
        Show 1 "PiVPN container does not exist."
        return 1
    fi
    
    ${sudo_cmd} docker restart pivpn
    sleep 3
    
    if check_running; then
        Show 0 "PiVPN restarted successfully."
        return 0
    else
        Show 1 "Failed to restart PiVPN container."
        return 1
    fi
}

# Function to show logs
show_logs() {
    Show 4 "Showing PiVPN container logs..."
    
    if ! check_container; then
        Show 1 "PiVPN container does not exist."
        return 1
    fi
    
    echo -e "${colorDim}Last 50 lines of PiVPN logs:${colorReset}"
    ${sudo_cmd} docker logs --tail 50 pivpn 2>&1 | while read line; do
        echo -e "${colorDim}  $line${colorReset}"
    done
}

# Function to create a new client
create_client() {
    local client_name="$1"
    
    if [[ -z "$client_name" ]]; then
        echo -e "${colorRed}Error: Client name is required.${colorReset}"
        echo -e "${colorDim}Usage: $0 add-client <client_name>${colorReset}"
        return 1
    fi
    
    # Validate client name (alphanumeric and hyphens only)
    if [[ ! "$client_name" =~ ^[a-zA-Z0-9-]+$ ]]; then
        Show 1 "Invalid client name. Use only letters, numbers, and hyphens."
        return 1
    fi
    
    if ! check_running; then
        Show 1 "PiVPN container is not running. Please start it first."
        return 1
    fi
    
    Show 4 "Creating client certificate for: $client_name"
    
    # Check if client already exists
    if [[ -f "/opt/pivpn/clients/$client_name.ovpn" ]]; then
        Show 3 "Client '$client_name' already exists. Overwriting..."
    fi
    
    # Generate client certificate
    ${sudo_cmd} docker exec pivpn easyrsa build-client-full "$client_name" nopass 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        # Export client configuration
        ${sudo_cmd} docker exec pivpn ovpn_getclient "$client_name" > "/opt/pivpn/clients/$client_name.ovpn" 2>/dev/null
        
        if [[ -f "/opt/pivpn/clients/$client_name.ovpn" ]]; then
            Show 0 "Client '$client_name' created successfully!"
            Show 2 "Configuration file: /opt/pivpn/clients/$client_name.ovpn"
            return 0
        else
            Show 1 "Failed to export client configuration."
            return 1
        fi
    else
        Show 1 "Failed to create client certificate."
        return 1
    fi
}

# Function to list clients
list_clients() {
    Show 4 "Listing VPN clients..."
    
    if [[ ! -d "/opt/pivpn/clients" ]]; then
        Show 1 "Client directory does not exist."
        return 1
    fi
    
    echo -e "\n${colorBold}${colorCyan}📋 VPN CLIENTS${colorReset}"
    echo -e "${colorDim}═══════════════════════════════════════${colorReset}"
    
    local client_files=($(ls -1 /opt/pivpn/clients/*.ovpn 2>/dev/null))
    
    if [[ ${#client_files[@]} -eq 0 ]]; then
        echo -e "${colorDim}  No client configurations found.${colorReset}"
    else
        for file in "${client_files[@]}"; do
            local client_name=$(basename "$file" .ovpn)
            local file_size=$(du -h "$file" | cut -f1)
            local file_date=$(stat -c %y "$file" 2>/dev/null | cut -d' ' -f1)
            echo -e "${colorGreen}•${colorReset} $client_name ${colorDim}($file_size, created: $file_date)${colorReset}"
        done
    fi
    
    echo -e "${colorDim}═══════════════════════════════════════${colorReset}"
}

# Function to remove a client
remove_client() {
    local client_name="$1"
    
    if [[ -z "$client_name" ]]; then
        echo -e "${colorRed}Error: Client name is required.${colorReset}"
        echo -e "${colorDim}Usage: $0 remove-client <client_name>${colorReset}"
        return 1
    fi
    
    if [[ ! -f "/opt/pivpn/clients/$client_name.ovpn" ]]; then
        Show 1 "Client '$client_name' does not exist."
        return 1
    fi
    
    Show 4 "Removing client: $client_name"
    
    # Revoke certificate if container is running
    if check_running; then
        ${sudo_cmd} docker exec pivpn easyrsa revoke "$client_name" 2>/dev/null || true
        ${sudo_cmd} docker exec pivpn easyrsa gen-crl 2>/dev/null || true
    fi
    
    # Remove client file
    rm -f "/opt/pivpn/clients/$client_name.ovpn"
    
    Show 0 "Client '$client_name' removed successfully."
}

# Function to show connection info
show_connection_info() {
    echo -e "\n${colorBold}${colorCyan}🌐 CONNECTION INFORMATION${colorReset}"
    echo -e "${colorDim}═══════════════════════════════════════${colorReset}"
    
    # Get server IP
    local server_ip=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')
    
    echo -e "${colorGreen}•${colorReset} Server IP: ${colorBold}$server_ip${colorReset}"
    echo -e "${colorGreen}•${colorReset} OpenVPN Port: ${colorBold}1194/UDP${colorReset}"
    echo -e "${colorGreen}•${colorReset} Admin Interface: ${colorBold}http://$server_ip:8443${colorReset}"
    echo -e "${colorGreen}•${colorReset} Client Configs: ${colorBold}/opt/pivpn/clients/${colorReset}"
    
    echo -e "\n${colorBold}${colorYellow}📱 CLIENT SETUP:${colorReset}"
    echo -e "${colorDim}1. Download the .ovpn file for your client${colorReset}"
    echo -e "${colorDim}2. Import it into your OpenVPN client app${colorReset}"
    echo -e "${colorDim}3. Connect to your VPN server${colorReset}"
    
    echo -e "${colorDim}═══════════════════════════════════════${colorReset}"
}

# Main execution
main() {
    case "${1:-}" in
        "status")
            show_status
            ;;
        "start")
            start_pivpn
            ;;
        "stop")
            stop_pivpn
            ;;
        "restart")
            restart_pivpn
            ;;
        "logs")
            show_logs
            ;;
        "add-client")
            create_client "$2"
            ;;
        "list-clients")
            list_clients
            ;;
        "remove-client")
            remove_client "$2"
            ;;
        "info")
            show_connection_info
            ;;
        "")
            # Default action - show status and basic info
            show_status
            echo
            show_connection_info
            ;;
        *)
            echo -e "${colorBold}PiVPN Container Manager${colorReset}"
            echo -e "${colorDim}Usage: $0 [command] [options]${colorReset}\n"
            echo -e "${colorBold}Commands:${colorReset}"
            echo -e "  ${colorGreen}status${colorReset}              Show PiVPN status"
            echo -e "  ${colorGreen}start${colorReset}               Start PiVPN container"
            echo -e "  ${colorGreen}stop${colorReset}                Stop PiVPN container"
            echo -e "  ${colorGreen}restart${colorReset}             Restart PiVPN container"
            echo -e "  ${colorGreen}logs${colorReset}                Show container logs"
            echo -e "  ${colorGreen}add-client${colorReset} <name>   Create new VPN client"
            echo -e "  ${colorGreen}list-clients${colorReset}        List all VPN clients"
            echo -e "  ${colorGreen}remove-client${colorReset} <name> Remove VPN client"
            echo -e "  ${colorGreen}info${colorReset}                Show connection information"
            echo -e "  ${colorDim}(no command)${colorReset}        Show status and info"
            echo
            echo -e "${colorBold}Examples:${colorReset}"
            echo -e "  ${colorDim}$0 add-client john-laptop${colorReset}"
            echo -e "  ${colorDim}$0 list-clients${colorReset}"
            echo -e "  ${colorDim}$0 remove-client old-phone${colorReset}"
            exit 1
            ;;
    esac
}

main "$@"