#!/usr/bin/env bash
# WARP Integration Module
# Docker WARP Native integration for Remnawave
# Based on: https://github.com/xxphantom/docker-warp-native
# Author: DigneZzZ

# Prevent double loading
[[ -n "${WARP_LOADED}" ]] && return 0
readonly WARP_LOADED=1

source "$(dirname "${BASH_SOURCE[0]}")/../core/colors.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../core/display.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/logging.sh"

# =============================================================================
# WARP CONFIGURATION
# =============================================================================

WARP_DIR="/opt/docker-warp-native"
WARP_COMPOSE_URL="https://raw.githubusercontent.com/xxphantom/docker-warp-native/refs/heads/main/docker-compose.yml"
WARP_CONTAINER_NAME="docker-warp-native"

# =============================================================================
# WARP CHECK
# =============================================================================

check_warp_installed() {
    if [ -d "$WARP_DIR" ] && [ -f "$WARP_DIR/docker-compose.yml" ]; then
        return 0
    fi
    return 1
}

check_warp_running() {
    if docker ps --format '{{.Names}}' | grep -q "^${WARP_CONTAINER_NAME}"; then
        return 0
    fi
    return 1
}

get_warp_status() {
    if ! check_warp_installed; then
        echo "not installed"
        return 1
    fi
    
    if check_warp_running; then
        echo "running"
        return 0
    else
        echo "stopped"
        return 1
    fi
}

# =============================================================================
# WARP INSTALLATION
# =============================================================================

install_warp() {
    log_section "WARP Docker Native Installation"
    
    # Check if already installed
    if check_warp_installed; then
        log_warning "WARP is already installed at $WARP_DIR"
        
        if check_warp_running; then
            log_success "WARP container is running"
            return 0
        else
            log_info "WARP container is not running"
            read -p "$(echo -e ${YELLOW}Start WARP container? [Y/n]:${NC} )" -r confirm
            if [[ ! $confirm =~ ^[Nn]$ ]]; then
                start_warp
                return $?
            fi
            return 0
        fi
    fi
    
    # Create directory
    log_step "Creating WARP directory..."
    mkdir -p "$WARP_DIR"
    log_success "Directory created: $WARP_DIR"
    
    # Download docker-compose.yml
    log_step "Downloading docker-compose.yml..."
    if wget -q "$WARP_COMPOSE_URL" -O "$WARP_DIR/docker-compose.yml"; then
        log_success "docker-compose.yml downloaded"
    else
        log_error "Failed to download docker-compose.yml"
        log_info "URL: $WARP_COMPOSE_URL"
        return 1
    fi
    
    # Start WARP
    log_step "Starting WARP container..."
    cd "$WARP_DIR"
    
    if docker compose up -d; then
        log_success "WARP container started"
        
        # Show logs
        echo
        log_info "Showing WARP logs (Ctrl+C to exit)..."
        sleep 2
        docker compose logs -f --tail=20 &
        local log_pid=$!
        
        sleep 10
        kill $log_pid 2>/dev/null
        
        echo
        log_success "WARP installation completed!"
        echo
        log_info "WARP Interface: warp"
        log_info "Use in Xray config:"
        echo -e "${GRAY}  \"streamSettings\": {${NC}"
        echo -e "${GRAY}    \"sockopt\": {${NC}"
        echo -e "${GRAY}      \"interface\": \"warp\"${NC}"
        echo -e "${GRAY}    }${NC}"
        echo -e "${GRAY}  }${NC}"
        
        cd - >/dev/null
        return 0
    else
        log_error "Failed to start WARP container"
        cd - >/dev/null
        return 1
    fi
}

# =============================================================================
# WARP MANAGEMENT
# =============================================================================

start_warp() {
    log_section "Starting WARP"
    
    if ! check_warp_installed; then
        log_error "WARP is not installed"
        return 1
    fi
    
    if check_warp_running; then
        log_success "WARP is already running"
        return 0
    fi
    
    cd "$WARP_DIR"
    if docker compose up -d; then
        log_success "WARP container started"
        cd - >/dev/null
        return 0
    else
        log_error "Failed to start WARP container"
        cd - >/dev/null
        return 1
    fi
}

stop_warp() {
    log_section "Stopping WARP"
    
    if ! check_warp_running; then
        log_warning "WARP is not running"
        return 0
    fi
    
    cd "$WARP_DIR"
    if docker compose down; then
        log_success "WARP container stopped"
        cd - >/dev/null
        return 0
    else
        log_error "Failed to stop WARP container"
        cd - >/dev/null
        return 1
    fi
}

restart_warp() {
    log_section "Restarting WARP"
    
    stop_warp
    sleep 2
    start_warp
}

show_warp_logs() {
    if ! check_warp_running; then
        log_error "WARP is not running"
        return 1
    fi
    
    log_info "WARP logs (Ctrl+C to exit):"
    echo
    cd "$WARP_DIR"
    docker compose logs -f --tail=50
    cd - >/dev/null
}

