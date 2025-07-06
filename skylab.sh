#!/bin/bash

###############################################################################
# 🚀 SkyLab Complete Installer
#
# Single script to install and configure the entire SkyLab stack
# Includes: Docker, Services, Cloudflare Tunnel, Traefik, Authelia
#
# Usage: curl -sSL https://raw.githubusercontent.com/your-repo/skylab/main/skylab-installer.sh | bash
# Or: wget -qO- https://raw.githubusercontent.com/your-repo/skylab/main/skylab-installer.sh | bash
###############################################################################

# Enhanced error handling
set -euo pipefail

# Global variables for debugging and logging
DEBUG=${DEBUG:-false}
LOG_FILE="/tmp/skylab-installer-$(id -u).log"
STEP_FILE="/tmp/skylab-step-$(id -u).txt"

# Error handling function
handle_error() {
    local exit_code=$?
    local line_number=$1
    local command="$2"

    echo ""
    echo -e "${RED}❌ Installation failed at line $line_number${NC}"
    echo -e "${RED}Command: $command${NC}"
    echo -e "${RED}Exit code: $exit_code${NC}"
    echo ""
    echo -e "${YELLOW}🔍 Troubleshooting steps:${NC}"
    echo -e "   1. Check the log file: ${CYAN}$LOG_FILE${NC}"
    echo -e "   2. Verify system requirements and permissions"
    echo -e "   3. Run with debug mode: ${CYAN}DEBUG=true ./skylab-installer.sh${NC}"
    echo -e "   4. Check available disk space and memory"
    echo ""
    echo -e "${CYAN}💡 You can resume installation by running the script again${NC}"
    echo -e "${CYAN}   The installer will detect existing components and continue${NC}"
    echo ""

    # Save current step for recovery
    local recovery_file="/tmp/skylab-recovery-$(id -u).env"
    echo "FAILED_AT_STEP=$(cat $STEP_FILE 2>/dev/null || echo 'unknown')" > "$recovery_file" 2>/dev/null || true
    echo "FAILED_AT_LINE=$line_number" >> "$recovery_file" 2>/dev/null || true
    echo "FAILED_COMMAND=$command" >> "$recovery_file" 2>/dev/null || true

    exit $exit_code
}

# Set up error trapping
trap 'handle_error $LINENO "$BASH_COMMAND"' ERR

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Try to write to log file, but don't fail if we can't
    if ! echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null; then
        # If we can't write to the log file, try to create it with proper permissions
        if ! touch "$LOG_FILE" 2>/dev/null; then
            # If we still can't create it, use a fallback location
            LOG_FILE="$HOME/skylab-installer.log"
            echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true
        else
            echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true
        fi
    fi

    if [[ "$DEBUG" == "true" ]]; then
        echo -e "${CYAN}[DEBUG]${NC} $message" >&2
    fi
}

# Enhanced print functions with logging
print_step() {
    echo "$1" > "$STEP_FILE" 2>/dev/null || true
    log "INFO" "STEP: $1"
    echo ""
    echo -e "${BOLD}${BLUE}🔧 $1${NC}"
    echo ""
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/opt/skylab"
DATA_DIR="/data"
DOMAIN=""
CF_EMAIL=""
CF_API_KEY=""
INSTALL_TYPE=""

# Function to print colored output
print_banner() {
    clear
    echo ""
    echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${CYAN}│                                         │${NC}"
    echo -e "${BOLD}${CYAN}│           🚀 ${WHITE}SkyLab Setup${CYAN} 🚀           │${NC}"
    echo -e "${BOLD}${CYAN}│                                         │${NC}"
    echo -e "${BOLD}${CYAN}│      ${WHITE}Complete Home Lab Installer${CYAN}      │${NC}"
    echo -e "${BOLD}${CYAN}│                                         │${NC}"
    echo -e "${BOLD}${CYAN}└─────────────────────────────────────────┘${NC}"
    echo ""

    # Show recovery info if available
    local recovery_file="/tmp/skylab-recovery-$(id -u).env"
    if [[ -f "$recovery_file" ]]; then
        source "$recovery_file" 2>/dev/null || true
        echo -e "${YELLOW}🔄 Recovery Mode Detected${NC}"
        echo -e "   Previous installation failed at: ${CYAN}${FAILED_AT_STEP:-unknown step}${NC}"
        echo -e "   The installer will attempt to resume from where it left off"
        echo ""
    fi
}

print_status() {
    log "INFO" "$1"
    echo -e "   ${BLUE}ℹ${NC}  $1"
}

print_success() {
    log "SUCCESS" "$1"
    echo -e "   ${GREEN}✅${NC} $1"
}

print_warning() {
    log "WARNING" "$1"
    echo -e "   ${YELLOW}⚠️${NC}  $1"
}

print_error() {
    log "ERROR" "$1"
    echo -e "   ${RED}❌${NC} $1"
}

print_step() {
    echo ""
    echo -e "${BOLD}${CYAN}🔧 $1${NC}"
    echo ""
}

# Prerequisites checking function
check_prerequisites() {
    print_step "Checking System Prerequisites"

    local errors=0

    # Check available disk space (minimum 10GB)
    local available_space=$(df / | awk 'NR==2 {print $4}')
    local required_space=10485760  # 10GB in KB

    if [[ $available_space -lt $required_space ]]; then
        print_error "Insufficient disk space. Required: 10GB, Available: $(($available_space/1024/1024))GB"
        ((errors++))
    else
        print_success "Disk space check passed ($(($available_space/1024/1024))GB available)"
    fi

    # Check available memory (minimum 2GB)
    local available_memory=$(free -m | awk 'NR==2{print $7}')
    if [[ $available_memory -lt 2048 ]]; then
        print_warning "Low available memory. Recommended: 2GB+, Available: ${available_memory}MB"
        print_status "Installation will continue but performance may be affected"
    else
        print_success "Memory check passed (${available_memory}MB available)"
    fi

    # Check internet connectivity
    if ! ping -c 1 google.com >/dev/null 2>&1; then
        print_error "No internet connection detected"
        print_status "Internet connection is required to download Docker images and packages"
        ((errors++))
    else
        print_success "Internet connectivity verified"
    fi

    # Check if ports are available
    local ports_to_check=(53 80 443 8080 9000)
    local port_conflicts=()

    for port in "${ports_to_check[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            port_conflicts+=($port)
        fi
    done

    if [[ ${#port_conflicts[@]} -gt 0 ]]; then
        print_warning "Port conflicts detected: ${port_conflicts[*]}"
        print_status "The installer will attempt to resolve these conflicts automatically"
    else
        print_success "No port conflicts detected"
    fi

    if [[ $errors -gt 0 ]]; then
        print_error "Prerequisites check failed with $errors critical errors"
        print_status "Please resolve the above issues before continuing"
        exit 1
    fi

    print_success "All prerequisites checks passed"
}

# Check for existing installation and offer recovery
check_existing_installation() {
    if [[ -f "$INSTALL_DIR/.env" ]] || [[ -f "$INSTALL_DIR/docker-compose.yml" ]]; then
        print_warning "Existing SkyLab installation detected"
        echo -e "   Installation directory: ${CYAN}$INSTALL_DIR${NC}"
        echo -e "   Data directory: ${CYAN}$DATA_DIR/appdata${NC}"
        echo ""

        while true; do
            echo -e "${YELLOW}What would you like to do?${NC}"
            echo -e "   ${GREEN}1)${NC} Continue and update existing installation"
            echo -e "   ${YELLOW}2)${NC} Backup existing and start fresh"
            echo -e "   ${RED}3)${NC} Exit and manually resolve"
            echo ""
            read -p "Enter your choice [1-3]: " choice

            case $choice in
                1)
                    print_success "Continuing with existing installation update"
                    return 0
                    ;;
                2)
                    print_status "Creating backup of existing installation..."
                    local backup_dir="/tmp/skylab-backup-$(date +%Y%m%d-%H%M%S)"
                    mkdir -p "$backup_dir"

                    if [[ -d "$INSTALL_DIR" ]]; then
                        cp -r "$INSTALL_DIR" "$backup_dir/"
                    fi
                    if [[ -d "$DATA_DIR/appdata" ]]; then
                        cp -r "$DATA_DIR/appdata" "$backup_dir/"
                    fi

                    print_success "Backup created at: $backup_dir"
                    print_status "Removing existing installation..."
                    sudo rm -rf "$INSTALL_DIR" "$DATA_DIR/appdata"
                    return 0
                    ;;
                3)
                    print_status "Installation cancelled by user"
                    echo -e "   To manually resolve:"
                    echo -e "   • Remove: ${CYAN}$INSTALL_DIR${NC}"
                    echo -e "   • Remove: ${CYAN}$DATA_DIR/appdata${NC}"
                    echo -e "   • Or backup and move these directories"
                    exit 0
                    ;;
                *)
                    print_warning "Please enter 1, 2, or 3"
                    ;;
            esac
        done
    fi
}

# Welcome message
show_welcome() {
    echo -e "${BOLD}${GREEN}Welcome to SkyLab! 🎉${NC}"
    echo ""
    echo -e "This installer will set up a complete home lab with:"
    echo -e "• File management, VPN server, DNS ad-blocking"
    echo -e "• Docker container management and auto-updates"
    echo -e "• Optional external access and monitoring"
    echo ""
    echo -e "${CYAN}Let's get started!${NC}"
    echo ""
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root"
        print_status "Please run as a regular user with sudo privileges"
        exit 1
    fi
    
    if ! sudo -n true 2>/dev/null; then
        print_warning "This script requires sudo privileges"
        print_status "You may be prompted for your password"
    fi
}

# Detect OS and architecture
detect_system() {
    print_step "Detecting System"
    
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        armv7l) ARCH="arm" ;;
        *) print_error "Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    
    print_status "OS: $OS"
    print_status "Architecture: $ARCH"
    
    # Check if supported OS
    case $OS in
        linux)
            if command -v apt-get >/dev/null 2>&1; then
                PKG_MANAGER="apt"
                INSTALL_CMD="apt-get install -y"
                UPDATE_CMD="apt-get update"
            elif command -v yum >/dev/null 2>&1; then
                PKG_MANAGER="yum"
                INSTALL_CMD="yum install -y"
                UPDATE_CMD="yum update"
            elif command -v dnf >/dev/null 2>&1; then
                PKG_MANAGER="dnf"
                INSTALL_CMD="dnf install -y"
                UPDATE_CMD="dnf update"
            else
                print_error "Unsupported package manager"
                exit 1
            fi
            ;;
        *)
            print_error "Unsupported operating system: $OS"
            exit 1
            ;;
    esac
    
    print_success "System detection completed"
}

# Show detailed service explanations
show_service_overview() {
    echo -e "${BOLD}${CYAN}📦 What will be installed:${NC}"
    echo ""
    echo -e "  ${GREEN}✓${NC} ${BOLD}File Manager${NC} - Access files from web browser"
    echo -e "  ${GREEN}✓${NC} ${BOLD}VPN Server${NC} - Secure remote access to your network"
    echo -e "  ${GREEN}✓${NC} ${BOLD}Ad Blocker${NC} - Block ads for all devices on your network"
    echo -e "  ${GREEN}✓${NC} ${BOLD}Docker Manager${NC} - Easy container management interface"
    echo -e "  ${GREEN}✓${NC} ${BOLD}Auto-Updater${NC} - Keeps everything up to date"
    echo ""
}

