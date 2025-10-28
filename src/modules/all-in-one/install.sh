#!/usr/bin/env bash
# All-in-One Installation Module
# Description: Installs Remnawave Panel + Node on the same server
# Dependencies: docker, docker-compose, caddy or nginx
# Author: DigneZzZ
# Version: 1.0.0

# Prevent double loading
[[ -n "${ALL_IN_ONE_INSTALL_LOADED}" ]] && return 0
readonly ALL_IN_ONE_INSTALL_LOADED=1

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../config.sh"
source "$SCRIPT_DIR/../../core/display.sh"
source "$SCRIPT_DIR/../../core/validation.sh"
source "$SCRIPT_DIR/../../lib/crypto.sh"
source "$SCRIPT_DIR/../../lib/input.sh"

# Source installation modules
source "$SCRIPT_DIR/../panel/install.sh"
source "$SCRIPT_DIR/../../providers/caddy/install.sh"
source "$SCRIPT_DIR/../../providers/caddy/config.sh"
source "$SCRIPT_DIR/../../providers/nginx/install.sh"
source "$SCRIPT_DIR/../../providers/nginx/config.sh"
source "$SCRIPT_DIR/../../providers/nginx/ssl.sh"

# Source auto-configuration module
source "$SCRIPT_DIR/auto-configure.sh"

# =============================================================================
# MAIN ALL-IN-ONE INSTALLATION
# =============================================================================

