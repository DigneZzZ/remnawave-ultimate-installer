#!/usr/bin/env bash
# All-in-One Auto-Configuration Module
# Description: Automatic configuration for all-in-one installations
# Author: DigneZzZ
# Version: 1.0.0

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/api.sh"
source "$SCRIPT_DIR/../../lib/panel-api.sh"
source "$SCRIPT_DIR/../../lib/user-api.sh"
source "$SCRIPT_DIR/../../lib/xray-config.sh"

# =============================================================================
# ALL-IN-ONE AUTO-CONFIGURATION
# =============================================================================

# Auto-configure all-in-one after installation
# Args: $1=admin_token, $2=domain, $3=selfsteal_domain
auto_configure_all_in_one() {
    local admin_token="$1"
    local domain="$2"
    local selfsteal_domain="$3"
    
    local panel_url="127.0.0.1:${DEFAULT_PANEL_PORT}"
    local node_address="172.17.0.1"  # Docker bridge IP for local node
    local node_port="${DEFAULT_NODE_PORT}"
    
    display_section "$ICON_CONFIG" "Автоматическая настройка All-in-One"
    
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
    display_info "Profile UUID: $profile_uuid"
    display_info "Inbound UUID: $inbound_uuid"
    
    # Step 5: Create local node entry
    if ! api_create_node "$panel_url" "$admin_token" "$domain" \
        "Local-Node" "$node_address" "$node_port" "$profile_uuid" "$inbound_uuid"; then
        display_warning "Не удалось создать node"
    fi
    
    # Step 6: Create host entry for selfsteal domain
    if ! api_create_host "$panel_url" "$admin_token" "$domain" \
        "$profile_uuid" "$inbound_uuid" "$selfsteal_domain" 443 "VLESS"; then
        display_warning "Не удалось создать host"
    fi
    
    # Step 7: Get squads and update
    local squads_response=$(api_get_squads "$panel_url" "$admin_token" "$domain")
    if [ $? -eq 0 ] && [ -n "$squads_response" ]; then
        local squad_uuid=$(echo "$squads_response" | jq -r '.response.internalSquads[0].uuid // empty' 2>/dev/null)
        
        if [ -n "$squad_uuid" ] && [ "$squad_uuid" != "null" ]; then
            display_info "Squad UUID: $squad_uuid"
            
            if ! api_update_squad_inbounds "$panel_url" "$admin_token" "$domain" \
                "$squad_uuid" "$inbound_uuid"; then
                display_warning "Не удалось обновить squad"
            fi
            
            # Step 8: Create default user
            display_step "Создание пользователя 'remnawave'..."
            if api_create_user "$panel_url" "$admin_token" "$domain" \
                "remnawave" "$inbound_uuid" "$squad_uuid"; then
                
                display_success "Пользователь создан"
                
                # Build full subscription URL
                local subscription_url="https://${domain}/api/subscription/${USER_SUBSCRIPTION_UUID}"
                
                # Display user credentials
                echo
                display_info "=== Учетные данные пользователя ==="
                display_info "Username: remnawave"
                display_info "VLESS UUID: ${USER_VLESS_UUID}"
                display_info "Subscription URL: ${subscription_url}"
                display_info "Public Key: ${public_key}"
                display_info "Selfsteal Domain: ${selfsteal_domain}"
                echo
                
                # Save to file
                local creds_file="$BASE_DIR/user_credentials.txt"
                cat >"$creds_file" <<EOF
=== Remnawave All-in-One User Credentials ===
Created: $(date)

Username: remnawave
UUID: ${USER_VLESS_UUID}
Short UUID: ${USER_SHORT_UUID}
Subscription UUID: ${USER_SUBSCRIPTION_UUID}
Subscription URL: ${subscription_url}

VLESS UUID: ${USER_VLESS_UUID}
Trojan Password: ${USER_TROJAN_PASSWORD}
Shadowsocks Password: ${USER_SS_PASSWORD}

=== Xray Reality Settings ===
Public Key: ${public_key}
Selfsteal Domain: ${selfsteal_domain}
Node Address: ${node_address}:${node_port}

=== Panel Access ===
Panel Domain: ${domain}
Admin credentials: (see panel_credentials.txt)
EOF
                chmod 600 "$creds_file"
                display_success "Учетные данные сохранены в $creds_file"
            else
                display_error "Не удалось создать пользователя"
            fi
        else
            display_error "Не удалось найти squad"
        fi
    else
        display_error "Не удалось получить список squad"
    fi
    
    display_success "Автоматическая настройка завершена"
    return 0
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f auto_configure_all_in_one
