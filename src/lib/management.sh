#!/usr/bin/env bash
# Management Scripts Module
# Description: Install and manage remnawave.sh, remnanode.sh, selfsteal.sh
# Author: DigneZzZ
# Version: 1.0.0

# Prevent double loading
[[ -n "${MANAGEMENT_LOADED}" ]] && return 0
readonly MANAGEMENT_LOADED=1

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"
source "$SCRIPT_DIR/../core/display.sh"
source "$SCRIPT_DIR/../lib/logging.sh"

# =============================================================================
# MANAGEMENT SCRIPTS INSTALLATION
# =============================================================================

install_management_scripts() {
    local script_type="${1:-all}"  # all, panel, node, selfsteal
    
    display_section "$ICON_DOWNLOAD" "Установка управляющих скриптов"
    
    case "$script_type" in
        "all")
            install_remnawave_script
            install_remnanode_script
            install_selfsteal_script
            ;;
        "panel")
            install_remnawave_script
            ;;
        "node")
            install_remnanode_script
            ;;
        "selfsteal")
            install_selfsteal_script
            ;;
        *)
            display_error "Неизвестный тип скрипта: $script_type"
            return 1
            ;;
    esac
    
    display_success "Управляющие скрипты установлены"
    echo
    display_info "Доступные команды:"
    
    if [ "$script_type" = "all" ] || [ "$script_type" = "panel" ]; then
        echo "  • remnawave --help"
    fi
    
    if [ "$script_type" = "all" ] || [ "$script_type" = "node" ]; then
        echo "  • remnanode --help"
    fi
    
    if [ "$script_type" = "all" ] || [ "$script_type" = "selfsteal" ]; then
        echo "  • selfsteal --help"
    fi
    
    echo
}

install_remnawave_script() {
    display_step "Установка remnawave.sh..."
    
    if ! curl -fsSL "$REMNAWAVE_SCRIPT_URL" -o /tmp/remnawave.sh; then
        log_error "Не удалось скачать remnawave.sh"
        display_error "Ошибка загрузки remnawave.sh"
        return 1
    fi
    
    chmod +x /tmp/remnawave.sh
    mv /tmp/remnawave.sh /usr/local/bin/remnawave
    
    log_info "remnawave.sh установлен в /usr/local/bin/remnawave"
    display_success "remnawave.sh установлен"
}

install_remnanode_script() {
    display_step "Установка remnanode.sh..."
    
    if ! curl -fsSL "$REMNANODE_SCRIPT_URL" -o /tmp/remnanode.sh; then
        log_error "Не удалось скачать remnanode.sh"
        display_error "Ошибка загрузки remnanode.sh"
        return 1
    fi
    
    chmod +x /tmp/remnanode.sh
    mv /tmp/remnanode.sh /usr/local/bin/remnanode
    
    log_info "remnanode.sh установлен в /usr/local/bin/remnanode"
    display_success "remnanode.sh установлен"
}

install_selfsteal_script() {
    display_step "Установка selfsteal.sh..."
    
    if ! curl -fsSL "$SELFSTEAL_SCRIPT_URL" -o /tmp/selfsteal.sh; then
        log_error "Не удалось скачать selfsteal.sh"
        display_error "Ошибка загрузки selfsteal.sh"
        return 1
    fi
    
    chmod +x /tmp/selfsteal.sh
    mv /tmp/selfsteal.sh /usr/local/bin/selfsteal
    
    log_info "selfsteal.sh установлен в /usr/local/bin/selfsteal"
    display_success "selfsteal.sh установлен"
}

# =============================================================================
# CHECK MANAGEMENT SCRIPTS STATUS
# =============================================================================

check_management_scripts() {
    local has_remnawave=false
    local has_remnanode=false
    local has_selfsteal=false
    
    if [ -f "/usr/local/bin/remnawave" ]; then
        has_remnawave=true
    fi
    
    if [ -f "/usr/local/bin/remnanode" ]; then
        has_remnanode=true
    fi
    
    if [ -f "/usr/local/bin/selfsteal" ]; then
        has_selfsteal=true
    fi
    
    display_section "$ICON_INFO" "Статус управляющих скриптов"
    echo
    
    if $has_remnawave; then
        display_success "remnawave: Установлен (/usr/local/bin/remnawave)"
    else
        display_warning "remnawave: Не установлен"
    fi
    
    if $has_remnanode; then
        display_success "remnanode: Установлен (/usr/local/bin/remnanode)"
    else
        display_warning "remnanode: Не установлен"
    fi
    
    if $has_selfsteal; then
        display_success "selfsteal: Установлен (/usr/local/bin/selfsteal)"
    else
        display_warning "selfsteal: Не установлен"
    fi
    
    echo
    
    if ! $has_remnawave && ! $has_remnanode && ! $has_selfsteal; then
        display_info "Используйте меню для установки управляющих скриптов"
        return 1
    fi
    
    return 0
}