install_all_in_one() {
    display_banner "$SCRIPT_VERSION"
    display_section "$ICON_ROCKET" "Установка Remnawave All-in-One"
    
    display_info "Этот режим установит Panel и Node на одном сервере"
    echo
    
    if ! confirm_action "Продолжить установку All-in-One?" "y"; then
        return 0
    fi
    
    # Validate system
    if ! validate_system_for_all_in_one; then
        return 1
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
    
    local domain=$(read_domain "Введите домен")
    local selfsteal_domain=$(read_domain "Введите selfsteal домен (для VLESS)")
    local admin_email=$(read_email "Введите email администратора")
    local admin_password=$(read_password_with_strength "Создайте пароль администратора" "true")
    
    # Select reverse proxy
    display_info "Выберите reverse proxy"
    local proxy_choice=$(select_from_list "Reverse Proxy" "Caddy (рекомендуется)" "NGINX")
    
    case "$proxy_choice" in
        "Caddy (рекомендуется)")
            CURRENT_REVERSE_PROXY="$PROXY_CADDY"
            ;;
        "NGINX")
            CURRENT_REVERSE_PROXY="$PROXY_NGINX"
            ;;
    esac
    
    # Select security level
    display_info "Выберите уровень безопасности"
    local security_choice=$(select_from_list "Уровень безопасности" \
        "Basic - Только домен" \
        "Cookie Auth - Cookie-based защита" \
        "Full Auth - HTTP Basic Auth")
    
    case "$security_choice" in
        "Basic - Только домен")
            CURRENT_SECURITY_LEVEL="$SECURITY_BASIC"
            ;;
        "Cookie Auth - Cookie-based защита")
            CURRENT_SECURITY_LEVEL="$SECURITY_COOKIE"
            ;;
        "Full Auth - HTTP Basic Auth")
            CURRENT_SECURITY_LEVEL="$SECURITY_FULL"
            ;;
    esac
    
    # Ask about Xray
    ENABLE_XRAY=$(select_yes_no "Установить Xray-core для Node?" "y")
    
    # Generate all credentials
    display_section "$ICON_KEY" "Генерация учетных данных"
    
    local db_password=$(generate_db_password)
    local redis_password=$(generate_secure_password 32)
    local jwt_secret=$(generate_jwt_secret)
    local panel_secret_key=$(generate_secret_key)
    local node_token=$(generate_api_key "node")
    local xray_uuid=$(generate_xray_uuid)
    local xray_private_key=$(generate_xray_private_key)
    local xray_public_key=$(generate_xray_public_key "$xray_private_key")
    local xray_short_id=$(generate_xray_short_id)
    
    display_step "Все учетные данные сгенерированы"
    
    # Create directory structure
    display_section "$ICON_FOLDER" "Создание структуры"
    
    mkdir -p "$PANEL_DIR"/{data,logs,backups}
    mkdir -p "$NODE_DIR"/{data,logs,xray}
    mkdir -p "$BASE_DIR"/{postgres/data,redis/data}
    
    # Install and configure Reverse Proxy
    display_section "$ICON_NETWORK" "Установка Reverse Proxy"
    
    if [ "$CURRENT_REVERSE_PROXY" = "$PROXY_CADDY" ]; then
        if ! install_caddy; then
            display_error "Ошибка установки Caddy"
            return 1
        fi
    elif [ "$CURRENT_REVERSE_PROXY" = "$PROXY_NGINX" ]; then
        if ! install_nginx; then
            display_error "Ошибка установки NGINX"
            return 1
        fi
        
        # Generate main nginx.conf
        generate_nginx_main_conf
        
        # SSL Certificate setup
        display_info "Выберите тип SSL сертификата"
        local ssl_choice=$(select_from_list "SSL Provider" \
            "Let's Encrypt (рекомендуется)" \
            "Cloudflare DNS" \
            "Self-signed (только для тестирования)")
        
        case "$ssl_choice" in
            "Let's Encrypt (рекомендуется)")
                if ! obtain_letsencrypt_standalone "$domain" "$admin_email"; then
                    display_error "Ошибка получения SSL сертификата"
                    return 1
                fi
                ;;
            "Cloudflare DNS")
                local cf_token=$(read_input "Введите Cloudflare API Token")
                if ! obtain_cloudflare_certificate "$domain" "$admin_email" "$cf_token"; then
                    display_error "Ошибка получения Cloudflare SSL сертификата"
                    return 1
                fi
                ;;
            "Self-signed (только для тестирования)")
                generate_self_signed_certificate "$domain"
                ;;
        esac
    fi
    
    # Generate combined docker-compose
    display_step "Создание docker-compose.yml..."
    generate_all_in_one_compose "$domain" "$db_password" "$redis_password" "$node_token"
    
    # Generate panel .env
    display_step "Создание конфигурации панели..."
    generate_panel_env "$domain" "$admin_email" "$admin_password" \
        "$db_password" "$redis_password" "$jwt_secret" "$xray_uuid"
    
    # Generate node .env
    display_step "Создание конфигурации node..."
    generate_node_env_local "$node_token"
    
    # Setup Xray if requested
    if [ "$ENABLE_XRAY" = "yes" ]; then
        display_step "Настройка Xray-core..."
        generate_xray_config "$xray_uuid" "$xray_private_key" "$xray_short_id"
    fi
    
    # Generate reverse proxy configuration
    display_step "Настройка reverse proxy..."
    
    if [ "$CURRENT_REVERSE_PROXY" = "$PROXY_CADDY" ]; then
        case "$CURRENT_SECURITY_LEVEL" in
            "$SECURITY_BASIC")
                generate_caddyfile_basic "$domain" "localhost:$DEFAULT_PANEL_PORT" "$admin_email"
                ;;
            "$SECURITY_COOKIE")
                generate_caddyfile_cookie_auth "$domain" "localhost:$DEFAULT_PANEL_PORT" \
                    "$panel_secret_key" "" "$admin_email"
                ;;
            "$SECURITY_FULL")
                generate_caddyfile_full_auth "$domain" "localhost:$DEFAULT_PANEL_PORT" \
                    "admin" "$admin_password" "" "$admin_email"
                ;;
        esac
        
        reload_caddy
        
    elif [ "$CURRENT_REVERSE_PROXY" = "$PROXY_NGINX" ]; then
        case "$CURRENT_SECURITY_LEVEL" in
            "$SECURITY_BASIC")
                generate_nginx_conf_basic "$domain" "http://127.0.0.1:$DEFAULT_PANEL_PORT"
                ;;
            "$SECURITY_COOKIE")
                local cookie_secret=$(generate_random_string 32)
                generate_nginx_conf_cookie_auth "$domain" "http://127.0.0.1:$DEFAULT_PANEL_PORT" \
                    "http://127.0.0.1:8080" "$cookie_secret"
                display_warning "Cookie Auth требует установки selfsteal контейнера"
                ;;
            "$SECURITY_FULL")
                generate_nginx_conf_full_auth "$domain" "http://127.0.0.1:$DEFAULT_PANEL_PORT" \
                    "admin" "$admin_password"
                ;;
        esac
        
        reload_nginx
    fi
    
    # Create Docker network
    if ! docker network inspect "$DOCKER_NETWORK" >/dev/null 2>&1; then
        display_step "Создание Docker сети..."
        docker network create "$DOCKER_NETWORK"
    fi
    
    # Start services
    display_section "$ICON_DOCKER" "Запуск сервисов"
    
    cd "$BASE_DIR" || return 1
    
    display_step "Запуск базы данных..."
    docker compose up -d postgres redis
    
    display_step "Ожидание готовности базы данных..."
    sleep 10
    
    display_step "Запуск панели..."
    docker compose up -d remnawave-panel
    
    display_step "Запуск node..."
    docker compose up -d remnawave-node
    
    if [ "$ENABLE_XRAY" = "yes" ]; then
        display_step "Запуск Xray..."
        docker compose up -d xray
    fi
    
    # Wait for services
    display_step "Ожидание запуска сервисов..."
    wait_for_panel_ready
    sleep 5
    
    # Register admin
    display_step "Регистрация администратора..."
    local admin_token=$(register_panel_admin "$admin_email" "$admin_password")
    
    if [ -z "$admin_token" ]; then
        display_error "Не удалось получить токен администратора"
    else
        # Run auto-configuration
        auto_configure_all_in_one "$admin_token" "$domain" "$selfsteal_domain"
    fi
    
    # Install management scripts
    display_section "$ICON_TOOLS" "Установка управляющих скриптов"
    if ! install_management_scripts "all"; then
        display_warning "Управляющие скрипты не установлены"
        display_info "Можно установить вручную: bash install.sh → Tools → Management Scripts"
    fi
    
    # Save installation info
    save_install_info "$INSTALL_TYPE_ALL_IN_ONE" "$CURRENT_REVERSE_PROXY" \
        "$CURRENT_SECURITY_LEVEL" "$domain"
    
    # Display completion
    display_completion "Установка All-in-One завершена!"
    
    display_summary "Информация о системе" \
        "Домен|https://$domain" \
        "Email|$admin_email" \
        "Пароль|$admin_password" \
        "Node Token|$node_token" \
        "Xray|$([ "$ENABLE_XRAY" = 'yes' ] && echo 'Enabled' || echo 'Disabled')"
    
    if [ "$CURRENT_SECURITY_LEVEL" = "$SECURITY_COOKIE" ]; then
        echo
        display_info "URL для доступа с cookie:"
        echo -e "${CYAN}https://$domain?caddy=$panel_secret_key${NC}"
    fi
    
    if [ "$ENABLE_XRAY" = "yes" ]; then
        echo
        display_info "Xray UUID: $xray_uuid"
        display_info "Xray Public Key: $xray_public_key"
        display_info "Xray Short ID: $xray_short_id"
        display_info "Xray Port: $DEFAULT_XRAY_PORT"
    fi
    
    echo
    display_info "Панель: https://$domain"
    display_info "Директория: $BASE_DIR"
    display_info "Логи панели: docker logs -f $PANEL_CONTAINER"
    display_info "Логи node: docker logs -f $NODE_CONTAINER"
    
    # Save credentials to file
    save_all_credentials "$domain" "$admin_email" "$admin_password" \
        "$node_token" "$xray_uuid" "$xray_public_key" "$xray_short_id" "$panel_secret_key"
    
    return 0
}