show_warp_status() {
    log_section "WARP Status"
    
    local status=$(get_warp_status)
    
    echo -e "${WHITE}Installation Directory:${NC} $WARP_DIR"
    echo -e "${WHITE}Container Name:${NC} $WARP_CONTAINER_NAME"
    
    case "$status" in
        "not installed")
            echo -e "${WHITE}Status:${NC} ${RED}Not Installed${NC}"
            ;;
        "running")
            echo -e "${WHITE}Status:${NC} ${GREEN}Running${NC}"
            
            # Show container info
            if [ -d "$WARP_DIR" ]; then
                cd "$WARP_DIR"
                echo
                docker compose ps
                cd - >/dev/null
            fi
            ;;
        "stopped")
            echo -e "${WHITE}Status:${NC} ${YELLOW}Stopped${NC}"
            ;;
    esac
    
    echo
}

uninstall_warp() {
    log_section "Uninstalling WARP"
    
    if ! check_warp_installed; then
        log_warning "WARP is not installed"
        return 0
    fi
    
    # Stop container if running
    if check_warp_running; then
        log_step "Stopping WARP container..."
        cd "$WARP_DIR"
        docker compose down
        cd - >/dev/null
    fi
    
    # Remove directory
    log_step "Removing WARP directory..."
    rm -rf "$WARP_DIR"
    log_success "WARP uninstalled"
    
    return 0
}

# =============================================================================
# WARP XRAY CONFIGURATION
# =============================================================================

show_warp_xray_config() {
    display_section "$ICON_CODE" "WARP Xray Configuration"
    
    echo -e "${BLUE}Add to your Xray outbounds:${NC}"
    echo
    cat <<'EOF'
{
  "tag": "warp-out",
  "protocol": "freedom",
  "settings": {},
  "streamSettings": {
    "sockopt": {
      "interface": "warp",
      "tcpFastOpen": true
    }
  }
}
EOF
    echo
    echo -e "${BLUE}Add to your Xray routing rules:${NC}"
    echo
    cat <<'EOF'
{
  "type": "field",
  "domain": [
    "ipinfo.io",
    "geosite:openai",
    "geosite:netflix"
  ],
  "inboundTag": ["VLESS"],
  "outboundTag": "warp-out"
}
EOF
    echo
    echo -e "${YELLOW}Customize the domain list based on your needs${NC}"
    echo
}

# =============================================================================
# WARP INTERACTIVE MENU
# =============================================================================

warp_menu() {
    while true; do
        clear
        display_section "$ICON_GLOBE" "WARP Integration"
        
        local status=$(get_warp_status)
        case "$status" in
            "not installed")
                echo -e "${RED}Status: Not Installed${NC}"
                ;;
            "running")
                echo -e "${GREEN}Status: Running${NC}"
                ;;
            "stopped")
                echo -e "${YELLOW}Status: Stopped${NC}"
                ;;
        esac
        
        echo
        echo -e "${GREEN}1.${NC} Install WARP"
        echo -e "${GREEN}2.${NC} Start WARP"
        echo -e "${GREEN}3.${NC} Stop WARP"
        echo -e "${GREEN}4.${NC} Restart WARP"
        echo -e "${GREEN}5.${NC} Show Logs"
        echo -e "${GREEN}6.${NC} Show Status"
        echo -e "${GREEN}7.${NC} Show Xray Config"
        echo -e "${GREEN}8.${NC} Uninstall WARP"
        echo -e "${GREEN}0.${NC} Back to Main Menu"
        echo
        
        read -p "$(echo -e ${YELLOW}Select option [0-8]:${NC} )" choice
        
        case $choice in
            1)
                install_warp
                read -p "Press Enter to continue..."
                ;;
            2)
                start_warp
                read -p "Press Enter to continue..."
                ;;
            3)
                stop_warp
                read -p "Press Enter to continue..."
                ;;
            4)
                restart_warp
                read -p "Press Enter to continue..."
                ;;
            5)
                show_warp_logs
                ;;
            6)
                show_warp_status
                read -p "Press Enter to continue..."
                ;;
            7)
                show_warp_xray_config
                read -p "Press Enter to continue..."
                ;;
            8)
                read -p "$(echo -e ${RED}Are you sure you want to uninstall WARP? [y/N]:${NC} )" confirm
                if [[ $confirm =~ ^[Yy]$ ]]; then
                    uninstall_warp
                fi
                read -p "Press Enter to continue..."
                ;;
            0)
                return 0
                ;;
            *)
                log_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f check_warp_installed
export -f check_warp_running
export -f get_warp_status
export -f install_warp
export -f start_warp
export -f stop_warp
export -f restart_warp
export -f show_warp_logs
export -f show_warp_status
export -f uninstall_warp
export -f show_warp_xray_config
export -f warp_menu
