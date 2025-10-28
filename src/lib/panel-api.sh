#!/usr/bin/env bash
# Remnawave Panel API Functions
# Description: API functions for managing panel configuration
# Author: DigneZzZ
# Version: 1.0.0

# Prevent double loading
[[ -n "${PANEL_API_LOADED}" ]] && return 0
readonly PANEL_API_LOADED=1

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/api.sh"

# =============================================================================
# CONFIG PROFILE FUNCTIONS
# =============================================================================

# Get all config profiles
# Args: $1=panel_url, $2=token, $3=domain
api_get_config_profiles() {
    local panel_url="$1"
    local token="$2"
    local domain="$3"
    
    local response=$(make_api_request "GET" \
        "http://${panel_url}/api/config-profiles" \
        "$token" "$domain" "")
    
    if ! api_check_response "$response" ".response.configProfiles"; then
        return 1
    fi
    
    echo "$response"
}

# Delete config profile
# Args: $1=panel_url, $2=token, $3=domain, $4=profile_uuid
api_delete_config_profile() {
    local panel_url="$1"
    local token="$2"
    local domain="$3"
    local profile_uuid="$4"
    
    display_step "Удаление профиля конфигурации..."
    
    local response=$(make_api_request "DELETE" \
        "http://${panel_url}/api/config-profiles/${profile_uuid}" \
        "$token" "$domain" "")
    
    # Success if empty response or isDeleted=true
    if [ -z "$response" ] || echo "$response" | jq -e '.response.isDeleted == true' >/dev/null 2>&1; then
        return 0
    fi
    
    return 1
}

# Create config profile with Xray config
# Args: $1=panel_url, $2=token, $3=domain, $4=profile_name, $5=xray_config_json
api_create_config_profile() {
    local panel_url="$1"
    local token="$2"
    local domain="$3"
    local profile_name="$4"
    local xray_config="$5"
    
    display_step "Создание профиля конфигурации '$profile_name'..."
    
    local payload=$(jq -n \
        --arg name "$profile_name" \
        --argjson config "$xray_config" \
        '{name: $name, config: $config}')
    
    local response=$(make_api_request "POST" \
        "http://${panel_url}/api/config-profiles" \
        "$token" "$domain" "$payload")
    
    if ! api_check_response "$response" ".response.uuid"; then
        display_error "Не удалось создать профиль конфигурации"
        return 1
    fi
    
    # Extract profile UUID and first inbound UUID
    local profile_uuid=$(echo "$response" | jq -r '.response.uuid')
    local inbound_uuid=$(echo "$response" | jq -r '.response.inbounds[0].uuid')
    
    if [ -z "$profile_uuid" ] || [ "$profile_uuid" = "null" ]; then
        display_error "Не удалось получить UUID профиля"
        return 1
    fi
    
    # Return both UUIDs separated by colon
    echo "${profile_uuid}:${inbound_uuid}"
}

# =============================================================================
# NODE FUNCTIONS
# =============================================================================

# Get all nodes
# Args: $1=panel_url, $2=token, $3=domain
api_get_nodes() {
    local panel_url="$1"
    local token="$2"
    local domain="$3"
    
    local response=$(make_api_request "GET" \
        "http://${panel_url}/api/nodes" \
        "$token" "$domain" "")
    
    if ! api_check_response "$response"; then
        return 1
    fi
    
    echo "$response"
}

# Create node entry
# Args: $1=panel_url, $2=token, $3=domain, $4=node_name, $5=node_address, 
#       $6=node_port, $7=profile_uuid, $8=inbound_uuid
api_create_node() {
    local panel_url="$1"
    local token="$2"
    local domain="$3"
    local node_name="$4"
    local node_address="$5"
    local node_port="$6"
    local profile_uuid="$7"
    local inbound_uuid="$8"
    
    display_step "Создание node '$node_name'..."
    
    local payload=$(jq -n \
        --arg name "$node_name" \
        --arg address "$node_address" \
        --argjson port "$node_port" \
        --arg profile "$profile_uuid" \
        --arg inbound "$inbound_uuid" \
        '{
            name: $name,
            address: $address,
            port: $port,
            configProfile: {
                activeConfigProfileUuid: $profile,
                activeInbounds: [$inbound]
            },
            isTrafficTrackingActive: false,
            trafficLimitBytes: 0,
            notifyPercent: 0,
            trafficResetDay: 31,
            excludedInbounds: [],
            countryCode: "XX",
            consumptionMultiplier: 1.0
        }')
    
    local response=$(make_api_request "POST" \
        "http://${panel_url}/api/nodes" \
        "$token" "$domain" "$payload")
    
    if ! api_check_response "$response" ".response.uuid"; then
        display_error "Не удалось создать node"
        return 1
    fi
    
    display_success "Node создан"
    return 0
}

# =============================================================================
# HOST FUNCTIONS
# =============================================================================

