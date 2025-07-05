#!/bin/bash

# SkyLab Service Verification Script
# Checks if all services are properly installed and working

set -euo pipefail

# Color definitions
colorRed='\033[31m'
colorGreen='\033[32m'
colorYellow='\033[33m'
colorBlue='\033[34m'
colorMagenta='\033[35m'
colorCyan='\033[36m'
colorBold='\033[1m'
colorDim='\033[2m'
colorReset='\033[0m'

# Script information
SCRIPT_NAME="SkyLab Service Verifier"
SCRIPT_VERSION="1.0.0"
VERIFY_LOG="/var/log/skylab/verify-$(date +%Y%m%d-%H%M%S).log"

# Create log directory if it doesn't exist
sudo mkdir -p /var/log/skylab

# Logging function
Log_Message() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | sudo tee -a "$VERIFY_LOG" > /dev/null
}

# Display functions
Show() {
    local type=$1
    local message="$2"
    local timestamp=$(date '+%H:%M:%S')
    
    case $type in
        0) # Success
            echo -e "${colorGreen} [$timestamp] [✓] $message${colorReset}"
            Log_Message "SUCCESS" "$message"
            ;;
        1) # Error
            echo -e "${colorRed} [$timestamp] [✗] $message${colorReset}"
            Log_Message "ERROR" "$message"
            ;;
        2) # Info
            echo -e "${colorBlue} [$timestamp] [!] $message${colorReset}"
            Log_Message "INFO" "$message"
            ;;
        3) # Warning
            echo -e "${colorYellow} [$timestamp] [⚠] $message${colorReset}"
            Log_Message "WARNING" "$message"
            ;;
        4) # Debug
            echo -e "${colorDim} [$timestamp] [🐛] $message${colorReset}"
            Log_Message "DEBUG" "$message"
            ;;
    esac
}

# Service verification functions
Check_Service_Status() {
    local service_name="$1"
    local container_name="$2"
    local expected_port="$3"
    local health_endpoint="${4:-}"
    
    echo -e "\n${colorCyan}${colorBold}━━━ Checking $service_name ━━━${colorReset}"
    
    # Check if container exists and is running
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "^$container_name"; then
        local status=$(docker ps --format "{{.Status}}" --filter "name=$container_name")
        Show 0 "Container '$container_name' is running: $status"
        
        # Check port binding
        if docker port "$container_name" 2>/dev/null | grep -q ":$expected_port"; then
            Show 0 "Port $expected_port is properly bound"
        else
            Show 3 "Port $expected_port binding not found or different"
        fi
        
        # Check health endpoint if provided
        if [[ -n "$health_endpoint" ]]; then
            if curl -s --connect-timeout 5 "$health_endpoint" > /dev/null 2>&1; then
                Show 0 "Health endpoint $health_endpoint is responding"
            else
                Show 3 "Health endpoint $health_endpoint is not responding"
            fi
        fi
        
        # Check container logs for errors
        local error_count=$(docker logs "$container_name" --since 1h 2>&1 | grep -i "error\|failed\|exception" | wc -l)
        if [[ $error_count -eq 0 ]]; then
            Show 0 "No recent errors in container logs"
        else
            Show 3 "Found $error_count error(s) in recent logs"
        fi
        
        return 0
    else
        Show 1 "Container '$container_name' is not running"
        return 1
    fi
}

# Check system dependencies
Check_System_Dependencies() {
    echo -e "\n${colorMagenta}${colorBold}═══ System Dependencies Verification ═══${colorReset}"
    
    local dependencies=("docker" "docker-compose" "curl" "wget" "rclone" "lazydocker")
    local missing_deps=()
    
    for dep in "${dependencies[@]}"; do
        if command -v "$dep" > /dev/null 2>&1; then
            local version=$("$dep" --version 2>/dev/null | head -n1 || echo "Unknown version")
            Show 0 "$dep is installed: $version"
        else
            Show 1 "$dep is not installed or not in PATH"
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -eq 0 ]]; then
        Show 0 "All system dependencies are installed"
        return 0
    else
        Show 1 "Missing dependencies: ${missing_deps[*]}"
        return 1
    fi
}

# Check Docker system
Check_Docker_System() {
    echo -e "\n${colorMagenta}${colorBold}═══ Docker System Verification ═══${colorReset}"
    
    # Check Docker daemon
    if docker info > /dev/null 2>&1; then
        Show 0 "Docker daemon is running"
        
        # Check Docker version
        local docker_version=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
        Show 0 "Docker version: $docker_version"
        
        # Check Docker Compose
        if docker-compose --version > /dev/null 2>&1; then
            local compose_version=$(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)
            Show 0 "Docker Compose version: $compose_version"
        else
            Show 1 "Docker Compose is not available"
        fi
        
        # Check Docker network
        if docker network ls | grep -q "skylab"; then
            Show 0 "SkyLab network exists"
        else
            Show 3 "SkyLab network not found"
        fi
        
        return 0
    else
        Show 1 "Docker daemon is not running or not accessible"
        return 1
    fi
}

