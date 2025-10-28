#!/usr/bin/env bash
# Remnawave Ultimate Installer - Entry Point
# Version: 1.0.0
# Author: DigneZzZ
# Description: Universal installer for Remnawave Panel/Node with NGINX or Caddy

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
source "$SRC_DIR/config.sh" || { echo "Failed to load config.sh"; exit 1; }

# 2. Core modules
source "$SRC_DIR/core/colors.sh" || { echo "Failed to load colors.sh"; exit 1; }
source "$SRC_DIR/core/display.sh" || { echo "Failed to load display.sh"; exit 1; }
source "$SRC_DIR/core/validation.sh" || { echo "Failed to load validation.sh"; exit 1; }

# 3. Library modules
source "$SRC_DIR/lib/crypto.sh" || { echo "Failed to load crypto.sh"; exit 1; }
source "$SRC_DIR/lib/http.sh" || { echo "Failed to load http.sh"; exit 1; }
source "$SRC_DIR/lib/input.sh" || { echo "Failed to load input.sh"; exit 1; }
source "$SRC_DIR/lib/backup.sh" || { echo "Failed to load backup.sh"; exit 1; }
source "$SRC_DIR/lib/logging.sh" || { echo "Failed to load logging.sh"; exit 1; }
source "$SRC_DIR/lib/docker.sh" || { echo "Failed to load docker.sh"; exit 1; }
source "$SRC_DIR/lib/management.sh" || { echo "Failed to load management.sh"; exit 1; }
source "$SRC_DIR/lib/api.sh" || { echo "Failed to load api.sh"; exit 1; }
source "$SRC_DIR/lib/panel-api.sh" || { echo "Failed to load panel-api.sh"; exit 1; }
source "$SRC_DIR/lib/user-api.sh" || { echo "Failed to load user-api.sh"; exit 1; }
source "$SRC_DIR/lib/xray-config.sh" || { echo "Failed to load xray-config.sh"; exit 1; }

# 4. Integration modules
source "$SRC_DIR/integrations/warp.sh" || { echo "Failed to load warp.sh"; exit 1; }
source "$SRC_DIR/integrations/netbird.sh" || { echo "Failed to load netbird.sh"; exit 1; }

# 4. Reverse proxy providers
source "$SRC_DIR/providers/caddy/install.sh" || { echo "Failed to load caddy/install.sh"; exit 1; }
source "$SRC_DIR/providers/caddy/config.sh" || { echo "Failed to load caddy/config.sh"; exit 1; }
source "$SRC_DIR/providers/nginx/install.sh" || { echo "Failed to load nginx/install.sh"; exit 1; }
source "$SRC_DIR/providers/nginx/config.sh" || { echo "Failed to load nginx/config.sh"; exit 1; }
source "$SRC_DIR/providers/nginx/ssl.sh" || { echo "Failed to load nginx/ssl.sh"; exit 1; }

# 5. Installation modules
source "$SRC_DIR/modules/panel/install.sh" || { echo "Failed to load panel/install.sh"; exit 1; }
source "$SRC_DIR/modules/node/install.sh" || { echo "Failed to load node/install.sh"; exit 1; }
source "$SRC_DIR/modules/all-in-one/install.sh" || { echo "Failed to load all-in-one/install.sh"; exit 1; }

# 6. Main menu
source "$SRC_DIR/main.sh" || { echo "Failed to load main.sh"; exit 1; }

# Start the installer
init_config
show_main_menu "$@"
