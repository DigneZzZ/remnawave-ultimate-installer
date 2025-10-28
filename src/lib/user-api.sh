#!/usr/bin/env bash
# Remnawave User API Functions
# Description: API functions for managing users
# Author: DigneZzZ
# Version: 1.0.0

# Prevent double loading
[[ -n "${USER_API_LOADED}" ]] && return 0
readonly USER_API_LOADED=1

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/api.sh"

# =============================================================================
# USER CREATION FUNCTIONS
# =============================================================================

# Create Remnawave user
# Args: $1=panel_url, $2=token, $3=domain, $4=username, $5=inbound_uuid, $6=squad_uuid
api_create_user() {
    local panel_url="$1"
    local token="$2"
    local domain="$3"
    local username="$4"
    local inbound_uuid="$5"
    local squad_uuid="$6"
    
    display_step "Создание пользователя '$username'..."
    
    local payload=$(jq -n \
        --arg username "$username" \
        --arg inbound "$inbound_uuid" \
        --arg squad "$squad_uuid" \
        '{
            username: $username,
            status: "ACTIVE",
            trafficLimitBytes: 0,
            trafficLimitStrategy: "NO_RESET",
            activeUserInbounds: [$inbound],
            activeInternalSquads: [$squad],
            expireAt: "2099-12-31T23:59:59.000Z",
            description: "User created during installation",
            hwidDeviceLimit: 0
        }')
    
    # Build headers with status code capture
    local host_only=$(echo "http://${panel_url}/api/users" | sed 's|http://||' | cut -d'/' -f1)
    
    local headers=(
        -H "Content-Type: application/json"
        -H "Host: $domain"
        -H "X-Forwarded-For: $host_only"
        -H "X-Forwarded-Proto: https"
        -H "X-Remnawave-Client-type: browser"
        -H "Authorization: Bearer $token"
    )
    
    # Make request and capture status code
    local temp_file=$(mktemp)
    local response=$(curl -s -w "\n%{http_code}" -X "POST" \
        "http://${panel_url}/api/users" \
        "${headers[@]}" -d "$payload" 2>&1 | tee "$temp_file")
    
    local status_code=$(tail -n1 "$temp_file")
    local body=$(head -n-1 "$temp_file")
    rm -f "$temp_file"
    
    # Check for 201 status
    if [ "$status_code" != "201" ]; then
        display_error "Не удалось создать пользователя (status: $status_code)"
        return 1
    fi
    
    if ! echo "$body" | jq -e '.response.uuid' >/dev/null 2>&1; then
        display_error "Не удалось получить данные пользователя"
        return 1
    fi
    
    # Extract user data
    local user_uuid=$(echo "$body" | jq -r '.response.uuid')
    local user_short_uuid=$(echo "$body" | jq -r '.response.shortUuid')
    local user_subscription_uuid=$(echo "$body" | jq -r '.response.subscriptionUuid')
    local user_vless_uuid=$(echo "$body" | jq -r '.response.vlessUuid')
    local user_trojan_password=$(echo "$body" | jq -r '.response.trojanPassword')
    local user_ss_password=$(echo "$body" | jq -r '.response.ssPassword')
    local user_subscription_url=$(echo "$body" | jq -r '.response.subscriptionUrl')
    
    # Save to global variables
    USER_UUID="$user_uuid"
    USER_SHORT_UUID="$user_short_uuid"
    USER_SUBSCRIPTION_UUID="$user_subscription_uuid"
    USER_VLESS_UUID="$user_vless_uuid"
    USER_TROJAN_PASSWORD="$user_trojan_password"
    USER_SS_PASSWORD="$user_ss_password"
    USER_SUBSCRIPTION_URL="$user_subscription_url"
    
    display_success "Пользователь создан"
    
    # Return user data as JSON
    echo "$body"
}

# Get user details
# Args: $1=panel_url, $2=token, $3=domain, $4=user_uuid
api_get_user() {
    local panel_url="$1"
    local token="$2"
    local domain="$3"
    local user_uuid="$4"
    
    local response=$(make_api_request "GET" \
        "http://${panel_url}/api/users/${user_uuid}" \
        "$token" "$domain" "")
    
    if ! api_check_response "$response" ".response.uuid"; then
        return 1
    fi
    
    echo "$response"
}

# =============================================================================
# USER LIST FUNCTIONS
# =============================================================================

# Get all users
# Args: $1=panel_url, $2=token, $3=domain
api_get_users() {
    local panel_url="$1"
    local token="$2"
    local domain="$3"
    
    local response=$(make_api_request "GET" \
        "http://${panel_url}/api/users" \
        "$token" "$domain" "")
    
    if ! api_check_response "$response"; then
        return 1
    fi
    
    echo "$response"
}

# =============================================================================
# SUBSCRIPTION FUNCTIONS
# =============================================================================

# Get user subscription URL
# Args: $1=domain, $2=subscription_uuid
api_build_subscription_url() {
    local domain="$1"
    local subscription_uuid="$2"
    
    echo "https://${domain}/api/subscription/${subscription_uuid}"
}

# =============================================================================
# INBOUND FUNCTIONS
# =============================================================================

# Get all inbounds
# Args: $1=panel_url, $2=token, $3=domain
api_get_inbounds() {
    local panel_url="$1"
    local token="$2"
    local domain="$3"
    
    local response=$(make_api_request "GET" \
        "http://${panel_url}/api/inbounds" \
        "$token" "$domain" "")
    
    if ! api_check_response "$response" ".response"; then
        return 1
    fi
    
    echo "$response"
}

# Get first inbound UUID (for quick setup)
# Args: $1=panel_url, $2=token, $3=domain
api_get_first_inbound_uuid() {
    local panel_url="$1"
    local token="$2"
    local domain="$3"
    
    local response=$(api_get_inbounds "$panel_url" "$token" "$domain")
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    local inbound_uuid=$(echo "$response" | jq -r '.response[0].uuid')
    
    if [ -z "$inbound_uuid" ] || [ "$inbound_uuid" = "null" ]; then
        display_error "Не удалось получить UUID inbound"
        return 1
    fi
    
    echo "$inbound_uuid"
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f api_create_user
export -f api_get_user
export -f api_get_users
export -f api_build_subscription_url
export -f api_get_inbounds
export -f api_get_first_inbound_uuid

# Export global variables
export USER_UUID=""
export USER_SHORT_UUID=""
export USER_SUBSCRIPTION_UUID=""
export USER_VLESS_UUID=""
export USER_TROJAN_PASSWORD=""
export USER_SS_PASSWORD=""
export USER_SUBSCRIPTION_URL=""
