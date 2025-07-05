#!/usr/bin/bash

###############################################################################
# ⭐ SkyLab - Advanced Home Lab Setup Orchestrator ⭐
# 
# An intelligent, interactive system setup script for home lab environments
# Originally based on CasaOS installer but evolved for comprehensive lab setup
# 
# 🚀 This script will:
# - Validate system requirements and compatibility
# - Install and configure Docker with networking
# - Set up USB auto-mounting capabilities
# - Install essential tools (Rclone, LazyDocker, Watchtower)
# - Configure regional optimizations
# - Provide real-time progress tracking
# 
# 📋 Supported: Debian, Ubuntu, CentOS, Fedora, openSUSE, Arch Linux
# 💾 Requirements: 1GB RAM, 5GB disk space, 64-bit architecture
###############################################################################

# Load configuration file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/skylab.conf"

if [[ -f "$CONFIG_FILE" ]]; then
    echo "Loading configuration from $CONFIG_FILE..."
    source "$CONFIG_FILE"
    
    # Validate configuration
    if declare -f validate_config >/dev/null; then
        if ! validate_config; then
            echo "Configuration validation failed. Please check $CONFIG_FILE"
            exit 1
        fi
    fi
else
    echo "Warning: Configuration file not found at $CONFIG_FILE"
    echo "Using default values..."
    
    # Default values if config file is missing
    SCRIPT_NAME="SkyLab"
    SCRIPT_VERSION="2.0.0"
    MIN_MEMORY_GB=2
    MIN_DISK_GB=10
    RETRY_ATTEMPTS=3
    RETRY_DELAY=5
fi

# Script Information (can be overridden by config)
SCRIPT_NAME=${SCRIPT_NAME:-"SkyLab"}
SCRIPT_VERSION=${SCRIPT_VERSION:-"2.0.0"}
TOTAL_STEPS=15
#
# Welcome Banner
Welcome_Banner() {
    clear
    echo -e "${colorCyan}${colorBold}"
    echo "    ███████╗██╗  ██╗██╗   ██╗██╗      █████╗ ██████╗ "
    echo "    ██╔════╝██║ ██╔╝╚██╗ ██╔╝██║     ██╔══██╗██╔══██╗"
    echo "    ███████╗█████╔╝  ╚████╔╝ ██║     ███████║██████╔╝"
    echo "    ╚════██║██╔═██╗   ╚██╔╝  ██║     ██╔══██║██╔══██╗"
    echo "    ███████║██║  ██╗   ██║   ███████╗██║  ██║██████╔╝"
    echo "    ╚══════╝╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═════╝ "
    echo -e "${colorReset}"
    echo -e "    ${colorBold}${colorMagenta}⭐ Advanced Home Lab Setup Orchestrator ⭐${colorReset}"
    echo -e "    ${colorDim}Version $SCRIPT_VERSION - Intelligent System Preparation${colorReset}"
    echo ""
    echo -e "    ${colorGreen}🚀 Features:${colorReset}"
    echo -e "    ${colorDim}   • Docker & Container Management${colorReset}"
    echo -e "    ${colorDim}   • USB Auto-mounting & Storage${colorReset}"
    echo -e "    ${colorDim}   • Cloud Integration (Rclone)${colorReset}"
    echo -e "    ${colorDim}   • Automated Updates (Watchtower)${colorReset}"
    echo -e "    ${colorDim}   • Interactive Progress Tracking${colorReset}"
    echo ""
    echo -e "    ${colorYellow}⚡ Press ENTER to begin setup or Ctrl+C to cancel${colorReset}"
    read -r
    clear
}

###############################################################################
# FUNCTIONS - Define functions before they are used                          #
###############################################################################

# Enhanced printing function with logging
Show() {
    local level_num="$1"
    local message="$2"
    local timestamp=$(date '+%H:%M:%S')
    local log_level

    # Map numeric levels to log levels
    case $level_num in
    0) log_level="SUCCESS" ;;
    1) log_level="ERROR" ;;
    2) log_level="INFO" ;;
    3) log_level="WARNING" ;;
    4) log_level="WORKING" ;;
    5) log_level="DEBUG" ;;
    *) log_level="INFO" ;;
    esac

    # Check if stdout is a terminal
    if [[ -t 1 ]]; then
        case $level_num in
        0) echo -e "[${timestamp}] [\033[32m✓\033[0m] $message" ;;
        1) echo -e "[${timestamp}] [\033[31m✗\033[0m] $message" ;;
        2) echo -e "[${timestamp}] [\033[33m!\033[0m] $message" ;;
        3) echo -e "[${timestamp}] [\033[33m⚠\033[0m] $message" ;;
        4) echo -e "[${timestamp}] [\033[36m🔄\033[0m] $message" ;;
        5) echo -e "[${timestamp}] [\033[35m🐛\033[0m] $message" ;;
        *) echo -e "[${timestamp}] [\033[34mℹ\033[0m] $message" ;;
        esac
    else
        case $level_num in
        0) echo "[$timestamp] [OK] $message" ;;
        1) echo "[$timestamp] [ERROR] $message" ;;
        2) echo "[$timestamp] [INFO] $message" ;;
        3) echo "[$timestamp] [WARNING] $message" ;;
        4) echo "[$timestamp] [WORKING] $message" ;;
        5) echo "[$timestamp] [DEBUG] $message" ;;
        *) echo "[$timestamp] [INFO] $message" ;;
        esac
    fi
}

Welcome_Banner
export PATH=/usr/sbin:$PATH
export DEBIAN_FRONTEND=noninteractive

set -e

###############################################################################
# GOLBALS                                                                     #
###############################################################################

# Check if running as root or with sudo privileges
if [[ $EUID -eq 0 ]]; then
sudo_cmd=""
Show 3 "Running as root user. Some operations will be performed without sudo."
else
# Check if sudo is available and user has sudo privileges
if command -v sudo >/dev/null 2>&1; then
if sudo -n true 2>/dev/null; then
sudo_cmd="sudo"
Show 0 "Sudo privileges confirmed."
else
Show 1 "This script requires sudo privileges. Please run with sudo or as root."
Show 2 "Usage: sudo $0"
exit 1
fi
else
Show 1 "Sudo is not installed and not running as root. Please install sudo or run as root."
exit 1
fi
fi

# shellcheck source=/dev/null
source /etc/os-release

# SYSTEM REQUIREMENTS
readonly MINIMUM_DISK_SIZE_GB="5"
readonly MINIMUM_MEMORY="400"
readonly MINIMUM_DOCKER_VERSION="20"
readonly SYSTEM_DEPANDS_PACKAGE=('wget' 'curl' 'smartmontools' 'parted' 'ntfs-3g' 'net-tools' 'udevil' 'samba' 'cifs-utils' 'mergerfs' 'unzip' 'screenfetch' 'btop')
readonly SYSTEM_DEPANDS_COMMAND=('wget' 'curl' 'smartctl' 'parted' 'ntfs-3g' 'netstat' 'udevil' 'smbd' 'mount.cifs' 'mount.mergerfs' 'unzip' 'screenfetch' 'btop')

# SYSTEM INFO
PHYSICAL_MEMORY=$(LC_ALL=C free -m | awk '/Mem:/ { print $2 }')
readonly PHYSICAL_MEMORY

FREE_DISK_BYTES=$(LC_ALL=C df -P / | tail -n 1 | awk '{print $4}')
readonly FREE_DISK_BYTES

readonly FREE_DISK_GB=$((FREE_DISK_BYTES / 1024 / 1024))

LSB_DIST=$( ([ -n "${ID_LIKE}" ] && echo "${ID_LIKE}") || ([ -n "${ID}" ] && echo "${ID}"))
readonly LSB_DIST

DIST=$(echo "${ID}")
readonly DIST

UNAME_M="$(uname -m)"
readonly UNAME_M

UNAME_U="$(uname -s)"
readonly UNAME_U

# REQUIREMENTS CONF PATH
# Udevil
readonly UDEVIL_CONF_PATH=/etc/udevil/udevil.conf
readonly DEVMON_CONF_PATH=/etc/conf.d/devmon

# COLORS
readonly COLOUR_RESET='\e[0m'
readonly aCOLOUR=(
    '\e[38;5;154m' # green  	| Lines, bullets and separators
    '\e[1m'        # Bold white	| Main descriptions
    '\e[90m'       # Grey		| Credits
    '\e[91m'       # Red		| Update notifications Alert
    '\e[33m'       # Yellow		| Emphasis
)

# Enhanced Color Variables
colorRed='\033[31m'
colorGreen='\033[32m'
colorYellow='\033[33m'
colorBlue='\033[34m'
colorMagenta='\033[35m'
colorCyan='\033[36m'
colorReset='\033[0m'
colorBold='\033[1m'
colorDim='\033[2m'
colorBlink='\033[5m'
PROGRESS_CHAR="#"
PROGRESS_EMPTY="-"
PROGRESS_WIDTH=50

readonly GREEN_LINE=" ${aCOLOUR[0]}─────────────────────────────────────────────────────$COLOUR_RESET"
readonly GREEN_BULLET=" ${aCOLOUR[0]}-$COLOUR_RESET"
readonly GREEN_SEPARATOR="${aCOLOUR[0]}:$COLOUR_RESET"

