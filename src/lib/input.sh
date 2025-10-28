#!/usr/bin/env bash
# Input Functions for Remnawave Ultimate Installer
# Provides interactive input handlers with validation
# Author: DigneZzZ
# Version: 1.0.0

# Prevent double loading
[[ -n "${INPUT_LOADED}" ]] && return 0
readonly INPUT_LOADED=1

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/display.sh"
source "$SCRIPT_DIR/../core/validation.sh"

# =============================================================================
# BASIC INPUT
# =============================================================================

read_input() {
    local prompt="$1"
    local default="$2"
    local validation_func="${3:-}"
    local result=""
    
    while true; do
        # Show prompt
        if [ -n "$default" ]; then
            display_prompt "$prompt" "$default"
            read -r -p "> " result
            result="${result:-$default}"
        else
            display_prompt "$prompt" ""
            read -r -p "> " result
        fi
        
        # Validate if function provided
        if [ -n "$validation_func" ]; then
            if $validation_func "$result"; then
                echo "$result"
                return 0
            else
                display_error "Неверный ввод. Попробуйте снова."
                continue
            fi
        else
            echo "$result"
            return 0
        fi
    done
}

read_input_silent() {
    local prompt="$1"
    local default="$2"
    local result=""
    
    if [ -n "$default" ]; then
        read -r -p "${prompt} [${default}]: " result
        echo "${result:-$default}"
    else
        read -r -p "${prompt}: " result
        echo "$result"
    fi
}

read_required_input() {
    local prompt="$1"
    local validation_func="${2:-}"
    local result=""
    
    while true; do
        display_prompt "$prompt" ""
        read -r -p "> " result
        
        if [ -z "$result" ]; then
            display_error "Это поле обязательно"
            continue
        fi
        
        if [ -n "$validation_func" ]; then
            if $validation_func "$result"; then
                echo "$result"
                return 0
            else
                display_error "Неверный ввод. Попробуйте снова."
                continue
            fi
        else
            echo "$result"
            return 0
        fi
    done
}

# =============================================================================
# PASSWORD INPUT
# =============================================================================

