#!/bin/bash

# =============================================================================
# NGINX Provider - SSL Certificate Management
# =============================================================================

# Определяем путь к библиотекам относительно текущего скрипта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/logging.sh"

# =============================================================================
# Certificate Installation
# =============================================================================

# Установка SSL сертификата из файлов
install_ssl_from_files() {
    local domain="$1"
    local cert_file="$2"
    local key_file="$3"
    local chain_file="$4"  # optional
    
    if [ ! -f "${cert_file}" ]; then
        log_error "Файл сертификата не найден: ${cert_file}"
        return 1
    fi
    
    if [ ! -f "${key_file}" ]; then
        log_error "Файл ключа не найден: ${key_file}"
        return 1
    fi
    
    local target_cert="${NGINX_CONFIG_DIR}/ssl/${domain}.crt"
    local target_key="${NGINX_CONFIG_DIR}/ssl/${domain}.key"
    
    # Объединение сертификата с цепочкой, если предоставлена
    if [ -n "${chain_file}" ] && [ -f "${chain_file}" ]; then
        cat "${cert_file}" "${chain_file}" > "${target_cert}"
    else
        cp "${cert_file}" "${target_cert}"
    fi
    
    cp "${key_file}" "${target_key}"
    
    # Установка прав доступа
    chmod 644 "${target_cert}"
    chmod 600 "${target_key}"
    
    # Проверка сертификата
    if validate_ssl_certificate "${domain}"; then
        log_success "SSL сертификат установлен для ${domain}"
        return 0
    else
        log_error "SSL сертификат невалиден"
        rm -f "${target_cert}" "${target_key}"
        return 1
    fi
}

# =============================================================================
# Let's Encrypt (Certbot)
# =============================================================================

# Установка Certbot
install_certbot() {
    if command -v certbot &> /dev/null; then
        log_info "Certbot уже установлен"
        return 0
    fi
    
    log_info "Установка Certbot..."
    
    if [ -f /etc/debian_version ]; then
        apt-get update
        apt-get install -y certbot
    elif [ -f /etc/redhat-release ]; then
        yum install -y certbot
    else
        log_error "Неподдерживаемая ОС для автоматической установки Certbot"
        return 1
    fi
    
    if command -v certbot &> /dev/null; then
        log_success "Certbot установлен"
        return 0
    else
        log_error "Не удалось установить Certbot"
        return 1
    fi
}

# Получение Let's Encrypt сертификата (Standalone)
obtain_letsencrypt_standalone() {
    local domain="$1"
    local email="$2"
    
    log_info "Получение Let's Encrypt сертификата для ${domain}..."
    
    # Установка Certbot
    if ! install_certbot; then
        return 1
    fi
    
    # Временная остановка NGINX для освобождения портов 80 и 443
    local nginx_was_running=false
    if check_container_running "${NGINX_CONTAINER_NAME}"; then
        nginx_was_running=true
        stop_nginx
    fi
    
    # Получение сертификата
    certbot certonly --standalone \
        --preferred-challenges http \
        --http-01-port 80 \
        --email "${email}" \
        --agree-tos \
        --no-eff-email \
        --non-interactive \
        -d "${domain}"
    
    local result=$?
    
    # Запуск NGINX обратно
    if [ "$nginx_was_running" = true ]; then
        start_nginx
    fi
    
    if [ $result -eq 0 ]; then
        # Копирование сертификатов
        cp "/etc/letsencrypt/live/${domain}/fullchain.pem" "${NGINX_CONFIG_DIR}/ssl/${domain}.crt"
        cp "/etc/letsencrypt/live/${domain}/privkey.pem" "${NGINX_CONFIG_DIR}/ssl/${domain}.key"
        
        chmod 644 "${NGINX_CONFIG_DIR}/ssl/${domain}.crt"
        chmod 600 "${NGINX_CONFIG_DIR}/ssl/${domain}.key"
        
        log_success "Let's Encrypt сертификат получен для ${domain}"
        return 0
    else
        log_error "Не удалось получить Let's Encrypt сертификат"
        return 1
    fi
}

