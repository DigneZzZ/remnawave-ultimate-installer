#!/bin/bash

# =============================================================================
# NGINX Provider - Installation & Management
# =============================================================================

# Prevent double loading
[[ -n "${NGINX_INSTALL_LOADED}" ]] && return 0
readonly NGINX_INSTALL_LOADED=1

# Определяем путь к библиотекам относительно текущего скрипта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/logging.sh"

NGINX_COMPOSE_FILE="${COMPOSE_DIR}/nginx-compose.yml"
NGINX_CONFIG_DIR="${INSTALL_DIR}/nginx"
NGINX_CONF_FILE="${NGINX_CONFIG_DIR}/nginx.conf"
NGINX_CONTAINER_NAME="remnawave-nginx"

# =============================================================================
# Installation Functions
# =============================================================================

# Установка NGINX
install_nginx() {
    log_info "Установка NGINX..."
    
    # Создание директорий
    mkdir -p "${NGINX_CONFIG_DIR}"
    mkdir -p "${NGINX_CONFIG_DIR}/conf.d"
    mkdir -p "${NGINX_CONFIG_DIR}/ssl"
    mkdir -p "${NGINX_CONFIG_DIR}/logs"
    
    # Генерация docker-compose файла
    generate_nginx_compose
    
    # Запуск NGINX
    start_nginx
    
    # Проверка статуса
    if ! check_container_running "${NGINX_CONTAINER_NAME}"; then
        log_error "Не удалось запустить NGINX"
        return 1
    fi
    
    log_success "NGINX успешно установлен"
    return 0
}

# Генерация docker-compose файла для NGINX
generate_nginx_compose() {
    log_info "Генерация docker-compose для NGINX..."
    
    cat > "${NGINX_COMPOSE_FILE}" <<EOF
version: '3.8'

services:
  nginx:
    image: nginx:alpine
    container_name: ${NGINX_CONTAINER_NAME}
    restart: unless-stopped
    network_mode: "host"
    volumes:
      - ${NGINX_CONF_FILE}:/etc/nginx/nginx.conf:ro
      - ${NGINX_CONFIG_DIR}/conf.d:/etc/nginx/conf.d:ro
      - ${NGINX_CONFIG_DIR}/ssl:/etc/nginx/ssl:ro
      - ${NGINX_CONFIG_DIR}/logs:/var/log/nginx
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
EOF
    
    log_success "Docker-compose файл создан: ${NGINX_COMPOSE_FILE}"
}

# =============================================================================
# Container Management
# =============================================================================

# Запуск NGINX
start_nginx() {
    log_info "Запуск NGINX..."
    
    docker compose -f "${NGINX_COMPOSE_FILE}" up -d
    
    if [ $? -eq 0 ]; then
        log_success "NGINX запущен"
        return 0
    else
        log_error "Не удалось запустить NGINX"
        return 1
    fi
}

# Остановка NGINX
stop_nginx() {
    log_info "Остановка NGINX..."
    
    docker compose -f "${NGINX_COMPOSE_FILE}" down
    
    if [ $? -eq 0 ]; then
        log_success "NGINX остановлен"
        return 0
    else
        log_error "Не удалось остановить NGINX"
        return 1
    fi
}

# Перезапуск NGINX
restart_nginx() {
    log_info "Перезапуск NGINX..."
    
    docker compose -f "${NGINX_COMPOSE_FILE}" restart
    
    if [ $? -eq 0 ]; then
        log_success "NGINX перезапущен"
        return 0
    else
        log_error "Не удалось перезапустить NGINX"
        return 1
    fi
}

# Перезагрузка конфигурации NGINX
reload_nginx() {
    log_info "Перезагрузка конфигурации NGINX..."
    
    # Проверка конфигурации перед перезагрузкой
    if ! validate_nginx_conf; then
        log_error "Конфигурация NGINX содержит ошибки"
        return 1
    fi
    
    docker exec "${NGINX_CONTAINER_NAME}" nginx -s reload
    
    if [ $? -eq 0 ]; then
        log_success "Конфигурация NGINX перезагружена"
        return 0
    else
        log_error "Не удалось перезагрузить конфигурацию NGINX"
        return 1
    fi
}

# Проверка статуса NGINX
status_nginx() {
    if check_container_running "${NGINX_CONTAINER_NAME}"; then
        log_success "NGINX запущен"
        docker ps --filter "name=${NGINX_CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        return 0
    else
        log_warning "NGINX не запущен"
        return 1
    fi
}

# Просмотр логов NGINX
logs_nginx() {
    local lines="${1:-50}"
    
    log_info "Последние ${lines} строк логов NGINX:"
    docker logs --tail "${lines}" -f "${NGINX_CONTAINER_NAME}"
}

# =============================================================================
# Validation Functions
# =============================================================================

# Проверка конфигурации NGINX
validate_nginx_conf() {
    if [ ! -f "${NGINX_CONF_FILE}" ]; then
        log_error "Конфигурационный файл NGINX не найден: ${NGINX_CONF_FILE}"
        return 1
    fi
    
    # Проверка синтаксиса через временный контейнер
    docker run --rm \
        -v "${NGINX_CONF_FILE}:/etc/nginx/nginx.conf:ro" \
        -v "${NGINX_CONFIG_DIR}/conf.d:/etc/nginx/conf.d:ro" \
        nginx:alpine \
        nginx -t
    
    if [ $? -eq 0 ]; then
        log_success "Конфигурация NGINX корректна"
        return 0
    else
        log_error "Конфигурация NGINX содержит ошибки"
        return 1
    fi
}