# Check containerized services
Check_Containerized_Services() {
    echo -e "\n${colorMagenta}${colorBold}═══ Containerized Services Verification ═══${colorReset}"
    
    local services_status=0
    
    # Core services (always expected to be running)
    Check_Service_Status "Filebrowser" "filebrowser" "8080" "http://localhost:8080" || services_status=1
    Check_Service_Status "Watchtower" "watchtower" "" "" || services_status=1
    
    # Optional services (may not be running depending on profiles)
    echo -e "\n${colorYellow}${colorBold}--- Optional Services (Profile-dependent) ---${colorReset}"
    
    # Check if docker-compose.yml exists
    if [[ -f "docker-compose.yml" ]]; then
        Show 0 "Docker Compose configuration found"
        
        # Check optional services
        Check_Service_Status "Portainer" "portainer" "9000" "http://localhost:9000" || true
        Check_Service_Status "Nginx Proxy Manager" "nginx-proxy-manager" "81" "http://localhost:81" || true
        Check_Service_Status "Uptime Kuma" "uptime-kuma" "3001" "http://localhost:3001" || true
        Check_Service_Status "Pi-hole" "pihole" "8053" "http://localhost:8053" || true
        Check_Service_Status "Heimdall" "heimdall" "8090" "http://localhost:8090" || true
        Check_Service_Status "AdGuard Home" "adguard" "3000" "http://localhost:3000" || true
    else
        Show 3 "Docker Compose configuration not found in current directory"
    fi
    
    return $services_status
}

# Check system resources
Check_System_Resources() {
    echo -e "\n${colorMagenta}${colorBold}═══ System Resources Verification ═══${colorReset}"
    
    # Check memory usage
    local memory_info=$(free -h | grep '^Mem:')
    local memory_used=$(echo $memory_info | awk '{print $3}')
    local memory_total=$(echo $memory_info | awk '{print $2}')
    Show 2 "Memory usage: $memory_used / $memory_total"
    
    # Check disk usage
    local disk_usage=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $disk_usage -lt 80 ]]; then
        Show 0 "Disk usage: ${disk_usage}% (healthy)"
    elif [[ $disk_usage -lt 90 ]]; then
        Show 3 "Disk usage: ${disk_usage}% (warning)"
    else
        Show 1 "Disk usage: ${disk_usage}% (critical)"
    fi
    
    # Check CPU load
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    Show 2 "CPU load average (1min): $load_avg"
    
    # Check running containers count
    local running_containers=$(docker ps -q | wc -l)
    Show 2 "Running containers: $running_containers"
}

# Generate verification report
Generate_Report() {
    echo -e "\n${colorCyan}${colorBold}═══════════════════════════════════════════════════════════════════════════════${colorReset}"
    echo -e "${colorCyan}${colorBold}                           VERIFICATION REPORT                                ${colorReset}"
    echo -e "${colorCyan}${colorBold}═══════════════════════════════════════════════════════════════════════════════${colorReset}"
    
    local total_checks=0
    local passed_checks=0
    local failed_checks=0
    local warning_checks=0
    
    # Count results from log
    total_checks=$(grep -c "\[SUCCESS\]\|\[ERROR\]\|\[WARNING\]" "$VERIFY_LOG" 2>/dev/null || echo "0")
    passed_checks=$(grep -c "\[SUCCESS\]" "$VERIFY_LOG" 2>/dev/null || echo "0")
    failed_checks=$(grep -c "\[ERROR\]" "$VERIFY_LOG" 2>/dev/null || echo "0")
    warning_checks=$(grep -c "\[WARNING\]" "$VERIFY_LOG" 2>/dev/null || echo "0")
    
    echo -e "${colorBold}📊 Summary:${colorReset}"
    echo -e "   ${colorGreen}✓ Passed: $passed_checks${colorReset}"
    echo -e "   ${colorRed}✗ Failed: $failed_checks${colorReset}"
    echo -e "   ${colorYellow}⚠ Warnings: $warning_checks${colorReset}"
    echo -e "   📋 Total Checks: $total_checks"
    
    if [[ $failed_checks -eq 0 ]]; then
        echo -e "\n${colorGreen}${colorBold}🎉 Overall Status: HEALTHY${colorReset}"
        if [[ $warning_checks -gt 0 ]]; then
            echo -e "${colorYellow}   Note: Some warnings detected, but system is functional${colorReset}"
        fi
    else
        echo -e "\n${colorRed}${colorBold}❌ Overall Status: ISSUES DETECTED${colorReset}"
        echo -e "${colorRed}   Please review the failed checks above${colorReset}"
    fi
    
    echo -e "\n${colorDim}📝 Detailed log saved to: $VERIFY_LOG${colorReset}"
    echo -e "${colorDim}🕒 Verification completed at: $(date)${colorReset}"
}

# Main verification function
Main_Verification() {
    clear
    echo -e "${colorMagenta}${colorBold}"
    echo "    ███████╗██╗  ██╗██╗   ██╗██╗      █████╗ ██████╗ "
    echo "    ██╔════╝██║ ██╔╝╚██╗ ██╔╝██║     ██╔══██╗██╔══██╗"
    echo "    ███████╗█████╔╝  ╚████╔╝ ██║     ███████║██████╔╝"
    echo "    ╚════██║██╔═██╗   ╚██╔╝  ██║     ██╔══██║██╔══██╗"
    echo "    ███████║██║  ██╗   ██║   ███████╗██║  ██║██████╔╝"
    echo "    ╚══════╝╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═════╝ "
    echo -e "${colorReset}"
    echo -e "${colorBold}${colorMagenta}    🔍 Service Verification & Health Check${colorReset}"
    echo -e "${colorDim}    Version $SCRIPT_VERSION${colorReset}"
    echo -e "\n${colorYellow}Starting comprehensive system verification...${colorReset}\n"
    
    Log_Message "INFO" "Starting SkyLab service verification"
    
    # Run all verification checks
    Check_System_Dependencies
    Check_Docker_System
    Check_Containerized_Services
    Check_System_Resources
    
    # Generate final report
    Generate_Report
    
    Log_Message "INFO" "SkyLab service verification completed"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    Main_Verification
fi