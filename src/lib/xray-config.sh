#!/usr/bin/env bash
# Xray Configuration Generator
# Description: Generate Xray configurations for Remnawave Panel
# Author: DigneZzZ
# Version: 1.0.0

# =============================================================================
# XRAY REALITY CONFIGURATION
# =============================================================================

# Generate complete Xray config for config profile
# Args: $1=selfsteal_domain, $2=caddy_port, $3=private_key
generate_xray_reality_config() {
    local selfsteal_domain="$1"
    local caddy_port="$2"
    local private_key="$3"
    
    # Generate short ID (16 hex characters)
    local short_id=$(openssl rand -hex 8)
    
    # Build JSON configuration
    cat <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "dns": {
    "servers": [
      {
        "address": "https://dns.google/dns-query",
        "skipFallback": false
      }
    ],
    "queryStrategy": "UseIPv4"
  },
  "inbounds": [
    {
      "tag": "VLESS",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "127.0.0.1:${caddy_port}",
          "show": false,
          "xver": 1,
          "shortIds": [
            "${short_id}"
          ],
          "privateKey": "${private_key}",
          "serverNames": [
            "${selfsteal_domain}"
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "tag": "DIRECT",
      "protocol": "freedom"
    },
    {
      "tag": "BLOCK",
      "protocol": "blackhole"
    }
  ],
  "routing": {
    "rules": [
      {
        "ip": [
          "geoip:private"
        ],
        "type": "field",
        "outboundTag": "BLOCK"
      },
      {
        "type": "field",
        "protocol": [
          "bittorrent"
        ],
        "outboundTag": "BLOCK"
      }
    ]
  }
}
EOF
}

# =============================================================================
# XRAY LOCAL FILE CONFIGURATION (for node docker)
# =============================================================================

# Generate Xray config file for local node
# Args: $1=output_file, $2=uuid, $3=private_key, $4=short_id
generate_xray_config_file() {
    local output_file="$1"
    local uuid="$2"
    local private_key="$3"
    local short_id="$4"
    
    display_step "Создание конфигурации Xray..."
    
    cat >"$output_file" <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": ${DEFAULT_XRAY_PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "www.google.com:443",
          "serverNames": [
            "www.google.com"
          ],
          "privateKey": "${private_key}",
          "shortIds": [
            "${short_id}"
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
EOF
    
    display_success "Конфигурация Xray создана"
}

# =============================================================================
# KEY GENERATION
# =============================================================================

# Generate x25519 keys (fallback method using Docker)
# No args required
generate_x25519_keys_docker() {
    display_step "Генерация x25519 ключей через Docker..."
    
    local temp_file=$(mktemp)
    
    if ! docker run --rm ghcr.io/xtls/xray-core x25519 >"$temp_file" 2>&1; then
        display_error "Не удалось сгенерировать ключи"
        rm -f "$temp_file"
        return 1
    fi
    
    local keys=$(cat "$temp_file")
    local private_key=$(echo "$keys" | grep "Private key:" | awk '{print $3}')
    local public_key=$(echo "$keys" | grep "Public key:" | awk '{print $3}')
    rm -f "$temp_file"
    
    if [ -z "$private_key" ] || [ -z "$public_key" ]; then
        display_error "Не удалось извлечь ключи"
        return 1
    fi
    
    # Return keys separated by colon
    echo "${private_key}:${public_key}"
}

# Smart key generation - try API first, fallback to Docker
# Args: $1=panel_url, $2=token, $3=domain
generate_x25519_keys_smart() {
    local panel_url="$1"
    local token="$2"
    local domain="$3"
    
    # Try API method if parameters provided
    if [ -n "$panel_url" ] && [ -n "$token" ] && [ -n "$domain" ]; then
        # Source panel-api if not already loaded
        if ! declare -f api_generate_x25519_keys >/dev/null 2>&1; then
            local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            source "$script_dir/panel-api.sh"
        fi
        
        local api_result=$(api_generate_x25519_keys "$panel_url" "$token" "$domain" 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$api_result" ]; then
            echo "$api_result"
            return 0
        fi
        
        display_warning "API генерация не удалась, используем Docker..."
    fi
    
    # Fallback to Docker method
    generate_x25519_keys_docker
}

# =============================================================================
# VALIDATION
# =============================================================================

# Validate Xray configuration JSON
# Args: $1=config_json
validate_xray_config() {
    local config="$1"
    
    # Check if valid JSON
    if ! echo "$config" | jq empty 2>/dev/null; then
        display_error "Некорректный JSON в конфигурации Xray"
        return 1
    fi
    
    # Check required fields
    if ! echo "$config" | jq -e '.inbounds' >/dev/null 2>&1; then
        display_error "Отсутствует поле inbounds"
        return 1
    fi
    
    if ! echo "$config" | jq -e '.outbounds' >/dev/null 2>&1; then
        display_error "Отсутствует поле outbounds"
        return 1
    fi
    
    return 0
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f generate_xray_reality_config
export -f generate_xray_config_file
export -f generate_x25519_keys_docker
export -f generate_x25519_keys_smart
export -f validate_xray_config
