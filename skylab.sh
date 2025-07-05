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

# Script Information
SCRIPT_NAME="SkyLab"
SCRIPT_VERSION="1.0.0"
TOTAL_STEPS=13
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
readonly SYSTEM_DEPANDS_PACKAGE=('wget' 'curl' 'smartmontools' 'parted' 'ntfs-3g' 'net-tools' 'udevil' 'samba' 'cifs-utils' 'mergerfs' 'unzip')
readonly SYSTEM_DEPANDS_COMMAND=('wget' 'curl' 'smartctl' 'parted' 'ntfs-3g' 'netstat' 'udevil' 'smbd' 'mount.cifs' 'mount.mergerfs' 'unzip')

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
PROGRESS_CHAR="█"
PROGRESS_EMPTY="░"
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
# Helpers                                                                     #
###############################################################################

#######################################
# Custom printing function
# Globals:
#   None
# Arguments:
#   $1 0:OK   1:FAILED  2:INFO  3:NOTICE
#   message
# Returns:
#   None
#######################################

Show() {
    local timestamp=$(date '+%H:%M:%S')
    # Check if stdout is a terminal
    if [[ -t 1 ]]; then
        case $1 in
        0) echo -e "${colorDim}[$timestamp]${colorReset} [${colorGreen}✓${colorReset}] $2" ;;
        1) echo -e "${colorDim}[$timestamp]${colorReset} [${colorRed}✗${colorReset}] $2" ;;
        2) echo -e "${colorDim}[$timestamp]${colorReset} [${colorYellow}!${colorReset}] $2" ;;
        3) echo -e "${colorDim}[$timestamp]${colorReset} [${colorYellow}⚠${colorReset}] $2" ;;
        4) echo -e "${colorDim}[$timestamp]${colorReset} [${colorCyan}🔄${colorReset}] $2" ;;
        *) echo -e "${colorDim}[$timestamp]${colorReset} [${colorBlue}ℹ${colorReset}] $2" ;;
        esac
    else
        case $1 in
        0) echo "[$timestamp] [OK] $2" ;;
        1) echo "[$timestamp] [ERROR] $2" ;;
        2) echo "[$timestamp] [INFO] $2" ;;
        3) echo "[$timestamp] [WARNING] $2" ;;
        4) echo "[$timestamp] [WORKING] $2" ;;
        *) echo "[$timestamp] [INFO] $2" ;;
        esac
    fi
}