# VARIABLES
REGION="UNKNOWN"

trap 'onCtrlC' INT
onCtrlC() {
    echo -e "${COLOUR_RESET}"
    exit 1
}

###############################################################################
# Enhanced Logging and Error Handling                                         #
###############################################################################

# Log file configuration
LOG_DIR="/var/log/skylab"
LOG_FILE="$LOG_DIR/skylab-$(date +%Y%m%d-%H%M%S).log"
ERROR_LOG="$LOG_DIR/skylab-errors.log"
DEBUG_MODE=${DEBUG_MODE:-false}

# Initialize logging
Init_Logging() {
    # Create log directory if it doesn't exist
    ${sudo_cmd} mkdir -p "$LOG_DIR" 2>/dev/null || {
        LOG_DIR="/tmp/skylab-logs"
        LOG_FILE="$LOG_DIR/skylab-$(date +%Y%m%d-%H%M%S).log"
        ERROR_LOG="$LOG_DIR/skylab-errors.log"
        mkdir -p "$LOG_DIR"
    }
    
    # Set proper permissions
    ${sudo_cmd} chmod 755 "$LOG_DIR" 2>/dev/null || true
    
    # Initialize log files
    echo "SkyLab Installation Log - $(date)" > "$LOG_FILE"
    echo "System: $UNAME_U $UNAME_M" >> "$LOG_FILE"
    echo "Distribution: $DIST" >> "$LOG_FILE"
    echo "Memory: ${PHYSICAL_MEMORY}MB" >> "$LOG_FILE"
    echo "Free Disk: ${FREE_DISK_GB}GB" >> "$LOG_FILE"
    echo "----------------------------------------" >> "$LOG_FILE"
}

# Enhanced logging function
Log_Message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local caller="${BASH_SOURCE[2]##*/}:${BASH_LINENO[1]}"
    
    # Log to file
    echo "[$timestamp] [$level] [$caller] $message" >> "$LOG_FILE" 2>/dev/null || true
    
    # Log errors to separate error log
    if [[ "$level" == "ERROR" || "$level" == "CRITICAL" ]]; then
        echo "[$timestamp] [$level] [$caller] $message" >> "$ERROR_LOG" 2>/dev/null || true
    fi
    
    # Debug logging
    if [[ "$DEBUG_MODE" == "true" && "$level" == "DEBUG" ]]; then
        echo "[$timestamp] [DEBUG] [$caller] $message" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# Error handling function
Handle_Error() {
    local exit_code=$?
    local line_number=$1
    local command="$2"
    
    Log_Message "ERROR" "Command failed with exit code $exit_code at line $line_number: $command"
    Show 1 "Critical error occurred. Check log file: $LOG_FILE"
    
    # Cleanup on error
    Cleanup_On_Error
    exit $exit_code
}

# Cleanup function for error scenarios
Cleanup_On_Error() {
    Log_Message "INFO" "Performing cleanup due to error..."
    
    # Stop any running Docker containers that might have been started
    if command -v docker >/dev/null 2>&1; then
        ${sudo_cmd} docker stop $(${sudo_cmd} docker ps -q) 2>/dev/null || true
    fi
    
    # Remove temporary files
    rm -f /tmp/skylab-* 2>/dev/null || true
    
    Log_Message "INFO" "Cleanup completed"
}

# Set error trap
set -eE
trap 'Handle_Error $LINENO "$BASH_COMMAND"' ERR

# Note: Show function moved to top of file to fix execution order

# Enhanced Progress Bar Function with App-level Progress
Show_Progress() {
    local current=$1
    local total=$2
    local step_name="$3"
    local app_current=${4:-0}
    local app_total=${5:-1}
    local app_name="${6:-}"
    local real_time=${7:-false}
    
    local percentage=$((current * 100 / total))
    local filled=$((current * PROGRESS_WIDTH / total))
    local empty=$((PROGRESS_WIDTH - filled))
    
    if [[ "$real_time" == "true" ]]; then
        printf "\r${colorBold}[%s] %3d%% [" "$SCRIPT_NAME"
        printf "%*s" $filled | tr ' ' "$PROGRESS_CHAR"
        printf "%*s" $empty | tr ' ' "$PROGRESS_EMPTY"
        printf "] Step %d/%d: %s${colorReset}" $current $total "$step_name"
        # Add newline for real-time display to prevent concatenation
        echo ""
        # Flush output for real-time display
        sleep 0.1
    else
        printf "\r${colorBold}[%s] %3d%% [" "$SCRIPT_NAME"
        printf "%*s" $filled | tr ' ' "$PROGRESS_CHAR"
        printf "%*s" $empty | tr ' ' "$PROGRESS_EMPTY"
        printf "] Step %d/%d: %s${colorReset}" $current $total "$step_name"
    fi
    
    # Show app-level progress if provided
    if [[ $app_total -gt 1 && -n "$app_name" ]]; then
        local app_percentage=$((app_current * 100 / app_total))
        printf "\n${colorCyan}    └─ Installing %s (%d/%d) - %d%%${colorReset}" "$app_name" $app_current $app_total $app_percentage
    fi
    
    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

# App Installation Progress Tracker
Show_App_Progress() {
    local app_name="$1"
    local current=$2
    local total=$3
    local status="$4"  # installing, success, failed
    
    local percentage=$((current * 100 / total))
    local status_icon="⏳"
    local status_color="$colorYellow"
    
    case "$status" in
        "installing")
            status_icon="⏳"
            status_color="$colorYellow"
            ;;
        "success")
            status_icon="✅"
            status_color="$colorGreen"
            ;;
        "failed")
            status_icon="❌"
            status_color="$colorRed"
            ;;
    esac
    
    printf "\r${status_color}${status_icon} [%3d%%] Installing %s...${colorReset}" $percentage "$app_name"
    
    if [[ "$status" == "success" || "$status" == "failed" ]]; then
        echo ""
    fi
}

# Interactive Step Header
Step_Header() {
    local step_num=$1
    local step_name="$2"
    echo ""
    echo -e "${colorBold}${colorCyan}╔══════════════════════════════════════════════════════════════════════════════╗${colorReset}"
    echo -e "${colorBold}${colorCyan}║${colorReset} ${colorBold}Step $step_num/$TOTAL_STEPS: $step_name${colorReset}$(printf "%*s" $((75 - ${#step_name} - ${#step_num} - 8)) "")${colorBold}${colorCyan}║${colorReset}"
    echo -e "${colorBold}${colorCyan}╚══════════════════════════════════════════════════════════════════════════════╝${colorReset}"
    Show_Progress $step_num $TOTAL_STEPS "$step_name"
    echo ""
}

# Animated Spinner for Long Operations
Spinner() {
    local pid=$1
    local message="$2"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        printf "\r${colorYellow}${spin:$i:1}${colorReset} $message"
        i=$(( (i+1) % ${#spin} ))
        sleep 0.1
    done
    printf "\r${colorGreen}✓${colorReset} $message\n"
}

Warn() {
    echo -e "${aCOLOUR[3]}$1$COLOUR_RESET"
}

GreyStart() {
    echo -e "${aCOLOUR[2]}\c"
}

ColorReset() {
    echo -e "$COLOUR_RESET\c"
}

# Clear Terminal
Clear_Term() {

    # Without an input terminal, there is no point in doing this.
    [[ -t 0 ]] || return

    # Printing terminal height - 1 newlines seems to be the fastest method that is compatible with all terminal types.
    lines=$(tput lines) i newlines
    local lines

    for ((i = 1; i < ${lines% *}; i++)); do newlines+='\n'; done
    echo -ne "\e[0m$newlines\e[H"

}

# Check file exists
exist_file() {
    if [ -e "$1" ]; then
        return 1
    else
        return 2
    fi
}

###############################################################################
# FUNCTIONS                                                                   #
###############################################################################

# 0 Get download url domain
# To solve the problem that Chinese users cannot access github.
Get_Download_Url_Domain() {
    # Use ipconfig.io/country and https://ifconfig.io/country_code to get the country code
    REGION=$(${sudo_cmd} curl --connect-timeout 2 -s ipconfig.io/country || echo "")
    if [ "${REGION}" = "" ]; then
       REGION=$(${sudo_cmd} curl --connect-timeout 2 -s https://ifconfig.io/country_code || echo "")
    fi
}

# 1 Check Arch
Check_Arch() {
    case $UNAME_M in
    *aarch64*)
        TARGET_ARCH="arm64"
        ;;
    *64*)
        TARGET_ARCH="amd64"
        ;;
    *armv7*)
        TARGET_ARCH="arm-7"
        ;;
    *)
        Show 1 "Aborted, unsupported or unknown architecture: $UNAME_M"
        exit 1
        ;;
    esac
    Show 0 "Your hardware architecture is : $UNAME_M"
}

