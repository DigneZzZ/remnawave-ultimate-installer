#!/usr/bin/env bash
# Panel Installation Module
# Description: Installs Remnawave Panel with all dependencies
# Dependencies: docker, docker-compose, caddy or nginx
# Author: DigneZzZ
# Version: 1.0.0

# Prevent double loading
[[ -n "${PANEL_INSTALL_LOADED}" ]] && return 0
readonly PANEL_INSTALL_LOADED=1

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../config.sh"
source "$SCRIPT_DIR/../../core/display.sh"
source "$SCRIPT_DIR/../../core/validation.sh"
source "$SCRIPT_DIR/../../lib/crypto.sh"
source "$SCRIPT_DIR/../../lib/input.sh"

# Source reverse proxy providers
source "$SCRIPT_DIR/../../providers/caddy/install.sh"
source "$SCRIPT_DIR/../../providers/caddy/config.sh"
source "$SCRIPT_DIR/../../providers/nginx/install.sh"
source "$SCRIPT_DIR/../../providers/nginx/config.sh"
source "$SCRIPT_DIR/../../providers/nginx/ssl.sh"

# Source auto-configuration module
source "$SCRIPT_DIR/auto-configure.sh"

# =============================================================================
# MAIN INSTALLATION FUNCTION
# =============================================================================

install_panel() {
    display_banner "$SCRIPT_VERSION"
    display_section "$ICON_ROCKET" "Установка Remnawave Panel"
    
    # Validate system
    if ! validate_system_for_panel; then
        return 1
    fi
    
    # Check if already installed
    if is_installed "panel"; then
        display_warning "Панель уже установлена"
        if ! confirm_action "Переустановить?" "n"; then
            return 0
        fi
    fi
    
    # Collect configuration
    display_section "$ICON_CONFIG" "Конфигурация"
    
    # Use latest Docker image by default
    DOCKER_IMAGE_TAG="latest"
    
    local domain=$(read_domain "Введите домен для панели")
    local admin_email=$(read_email "Введите email администратора")
    
    # Generate admin password automatically
    local admin_password=$(generate_secure_password 16)
    display_success "Пароль администратора сгенерирован" >&2
    
    # Select reverse proxy
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
    
    # Generate credentials
    display_section "$ICON_KEY" "Генерация учетных данных"
    
    local db_password=$(generate_db_password)
    local redis_password=$(generate_secure_password 32)
    local jwt_secret=$(generate_jwt_secret)
    local panel_secret_key=$(generate_secret_key)
    local xray_uuid=$(generate_xray_uuid)
    
    display_step "Учетные данные сгенерированы"
    echo
    display_info "Доступ к панели:"
    display_info "  Домен: https://$domain"
    display_info "  Email: $admin_email"
    display_warning "  Пароль: $admin_password"
    echo
    display_warning "СОХРАНИТЕ ПАРОЛЬ! Он также будет записан в файл credentials.txt"
    echo
    read -p "Нажмите Enter для продолжения..."
    
    # Create directory structure
    display_section "$ICON_FOLDER" "Создание структуры"
    
    mkdir -p "$PANEL_DIR"/{data,logs,backups}
    mkdir -p "$BASE_DIR/postgres/data"
    mkdir -p "$BASE_DIR/redis/data"
    
    # Generate docker-compose.yml
    display_step "Создание docker-compose.yml..."
    generate_panel_compose "$domain" "$db_password" "$redis_password"
    
    # Generate .env file
    display_step "Создание .env файла..."
    generate_panel_env "$domain" "$admin_email" "$admin_password" \
        "$db_password" "$redis_password" "$jwt_secret" "$xray_uuid"
    
    # Create Docker network
    if ! docker network inspect "$DOCKER_NETWORK" >/dev/null 2>&1; then
        display_step "Создание Docker сети..."
        docker network create "$DOCKER_NETWORK"
    fi
    
    # Install and configure reverse proxy
    display_section "$ICON_NETWORK" "Настройка Reverse Proxy"
    
    if [ "$CURRENT_REVERSE_PROXY" = "$PROXY_CADDY" ]; then
        if ! install_caddy; then
            display_error "Ошибка установки Caddy"
            return 1
        fi
        
        # Generate Caddyfile based on security level
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
        
        # Generate NGINX config based on security level
        case "$CURRENT_SECURITY_LEVEL" in
            "$SECURITY_BASIC")
                generate_nginx_conf_basic "$domain" "http://127.0.0.1:$DEFAULT_PANEL_PORT"
                ;;
            "$SECURITY_COOKIE")
                # Note: Need selfsteal container for cookie auth
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
    
    # Start services
    display_section "$ICON_DOCKER" "Запуск сервисов"
    
    cd "$PANEL_DIR" || return 1
    
    display_step "Запуск базы данных..."
    docker compose up -d postgres redis
    
    display_step "Ожидание готовности базы данных..."
    sleep 10
    
    display_step "Запуск панели..."
    docker compose up -d remnawave-panel
    
    # Wait for panel to start
    display_step "Ожидание запуска панели..."
    wait_for_panel_ready
    
    # Register admin user
    display_step "Регистрация администратора..."
    local admin_token=$(register_panel_admin "$admin_email" "$admin_password")
    
    if [ -z "$admin_token" ]; then
        display_error "Не удалось получить токен администратора"
    else
        # Ask for node details for auto-configuration
        echo
        if confirm_action "Хотите настроить панель автоматически (создать node/host/config profile)?" "y"; then
            local node_address=$(read_input "Введите IP адрес Node сервера")
            local node_port=$(read_input "Введите порт Node" "$DEFAULT_NODE_PORT")
            local selfsteal_domain=$(read_domain "Введите selfsteal домен")
            
            # Run auto-configuration
            auto_configure_panel_only "$admin_token" "$domain" "$node_address" "$node_port" "$selfsteal_domain"
        fi
    fi
    
    # Install management scripts
    display_section "$ICON_TOOLS" "Установка управляющих скриптов"
    if ! install_management_scripts "panel"; then
        display_warning "Управляющие скрипты не установлены"
        display_info "Можно установить вручную: bash install.sh → Tools → Management Scripts"
    fi
    
    # Save installation info
    save_install_info "$INSTALL_TYPE_PANEL" "$CURRENT_REVERSE_PROXY" \
        "$CURRENT_SECURITY_LEVEL" "$domain"
    
    # Display completion
    display_completion "Установка завершена!"
    
    display_summary "Информация о панели" \
        "Домен|https://$domain" \
        "Email|$admin_email" \
        "Пароль|$admin_password" \
        "JWT Secret|$jwt_secret" \
        "Database Password|$db_password"
    
    if [ "$CURRENT_SECURITY_LEVEL" = "$SECURITY_COOKIE" ]; then
        echo
        display_info "URL для доступа с cookie:"
        echo -e "${CYAN}https://$domain?caddy=$panel_secret_key${NC}"
    fi
    
    echo
    display_info "Панель управления: https://$domain"
    display_info "Логи: docker logs -f $PANEL_CONTAINER"
    
    return 0
}

