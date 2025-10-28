#!/usr/bin/env bash
# Node Installation Module
# Description: Installs Remnawave Node with Xray-core integration
# Dependencies: docker, docker-compose
# Author: DigneZzZ
# Version: 1.0.0

# Prevent double loading
[[ -n "${NODE_INSTALL_LOADED}" ]] && return 0
readonly NODE_INSTALL_LOADED=1

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../config.sh"
source "$SCRIPT_DIR/../../core/display.sh"
source "$SCRIPT_DIR/../../core/validation.sh"
source "$SCRIPT_DIR/../../lib/crypto.sh"
source "$SCRIPT_DIR/../../lib/input.sh"

# =============================================================================
# MAIN INSTALLATION FUNCTION
# =============================================================================

install_node() {
    display_banner "$SCRIPT_VERSION"
    display_section "$ICON_SERVER" "Установка Remnawave Node"
    
    # Validate system
    if ! validate_system_for_node; then
        return 1
    fi
    
    # Check if already installed
    if is_installed "node"; then
        display_warning "Node уже установлен"
        if ! confirm_action "Переустановить?" "n"; then
            return 0
        fi
    fi
    
    # Collect configuration
    display_section "$ICON_CONFIG" "Конфигурация"
    
    # Select Docker image version
    display_info "Выберите версию образа Docker"
    local version_choice=$(select_from_list "Версия" "Latest (стабильная)" "Dev (разработка)")
    
    case "$version_choice" in
        "Latest (стабильная)")
            DOCKER_IMAGE_TAG="latest"
            ;;
        "Dev (разработка)")
            DOCKER_IMAGE_TAG="dev"
            display_warning "Dev версия может быть нестабильной"
            ;;
    esac
    
    # Panel connection info
    display_info "Для подключения к панели нужны IP и сертификат"
    echo
    
    local panel_ip=$(read_input "IP адрес панели" "" "validate_ip_format")
    local node_port=$(read_port "Порт для Node API" "2222")
    
    # SSL Certificate
    display_info "Введите SSL сертификат для подключения к панели"
    display_info "Получить можно в панели: Settings -> Nodes -> Add Node"
    echo
    
    local ssl_certificate=$(read_multiline "SSL Certificate" "END")
    
    # Validate certificate format
    if ! validate_ssl_certificate "$ssl_certificate"; then
        display_error "Неверный формат сертификата"
        return 1
    fi
    
    # Optional: Xray integration
    display_info "Установить Xray-core для работы с трафиком?"
    local install_xray=$(select_yes_no "Установить Xray-core" "y")
    
    if [ "$install_xray" = "yes" ]; then
        ENABLE_XRAY=true
    fi
    
    # Generate credentials
    display_section "$ICON_KEY" "Генерация учетных данных"
    
    local node_token=$(generate_api_key "node")
    
    display_step "Учетные данные сгенерированы"
    
    # Create directory structure
    display_section "$ICON_FOLDER" "Создание структуры"
    
    mkdir -p "$NODE_DIR"/{data,logs,xray}
    
    # Generate docker-compose.yml
    display_step "Создание docker-compose.yml..."
    generate_node_compose "$node_port" "$install_xray"
    
    # Generate .env file
    display_step "Создание .env файла..."
    generate_node_env "$panel_ip" "$node_port" "$ssl_certificate" "$node_token"
    
    # Setup Xray if requested
    if [ "$ENABLE_XRAY" = true ]; then
        display_step "Настройка Xray-core..."
        setup_xray_for_node
    fi
    
    # Setup UFW rules
    if command -v ufw >/dev/null 2>&1; then
        display_step "Настройка firewall..."
        
        # Allow Node API port from panel IP
        if confirm_action "Разрешить подключение с IP панели ($panel_ip)?" "y"; then
            ufw allow from "$panel_ip" to any port "$node_port" proto tcp >/dev/null 2>&1
            display_success "Правило firewall добавлено"
        fi
        
        # Allow Xray ports if enabled
        if [ "$ENABLE_XRAY" = true ]; then
            ufw allow "$DEFAULT_XRAY_PORT"/tcp >/dev/null 2>&1
            ufw allow "$DEFAULT_XRAY_PORT"/udp >/dev/null 2>&1
            display_success "Порты Xray открыты"
        fi
    fi
    
    # Start services
    display_section "$ICON_DOCKER" "Запуск сервисов"
    
    cd "$NODE_DIR" || return 1
    
    display_step "Запуск Node..."
    docker compose up -d
    
    # Wait for node to start
    display_step "Ожидание запуска Node..."
    wait_for_node_ready "$node_port"
    
    # Install management script
    display_section "$ICON_TOOLS" "Установка управляющего скрипта"
    # Install management scripts
    display_section "$ICON_TOOLS" "Установка управляющих скриптов"
    if ! install_management_scripts "node"; then
        display_warning "Управляющие скрипты не установлены"
        display_info "Можно установить вручную: bash install.sh → Tools → Management Scripts"
    fi
    
    # Save installation info
    save_install_info "$INSTALL_TYPE_NODE" "none" "none" "node-$node_port"
    
    # Display completion
    display_completion "Установка завершена!"
    
    display_summary "Информация о Node" \
        "IP Панели|$panel_ip" \
        "Node Port|$node_port" \
        "Node Token|$node_token" \
        "Xray|$([ "$ENABLE_XRAY" = true ] && echo 'Enabled' || echo 'Disabled')"
    
    echo
    display_info "Node API: http://$(get_server_ip):$node_port"
    display_info "Директория: $NODE_DIR"
    display_info "Логи: docker logs -f $NODE_CONTAINER"
    
    if [ "$ENABLE_XRAY" = true ]; then
        echo
        display_info "Xray работает на порту $DEFAULT_XRAY_PORT"
    fi
    
    return 0
}

