#!/usr/bin/env bash
# Main Entry Point for Remnawave Ultimate Installer
# Version: 1.0.0

set -e

# =============================================================================
# SOURCE DEPENDENCIES
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source configuration
source "$SCRIPT_DIR/config.sh"

# Source core modules
source "$SCRIPT_DIR/core/colors.sh"
source "$SCRIPT_DIR/core/display.sh"
source "$SCRIPT_DIR/core/validation.sh"

# Source libraries
source "$SCRIPT_DIR/lib/crypto.sh"
source "$SCRIPT_DIR/lib/http.sh"
source "$SCRIPT_DIR/lib/input.sh"
source "$SCRIPT_DIR/lib/backup.sh"

# Initialize configuration
init_config

# =============================================================================
# MAIN MENU
# =============================================================================

show_main_menu() {
    while true; do
        display_banner "$SCRIPT_VERSION"
        
        echo -e "${GRAY}   Universal Remnawave installation framework by DigneZzZ${NC}"
        echo
        
        # Show current status if installed
        if load_install_info; then
            echo -e "${WHITE}📊 Current Installation:${NC}"
            display_separator "" 40
            display_table_row "Type" "$CURRENT_INSTALL_TYPE" 20
            display_table_row "Reverse Proxy" "$CURRENT_REVERSE_PROXY" 20
            display_table_row "Domain" "$CURRENT_DOMAIN" 20
            echo
        fi
        
        echo -e "${WHITE}   📦 Installation Options:${NC}"
        display_separator "" 40
        display_menu_item "1" "Panel Only" "Install Remnawave Panel"
        display_menu_item "2" "Node Only" "Install Remnawave Node"
        display_menu_item "3" "All-in-One" "Install Panel + Node"
        display_menu_item "4" "Selfsteal Only" "Install Caddy Selfsteal"
        echo
        
        echo -e "${WHITE}   🔧 Configuration:${NC}"
        display_separator "" 40
        display_menu_item "5" "Reverse Proxy" "Choose NGINX or Caddy"
        display_menu_item "6" "Security Level" "Basic / Cookie / 2FA"
        display_menu_item "7" "SSL Provider" "Let's Encrypt / Cloudflare / CertWarden"
        echo
        
        echo -e "${WHITE}   🔌 Integrations:${NC}"
        display_separator "" 40
        display_menu_item "8" "WARP" "Cloudflare WARP integration"
        display_menu_item "9" "VPN Setup" "Netbird integration"
        echo
        
        echo -e "${WHITE}   🛠️  Tools:${NC}"
        display_separator "" 40
        display_menu_item "10" "Management Scripts" "Install remnawave/remnanode/selfsteal"
        display_menu_item "11" "Backup & Restore" "Manage backups"
        display_menu_item "12" "Update" "Update components"
        display_menu_item "13" "Status" "View system status"
        echo
        
        display_menu_item "0" "Exit" ""
        echo
        display_divider "─" 60
        echo
        
        display_prompt "Select option" ""
        read -r choice
        
        case "$choice" in
            1) menu_install_panel ;;
            2) menu_install_node ;;
            3) menu_install_all_in_one ;;
            4) menu_install_selfsteal ;;
            5) menu_configure_proxy ;;
            6) choose_security_level ;;
            7) configure_ssl ;;
            8) menu_integration_warp ;;
            9) menu_integration_vpn ;;
            10) menu_management_scripts ;;
            11) menu_backup_restore ;;
            12) menu_update ;;
            13) menu_status ;;
            0) 
                echo
                display_info "Thank you for using Remnawave Ultimate Installer!"
                echo
                exit 0
                ;;
            *)
                display_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# =============================================================================
# INSTALLATION MENUS
# =============================================================================

