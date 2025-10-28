#!/usr/bin/env bash
# Panel Auto-Configuration Module
# Description: Automatic panel configuration via API after installation
# Author: DigneZzZ
# Version: 1.0.0

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/api.sh"
source "$SCRIPT_DIR/../../lib/panel-api.sh"
source "$SCRIPT_DIR/../../lib/user-api.sh"
source "$SCRIPT_DIR/../../lib/xray-config.sh"

# =============================================================================
# PANEL ONLY AUTO-CONFIGURATION
# =============================================================================

# Auto-configure panel after installation (Panel-Only mode)
# Args: $1=admin_token, $2=domain, $3=node_address, $4=node_port, $5=selfsteal_domain
auto_configure_panel_only() {
    local admin_token="$1"
    local domain="$2"
    local node_address="$3"
    local node_port="$4"
    local selfsteal_domain="$5"
    
    local panel_url="127.0.0.1:${DEFAULT_PANEL_PORT}"
    
    display_section "$ICON_CONFIG" "Автоматическая настройка панели"
    
    # Wait for API to be ready
    if ! api_wait_for_panel "$panel_url" "$domain"; then
        display_error "API панели не готов"
        return 1
    fi
    
    sleep 3
    
    # Step 1: Generate x25519 keys
    display_step "Генерация ключей..."
    local keys=$(api_generate_x25519_keys "$panel_url" "$admin_token" "$domain")
    if [ $? -ne 0 ] || [ -z "$keys" ]; then
        display_error "Не удалось сгенерировать ключи"
        return 1
    fi
    
    local private_key=$(echo "$keys" | cut -d':' -f1)
    local public_key=$(echo "$keys" | cut -d':' -f2)
    
    display_success "Ключи сгенерированы"
    display_info "Public Key: $public_key"
    
    # Step 2: Generate Xray Reality config
    display_step "Генерация Xray конфигурации..."
    local caddy_port="${DEFAULT_CADDY_LOCAL_PORT}"
    local xray_config=$(generate_xray_reality_config "$selfsteal_domain" "$caddy_port" "$private_key")
    
    if ! validate_xray_config "$xray_config"; then
        display_error "Некорректная конфигурация Xray"
        return 1
    fi
    
    # Step 3: Delete default config profile if exists
    local profiles_response=$(api_get_config_profiles "$panel_url" "$admin_token" "$domain")
    if [ $? -eq 0 ] && [ -n "$profiles_response" ]; then
        local default_profile=$(echo "$profiles_response" | jq -r '.response.configProfiles[0].uuid // empty' 2>/dev/null)
        if [ -n "$default_profile" ] && [ "$default_profile" != "null" ]; then
            display_step "Удаление дефолтного профиля..."
            api_delete_config_profile "$panel_url" "$admin_token" "$domain" "$default_profile"
        fi
    fi
    
    # Step 4: Create config profile
    local profile_result=$(api_create_config_profile "$panel_url" "$admin_token" "$domain" \
        "VLESS Reality" "$xray_config")
    
    if [ $? -ne 0 ] || [ -z "$profile_result" ]; then
        display_error "Не удалось создать профиль конфигурации"
        return 1
    fi
    
    local profile_uuid=$(echo "$profile_result" | cut -d':' -f1)
    local inbound_uuid=$(echo "$profile_result" | cut -d':' -f2)
    
    display_success "Config Profile создан"
    
    # Step 5: Create node entry
    if ! api_create_node "$panel_url" "$admin_token" "$domain" \
        "Node-1" "$node_address" "$node_port" "$profile_uuid" "$inbound_uuid"; then
        display_warning "Не удалось создать node автоматически"
    fi
    
    # Step 6: Create host entry
    if ! api_create_host "$panel_url" "$admin_token" "$domain" \
        "$profile_uuid" "$inbound_uuid" "$selfsteal_domain" 443 "VLESS"; then
        display_warning "Не удалось создать host автоматически"
    fi
    
    # Step 7: Get squads and update
    local squads_response=$(api_get_squads "$panel_url" "$admin_token" "$domain")
    if [ $? -eq 0 ] && [ -n "$squads_response" ]; then
        local squad_uuid=$(echo "$squads_response" | jq -r '.response.internalSquads[0].uuid // empty' 2>/dev/null)
        
        if [ -n "$squad_uuid" ] && [ "$squad_uuid" != "null" ]; then
            if ! api_update_squad_inbounds "$panel_url" "$admin_token" "$domain" \
                "$squad_uuid" "$inbound_uuid"; then
                display_warning "Не удалось обновить squad автоматически"
            fi
            
            # Step 8: Create default user
            display_step "Создание пользователя..."
            if api_create_user "$panel_url" "$admin_token" "$domain" \
                "remnawave" "$inbound_uuid" "$squad_uuid"; then
                
                display_success "Пользователь создан"
                
                # Display user credentials
                display_info "Subscription URL: ${USER_SUBSCRIPTION_URL}"
                display_info "VLESS UUID: ${USER_VLESS_UUID}"
                
                # Save to file
                local creds_file="$BASE_DIR/user_credentials.txt"
                cat >"$creds_file" <<EOF
=== Remnawave User Credentials ===
Username: remnawave
UUID: ${USER_VLESS_UUID}
Subscription UUID: ${USER_SUBSCRIPTION_UUID}
Subscription URL: ${USER_SUBSCRIPTION_URL}
Trojan Password: ${USER_TROJAN_PASSWORD}
Shadowsocks Password: ${USER_SS_PASSWORD}

Public Key: ${public_key}
Selfsteal Domain: ${selfsteal_domain}
EOF
                display_success "Учетные данные сохранены в $creds_file"
            fi
        fi
    fi
    
    display_success "Автоматическая настройка завершена"
    return 0
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f auto_configure_panel_only