show_detailed_services() {
    clear
    print_banner
    echo -e "${BOLD}${CYAN}📋 Detailed Service Information${NC}"
    echo ""

    echo -e "${BOLD}� CORE SERVICES:${NC}"
    echo ""
    echo -e "  ${CYAN}📁 Filebrowser${NC} - Web file manager (Port 8080)"
    echo -e "  ${CYAN}🔒 PiVPN${NC} - OpenVPN server (Port 1194/8443)"
    echo -e "  ${CYAN}🛡️ AdGuard Home${NC} - DNS ad blocker (Port 3000/53)"
    echo -e "  ${CYAN}🐳 Portainer${NC} - Docker management (Port 9000)"
    echo -e "  ${CYAN}🔄 Watchtower${NC} - Auto-updater (Background)"
    echo ""

    echo -e "${BOLD}🌐 OPTIONAL SERVICES:${NC}"
    echo ""
    echo -e "  ${YELLOW}🚦 Traefik${NC} - Reverse proxy with auto-SSL"
    echo -e "  ${YELLOW}🔐 Authelia${NC} - 2FA authentication for all services"
    echo -e "  ${YELLOW}☁️ Cloudflare Tunnel${NC} - Secure external access"
    echo -e "  ${YELLOW}📊 Uptime Kuma${NC} - Service monitoring & alerts"
    echo -e "  ${YELLOW}🏠 Heimdall${NC} - Beautiful application dashboard"
    echo ""

    read -p "Press Enter to return to installation options..."
}

# Show installation menu
show_menu() {
    clear
    print_banner

    show_service_overview

    echo -e "${BOLD}${CYAN}🎯 Choose Installation Type:${NC}"
    echo ""

    echo -e "  ${GREEN}1)${NC} ${BOLD}🏠 Local Only${NC}"
    echo -e "     ${CYAN}→${NC} Core services for home network use"
    echo -e "     ${CYAN}→${NC} Access via local IP addresses (192.168.x.x:port)"
    echo -e "     ${CYAN}→${NC} No domain or external setup required"
    echo ""

    echo -e "  ${GREEN}2)${NC} ${BOLD}☁️ Cloudflare Tunnel${NC}"
    echo -e "     ${CYAN}→${NC} Secure external access via Cloudflare"
    echo -e "     ${CYAN}→${NC} Access via custom domains (files.yourdomain.com)"
    echo -e "     ${CYAN}→${NC} Requires: Domain name + Cloudflare account (free)"
    echo ""

    echo -e "  ${GREEN}3)${NC} ${BOLD}🌐 Port Forward${NC}"
    echo -e "     ${CYAN}→${NC} Traditional external access via router"
    echo -e "     ${CYAN}→${NC} Access via custom domains with router setup"
    echo -e "     ${CYAN}→${NC} Requires: Domain name + router configuration"
    echo ""

    echo -e "  ${YELLOW}4)${NC} ${BOLD}ℹ️ Show Detailed Service Info${NC}"
    echo -e "  ${RED}5)${NC} ${BOLD}❌ Exit${NC}"
    echo ""

    while true; do
        read -p "Enter your choice [1-5]: " choice
        case $choice in
            1)
                INSTALL_TYPE="local"
                print_success "Selected: Local Only installation"
                confirm_local_installation
                break
                ;;
            2)
                INSTALL_TYPE="cloudflare"
                print_success "Selected: Cloudflare Tunnel installation"
                explain_cloudflare_requirements
                collect_cloudflare_info
                break
                ;;
            3)
                INSTALL_TYPE="portforward"
                print_success "Selected: Port Forward installation"
                explain_portforward_requirements
                collect_domain_info
                break
                ;;
            4)
                show_detailed_services
                show_menu
                return
                ;;
            5)
                print_status "Installation cancelled"
                exit 0
                ;;
            *)
                print_warning "Invalid option. Please choose 1-5."
                ;;
        esac
    done
}

# Confirm local installation
confirm_local_installation() {
    print_step "Local Installation Confirmation"

    echo -e "${BOLD}You've selected Local Only installation.${NC}"
    echo ""
    echo -e "${GREEN}✅ What will be installed:${NC}"
    echo -e "   • Filebrowser (File management)"
    echo -e "   • PiVPN (VPN server)"
    echo -e "   • AdGuard Home (DNS ad-blocking)"
    echo -e "   • Portainer (Docker management)"
    echo -e "   • Watchtower (Auto-updates)"
    echo ""
    echo -e "${YELLOW}📍 Access URLs after installation:${NC}"
    echo -e "   • Files: http://your-server-ip:8080"
    echo -e "   • VPN Admin: http://your-server-ip:8443"
    echo -e "   • AdGuard: http://your-server-ip:3000"
    echo -e "   • Portainer: http://your-server-ip:9000"
    echo ""
    echo -e "${CYAN}💡 Perfect for:${NC}"
    echo -e "   • Home users who access services locally"
    echo -e "   • Users who don't need external access"
    echo -e "   • Quick setup without domain configuration"
    echo ""

    while true; do
        read -p "Continue with Local Only installation? [y/N]: " confirm
        case $confirm in
            [Yy]*)
                print_success "Proceeding with Local Only installation"
                break
                ;;
            [Nn]*|"")
                print_status "Returning to main menu..."
                show_menu
                return
                ;;
            *)
                print_warning "Please answer yes (y) or no (n)"
                ;;
        esac
    done
}

# Explain Cloudflare requirements
explain_cloudflare_requirements() {
    print_step "Cloudflare Tunnel Requirements"

    echo -e "${BOLD}${CYAN}What you need for Cloudflare Tunnel:${NC}"
    echo ""
    echo -e "${YELLOW}1. Domain Name${NC}"
    echo -e "   • Any domain you own (example.com, mydomain.net, etc.)"
    echo -e "   • Can be from any registrar (GoDaddy, Namecheap, etc.)"
    echo -e "   • Will be used for subdomains (files.yourdomain.com)"
    echo ""
    echo -e "${YELLOW}2. Cloudflare Account${NC}"
    echo -e "   • Free account at cloudflare.com"
    echo -e "   • Add your domain to Cloudflare"
    echo -e "   • Change nameservers to Cloudflare's"
    echo ""
    echo -e "${YELLOW}3. Cloudflare API Token${NC}"
    echo -e "   • Go to Cloudflare Dashboard → My Profile → API Tokens"
    echo -e "   • Create token with Zone:DNS:Edit permissions"
    echo -e "   • Copy the token (starts with letters/numbers)"
    echo ""
    echo -e "${GREEN}✅ Benefits you'll get:${NC}"
    echo -e "   • Access services from anywhere: files.yourdomain.com"
    echo -e "   • Automatic HTTPS certificates"
    echo -e "   • 2FA protection on all services"
    echo -e "   • No port forwarding needed"
    echo -e "   • DDoS protection from Cloudflare"
    echo -e "   • Faster loading via Cloudflare's global network"
    echo ""
    echo -e "${MAGENTA}💰 Cost Savings:${NC}"
    echo -e "   • Replaces AWS (\$5-20/month) → \$0/month"
    echo -e "   • Better than Twingate (limited free tier)"
    echo ""

    while true; do
        read -p "Do you have a domain and Cloudflare account ready? [y/N]: " ready
        case $ready in
            [Yy]*)
                print_success "Great! Let's configure Cloudflare Tunnel"
                break
                ;;
            [Nn]*|"")
                echo ""
                echo -e "${YELLOW}📋 Setup Steps:${NC}"
                echo -e "1. Buy a domain (or use existing one)"
                echo -e "2. Create free Cloudflare account"
                echo -e "3. Add domain to Cloudflare"
                echo -e "4. Update nameservers at your registrar"
                echo -e "5. Create API token in Cloudflare dashboard"
                echo -e "6. Run this installer again"
                echo ""
                print_status "Come back when you're ready!"
                exit 0
                ;;
            *)
                print_warning "Please answer yes (y) or no (n)"
                ;;
        esac
    done
}

# Explain port forward requirements
explain_portforward_requirements() {
    print_step "Port Forward Requirements"

    echo -e "${BOLD}${CYAN}What you need for Port Forward setup:${NC}"
    echo ""
    echo -e "${YELLOW}1. Router Access${NC}"
    echo -e "   • Admin access to your home router"
    echo -e "   • Ability to configure port forwarding"
    echo -e "   • Forward ports 80 and 443 to your server"
    echo ""
    echo -e "${YELLOW}2. Static IP or Dynamic DNS${NC}"
    echo -e "   • Static public IP (best option)"
    echo -e "   • OR dynamic DNS service (DuckDNS, No-IP, etc.)"
    echo -e "   • Domain name (optional but recommended)"
    echo ""
    echo -e "${GREEN}✅ Benefits you'll get:${NC}"
    echo -e "   • Direct access to your server"
    echo -e "   • Full control over traffic routing"
    echo -e "   • HTTPS with automatic certificates"
    echo -e "   • 2FA protection on all services"
    echo ""
    echo -e "${RED}⚠️ Security Considerations:${NC}"
    echo -e "   • Your home IP will be exposed"
    echo -e "   • Need to keep services updated"
    echo -e "   • Consider firewall rules"
    echo ""

    while true; do
        read -p "Do you have router access and understand the requirements? [y/N]: " ready
        case $ready in
            [Yy]*)
                print_success "Great! Let's configure port forwarding setup"
                break
                ;;
            [Nn]*|"")
                echo ""
                echo -e "${YELLOW}📋 Setup Steps:${NC}"
                echo -e "1. Access your router admin panel"
                echo -e "2. Find port forwarding settings"
                echo -e "3. Forward port 80 → your-server-ip:80"
                echo -e "4. Forward port 443 → your-server-ip:443"
                echo -e "5. Set up dynamic DNS if needed"
                echo -e "6. Run this installer again"
                echo ""
                print_status "Come back when you're ready!"
                exit 0
                ;;
            *)
                print_warning "Please answer yes (y) or no (n)"
                ;;
        esac
    done
}