menu_install_panel() {
    clear
    display_banner "$SCRIPT_VERSION"
    display_section "$ICON_PACKAGE" "Panel Installation"
    
    # Check if already installed
    if is_installed "panel"; then
        display_warning "Panel is already installed"
        echo
        display_confirm "Reinstall" "n"
        read -r confirm
        [[ ! $confirm =~ ^[Yy]$ ]] && return
    fi
    
    # Pre-flight checks
    display_step "Running pre-flight checks..."
    echo
    
    if ! validate_root; then
        read -p "Press Enter to continue..."
        return
    fi
    
    if ! validate_system_requirements; then
        read -p "Press Enter to continue..."
        return
    fi
    
    # Choose reverse proxy
    choose_reverse_proxy
    
    # Choose security level
    choose_security_level
    
    # Domain configuration
    configure_domain
    
    # SSL configuration
    configure_ssl
    
    # Run installation
    echo
    
    if install_panel; then
        display_success "Panel installation completed successfully!"
    else
        display_error "Panel installation failed"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

menu_install_node() {
    clear
    display_banner "$SCRIPT_VERSION"
    display_section "$ICON_SERVER" "Node Installation"
    
    # Check if already installed
    if is_installed "node"; then
        display_warning "Node is already installed"
        echo
        display_confirm "Reinstall" "n"
        read -r confirm
        [[ ! $confirm =~ ^[Yy]$ ]] && return
    fi
    
    # Pre-flight checks
    display_step "Running pre-flight checks..."
    echo
    
    if ! validate_root; then
        read -p "Press Enter to continue..."
        return
    fi
    
    if ! validate_system_requirements; then
        read -p "Press Enter to continue..."
        return
    fi
    
    # Ask for Xray integration
    echo
    display_prompt "Install Xray-core" "yes"
    read -r install_xray
    [[ $install_xray =~ ^[Yy]|yes$ ]] && ENABLE_XRAY=true
    
    # Ask for Selfsteal
    if [ "$ENABLE_XRAY" = true ]; then
        display_prompt "Install Selfsteal (Caddy)" "yes"
        read -r install_selfsteal
        [[ $install_selfsteal =~ ^[Yy]|yes$ ]] && ENABLE_SELFSTEAL=true
    fi
    
    # Run installation
    echo
    
    if install_node; then
        display_success "Node installation completed successfully!"
    else
        display_error "Node installation failed"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

menu_install_all_in_one() {
    clear
    display_banner "$SCRIPT_VERSION"
    display_section "$ICON_ROCKET" "All-in-One Installation"
    
    display_info "This will install both Panel and Node on the same server"
    echo
    
    # Pre-flight checks
    if ! validate_root; then
        read -p "Press Enter to continue..."
        return
    fi
    
    if ! validate_system_requirements; then
        read -p "Press Enter to continue..."
        return
    fi
    
    # Choose reverse proxy
    choose_reverse_proxy
    
    # Choose security level
    choose_security_level
    
    # Domain configuration
    configure_domain
    
    # SSL configuration
    configure_ssl
    
    # Xray options
    ENABLE_XRAY=true
    display_prompt "Install Selfsteal (Caddy)" "yes"
    read -r install_selfsteal
    [[ $install_selfsteal =~ ^[Yy]|yes$ ]] && ENABLE_SELFSTEAL=true
    
    # Run installation
    echo
    
    if install_all_in_one; then
        display_success "All-in-One installation completed successfully!"
    else
        display_error "All-in-One installation failed"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

menu_install_selfsteal() {
    clear
    display_banner "$SCRIPT_VERSION"
    display_section "$ICON_LOCK" "Selfsteal Installation"
    
    display_info "Selfsteal: Caddy server for Xray Reality traffic masking"
    echo
    
    if ! validate_root; then
        read -p "Press Enter to continue..."
        return
    fi
    
    if ! validate_system_requirements; then
        read -p "Press Enter to continue..."
        return
    fi
    
    # Domain for selfsteal
    echo
    display_prompt "Selfsteal domain" "cloudflare.com"
    read -r selfsteal_domain
    [ -z "$selfsteal_domain" ] && selfsteal_domain="cloudflare.com"
    
    # Port for selfsteal
    display_prompt "Selfsteal port" "9443"
    read -r selfsteal_port
    [ -z "$selfsteal_port" ] && selfsteal_port="9443"
    
    # Run installation
    echo
    display_step "Starting Selfsteal installation..."
    # TODO: Call selfsteal installation module
    
    read -p "Press Enter to continue..."
}

# =============================================================================
# CONFIGURATION MENUS
# =============================================================================

choose_reverse_proxy() {
    echo
    display_section "$ICON_GEAR" "Reverse Proxy Selection"
    
    echo -e "${WHITE}Available options:${NC}"
    echo -e "${CYAN}1)${NC} ${WHITE}NGINX${NC} ${GRAY}(Unix socket, cookie auth, emergency port)${NC}"
    echo -e "${CYAN}2)${NC} ${WHITE}Caddy${NC} ${GRAY}(Auto SSL, 2FA support, simple config)${NC}"
    echo
    
    display_prompt "Choose reverse proxy" "2"
    read -r proxy_choice
    
    case "$proxy_choice" in
        1) CURRENT_REVERSE_PROXY="$PROXY_NGINX" ;;
        2|"") CURRENT_REVERSE_PROXY="$PROXY_CADDY" ;;
        *) 
            display_error "Invalid choice"
            choose_reverse_proxy
            return
            ;;
    esac
    
    display_success "Selected: $CURRENT_REVERSE_PROXY"
}