# Получение Let's Encrypt сертификата (Webroot)
obtain_letsencrypt_webroot() {
    local domain="$1"
    local email="$2"
    local webroot_path="${3:-/var/www/html}"
    
    log_info "Получение Let's Encrypt сертификата (webroot) для ${domain}..."
    
    # Установка Certbot
    if ! install_certbot; then
        return 1
    fi
    
    # Создание webroot директории
    mkdir -p "${webroot_path}/.well-known/acme-challenge"
    
    # Получение сертификата
    certbot certonly --webroot \
        -w "${webroot_path}" \
        --email "${email}" \
        --agree-tos \
        --no-eff-email \
        --non-interactive \
        -d "${domain}"
    
    if [ $? -eq 0 ]; then
        # Копирование сертификатов
        cp "/etc/letsencrypt/live/${domain}/fullchain.pem" "${NGINX_CONFIG_DIR}/ssl/${domain}.crt"
        cp "/etc/letsencrypt/live/${domain}/privkey.pem" "${NGINX_CONFIG_DIR}/ssl/${domain}.key"
        
        chmod 644 "${NGINX_CONFIG_DIR}/ssl/${domain}.crt"
        chmod 600 "${NGINX_CONFIG_DIR}/ssl/${domain}.key"
        
        log_success "Let's Encrypt сертификат получен для ${domain}"
        return 0
    else
        log_error "Не удалось получить Let's Encrypt сертификат"
        return 1
    fi
}