# 2 Check Distribution
Check_Distribution() {
    sType=0
    notice=""
    case $LSB_DIST in
    *debian*) ;;

    *ubuntu*) ;;

    *raspbian*) ;;

    *openwrt*)
        Show 1 "Aborted, OpenWrt cannot be setup using this script."
        exit 1
        ;;
    *alpine*)
        Show 1 "Aborted, Alpine setup is not yet supported."
        exit 1
        ;;
    *trisquel*) ;;

    *)
        sType=3
        notice="We have not tested it on this system and it may fail to setup."
        ;;
    esac
    Show ${sType} "Your Linux Distribution is : ${DIST} ${notice}"

    if [[ ${sType} == 1 ]]; then
        select yn in "Yes" "No"; do
            case $yn in
            [yY][eE][sS] | [yY])
                Show 0 "Distribution check has been ignored."
                break
                ;;
            [nN][oO] | [nN])
                Show 1 "Already exited the setup."
                exit 1
                ;;
            esac
        done < /dev/tty # < /dev/tty is used to read the input from the terminal
    fi
}

# 3 Check OS
Check_OS() {
    if [[ $UNAME_U == *Linux* ]]; then
        Show 0 "Your System is : $UNAME_U"
    else
        Show 1 "This script is only for Linux."
        exit 1
    fi
}

# 4 Check Memory
Check_Memory() {
    if [[ "${PHYSICAL_MEMORY}" -lt "${MINIMUM_MEMORY}" ]]; then
        Show 1 "requires atleast 400MB physical memory."
        exit 1
    fi
    Show 0 "Memory capacity check passed."
}

# 5 Check Disk
Check_Disk() {
    if [[ "${FREE_DISK_GB}" -lt "${MINIMUM_DISK_SIZE_GB}" ]]; then
        echo -e "${aCOLOUR[4]}Recommended free disk space is greater than ${MINIMUM_DISK_SIZE_GB}GB, Current free disk space is ${aCOLOUR[3]}${FREE_DISK_GB}GB${COLOUR_RESET}${aCOLOUR[4]}.\nContinue setup?${COLOUR_RESET}"
        select yn in "Yes" "No"; do
            case $yn in
            [yY][eE][sS] | [yY])
                Show 0 "Disk capacity check has been ignored."
                break
                ;;
            [nN][oO] | [nN])
                Show 1 "Already exited the setup."
                exit 1
                ;;
            esac
        done < /dev/tty  # < /dev/tty is used to read the input from the terminal
    else
        Show 0 "Disk capacity check passed."
    fi
}

###############################################################################
# Configuration Validation Functions                                          #
###############################################################################