choose_security_level() {
    echo
    display_section "$ICON_SHIELD" "Security Level Selection"
    
    echo -e "${WHITE}Available options:${NC}"
    echo -e "${CYAN}1)${NC} ${WHITE}Basic${NC} ${GRAY}(No authentication, fast setup)${NC}"
    echo -e "${CYAN}2)${NC} ${WHITE}Cookie Auth${NC} ${GRAY}(Cookie-based protection)${NC}"
    echo -e "${CYAN}3)${NC} ${WHITE}Full Auth${NC} ${GRAY}(2FA with caddy-security)${NC}"
    echo
    
    display_prompt "Choose security level" "1"
    read -r security_choice
    
    case "$security_choice" in
        1|"") CURRENT_SECURITY_LEVEL="$SECURITY_BASIC" ;;
        2) CURRENT_SECURITY_LEVEL="$SECURITY_COOKIE" ;;
        3) 
            if [ "$CURRENT_REVERSE_PROXY" != "$PROXY_CADDY" ]; then
                display_error "Full Auth (2FA) requires Caddy"
                choose_security_level
                return
            fi
            CURRENT_SECURITY_LEVEL="$SECURITY_FULL"
            ;;
        *) 
            display_error "Invalid choice"
            choose_security_level
            return
            ;;
    esac
    
    display_success "Selected: $CURRENT_SECURITY_LEVEL"
}

configure_domain() {
    echo
    display_section "$ICON_GLOBE" "Domain Configuration"
    
    display_prompt "Enter domain" ""
    read -r domain
    
    if [ -z "$domain" ]; then
        display_error "Domain cannot be empty"
        configure_domain
        return
    fi
    
    # Validate domain
    if ! validate_domain_complete "$domain" "$CURRENT_SERVER_IP"; then
        echo
        display_confirm "Continue anyway" "n"
        read -r confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            configure_domain
            return
        fi
    fi
    
    CURRENT_DOMAIN="$domain"
    display_success "Domain configured: $CURRENT_DOMAIN"
}

configure_ssl() {
    echo
    display_section "$ICON_KEY" "SSL Configuration"
    
    echo -e "${WHITE}Available SSL providers:${NC}"
    echo -e "${CYAN}1)${NC} ${WHITE}Let's Encrypt${NC} ${GRAY}(Free, automatic, recommended)${NC}"
    echo -e "${CYAN}2)${NC} ${WHITE}Cloudflare${NC} ${GRAY}(API-based, good for proxied sites)${NC}"
    echo -e "${CYAN}3)${NC} ${WHITE}Self-signed${NC} ${GRAY}(For testing only)${NC}"
    echo
    
    display_prompt "Choose SSL provider" "1"
    read -r ssl_choice
    
    case "$ssl_choice" in
        1|"") CURRENT_SSL_PROVIDER="$SSL_LETSENCRYPT" ;;
        2) 
            CURRENT_SSL_PROVIDER="$SSL_CLOUDFLARE"
            # Ask for Cloudflare credentials
            echo
            display_prompt "Cloudflare Email" ""
            read -r cf_email
            display_prompt "Cloudflare API Key" ""
            read -r cf_api_key
            # TODO: Store credentials
            ;;
        3) CURRENT_SSL_PROVIDER="$SSL_SELF_SIGNED" ;;
        *) 
            display_error "Invalid choice"
            configure_ssl
            return
            ;;
    esac
    
    display_success "Selected: $CURRENT_SSL_PROVIDER"
}