# =============================================================================
# UPDATE MANAGEMENT SCRIPTS
# =============================================================================

update_management_scripts() {
    display_section "$ICON_UPDATE" "Обновление управляющих скриптов"
    
    if [ -f "/usr/local/bin/remnawave" ]; then
        display_step "Обновление remnawave..."
        install_remnawave_script
    fi
    
    if [ -f "/usr/local/bin/remnanode" ]; then
        display_step "Обновление remnanode..."
        install_remnanode_script
    fi
    
    if [ -f "/usr/local/bin/selfsteal" ]; then
        display_step "Обновление selfsteal..."
        install_selfsteal_script
    fi
    
    display_success "Обновление завершено"
}

# =============================================================================
# UNINSTALL MANAGEMENT SCRIPTS
# =============================================================================

uninstall_management_scripts() {
    display_section "$ICON_DELETE" "Удаление управляющих скриптов"
    
    if ! confirm_action "Удалить управляющие скрипты?" "n"; then
        return 0
    fi
    
    if [ -f "/usr/local/bin/remnawave" ]; then
        rm -f /usr/local/bin/remnawave
        display_success "remnawave удален"
    fi
    
    if [ -f "/usr/local/bin/remnanode" ]; then
        rm -f /usr/local/bin/remnanode
        display_success "remnanode удален"
    fi
    
    if [ -f "/usr/local/bin/selfsteal" ]; then
        rm -f /usr/local/bin/selfsteal
        display_success "selfsteal удален"
    fi
    
    display_success "Управляющие скрипты удалены"
}

# =============================================================================
# INTERACTIVE MENU
# =============================================================================

menu_management_scripts() {
    while true; do
        clear
        display_banner
        display_section "$ICON_TOOLS" "Управляющие скрипты"
        
        # Show current status
        check_management_scripts >/dev/null 2>&1
        echo
        
        display_menu_item "1" "Установить все скрипты" "remnawave + remnanode + selfsteal"
        display_menu_item "2" "Установить remnawave.sh" "Управление панелью"
        display_menu_item "3" "Установить remnanode.sh" "Управление нодой"
        display_menu_item "4" "Установить selfsteal.sh" "Управление selfsteal"
        display_menu_item "5" "Обновить скрипты" "Обновить до последней версии"
        display_menu_item "6" "Проверить статус" "Показать статус скриптов"
        display_menu_item "7" "Удалить скрипты" "Удалить все скрипты"
        display_menu_item "0" "Назад" ""
        echo
        
        display_prompt "Выберите опцию" ""
        read -r choice
        
        case "$choice" in
            1) install_management_scripts "all"; pause_for_user ;;
            2) install_management_scripts "panel"; pause_for_user ;;
            3) install_management_scripts "node"; pause_for_user ;;
            4) install_management_scripts "selfsteal"; pause_for_user ;;
            5) update_management_scripts; pause_for_user ;;
            6) check_management_scripts; pause_for_user ;;
            7) uninstall_management_scripts; pause_for_user ;;
            0) break ;;
            *) display_error "Неверный выбор"; sleep 1 ;;
        esac
    done
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

is_remnawave_script_installed() {
    [ -f "/usr/local/bin/remnawave" ]
}

is_remnanode_script_installed() {
    [ -f "/usr/local/bin/remnanode" ]
}

is_selfsteal_script_installed() {
    [ -f "/usr/local/bin/selfsteal" ]
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f install_management_scripts
export -f install_remnawave_script
export -f install_remnanode_script
export -f install_selfsteal_script
export -f check_management_scripts
export -f update_management_scripts
export -f uninstall_management_scripts
export -f menu_management_scripts
export -f is_remnawave_script_installed
export -f is_remnanode_script_installed
export -f is_selfsteal_script_installed