# Validate environment configuration
Validate_Environment() {
    Show 5 "Validating environment configuration..."
    
    # Check if .env file exists and validate required variables
    if [[ -f ".env" ]]; then
        Show 2 "Found .env file, validating configuration..."
        
        # Source the .env file safely
        set -a
        source .env 2>/dev/null || {
            Show 3 "Warning: Could not source .env file properly"
        }
        set +a
        
        # Validate critical environment variables
        local required_vars=("CASA_OS_VERSION" "DOCKER_COMPOSE_VERSION")
        local missing_vars=()
        
        for var in "${required_vars[@]}"; do
            if [[ -z "${!var}" ]]; then
                missing_vars+=("$var")
            fi
        done
        
        if [[ ${#missing_vars[@]} -gt 0 ]]; then
            Show 3 "Missing required environment variables: ${missing_vars[*]}"
            Show 2 "Using default values for missing variables"
        else
            Show 0 "Environment configuration validated successfully"
        fi
    else
        Show 2 "No .env file found, using default configuration"
    fi
}

# Validate system prerequisites
Validate_System_Prerequisites() {
    Show 5 "Validating system prerequisites..."
    
    local validation_errors=()
    
    # Check internet connectivity
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        validation_errors+=("No internet connectivity detected")
    fi
    
    # Check if running in container
    if [[ -f /.dockerenv ]]; then
        validation_errors+=("Running inside Docker container is not supported")
    fi
    
    # Check for conflicting services
    if systemctl is-active --quiet apache2 2>/dev/null; then
        Show 3 "Apache2 is running and may conflict with Docker services"
    fi
    
    if systemctl is-active --quiet nginx 2>/dev/null; then
        Show 3 "Nginx is running and may conflict with Docker services"
    fi
    
    # Report validation results
    if [[ ${#validation_errors[@]} -gt 0 ]]; then
        Show 1 "System validation failed:"
        for error in "${validation_errors[@]}"; do
            Show 1 "  - $error"
        done
        return 1
    else
        Show 0 "System prerequisites validation passed"
        return 0
    fi
}

# Enhanced package update with retry logic
Update_Package_Resource() {
    Show 2 "Updating package manager..."
    Log_Message "INFO" "Starting package manager update"
    
    local max_retries=3
    local retry_count=0
    local update_success=false
    
    while [[ $retry_count -lt $max_retries && $update_success == false ]]; do
        if [[ $retry_count -gt 0 ]]; then
            Show 2 "Retry attempt $retry_count/$max_retries..."
            sleep 5
        fi
        
        GreyStart
        
        if [ -x "$(command -v apk)" ]; then
            if ${sudo_cmd} apk update; then
                update_success=true
                Log_Message "SUCCESS" "APK package update successful"
            else
                Log_Message "WARNING" "APK package update failed on attempt $((retry_count + 1))"
            fi
        elif [ -x "$(command -v apt-get)" ]; then
            if ${sudo_cmd} apt-get update -qq; then
                update_success=true
                Log_Message "SUCCESS" "APT package update successful"
            else
                Log_Message "WARNING" "APT package update failed on attempt $((retry_count + 1))"
            fi
        elif [ -x "$(command -v dnf)" ]; then
            if ${sudo_cmd} dnf check-update || [[ $? -eq 100 ]]; then  # dnf returns 100 when updates are available
                update_success=true
                Log_Message "SUCCESS" "DNF package update successful"
            else
                Log_Message "WARNING" "DNF package update failed on attempt $((retry_count + 1))"
            fi
        elif [ -x "$(command -v zypper)" ]; then
            if ${sudo_cmd} zypper refresh; then
                update_success=true
                Log_Message "SUCCESS" "Zypper package update successful"
            else
                Log_Message "WARNING" "Zypper package update failed on attempt $((retry_count + 1))"
            fi
        elif [ -x "$(command -v yum)" ]; then
            if ${sudo_cmd} yum check-update || [[ $? -eq 100 ]]; then  # yum returns 100 when updates are available
                update_success=true
                Log_Message "SUCCESS" "YUM package update successful"
            else
                Log_Message "WARNING" "YUM package update failed on attempt $((retry_count + 1))"
            fi
        elif [ -x "$(command -v pacman)" ]; then
            if ${sudo_cmd} pacman -Sy; then
                update_success=true
                Log_Message "SUCCESS" "Pacman package update successful"
            else
                Log_Message "WARNING" "Pacman package update failed on attempt $((retry_count + 1))"
            fi
        else
            Show 1 "No supported package manager found"
            Log_Message "ERROR" "No supported package manager detected"
            return 1
        fi
        
        ColorReset
        retry_count=$((retry_count + 1))
    done
    
    if [[ $update_success == true ]]; then
        Show 0 "Package manager update completed successfully"
    else
        Show 3 "Package manager update failed after $max_retries attempts, continuing anyway..."
        Log_Message "WARNING" "Package update failed after all retry attempts"
    fi
}

###############################################################################
# Enhanced Dependency Management                                              #
###############################################################################

# Install dependencies with enhanced error handling and retry logic
Install_Depends() {
    Show 2 "Installing system dependencies..."
    Log_Message "INFO" "Starting dependency installation process"
    
    local failed_packages=()
    local installed_packages=()
    local skipped_packages=()
    
    local total_packages=${#SYSTEM_DEPANDS_COMMAND[@]}
    
    for ((i = 0; i < ${#SYSTEM_DEPANDS_COMMAND[@]}; i++)); do
        cmd=${SYSTEM_DEPANDS_COMMAND[i]}
        packagesNeeded=${SYSTEM_DEPANDS_PACKAGE[i]}
        
        # Update progress for current package
        local current_progress=$((i + 1))
        Show_App_Progress "$packagesNeeded" $current_progress $total_packages "installing"
        
        # Show real-time progress during installation
        Show_Progress $current_progress $total_packages "Installing $packagesNeeded" 0 1 "" true
        
        # Check if command already exists
        if [[ -x $(${sudo_cmd} which "$cmd" 2>/dev/null) ]]; then
            Show 5 "Command '$cmd' already available, skipping $packagesNeeded"
            skipped_packages+=("$packagesNeeded")
            Show_App_Progress "$packagesNeeded" $current_progress $total_packages "success"
            continue
        fi
        
        Show 4 "Installing dependency: $packagesNeeded"
        Log_Message "INFO" "Installing package: $packagesNeeded for command: $cmd"
        
        local install_success=false
        local max_retries=2
        local retry_count=0
        
        while [[ $retry_count -lt $max_retries && $install_success == false ]]; do
            if [[ $retry_count -gt 0 ]]; then
                Show 2 "Retrying installation of $packagesNeeded (attempt $((retry_count + 1))/$max_retries)..."
                # Update progress for retry attempt
                Show_Progress $current_progress $total_packages "Retrying $packagesNeeded (attempt $((retry_count + 1))/$max_retries)" 0 1 "" true
                sleep 3
            fi
            
            # Show installation attempt progress
            Show_Progress $current_progress $total_packages "Installing $packagesNeeded..." 0 1 "" true
            
            GreyStart
            
            if [ -x "$(command -v apk)" ]; then
                if ${sudo_cmd} apk add --no-cache "$packagesNeeded"; then
                    install_success=true
                fi
            elif [ -x "$(command -v apt-get)" ]; then
                if ${sudo_cmd} apt-get -y -qq install "$packagesNeeded" --no-upgrade; then
                    install_success=true
                fi
            elif [ -x "$(command -v dnf)" ]; then
                if ${sudo_cmd} dnf install -y "$packagesNeeded"; then
                    install_success=true
                fi
            elif [ -x "$(command -v zypper)" ]; then
                if ${sudo_cmd} zypper install -y "$packagesNeeded"; then
                    install_success=true
                fi
            elif [ -x "$(command -v yum)" ]; then
                if ${sudo_cmd} yum install -y "$packagesNeeded"; then
                    install_success=true
                fi
            elif [ -x "$(command -v pacman)" ]; then
                if ${sudo_cmd} pacman -S --noconfirm "$packagesNeeded"; then
                    install_success=true
                fi
            elif [ -x "$(command -v paru)" ]; then
                if ${sudo_cmd} paru -S --noconfirm "$packagesNeeded"; then
                    install_success=true
                fi
            else
                Show 1 "No supported package manager found"
                Log_Message "ERROR" "No supported package manager detected"
                failed_packages+=("$packagesNeeded")
                break
            fi
            
            ColorReset
            retry_count=$((retry_count + 1))
        done
        
        if [[ $install_success == true ]]; then
            Show 0 "Successfully installed: $packagesNeeded"
            Log_Message "SUCCESS" "Package installed successfully: $packagesNeeded"
            installed_packages+=("$packagesNeeded")
            Show_App_Progress "$packagesNeeded" $current_progress $total_packages "success"
            # Show real-time success progress
            Show_Progress $current_progress $total_packages "Successfully installed $packagesNeeded" 0 1 "" true
        else
            Show 1 "Failed to install: $packagesNeeded after $max_retries attempts"
            Log_Message "ERROR" "Package installation failed: $packagesNeeded"
            failed_packages+=("$packagesNeeded")
            Show_App_Progress "$packagesNeeded" $current_progress $total_packages "failed"
            # Show real-time failure progress
            Show_Progress $current_progress $total_packages "Failed to install $packagesNeeded" 0 1 "" true
        fi
    done
    
    # Report installation summary
    Show 2 "Dependency installation summary:"
    if [[ ${#installed_packages[@]} -gt 0 ]]; then
        Show 0 "Installed (${#installed_packages[@]}): ${installed_packages[*]}"
    fi
    if [[ ${#skipped_packages[@]} -gt 0 ]]; then
        Show 2 "Skipped (${#skipped_packages[@]}): ${skipped_packages[*]}"
    fi
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        Show 1 "Failed (${#failed_packages[@]}): ${failed_packages[*]}"
        Log_Message "ERROR" "Failed packages: ${failed_packages[*]}"
        return 1
    fi
    
    Log_Message "SUCCESS" "Dependency installation completed successfully"
    return 0
}

# Enhanced dependency verification
Check_Dependency_Installation() {
    Show 2 "Verifying dependency installation..."
    Log_Message "INFO" "Starting dependency verification"
    
    local failed_commands=()
    local verified_commands=()
    
    for ((i = 0; i < ${#SYSTEM_DEPANDS_COMMAND[@]}; i++)); do
        cmd=${SYSTEM_DEPANDS_COMMAND[i]}
        packagesNeeded=${SYSTEM_DEPANDS_PACKAGE[i]}
        
        if [[ -x $(${sudo_cmd} which "$cmd" 2>/dev/null) ]]; then
            Show 5 "✓ Command verified: $cmd"
            verified_commands+=("$cmd")
        else
            Show 1 "✗ Command not found: $cmd (package: $packagesNeeded)"
            failed_commands+=("$cmd")
        fi
    done
    
    # Report verification results
    if [[ ${#failed_commands[@]} -gt 0 ]]; then
        Show 1 "Dependency verification failed for: ${failed_commands[*]}"
        Show 2 "Please install missing dependencies manually and run the script again."
        Log_Message "ERROR" "Dependency verification failed: ${failed_commands[*]}"
        return 1
    else
        Show 0 "All dependencies verified successfully (${#verified_commands[@]} commands)"
        Log_Message "SUCCESS" "All dependencies verified: ${verified_commands[*]}"
        return 0
    fi
}

###############################################################################
# System Health Monitoring                                                    #
###############################################################################

# System health check function
Perform_Health_Check() {
    Show 2 "Performing system health check..."
    Log_Message "INFO" "Starting system health check"
    
    local health_issues=()
    local health_warnings=()
    
    # Check disk space
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $disk_usage -gt 90 ]]; then
        health_issues+=("Disk usage is critically high: ${disk_usage}%")
    elif [[ $disk_usage -gt 80 ]]; then
        health_warnings+=("Disk usage is high: ${disk_usage}%")
    fi
    
    # Check memory usage
    local mem_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    if [[ $mem_usage -gt 95 ]]; then
        health_issues+=("Memory usage is critically high: ${mem_usage}%")
    elif [[ $mem_usage -gt 85 ]]; then
        health_warnings+=("Memory usage is high: ${mem_usage}%")
    fi
    
    # Check system load
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local cpu_cores=$(nproc)
    if (( $(echo "$load_avg > $cpu_cores * 2" | bc -l) )); then
        health_warnings+=("System load is high: $load_avg (cores: $cpu_cores)")
    fi
    
    # Check for zombie processes
    local zombie_count=$(ps aux | awk '$8 ~ /^Z/ { count++ } END { print count+0 }')
    if [[ $zombie_count -gt 0 ]]; then
        health_warnings+=("Found $zombie_count zombie processes")
    fi
    
    # Report health status
    if [[ ${#health_issues[@]} -gt 0 ]]; then
        Show 1 "Critical health issues detected:"
        for issue in "${health_issues[@]}"; do
            Show 1 "  - $issue"
            Log_Message "ERROR" "Health issue: $issue"
        done
        return 1
    elif [[ ${#health_warnings[@]} -gt 0 ]]; then
        Show 3 "Health warnings detected:"
        for warning in "${health_warnings[@]}"; do
            Show 3 "  - $warning"
            Log_Message "WARNING" "Health warning: $warning"
        done
        return 0
    else
        Show 0 "System health check passed"
        Log_Message "SUCCESS" "System health check completed successfully"
        return 0
    fi
}

Check_Dependency_Installation() {
    local failed_packages=()
    for ((i = 0; i < ${#SYSTEM_DEPANDS_COMMAND[@]}; i++)); do
        cmd=${SYSTEM_DEPANDS_COMMAND[i]}
        if [[ ! -x $(${sudo_cmd} which "$cmd" 2>/dev/null) ]]; then
            packagesNeeded=${SYSTEM_DEPANDS_PACKAGE[i]}
            failed_packages+=("$packagesNeeded")
        fi
    done
    
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        Show 1 "The following dependencies failed to install: ${failed_packages[*]}"
        Show 2 "Please install them manually and run the script again."
        exit 1
    else
        Show 0 "All system dependencies installed successfully."
    fi
}

# Check Docker running
Check_Docker_Running() {
    for ((i = 1; i <= 3; i++)); do
        sleep 3
        if [[ ! $(${sudo_cmd} systemctl is-active docker) == "active" ]]; then
            Show 1 "Docker is not running, try to start"
            ${sudo_cmd} systemctl start docker
        else
            break
        fi
    done
}

#Check Docker Installed and version
Check_Docker_Install() {
    if [[ -x "$(command -v docker)" ]]; then
        Docker_Version=$(${sudo_cmd} docker version --format '{{.Server.Version}}')
        if [[ $? -ne 0 ]]; then
            Install_Docker
        elif [[ ${Docker_Version:0:2} -lt "${MINIMUM_DOCKER_VERSION}" ]]; then
            Show 1 "Recommended minimum Docker version is \e[33m${MINIMUM_DOCKER_VERSION}.xx.xx\e[0m,\Current Docker version is \e[33m${Docker_Version}\e[0m,\nPlease uninstall current Docker and rerun the setup script."
            exit 1
        else
            Show 0 "Current Docker version is ${Docker_Version}."
        fi
    else
        Install_Docker
    fi
}

# Check Docker installed
Check_Docker_Install_Final() {
    if [[ -x "$(command -v docker)" ]]; then
        Docker_Version=$(${sudo_cmd} docker version --format '{{.Server.Version}}')
        if [[ $? -ne 0 ]]; then
            Install_Docker
        elif [[ ${Docker_Version:0:2} -lt "${MINIMUM_DOCKER_VERSION}" ]]; then
            Show 1 "Recommended minimum Docker version is \e[33m${MINIMUM_DOCKER_VERSION}.xx.xx\e[0m,\Current Docker version is \e[33m${Docker_Version}\e[0m,\nPlease uninstall current Docker and rerun the setup script."
            exit 1
        else
            Show 0 "Current Docker version is ${Docker_Version}."
            Check_Docker_Running
        fi
    else
        Show 1 "Installation failed, please run 'curl -fsSL https://get.docker.com | bash' and rerun the setup script."
        exit 1
    fi
}

#Install Docker
Install_Docker() {
  Show 2 "Install the necessary dependencies: \e[33mDocker \e[0m"
  if [[ ! -d "${PREFIX}/etc/apt/sources.list.d" ]]; then
      ${sudo_cmd} mkdir -p "${PREFIX}/etc/apt/sources.list.d"
  fi
  
  # Ensure proper permissions for Docker installation
  ${sudo_cmd} chmod 755 "${PREFIX}/etc/apt/sources.list.d" 2>/dev/null || true
  
  # Create a temporary file for the installation output with proper permissions
  local temp_file=$(mktemp)
  chmod 644 "$temp_file" 2>/dev/null || true
  
  # Run the installation in the background
  if [[ "${REGION}" = "China" ]] || [[ "${REGION}" = "CN" ]]; then
    (${sudo_cmd} curl -fsSL https://play.cuse.eu.org/get_docker.sh | bash -s docker --mirror Aliyun > "$temp_file" 2>&1) &
  else
    (${sudo_cmd} curl -fsSL https://get.docker.com | bash > "$temp_file" 2>&1) &
  fi
  
  # Get the process ID
  local pid=$!
  
  # Show spinner while Docker is installing
  Spinner $pid "Installing Docker Engine and CLI tools..."
  
  # Check if the installation was successful
  wait $pid
  if [ $? -ne 0 ]; then
    Show 1 "Docker installation failed. See details below:"
    cat "$temp_file"
    rm -f "$temp_file"
    exit 1
  fi
  
  rm -f "$temp_file"
  
  # Add current user to docker group if not root
  if [[ $EUID -ne 0 ]] && [[ -n "$SUDO_USER" ]]; then
    Show 4 "Adding user $SUDO_USER to docker group..."
    ${sudo_cmd} usermod -aG docker "$SUDO_USER" || {
      Show 3 "Failed to add user to docker group. You may need to log out and back in."
    }
    Show 2 "Note: You may need to log out and back in for docker group membership to take effect."
  elif [[ $EUID -ne 0 ]]; then
    current_user=$(whoami)
    Show 4 "Adding user $current_user to docker group..."
    ${sudo_cmd} usermod -aG docker "$current_user" || {
      Show 3 "Failed to add user to docker group. You may need to log out and back in."
    }
    Show 2 "Note: You may need to log out and back in for docker group membership to take effect."
  fi
  
  # Ensure Docker socket has proper permissions
  if [[ -S "/var/run/docker.sock" ]]; then
    Show 4 "Setting Docker socket permissions..."
    ${sudo_cmd} chmod 666 /var/run/docker.sock 2>/dev/null || {
      Show 3 "Could not modify Docker socket permissions - this may be normal"
    }
  fi
  
  Check_Docker_Install_Final
}

#Install Rclone
Install_rclone_from_source() {
  Show 4 "Downloading Rclone installer..."
  # Create temporary directory with proper permissions
  local temp_dir=$(mktemp -d)
  cd "$temp_dir" || {
    Show 1 "Failed to create temporary directory for Rclone installation"
    exit 1
  }
  
  ${sudo_cmd} wget -qO ./install.sh https://rclone.org/install.sh || {
    Show 1 "Failed to download Rclone installer"
    cd - >/dev/null
    rm -rf "$temp_dir"
    exit 1
  }
  
  # Modify download source based on region
  if [[ "${REGION}" = "China" ]] || [[ "${REGION}" = "CN" ]]; then
    Show 4 "Using optimized download source for your region..."
    sed -i 's/downloads.rclone.org/get.homelabos.io/g' ./install.sh
  else
    Show 4 "Using standard download source..."
    # Keep original download source for better reliability
    # sed -i 's/downloads.rclone.org/get.homelabos.io/g' ./install.sh
  fi
  
  ${sudo_cmd} chmod +x ./install.sh
  
  # Create a temporary file for the installation output with proper permissions
  local temp_file=$(mktemp)
  chmod 644 "$temp_file" 2>/dev/null || true
  
  # Run the installation in the background
  (${sudo_cmd} ./install.sh > "$temp_file" 2>&1) &
  
  # Get the process ID
  local pid=$!
  
  # Show spinner while Rclone is installing
  Spinner $pid "Installing Rclone cloud storage client..."
  
  # Check if the installation was successful
  wait $pid
  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    Show 1 "Rclone installation failed with exit code $exit_code. See details below:"
    cat "$temp_file"
    
    # Try fallback installation method
    Show 3 "Attempting fallback installation method..."
    if Install_rclone_fallback; then
      Show 0 "Rclone installed successfully using fallback method."
    else
      ${sudo_cmd} rm -rf install.sh
      rm -f "$temp_file"
      Show 1 "Both primary and fallback Rclone installation methods failed."
      Show 3 "You can manually install Rclone later using: curl https://rclone.org/install.sh | sudo bash"
      return 1
    fi
  fi
  
  rm -f "$temp_file"
  
  # Clean up temporary directory
  cd - >/dev/null
  rm -rf "$temp_dir"
  Show 0 "Rclone v1.61.1 installed successfully."
}

# Fallback Rclone installation method
Install_rclone_fallback() {
  Show 4 "Trying alternative Rclone installation method..."
  
  # Try direct download and installation
  local arch="$(uname -m)"
  local os="linux"
  local rclone_version="v1.61.1"
  
  case "$arch" in
    x86_64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    armv7l) arch="arm" ;;
    *) 
      Show 1 "Unsupported architecture: $arch"
      return 1
      ;;
  esac
  
  local download_url="https://downloads.rclone.org/${rclone_version}/rclone-${rclone_version}-${os}-${arch}.zip"
  local temp_dir=$(mktemp -d)
  
  Show 4 "Downloading Rclone ${rclone_version} for ${os}-${arch}..."
  
  cd "$temp_dir" || return 1
  
  if ${sudo_cmd} wget -q "$download_url" -O rclone.zip; then
    Show 4 "Extracting Rclone..."
    if ${sudo_cmd} unzip -q rclone.zip; then
      local rclone_dir="rclone-${rclone_version}-${os}-${arch}"
      if [[ -d "$rclone_dir" ]]; then
        Show 4 "Installing Rclone binary..."
        ${sudo_cmd} cp "$rclone_dir/rclone" /usr/local/bin/
        ${sudo_cmd} chmod +x /usr/local/bin/rclone
        
        # Install man page if available
        if [[ -f "$rclone_dir/rclone.1" ]]; then
          ${sudo_cmd} mkdir -p /usr/local/share/man/man1
          ${sudo_cmd} cp "$rclone_dir/rclone.1" /usr/local/share/man/man1/
        fi
        
        cd - >/dev/null
        rm -rf "$temp_dir"
        
        # Verify installation
        if command -v rclone >/dev/null 2>&1; then
          Show 0 "Rclone fallback installation completed successfully."
          return 0
        else
          Show 1 "Rclone binary installed but not found in PATH."
          return 1
        fi
      else
        Show 1 "Rclone extraction directory not found."
        cd - >/dev/null
        rm -rf "$temp_dir"
        return 1
      fi
    else
      Show 1 "Failed to extract Rclone archive."
      cd - >/dev/null
      rm -rf "$temp_dir"
      return 1
    fi
  else
    Show 1 "Failed to download Rclone from fallback source."
    cd - >/dev/null
    rm -rf "$temp_dir"
    return 1
  fi
}

Install_Rclone() {
  Show 2 "Setting up Rclone cloud storage integration..."
  if [[ -x "$(command -v rclone)" ]]; then
    version=$(rclone --version 2>>errors | head -n 1)
    target_version="rclone v1.61.1"
    rclone1="${PREFIX}/usr/share/man/man1/rclone.1.gz"
    if [ "$version" != "$target_version" ]; then
      Show 3 "Updating Rclone from $version to $target_version..."
      rclone_path=$(command -v rclone)
      ${sudo_cmd} rm -rf "${rclone_path}"
      if [[ -f "$rclone1" ]]; then
        ${sudo_cmd} rm -rf "$rclone1"
      fi
      if ! Install_rclone_from_source; then
        Show 3 "Rclone installation failed, but continuing with setup..."
        return 1
      fi
    else
      Show 0 "Rclone $target_version already installed."
    fi
  else
    Show 4 "Rclone not found, installing..."
    if ! Install_rclone_from_source; then
      Show 3 "Rclone installation failed, but continuing with setup..."
      return 1
    fi
  fi
  
  # Enable Rclone service if available
  Show 4 "Configuring Rclone service..."
  if ${sudo_cmd} systemctl enable rclone 2>/dev/null; then
    Show 0 "Rclone service enabled successfully."
  else 
    Show 3 "Rclone systemd service not available - this is normal on some distributions."
  fi
  
  # Verify Rclone installation
  if rclone --version > /dev/null 2>&1; then
    Show 0 "Rclone installation verified successfully."
  else
    Show 3 "Rclone installation verification failed. You may need to restart your terminal."
  fi
}

#Install LazyDocker
Install_LazyDocker() {
  Show 2 "Installing LazyDocker terminal UI..."
  if [[ -x "$(command -v lazydocker)" ]]; then
    Show 2 "LazyDocker already installed."
  else
    # Create a temporary file for the installation output with proper permissions
    local temp_file=$(mktemp)
    chmod 644 "$temp_file" 2>/dev/null || true
    
    # Run the installation in the background
    (${sudo_cmd} curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash > "$temp_file" 2>&1) &
    
    # Get the process ID
    local pid=$!
    
    # Show spinner while LazyDocker is installing
    Spinner $pid "Downloading and installing LazyDocker..."
    
    # Check if the installation was successful
    wait $pid
    if [ $? -ne 0 ]; then
      Show 1 "LazyDocker installation failed. See details below:"
      cat "$temp_file"
      rm -f "$temp_file"
      exit 1
    fi
    
    rm -f "$temp_file"
    Show 0 "LazyDocker installed successfully."
  fi
}

#Install Watchtower
Install_Watchtower() {
  Show 2 "Setting up Watchtower auto-update service..."
  if ${sudo_cmd} docker ps -a --format "table {{.Names}}" | grep -q "watchtower"; then
    Show 2 "Watchtower container already exists."
    
    # Check if it's running
    if ! ${sudo_cmd} docker ps --format "table {{.Names}}" | grep -q "watchtower"; then
      Show 3 "Watchtower container exists but is not running. Starting it..."
      ${sudo_cmd} docker start watchtower
      Show 0 "Watchtower container started."
    fi
  else
    Show 4 "Pulling Watchtower image..."
    ${sudo_cmd} docker pull containrrr/watchtower > /dev/null 2>&1 &
    local pull_pid=$!
    Spinner $pull_pid "Downloading Watchtower container image..."
    wait $pull_pid
    
    Show 4 "Creating and starting Watchtower container..."
    ${sudo_cmd} docker run -d \
      --name watchtower \
      --restart unless-stopped \
      -v /var/run/docker.sock:/var/run/docker.sock \
      containrrr/watchtower --cleanup --interval 86400 || {
      Show 1 "Watchtower installation failed, please try again."
      exit 1
    }
    
    # Verify it's running
    if ${sudo_cmd} docker ps --format "table {{.Names}}" | grep -q "watchtower"; then
      Show 0 "Watchtower installed and running successfully."
      Show 2 "Configured to check for updates daily and clean up old images."
    else
      Show 1 "Watchtower container created but failed to start."
      exit 1
    fi
  fi
}

#Install Filebrowser
Install_Filebrowser() {
  Show 2 "Setting up Filebrowser web file manager..."
  
  # Check if Filebrowser container already exists
  if ${sudo_cmd} docker ps -a --format "table {{.Names}}" | grep -q "filebrowser"; then
    Show 2 "Filebrowser container already exists."
    
    # Check if it's running
    if ! ${sudo_cmd} docker ps --format "table {{.Names}}" | grep -q "filebrowser"; then
      Show 3 "Filebrowser container exists but is not running. Starting it..."
      ${sudo_cmd} docker start filebrowser
      Show 0 "Filebrowser container started."
    fi
  else
    # Create directories for Filebrowser with proper permissions
    Show 4 "Creating Filebrowser directories..."
    ${sudo_cmd} mkdir -p /data/appdata/filebrowser/config
    ${sudo_cmd} mkdir -p /data/appdata/filebrowser/data
    
    # Set proper ownership and permissions
    ${sudo_cmd} chmod 755 /data/appdata/filebrowser
    ${sudo_cmd} chmod 755 /data/appdata/filebrowser/config
    ${sudo_cmd} chmod 755 /data/appdata/filebrowser/data
    
    # If not running as root, try to set ownership to current user
    if [[ $EUID -ne 0 ]] && [[ -n "$SUDO_USER" ]]; then
      ${sudo_cmd} chown -R "$SUDO_USER:$SUDO_USER" /data/appdata/filebrowser 2>/dev/null || {
        Show 3 "Could not change ownership of /data/appdata/filebrowser to $SUDO_USER"
      }
    fi
    
    Show 4 "Pulling Filebrowser image..."
    ${sudo_cmd} docker pull filebrowser/filebrowser > /dev/null 2>&1 &
    local pull_pid=$!
    Spinner $pull_pid "Downloading Filebrowser container image..."
    wait $pull_pid
    
    Show 4 "Creating and starting Filebrowser container..."
    ${sudo_cmd} docker run -d \
      --name filebrowser \
      --restart unless-stopped \
      -p 8080:80 \
      -v /data/appdata/filebrowser/config:/config \
      -v /data/appdata/filebrowser/data:/srv \
      -v /:/mnt/host:ro \
      filebrowser/filebrowser || {
      Show 1 "Filebrowser installation failed, please try again."
      exit 1
    }
    
    # Verify it's running
    if ${sudo_cmd} docker ps --format "table {{.Names}}" | grep -q "filebrowser"; then
      Show 0 "Filebrowser installed and running successfully."
      Show 2 "Access at: http://localhost:8080"
      Show 3 "Default login: admin/admin (Change this immediately!)"
    else
      Show 1 "Filebrowser container created but failed to start."
      exit 1
    fi
  fi
}

# Install PiVPN (Containerized OpenVPN Server)
Install_AdGuard() {
    Show 2 "Setting up AdGuard Home (DNS Ad Blocker)..."
    
    # Load configuration values with defaults
    local adguard_port=${ADGUARD_PORT:-3000}
    local adguard_dns_port=${ADGUARD_DNS_PORT:-53}
    local adguard_data_dir=${ADGUARD_DATA_DIR:-/data/appdata/adguard/data}
    local adguard_config_dir=${ADGUARD_CONFIG_DIR:-/data/appdata/adguard/config}
    local adguard_work_dir=${ADGUARD_WORK_DIR:-/data/appdata/adguard/work}
    local adguard_version=${ADGUARD_VERSION:-latest}
    
    # Check if container already exists
    if ${sudo_cmd} docker ps -a --format "table {{.Names}}" | grep -q "adguard"; then
        Show 2 "AdGuard Home container already exists."
        
        # Check if it's running
        if ! ${sudo_cmd} docker ps --format "table {{.Names}}" | grep -q "adguard"; then
            Show 3 "AdGuard Home container exists but is not running. Starting it..."
            ${sudo_cmd} docker start adguard
            Show 0 "AdGuard Home container started."
        fi
    else
        # Create directories with proper permissions
        Show 4 "Creating AdGuard Home directories..."
        ${sudo_cmd} mkdir -p /data/appdata/adguard
        ${sudo_cmd} mkdir -p "$adguard_data_dir"
        ${sudo_cmd} mkdir -p "$adguard_config_dir"
        ${sudo_cmd} mkdir -p "$adguard_work_dir"
        ${sudo_cmd} chmod 755 /data/appdata/adguard
        ${sudo_cmd} chmod 755 "$adguard_data_dir"
        ${sudo_cmd} chmod 755 "$adguard_config_dir"
        ${sudo_cmd} chmod 755 "$adguard_work_dir"
        
        # Set ownership if not root
        if [[ $EUID -ne 0 ]] && [[ -n "$SUDO_USER" ]]; then
            ${sudo_cmd} chown -R "$SUDO_USER:$SUDO_USER" /data/appdata/adguard 2>/dev/null || {
                Show 3 "Could not change ownership of /data/appdata/adguard to $SUDO_USER"
            }
        fi
        
        # Pull and run AdGuard Home container
        Show 4 "Pulling AdGuard Home image..."
        ${sudo_cmd} docker pull adguard/adguardhome:$adguard_version > /dev/null 2>&1 &
        local pull_pid=$!
        Spinner $pull_pid "Downloading AdGuard Home container image..."
        wait $pull_pid
        
        Show 4 "Creating and starting AdGuard Home container..."
        ${sudo_cmd} docker run -d \
            --name adguard \
            --restart unless-stopped \
            -p $adguard_port:3000/tcp \
            -p $adguard_dns_port:53/tcp \
            -p $adguard_dns_port:53/udp \
            -v "$adguard_config_dir:/opt/adguardhome/conf" \
            -v "$adguard_work_dir:/opt/adguardhome/work" \
            adguard/adguardhome:$adguard_version || {
            Show 1 "AdGuard Home installation failed, please try again."
            exit 1
        }
        
        # Wait for container to initialize
        Show 4 "Waiting for AdGuard Home to initialize..."
        sleep 15
        
        # Verify installation
        if ${sudo_cmd} docker ps --format "table {{.Names}}" | grep -q "adguard"; then
            Show 0 "AdGuard Home installed and running successfully."
            
            # Get server IP for setup instructions
            local server_ip=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')
            if [[ -z "$server_ip" ]]; then
                server_ip=$(hostname -I | awk '{print $1}')
            fi
            
            Show 2 "AdGuard Home web interface available at: http://$server_ip:$adguard_port"
            Show 2 "DNS server configured on port: $adguard_dns_port"
            Show 3 "Complete the initial setup through the web interface."
        else
            Show 1 "AdGuard Home container created but failed to start."
            exit 1
        fi
    fi
}

#Configuration Addons
Configuration_Addons() {
    Show 2 "Configuration System Addons"
    #Remove old udev rules
    if [[ -f "${PREFIX}/etc/udev/rules.d/11-usb-mount.rules" ]]; then
        ${sudo_cmd} rm -rf "${PREFIX}/etc/udev/rules.d/11-usb-mount.rules"
    fi

    if [[ -f "${PREFIX}/etc/systemd/system/usb-mount@.service" ]]; then
        ${sudo_cmd} rm -rf "${PREFIX}/etc/systemd/system/usb-mount@.service"
    fi

    #Udevil
    if [[ -f $PREFIX${UDEVIL_CONF_PATH} ]]; then

        # GreyStart
        # Add a devmon user with proper error handling
        USERNAME=devmon
        if ! id ${USERNAME} &>/dev/null; then
            Show 4 "Creating devmon user for USB auto-mounting..."
            ${sudo_cmd} useradd -M -u 300 ${USERNAME} 2>/dev/null || {
                # If UID 300 is taken, let system assign one
                ${sudo_cmd} useradd -M ${USERNAME} 2>/dev/null || {
                    Show 3 "User devmon may already exist or creation failed"
                }
            }
            ${sudo_cmd} usermod -L ${USERNAME} 2>/dev/null || true
        else
            Show 2 "User devmon already exists"
        fi

        # Configure udevil with proper error handling
        Show 4 "Configuring udevil for USB auto-mounting..."
        ${sudo_cmd} sed -i '/exfat/s/, nonempty//g' "$PREFIX"${UDEVIL_CONF_PATH} 2>/dev/null || {
            Show 3 "Could not modify exfat options in udevil.conf"
        }
        ${sudo_cmd} sed -i '/default_options/s/, noexec//g' "$PREFIX"${UDEVIL_CONF_PATH} 2>/dev/null || {
            Show 3 "Could not modify default_options in udevil.conf"
        }
        
        # Configure devmon if config file exists
        if [[ -f "$PREFIX"${DEVMON_CONF_PATH} ]]; then
            ${sudo_cmd} sed -i '/^ARGS/cARGS="--mount-options nosuid,nodev,noatime --ignore-label EFI"' "$PREFIX"${DEVMON_CONF_PATH} 2>/dev/null || {
                Show 3 "Could not modify devmon configuration"
            }
        fi

        # Add and start Devmon service with error handling
        Show 4 "Enabling and starting devmon service..."
        GreyStart
        ${sudo_cmd} systemctl enable devmon@devmon 2>/dev/null || {
            Show 3 "Could not enable devmon service - this may be normal on some systems"
        }
        ${sudo_cmd} systemctl start devmon@devmon 2>/dev/null || {
            Show 3 "Could not start devmon service - this may be normal on some systems"
        }
        ColorReset
        # ColorReset
    fi
}

# Install SkyLab Homepage
Install_Homepage() {
    Show 2 "Installing SkyLab Homepage Dashboard..."
    
    local homepage_dir="${APP_DATA_BASE_DIR:-/data/appdata}/homepage"
    local homepage_port=${HOMEPAGE_PORT:-8888}
    
    # Create homepage directory
    Show 4 "Creating homepage directory..."
    ${sudo_cmd} mkdir -p "$homepage_dir"
    ${sudo_cmd} chmod 755 "$homepage_dir"
    
    # Set ownership if not root
    if [[ $EUID -ne 0 ]] && [[ -n "$SUDO_USER" ]]; then
        ${sudo_cmd} chown -R "$SUDO_USER:$SUDO_USER" "$homepage_dir" 2>/dev/null || {
            Show 3 "Could not change ownership of $homepage_dir to $SUDO_USER"
        }
    fi
    
    # Check if homepage files exist in the script directory
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$script_dir/homepage/index.html" ]]; then
        Show 4 "Copying homepage files..."
        ${sudo_cmd} cp -r "$script_dir/homepage/"* "$homepage_dir/" 2>/dev/null || {
            Show 3 "Could not copy homepage files"
        }
        ${sudo_cmd} chmod +x "$homepage_dir/server.py" 2>/dev/null || true
    else
        Show 4 "Creating default homepage..."
        # Create a simple default homepage if files don't exist
        cat > "$homepage_dir/index.html" << 'EOF'
<!DOCTYPE html>
<html><head><title>SkyLab Dashboard</title></head>
<body style="font-family: monospace; background: #000; color: #0f0; padding: 20px;">
<h1>🚀 SkyLab Command Center</h1>
<p>Your homelab services:</p>
<ul>
<li><a href="http://localhost:8080" style="color: #0ff;">Filebrowser</a></li>
<li><a href="http://localhost:3000" style="color: #0ff;">AdGuard Home</a></li>
<li><a href="http://localhost:9000" style="color: #0ff;">Portainer</a></li>
</ul>
</body></html>
EOF
    fi
    
    # Check if homepage container already exists
    if ${sudo_cmd} docker ps -a --format "table {{.Names}}" | grep -q "skylab-homepage"; then
        Show 2 "SkyLab Homepage container already exists."
        
        # Check if it's running
        if ! ${sudo_cmd} docker ps --format "table {{.Names}}" | grep -q "skylab-homepage"; then
            Show 3 "Homepage container exists but is not running. Starting it..."
            ${sudo_cmd} docker start skylab-homepage
            Show 0 "Homepage container started."
        fi
    else
        Show 4 "Creating and starting homepage container..."
        ${sudo_cmd} docker run -d \
            --name skylab-homepage \
            --restart unless-stopped \
            -p $homepage_port:80 \
            -v "$homepage_dir:/usr/share/nginx/html:ro" \
            nginx:alpine || {
            Show 3 "Homepage container creation failed, but continuing..."
            return 0
        }
        
        # Wait for container to initialize
        Show 4 "Waiting for homepage to initialize..."
        sleep 5
        
        # Verify installation
        if ${sudo_cmd} docker ps --format "table {{.Names}}" | grep -q "skylab-homepage"; then
            Show 0 "SkyLab Homepage installed and running successfully."
            
            # Get server IP for access instructions
            local server_ip=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')
            if [[ -z "$server_ip" ]]; then
                server_ip=$(hostname -I | awk '{print $1}')
            fi
            
            Show 2 "Homepage available at: http://$server_ip:$homepage_port"
            Show 2 "Local access: http://localhost:$homepage_port"
        else
            Show 3 "Homepage container created but may not be running properly."
        fi
    fi
}

# Show completion banner
Completion_Banner() {
    clear
    echo -e "${colorCyan}${colorBold}"
    echo "    ███████╗██╗  ██╗██╗   ██╗██╗      █████╗ ██████╗ "
    echo "    ██╔════╝██║ ██╔╝╚██╗ ██╔╝██║     ██╔══██╗██╔══██╗"
    echo "    ███████╗█████╔╝  ╚████╔╝ ██║     ███████║██████╔╝"
    echo "    ╚════██║██╔═██╗   ╚██╔╝  ██║     ██╔══██║██╔══██╗"
    echo "    ███████║██║  ██╗   ██║   ███████╗██║  ██║██████╔╝"
    echo "    ╚══════╝╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═════╝ "
    echo -e "${colorReset}"
    
    echo -e "${colorGreen}${colorBold}╔══════════════════════════════════════════════════════════════════════════════╗${colorReset}"
    echo -e "${colorGreen}${colorBold}║${colorReset}${colorBold} 🎉 SETUP COMPLETE! Your home lab environment is ready!${colorReset}$(printf "%*s" 25 "")${colorGreen}${colorBold}║${colorReset}"
    echo -e "${colorGreen}${colorBold}╚══════════════════════════════════════════════════════════════════════════════╝${colorReset}"
    
    echo -e "\n${colorBold}${colorMagenta}✅ INSTALLED COMPONENTS:${colorReset}"
    echo -e "   ${colorGreen}•${colorReset} Docker Engine ${colorDim}(Container runtime)${colorReset}"
    echo -e "   ${colorGreen}•${colorReset} USB Auto-mounting ${colorDim}(udevil/devmon)${colorReset}"
    echo -e "   ${colorGreen}•${colorReset} System Dependencies ${colorDim}(curl, wget, net-tools, etc.)${colorReset}"
    echo -e "   ${colorGreen}•${colorReset} Rclone ${colorDim}(Cloud storage integration)${colorReset}"
    echo -e "   ${colorGreen}•${colorReset} LazyDocker ${colorDim}(Terminal UI for Docker)${colorReset}"
    echo -e "   ${colorGreen}•${colorReset} Watchtower ${colorDim}(Automatic container updates)${colorReset}"
    echo -e "   ${colorGreen}•${colorReset} Filebrowser ${colorDim}(Web-based file management)${colorReset}"
    echo -e "   ${colorGreen}•${colorReset} AdGuard Home ${colorDim}(DNS Ad Blocker)${colorReset}"
    echo -e "   ${colorGreen}•${colorReset} SkyLab Homepage ${colorDim}(Homelab dashboard)${colorReset}"
    
    echo -e "\n${colorBold}${colorYellow}🚀 NEXT STEPS:${colorReset}"
    echo -e "   ${colorBlue}1.${colorReset} Access SkyLab Dashboard: ${colorDim}http://localhost:8888${colorReset}"
    echo -e "   ${colorBlue}2.${colorReset} Access Filebrowser: ${colorDim}http://localhost:8080 (admin/admin)${colorReset}"
    echo -e "   ${colorBlue}3.${colorReset} Access AdGuard Home: ${colorDim}http://localhost:3000${colorReset}"
    echo -e "   ${colorBlue}4.${colorReset} Configure DNS settings: ${colorDim}Point devices to this server's IP:53${colorReset}"
    echo -e "   ${colorBlue}5.${colorReset} Start LazyDocker: ${colorDim}lazydocker${colorReset}"
    echo -e "   ${colorBlue}6.${colorReset} Check Docker status: ${colorDim}docker ps${colorReset}"
    
    echo -e "\n${colorBold}${colorCyan}📚 USEFUL COMMANDS:${colorReset}"
    echo -e "   ${colorGreen}•${colorReset} ${colorDim}docker ps${colorReset} - List running containers"
    echo -e "   ${colorGreen}•${colorReset} ${colorDim}docker-compose up -d${colorReset} - Start services defined in docker-compose.yml"
    echo -e "   ${colorGreen}•${colorReset} ${colorDim}lazydocker${colorReset} - Open the Docker management UI"
    echo -e "   ${colorGreen}•${colorReset} ${colorDim}rclone config${colorReset} - Configure cloud storage connections"
    echo -e "   ${colorGreen}•${colorReset} ${colorDim}http://localhost:8888${colorReset} - Access SkyLab homepage dashboard"
    echo -e "   ${colorGreen}•${colorReset} ${colorDim}http://localhost:8080${colorReset} - Access Filebrowser web interface"
    echo -e "   ${colorGreen}•${colorReset} ${colorDim}docker logs adguard${colorReset} - View AdGuard Home logs"
    echo -e "   ${colorGreen}•${colorReset} ${colorDim}http://localhost:3000${colorReset} - Access AdGuard Home web interface"
    
    echo -e "\n${colorBold}${colorGreen}💖 Thank you for using SkyLab! ${colorReset}${colorDim}(v$SCRIPT_VERSION)${colorReset}"
    echo -e "${colorDim}For issues and feedback: https://github.com/yourusername/skylab${colorReset}"
    echo -e "\n"
}

###############################################################################
# Main                                                                        #
###############################################################################

#Usage
usage() {
    cat <<-EOF
		Usage: homelab-setup.sh [options]
		Valid options are:
		    -h                      Show this help message and exit
	EOF
    exit "$1"
}

while getopts ":h" arg; do
    case "$arg" in
    h)
        usage 0
        ;;
    *)
        usage 1
        ;;
    esac
done
# Pre-flight permission and environment checks
Show 2 "Performing pre-flight checks..."

# Check if we can write to common system directories
if [[ ! -w "/tmp" ]]; then
    Show 1 "Cannot write to /tmp directory. Please check permissions."
    exit 1
fi

# Test sudo functionality if not root
if [[ $EUID -ne 0 ]]; then
    if ! ${sudo_cmd} true 2>/dev/null; then
        Show 1 "Sudo authentication failed. Please ensure you have sudo privileges."
        exit 1
    fi
fi

# Check if running in a supported shell
if [[ -z "$BASH_VERSION" ]]; then
    Show 1 "This script requires Bash. Please run with: bash $0"
    exit 1
fi

Show 0 "Pre-flight checks completed successfully."

# Initialize enhanced logging system
Init_Logging
Show 0 "Logging system initialized. Log file: $LOG_FILE"

# Validate environment and system prerequisites
Show 2 "Running enhanced system validation..."
Validate_Environment
if ! Validate_System_Prerequisites; then
    Show 1 "System validation failed. Please resolve the issues above before continuing."
    exit 1
fi

# Perform initial health check
if ! Perform_Health_Check; then
    Show 3 "System health check detected issues. Continuing with installation but monitor system resources."
fi

# Main execution flow with interactive progress
echo -e "${GREEN_LINE}"
echo -e " ${GREEN_BULLET} Starting $SCRIPT_NAME System Setup..."
echo -e "${GREEN_LINE}"

# Step 1: Get Download URL Domain
Step_Header 1 "Configuring Download Sources"
Show_Progress 1 $TOTAL_STEPS "Configuring Download Sources" 0 1 "" true
Get_Download_Url_Domain
Show_Progress 1 $TOTAL_STEPS "Download Sources Configured" 0 1 "" true

# Step 2: Check Architecture
Step_Header 2 "Validating System Architecture"
Show_Progress 2 $TOTAL_STEPS "Validating System Architecture" 0 1 "" true
Check_Arch
Show_Progress 2 $TOTAL_STEPS "System Architecture Validated" 0 1 "" true

# Step 3: Check OS and Distribution
Step_Header 3 "Detecting Operating System"
Show_Progress 3 $TOTAL_STEPS "Detecting Operating System" 0 1 "" true
Check_OS
Check_Distribution

# Step 4: Check System Requirements
Step_Header 4 "Verifying System Requirements"
Show 4 "Checking memory requirements..."
Check_Memory
Show 4 "Checking disk space requirements..."
Check_Disk

# Step 5: Update Package Lists
Step_Header 5 "Updating Package Repositories"
Update_Package_Resource

# Enhanced Installation with App Progress Tracking
APPS_TO_INSTALL=("Dependencies" "Docker" "System-Config" "Rclone" "LazyDocker" "Watchtower" "Filebrowser" "AdGuard" "Homepage")
TOTAL_APPS=${#APPS_TO_INSTALL[@]}

# Step 6: Install Dependencies
Step_Header 6 "Installing System Dependencies"
Show_App_Progress "System Dependencies" 1 $TOTAL_APPS "installing"
Install_Depends
Check_Dependency_Installation
Show_App_Progress "System Dependencies" 1 $TOTAL_APPS "success"

# Step 7: Install Docker
Step_Header 7 "Installing Docker Engine"
Show_App_Progress "Docker Engine" 2 $TOTAL_APPS "installing"
Check_Docker_Install
Show_App_Progress "Docker Engine" 2 $TOTAL_APPS "success"

# Step 8: Configuration Addons
Step_Header 8 "Configuring System Addons"
Show_App_Progress "System Configuration" 3 $TOTAL_APPS "installing"
Configuration_Addons
Show_App_Progress "System Configuration" 3 $TOTAL_APPS "success"

# Step 9: Install Rclone
Step_Header 9 "Installing Rclone Cloud Storage"
Show_App_Progress "Rclone" 4 $TOTAL_APPS "installing"
if Install_Rclone; then
  Show_App_Progress "Rclone" 4 $TOTAL_APPS "success"
else
  Show_App_Progress "Rclone" 4 $TOTAL_APPS "failed"
  Show 3 "Rclone installation failed, but continuing with other components..."
fi

# Step 10: Install LazyDocker
Step_Header 10 "Installing LazyDocker Management UI"
Show_App_Progress "LazyDocker" 5 $TOTAL_APPS "installing"
Install_LazyDocker
Show_App_Progress "LazyDocker" 5 $TOTAL_APPS "success"

# Step 11: Install Watchtower
Step_Header 11 "Installing Watchtower Auto-Updater"
Show_App_Progress "Watchtower" 6 $TOTAL_APPS "installing"
Install_Watchtower
Show_App_Progress "Watchtower" 6 $TOTAL_APPS "success"

# Step 12: Install Filebrowser
Step_Header 12 "Installing Filebrowser Web File Manager"
Show_App_Progress "Filebrowser" 7 $TOTAL_APPS "installing"
Install_Filebrowser
Show_App_Progress "Filebrowser" 7 $TOTAL_APPS "success"

# Step 13: Install AdGuard Home
Step_Header 13 "Installing AdGuard Home (DNS Ad Blocker)"
Show_App_Progress "AdGuard Home" 8 $TOTAL_APPS "installing"
Install_AdGuard
Show_App_Progress "AdGuard Home" 8 $TOTAL_APPS "success"

# Step 14: Install SkyLab Homepage
Step_Header 14 "Installing SkyLab Homepage Dashboard"
Show_App_Progress "Homepage Dashboard" 9 $TOTAL_APPS "installing"
Install_Homepage
Show_App_Progress "Homepage Dashboard" 9 $TOTAL_APPS "success"

# Step 15: Final System Health Check
Step_Header 15 "Performing Final System Health Check"
Show 4 "Running post-installation health check..."
if Perform_Health_Check; then
    Show 0 "✅ All systems operational and healthy!"
else
    Show 3 "⚠️  Some health check warnings detected. System is functional but may need attention."
fi

# Log installation summary
Log_Message "INFO" "SkyLab installation completed successfully"
Log_Message "INFO" "Installation log saved to: $LOG_FILE"
Show 0 "Installation completed! Check $LOG_FILE for detailed logs."

# Final Step: Show Completion Banner
Completion_Banner