# =============================================================================
# DOCKER COMPOSE GENERATION
# =============================================================================

generate_panel_compose() {
    local domain="$1"
    local db_password="$2"
    local redis_password="$3"
    
    cat > "$PANEL_DIR/docker-compose.yml" <<EOF
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
      - .env
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
    networks:
      - ${DOCKER_NETWORK}
    depends_on:
      - postgres
      - redis
    labels:
      - "remnawave.type=panel"
      - "remnawave.version=${SCRIPT_VERSION}"

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

networks:
  ${DOCKER_NETWORK}:
    driver: bridge
EOF
}

# =============================================================================
# ENVIRONMENT FILE GENERATION
# =============================================================================

generate_panel_env() {
    local domain="$1"
    local admin_email="$2"
    local admin_password="$3"
    local db_password="$4"
    local redis_password="$5"
    local jwt_secret="$6"
    local xray_uuid="$7"
    
    cat > "$PANEL_DIR/.env" <<EOF
# Remnawave Panel Configuration
# Generated: $(date)

# Application
NODE_ENV=production
API_PORT=3000
DOMAIN=$domain

# Database
DB_HOST=postgres
DB_PORT=5432
DB_NAME=$DEFAULT_DB_NAME
DB_USER=$DEFAULT_DB_USER
DB_PASSWORD=$db_password

# Redis
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=$redis_password

# JWT
JWT_SECRET=$jwt_secret
JWT_EXPIRATION=7d

# Admin
ADMIN_EMAIL=$admin_email
ADMIN_PASSWORD=$admin_password

# Xray
XRAY_UUID=$xray_uuid

# Logging
LOG_LEVEL=info
LOG_FILE=/app/logs/remnawave.log

# Features
ENABLE_REGISTRATION=false
ENABLE_TELEGRAM_BOT=false
EOF
}