# Обновление Let's Encrypt сертификатов
renew_letsencrypt_certificates() {
    log_info "Обновление Let's Encrypt сертификатов..."
    
    if ! command -v certbot &> /dev/null; then
        log_error "Certbot не установлен"
        return 1
    fi
    
    certbot renew --quiet --deploy-hook "nginx -s reload"
    
    if [ $? -eq 0 ]; then
        # Копирование обновленных сертификатов
        for domain_dir in /etc/letsencrypt/live/*/; do
            if [ -d "${domain_dir}" ]; then
                local domain=$(basename "${domain_dir}")
                if [ -f "${domain_dir}/fullchain.pem" ]; then
                    cp "${domain_dir}/fullchain.pem" "${NGINX_CONFIG_DIR}/ssl/${domain}.crt"
                    cp "${domain_dir}/privkey.pem" "${NGINX_CONFIG_DIR}/ssl/${domain}.key"
                fi
            fi
        done
        
        reload_nginx
        log_success "Let's Encrypt сертификаты обновлены"
        return 0
    else
        log_warning "Не требуется обновление сертификатов или обновление не удалось"
        return 1
    fi
}

# =============================================================================
# Cloudflare DNS Challenge
# =============================================================================

# Установка Certbot Cloudflare plugin
install_certbot_cloudflare() {
    if pip3 list | grep -q certbot-dns-cloudflare; then
        log_info "certbot-dns-cloudflare уже установлен"
        return 0
    fi
    
    log_info "Установка certbot-dns-cloudflare..."
    
    # Установка pip3, если не установлен
    if ! command -v pip3 &> /dev/null; then
        if [ -f /etc/debian_version ]; then
            apt-get update
            apt-get install -y python3-pip
        elif [ -f /etc/redhat-release ]; then
            yum install -y python3-pip
        fi
    fi
    
    pip3 install certbot-dns-cloudflare
    
    if pip3 list | grep -q certbot-dns-cloudflare; then
        log_success "certbot-dns-cloudflare установлен"
        return 0
    else
        log_error "Не удалось установить certbot-dns-cloudflare"
        return 1
    fi
}

# Получение сертификата через Cloudflare DNS
obtain_cloudflare_certificate() {
    local domain="$1"
    local email="$2"
    local cf_api_token="$3"
    
    log_info "Получение SSL сертификата через Cloudflare DNS для ${domain}..."
    
    # Установка зависимостей
    if ! install_certbot; then
        return 1
    fi
    
    if ! install_certbot_cloudflare; then
        return 1
    fi
    
    # Создание файла с credentials
    local cf_credentials="${NGINX_CONFIG_DIR}/ssl/.cloudflare.ini"
    cat > "${cf_credentials}" <<EOF
# Cloudflare API Token
dns_cloudflare_api_token = ${cf_api_token}
EOF
    chmod 600 "${cf_credentials}"
    
    # Получение сертификата
    certbot certonly --dns-cloudflare \
        --dns-cloudflare-credentials "${cf_credentials}" \
        --dns-cloudflare-propagation-seconds 60 \
        --email "${email}" \
        --agree-tos \
        --no-eff-email \
        --non-interactive \
        -d "${domain}" \
        -d "*.${domain}"
    
    if [ $? -eq 0 ]; then
        # Копирование сертификатов
        cp "/etc/letsencrypt/live/${domain}/fullchain.pem" "${NGINX_CONFIG_DIR}/ssl/${domain}.crt"
        cp "/etc/letsencrypt/live/${domain}/privkey.pem" "${NGINX_CONFIG_DIR}/ssl/${domain}.key"
        
        chmod 644 "${NGINX_CONFIG_DIR}/ssl/${domain}.crt"
        chmod 600 "${NGINX_CONFIG_DIR}/ssl/${domain}.key"
        
        log_success "Cloudflare SSL сертификат получен для ${domain}"
        return 0
    else
        log_error "Не удалось получить Cloudflare SSL сертификат"
        rm -f "${cf_credentials}"
        return 1
    fi
}

# =============================================================================
# Self-Signed Certificates
# =============================================================================

# Генерация self-signed сертификата
generate_self_signed_certificate() {
    local domain="$1"
    local days="${2:-365}"
    local country="${3:-US}"
    local state="${4:-State}"
    local city="${5:-City}"
    local org="${6:-Organization}"
    
    log_info "Генерация self-signed SSL сертификата для ${domain}..."
    
    local cert_file="${NGINX_CONFIG_DIR}/ssl/${domain}.crt"
    local key_file="${NGINX_CONFIG_DIR}/ssl/${domain}.key"
    
    # Генерация приватного ключа и сертификата
    openssl req -x509 -nodes -days "${days}" -newkey rsa:2048 \
        -keyout "${key_file}" \
        -out "${cert_file}" \
        -subj "/C=${country}/ST=${state}/L=${city}/O=${org}/CN=${domain}"
    
    if [ $? -eq 0 ]; then
        chmod 600 "${key_file}"
        chmod 644 "${cert_file}"
        
        log_success "Self-signed SSL сертификат создан для ${domain}"
        log_warning "⚠️  Self-signed сертификаты вызывают предупреждения в браузерах"
        log_warning "⚠️  Используйте только для тестирования или внутренних целей"
        return 0
    else
        log_error "Не удалось создать self-signed сертификат"
        return 1
    fi
}

# Генерация self-signed сертификата с SAN (Subject Alternative Names)
generate_self_signed_san_certificate() {
    local primary_domain="$1"
    shift
    local san_domains=("$@")
    local days="365"
    
    log_info "Генерация self-signed SSL сертификата с SAN для ${primary_domain}..."
    
    local cert_file="${NGINX_CONFIG_DIR}/ssl/${primary_domain}.crt"
    local key_file="${NGINX_CONFIG_DIR}/ssl/${primary_domain}.key"
    local config_file="${NGINX_CONFIG_DIR}/ssl/${primary_domain}_openssl.cnf"
    
    # Создание конфигурационного файла OpenSSL
    cat > "${config_file}" <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[dn]
C = US
ST = State
L = City
O = Organization
CN = ${primary_domain}

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${primary_domain}
EOF
    
    # Добавление альтернативных имен
    local counter=2
    for san in "${san_domains[@]}"; do
        echo "DNS.${counter} = ${san}" >> "${config_file}"
        ((counter++))
    done
    
    # Генерация сертификата
    openssl req -x509 -nodes -days "${days}" -newkey rsa:2048 \
        -keyout "${key_file}" \
        -out "${cert_file}" \
        -config "${config_file}"
    
    if [ $? -eq 0 ]; then
        chmod 600 "${key_file}"
        chmod 644 "${cert_file}"
        rm -f "${config_file}"
        
        log_success "Self-signed SSL сертификат с SAN создан для ${primary_domain}"
        return 0
    else
        log_error "Не удалось создать self-signed сертификат с SAN"
        rm -f "${config_file}"
        return 1
    fi
}

# =============================================================================
# Certificate Validation
# =============================================================================

# Проверка SSL сертификата
validate_ssl_certificate() {
    local domain="$1"
    local cert_file="${NGINX_CONFIG_DIR}/ssl/${domain}.crt"
    local key_file="${NGINX_CONFIG_DIR}/ssl/${domain}.key"
    
    if [ ! -f "${cert_file}" ]; then
        log_error "Файл сертификата не найден: ${cert_file}"
        return 1
    fi
    
    if [ ! -f "${key_file}" ]; then
        log_error "Файл ключа не найден: ${key_file}"
        return 1
    fi
    
    # Проверка формата сертификата
    if ! openssl x509 -in "${cert_file}" -noout -text &>/dev/null; then
        log_error "Невалидный формат сертификата"
        return 1
    fi
    
    # Проверка формата ключа
    if ! openssl rsa -in "${key_file}" -check -noout &>/dev/null; then
        log_error "Невалидный формат приватного ключа"
        return 1
    fi
    
    # Проверка соответствия сертификата и ключа
    local cert_modulus
    local key_modulus
    cert_modulus=$(openssl x509 -noout -modulus -in "${cert_file}" | openssl md5)
    key_modulus=$(openssl rsa -noout -modulus -in "${key_file}" | openssl md5)
    
    if [ "${cert_modulus}" != "${key_modulus}" ]; then
        log_error "Сертификат и ключ не соответствуют друг другу"
        return 1
    fi
    
    log_success "SSL сертификат валиден для ${domain}"
    return 0
}

# Получение информации о сертификате
get_certificate_info() {
    local domain="$1"
    local cert_file="${NGINX_CONFIG_DIR}/ssl/${domain}.crt"
    
    if [ ! -f "${cert_file}" ]; then
        log_error "Сертификат не найден для домена: ${domain}"
        return 1
    fi
    
    log_info "Информация о SSL сертификате для ${domain}:"
    echo ""
    
    # Subject
    echo "Subject:"
    openssl x509 -in "${cert_file}" -noout -subject | sed 's/subject=/  /'
    echo ""
    
    # Issuer
    echo "Issuer:"
    openssl x509 -in "${cert_file}" -noout -issuer | sed 's/issuer=/  /'
    echo ""
    
    # Valid dates
    echo "Valid From:"
    openssl x509 -in "${cert_file}" -noout -startdate | sed 's/notBefore=/  /'
    echo ""
    echo "Valid Until:"
    openssl x509 -in "${cert_file}" -noout -enddate | sed 's/notAfter=/  /'
    echo ""
    
    # Check expiration
    local expiry_date
    expiry_date=$(openssl x509 -in "${cert_file}" -noout -enddate | cut -d= -f2)
    local expiry_epoch
    expiry_epoch=$(date -d "${expiry_date}" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "${expiry_date}" +%s 2>/dev/null)
    local current_epoch
    current_epoch=$(date +%s)
    local days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
    
    if [ "${days_left}" -lt 0 ]; then
        echo -e "${COLOR_RED}⚠️  Сертификат истек ${days_left#-} дней назад${COLOR_RESET}"
    elif [ "${days_left}" -lt 30 ]; then
        echo -e "${COLOR_YELLOW}⚠️  Сертификат истекает через ${days_left} дней${COLOR_RESET}"
    else
        echo -e "${COLOR_GREEN}✓ Сертификат действителен еще ${days_left} дней${COLOR_RESET}"
    fi
    echo ""
    
    # SAN (Subject Alternative Names)
    echo "Subject Alternative Names:"
    openssl x509 -in "${cert_file}" -noout -text | grep -A1 "Subject Alternative Name" | tail -n1 | sed 's/^[ \t]*/  /'
    echo ""
}