# Проверка доступности NGINX
check_nginx_health() {
    if ! check_container_running "${NGINX_CONTAINER_NAME}"; then
        log_error "Контейнер NGINX не запущен"
        return 1
    fi
    
    local health_status
    health_status=$(docker inspect --format='{{.State.Health.Status}}' "${NGINX_CONTAINER_NAME}" 2>/dev/null)
    
    if [ "$health_status" = "healthy" ]; then
        log_success "NGINX работает корректно"
        return 0
    else
        log_warning "Статус NGINX: ${health_status}"
        return 1
    fi
}

# =============================================================================
# Uninstallation
# =============================================================================

# Удаление NGINX
uninstall_nginx() {
    log_warning "Удаление NGINX..."
    
    if ! confirm_action "Вы уверены, что хотите удалить NGINX?"; then
        log_info "Удаление отменено"
        return 1
    fi
    
    # Остановка контейнера
    stop_nginx
    
    # Резервная копия конфигурации
    if [ -d "${NGINX_CONFIG_DIR}" ]; then
        local backup_dir="${BACKUP_DIR}/nginx_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "${backup_dir}"
        cp -r "${NGINX_CONFIG_DIR}" "${backup_dir}/"
        log_info "Резервная копия сохранена: ${backup_dir}"
    fi
    
    # Удаление контейнера и образа
    docker compose -f "${NGINX_COMPOSE_FILE}" down -v
    docker rmi nginx:alpine 2>/dev/null || true
    
    # Опционально: удаление конфигурационных файлов
    if confirm_action "Удалить конфигурационные файлы NGINX?"; then
        rm -rf "${NGINX_CONFIG_DIR}"
        rm -f "${NGINX_COMPOSE_FILE}"
        log_success "Конфигурационные файлы удалены"
    fi
    
    log_success "NGINX удален"
    return 0
}

# =============================================================================
# Utility Functions
# =============================================================================

# Получить список upstream серверов
get_nginx_upstreams() {
    if [ ! -f "${NGINX_CONF_FILE}" ]; then
        return 1
    fi
    
    grep -A 5 "upstream" "${NGINX_CONF_FILE}" | grep "server" | awk '{print $2}' | sed 's/;//'
}

# Проверка порта
check_nginx_port() {
    local port="$1"
    
    if netstat -tuln | grep -q ":${port} "; then
        log_warning "Порт ${port} уже используется"
        return 1
    fi
    
    return 0
}

# Экспорт конфигурации
export_nginx_config() {
    local export_dir="${1:-${BACKUP_DIR}/nginx_export_$(date +%Y%m%d_%H%M%S)}"
    
    mkdir -p "${export_dir}"
    cp -r "${NGINX_CONFIG_DIR}"/* "${export_dir}/"
    cp "${NGINX_COMPOSE_FILE}" "${export_dir}/"
    
    log_success "Конфигурация экспортирована: ${export_dir}"
    echo "${export_dir}"
}

# Импорт конфигурации
import_nginx_config() {
    local import_dir="$1"
    
    if [ ! -d "${import_dir}" ]; then
        log_error "Директория импорта не найдена: ${import_dir}"
        return 1
    fi
    
    # Резервная копия текущей конфигурации
    export_nginx_config "${BACKUP_DIR}/nginx_before_import_$(date +%Y%m%d_%H%M%S)" >/dev/null
    
    # Импорт
    cp -r "${import_dir}"/* "${NGINX_CONFIG_DIR}/"
    
    # Проверка конфигурации
    if validate_nginx_conf; then
        reload_nginx
        log_success "Конфигурация импортирована"
        return 0
    else
        log_error "Импортированная конфигурация содержит ошибки"
        return 1
    fi
}

# =============================================================================
# SSL Management
# =============================================================================

# Проверка SSL сертификата
check_nginx_ssl() {
    local domain="$1"
    local cert_file="${NGINX_CONFIG_DIR}/ssl/${domain}.crt"
    local key_file="${NGINX_CONFIG_DIR}/ssl/${domain}.key"
    
    if [ ! -f "${cert_file}" ] || [ ! -f "${key_file}" ]; then
        log_error "SSL сертификат не найден для домена: ${domain}"
        return 1
    fi
    
    # Проверка срока действия сертификата
    local expiry_date
    expiry_date=$(openssl x509 -in "${cert_file}" -noout -enddate 2>/dev/null | cut -d= -f2)
    
    if [ -n "${expiry_date}" ]; then
        log_info "Сертификат действителен до: ${expiry_date}"
        
        # Проверка, не истекает ли через 30 дней
        local expiry_epoch
        expiry_epoch=$(date -d "${expiry_date}" +%s 2>/dev/null)
        local current_epoch
        current_epoch=$(date +%s)
        local days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
        
        if [ "${days_left}" -lt 30 ]; then
            log_warning "Сертификат истекает через ${days_left} дней"
        fi
    fi
    
    return 0
}

# Обновление SSL сертификатов
renew_nginx_ssl() {
    log_info "Обновление SSL сертификатов через Certbot..."
    
    if ! command -v certbot &> /dev/null; then
        log_error "Certbot не установлен"
        return 1
    fi
    
    certbot renew --nginx --non-interactive
    
    if [ $? -eq 0 ]; then
        reload_nginx
        log_success "SSL сертификаты обновлены"
        return 0
    else
        log_error "Не удалось обновить SSL сертификаты"
        return 1
    fi
}