# =============================================================================
# DOCKER COMPOSE GENERATION
# =============================================================================

generate_all_in_one_compose() {
    local domain="$1"
    local db_password="$2"
    local redis_password="$3"
    local node_token="$4"
    
    cat > "$BASE_DIR/docker-compose.yml" <<EOF
services:
  remnawave-panel:
    image: ${PANEL_IMAGE}:${DOCKER_IMAGE_TAG}
    container_name: ${PANEL_CONTAINER}
    restart: unless-stopped
    ports:
      - "127.0.0.1:${DEFAULT_PANEL_PORT}:3000"
    environment:
      - NODE_ENV=production
    env_file:
      - ${PANEL_DIR}/.env
    volumes:
      - ${PANEL_DIR}/data:/app/data
      - ${PANEL_DIR}/logs:/app/logs
    networks:
      - ${DOCKER_NETWORK}
    depends_on:
      - postgres
      - redis
    labels:
      - "remnawave.type=panel"
      - "remnawave.version=${SCRIPT_VERSION}"

  remnawave-node:
    image: ${NODE_IMAGE}:${DOCKER_IMAGE_TAG}
    container_name: ${NODE_CONTAINER}
    restart: unless-stopped
    network_mode: host
    env_file:
      - ${NODE_DIR}/.env
    volumes:
      - ${NODE_DIR}/data:/app/data
      - ${NODE_DIR}/logs:/app/logs
      - ${NODE_DIR}/xray:/app/xray
    labels:
      - "remnawave.type=node"

  postgres:
    image: ${DB_IMAGE}
    container_name: ${DB_CONTAINER}
    restart: unless-stopped
    environment:
      - POSTGRES_DB=${DEFAULT_DB_NAME}
      - POSTGRES_USER=${DEFAULT_DB_USER}
      - POSTGRES_PASSWORD=${db_password}
      - PGDATA=/var/lib/postgresql/data/pgdata
    volumes:
      - ${BASE_DIR}/postgres/data:/var/lib/postgresql/data
    networks:
      - ${DOCKER_NETWORK}
    labels:
      - "remnawave.type=database"

  redis:
    image: ${REDIS_IMAGE}
    container_name: ${REDIS_CONTAINER}
    restart: unless-stopped
    command: >
      valkey-server
      --requirepass ${redis_password}
      --maxmemory 256mb
      --maxmemory-policy allkeys-lru
    volumes:
      - ${BASE_DIR}/redis/data:/data
    networks:
      - ${DOCKER_NETWORK}
    labels:
      - "remnawave.type=cache"
EOF

    if [ "$ENABLE_XRAY" = "yes" ]; then
        cat >> "$BASE_DIR/docker-compose.yml" <<EOF

  xray:
    image: teddysun/xray:latest
    container_name: xray-core
    restart: unless-stopped
    network_mode: host
    volumes:
      - ${NODE_DIR}/xray/config.json:/etc/xray/config.json:ro
      - ${NODE_DIR}/xray/logs:/var/log/xray
    labels:
      - "remnawave.type=xray"
EOF
    fi

    cat >> "$BASE_DIR/docker-compose.yml" <<EOF

networks:
  ${DOCKER_NETWORK}:
    driver: bridge
EOF
}