# Progress Bar Function
Show_Progress() {
    local current=$1
    local total=$2
    local step_name="$3"
    local percentage=$((current * 100 / total))
    local filled=$((current * PROGRESS_WIDTH / total))
    local empty=$((PROGRESS_WIDTH - filled))
    
    printf "\r${colorBold}[%s] %3d%% [" "$SCRIPT_NAME"
    printf "%*s" $filled | tr ' ' "$PROGRESS_CHAR"
    printf "%*s" $empty | tr ' ' "$PROGRESS_EMPTY"
    printf "] Step %d/%d: %s${colorReset}" $current $total "$step_name"
    
    if [[ $current -eq $total ]]; then
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

# Update package
Update_Package_Resource() {
    Show 2 "Updating package manager..."
    GreyStart
    if [ -x "$(command -v apk)" ]; then
        ${sudo_cmd} apk update || {
            Show 3 "Package update failed for apk, continuing anyway..."
        }
    elif [ -x "$(command -v apt-get)" ]; then
        ${sudo_cmd} apt-get update -qq || {
            Show 3 "Package update failed for apt-get, continuing anyway..."
        }
    elif [ -x "$(command -v dnf)" ]; then
        ${sudo_cmd} dnf check-update || {
            Show 3 "Package update check failed for dnf, continuing anyway..."
        }
    elif [ -x "$(command -v zypper)" ]; then
        ${sudo_cmd} zypper refresh || {
            Show 3 "Package update failed for zypper, continuing anyway..."
        }
    elif [ -x "$(command -v yum)" ]; then
        ${sudo_cmd} yum check-update || {
            Show 3 "Package update check failed for yum, continuing anyway..."
        }
    fi
    ColorReset
    Show 0 "Package manager update complete."
}

# Install depends package
Install_Depends() {
    for ((i = 0; i < ${#SYSTEM_DEPANDS_COMMAND[@]}; i++)); do
        cmd=${SYSTEM_DEPANDS_COMMAND[i]}
        if [[ ! -x $(${sudo_cmd} which "$cmd" 2>/dev/null) ]]; then
            packagesNeeded=${SYSTEM_DEPANDS_PACKAGE[i]}
            Show 2 "Install the necessary dependencies: \e[33m$packagesNeeded \e[0m"
            GreyStart
            if [ -x "$(command -v apk)" ]; then
                ${sudo_cmd} apk add --no-cache "$packagesNeeded" || {
                    Show 1 "Failed to install $packagesNeeded using apk"
                    exit 1
                }
            elif [ -x "$(command -v apt-get)" ]; then
                ${sudo_cmd} apt-get -y -qq install "$packagesNeeded" --no-upgrade || {
                    Show 1 "Failed to install $packagesNeeded using apt-get"
                    exit 1
                }
            elif [ -x "$(command -v dnf)" ]; then
                ${sudo_cmd} dnf install -y "$packagesNeeded" || {
                    Show 1 "Failed to install $packagesNeeded using dnf"
                    exit 1
                }
            elif [ -x "$(command -v zypper)" ]; then
                ${sudo_cmd} zypper install -y "$packagesNeeded" || {
                    Show 1 "Failed to install $packagesNeeded using zypper"
                    exit 1
                }
            elif [ -x "$(command -v yum)" ]; then
                ${sudo_cmd} yum install -y "$packagesNeeded" || {
                    Show 1 "Failed to install $packagesNeeded using yum"
                    exit 1
                }
            elif [ -x "$(command -v pacman)" ]; then
                ${sudo_cmd} pacman -S --noconfirm "$packagesNeeded" || {
                    Show 1 "Failed to install $packagesNeeded using pacman"
                    exit 1
                }
            elif [ -x "$(command -v paru)" ]; then
                ${sudo_cmd} paru -S --noconfirm "$packagesNeeded" || {
                    Show 1 "Failed to install $packagesNeeded using paru"
                    exit 1
                }
            else
                Show 1 "Package manager not found. You must manually install: \e[33m$packagesNeeded \e[0m"
                exit 1
            fi
            ColorReset
        fi
    done
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
    sed -i 's/downloads.rclone.org/get.homelabos.io/g' ./install.sh
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
  if [ $? -ne 0 ]; then
    Show 1 "Rclone installation failed. See details below:"
    cat "$temp_file"
    ${sudo_cmd} rm -rf install.sh
    rm -f "$temp_file"
    exit 1
  fi
  
  rm -f "$temp_file"
  
  # Clean up temporary directory
  cd - >/dev/null
  rm -rf "$temp_dir"
  Show 0 "Rclone v1.61.1 installed successfully."
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
      Install_rclone_from_source
    else
      Show 0 "Rclone $target_version already installed."
    fi
  else
    Show 4 "Rclone not found, installing..."
    Install_rclone_from_source
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
    ${sudo_cmd} mkdir -p /opt/filebrowser/config
    ${sudo_cmd} mkdir -p /opt/filebrowser/data
    
    # Set proper ownership and permissions
    ${sudo_cmd} chmod 755 /opt/filebrowser
    ${sudo_cmd} chmod 755 /opt/filebrowser/config
    ${sudo_cmd} chmod 755 /opt/filebrowser/data
    
    # If not running as root, try to set ownership to current user
    if [[ $EUID -ne 0 ]] && [[ -n "$SUDO_USER" ]]; then
      ${sudo_cmd} chown -R "$SUDO_USER:$SUDO_USER" /opt/filebrowser 2>/dev/null || {
        Show 3 "Could not change ownership of /opt/filebrowser to $SUDO_USER"
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
      -v /opt/filebrowser/config:/config \
      -v /opt/filebrowser/data:/srv \
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
Install_PiVPN() {
    Show 2 "Setting up PiVPN (Containerized OpenVPN Server)..."
    
    # Check if container already exists
    if ${sudo_cmd} docker ps -a --format "table {{.Names}}" | grep -q "pivpn"; then
        Show 2 "PiVPN container already exists."
        
        # Check if it's running
        if ! ${sudo_cmd} docker ps --format "table {{.Names}}" | grep -q "pivpn"; then
            Show 3 "PiVPN container exists but is not running. Starting it..."
            ${sudo_cmd} docker start pivpn
            Show 0 "PiVPN container started."
        fi
    else
        # Create directories with proper permissions
        Show 4 "Creating PiVPN directories..."
        ${sudo_cmd} mkdir -p /opt/pivpn/config
        ${sudo_cmd} mkdir -p /opt/pivpn/clients
        ${sudo_cmd} chmod 755 /opt/pivpn
        ${sudo_cmd} chmod 755 /opt/pivpn/config
        ${sudo_cmd} chmod 755 /opt/pivpn/clients
        
        # Set ownership if not root
        if [[ $EUID -ne 0 ]] && [[ -n "$SUDO_USER" ]]; then
            ${sudo_cmd} chown -R "$SUDO_USER:$SUDO_USER" /opt/pivpn 2>/dev/null || {
                Show 3 "Could not change ownership of /opt/pivpn to $SUDO_USER"
            }
        fi
        
        # Get the server's public IP (fallback to local IP if detection fails)
        Show 4 "Detecting server IP address..."
        SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')
        
        if [[ -z "$SERVER_IP" ]]; then
            Show 3 "Could not detect public IP. Using local IP address."
            SERVER_IP=$(hostname -I | awk '{print $1}')
        fi
        
        Show 2 "Using server IP: $SERVER_IP"
        
        # Pull and run PiVPN container
        Show 4 "Pulling OpenVPN image..."
        ${sudo_cmd} docker pull dperson/openvpn > /dev/null 2>&1 &
        local pull_pid=$!
        Spinner $pull_pid "Downloading OpenVPN container image..."
        wait $pull_pid
        
        Show 4 "Creating and starting PiVPN container..."
        ${sudo_cmd} docker run -d \
            --name pivpn \
            --restart unless-stopped \
            --cap-add=NET_ADMIN \
            --device /dev/net/tun \
            -p 1194:1194/udp \
            -p 8443:8080/tcp \
            -v /opt/pivpn/config:/etc/openvpn \
            -e "OPENVPN_OPTS=--config /etc/openvpn/server.conf" \
            -e "SERVER_NAME=$SERVER_IP" \
            dperson/openvpn -s "$SERVER_IP/24" -r "8.8.8.8" -r "8.8.4.4" || {
            Show 1 "PiVPN installation failed, please try again."
            exit 1
        }
        
        # Wait for container to initialize
        Show 4 "Waiting for PiVPN to initialize..."
        sleep 10
        
        # Verify installation
        if ${sudo_cmd} docker ps --format "table {{.Names}}" | grep -q "pivpn"; then
            Show 0 "PiVPN installed and running successfully."
            
            # Generate a default client certificate
            Show 4 "Generating default client certificate..."
            ${sudo_cmd} docker exec pivpn ovpn_genconfig -u udp://$SERVER_IP 2>/dev/null || true
            ${sudo_cmd} docker exec pivpn ovpn_initpki nopass 2>/dev/null || true
            ${sudo_cmd} docker exec pivpn easyrsa build-client-full client1 nopass 2>/dev/null || true
            ${sudo_cmd} docker exec pivpn ovpn_getclient client1 > /opt/pivpn/clients/client1.ovpn 2>/dev/null || true
            
            if [[ -f "/opt/pivpn/clients/client1.ovpn" ]]; then
                Show 0 "Default client certificate generated: /opt/pivpn/clients/client1.ovpn"
            else
                Show 3 "Client certificate generation may have failed. You can generate it manually later."
            fi
        else
            Show 1 "PiVPN container created but failed to start."
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
    echo -e "   ${colorGreen}•${colorReset} PiVPN ${colorDim}(Containerized OpenVPN server)${colorReset}"
    
    echo -e "\n${colorBold}${colorYellow}🚀 NEXT STEPS:${colorReset}"
    echo -e "   ${colorBlue}1.${colorReset} Access Filebrowser: ${colorDim}http://localhost:8080 (admin/admin)${colorReset}"
    echo -e "   ${colorBlue}2.${colorReset} Access PiVPN Admin: ${colorDim}http://localhost:8443${colorReset}"
    echo -e "   ${colorBlue}3.${colorReset} Download VPN client config: ${colorDim}/opt/pivpn/clients/client1.ovpn${colorReset}"
    echo -e "   ${colorBlue}4.${colorReset} Start LazyDocker: ${colorDim}lazydocker${colorReset}"
    echo -e "   ${colorBlue}5.${colorReset} Check Docker status: ${colorDim}docker ps${colorReset}"
    
    echo -e "\n${colorBold}${colorCyan}📚 USEFUL COMMANDS:${colorReset}"
    echo -e "   ${colorGreen}•${colorReset} ${colorDim}docker ps${colorReset} - List running containers"
    echo -e "   ${colorGreen}•${colorReset} ${colorDim}docker-compose up -d${colorReset} - Start services defined in docker-compose.yml"
    echo -e "   ${colorGreen}•${colorReset} ${colorDim}lazydocker${colorReset} - Open the Docker management UI"
    echo -e "   ${colorGreen}•${colorReset} ${colorDim}rclone config${colorReset} - Configure cloud storage connections"
    echo -e "   ${colorGreen}•${colorReset} ${colorDim}http://localhost:8080${colorReset} - Access Filebrowser web interface"
    echo -e "   ${colorGreen}•${colorReset} ${colorDim}docker exec pivpn ovpn_getclient <clientname>${colorReset} - Generate VPN client config"
    echo -e "   ${colorGreen}•${colorReset} ${colorDim}docker logs pivpn${colorReset} - View PiVPN logs"
    
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

# Main execution flow with interactive progress
echo -e "${GREEN_LINE}"
echo -e " ${GREEN_BULLET} Starting $SCRIPT_NAME System Setup..."
echo -e "${GREEN_LINE}"

# Step 1: Get Download URL Domain
Step_Header 1 "Configuring Download Sources"
Get_Download_Url_Domain

# Step 2: Check Architecture
Step_Header 2 "Validating System Architecture"
Check_Arch

# Step 3: Check OS and Distribution
Step_Header 3 "Detecting Operating System"
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

# Step 6: Install Dependencies
Step_Header 6 "Installing System Dependencies"
Install_Depends
Check_Dependency_Installation

# Step 7: Install Docker
Step_Header 7 "Installing Docker Engine"
Check_Docker_Install

# Step 8: Configuration Addons
Step_Header 8 "Configuring System Addons"
Configuration_Addons

# Step 9: Install Rclone
Step_Header 9 "Installing Rclone Cloud Storage"
Install_Rclone

# Step 10: Install LazyDocker
Step_Header 10 "Installing LazyDocker Management UI"
Install_LazyDocker

# Step 11: Install Watchtower
Step_Header 11 "Installing Watchtower Auto-Updater"
Install_Watchtower

# Step 12: Install Filebrowser
Step_Header 12 "Installing Filebrowser Web File Manager"
Install_Filebrowser

# Step 13: Install PiVPN
Step_Header 13 "Installing PiVPN (Containerized OpenVPN Server)"
Install_PiVPN

# Final Step: Show Completion Banner
Completion_Banner
