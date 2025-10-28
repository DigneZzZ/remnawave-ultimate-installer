#!/usr/bin/env bash
# Global Configuration for Remnawave Ultimate Installer

# =============================================================================
# VERSION INFORMATION
# =============================================================================

readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="Remnawave Ultimate Installer"
readonly GITHUB_REPO="DigneZzZ/remnawave-scripts"
readonly GITHUB_BRANCH="main"
readonly PROJECT_DIR="remnawave-ultimate-installer"

# =============================================================================
# PATHS & DIRECTORIES
# =============================================================================

# Base directories
readonly BASE_DIR="/opt/remnawave"
readonly PANEL_DIR="$BASE_DIR/panel"
readonly NODE_DIR="$BASE_DIR/node"
readonly NGINX_DIR="$BASE_DIR/nginx"
readonly CADDY_DIR="$BASE_DIR/caddy"
readonly SELFSTEAL_DIR="$BASE_DIR/selfsteal"
readonly BACKUP_DIR="$BASE_DIR/backups"
readonly LOG_DIR="$BASE_DIR/logs"
readonly TMP_DIR="/tmp/remnawave-installer"

# Configuration files
readonly ENV_FILE="$BASE_DIR/.env"
readonly INSTALL_INFO="$BASE_DIR/install_info.json"

# =============================================================================
# LOGGING CONFIGURATION
# =============================================================================

# Installer logging
INSTALLER_LOG_FILE="${INSTALLER_LOG_FILE:-/var/log/remnawave-installer.log}"
INSTALLER_LOG_ENABLED="${INSTALLER_LOG_ENABLED:-true}"
INSTALLER_DEBUG="${INSTALLER_DEBUG:-false}"

# Log levels
readonly LOG_LEVEL_DEBUG="DEBUG"
readonly LOG_LEVEL_INFO="INFO"
readonly LOG_LEVEL_WARNING="WARNING"
readonly LOG_LEVEL_ERROR="ERROR"
readonly LOG_LEVEL_FATAL="FATAL"

# =============================================================================
# DEFAULT PORTS
# =============================================================================

readonly DEFAULT_PANEL_PORT="3000"
readonly DEFAULT_NODE_PORT="8000"
readonly DEFAULT_XRAY_PORT="443"
readonly DEFAULT_SELFSTEAL_PORT="9443"
readonly DEFAULT_NGINX_PORT="80"
readonly DEFAULT_NGINX_SSL_PORT="443"
readonly DEFAULT_CADDY_PORT="80"
readonly DEFAULT_CADDY_SSL_PORT="443"
readonly DEFAULT_EMERGENCY_PORT="8443"

# =============================================================================
# DOCKER CONFIGURATION
# =============================================================================

readonly DOCKER_NETWORK="remnawave-network"
readonly PANEL_CONTAINER="remnawave-panel"
readonly NODE_CONTAINER="remnawave-node"
readonly DB_CONTAINER="remnawave-db"
readonly REDIS_CONTAINER="remnawave-redis"
readonly NGINX_CONTAINER="remnawave-nginx"
readonly CADDY_CONTAINER="remnawave-caddy"
readonly SELFSTEAL_CONTAINER="caddy-selfsteal"

# Docker images
readonly PANEL_IMAGE="ghcr.io/remnawave/backend"
readonly NODE_IMAGE="ghcr.io/remnawave/node"
readonly DB_IMAGE="postgres:17.6-alpine"
readonly REDIS_IMAGE="valkey/valkey:8.0-alpine"
readonly NGINX_IMAGE="nginx:alpine"
readonly CADDY_IMAGE="caddy:2.9.1-alpine"

# =============================================================================
# DEFAULT CREDENTIALS
# =============================================================================

readonly DEFAULT_ADMIN_USERNAME="admin"
readonly DEFAULT_DB_NAME="remnawave"
readonly DEFAULT_DB_USER="remnawave"

# =============================================================================
# INSTALLATION OPTIONS
# =============================================================================

# Installation types
readonly INSTALL_TYPE_PANEL="panel"
readonly INSTALL_TYPE_NODE="node"
readonly INSTALL_TYPE_ALL_IN_ONE="all-in-one"
readonly INSTALL_TYPE_SELFSTEAL="selfsteal"

# Reverse proxy options
readonly PROXY_NGINX="nginx"
readonly PROXY_CADDY="caddy"

# Security levels
readonly SECURITY_BASIC="basic"
readonly SECURITY_COOKIE="cookie-auth"
readonly SECURITY_FULL="full-auth"

# SSL providers
readonly SSL_LETSENCRYPT="letsencrypt"
readonly SSL_CLOUDFLARE="cloudflare"
readonly SSL_CERTWARDEN="certwarden"
readonly SSL_SELF_SIGNED="self-signed"