# Create host entry
# Args: $1=panel_url, $2=token, $3=domain, $4=profile_uuid, $5=inbound_uuid,
#       $6=host_address, $7=host_port, $8=host_remark
api_create_host() {
    local panel_url="$1"
    local token="$2"
    local domain="$3"
    local profile_uuid="$4"
    local inbound_uuid="$5"
    local host_address="$6"
    local host_port="${7:-443}"
    local host_remark="${8:-VLESS}"
    
    display_step "Создание host для '$host_address'..."
    
    local payload=$(jq -n \
        --arg profile "$profile_uuid" \
        --arg inbound "$inbound_uuid" \
        --arg remark "$host_remark" \
        --arg address "$host_address" \
        --argjson port "$host_port" \
        --arg sni "$host_address" \
        '{
            inbound: {
                configProfileUuid: $profile,
                configProfileInboundUuid: $inbound
            },
            remark: $remark,
            address: $address,
            port: $port,
            path: "",
            sni: $sni,
            host: "",
            alpn: null,
            fingerprint: "chrome",
            allowInsecure: false,
            isDisabled: false,
            securityLayer: "DEFAULT"
        }')
    
    local response=$(make_api_request "POST" \
        "http://${panel_url}/api/hosts" \
        "$token" "$domain" "$payload")
    
    if ! api_check_response "$response" ".response.uuid"; then
        display_error "Не удалось создать host"
        return 1
    fi
    
    display_success "Host создан"
    return 0
}

# =============================================================================
# SQUAD FUNCTIONS
# =============================================================================

# Get all squads
# Args: $1=panel_url, $2=token, $3=domain
api_get_squads() {
    local panel_url="$1"
    local token="$2"
    local domain="$3"
    
    display_step "Получение списка squad..."
    
    local response=$(make_api_request "GET" \
        "http://${panel_url}/api/internal-squads" \
        "$token" "$domain" "")
    
    if ! api_check_response "$response" ".response.internalSquads"; then
        return 1
    fi
    
    echo "$response"
}

# Update squad with new inbounds
# Args: $1=panel_url, $2=token, $3=domain, $4=squad_uuid, $5=inbound_uuid
api_update_squad_inbounds() {
    local panel_url="$1"
    local token="$2"
    local domain="$3"
    local squad_uuid="$4"
    local inbound_uuid="$5"
    
    display_step "Обновление squad..."
    
    # Get current squad data
    local squads_response=$(api_get_squads "$panel_url" "$token" "$domain")
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Extract existing inbounds for this squad
    local existing_inbounds=$(echo "$squads_response" | \
        jq -r --arg uuid "$squad_uuid" \
        '.response.internalSquads[] | select(.uuid == $uuid) | .inbounds[].uuid')
    
    # Build inbounds array (existing + new)
    local inbounds_array
    if [ -z "$existing_inbounds" ]; then
        inbounds_array=$(jq -n --arg new "$inbound_uuid" '[$new]')
    else
        inbounds_array=$(echo "$existing_inbounds" | jq -R . | jq -s '. + ["'"$inbound_uuid"'"] | unique')
    fi
    
    # Create update payload
    local payload=$(jq -n \
        --arg uuid "$squad_uuid" \
        --argjson inbounds "$inbounds_array" \
        '{uuid: $uuid, inbounds: $inbounds}')
    
    local response=$(make_api_request "PATCH" \
        "http://${panel_url}/api/internal-squads" \
        "$token" "$domain" "$payload")
    
    if ! api_check_response "$response" ".response.uuid"; then
        display_error "Не удалось обновить squad"
        return 1
    fi
    
    display_success "Squad обновлен"
    return 0
}

# =============================================================================
# KEY GENERATION FUNCTIONS
# =============================================================================

# Generate x25519 keys via API
# Args: $1=panel_url, $2=token, $3=domain
api_generate_x25519_keys() {
    local panel_url="$1"
    local token="$2"
    local domain="$3"
    
    display_step "Генерация x25519 ключей..."
    
    local response=$(make_api_request "GET" \
        "http://${panel_url}/api/system/tools/x25519/generate" \
        "$token" "$domain" "")
    
    if ! api_check_response "$response" ".response.keypairs"; then
        return 1
    fi
    
    local private_key=$(echo "$response" | jq -r '.response.keypairs[0].privateKey')
    local public_key=$(echo "$response" | jq -r '.response.keypairs[0].publicKey')
    
    if [ -z "$private_key" ] || [ "$private_key" = "null" ]; then
        display_error "Не удалось получить ключи"
        return 1
    fi
    
    # Return keys separated by colon
    echo "${private_key}:${public_key}"
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f api_get_config_profiles
export -f api_delete_config_profile
export -f api_create_config_profile
export -f api_get_nodes
export -f api_create_node
export -f api_create_host
export -f api_get_squads
export -f api_update_squad_inbounds
export -f api_generate_x25519_keys