generate_node_env_local() {
    local node_token="$1"
    
    cat > "$NODE_DIR/.env" <<EOF
# Remnawave Node Configuration (All-in-One)
# Generated: $(date)

APP_PORT=2222
NODE_ENV=production
PANEL_IP=127.0.0.1
NODE_TOKEN=$node_token

LOG_LEVEL=info
LOG_FILE=/app/logs/remnanode.log

XRAY_ENABLED=$ENABLE_XRAY
XRAY_PORT=$DEFAULT_XRAY_PORT
EOF
}

generate_xray_config() {
    local uuid="$1"
    local private_key="$2"
    local short_id="$3"
    
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
            "id": "$uuid",
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
          "privateKey": "$private_key",
          "shortIds": [
            "$short_id"
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
}

# =============================================================================
# VALIDATION
# =============================================================================

validate_system_for_all_in_one() {
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
        return 1
    fi
    
    if ! validate_docker_compose; then
        display_error "Docker Compose не установлен"
        return 1
    fi
    
    # Check disk space
    local free_space=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')
    if [ "$free_space" -lt "$MIN_DISK_SPACE_GB" ]; then
        display_error "Недостаточно места на диске (требуется минимум ${MIN_DISK_SPACE_GB}GB)"
        return 1
    fi
    
    # Check memory
    local free_mem=$(free -g | awk '/^Mem:/{print $7}')
    if [ "$free_mem" -lt "$MIN_MEMORY_GB" ]; then
        display_warning "Рекомендуется минимум ${RECOMMENDED_MEMORY_GB}GB RAM"
    fi
    
    display_success "Система готова"
    return 0
}

# =============================================================================
# CREDENTIALS SAVE
# =============================================================================

save_all_credentials() {
    local domain="$1"
    local email="$2"
    local password="$3"
    local node_token="$4"
    local xray_uuid="$5"
    local xray_public_key="$6"
    local xray_short_id="$7"
    local panel_secret="$8"
    
    cat > "$BASE_DIR/credentials.txt" <<EOF
===========================================
Remnawave All-in-One Installation
===========================================
Generated: $(date)

PANEL ACCESS
-----------
Domain: https://$domain
Email: $email
Password: $password

$([ -n "$panel_secret" ] && echo "Cookie Access: https://$domain?caddy=$panel_secret")

NODE CONFIGURATION
-----------------
Node Token: $node_token
Node Port: 2222

$([ "$ENABLE_XRAY" = "yes" ] && cat <<XRAY
XRAY CONFIGURATION
-----------------
UUID: $xray_uuid
Public Key: $xray_public_key
Short ID: $xray_short_id
Port: $DEFAULT_XRAY_PORT
XRAY
)

IMPORTANT
---------
- Сохраните этот файл в безопасном месте
- Не делитесь учетными данными
- Регулярно создавайте резервные копии

===========================================
EOF
    
    chmod 600 "$BASE_DIR/credentials.txt"
    
    echo
    display_success "Учетные данные сохранены: $BASE_DIR/credentials.txt"
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f install_all_in_one
export -f generate_all_in_one_compose
export -f generate_node_env_local
export -f generate_xray_config
export -f validate_system_for_all_in_one
export -f save_all_credentials