# Input validation functions
validate_domain() {
    local domain="$1"
    if [[ ! "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
        return 1
    fi
    return 0
}

validate_email() {
    local email="$1"
    if [[ ! "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        return 1
    fi
    return 0
}

validate_ip() {
    local ip="$1"
    if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 1
    fi

    # Check each octet is valid (0-255)
    IFS='.' read -ra ADDR <<< "$ip"
    for i in "${ADDR[@]}"; do
        if [[ $i -gt 255 ]]; then
            return 1
        fi
    done
    return 0
}

validate_api_token() {
    local token="$1"
    if [[ ${#token} -lt 20 ]]; then
        return 1
    fi
    return 0
}

# Enhanced input collection with validation
get_validated_input() {
    local prompt="$1"
    local validation_func="$2"
    local error_msg="$3"
    local value=""

    while [[ -z "$value" ]]; do
        read -p "$prompt" value
        if ! $validation_func "$value"; then
            print_warning "$error_msg"
            value=""
        fi
    done
    echo "$value"
}

# Collect Cloudflare information
collect_cloudflare_info() {
    print_step "Cloudflare Configuration"

    echo -e "${BOLD}Let's configure your Cloudflare settings:${NC}"
    echo ""

    # Domain collection with validation and examples
    echo -e "${YELLOW}📍 Step 1: Domain Name${NC}"
    echo -e "Enter the domain you've added to Cloudflare"
    echo -e "${CYAN}Examples:${NC} example.com, mydomain.net, homelab.org"
    echo ""

    while [[ -z "$DOMAIN" ]]; do
        DOMAIN=$(get_validated_input "Your domain name: " validate_domain "Invalid domain format. Please enter just the domain (e.g., example.com)")

        echo -e "${GREEN}✅ Domain: $DOMAIN${NC}"
        echo -e "${CYAN}Your services will be available at:${NC}"
        echo -e "   • files.$DOMAIN"
        echo -e "   • portainer.$DOMAIN"
        echo -e "   • auth.$DOMAIN"
        echo ""
        while true; do
            read -p "Is this correct? [Y/n]: " confirm
            case $confirm in
                [Nn]*)
                    DOMAIN=""
                    break
                    ;;
                [Yy]*|"")
                    break
                    ;;
                *)
                    print_warning "Please answer yes (y) or no (n)"
                    ;;
            esac
        done
    done

    # Email collection
    echo -e "${YELLOW}📍 Step 2: Cloudflare Email${NC}"
    echo -e "Enter the email address you use to log into Cloudflare"
    echo ""

    CF_EMAIL=$(get_validated_input "Cloudflare email: " validate_email "Invalid email format. Please try again.")
    echo -e "${GREEN}✅ Email: $CF_EMAIL${NC}"

    # API Token collection with detailed instructions
    echo -e "${YELLOW}📍 Step 3: Cloudflare API Token${NC}"
    echo -e "This token allows SkyLab to manage DNS records for your domain"
    echo ""
    echo -e "${CYAN}How to get your API token:${NC}"
    echo -e "1. Go to: https://dash.cloudflare.com/profile/api-tokens"
    echo -e "2. Click 'Create Token'"
    echo -e "3. Use 'Custom token' template"
    echo -e "4. Set permissions:"
    echo -e "   • Zone:Zone:Read"
    echo -e "   • Zone:DNS:Edit"
    echo -e "5. Zone Resources: Include - All zones"
    echo -e "6. Click 'Continue to summary' → 'Create Token'"
    echo -e "7. Copy the token (it starts with letters and numbers)"
    echo ""
    echo -e "${RED}⚠️ Keep this token secure - it has access to your DNS!${NC}"
    echo ""

    while [[ -z "$CF_API_KEY" ]]; do
        read -s -p "Paste your Cloudflare API token: " CF_API_KEY
        echo ""
        if [[ ${#CF_API_KEY} -lt 20 ]]; then
            print_warning "API token seems too short. Please check and try again."
            print_status "Token should be 40+ characters long"
            CF_API_KEY=""
        else
            echo -e "${GREEN}✅ API token received (${#CF_API_KEY} characters)${NC}"

            # Test the token
            print_status "Testing API token..."
            local test_result=$(curl -s -H "Authorization: Bearer $CF_API_KEY" \
                "https://api.cloudflare.com/client/v4/user/tokens/verify" | \
                grep -o '"success":[^,]*' | cut -d':' -f2)

            if [[ "$test_result" == "true" ]]; then
                print_success "API token is valid!"
            else
                print_warning "API token test failed, but continuing anyway"
                print_status "You can fix this later if needed"
            fi
        fi
    done

    echo ""
    print_success "Cloudflare configuration completed!"
    echo -e "${CYAN}Summary:${NC}"
    echo -e "   • Domain: $DOMAIN"
    echo -e "   • Email: $CF_EMAIL"
    echo -e "   • API Token: ✅ Configured"
}

# Collect domain information for port forward setup
collect_domain_info() {
    print_step "Domain Configuration"
    
    read -p "Enter your domain name (optional, press Enter to skip): " DOMAIN
    if [[ -n "$DOMAIN" && ! "$DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
        print_warning "Invalid domain format. Continuing without domain."
        DOMAIN=""
    fi
}

# Install system dependencies
install_dependencies() {
    print_step "Installing System Dependencies"

    echo -e "${CYAN}Installing essential tools for SkyLab:${NC}"
    echo -e "   • curl & wget - Download files and communicate with APIs"
    echo -e "   • git - Version control (for future updates)"
    echo -e "   • unzip - Extract downloaded packages"
    echo -e "   • jq - Process JSON data from APIs"
    echo -e "   • openssl - Generate security certificates and keys"
    echo ""

    print_status "Updating package manager..."
    sudo $UPDATE_CMD >/dev/null 2>&1

    local packages="curl wget git unzip jq openssl"

    print_status "Installing required packages..."
    sudo $INSTALL_CMD $packages >/dev/null 2>&1

    print_success "System dependencies installed"
}

# Install Docker
install_docker() {
    print_step "Installing Docker"

    echo -e "${CYAN}Docker is the foundation of SkyLab:${NC}"
    echo -e "   • Containers - Isolated environments for each service"
    echo -e "   • Images - Pre-built software packages"
    echo -e "   • Networks - Secure communication between services"
    echo -e "   • Volumes - Persistent data storage"
    echo ""

    if command -v docker >/dev/null 2>&1; then
        print_status "Docker already installed"
        local docker_version=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
        print_success "Docker version: $docker_version"
        return
    fi

    print_status "Downloading Docker installation script..."

    # Download with progress bar
    if curl --progress-bar -fsSL https://get.docker.com -o /tmp/get-docker.sh; then
        print_success "Docker script downloaded"
    else
        print_error "Failed to download Docker installation script"
        exit 1
    fi

    print_status "Installing Docker (this may take 2-5 minutes)..."
    print_status "Please wait while Docker is being installed..."

    # Run installation with some progress feedback
    {
        timeout 300 sh /tmp/get-docker.sh 2>&1 | while IFS= read -r line; do
            case "$line" in
                *"Downloading"*|*"Installing"*|*"Configuring"*|*"Starting"*)
                    print_status "$(echo "$line" | sed 's/^[[:space:]]*//')"
                    ;;
                *"ERROR"*|*"FATAL"*)
                    print_error "$(echo "$line" | sed 's/^[[:space:]]*//')"
                    ;;
            esac
        done
        echo "DOCKER_INSTALL_COMPLETE"
    } &

    # Show a simple progress indicator while Docker installs
    local pid=$!
    local spin='-\|/'
    local i=0
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r   ${BLUE}ℹ${NC}  Installing Docker... ${spin:$i:1}"
        sleep 0.5
    done
    printf "\r   ${BLUE}ℹ${NC}  Installing Docker... ✓\n"

    wait $pid
    rm -f /tmp/get-docker.sh

    print_status "Configuring Docker permissions..."
    print_status "Adding your user to the docker group for non-root access"
    sudo usermod -aG docker $USER

    print_status "Starting Docker service..."
    sudo systemctl enable docker >/dev/null 2>&1
    sudo systemctl start docker >/dev/null 2>&1

    # Verify Docker installation
    if docker --version >/dev/null 2>&1; then
        local docker_version=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
        print_success "Docker installed successfully (version: $docker_version)"
    else
        print_error "Docker installation failed"
        exit 1
    fi

    print_warning "Note: You may need to log out and back in for Docker permissions to take effect"
    print_status "For now, we'll use sudo for Docker commands during installation"
}

# Install Docker Compose
install_docker_compose() {
    print_step "Installing Docker Compose"

    echo -e "${CYAN}Docker Compose orchestrates multiple containers:${NC}"
    echo -e "   • Defines all SkyLab services in one file"
    echo -e "   • Manages service dependencies and startup order"
    echo -e "   • Creates networks for secure service communication"
    echo -e "   • Handles volume mounting for data persistence"
    echo ""

    if command -v docker-compose >/dev/null 2>&1; then
        local compose_version=$(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)
        print_status "Docker Compose already installed (version: $compose_version)"
        return
    fi

    print_status "Getting latest Docker Compose version..."
    local compose_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
    print_status "Installing Docker Compose $compose_version..."

    # Download with progress bar
    local compose_url="https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-$(uname -s)-$(uname -m)"
    print_status "Downloading Docker Compose binary..."

    if sudo curl -L --progress-bar "$compose_url" -o /usr/local/bin/docker-compose; then
        print_success "Docker Compose downloaded successfully"
    else
        print_error "Failed to download Docker Compose"
        exit 1
    fi

    print_status "Setting executable permissions..."
    sudo chmod +x /usr/local/bin/docker-compose

    # Verify installation
    if docker-compose --version >/dev/null 2>&1; then
        local installed_version=$(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)
        print_success "Docker Compose installed successfully (version: $installed_version)"
    else
        print_error "Docker Compose installation failed"
        exit 1
    fi
}

# Create directory structure
create_directories() {
    print_step "Creating Directory Structure"

    echo -e "${CYAN}Setting up SkyLab directory structure:${NC}"
    echo -e "   • $INSTALL_DIR - Main installation files"
    echo -e "   • $DATA_DIR/appdata - Service configuration and data"
    echo -e "   • Organized folders for each service"
    echo ""

    print_status "Creating installation directory at $INSTALL_DIR..."
    sudo mkdir -p "$INSTALL_DIR"
    sudo chown $USER:$USER "$INSTALL_DIR"

    print_status "Creating data directories at $DATA_DIR..."
    sudo mkdir -p "$DATA_DIR/appdata"
    sudo chown -R $USER:$USER "$DATA_DIR"

    # Create specific app directories
    print_status "Creating service directories..."
    local app_dirs=(
        "filebrowser/config"
        "filebrowser/data"
        "portainer"
        "adguard"
        "watchtower"
        "uptime-kuma"
        "heimdall/config"
        "nginx-proxy-manager/data"
        "nginx-proxy-manager/letsencrypt"
    )

    if [[ "$INSTALL_TYPE" == "cloudflare" || "$INSTALL_TYPE" == "portforward" ]]; then
        app_dirs+=(
            "traefik"
            "authelia"
        )
        print_status "Adding advanced service directories (Traefik, Authelia)..."
    fi

    for dir in "${app_dirs[@]}"; do
        if ! mkdir -p "$DATA_DIR/appdata/$dir"; then
            print_error "Failed to create directory: $DATA_DIR/appdata/$dir"
            print_status "Check permissions and available disk space"
            exit 1
        fi
        echo -e "   ${GREEN}✓${NC} Created: $DATA_DIR/appdata/$dir"
    done

    # Verify directory structure
    print_status "Verifying directory permissions..."
    if [[ ! -w "$DATA_DIR/appdata" ]]; then
        print_error "Data directory is not writable: $DATA_DIR/appdata"
        print_status "Attempting to fix permissions..."
        if ! sudo chown -R $USER:$USER "$DATA_DIR/appdata"; then
            print_error "Failed to fix directory permissions"
            exit 1
        fi
        print_success "Directory permissions fixed"
    fi

    print_success "Directory structure created successfully"
    print_status "All service data will be stored in $DATA_DIR/appdata"
}

# Generate secrets
generate_secrets() {
    print_step "Generating Security Secrets"

    echo -e "${CYAN}Creating cryptographic secrets for security:${NC}"
    echo -e "   • JWT Secret - Secures authentication tokens"
    echo -e "   • Session Secret - Protects user sessions"
    echo -e "   • Encryption Key - Encrypts stored data"
    echo ""

    print_status "Generating JWT secret (64 characters)..."
    JWT_SECRET=$(openssl rand -hex 32)

    print_status "Generating session secret (64 characters)..."
    SESSION_SECRET=$(openssl rand -hex 32)

    print_status "Generating encryption key (32 characters)..."
    ENCRYPTION_KEY=$(openssl rand -hex 16)

    print_success "Security secrets generated successfully"
    print_status "These secrets will be stored securely in your .env file"
}

# Auto-detect server IP
detect_server_ip() {
    print_status "Auto-detecting server IP address..."

    # Try multiple methods to get the local IP
    local server_ip=""

    # Method 1: Try to get local network IP (most common for home labs)
    if command -v ip >/dev/null 2>&1; then
        server_ip=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' | head -1)
    fi

    # Method 2: Use hostname -I as fallback
    if [[ -z "$server_ip" ]]; then
        server_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi

    # Method 3: Parse ip addr output
    if [[ -z "$server_ip" ]]; then
        server_ip=$(ip addr show 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' | cut -d'/' -f1)
    fi

    # Method 4: Use ifconfig if available
    if [[ -z "$server_ip" ]] && command -v ifconfig >/dev/null 2>&1; then
        server_ip=$(ifconfig 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}')
    fi

    # Method 5: Last resort - use localhost
    if [[ -z "$server_ip" ]]; then
        server_ip="127.0.0.1"
        print_warning "Could not detect IP address, using localhost (127.0.0.1)"
    fi

    # Validate IP format
    if [[ $server_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        print_success "Detected server IP: $server_ip"

        # Check if it's a private IP (typical for home labs)
        if [[ $server_ip =~ ^192\.168\. ]] || [[ $server_ip =~ ^10\. ]] || [[ $server_ip =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]]; then
            print_status "Detected private IP address (perfect for home lab)"
            print_status "Services will be accessible from devices on your local network"
        elif [[ $server_ip == "127.0.0.1" ]]; then
            print_warning "Using localhost - services will only be accessible from this machine"
            print_status "Consider using your network IP for access from other devices"
        else
            print_status "Detected public IP address"
            print_warning "Ensure firewall is properly configured for security"
        fi
    else
        print_warning "Invalid IP format detected: $server_ip, using 127.0.0.1"
        server_ip="127.0.0.1"
    fi

    SERVER_IP="$server_ip"

    # Ask user to confirm the detected IP
    echo ""
    echo -e "${BOLD}${YELLOW}Please confirm your server IP address:${NC}"
    echo -e "Detected IP: ${CYAN}$SERVER_IP${NC}"
    echo ""
    echo -e "${CYAN}This IP will be used for:${NC}"
    echo -e "   • Service access URLs"
    echo -e "   • AdGuard Home DNS configuration"
    echo -e "   • VPN server configuration"
    echo ""

    while true; do
        read -p "Is this IP address correct? [Y/n]: " confirm
        case $confirm in
            [Nn]*)
                echo ""
                read -p "Enter the correct IP address: " custom_ip
                if [[ $custom_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                    SERVER_IP="$custom_ip"
                    print_success "Using custom IP: $SERVER_IP"
                    break
                else
                    print_warning "Invalid IP format. Please try again."
                fi
                ;;
            [Yy]*|"")
                print_success "Using detected IP: $SERVER_IP"
                break
                ;;
            *)
                print_warning "Please answer yes (y) or no (n)"
                ;;
        esac
    done
}

# Create environment file
create_env_file() {
    print_step "Creating Environment Configuration"

    # Auto-detect server IP
    detect_server_ip

    echo -e "${CYAN}Environment configuration:${NC}"
    echo -e "   • Server IP: ${YELLOW}$SERVER_IP${NC}"
    echo -e "   • Timezone: ${YELLOW}$(timedatectl show --property=Timezone --value 2>/dev/null || echo "UTC")${NC}"
    echo -e "   • User ID: ${YELLOW}$(id -u)${NC}"
    echo -e "   • Group ID: ${YELLOW}$(id -g)${NC}"
    echo ""

    cat > "$INSTALL_DIR/.env" << EOF
# SkyLab Environment Configuration
# Generated on $(date)

# System Configuration
TZ=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "UTC")
PUID=$(id -u)
PGID=$(id -g)

# Server Configuration
SERVER_IP=${SERVER_IP}

# Data Directory
DATA_DIR=${DATA_DIR}

# Service Ports
FILEBROWSER_PORT=8080
PORTAINER_HTTP_PORT=9000
PORTAINER_HTTPS_PORT=9443
ADGUARD_PORT=3000
UPTIME_KUMA_PORT=3001
HEIMDALL_PORT=8090

EOF

    if [[ "$INSTALL_TYPE" == "cloudflare" ]]; then
        cat >> "$INSTALL_DIR/.env" << EOF
# Domain Configuration
DOMAIN=${DOMAIN}

# Cloudflare Configuration
CF_API_EMAIL=${CF_EMAIL}
CF_API_KEY=${CF_API_KEY}
TUNNEL_TOKEN=

# Authelia Configuration
AUTHELIA_JWT_SECRET=${JWT_SECRET}
AUTHELIA_SESSION_SECRET=${SESSION_SECRET}
AUTHELIA_STORAGE_ENCRYPTION_KEY=${ENCRYPTION_KEY}

EOF
    elif [[ "$INSTALL_TYPE" == "portforward" && -n "$DOMAIN" ]]; then
        cat >> "$INSTALL_DIR/.env" << EOF
# Domain Configuration
DOMAIN=${DOMAIN}

# Authelia Configuration
AUTHELIA_JWT_SECRET=${JWT_SECRET}
AUTHELIA_SESSION_SECRET=${SESSION_SECRET}
AUTHELIA_STORAGE_ENCRYPTION_KEY=${ENCRYPTION_KEY}

EOF
    fi

    print_success "Environment file created at $INSTALL_DIR/.env"
}

# Create docker-compose file
create_docker_compose() {
    print_step "Creating Docker Compose Configuration"

    cat > "$INSTALL_DIR/docker-compose.yml" << 'EOF'

networks:
  skylab:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

services:
  # Filebrowser - Web-based file management
  filebrowser:
    image: filebrowser/filebrowser:latest
    container_name: filebrowser
    restart: unless-stopped
    ports:
      - "${FILEBROWSER_PORT:-8080}:80"
    volumes:
      - ${DATA_DIR}/appdata/filebrowser/config:/config
      - ${DATA_DIR}:/srv
      - /:/mnt/host:ro
    environment:
      - PUID=${PUID:-1000}
      - PGID=${PGID:-1000}
      - TZ=${TZ:-UTC}
    networks:
      - skylab
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.filebrowser.rule=Host('files.${DOMAIN:-localhost}')"
      - "traefik.http.routers.filebrowser.middlewares=authelia@docker"
      - "traefik.http.services.filebrowser.loadbalancer.server.port=80"

  # PiVPN - OpenVPN server
  pivpn:
    image: innovativeinventor/docker-pivpn:latest
    container_name: pivpn
    restart: unless-stopped
    ports:
      - "1194:1194/udp"
      - "8443:8080"
    volumes:
      - ${DATA_DIR}/appdata/pivpn:/vpn
    environment:
      - TZ=${TZ:-UTC}
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun
    networks:
      - skylab
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.pivpn.rule=Host('vpn.${DOMAIN:-localhost}')"
      - "traefik.http.routers.pivpn.middlewares=authelia@docker"
      - "traefik.http.services.pivpn.loadbalancer.server.port=8080"

  # Portainer - Docker management UI
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    ports:
      - "${PORTAINER_HTTP_PORT:-9000}:9000"
      - "${PORTAINER_HTTPS_PORT:-9443}:9443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ${DATA_DIR}/appdata/portainer:/data
    networks:
      - skylab
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.portainer.rule=Host('portainer.${DOMAIN:-localhost}')"
      - "traefik.http.routers.portainer.middlewares=authelia@docker"
      - "traefik.http.services.portainer.loadbalancer.server.port=9000"

  # AdGuard Home - DNS Ad Blocker (Dockerized)
  adguard:
    image: adguard/adguardhome:latest
    container_name: adguard
    restart: unless-stopped
    ports:
      - "${ADGUARD_PORT:-3000}:3000"
      - "53:53/tcp"
      - "53:53/udp"
    volumes:
      - ${DATA_DIR}/appdata/adguard/work:/opt/adguardhome/work
      - ${DATA_DIR}/appdata/adguard/conf:/opt/adguardhome/conf
    environment:
      - TZ=${TZ:-UTC}
    networks:
      - skylab
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.adguard.rule=Host('dns.${DOMAIN:-localhost}')"
      - "traefik.http.routers.adguard.middlewares=authelia@docker"
      - "traefik.http.services.adguard.loadbalancer.server.port=3000"

  # Watchtower - Automatic container updates
  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - TZ=${TZ:-UTC}
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_SCHEDULE=0 0 4 * * *
    networks:
      - skylab

  # Nginx Proxy Manager - Traditional reverse proxy (optional)
  nginx-proxy-manager:
    image: jc21/nginx-proxy-manager:latest
    container_name: nginx-proxy-manager
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "81:81"
    volumes:
      - ${DATA_DIR}/appdata/nginx-proxy-manager/data:/data
      - ${DATA_DIR}/appdata/nginx-proxy-manager/letsencrypt:/etc/letsencrypt
    networks:
      - skylab
    profiles:
      - npm  # Only start with --profile npm

  # Uptime Kuma - Service monitoring (optional)
  uptime-kuma:
    image: louislam/uptime-kuma:latest
    container_name: uptime-kuma
    restart: unless-stopped
    ports:
      - "${UPTIME_KUMA_PORT:-3001}:3001"
    volumes:
      - ${DATA_DIR}/appdata/uptime-kuma:/app/data
    networks:
      - skylab
    profiles:
      - monitoring
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.uptime.rule=Host('status.${DOMAIN:-localhost}')"
      - "traefik.http.routers.uptime.middlewares=authelia@docker"
      - "traefik.http.services.uptime.loadbalancer.server.port=3001"

  # Heimdall - Application dashboard (optional)
  heimdall:
    image: lscr.io/linuxserver/heimdall:latest
    container_name: heimdall
    restart: unless-stopped
    ports:
      - "${HEIMDALL_PORT:-8090}:80"
    environment:
      - PUID=${PUID:-1000}
      - PGID=${PGID:-1000}
      - TZ=${TZ:-UTC}
    volumes:
      - ${DATA_DIR}/appdata/heimdall/config:/config
    networks:
      - skylab
    profiles:
      - dashboard
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.heimdall.rule=Host('dashboard.${DOMAIN:-localhost}')"
      - "traefik.http.routers.heimdall.middlewares=authelia@docker"
      - "traefik.http.services.heimdall.loadbalancer.server.port=80"
EOF

    # Add Traefik and Authelia for advanced setups
    if [[ "$INSTALL_TYPE" == "cloudflare" || "$INSTALL_TYPE" == "portforward" ]]; then
        cat >> "$INSTALL_DIR/docker-compose.yml" << 'EOF'

  # Traefik - Modern reverse proxy
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "8081:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ${DATA_DIR}/appdata/traefik:/etc/traefik
      - ${DATA_DIR}/appdata/traefik/acme:/acme
    environment:
      - CF_API_EMAIL=${CF_API_EMAIL}
      - CF_API_KEY=${CF_API_KEY}
    networks:
      - skylab
    profiles:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.rule=Host('traefik.${DOMAIN:-localhost}')"
      - "traefik.http.routers.traefik.middlewares=authelia@docker"
      - "traefik.http.routers.traefik.service=api@internal"

  # Authelia - Authentication server
  authelia:
    image: authelia/authelia:latest
    container_name: authelia
    restart: unless-stopped
    volumes:
      - ${DATA_DIR}/appdata/authelia:/config
    environment:
      - TZ=${TZ:-UTC}
    networks:
      - skylab
    profiles:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.authelia.rule=Host('auth.${DOMAIN:-localhost}')"
      - "traefik.http.services.authelia.loadbalancer.server.port=9091"
      - "traefik.http.middlewares.authelia.forwardauth.address=http://authelia:9091/api/verify?rd=https://auth.${DOMAIN:-localhost}"
      - "traefik.http.middlewares.authelia.forwardauth.trustForwardHeader=true"
      - "traefik.http.middlewares.authelia.forwardauth.authResponseHeaders=Remote-User,Remote-Groups,Remote-Name,Remote-Email"
EOF
    fi

    # Add Cloudflare tunnel for cloudflare setup
    if [[ "$INSTALL_TYPE" == "cloudflare" ]]; then
        cat >> "$INSTALL_DIR/docker-compose.yml" << 'EOF'

  # Cloudflare Tunnel
  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    restart: unless-stopped
    command: tunnel --no-autoupdate run --token ${TUNNEL_TOKEN}
    environment:
      - TUNNEL_TOKEN=${TUNNEL_TOKEN}
    networks:
      - skylab
    profiles:
      - proxy
    depends_on:
      - traefik
EOF
    fi

    print_success "Docker Compose configuration created"
}

# Create Traefik configuration
create_traefik_config() {
    if [[ "$INSTALL_TYPE" != "cloudflare" && "$INSTALL_TYPE" != "portforward" ]]; then
        return
    fi

    print_step "Creating Traefik Configuration"

    mkdir -p "$DATA_DIR/appdata/traefik"

    # Main Traefik configuration
    cat > "$DATA_DIR/appdata/traefik/traefik.yml" << EOF
# Traefik Configuration for SkyLab
global:
  checkNewVersion: false
  sendAnonymousUsage: false

api:
  dashboard: true
  debug: false

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entrypoint:
          to: websecure
          scheme: https
          permanent: true
  websecure:
    address: ":443"

certificatesResolvers:
  cloudflare:
    acme:
      email: ${CF_EMAIL:-admin@example.com}
      storage: /acme/acme.json
      dnsChallenge:
        provider: cloudflare
        resolvers:
          - "1.1.1.1:53"
          - "1.0.0.1:53"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: skylab_skylab
  file:
    filename: /etc/traefik/dynamic.yml
    watch: true

log:
  level: INFO

accessLog: {}

metrics:
  prometheus:
    addEntryPointsLabels: true
    addServicesLabels: true
EOF

    # Dynamic configuration
    cat > "$DATA_DIR/appdata/traefik/dynamic.yml" << 'EOF'
# Traefik Dynamic Configuration
http:
  middlewares:
    secure-headers:
      headers:
        accessControlAllowMethods:
          - GET
          - OPTIONS
          - PUT
        accessControlMaxAge: 100
        hostsProxyHeaders:
          - "X-Forwarded-Host"
        referrerPolicy: "same-origin"
        sslRedirect: true
        stsSeconds: 31536000
        stsIncludeSubdomains: true
        stsPreload: true
        forceSTSHeader: true
        frameDeny: true
        contentTypeNosniff: true
        browserXssFilter: true

    rate-limit:
      rateLimit:
        average: 100
        burst: 50

    default:
      chain:
        middlewares:
          - secure-headers
          - rate-limit

tls:
  options:
    default:
      sslStrategies:
        - "tls.SniStrict"
      minVersion: "VersionTLS12"
      cipherSuites:
        - "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
        - "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305"
        - "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
        - "TLS_RSA_WITH_AES_256_GCM_SHA384"
        - "TLS_RSA_WITH_AES_128_GCM_SHA256"
EOF

    # Create acme directory and file with correct permissions
    print_status "Creating ACME directory for SSL certificates..."

    # Ensure parent directory exists with proper permissions
    if ! mkdir -p "$DATA_DIR/appdata/traefik"; then
        print_error "Failed to create traefik directory"
        print_status "Check permissions for $DATA_DIR/appdata/"
        exit 1
    fi

    # Create acme subdirectory
    if ! mkdir -p "$DATA_DIR/appdata/traefik/acme"; then
        print_error "Failed to create acme directory"
        print_status "Check permissions for $DATA_DIR/appdata/traefik/"
        exit 1
    fi

    # Create acme.json file
    if ! touch "$DATA_DIR/appdata/traefik/acme/acme.json"; then
        print_error "Failed to create acme.json file"
        print_status "Check permissions for $DATA_DIR/appdata/traefik/acme/"
        exit 1
    fi

    # Set secure permissions for acme.json
    if ! chmod 600 "$DATA_DIR/appdata/traefik/acme/acme.json"; then
        print_error "Failed to set permissions on acme.json"
        exit 1
    fi

    print_success "ACME directory and file created successfully"
    print_success "Traefik configuration created"
}

# Create Authelia configuration
create_authelia_config() {
    if [[ "$INSTALL_TYPE" != "cloudflare" && "$INSTALL_TYPE" != "portforward" ]]; then
        return
    fi

    print_step "Creating Authelia Configuration"

    mkdir -p "$DATA_DIR/appdata/authelia"

    # Main Authelia configuration
    cat > "$DATA_DIR/appdata/authelia/configuration.yml" << EOF
# Authelia Configuration for SkyLab
server:
  host: 0.0.0.0
  port: 9091
  path: ""
  read_buffer_size: 4096
  write_buffer_size: 4096

log:
  level: info
  format: text

jwt_secret: ${JWT_SECRET}
default_redirection_url: https://auth.${DOMAIN:-localhost}

totp:
  issuer: SkyLab
  period: 30
  skew: 1

authentication_backend:
  file:
    path: /config/users_database.yml
    password:
      algorithm: argon2id
      iterations: 1
      salt_length: 16
      parallelism: 8
      memory: 64

access_control:
  default_policy: deny
  rules:
    - domain: traefik.${DOMAIN:-localhost}
      policy: two_factor
    - domain: portainer.${DOMAIN:-localhost}
      policy: two_factor
    - domain: files.${DOMAIN:-localhost}
      policy: one_factor
    - domain: status.${DOMAIN:-localhost}
      policy: two_factor
    - domain: dashboard.${DOMAIN:-localhost}
      policy: one_factor
    - domain: vpn.${DOMAIN:-localhost}
      policy: two_factor

session:
  name: authelia_session
  secret: ${SESSION_SECRET}
  expiration: 3600
  inactivity: 300
  domain: ${DOMAIN:-localhost}

regulation:
  max_retries: 3
  find_time: 120
  ban_time: 300

storage:
  local:
    path: /config/db.sqlite3
  encryption_key: ${ENCRYPTION_KEY}

notifier:
  filesystem:
    filename: /config/notification.txt
EOF

    # Create users database with default admin user
    local admin_password_hash='$argon2id$v=19$m=65536,t=3,p=4$BpLnfgDsc2WD8F2q$o/vzA4myCqZZ36bUGsDY//8mKUYNZZaR0t4MFFSs+iM'

    cat > "$DATA_DIR/appdata/authelia/users_database.yml" << EOF
# Authelia Users Database
users:
  admin:
    displayname: "Administrator"
    password: "${admin_password_hash}"  # Password: admin123
    email: admin@${DOMAIN:-skylab.local}
    groups:
      - admins
      - dev

groups:
  admins:
    - admin
  users: []
EOF

    print_success "Authelia configuration created"
    print_warning "Default admin password is 'admin123' - change this after first login!"
}

# Install and configure Cloudflare tunnel
setup_cloudflare_tunnel() {
    if [[ "$INSTALL_TYPE" != "cloudflare" ]]; then
        return
    fi

    print_step "Setting up Cloudflare Tunnel"

    # Install cloudflared
    if ! command -v cloudflared >/dev/null 2>&1; then
        print_status "Installing cloudflared..."
        wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.deb"
        sudo dpkg -i "cloudflared-linux-${ARCH}.deb" >/dev/null 2>&1
        rm "cloudflared-linux-${ARCH}.deb"
    fi

    print_status "Authenticating with Cloudflare..."
    print_warning "This will open a browser window. Please log in to Cloudflare and authorize the tunnel."

    # Authenticate
    cloudflared tunnel login

    # Create tunnel
    local tunnel_name="skylab-tunnel"
    print_status "Creating tunnel: $tunnel_name"

    local tunnel_id
    if cloudflared tunnel list | grep -q "$tunnel_name"; then
        print_warning "Tunnel $tunnel_name already exists"
        tunnel_id=$(cloudflared tunnel list | grep "$tunnel_name" | awk '{print $1}')
    else
        tunnel_id=$(cloudflared tunnel create "$tunnel_name" | grep -o '[a-f0-9-]\{36\}')
        print_success "Tunnel created with ID: $tunnel_id"
    fi

    # Create tunnel configuration
    print_status "Creating tunnel configuration..."
    mkdir -p ~/.cloudflared

    # Validate variables before creating config
    if [[ -z "$tunnel_id" ]]; then
        print_error "Tunnel ID is empty"
        exit 1
    fi

    if [[ -z "$DOMAIN" ]]; then
        print_error "Domain is empty"
        exit 1
    fi

    print_status "Creating tunnel config with ID: $tunnel_id and domain: $DOMAIN"

    cat > ~/.cloudflared/config.yml << EOF
tunnel: $tunnel_id
credentials-file: ~/.cloudflared/$tunnel_id.json

ingress:
  - hostname: "*.$DOMAIN"
    service: http://localhost:80
  - service: http_status:404
EOF

    # Verify the config file was created correctly
    if [[ ! -f ~/.cloudflared/config.yml ]]; then
        print_error "Failed to create tunnel configuration file"
        exit 1
    fi

    # Validate YAML syntax
    if ! cloudflared tunnel ingress validate ~/.cloudflared/config.yml 2>/dev/null; then
        print_error "Invalid tunnel configuration generated"
        print_status "Config file contents:"
        cat ~/.cloudflared/config.yml
        exit 1
    fi

    # Get tunnel token and update .env
    print_status "Generating tunnel token..."
    local tunnel_token=$(cloudflared tunnel token "$tunnel_name" 2>/dev/null)

    if [[ -z "$tunnel_token" ]]; then
        print_error "Failed to generate tunnel token"
        print_status "Trying alternative method..."
        tunnel_token=$(cloudflared tunnel token "$tunnel_id" 2>/dev/null)
    fi

    if [[ -z "$tunnel_token" ]]; then
        print_error "Could not generate tunnel token"
        print_status "You may need to manually configure the tunnel"
        print_status "Tunnel ID: $tunnel_id"
    else
        print_success "Tunnel token generated successfully"
        sed -i "s/TUNNEL_TOKEN=.*/TUNNEL_TOKEN=$tunnel_token/" "$INSTALL_DIR/.env"
    fi

    print_success "Cloudflare Tunnel setup completed!"
    print_warning "Don't forget to add DNS records in Cloudflare dashboard:"
    print_status "Type: CNAME, Name: *, Target: $tunnel_id.cfargotunnel.com"
}

# Resolve DNS port conflicts
resolve_dns_conflicts() {
    print_step "Resolving DNS Port Conflicts"

    echo -e "${CYAN}AdGuard Home requires port 53 for DNS service:${NC}"
    echo -e "   • Standard DNS port that all devices expect"
    echo -e "   • Required for router and device DNS configuration"
    echo -e "   • Cannot use alternative ports for real-world DNS"
    echo ""

    # Check for conflicting services
    local conflicting_services=()

    # Check systemd-resolved
    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        conflicting_services+=("systemd-resolved")
    fi

    # Check dnsmasq
    if systemctl is-active --quiet dnsmasq 2>/dev/null; then
        conflicting_services+=("dnsmasq")
    fi

    # Check if port 53 is in use
    if netstat -tulpn 2>/dev/null | grep -q ":53 " || ss -tulpn 2>/dev/null | grep -q ":53 "; then
        print_warning "Port 53 is currently in use by system DNS service"
    fi

    if [[ ${#conflicting_services[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠️ Found conflicting DNS services:${NC}"
        for service in "${conflicting_services[@]}"; do
            echo -e "   • $service"
        done
        echo ""
        echo -e "${BOLD}These services must be stopped for AdGuard to work properly.${NC}"
        echo ""

        while true; do
            read -p "Stop conflicting DNS services automatically? [Y/n]: " confirm
            case $confirm in
                [Nn]*)
                    print_warning "DNS conflicts not resolved - AdGuard may fail to start"
                    print_status "You can manually stop services later with:"
                    for service in "${conflicting_services[@]}"; do
                        echo -e "   sudo systemctl stop $service"
                        echo -e "   sudo systemctl disable $service"
                    done
                    break
                    ;;
                [Yy]*|"")
                    print_status "Stopping conflicting DNS services..."
                    for service in "${conflicting_services[@]}"; do
                        print_status "Stopping $service..."
                        sudo systemctl stop "$service" >/dev/null 2>&1
                        sudo systemctl disable "$service" >/dev/null 2>&1
                        echo -e "   ${GREEN}✓${NC} Stopped $service"
                    done
                    print_success "DNS conflicts resolved"

                    # Temporarily restore DNS resolution for Docker operations
                    print_status "Configuring temporary DNS resolution..."
                    echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf >/dev/null
                    echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf >/dev/null
                    print_success "Temporary DNS configured for Docker operations"

                    break
                    ;;
                *)
                    print_warning "Please answer yes (y) or no (n)"
                    ;;
            esac
        done
    else
        print_success "No DNS conflicts detected - port 53 is available"
    fi
}

# Prepare AdGuard Home configuration
prepare_adguard_config() {
    print_step "Preparing AdGuard Home Configuration"

    print_status "Creating AdGuard Home configuration directory..."
    mkdir -p "$DATA_DIR/appdata/adguard/work"
    mkdir -p "$DATA_DIR/appdata/adguard/conf"

    # Create basic AdGuard Home configuration
    cat > "$DATA_DIR/appdata/adguard/conf/AdGuardHome.yaml" << EOF
# AdGuard Home Configuration
bind_host: 0.0.0.0
bind_port: 3000
users:
  - name: admin
    password: \$2a\$10\$iyodZLWqzE5DZmdSuhb9YOczW5TgdRLHbPTvmQonLlcHEpr5bq7Ga  # admin123
web_session_ttl: 720h
dns:
  bind_hosts:
    - 0.0.0.0
  port: 53
  statistics_interval: 24h
  querylog_enabled: true
  querylog_file_enabled: true
  querylog_interval: 2160h
  querylog_size_memory: 1000
  anonymize_client_ip: false
  protection_enabled: true
  blocking_mode: default
  blocked_response_ttl: 10
  parental_block_host: family-block.dns.adguard.com
  safebrowsing_block_host: standard-block.dns.adguard.com
  rewrites: []
  blocked_services: []
  upstream_dns:
    - 8.8.8.8
    - 8.8.4.4
    - 1.1.1.1
    - 1.0.0.1
  upstream_dns_file: ""
  bootstrap_dns:
    - 9.9.9.10
    - 149.112.112.10
    - 2620:fe::10
    - 2620:fe::fe:10
  all_servers: false
  fastest_addr: false
  fastest_timeout: 1s
  allowed_clients: []
  disallowed_clients: []
  blocked_hosts:
    - version.bind
    - id.server
    - hostname.bind
  cache_size: 4194304
  cache_ttl_min: 0
  cache_ttl_max: 0
  cache_optimistic: false
  bogus_nxdomain: []
  aaaa_disabled: false
  enable_dnssec: false
  edns_client_subnet:
    custom_ip: ""
    enabled: false
    use_custom: false
  max_goroutines: 300
  handle_ddr: true
  ipset: []
  ipset_file: ""
  filtering:
    protection_enabled: true
    filtering_enabled: true
    blocked_response_ttl: 10
    parental_enabled: false
    safebrowsing_enabled: false
    safesearch_enabled: false
    safesearch_cache_size: 1048576
    safesearch_cache_ttl: 1800
    rewrites: []
    blocked_services: []
    parental_block_host: family-block.dns.adguard.com
    safebrowsing_block_host: standard-block.dns.adguard.com
  filters:
    - enabled: true
      url: https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt
      name: AdGuard DNS filter
      id: 1
    - enabled: true
      url: https://adaway.org/hosts.txt
      name: AdAway Default Blocklist
      id: 2
  whitelist_filters: []
  user_rules: []
dhcp:
  enabled: false
clients:
  runtime_sources:
    whois: true
    arp: true
    rdns: true
    dhcp: true
    hosts: true
  persistent: []
log_file: ""
log_max_backups: 0
log_max_size: 100
log_max_age: 3
log_compress: false
log_localtime: false
verbose: false
os:
  group: ""
  user: ""
  rlimit_nofile: 0
schema_version: 20
EOF

    print_success "AdGuard Home configuration prepared"
    print_status "AdGuard Home will be available as a Docker container"
    print_status "DNS service will run on standard port 53"
}

# Create management script
create_management_script() {
    print_step "Creating Management Script"

    cat > "$INSTALL_DIR/skylab" << 'EOF'
#!/bin/bash

# SkyLab Management Script
INSTALL_DIR="/opt/skylab"
cd "$INSTALL_DIR"

case "$1" in
    start|up)
        echo "Starting SkyLab services..."
        docker-compose up -d ${@:2}
        ;;
    stop|down)
        echo "Stopping SkyLab services..."
        docker-compose down
        ;;
    restart)
        echo "Restarting SkyLab services..."
        docker-compose restart ${@:2}
        ;;
    status)
        echo "SkyLab Service Status:"
        docker-compose ps
        ;;
    logs)
        docker-compose logs -f ${@:2}
        ;;
    update)
        echo "Updating SkyLab services..."
        docker-compose pull
        docker-compose up -d
        ;;
    deploy)
        profiles="${@:2}"
        if [[ -z "$profiles" ]]; then
            profiles="core"
        fi
        echo "Deploying SkyLab with profiles: $profiles"

        profile_args=""
        for profile in $profiles; do
            if [[ "$profile" != "core" ]]; then
                profile_args="$profile_args --profile $profile"
            fi
        done

        # Check if docker-compose supports profiles
        if docker-compose --help | grep -q "profile"; then
            if ! docker-compose up -d $profile_args 2>/dev/null; then
                echo "Docker permission issue, trying with sudo..."
                sudo docker-compose up -d $profile_args
            fi
        else
            echo "Docker Compose version doesn't support profiles, starting all services"
            if ! docker-compose up -d 2>/dev/null; then
                echo "Docker permission issue, trying with sudo..."
                sudo docker-compose up -d
            fi
        fi
        ;;
    *)
        echo "SkyLab Management Script"
        echo ""
        echo "Usage: $0 {start|stop|restart|status|logs|update|deploy} [options]"
        echo ""
        echo "Commands:"
        echo "  start [service]     Start all services or specific service"
        echo "  stop               Stop all services"
        echo "  restart [service]  Restart all services or specific service"
        echo "  status             Show service status"
        echo "  logs [service]     Show logs for all or specific service"
        echo "  update             Update all services to latest images"
        echo "  deploy [profiles]  Deploy with specific profiles"
        echo ""
        echo "Profiles:"
        echo "  core              Essential services (default)"
        echo "  proxy             Traefik + Authelia + Cloudflare Tunnel"
        echo "  monitoring        Uptime Kuma"
        echo "  dashboard         Heimdall"
        echo "  npm               Nginx Proxy Manager"
        echo ""
        echo "Examples:"
        echo "  $0 deploy core proxy"
        echo "  $0 logs traefik"
        echo "  $0 restart filebrowser"
        ;;
esac
EOF

    chmod +x "$INSTALL_DIR/skylab"

    # Create symlink for global access
    sudo ln -sf "$INSTALL_DIR/skylab" /usr/local/bin/skylab

    print_success "Management script created"
    print_status "Use 'skylab' command from anywhere to manage your stack"
}