menu_configure_proxy() {
    clear
    display_banner "$SCRIPT_VERSION"
    choose_reverse_proxy
    read -p "Press Enter to continue..."
}

menu_configure_security() {
    clear
    display_banner "$SCRIPT_VERSION"
    choose_security_level
    read -p "Press Enter to continue..."
}

menu_configure_ssl() {
    clear
    display_banner "$SCRIPT_VERSION"
    configure_ssl
    read -p "Press Enter to continue..."
}

# =============================================================================
# INTEGRATION MENUS
# =============================================================================

menu_integration_warp() {
    clear
    display_banner "$SCRIPT_VERSION"
    display_section "$ICON_NETWORK" "WARP Integration"
    
    display_info "Cloudflare WARP integration for routing traffic"
    echo
    
    display_warning "Feature coming soon!"
    read -p "Press Enter to continue..."
}


menu_integration_vpn() {
    clear
    display_banner "$SCRIPT_VERSION"
    display_section "$ICON_NETWORK" "VPN Setup"
    
    display_info "Netbird VPN integration"
    echo
    
    display_warning "Feature coming soon!"
    read -p "Press Enter to continue..."
}

# =============================================================================
# TOOLS MENUS
# =============================================================================

menu_backup_restore() {
    clear
    display_banner "$SCRIPT_VERSION"
    display_section "$ICON_FOLDER" "Backup & Restore"
    
    # Check if remnawave script is installed
    if ! command -v remnawave >/dev/null 2>&1; then
        display_warning "remnawave скрипт не установлен"
        echo
        display_info "Для управления резервными копиями необходимо установить remnawave"
        display_info "В remnawave есть полное меню для работы с бэкапами"
        echo
        
        if confirm_action "Установить remnawave сейчас?" "y"; then
            if install_management_scripts "panel"; then
                display_success "remnawave установлен"
                echo
                display_info "Открываем меню резервного копирования..."
                sleep 2
                remnawave schedule
            else
                display_error "Не удалось установить remnawave"
                pause_for_user
                return 1
            fi
        else
            display_info "Установка отменена"
            display_info "Вы можете установить remnawave позже через:"
            echo -e "  ${CYAN}bash install.sh → 10) Management Scripts${NC}"
            pause_for_user
            return 0
        fi
    else
        # remnawave installed, use it for backup management
        display_info "Используется remnawave для управления резервными копиями..."
        echo
        remnawave schedule
    fi
}

menu_update() {
    clear
    display_banner "$SCRIPT_VERSION"
    display_section "$ICON_DOWNLOAD" "Update Components"
    
    # Check if remnawave script is installed
    if ! command -v remnawave >/dev/null 2>&1; then
        display_warning "remnawave скрипт не установлен"
        echo
        display_info "Для использования функции обновления необходимо установить remnawave"
        echo
        
        if confirm_action "Установить remnawave сейчас?" "y"; then
            if install_management_scripts "panel"; then
                display_success "remnawave установлен"
                echo
                display_info "Запускаем обновление..."
                sleep 2
                remnawave update
            else
                display_error "Не удалось установить remnawave"
                pause_for_user
                return 1
            fi
        else
            display_info "Установка отменена"
            pause_for_user
            return 0
        fi
    else
        # remnawave installed, use it for updates
        display_info "Используется remnawave для обновления..."
        echo
        remnawave update
    fi
}

menu_status() {
    clear
    display_banner "$SCRIPT_VERSION"
    display_section "$ICON_INFO" "System Status"
    
    # Show installation info
    if load_install_info; then
        declare -A status_data=(
            ["Installation Type"]="$CURRENT_INSTALL_TYPE"
            ["Reverse Proxy"]="$CURRENT_REVERSE_PROXY"
            ["Security Level"]="$CURRENT_SECURITY_LEVEL"
            ["Domain"]="$CURRENT_DOMAIN"
            ["Server IP"]="$CURRENT_SERVER_IP"
        )
        
        display_table status_data 25
    else
        display_info "No installation found"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    # Check root
    if ! validate_root; then
        exit 1
    fi
    
    # Check OS and architecture
    validate_os
    validate_architecture
    
    # Show main menu
    show_main_menu
}

# Run main function
main "$@"