read_password() {
    local prompt="$1"
    local confirm="${2:-false}"
    local min_length="${3:-8}"
    local password=""
    local password_confirm=""
    
    while true; do
        display_prompt "$prompt" ""
        read -r -s -p "> " password
        echo
        
        if [ -z "$password" ]; then
            display_error "Пароль не может быть пустым"
            continue
        fi
        
        if [ ${#password} -lt "$min_length" ]; then
            display_error "Пароль должен быть не менее $min_length символов"
            continue
        fi
        
        if [ "$confirm" = "true" ]; then
            display_prompt "Подтвердите пароль" ""
            read -r -s -p "> " password_confirm
            echo
            
            if [ "$password" != "$password_confirm" ]; then
                display_error "Пароли не совпадают"
                continue
            fi
        fi
        
        echo "$password"
        return 0
    done
}

read_password_with_strength() {
    local prompt="$1"
    local confirm="${2:-true}"
    local password=""
    
    while true; do
        display_prompt "$prompt" ""
        read -r -s -p "> " password
        echo
        
        if ! validate_password_strength "$password"; then
            display_error "Пароль должен содержать минимум 8 символов, заглавные и строчные буквы, цифры"
            continue
        fi
        
        if [ "$confirm" = "true" ]; then
            display_prompt "Подтвердите пароль" ""
            read -r -s -p "> " password_confirm
            echo
            
            if [ "$password" != "$password_confirm" ]; then
                display_error "Пароли не совпадают"
                continue
            fi
        fi
        
        echo "$password"
        return 0
    done
}

# =============================================================================
# CONFIRMATION
# =============================================================================

confirm_action() {
    local message="$1"
    local default="${2:-n}"
    local response=""
    
    if [ "$default" = "y" ]; then
        display_prompt "$message" "Y/n"
        read -r -p "> " response
        response="${response:-y}"
    else
        display_prompt "$message" "y/N"
        read -r -p "> " response
        response="${response:-n}"
    fi
    
    case "$response" in
        [yYдД]*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

confirm_with_warning() {
    local message="$1"
    local warning="$2"
    
    echo
    display_warning "$warning"
    echo
    
    confirm_action "$message" "n"
}

confirm_destructive() {
    local action="$1"
    local confirmation_word="${2:-DELETE}"
    
    echo
    display_warning "ВНИМАНИЕ: Это действие необратимо!"
    echo
    display_info "Действие: $action"
    echo
    display_prompt "Введите '$confirmation_word' для подтверждения" ""
    
    local response=""
    read -r -p "> " response
    
    if [ "$response" = "$confirmation_word" ]; then
        return 0
    else
        display_error "Действие отменено"
        return 1
    fi
}

# =============================================================================
# SELECTION MENU
# =============================================================================

select_from_list() {
    local title="$1"
    shift
    local options=("$@")
    local choice=""
    
    if [ ${#options[@]} -eq 0 ]; then
        display_error "Список опций пуст"
        return 1
    fi
    
    while true; do
        echo
        display_section "$ICON_MENU" "$title"
        
        for i in "${!options[@]}"; do
            display_menu_item "$((i + 1))" "${options[$i]}"
        done
        
        echo
        display_prompt "Выберите опцию (1-${#options[@]})" ""
        read -r -p "> " choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
            echo "${options[$((choice - 1))]}"
            return 0
        else
            display_error "Неверный выбор"
        fi
    done
}

select_multiple() {
    local title="$1"
    shift
    local options=("$@")
    local selected=()
    
    if [ ${#options[@]} -eq 0 ]; then
        display_error "Список опций пуст"
        return 1
    fi
    
    display_section "$ICON_MENU" "$title"
    echo
    
    for i in "${!options[@]}"; do
        display_menu_item "$((i + 1))" "${options[$i]}"
    done
    
    echo
    display_info "Введите номера через пробел (например: 1 3 5)"
    display_prompt "Ваш выбор" ""
    
    local input=""
    read -r -p "> " input
    
    for num in $input; do
        if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#options[@]}" ]; then
            selected+=("${options[$((num - 1))]}")
        fi
    done
    
    if [ ${#selected[@]} -eq 0 ]; then
        display_error "Ничего не выбрано"
        return 1
    fi
    
    echo "${selected[@]}"
    return 0
}

select_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    
    if confirm_action "$prompt" "$default"; then
        echo "yes"
    else
        echo "no"
    fi
}

# =============================================================================
# MULTILINE INPUT
# =============================================================================

read_multiline() {
    local prompt="$1"
    local end_marker="${2:-EOF}"
    local lines=()
    local line=""
    
    display_info "$prompt"
    echo -e "${GRAY}(Введите '$end_marker' на новой строке для завершения)${NC}"
    echo
    
    while IFS= read -r line; do
        if [ "$line" = "$end_marker" ]; then
            break
        fi
        lines+=("$line")
    done
    
    printf "%s\n" "${lines[@]}"
}

read_file_content() {
    local prompt="$1"
    
    display_prompt "$prompt" ""
    local filepath=""
    read -r -p "> " filepath
    
    if ! validate_file_exists "$filepath"; then
        display_error "Файл не найден: $filepath"
        return 1
    fi
    
    cat "$filepath"
}

# =============================================================================
# DOMAIN INPUT
# =============================================================================

read_domain() {
    local prompt="${1:-Введите домен}"
    local allow_ip="${2:-false}"
    local domain=""
    
    while true; do
        # Output prompt to stderr so it's not captured by command substitution
        display_prompt "$prompt" "" >&2
        read -r -p "> " domain
        
        if [ -z "$domain" ]; then
            display_error "Домен не может быть пустым" >&2
            continue
        fi
        
        if validate_domain_format "$domain"; then
            echo "$domain"
            return 0
        elif [ "$allow_ip" = "true" ] && validate_ip_format "$domain"; then
            echo "$domain"
            return 0
        else
            display_error "Неверный формат домена" >&2
        fi
    done
}

read_email() {
    local prompt="${1:-Введите email}"
    local email=""
    
    while true; do
        display_prompt "$prompt" ""
        read -r -p "> " email
        
        if [ -z "$email" ]; then
            display_error "Email не может быть пустым"
            continue
        fi
        
        if validate_email "$email"; then
            echo "$email"
            return 0
        else
            display_error "Неверный формат email"
        fi
    done
}

read_port() {
    local prompt="${1:-Введите порт}"
    local default="${2:-}"
    local port=""
    
    while true; do
        if [ -n "$default" ]; then
            display_prompt "$prompt" "$default"
            read -r -p "> " port
            port="${port:-$default}"
        else
            display_prompt "$prompt" ""
            read -r -p "> " port
        fi
        
        if validate_port "$port"; then
            echo "$port"
            return 0
        else
            display_error "Неверный порт (1-65535)"
        fi
    done
}

# =============================================================================
# NUMERIC INPUT
# =============================================================================

read_number() {
    local prompt="$1"
    local min="${2:-}"
    local max="${3:-}"
    local default="${4:-}"
    local number=""
    
    while true; do
        if [ -n "$default" ]; then
            display_prompt "$prompt" "$default"
            read -r -p "> " number
            number="${number:-$default}"
        else
            display_prompt "$prompt" ""
            read -r -p "> " number
        fi
        
        if ! [[ "$number" =~ ^[0-9]+$ ]]; then
            display_error "Введите число"
            continue
        fi
        
        if [ -n "$min" ] && [ "$number" -lt "$min" ]; then
            display_error "Число должно быть не меньше $min"
            continue
        fi
        
        if [ -n "$max" ] && [ "$number" -gt "$max" ]; then
            display_error "Число должно быть не больше $max"
            continue
        fi
        
        echo "$number"
        return 0
    done
}

read_float() {
    local prompt="$1"
    local default="${2:-}"
    local number=""
    
    while true; do
        if [ -n "$default" ]; then
            display_prompt "$prompt" "$default"
            read -r -p "> " number
            number="${number:-$default}"
        else
            display_prompt "$prompt" ""
            read -r -p "> " number
        fi
        
        if [[ "$number" =~ ^[0-9]*\.?[0-9]+$ ]]; then
            echo "$number"
            return 0
        else
            display_error "Введите число"
        fi
    done
}

# =============================================================================
# ADVANCED INPUT
# =============================================================================

read_with_autocomplete() {
    local prompt="$1"
    shift
    local suggestions=("$@")
    
    display_prompt "$prompt" ""
    display_info "Доступные варианты: ${suggestions[*]}"
    
    local input=""
    read -r -p "> " input
    echo "$input"
}

read_with_timeout() {
    local prompt="$1"
    local timeout="$2"
    local default="$3"
    
    display_prompt "$prompt (${timeout}s)" "$default"
    
    local input=""
    if read -r -t "$timeout" -p "> " input; then
        echo "${input:-$default}"
    else
        echo
        display_warning "Timeout - используется значение по умолчанию"
        echo "$default"
    fi
}

press_any_key() {
    local message="${1:-Нажмите любую клавишу для продолжения...}"
    
    echo
    read -n 1 -s -r -p "${GRAY}${message}${NC}"
    echo
}

wait_for_enter() {
    local message="${1:-Нажмите Enter для продолжения...}"
    
    echo
    read -r -p "${GRAY}${message}${NC}"
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f read_input
export -f read_input_silent
export -f read_required_input
export -f read_password
export -f read_password_with_strength
export -f confirm_action
export -f confirm_with_warning
export -f confirm_destructive
export -f select_from_list
export -f select_multiple
export -f select_yes_no
export -f read_multiline
export -f read_file_content
export -f read_domain
export -f read_email
export -f read_port
export -f read_number
export -f read_float
export -f read_with_autocomplete
export -f read_with_timeout
export -f press_any_key
export -f wait_for_enter