# =============================================================================
# FEATURES & INTEGRATIONS
# =============================================================================

# Available integrations
readonly INTEGRATION_WARP="warp"
readonly INTEGRATION_BESZEL="beszel"
readonly INTEGRATION_GRAFANA="grafana"
readonly INTEGRATION_PROMETHEUS="prometheus"
readonly INTEGRATION_NETBIRD="netbird"
readonly INTEGRATION_CERTWARDEN="certwarden"

# =============================================================================
# RUNTIME VARIABLES
# =============================================================================

# Current configuration (will be set during installation)
CURRENT_INSTALL_TYPE=""
CURRENT_REVERSE_PROXY=""
CURRENT_SECURITY_LEVEL=""
CURRENT_SSL_PROVIDER=""
CURRENT_DOMAIN=""
CURRENT_SERVER_IP=""

# Feature flags
ENABLE_XRAY=false
ENABLE_SELFSTEAL=false
ENABLE_WARP=false
ENABLE_BESZEL=false
ENABLE_GRAFANA=false
ENABLE_PROMETHEUS=false
ENABLE_NETBIRD=false
ENABLE_CERTWARDEN=false

# Backup configuration
BACKUP_ENABLED=false
BACKUP_SCHEDULE="0 3 * * *"
BACKUP_RETENTION=7
TELEGRAM_NOTIFICATIONS=false

# Language
CURRENT_LANGUAGE="ru"

# Debug mode
DEBUG_MODE=false

# Docker image version (latest or dev)
DOCKER_IMAGE_TAG="latest"

# =============================================================================
# SYSTEM REQUIREMENTS
# =============================================================================

readonly MIN_DISK_SPACE_GB=5
readonly MIN_MEMORY_GB=1
readonly RECOMMENDED_MEMORY_GB=2

# Required commands
readonly REQUIRED_COMMANDS=(
    "docker"
    "curl"
    "openssl"
)

# =============================================================================
# URLS & ENDPOINTS
# =============================================================================

readonly REMNAWAVE_DOCS="https://docs.remnawave.com"
readonly REMNAWAVE_GITHUB="https://github.com/remnawave"
readonly INSTALLER_GITHUB="https://github.com/$GITHUB_REPO"

# Update URLs
readonly UPDATE_CHECK_URL="https://raw.githubusercontent.com/$GITHUB_REPO/$GITHUB_BRANCH/$PROJECT_DIR/version.txt"
readonly SCRIPT_DOWNLOAD_URL="https://raw.githubusercontent.com/$GITHUB_REPO/$GITHUB_BRANCH/$PROJECT_DIR/dist/remnawave-ultimate.sh"

# Management scripts URLs
readonly REMNAWAVE_SCRIPT_URL="https://raw.githubusercontent.com/$GITHUB_REPO/$GITHUB_BRANCH/remnawave.sh"
readonly REMNANODE_SCRIPT_URL="https://raw.githubusercontent.com/$GITHUB_REPO/$GITHUB_BRANCH/remnanode.sh"
readonly SELFSTEAL_SCRIPT_URL="https://raw.githubusercontent.com/$GITHUB_REPO/$GITHUB_BRANCH/selfsteal.sh"

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Load environment variables from .env file
load_env_file() {
    if [ -f "$ENV_FILE" ]; then
        set -a
        source "$ENV_FILE"
        set +a
        return 0
    fi
    return 1
}

# Save installation info to JSON
save_install_info() {
    local install_type="$1"
    local reverse_proxy="$2"
    local security_level="$3"
    local domain="$4"
    
    cat > "$INSTALL_INFO" << EOF
{
    "version": "$SCRIPT_VERSION",
    "install_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "install_type": "$install_type",
    "reverse_proxy": "$reverse_proxy",
    "security_level": "$security_level",
    "domain": "$domain",
    "server_ip": "$CURRENT_SERVER_IP",
    "features": {
        "xray": $ENABLE_XRAY,
        "selfsteal": $ENABLE_SELFSTEAL,
        "warp": $ENABLE_WARP,
        "beszel": $ENABLE_BESZEL,
        "grafana": $ENABLE_GRAFANA,
        "prometheus": $ENABLE_PROMETHEUS,
        "netbird": $ENABLE_NETBIRD
    }
}
EOF
}

# Load installation info from JSON
load_install_info() {
    if [ -f "$INSTALL_INFO" ] && command -v jq >/dev/null 2>&1; then
        CURRENT_INSTALL_TYPE=$(jq -r '.install_type' "$INSTALL_INFO")
        CURRENT_REVERSE_PROXY=$(jq -r '.reverse_proxy' "$INSTALL_INFO")
        CURRENT_SECURITY_LEVEL=$(jq -r '.security_level' "$INSTALL_INFO")
        CURRENT_DOMAIN=$(jq -r '.domain' "$INSTALL_INFO")
        CURRENT_SERVER_IP=$(jq -r '.server_ip' "$INSTALL_INFO")
        return 0
    fi
    return 1
}

