#!/usr/bin/env bash
# Remnawave API Client
# Description: Core HTTP client for Remnawave Panel API
# Author: DigneZzZ
# Version: 1.0.0

# =============================================================================
# HTTP REQUEST FUNCTIONS
# =============================================================================

# Make API request to Remnawave Panel
# Args: $1=method, $2=url, $3=token, $4=domain, $5=data
make_api_request() {
    local method="$1"
    local url="$2"
    local token="$3"
    local domain="$4"
    local data="$5"
    
    # Extract host from URL for X-Forwarded-For
    local host_only=$(echo "$url" | sed 's|http://||' | cut -d'/' -f1)
    
    # Build headers
    local headers=(
        -H "Content-Type: application/json"
        -H "Host: $domain"
        -H "X-Forwarded-For: $host_only"
        -H "X-Forwarded-Proto: https"
        -H "X-Remnawave-Client-type: browser"
    )
    
    # Add Authorization if token provided
    if [ -n "$token" ]; then
        headers+=(-H "Authorization: Bearer $token")
    fi
    
    # Make request
    if [ -n "$data" ]; then
        curl -s -X "$method" "$url" "${headers[@]}" -d "$data"
    else
        curl -s -X "$method" "$url" "${headers[@]}"
    fi
}

# =============================================================================
# AUTHENTICATION FUNCTIONS
# =============================================================================

# Register admin user and get token
# Args: $1=panel_url, $2=domain, $3=username, $4=password
api_register_admin() {
    local panel_url="$1"
    local domain="$2"
    local username="$3"
    local password="$4"
    
    local api_url="http://${panel_url}/api/auth/register"
    local max_wait=180
    local start_time=$(date +%s)
    local end_time=$((start_time + max_wait))
    
    display_step "Регистрация администратора..."
    
    while [ $(date +%s) -lt $end_time ]; do
        local response=$(make_api_request "POST" "$api_url" "" "$domain" \
            "{\"username\":\"$username\",\"password\":\"$password\"}")
        
        if [ -z "$response" ]; then
            sleep 2
            continue
        fi
        
        if echo "$response" | jq -e '.response.accessToken' >/dev/null 2>&1; then
            local token=$(echo "$response" | jq -r '.response.accessToken')
            echo "$token"
            return 0
        fi
        
        sleep 2
    done
    
    display_error "Не удалось зарегистрировать администратора"
    return 1
}

# Get existing admin token (for re-login)
# Args: $1=panel_url, $2=domain, $3=username, $4=password
api_login_admin() {
    local panel_url="$1"
    local domain="$2"
    local username="$3"
    local password="$4"
    
    local api_url="http://${panel_url}/api/auth/login"
    
    local response=$(make_api_request "POST" "$api_url" "" "$domain" \
        "{\"username\":\"$username\",\"password\":\"$password\"}")
    
    if [ -z "$response" ]; then
        display_error "Пустой ответ при авторизации"
        return 1
    fi
    
    if echo "$response" | jq -e '.response.accessToken' >/dev/null 2>&1; then
        local token=$(echo "$response" | jq -r '.response.accessToken')
        echo "$token"
        return 0
    fi
    
    display_error "Не удалось получить токен"
    return 1
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Wait for panel API to be ready
# Args: $1=panel_url, $2=domain
api_wait_for_panel() {
    local panel_url="$1"
    local domain="$2"
    local max_wait=120
    local start_time=$(date +%s)
    local end_time=$((start_time + max_wait))
    
    display_step "Ожидание готовности API панели..."
    
    while [ $(date +%s) -lt $end_time ]; do
        if curl -s -f -H "Host: $domain" "http://${panel_url}/api/health" >/dev/null 2>&1; then
            display_success "API панели готов"
            return 0
        fi
        sleep 2
    done
    
    display_error "API панели не готов"
    return 1
}

# Check API response for errors
# Args: $1=response, $2=expected_field (optional)
api_check_response() {
    local response="$1"
    local expected_field="$2"
    
    if [ -z "$response" ]; then
        display_error "Пустой ответ от API"
        return 1
    fi
    
    # Check for error field
    if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
        local error_msg=$(echo "$response" | jq -r '.error.message // .error')
        display_error "Ошибка API: $error_msg"
        return 1
    fi
    
    # Check for expected field if provided
    if [ -n "$expected_field" ]; then
        if ! echo "$response" | jq -e "$expected_field" >/dev/null 2>&1; then
            display_error "Отсутствует ожидаемое поле: $expected_field"
            return 1
        fi
    fi
    
    return 0
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f make_api_request
export -f api_register_admin
export -f api_login_admin
export -f api_wait_for_panel
export -f api_check_response
