#!/usr/bin/env bash
# Caddy Installation Module
# Description: Installs and configures Caddy reverse proxy via Docker
# Dependencies: docker, docker-compose
# Author: DigneZzZ
# Version: 1.0.0

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../config.sh"
source "$SCRIPT_DIR/../../core/display.sh"
source "$SCRIPT_DIR/../../core/validation.sh"
source "$SCRIPT_DIR/../../lib/crypto.sh"
source "$SCRIPT_DIR/../../lib/input.sh"

# =============================================================================
# INSTALLATION
# =============================================================================

install_caddy() {
    display_section "$ICON_ROCKET" "Установка Caddy"
    
    # Validate prerequisites
    if ! validate_docker; then
        display_error "Docker не установлен"
        return 1
    fi
    
    if ! validate_docker_compose; then
        display_error "Docker Compose не установлен"
        return 1
    fi
    
    # Check if already installed
    if is_installed "caddy"; then
        display_warning "Caddy уже установлен"
        if ! confirm_action "Переустановить?" "n"; then
            return 0
        fi
        uninstall_caddy
    fi
    
    # Create directory structure
    display_step "Создание структуры директорий..."
    mkdir -p "$CADDY_DIR"/{config,data,logs,html}
    
    # Generate docker-compose.yml
    display_step "Создание docker-compose.yml..."
    generate_caddy_compose
    
    # Generate basic Caddyfile
    display_step "Создание базового Caddyfile..."
    generate_basic_caddyfile
    
    # Start Caddy
    display_step "Запуск Caddy..."
    cd "$CADDY_DIR" || return 1
    
    if docker compose up -d; then
        display_success "Caddy успешно установлен"
        
        # Show info
        display_info_box "Caddy работает на портах 80 и 443"
        
        return 0
    else
        display_error "Ошибка запуска Caddy"
        return 1
    fi
}

# =============================================================================
# DOCKER COMPOSE GENERATION
# =============================================================================

generate_caddy_compose() {
    cat > "$CADDY_DIR/docker-compose.yml" <<EOF
services:
  caddy:
    image: ${CADDY_IMAGE}
    container_name: ${CADDY_CONTAINER}
    restart: unless-stopped
    network_mode: "host"
    volumes:
      - ./config/Caddyfile:/etc/caddy/Caddyfile:ro
      - ./data:/data
      - ./logs:/var/log/caddy
      - ./html:/var/www/html
    environment:
      - CADDY_ADMIN=0.0.0.0:2019
    labels:
      - "remnawave.type=reverse-proxy"
      - "remnawave.version=${SCRIPT_VERSION}"      - CADDY_ADMIN=0.0.0.0:2019
    labels:
      - "remnawave.type=reverse-proxy"
      - "remnawave.version=${SCRIPT_VERSION}"
EOF
}

# =============================================================================
# BASIC CADDYFILE
# =============================================================================

generate_basic_caddyfile() {
    cat > "$CADDY_DIR/config/Caddyfile" <<'EOF'
{
    admin off
    # Global options
}

# Default catch-all for port 80
:80 {
    respond 204
}

# Health check endpoint
:2019 {
    respond /health 200
}
EOF
}

# =============================================================================
# CONTROL FUNCTIONS
# =============================================================================

start_caddy() {
    display_step "Запуск Caddy..."
    
    cd "$CADDY_DIR" || return 1
    
    if docker compose up -d; then
        display_success "Caddy запущен"
        return 0
    else
        display_error "Ошибка запуска Caddy"
        return 1
    fi
}

stop_caddy() {
    display_step "Остановка Caddy..."
    
    cd "$CADDY_DIR" || return 1
    
    if docker compose down; then
        display_success "Caddy остановлен"
        return 0
    else
        display_error "Ошибка остановки Caddy"
        return 1
    fi
}

restart_caddy() {
    display_step "Перезапуск Caddy..."
    
    cd "$CADDY_DIR" || return 1
    
    if docker compose restart; then
        display_success "Caddy перезапущен"
        return 0
    else
        display_error "Ошибка перезапуска Caddy"
        return 1
    fi
}