# Check if component is installed
is_installed() {
    local component="$1"
    
    case "$component" in
        panel)
            [ -d "$PANEL_DIR" ] && docker ps -q -f name="$PANEL_CONTAINER" >/dev/null 2>&1
            ;;
        node)
            [ -d "$NODE_DIR" ] && docker ps -q -f name="$NODE_CONTAINER" >/dev/null 2>&1
            ;;
        nginx)
            [ -d "$NGINX_DIR" ] && docker ps -q -f name="$NGINX_CONTAINER" >/dev/null 2>&1
            ;;
        caddy)
            [ -d "$CADDY_DIR" ] && docker ps -q -f name="$CADDY_CONTAINER" >/dev/null 2>&1
            ;;
        selfsteal)
            [ -d "$SELFSTEAL_DIR" ] && docker ps -q -f name="$SELFSTEAL_CONTAINER" >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

# Get server public IP
get_server_ip() {
    CURRENT_SERVER_IP=$(curl -s -4 ifconfig.io 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null || echo "unknown")
}

# Install management script to /usr/local/bin
install_management_script() {
    local script_name="$1"
    local script_url="$2"
    local target_path="/usr/local/bin/$script_name"
    
    display_step "Установка $script_name..."
    
    if curl -sSL "$script_url" -o "$target_path"; then
        chmod +x "$target_path"
        display_success "$script_name установлен в $target_path"
        return 0
    else
        display_error "Ошибка установки $script_name"
        return 1
    fi
}

# Install remnawave management script
install_remnawave_script() {
    install_management_script "remnawave" "$REMNAWAVE_SCRIPT_URL"
}

# Install remnanode management script
install_remnanode_script() {
    install_management_script "remnanode" "$REMNANODE_SCRIPT_URL"
}

# Install selfsteal management script
install_selfsteal_script() {
    install_management_script "selfsteal" "$SELFSTEAL_SCRIPT_URL"
}

# =============================================================================
# EXPORTS
# =============================================================================

export -f load_env_file
export -f save_install_info
export -f load_install_info
export -f is_installed
export -f get_server_ip
export -f install_management_script
export -f install_remnawave_script
export -f install_remnanode_script
export -f install_selfsteal_script

# Initialize configuration
init_config() {
    # Get server IP
    CURRENT_SERVER_IP=$(get_server_ip)
    
    # Create base directory if not exists
    mkdir -p "$BASE_DIR"
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$TMP_DIR"
    
    # Try to load existing config
    load_install_info
}

# Export all configuration
export SCRIPT_VERSION SCRIPT_NAME GITHUB_REPO GITHUB_BRANCH PROJECT_DIR
export BASE_DIR PANEL_DIR NODE_DIR NGINX_DIR CADDY_DIR SELFSTEAL_DIR BACKUP_DIR LOG_DIR TMP_DIR
export ENV_FILE INSTALL_INFO
export DEFAULT_PANEL_PORT DEFAULT_NODE_PORT DEFAULT_XRAY_PORT DEFAULT_SELFSTEAL_PORT
export DEFAULT_NGINX_PORT DEFAULT_NGINX_SSL_PORT DEFAULT_CADDY_PORT DEFAULT_CADDY_SSL_PORT
export DOCKER_NETWORK PANEL_CONTAINER NODE_CONTAINER DB_CONTAINER REDIS_CONTAINER
export NGINX_CONTAINER CADDY_CONTAINER SELFSTEAL_CONTAINER
export PANEL_IMAGE NODE_IMAGE DB_IMAGE REDIS_IMAGE NGINX_IMAGE CADDY_IMAGE
export INSTALL_TYPE_PANEL INSTALL_TYPE_NODE INSTALL_TYPE_ALL_IN_ONE INSTALL_TYPE_SELFSTEAL
export PROXY_NGINX PROXY_CADDY
export SECURITY_BASIC SECURITY_COOKIE SECURITY_FULL
export SSL_LETSENCRYPT SSL_CLOUDFLARE SSL_CERTWARDEN SSL_SELF_SIGNED
export MIN_DISK_SPACE_GB MIN_MEMORY_GB RECOMMENDED_MEMORY_GB
export REMNAWAVE_DOCS REMNAWAVE_GITHUB INSTALLER_GITHUB
export UPDATE_CHECK_URL SCRIPT_DOWNLOAD_URL

export -f load_env_file
export -f save_install_info
export -f load_install_info
export -f is_installed
export -f get_server_ip
export -f init_config