# Deploy services
deploy_services() {
    print_step "Deploying SkyLab Services"

    cd "$INSTALL_DIR"

    echo -e "${CYAN}Starting Docker containers for your selected services...${NC}"
    echo ""

    # Build profile arguments
    local profile_args=""

    case "$INSTALL_TYPE" in
        local)
            echo -e "${YELLOW}Deploying Local Only services:${NC}"
            echo -e "   • Filebrowser (File management)"
            echo -e "   • PiVPN (VPN server)"
            echo -e "   • AdGuard Home (DNS ad-blocking) - Docker"
            echo -e "   • Portainer (Docker management)"
            echo -e "   • Watchtower (Auto-updates)"

            # Add optional services for local installation
            if [[ "$INSTALL_MONITORING" == true ]]; then
                echo -e "   • Uptime Kuma (Service monitoring)"
                profile_args="$profile_args --profile monitoring"
            fi
            if [[ "$INSTALL_DASHBOARD" == true ]]; then
                echo -e "   • Heimdall (Application dashboard)"
                profile_args="$profile_args --profile dashboard"
            fi
            echo ""
            print_status "Starting core services$profile_args..."
            print_status "Pulling Docker images and starting containers..."

            # Run docker-compose with progress output
            docker-compose pull $profile_args 2>&1 | while IFS= read -r line; do
                if [[ "$line" =~ (Pulling|Downloaded|Extracting|Pull complete) ]]; then
                    print_status "$(echo "$line" | sed 's/^[[:space:]]*//')"
                fi
            done

            print_status "Starting containers..."

            # Check if docker-compose supports profiles
            if docker-compose --help | grep -q "profile"; then
                if ! docker-compose up -d $profile_args 2>/dev/null; then
                    print_warning "Docker permission issue, trying with sudo..."
                    sudo docker-compose up -d $profile_args
                fi
            else
                print_warning "Docker Compose version doesn't support profiles, starting all services"
                if ! docker-compose up -d 2>/dev/null; then
                    print_warning "Docker permission issue, trying with sudo..."
                    sudo docker-compose up -d
                fi
            fi
            ;;
        cloudflare)
            echo -e "${YELLOW}Deploying Cloudflare Tunnel services:${NC}"
            echo -e "   • All Local services +"
            echo -e "   • Traefik (Reverse proxy)"
            echo -e "   • Authelia (2FA authentication)"
            echo -e "   • Cloudflare Tunnel (External access)"

            profile_args="--profile proxy"
            if [[ "$INSTALL_MONITORING" == true ]]; then
                echo -e "   • Uptime Kuma (Service monitoring)"
                profile_args="$profile_args --profile monitoring"
            fi
            if [[ "$INSTALL_DASHBOARD" == true ]]; then
                echo -e "   • Heimdall (Application dashboard)"
                profile_args="$profile_args --profile dashboard"
            fi
            echo ""
            print_status "Starting core + proxy services..."

            # Check if docker-compose supports profiles
            if docker-compose --help | grep -q "profile"; then
                if ! docker-compose up -d $profile_args 2>/dev/null; then
                    print_warning "Docker permission issue, trying with sudo..."
                    sudo docker-compose up -d $profile_args
                fi
            else
                print_warning "Docker Compose version doesn't support profiles, starting all services"
                if ! docker-compose up -d 2>/dev/null; then
                    print_warning "Docker permission issue, trying with sudo..."
                    sudo docker-compose up -d
                fi
            fi
            ;;
        portforward)
            echo -e "${YELLOW}Deploying Port Forward services:${NC}"
            echo -e "   • All Local services +"
            echo -e "   • Traefik (Reverse proxy)"
            echo -e "   • Authelia (2FA authentication)"

            profile_args="--profile proxy"
            if [[ "$INSTALL_MONITORING" == true ]]; then
                echo -e "   • Uptime Kuma (Service monitoring)"
                profile_args="$profile_args --profile monitoring"
            fi
            if [[ "$INSTALL_DASHBOARD" == true ]]; then
                echo -e "   • Heimdall (Application dashboard)"
                profile_args="$profile_args --profile dashboard"
            fi
            echo ""
            print_status "Starting core + proxy services..."

            # Check if docker-compose supports profiles
            if docker-compose --help | grep -q "profile"; then
                if ! docker-compose up -d $profile_args 2>/dev/null; then
                    print_warning "Docker permission issue, trying with sudo..."
                    sudo docker-compose up -d $profile_args
                fi
            else
                print_warning "Docker Compose version doesn't support profiles, starting all services"
                if ! docker-compose up -d 2>/dev/null; then
                    print_warning "Docker permission issue, trying with sudo..."
                    sudo docker-compose up -d
                fi
            fi
            ;;
    esac

    # Wait a moment for containers to start
    print_status "Waiting for containers to initialize..."
    sleep 15

    # Configure DNS to point to AdGuard Home if it's running
    if docker ps --format "{{.Names}}" | grep -q "adguard"; then
        print_status "Configuring system DNS to use AdGuard Home..."
        local server_ip=$(hostname -I | awk '{print $1}')
        echo "nameserver $server_ip" | sudo tee /etc/resolv.conf >/dev/null
        echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf >/dev/null
        print_success "DNS configured to use AdGuard Home at $server_ip"
    fi
    sleep 10

    # Check if containers are running
    local running_containers=$(docker ps --format "table {{.Names}}" | grep -v NAMES | wc -l)
    print_success "Services deployed successfully ($running_containers containers running)"

    # Show any failed containers
    local failed_containers=$(docker ps -a --filter "status=exited" --format "{{.Names}}" | head -5)
    if [[ -n "$failed_containers" ]]; then
        print_warning "Some containers may have issues:"
        echo "$failed_containers" | while read container; do
            echo -e "   ${RED}⚠${NC} $container"
        done
        print_status "Check logs with: skylab logs [container-name]"
    fi
}