# Проверка всех сертификатов на истечение
check_all_certificates_expiry() {
    log_info "Проверка всех SSL сертификатов..."
    echo ""
    
    local expiring_soon=0
    local expired=0
    
    for cert_file in "${NGINX_CONFIG_DIR}"/ssl/*.crt; do
        if [ -f "${cert_file}" ]; then
            local domain=$(basename "${cert_file}" .crt)
            local expiry_date
            expiry_date=$(openssl x509 -in "${cert_file}" -noout -enddate 2>/dev/null | cut -d= -f2)
            
            if [ -n "${expiry_date}" ]; then
                local expiry_epoch
                expiry_epoch=$(date -d "${expiry_date}" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "${expiry_date}" +%s 2>/dev/null)
                local current_epoch
                current_epoch=$(date +%s)
                local days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
                
                if [ "${days_left}" -lt 0 ]; then
                    echo -e "${COLOR_RED}❌ ${domain}: Истек ${days_left#-} дней назад${COLOR_RESET}"
                    ((expired++))
                elif [ "${days_left}" -lt 30 ]; then
                    echo -e "${COLOR_YELLOW}⚠️  ${domain}: Истекает через ${days_left} дней${COLOR_RESET}"
                    ((expiring_soon++))
                else
                    echo -e "${COLOR_GREEN}✓ ${domain}: ${days_left} дней до истечения${COLOR_RESET}"
                fi
            fi
        fi
    done
    
    echo ""
    if [ "${expired}" -gt 0 ] || [ "${expiring_soon}" -gt 0 ]; then
        log_warning "Найдено истекших сертификатов: ${expired}, истекающих скоро: ${expiring_soon}"
        return 1
    else
        log_success "Все сертификаты действительны"
        return 0
    fi
}

# =============================================================================
# Certificate Backup & Restore
# =============================================================================

# Резервная копия сертификатов
backup_ssl_certificates() {
    local backup_name="${1:-ssl_backup_$(date +%Y%m%d_%H%M%S)}"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    mkdir -p "${backup_path}"
    
    cp -r "${NGINX_CONFIG_DIR}/ssl" "${backup_path}/"
    
    log_success "Резервная копия SSL сертификатов создана: ${backup_path}"
    echo "${backup_path}"
}

# Восстановление сертификатов
restore_ssl_certificates() {
    local backup_path="$1"
    
    if [ ! -d "${backup_path}/ssl" ]; then
        log_error "Резервная копия SSL не найдена: ${backup_path}"
        return 1
    fi
    
    # Создание резервной копии текущих сертификатов
    backup_ssl_certificates "before_restore_$(date +%Y%m%d_%H%M%S)" >/dev/null
    
    # Восстановление
    rm -rf "${NGINX_CONFIG_DIR}/ssl"
    cp -r "${backup_path}/ssl" "${NGINX_CONFIG_DIR}/"
    
    log_success "SSL сертификаты восстановлены из ${backup_path}"
    reload_nginx
}

# =============================================================================
# Auto-renewal Setup
# =============================================================================

# Настройка автоматического обновления сертификатов
setup_certificate_auto_renewal() {
    log_info "Настройка автоматического обновления SSL сертификатов..."
    
    # Создание скрипта обновления
    local renewal_script="/usr/local/bin/remnawave-renew-certs.sh"
    cat > "${renewal_script}" <<'SCRIPT'
#!/bin/bash
# Remnawave SSL Certificate Auto-Renewal Script

/usr/bin/certbot renew --quiet --deploy-hook "docker exec remnawave-nginx nginx -s reload"

# Copy renewed certificates to NGINX config directory
for domain_dir in /etc/letsencrypt/live/*/; do
    if [ -d "${domain_dir}" ]; then
        domain=$(basename "${domain_dir}")
        if [ -f "${domain_dir}/fullchain.pem" ]; then
            cp "${domain_dir}/fullchain.pem" "/opt/remnawave/nginx/ssl/${domain}.crt"
            cp "${domain_dir}/privkey.pem" "/opt/remnawave/nginx/ssl/${domain}.key"
        fi
    fi
done
SCRIPT
    
    chmod +x "${renewal_script}"
    
    # Добавление в crontab (ежедневно в 3:00 AM)
    local cron_entry="0 3 * * * ${renewal_script} >> /var/log/remnawave-cert-renewal.log 2>&1"
    
    if ! crontab -l 2>/dev/null | grep -q "${renewal_script}"; then
        (crontab -l 2>/dev/null; echo "${cron_entry}") | crontab -
        log_success "Автоматическое обновление SSL сертификатов настроено (ежедневно в 3:00 AM)"
    else
        log_info "Автоматическое обновление уже настроено"
    fi
    
    return 0
}