# =============================================================================
# VALIDATION
# =============================================================================

validate_system_for_panel() {
    display_step "Проверка системы..."
    
    if ! validate_root; then
        display_error "Требуются права root"
        return 1
    fi
    
    if ! validate_os; then
        display_error "Неподдерживаемая операционная система"
        return 1
    fi
    
    # Check and install Docker if needed
    if ! check_docker; then
        display_warning "Docker не установлен"
        echo
        if confirm_action "Установить Docker автоматически?" "y"; then
            if ! install_docker; then
                display_error "Не удалось установить Docker"
                return 1
            fi
        else
            display_error "Docker обязателен для установки"
            display_info "Установите Docker: https://docs.docker.com/engine/install/"
            return 1
        fi
    else
        local docker_version=$(docker --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
        display_success "Docker установлен: $docker_version"
    fi
    
    # Check and install Docker Compose if needed
    if ! check_docker_compose; then
        display_warning "Docker Compose V2 не установлен"
        echo
        if confirm_action "Установить Docker Compose автоматически?" "y"; then
            if ! install_docker_compose; then
                display_error "Не удалось установить Docker Compose"
                return 1
            fi
        else
            display_error "Docker Compose обязателен для установки"
            return 1
        fi
    else
        local compose_version=$(docker compose version --short 2>/dev/null)
        display_success "Docker Compose V2: $compose_version"
    fi
    
    display_success "Система готова"
    return 0
}

# =============================================================================
# PANEL UTILITIES
# =============================================================================

wait_for_panel_ready() {
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s http://localhost:$DEFAULT_PANEL_PORT/health >/dev/null 2>&1; then
            display_success "Панель запущена"
            return 0
        fi
        
        echo -ne "\r${GRAY}Попытка $attempt/$max_attempts...${NC}"
        sleep 2
        ((attempt++))
    done
    
    echo
    display_warning "Панель не ответила на health check"
    return 1
}

register_panel_admin() {
    local email="$1"
    local password="$2"
    
    # Call registration API
    local response
    response=$(curl -s -X POST http://localhost:$DEFAULT_PANEL_PORT/api/auth/register \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"$email\",\"password\":\"$password\"}")
    
    if [ $? -eq 0 ]; then
        display_success "Администратор зарегистрирован"
        return 0
    else
        display_warning "Регистрация через API не удалась, используйте веб-интерфейс"
        return 1
    fi
}

# =============================================================================
# PANEL MANAGEMENT
# =============================================================================

start_panel() {
    display_step "Запуск панели..."
    
    cd "$PANEL_DIR" || return 1
    docker compose start remnawave-panel
}

stop_panel() {
    display_step "Остановка панели..."
    
    cd "$PANEL_DIR" || return 1
    docker compose stop remnawave-panel
}

restart_panel() {
    display_step "Перезапуск панели..."
    
    cd "$PANEL_DIR" || return 1
    docker compose restart remnawave-panel
}

status_panel() {
    display_section "$ICON_INFO" "Статус панели"
    
    if ! is_installed "panel"; then
        display_warning "Панель не установлена"
        return 1
    fi
    
    cd "$PANEL_DIR" || return 1
    docker compose ps
}

logs_panel() {
    local lines="${1:-50}"
    local follow="${2:-false}"
    
    if [ "$follow" = "true" ]; then
        docker logs -f --tail "$lines" "$PANEL_CONTAINER"
    else
        docker logs --tail "$lines" "$PANEL_CONTAINER"
    fi
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f install_panel
export -f generate_panel_compose
export -f generate_panel_env
export -f validate_system_for_panel
export -f wait_for_panel_ready
export -f register_panel_admin
export -f start_panel
export -f stop_panel
export -f restart_panel
export -f status_panel
export -f logs_panel