# Show final information
show_completion_info() {
    print_step "🎉 Installation Complete!"

    # Use the already detected server IP
    local server_ip="$SERVER_IP"

    echo -e "${GREEN}${BOLD}🎉 SkyLab installation completed successfully!${NC}"
    echo ""

    # Show service access information based on installation type
    case "$INSTALL_TYPE" in
        local)
            echo -e "${BOLD}${CYAN}🏠 Your Local Services:${NC}"
            echo ""
            echo -e "${BOLD}📁 File Management:${NC}"
            echo -e "   ${CYAN}http://$server_ip:8080${NC} - Filebrowser"
            echo -e "   Upload, download, and manage files through web browser"
            echo ""
            echo -e "${BOLD}🐳 Container Management:${NC}"
            echo -e "   ${CYAN}http://$server_ip:9000${NC} - Portainer"
            echo -e "   Monitor and control Docker containers visually"
            echo ""
            echo -e "${BOLD}🔒 VPN Server:${NC}"
            echo -e "   ${CYAN}http://$server_ip:8443${NC} - PiVPN Admin"
            echo -e "   Create VPN profiles for secure remote access"
            echo ""
            echo -e "${BOLD}🛡️ DNS Protection:${NC}"
            echo -e "   ${CYAN}http://$server_ip:3000${NC} - AdGuard Home (Docker)"
            echo -e "   Configure network-wide ad blocking and DNS filtering"
            echo -e "   ${YELLOW}Default login: admin / admin123${NC}"
            echo -e "   ${YELLOW}DNS Server: $server_ip${NC} - Set this as your device DNS"
            ;;
        cloudflare)
            echo -e "${BOLD}${CYAN}☁️ Your Cloudflare Tunnel Services:${NC}"
            echo ""
            echo -e "${BOLD}🌐 External Access (HTTPS + 2FA):${NC}"
            echo -e "   ${CYAN}https://files.$DOMAIN${NC} - File Management"
            echo -e "   ${CYAN}https://portainer.$DOMAIN${NC} - Container Management"
            echo -e "   ${CYAN}https://vpn.$DOMAIN${NC} - VPN Administration"
            echo -e "   ${CYAN}https://dns.$DOMAIN${NC} - AdGuard Home (DNS Filtering)"
            echo -e "   ${CYAN}https://traefik.$DOMAIN${NC} - Proxy Dashboard"
            echo ""
            echo -e "${BOLD}🔐 Authentication Portal:${NC}"
            echo -e "   ${CYAN}https://auth.$DOMAIN${NC} - Login & 2FA Setup"
            echo ""
            echo -e "${BOLD}🛡️ Local DNS (No 2FA needed):${NC}"
            echo -e "   ${CYAN}http://$server_ip:3000${NC} - AdGuard Home"
            echo -e "   ${YELLOW}DNS Server: $server_ip${NC} - Configure devices to use this DNS"
            echo ""
            echo -e "${YELLOW}🔑 Default Login: admin / admin123${NC}"
            echo -e "${RED}⚠️ Change this password immediately!${NC}"
            ;;
        portforward)
            if [[ -n "$DOMAIN" ]]; then
                echo -e "${BOLD}${CYAN}🌐 Your Port Forward Services:${NC}"
                echo ""
                echo -e "${BOLD}🌐 External Access (HTTPS + 2FA):${NC}"
                echo -e "   ${CYAN}https://files.$DOMAIN${NC} - File Management"
                echo -e "   ${CYAN}https://portainer.$DOMAIN${NC} - Container Management"
                echo -e "   ${CYAN}https://vpn.$DOMAIN${NC} - VPN Administration"
                echo -e "   ${CYAN}https://dns.$DOMAIN${NC} - AdGuard Home (DNS Filtering)"
                echo -e "   ${CYAN}https://traefik.$DOMAIN${NC} - Proxy Dashboard"
                echo ""
                echo -e "${BOLD}🔐 Authentication Portal:${NC}"
                echo -e "   ${CYAN}https://auth.$DOMAIN${NC} - Login & 2FA Setup"
                echo ""
                echo -e "${YELLOW}🔑 Default Login: admin / admin123${NC}"
                echo -e "${RED}⚠️ Change this password immediately!${NC}"
            else
                echo -e "${BOLD}${CYAN}🌐 Your Port Forward Services:${NC}"
                echo ""
                echo -e "${BOLD}🌐 Local Access:${NC}"
                echo -e "   ${CYAN}http://$server_ip:8080${NC} - Filebrowser"
                echo -e "   ${CYAN}http://$server_ip:9000${NC} - Portainer"
                echo -e "   ${CYAN}http://$server_ip:8443${NC} - PiVPN Admin"
                echo -e "   ${CYAN}http://$server_ip:8081${NC} - Traefik Dashboard"
            fi
            echo ""
            echo -e "${BOLD}🛡️ DNS Protection:${NC}"
            echo -e "   ${CYAN}http://$server_ip:3000${NC} - AdGuard Home"
            echo -e "   ${YELLOW}DNS Server: $server_ip${NC} - Configure devices to use this DNS"
            ;;
    esac

    echo ""
    echo -e "${BOLD}${MAGENTA}🛠️ Management Commands:${NC}"
    echo -e "   ${YELLOW}skylab status${NC}     - Check all services"
    echo -e "   ${YELLOW}skylab logs${NC}       - View service logs"
    echo -e "   ${YELLOW}skylab restart${NC}    - Restart services"
    echo -e "   ${YELLOW}skylab update${NC}     - Update to latest versions"
    echo ""
    echo -e "${BOLD}${MAGENTA}📦 Add More Services:${NC}"
    echo -e "   ${YELLOW}skylab deploy core monitoring${NC}  - Add Uptime Kuma"
    echo -e "   ${YELLOW}skylab deploy core dashboard${NC}   - Add Heimdall"
    echo -e "   ${YELLOW}skylab deploy core monitoring dashboard${NC} - Add both"

    # Installation-specific instructions
    if [[ "$INSTALL_TYPE" == "cloudflare" ]]; then
        echo ""
        echo -e "${BOLD}${RED}🚨 IMPORTANT NEXT STEPS:${NC}"
        echo ""
        echo -e "${YELLOW}1. Add DNS Records in Cloudflare:${NC}"
        echo -e "   • Go to Cloudflare Dashboard → DNS"
        echo -e "   • Add CNAME record: ${CYAN}*${NC} → ${CYAN}tunnel-id.cfargotunnel.com${NC}"
        echo -e "   • Or add individual records for each subdomain"
        echo ""
        echo -e "${YELLOW}2. Set Up 2FA Authentication:${NC}"
        echo -e "   • Visit: ${CYAN}https://auth.$DOMAIN${NC}"
        echo -e "   • Login with: ${CYAN}admin / admin123${NC}"
        echo -e "   • Change password immediately"
        echo -e "   • Set up 2FA with Google Authenticator or similar"
        echo ""
        echo -e "${YELLOW}3. Configure AdGuard Home:${NC}"
        echo -e "   • Visit: ${CYAN}http://$server_ip:3000${NC}"
        echo -e "   • Complete initial setup wizard"
        echo -e "   • Set DNS servers on your devices to: ${CYAN}$server_ip${NC}"
    fi

    if [[ "$INSTALL_TYPE" == "portforward" ]]; then
        echo ""
        echo -e "${BOLD}${RED}🚨 IMPORTANT NEXT STEPS:${NC}"
        echo ""
        echo -e "${YELLOW}1. Configure Router Port Forwarding:${NC}"
        echo -e "   • Forward port 80 → $server_ip:80"
        echo -e "   • Forward port 443 → $server_ip:443"
        echo -e "   • Ensure your server has a static local IP"
        echo ""
        if [[ -n "$DOMAIN" ]]; then
            echo -e "${YELLOW}2. Set Up 2FA Authentication:${NC}"
            echo -e "   • Visit: ${CYAN}https://auth.$DOMAIN${NC}"
            echo -e "   • Login with: ${CYAN}admin / admin123${NC}"
            echo -e "   • Change password immediately"
            echo -e "   • Set up 2FA with Google Authenticator or similar"
            echo ""
        fi
        echo -e "${YELLOW}3. Configure AdGuard Home:${NC}"
        echo -e "   • Visit: ${CYAN}http://$server_ip:3000${NC}"
        echo -e "   • Complete initial setup wizard"
        echo -e "   • Set DNS servers on your devices to: ${CYAN}$server_ip${NC}"
    fi

    if [[ "$INSTALL_TYPE" == "local" ]]; then
        echo ""
        echo -e "${BOLD}${YELLOW}📋 RECOMMENDED NEXT STEPS:${NC}"
        echo ""
        echo -e "${YELLOW}1. Configure AdGuard Home:${NC}"
        echo -e "   • Visit: ${CYAN}http://$server_ip:3000${NC}"
        echo -e "   • Complete initial setup wizard"
        echo -e "   • Set DNS servers on your devices to: ${CYAN}$server_ip${NC}"
        echo ""
        echo -e "${YELLOW}2. Set Up VPN Access:${NC}"
        echo -e "   • Visit: ${CYAN}http://$server_ip:8443${NC}"
        echo -e "   • Create VPN profiles for your devices"
        echo -e "   • Download .ovpn files and configure clients"
        echo ""
        echo -e "${YELLOW}3. Explore Your Files:${NC}"
        echo -e "   • Visit: ${CYAN}http://$server_ip:8080${NC}"
        echo -e "   • Upload and manage files through web interface"
        echo -e "   • Access your entire server filesystem"
    fi

    echo ""
    echo -e "${BOLD}${GREEN}🎊 Congratulations! Your SkyLab is ready! 🎊${NC}"
    echo ""
    echo -e "${CYAN}💡 Pro Tips:${NC}"
    echo -e "   • Bookmark your service URLs for easy access"
    echo -e "   • Check service status regularly with ${YELLOW}skylab status${NC}"
    echo -e "   • Services auto-update nightly via Watchtower"
    echo -e "   • All data is stored in ${CYAN}$DATA_DIR/appdata${NC}"
    echo ""
    echo -e "${BOLD}${CYAN}📁 Installation Summary:${NC}"
    echo -e "   • Installation files: ${CYAN}$INSTALL_DIR${NC}"
    echo -e "   • Service data: ${CYAN}$DATA_DIR/appdata${NC}"
    echo -e "   • Management command: ${CYAN}skylab${NC} (available globally)"
    echo -e "   • Configuration: ${CYAN}$INSTALL_DIR/.env${NC}"
    echo -e "   • Docker Compose: ${CYAN}$INSTALL_DIR/docker-compose.yml${NC}"
    echo ""
    echo -e "${BOLD}${MAGENTA}🚀 Welcome to the future of home lab management! 🚀${NC}"
}

