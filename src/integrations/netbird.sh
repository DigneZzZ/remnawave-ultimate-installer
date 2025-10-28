#!/usr/bin/env bash
# Netbird Integration Module
# WireGuard-based VPN mesh network for secure server connections
# Based on: https://www.netbird.io/
# Author: DigneZzZ

source "$(dirname "${BASH_SOURCE[0]}")/../core/colors.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../core/display.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/logging.sh"

# =============================================================================
# NETBIRD CONFIGURATION
# =============================================================================

NETBIRD_INSTALL_SCRIPT="https://pkgs.netbird.io/install.sh"

# =============================================================================
# NETBIRD CHECK
# =============================================================================

check_netbird_installed() {
    if command -v netbird >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

check_netbird_running() {
    if netbird status 2>/dev/null | grep -q "Connected"; then
        return 0
    fi
    return 1
}

get_netbird_status() {
    if ! check_netbird_installed; then
        echo "not installed"
        return 1
    fi
    
    if check_netbird_running; then
        echo "connected"
        return 0
    else
        echo "disconnected"
        return 1
    fi
}

get_netbird_ip() {
    if ! check_netbird_running; then
        echo "N/A"
        return 1
    fi
    
    netbird status 2>/dev/null | grep "NetBird IP:" | awk '{print $3}'
}

# =============================================================================
# NETBIRD INSTALLATION
# =============================================================================

install_netbird() {
    log_section "Netbird Installation"
    
    # Check if already installed
    if check_netbird_installed; then
        log_success "Netbird is already installed"
        
        local version=$(netbird version 2>/dev/null | head -1)
        log_info "Version: $version"
        
        if check_netbird_running; then
            log_success "Netbird is connected"
            local nb_ip=$(get_netbird_ip)
            log_info "Netbird IP: $nb_ip"
            return 0
        else
            log_warning "Netbird is not connected"
            echo
            read -p "$(echo -e ${YELLOW}Connect to Netbird network? [Y/n]:${NC} )" -r confirm
            if [[ ! $confirm =~ ^[Nn]$ ]]; then
                connect_netbird_interactive
                return $?
            fi
            return 0
        fi
    fi
    
    # Download and run installation script
    log_step "Downloading Netbird installation script..."
    
    if curl -fsSL "$NETBIRD_INSTALL_SCRIPT" -o /tmp/netbird-install.sh 2>/dev/null; then
        log_success "Installation script downloaded"
        
        chmod +x /tmp/netbird-install.sh
        
        log_step "Installing Netbird..."
        echo
        log_warning "The installation will prompt for sudo password"
        echo
        
        if sh /tmp/netbird-install.sh; then
            rm -f /tmp/netbird-install.sh
            
            echo
            log_success "Netbird installed successfully!"
            
            local version=$(netbird version 2>/dev/null | head -1)
            log_info "Version: $version"
            
            echo
            log_info "Netbird is installed but not connected"
            
            read -p "$(echo -e ${YELLOW}Connect to Netbird network now? [Y/n]:${NC} )" -r confirm
            if [[ ! $confirm =~ ^[Nn]$ ]]; then
                connect_netbird_interactive
                return $?
            fi
            
            return 0
        else
            rm -f /tmp/netbird-install.sh
            log_error "Netbird installation failed"
            return 1
        fi
    else
        log_error "Failed to download installation script"
        log_info "URL: $NETBIRD_INSTALL_SCRIPT"
        return 1
    fi
}

# =============================================================================
# NETBIRD CONNECTION
# =============================================================================

connect_netbird() {
    local setup_key="$1"
    
    if [ -z "$setup_key" ]; then
        log_error "Setup key is required"
        return 1
    fi
    
    log_section "Connecting to Netbird"
    
    if check_netbird_running; then
        log_warning "Already connected to Netbird"
        local nb_ip=$(get_netbird_ip)
        log_info "Netbird IP: $nb_ip"
        return 0
    fi
    
    log_step "Connecting with setup key..."
    
    if netbird up --setup-key "$setup_key" 2>&1 | tee /tmp/netbird-connect.log; then
        log_success "Successfully connected to Netbird!"
        
        sleep 2
        
        if check_netbird_running; then
            local nb_ip=$(get_netbird_ip)
            echo
            log_info "Connection Details:"
            log_info "  Status: Connected"
            log_info "  Netbird IP: $nb_ip"
            echo
            log_success "Netbird mesh VPN is active"
            
            rm -f /tmp/netbird-connect.log
            return 0
        else
            log_warning "Connected but status is unclear"
            log_info "Check with: netbird status"
            rm -f /tmp/netbird-connect.log
            return 0
        fi
    else
        log_error "Failed to connect to Netbird"
        log_info "Check the error messages above"
        
        if [ -f /tmp/netbird-connect.log ]; then
            echo
            log_info "Connection log:"
            cat /tmp/netbird-connect.log
            rm -f /tmp/netbird-connect.log
        fi
        
        return 1
    fi
}

connect_netbird_interactive() {
    echo
    display_section "$ICON_KEY" "Netbird Connection"
    
    echo -e "${BLUE}To connect to Netbird, you need a setup key${NC}"
    echo -e "${GRAY}Get it from: https://app.netbird.io/setup-keys${NC}"
    echo
    
    read -p "$(echo -e ${YELLOW}Enter setup key:${NC} )" setup_key
    
    if [ -z "$setup_key" ]; then
        log_error "Setup key cannot be empty"
        return 1
    fi
    
    connect_netbird "$setup_key"
}

disconnect_netbird() {
    log_section "Disconnecting Netbird"
    
    if ! check_netbird_running; then
        log_warning "Netbird is not connected"
        return 0
    fi
    
    log_step "Disconnecting from Netbird..."
    
    if netbird down 2>/dev/null; then
        log_success "Disconnected from Netbird"
        return 0
    else
        log_error "Failed to disconnect"
        return 1
    fi
}

# =============================================================================
# NETBIRD STATUS
# =============================================================================

show_netbird_status() {
    log_section "Netbird Status"
    
    if ! check_netbird_installed; then
        echo -e "${WHITE}Status:${NC} ${RED}Not Installed${NC}"
        echo
        log_info "Install with: netbird_menu → Install Netbird"
        return 1
    fi
    
    local version=$(netbird version 2>/dev/null | head -1)
    echo -e "${WHITE}Version:${NC} $version"
    
    if check_netbird_running; then
        echo -e "${WHITE}Status:${NC} ${GREEN}Connected${NC}"
        
        local nb_ip=$(get_netbird_ip)
        echo -e "${WHITE}Netbird IP:${NC} $nb_ip"
        
        echo
        log_info "Full status:"
        netbird status 2>/dev/null
    else
        echo -e "${WHITE}Status:${NC} ${YELLOW}Disconnected${NC}"
        echo
        log_warning "Not connected to any Netbird network"
        log_info "Connect with: netbird up --setup-key YOUR_KEY"
    fi
    
    echo
}

show_netbird_peers() {
    if ! check_netbird_running; then
        log_error "Netbird is not connected"
        return 1
    fi
    
    log_section "Netbird Peers"
    
    netbird status 2>/dev/null
    echo
}

# =============================================================================
# NETBIRD MANAGEMENT
# =============================================================================

uninstall_netbird() {
    log_section "Uninstalling Netbird"
    
    if ! check_netbird_installed; then
        log_warning "Netbird is not installed"
        return 0
    fi
    
    # Disconnect first
    if check_netbird_running; then
        log_step "Disconnecting from Netbird..."
        netbird down 2>/dev/null || true
    fi
    
    # Uninstall
    log_step "Removing Netbird..."
    
    if command -v apt-get >/dev/null 2>&1; then
        apt-get remove -y netbird 2>/dev/null || true
        apt-get autoremove -y 2>/dev/null || true
    elif command -v yum >/dev/null 2>&1; then
        yum remove -y netbird 2>/dev/null || true
    elif command -v dnf >/dev/null 2>&1; then
        dnf remove -y netbird 2>/dev/null || true
    fi
    
    # Remove config
    rm -rf /etc/netbird 2>/dev/null || true
    rm -rf ~/.netbird 2>/dev/null || true
    
    log_success "Netbird uninstalled"
    return 0
}

# =============================================================================
# FIREWALL CONFIGURATION
# =============================================================================

configure_netbird_firewall() {
    local remote_netbird_ip="$1"
    local port="${2:-2222}"
    
    if [ -z "$remote_netbird_ip" ]; then
        log_error "Remote Netbird IP is required"
        return 1
    fi
    
    log_section "Configuring Firewall for Netbird"
    
    if ! command -v ufw >/dev/null 2>&1; then
        log_warning "UFW is not installed"
        return 1
    fi
    
    log_step "Opening port $port for $remote_netbird_ip..."
    
    if ufw allow from "$remote_netbird_ip" to any port "$port" proto tcp; then
        log_success "Firewall rule added"
        
        log_step "Reloading firewall..."
        if ufw reload; then
            log_success "Firewall reloaded"
            echo
            log_info "Firewall configured:"
            log_info "  Allow: $remote_netbird_ip → port $port/tcp"
            return 0
        else
            log_error "Failed to reload firewall"
            return 1
        fi
    else
        log_error "Failed to add firewall rule"
        return 1
    fi
}

show_netbird_firewall_guide() {
    display_section "$ICON_SHIELD" "Netbird Firewall Configuration"
    
    echo -e "${BLUE}To allow panel to connect to node via Netbird:${NC}"
    echo
    echo -e "${WHITE}1.${NC} Get panel's Netbird IP:"
    echo -e "${GRAY}   On panel server: netbird status | grep 'NetBird IP'${NC}"
    echo
    echo -e "${WHITE}2.${NC} Configure firewall on node:"
    echo -e "${GRAY}   ufw allow from PANEL_NETBIRD_IP to any port 2222 proto tcp${NC}"
    echo -e "${GRAY}   ufw reload${NC}"
    echo
    echo -e "${WHITE}3.${NC} Update node address in panel:"
    echo -e "${GRAY}   Use node's Netbird IP instead of public IP${NC}"
    echo
    echo -e "${YELLOW}Example:${NC}"
    echo -e "${GRAY}   Panel Netbird IP: 100.88.38.121${NC}"
    echo -e "${GRAY}   Node Netbird IP: 100.88.74.220${NC}"
    echo -e "${GRAY}   Command: ufw allow from 100.88.38.121 to any port 2222 proto tcp${NC}"
    echo
}

# =============================================================================
# NETBIRD INTERACTIVE MENU
# =============================================================================

netbird_menu() {
    while true; do
        clear
        display_section "$ICON_GLOBE" "Netbird Integration"
        
        local status=$(get_netbird_status)
        case "$status" in
            "not installed")
                echo -e "${RED}Status: Not Installed${NC}"
                ;;
            "connected")
                local nb_ip=$(get_netbird_ip)
                echo -e "${GREEN}Status: Connected${NC}"
                echo -e "${WHITE}Netbird IP:${NC} $nb_ip"
                ;;
            "disconnected")
                echo -e "${YELLOW}Status: Disconnected${NC}"
                ;;
        esac
        
        echo
        echo -e "${GREEN}1.${NC} Install Netbird"
        echo -e "${GREEN}2.${NC} Connect to Network"
        echo -e "${GREEN}3.${NC} Disconnect"
        echo -e "${GREEN}4.${NC} Show Status"
        echo -e "${GREEN}5.${NC} Show Peers"
        echo -e "${GREEN}6.${NC} Configure Firewall"
        echo -e "${GREEN}7.${NC} Firewall Guide"
        echo -e "${GREEN}8.${NC} Uninstall Netbird"
        echo -e "${GREEN}0.${NC} Back to Main Menu"
        echo
        
        read -p "$(echo -e ${YELLOW}Select option [0-8]:${NC} )" choice
        
        case $choice in
            1)
                install_netbird
                read -p "Press Enter to continue..."
                ;;
            2)
                connect_netbird_interactive
                read -p "Press Enter to continue..."
                ;;
            3)
                disconnect_netbird
                read -p "Press Enter to continue..."
                ;;
            4)
                show_netbird_status
                read -p "Press Enter to continue..."
                ;;
            5)
                show_netbird_peers
                read -p "Press Enter to continue..."
                ;;
            6)
                echo
                read -p "Enter remote Netbird IP: " remote_ip
                read -p "Enter port [2222]: " port
                port=${port:-2222}
                configure_netbird_firewall "$remote_ip" "$port"
                read -p "Press Enter to continue..."
                ;;
            7)
                show_netbird_firewall_guide
                read -p "Press Enter to continue..."
                ;;
            8)
                read -p "$(echo -e ${RED}Are you sure you want to uninstall Netbird? [y/N]:${NC} )" confirm
                if [[ $confirm =~ ^[Yy]$ ]]; then
                    uninstall_netbird
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

export -f check_netbird_installed
export -f check_netbird_running
export -f get_netbird_status
export -f get_netbird_ip
export -f install_netbird
export -f connect_netbird
export -f connect_netbird_interactive
export -f disconnect_netbird
export -f show_netbird_status
export -f show_netbird_peers
export -f uninstall_netbird
export -f configure_netbird_firewall
export -f show_netbird_firewall_guide
export -f netbird_menu