reload_caddy() {
    display_step "Перезагрузка конфигурации Caddy..."
    
    if docker exec "$CADDY_CONTAINER" caddy reload --config /etc/caddy/Caddyfile 2>/dev/null; then
        display_success "Конфигурация перезагружена"
        return 0
    else
        display_warning "Не удалось перезагрузить, перезапускаем контейнер..."
        restart_caddy
    fi
}

# =============================================================================
# STATUS & LOGS
# =============================================================================

status_caddy() {
    display_section "$ICON_INFO" "Статус Caddy"
    
    if ! is_installed "caddy"; then
        display_warning "Caddy не установлен"
        return 1
    fi
    
    local status
    status=$(docker inspect -f '{{.State.Status}}' "$CADDY_CONTAINER" 2>/dev/null)
    
    if [ "$status" = "running" ]; then
        display_success "Caddy работает"
        
        # Show uptime
        local started
        started=$(docker inspect -f '{{.State.StartedAt}}' "$CADDY_CONTAINER" 2>/dev/null)
        echo -e "${GRAY}Запущен: $started${NC}"
        
        # Show ports
        echo -e "${GRAY}Порты: 80, 443${NC}"
        
        return 0
    else
        display_error "Caddy не работает (статус: $status)"
        return 1
    fi
}

logs_caddy() {
    local lines="${1:-50}"
    local follow="${2:-false}"
    
    display_section "$ICON_INFO" "Логи Caddy"
    
    if [ "$follow" = "true" ]; then
        docker logs -f --tail "$lines" "$CADDY_CONTAINER"
    else
        docker logs --tail "$lines" "$CADDY_CONTAINER"
    fi
}

# =============================================================================
# VALIDATION
# =============================================================================

validate_caddyfile() {
    local caddyfile="${1:-$CADDY_DIR/config/Caddyfile}"
    
    display_step "Проверка Caddyfile..."
    
    if ! validate_file_exists "$caddyfile"; then
        display_error "Caddyfile не найден: $caddyfile"
        return 1
    fi
    
    # Validate using Caddy
    if docker run --rm -v "$caddyfile:/etc/caddy/Caddyfile:ro" "$CADDY_IMAGE" caddy validate --config /etc/caddy/Caddyfile 2>/dev/null; then
        display_success "Caddyfile валиден"
        return 0
    else
        display_error "Ошибка в Caddyfile"
        return 1
    fi
}

# =============================================================================
# UNINSTALL
# =============================================================================

uninstall_caddy() {
    display_section "$ICON_WARNING" "Удаление Caddy"
    
    if ! is_installed "caddy"; then
        display_warning "Caddy не установлен"
        return 0
    fi
    
    if ! confirm_with_warning "Удалить Caddy?" "Это действие остановит reverse proxy"; then
        return 0
    fi
    
    display_step "Остановка контейнера..."
    cd "$CADDY_DIR" || return 1
    docker compose down -v 2>/dev/null
    
    display_step "Удаление файлов..."
    if confirm_action "Удалить конфигурацию и данные?" "n"; then
        rm -rf "$CADDY_DIR"
        display_success "Caddy полностью удален"
    else
        display_info "Конфигурация сохранена в $CADDY_DIR"
    fi
}

# =============================================================================
# HEALTH CHECK
# =============================================================================

check_caddy_health() {
    if ! is_installed "caddy"; then
        return 1
    fi
    
    if docker exec "$CADDY_CONTAINER" caddy version >/dev/null 2>&1; then
        return 0
    fi
    
    return 1
}

get_caddy_version() {
    if is_installed "caddy"; then
        docker exec "$CADDY_CONTAINER" caddy version 2>/dev/null | head -n1
    else
        echo "Not installed"
    fi
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f install_caddy
export -f generate_caddy_compose
export -f generate_caddy_compose_host_mode
export -f generate_basic_caddyfile
export -f start_caddy
export -f stop_caddy
export -f restart_caddy
export -f reload_caddy
export -f status_caddy
export -f logs_caddy
export -f validate_caddyfile
export -f uninstall_caddy
export -f check_caddy_health
export -f get_caddy_version