# Progress tracking
show_progress() {
    local current=$1
    local total=$2
    local task=$3

    local percent=$((current * 100 / total))
    local filled=$((percent / 5))
    local empty=$((20 - filled))

    printf "\r${BOLD}${CYAN}Progress: [${NC}"
    printf "%*s" $filled | tr ' ' '#'
    printf "%*s" $empty | tr ' ' '-'
    printf "${BOLD}${CYAN}] %d%% - %s${NC}" $percent "$task"

    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

# Optional services selection
select_optional_services() {
    if [[ "$INSTALL_TYPE" == "local" ]]; then
        return  # No optional services for local installation
    fi

    print_step "Optional Services Selection"

    echo -e "${BOLD}Would you like to install optional services?${NC}"
    echo ""
    echo -e "${CYAN}Available optional services:${NC}"
    echo ""
    echo -e "${BOLD}📊 Uptime Kuma${NC} - Service Monitoring"
    echo -e "   • Monitor all your services 24/7"
    echo -e "   • Get alerts when services go down"
    echo -e "   • Beautiful status pages"
    echo -e "   • Email/Discord/Slack notifications"
    echo ""
    echo -e "${BOLD}🏠 Heimdall${NC} - Application Dashboard"
    echo -e "   • Beautiful homepage for all services"
    echo -e "   • Custom icons and themes"
    echo -e "   • Quick access to everything"
    echo -e "   • Search functionality"
    echo ""

    INSTALL_MONITORING=false
    INSTALL_DASHBOARD=false

    while true; do
        read -p "Install Uptime Kuma (monitoring)? [y/N]: " choice
        case $choice in
            [Yy]*)
                INSTALL_MONITORING=true
                print_success "Uptime Kuma will be installed"
                break
                ;;
            [Nn]*|"")
                print_status "Skipping Uptime Kuma"
                break
                ;;
            *)
                print_warning "Please answer yes (y) or no (n)"
                ;;
        esac
    done

    while true; do
        read -p "Install Heimdall (dashboard)? [y/N]: " choice
        case $choice in
            [Yy]*)
                INSTALL_DASHBOARD=true
                print_success "Heimdall will be installed"
                break
                ;;
            [Nn]*|"")
                print_status "Skipping Heimdall"
                break
                ;;
            *)
                print_warning "Please answer yes (y) or no (n)"
                ;;
        esac
    done

    if [[ "$INSTALL_MONITORING" == true || "$INSTALL_DASHBOARD" == true ]]; then
        echo ""
        echo -e "${GREEN}Optional services selected:${NC}"
        [[ "$INSTALL_MONITORING" == true ]] && echo -e "   ✅ Uptime Kuma (monitoring)"
        [[ "$INSTALL_DASHBOARD" == true ]] && echo -e "   ✅ Heimdall (dashboard)"
        echo ""
    fi
}