# =============================================================================
# DOCKER COMPOSE GENERATION
# =============================================================================

generate_node_compose() {
    local node_port="$1"
    local with_xray="$2"
    
    cat > "$NODE_DIR/docker-compose.yml" <<EOF
services:
  remnawave-node:
    image: ${NODE_IMAGE}:${DOCKER_IMAGE_TAG}
    container_name: ${NODE_CONTAINER}
    restart: unless-stopped
    network_mode: host
    env_file:
      - .env
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
EOF

    if [ "$with_xray" = "yes" ]; then
        cat >> "$NODE_DIR/docker-compose.yml" <<EOF
      - ./xray:/app/xray
EOF
    fi

    cat >> "$NODE_DIR/docker-compose.yml" <<EOF
    labels:
      - "remnawave.type=node"
      - "remnawave.version=${SCRIPT_VERSION}"
EOF

    if [ "$with_xray" = "yes" ]; then
        cat >> "$NODE_DIR/docker-compose.yml" <<EOF

  xray:
    image: teddysun/xray:latest
    container_name: xray-core
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./xray/config.json:/etc/xray/config.json:ro
      - ./xray/logs:/var/log/xray
    labels:
      - "remnawave.type=xray"
EOF
    fi
}

# =============================================================================
# ENVIRONMENT FILE GENERATION
# =============================================================================

generate_node_env() {
    local panel_ip="$1"
    local node_port="$2"
    local ssl_cert="$3"
    local node_token="$4"
    
    cat > "$NODE_DIR/.env" <<EOF
# Remnawave Node Configuration
# Generated: $(date)

# Application
APP_PORT=$node_port
NODE_ENV=production

# Panel Connection
PANEL_IP=$panel_ip
NODE_TOKEN=$node_token

# SSL Certificate
$ssl_cert

# Logging
LOG_LEVEL=info
LOG_FILE=/app/logs/remnanode.log

# Xray
XRAY_ENABLED=$ENABLE_XRAY
XRAY_PORT=$DEFAULT_XRAY_PORT
EOF
}

