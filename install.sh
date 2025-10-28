#!/usr/bin/env bash
# Remnawave Ultimate Installer - Entry Point
# Version: 1.0.0
# Author: DigneZzZ
# Description: Universal installer for Remnawave Panel/Node with NGINX or Caddy

set -e

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "\033[0;31m❌ This script must be run as root\033[0m"
    echo -e "\033[0;37m   Please run: sudo bash install.sh\033[0m"
    exit 1
fi

# Check if source directory exists
if [ ! -d "$SRC_DIR" ]; then
    echo -e "\033[0;31m❌ Source directory not found: $SRC_DIR\033[0m"
    echo -e "\033[0;37m   Please run from the repository root\033[0m"
    exit 1
fi

# Load modules in correct order
echo "Loading Remnawave Ultimate Installer..."

# 1. Configuration
source "$SRC_DIR/config.sh"

# 2. Core modules
source "$SRC_DIR/core/colors.sh"
source "$SRC_DIR/core/display.sh"
source "$SRC_DIR/core/validation.sh"

# 3. Library modules
source "$SRC_DIR/lib/crypto.sh"
source "$SRC_DIR/lib/http.sh"
source "$SRC_DIR/lib/input.sh"
source "$SRC_DIR/lib/backup.sh"
source "$SRC_DIR/lib/logging.sh"
source "$SRC_DIR/lib/docker.sh"
source "$SRC_DIR/lib/api.sh"
source "$SRC_DIR/lib/panel-api.sh"
source "$SRC_DIR/lib/user-api.sh"
source "$SRC_DIR/lib/xray-config.sh"

# 4. Integration modules
source "$SRC_DIR/integrations/warp.sh"
source "$SRC_DIR/integrations/netbird.sh"

# 4. Reverse proxy providers
source "$SRC_DIR/providers/caddy/install.sh"
source "$SRC_DIR/providers/caddy/config.sh"
source "$SRC_DIR/providers/nginx/install.sh"
source "$SRC_DIR/providers/nginx/config.sh"
source "$SRC_DIR/providers/nginx/ssl.sh"

# 5. Installation modules
source "$SRC_DIR/modules/panel/install.sh"
source "$SRC_DIR/modules/node/install.sh"
source "$SRC_DIR/modules/all-in-one/install.sh"

# 6. Main menu
source "$SRC_DIR/main.sh"

# Start the installer
init_config
show_main_menu "$@"