# Main installation function
main() {
    print_banner
    show_welcome

    # Pre-installation checks
    show_progress 1 12 "Checking system requirements..."
    check_root
    detect_system
    check_prerequisites
    check_existing_installation

    # User configuration
    show_progress 2 12 "Collecting configuration..."
    show_menu
    select_optional_services

    # System setup
    show_progress 3 12 "Installing system dependencies..."
    install_dependencies

    show_progress 4 12 "Installing Docker..."
    install_docker

    show_progress 5 12 "Installing Docker Compose..."
    install_docker_compose

    # Directory and configuration setup
    show_progress 6 12 "Creating directory structure..."
    create_directories

    show_progress 7 12 "Generating security secrets..."
    generate_secrets

    show_progress 8 12 "Creating environment configuration..."
    create_env_file

    show_progress 9 12 "Creating Docker Compose configuration..."
    create_docker_compose

    # Advanced setup for proxy installations
    if [[ "$INSTALL_TYPE" == "cloudflare" || "$INSTALL_TYPE" == "portforward" ]]; then
        show_progress 10 12 "Configuring Traefik reverse proxy..."
        create_traefik_config
        create_authelia_config
    fi

    # Cloudflare-specific setup
    if [[ "$INSTALL_TYPE" == "cloudflare" ]]; then
        show_progress 10 12 "Setting up Cloudflare Tunnel..."
        setup_cloudflare_tunnel
    fi

    # Service preparation
    show_progress 11 12 "Resolving DNS conflicts..."
    resolve_dns_conflicts

    show_progress 11 12 "Preparing AdGuard Home configuration..."
    prepare_adguard_config

    show_progress 11 12 "Creating management tools..."
    create_management_script

    # Final deployment
    show_progress 12 12 "Deploying services..."
    deploy_services

    show_progress 12 12 "Installation complete!"
    echo ""

    show_completion_info
}