# =============================================================================
# XRAY SETUP
# =============================================================================

setup_xray_for_node() {
    local xray_uuid=$(generate_xray_uuid)
    local xray_private_key=$(generate_xray_private_key)
    local xray_public_key=$(generate_xray_public_key "$xray_private_key")
    local xray_short_id=$(generate_xray_short_id)
    
    # Generate Xray config
    cat > "$NODE_DIR/xray/config.json" <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [
    {
      "port": $DEFAULT_XRAY_PORT,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$xray_uuid",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "www.google.com:443",
          "xver": 0,
          "serverNames": [
            "www.google.com"
          ],
          "privateKey": "$xray_private_key",
          "shortIds": [
            "$xray_short_id"
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ]
}
EOF
    
    display_success "Xray настроен"
    
    # Save Xray credentials
    cat > "$NODE_DIR/xray/credentials.txt" <<EOF
Xray Configuration
==================
UUID: $xray_uuid
Private Key: $xray_private_key
Public Key: $xray_public_key
Short ID: $xray_short_id
Port: $DEFAULT_XRAY_PORT
EOF
}

# =============================================================================
# VALIDATION
# =============================================================================

validate_system_for_node() {
    display_step "Проверка системы..."
    
    if ! validate_root; then
        display_error "Требуются права root"
        return 1
    fi
    
    if ! validate_os; then
        display_error "Неподдерживаемая операционная система"
        return 1
    fi
    
    if ! validate_docker; then
        display_error "Docker не установлен"
        display_info "Установите Docker: https://docs.docker.com/engine/install/"
        return 1
    fi
    
    if ! validate_docker_compose; then
        display_error "Docker Compose не установлен"
        return 1
    fi
    
    # Check required ports
    if ! validate_port_available "2222"; then
        display_warning "Порт 2222 занят"
    fi
    
    display_success "Система готова"
    return 0
}

validate_ssl_certificate() {
    local cert="$1"
    
    # Basic validation - check if contains certificate data
    if [[ "$cert" =~ CERTIFICATE|BEGIN|END ]] || [[ "${#cert}" -gt 50 ]]; then
        return 0
    fi
    
    return 1
}

# =============================================================================
# NODE UTILITIES
# =============================================================================

wait_for_node_ready() {
    local port="$1"
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s http://localhost:"$port"/health >/dev/null 2>&1; then
            display_success "Node запущен"
            return 0
        fi
        
        echo -ne "\r${GRAY}Попытка $attempt/$max_attempts...${NC}"
        sleep 2
        ((attempt++))
    done
    
    echo
    display_warning "Node не ответил на health check"
    return 1
}

# =============================================================================
# NODE MANAGEMENT
# =============================================================================

start_node() {
    display_step "Запуск Node..."
    
    cd "$NODE_DIR" || return 1
    docker compose start remnawave-node
}

stop_node() {
    display_step "Остановка Node..."
    
    cd "$NODE_DIR" || return 1
    docker compose stop remnawave-node
}

restart_node() {
    display_step "Перезапуск Node..."
    
    cd "$NODE_DIR" || return 1
    docker compose restart remnawave-node
}

status_node() {
    display_section "$ICON_INFO" "Статус Node"
    
    if ! is_installed "node"; then
        display_warning "Node не установлен"
        return 1
    fi
    
    cd "$NODE_DIR" || return 1
    docker compose ps
}

logs_node() {
    local lines="${1:-50}"
    local follow="${2:-false}"
    
    if [ "$follow" = "true" ]; then
        docker logs -f --tail "$lines" "$NODE_CONTAINER"
    else
        docker logs --tail "$lines" "$NODE_CONTAINER"
    fi
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f install_node
export -f generate_node_compose
export -f generate_node_env
export -f setup_xray_for_node
export -f validate_system_for_node
export -f validate_ssl_certificate
export -f wait_for_node_ready
export -f start_node
export -f stop_node
export -f restart_node
export -f status_node
export -f logs_node