# Test installation function
test_installation() {
    print_step "Testing SkyLab Installation"

    local errors=0

    # Test Docker
    if ! docker --version >/dev/null 2>&1; then
        print_error "Docker is not working"
        ((errors++))
    else
        print_success "Docker is working"
    fi

    # Test Docker Compose
    if ! docker-compose --version >/dev/null 2>&1; then
        print_error "Docker Compose is not working"
        ((errors++))
    else
        print_success "Docker Compose is working"
    fi

    # Test directory structure
    if [[ ! -d "$DATA_DIR/appdata" ]]; then
        print_error "Data directory missing: $DATA_DIR/appdata"
        ((errors++))
    else
        print_success "Data directory exists"
    fi

    # Test configuration files
    if [[ ! -f "$INSTALL_DIR/.env" ]]; then
        print_error "Environment file missing: $INSTALL_DIR/.env"
        ((errors++))
    else
        print_success "Environment file exists"
    fi

    if [[ ! -f "$INSTALL_DIR/docker-compose.yml" ]]; then
        print_error "Docker Compose file missing: $INSTALL_DIR/docker-compose.yml"
        ((errors++))
    else
        print_success "Docker Compose file exists"
    fi

    # Test service startup
    print_status "Testing service startup..."
    cd "$INSTALL_DIR"

    if ! sudo docker-compose config >/dev/null 2>&1; then
        print_error "Docker Compose configuration is invalid"
        ((errors++))
    else
        print_success "Docker Compose configuration is valid"
    fi

    if [[ $errors -eq 0 ]]; then
        print_success "All installation tests passed!"
        return 0
    else
        print_error "Installation test failed with $errors errors"
        print_status "Please check the issues above before proceeding"
        return 1
    fi
}

# Handle command line arguments
if [[ $# -gt 0 ]]; then
    if [[ "$1" == "test" ]]; then
        test_installation
        exit $?
    elif [[ "$1" == "--debug" ]]; then
        DEBUG=true
        shift
    fi
fi

# Run main function
main "$@"
