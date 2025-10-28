#!/bin/bash

# =============================================================================
# NGINX Provider - Configuration Generation
# =============================================================================

# =============================================================================
# Main Configuration Generator
# =============================================================================

# Генерация базовой конфигурации nginx.conf
generate_nginx_main_conf() {
    log_info "Генерация основного файла nginx.conf..."
    
    cat > "${NGINX_CONF_FILE}" <<'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 100M;

    # Gzip Settings
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript 
               application/json application/javascript application/xml+rss 
               application/rss+xml font/truetype font/opentype 
               application/vnd.ms-fontobject image/svg+xml;

    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # SSL Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Health check endpoint
    server {
        listen 80;
        server_name _;
        
        location /health {
            access_log off;
            return 200 "OK\n";
            add_header Content-Type text/plain;
        }
        
        location / {
            return 404;
        }
    }

    # Include additional configurations
    include /etc/nginx/conf.d/*.conf;
}
EOF
    
    log_success "Основной файл nginx.conf создан"
}

# =============================================================================
# Basic Configuration (Domain Only)
# =============================================================================

# Генерация базовой конфигурации (только домен)
generate_nginx_conf_basic() {
    local domain="$1"
    local backend_url="$2"  # http://remnawave-panel:3000
    local conf_file="${NGINX_CONFIG_DIR}/conf.d/${domain}.conf"
    
    log_info "Генерация базовой конфигурации для ${domain}..."
    
    # Используем шаблон
    local template_file="${SCRIPT_DIR}/providers/nginx/templates/basic.conf"
    
    if [ -f "${template_file}" ]; then
        sed -e "s|{{DOMAIN}}|${domain}|g" \
            -e "s|{{BACKEND_URL}}|${backend_url}|g" \
            "${template_file}" > "${conf_file}"
    else
        # Fallback: генерация без шаблона
        cat > "${conf_file}" <<EOF
# Basic Configuration for ${domain}
upstream backend_${domain//./_} {
    server ${backend_url#http://};
    keepalive 32;
}

server {
    listen 80;
    server_name ${domain};

    # Redirect HTTP to HTTPS
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${domain};

    # SSL Configuration
    ssl_certificate /etc/nginx/ssl/${domain}.crt;
    ssl_certificate_key /etc/nginx/ssl/${domain}.key;

    # Logging
    access_log /var/log/nginx/${domain}_access.log;
    error_log /var/log/nginx/${domain}_error.log;

    # Proxy settings
    location / {
        proxy_pass ${backend_url};
        proxy_http_version 1.1;
        
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_redirect off;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF
    fi
    
    log_success "Базовая конфигурация создана: ${conf_file}"
}

# =============================================================================
# Cookie Auth Configuration
# =============================================================================

# Генерация конфигурации с Cookie Auth
generate_nginx_conf_cookie_auth() {
    local domain="$1"
    local backend_url="$2"
    local selfsteal_url="$3"  # http://selfsteal:8080
    local cookie_secret="$4"
    local conf_file="${NGINX_CONFIG_DIR}/conf.d/${domain}.conf"
    
    log_info "Генерация конфигурации Cookie Auth для ${domain}..."
    
    # Генерация секрета для cookie, если не указан
    if [ -z "${cookie_secret}" ]; then
        cookie_secret=$(generate_random_string 32)
    fi
    
    local template_file="${SCRIPT_DIR}/providers/nginx/templates/cookie-auth.conf"
    
    if [ -f "${template_file}" ]; then
        sed -e "s|{{DOMAIN}}|${domain}|g" \
            -e "s|{{BACKEND_URL}}|${backend_url}|g" \
            -e "s|{{SELFSTEAL_URL}}|${selfsteal_url}|g" \
            -e "s|{{COOKIE_SECRET}}|${cookie_secret}|g" \
            "${template_file}" > "${conf_file}"
    else
        # Fallback: генерация без шаблона
        cat > "${conf_file}" <<EOF
# Cookie Auth Configuration for ${domain}
map \$http_cookie \$auth_cookie {
    default 0;
    "~*remnawave_auth=${cookie_secret}" 1;
}

upstream backend_${domain//./_} {
    server ${backend_url#http://};
    keepalive 32;
}

upstream selfsteal_${domain//./_} {
    server ${selfsteal_url#http://};
    keepalive 16;
}

server {
    listen 80;
    server_name ${domain};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${domain};

    # SSL Configuration
    ssl_certificate /etc/nginx/ssl/${domain}.crt;
    ssl_certificate_key /etc/nginx/ssl/${domain}.key;

    # Logging
    access_log /var/log/nginx/${domain}_access.log;
    error_log /var/log/nginx/${domain}_error.log;

    # Selfsteal authentication page
    location /auth {
        if (\$auth_cookie = 1) {
            return 302 /;
        }
        
        proxy_pass ${selfsteal_url};
        proxy_http_version 1.1;
        
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Main application
    location / {
        if (\$auth_cookie != 1) {
            return 302 /auth;
        }
        
        proxy_pass ${backend_url};
        proxy_http_version 1.1;
        
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_redirect off;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF
    fi
    
    # Сохранение секрета
    echo "${cookie_secret}" > "${NGINX_CONFIG_DIR}/ssl/${domain}_cookie_secret"
    chmod 600 "${NGINX_CONFIG_DIR}/ssl/${domain}_cookie_secret"
    
    log_success "Cookie Auth конфигурация создана: ${conf_file}"
    log_info "Cookie Secret: ${cookie_secret}"
}

# =============================================================================
# Full Auth Configuration (HTTP Basic Auth)
# =============================================================================

# Генерация конфигурации с Full Auth (HTTP Basic Auth)
generate_nginx_conf_full_auth() {
    local domain="$1"
    local backend_url="$2"
    local auth_username="$3"
    local auth_password="$4"
    local conf_file="${NGINX_CONFIG_DIR}/conf.d/${domain}.conf"
    local htpasswd_file="${NGINX_CONFIG_DIR}/ssl/${domain}.htpasswd"
    
    log_info "Генерация конфигурации Full Auth для ${domain}..."
    
    # Генерация .htpasswd файла
    if command -v htpasswd &> /dev/null; then
        htpasswd -bc "${htpasswd_file}" "${auth_username}" "${auth_password}"
    else
        # Использование openssl для генерации htpasswd
        local encrypted_password
        encrypted_password=$(openssl passwd -apr1 "${auth_password}")
        echo "${auth_username}:${encrypted_password}" > "${htpasswd_file}"
    fi
    
    chmod 600 "${htpasswd_file}"
    
    local template_file="${SCRIPT_DIR}/providers/nginx/templates/full-auth.conf"
    
    if [ -f "${template_file}" ]; then
        sed -e "s|{{DOMAIN}}|${domain}|g" \
            -e "s|{{BACKEND_URL}}|${backend_url}|g" \
            -e "s|{{HTPASSWD_FILE}}|/etc/nginx/ssl/${domain}.htpasswd|g" \
            "${template_file}" > "${conf_file}"
    else
        # Fallback: генерация без шаблона
        cat > "${conf_file}" <<EOF
# Full Auth Configuration for ${domain}
upstream backend_${domain//./_} {
    server ${backend_url#http://};
    keepalive 32;
}

server {
    listen 80;
    server_name ${domain};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${domain};

    # SSL Configuration
    ssl_certificate /etc/nginx/ssl/${domain}.crt;
    ssl_certificate_key /etc/nginx/ssl/${domain}.key;

    # Logging
    access_log /var/log/nginx/${domain}_access.log;
    error_log /var/log/nginx/${domain}_error.log;

    # HTTP Basic Auth
    auth_basic "Remnawave Panel Access";
    auth_basic_user_file /etc/nginx/ssl/${domain}.htpasswd;

    # Main application
    location / {
        proxy_pass ${backend_url};
        proxy_http_version 1.1;
        
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_redirect off;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF
    fi
    
    log_success "Full Auth конфигурация создана: ${conf_file}"
    log_info "HTTP Basic Auth: ${auth_username} / ${auth_password}"
}

# =============================================================================
# Domain Management
# =============================================================================

# Добавление upstream в конфигурацию
add_upstream_to_nginx() {
    local name="$1"
    local server="$2"
    local conf_file="$3"
    
    if grep -q "upstream ${name}" "${conf_file}"; then
        log_warning "Upstream ${name} уже существует"
        return 1
    fi
    
    # Добавление upstream блока перед первым server блоком
    sed -i "/^server {/i upstream ${name} {\n    server ${server};\n    keepalive 32;\n}\n" "${conf_file}"
    
    log_success "Upstream ${name} добавлен в ${conf_file}"
}

# Удаление upstream из конфигурации
remove_upstream_from_nginx() {
    local name="$1"
    local conf_file="$2"
    
    if ! grep -q "upstream ${name}" "${conf_file}"; then
        log_warning "Upstream ${name} не найден"
        return 1
    fi
    
    # Удаление upstream блока
    sed -i "/^upstream ${name}/,/^}/d" "${conf_file}"
    
    log_success "Upstream ${name} удален из ${conf_file}"
}

# Добавление нового домена
add_domain_to_nginx() {
    local domain="$1"
    local backend_url="$2"
    local auth_type="${3:-basic}"  # basic, cookie, full
    
    case "${auth_type}" in
        basic)
            generate_nginx_conf_basic "${domain}" "${backend_url}"
            ;;
        cookie)
            local selfsteal_url="$4"
            local cookie_secret="$5"
            generate_nginx_conf_cookie_auth "${domain}" "${backend_url}" "${selfsteal_url}" "${cookie_secret}"
            ;;
        full)
            local auth_username="$4"
            local auth_password="$5"
            generate_nginx_conf_full_auth "${domain}" "${backend_url}" "${auth_username}" "${auth_password}"
            ;;
        *)
            log_error "Неизвестный тип авторизации: ${auth_type}"
            return 1
            ;;
    esac
    
    # Проверка и перезагрузка
    if validate_nginx_conf; then
        reload_nginx
        return 0
    else
        log_error "Конфигурация содержит ошибки"
        return 1
    fi
}

# Удаление домена
remove_domain_from_nginx() {
    local domain="$1"
    local conf_file="${NGINX_CONFIG_DIR}/conf.d/${domain}.conf"
    
    if [ ! -f "${conf_file}" ]; then
        log_error "Конфигурация для домена ${domain} не найдена"
        return 1
    fi
    
    # Резервная копия
    cp "${conf_file}" "${conf_file}.bak"
    
    # Удаление конфигурации
    rm -f "${conf_file}"
    
    log_success "Домен ${domain} удален"
    
    # Перезагрузка
    reload_nginx
}

# =============================================================================
# SSL Configuration Functions
# =============================================================================

# Настройка SSL Let's Encrypt
configure_ssl_letsencrypt() {
    local domain="$1"
    local email="$2"
    
    log_info "Настройка SSL Let's Encrypt для ${domain}..."
    
    # Установка certbot, если не установлен
    if ! command -v certbot &> /dev/null; then
        log_info "Установка Certbot..."
        apt-get update && apt-get install -y certbot
    fi
    
    # Получение сертификата
    certbot certonly --standalone \
        --preferred-challenges http \
        --email "${email}" \
        --agree-tos \
        --no-eff-email \
        -d "${domain}"
    
    if [ $? -eq 0 ]; then
        # Копирование сертификатов
        cp "/etc/letsencrypt/live/${domain}/fullchain.pem" "${NGINX_CONFIG_DIR}/ssl/${domain}.crt"
        cp "/etc/letsencrypt/live/${domain}/privkey.pem" "${NGINX_CONFIG_DIR}/ssl/${domain}.key"
        
        log_success "SSL сертификат Let's Encrypt установлен для ${domain}"
        return 0
    else
        log_error "Не удалось получить SSL сертификат для ${domain}"
        return 1
    fi
}

# Настройка SSL Cloudflare
configure_ssl_cloudflare() {
    local domain="$1"
    local cf_api_token="$2"
    local email="$3"
    
    log_info "Настройка SSL Cloudflare для ${domain}..."
    
    # Установка certbot-dns-cloudflare
    if ! pip3 list | grep -q certbot-dns-cloudflare; then
        log_info "Установка certbot-dns-cloudflare..."
        pip3 install certbot-dns-cloudflare
    fi
    
    # Создание credentials файла
    local cf_credentials="${NGINX_CONFIG_DIR}/ssl/cloudflare.ini"
    cat > "${cf_credentials}" <<EOF
dns_cloudflare_api_token = ${cf_api_token}
EOF
    chmod 600 "${cf_credentials}"
    
    # Получение сертификата
    certbot certonly --dns-cloudflare \
        --dns-cloudflare-credentials "${cf_credentials}" \
        --email "${email}" \
        --agree-tos \
        --no-eff-email \
        -d "${domain}"
    
    if [ $? -eq 0 ]; then
        # Копирование сертификатов
        cp "/etc/letsencrypt/live/${domain}/fullchain.pem" "${NGINX_CONFIG_DIR}/ssl/${domain}.crt"
        cp "/etc/letsencrypt/live/${domain}/privkey.pem" "${NGINX_CONFIG_DIR}/ssl/${domain}.key"
        
        log_success "SSL сертификат Cloudflare установлен для ${domain}"
        return 0
    else
        log_error "Не удалось получить SSL сертификат Cloudflare для ${domain}"
        return 1
    fi
}

# Настройка Self-signed SSL
configure_ssl_self_signed() {
    local domain="$1"
    
    log_info "Генерация self-signed SSL сертификата для ${domain}..."
    
    local cert_file="${NGINX_CONFIG_DIR}/ssl/${domain}.crt"
    local key_file="${NGINX_CONFIG_DIR}/ssl/${domain}.key"
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "${key_file}" \
        -out "${cert_file}" \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=${domain}"
    
    if [ $? -eq 0 ]; then
        chmod 600 "${key_file}"
        chmod 644 "${cert_file}"
        
        log_success "Self-signed SSL сертификат создан для ${domain}"
        log_warning "⚠️  Self-signed сертификаты не рекомендуются для production"
        return 0
    else
        log_error "Не удалось создать self-signed сертификат"
        return 1
    fi
}

# =============================================================================
# WebSocket Support
# =============================================================================

# Добавление поддержки WebSocket
add_websocket_support() {
    local conf_file="$1"
    local location="${2:-/}"
    
    # Проверка, есть ли уже WebSocket конфигурация
    if grep -q "proxy_set_header Upgrade" "${conf_file}"; then
        log_info "WebSocket поддержка уже настроена"
        return 0
    fi
    
    # Добавление WebSocket headers в location блок
    sed -i "/location ${location//\//\\/}/,/}/ {
        /proxy_pass/a\        proxy_http_version 1.1;\n        proxy_set_header Upgrade \$http_upgrade;\n        proxy_set_header Connection \"upgrade\";
    }" "${conf_file}"
    
    log_success "WebSocket поддержка добавлена в ${conf_file}"
}

# =============================================================================
# Backup & Restore
# =============================================================================

# Резервная копия конфигурации NGINX
backup_nginx_config() {
    local backup_name="${1:-nginx_$(date +%Y%m%d_%H%M%S)}"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    mkdir -p "${backup_path}"
    
    cp -r "${NGINX_CONFIG_DIR}" "${backup_path}/"
    cp "${NGINX_COMPOSE_FILE}" "${backup_path}/"
    
    log_success "Резервная копия NGINX создана: ${backup_path}"
    echo "${backup_path}"
}

# Восстановление конфигурации NGINX
restore_nginx_config() {
    local backup_path="$1"
    
    if [ ! -d "${backup_path}" ]; then
        log_error "Резервная копия не найдена: ${backup_path}"
        return 1
    fi
    
    # Создание резервной копии перед восстановлением
    backup_nginx_config "before_restore_$(date +%Y%m%d_%H%M%S)" >/dev/null
    
    # Восстановление
    rm -rf "${NGINX_CONFIG_DIR}"
    cp -r "${backup_path}/nginx" "${INSTALL_DIR}/"
    cp "${backup_path}/nginx-compose.yml" "${COMPOSE_DIR}/"
    
    # Проверка и перезагрузка
    if validate_nginx_conf; then
        reload_nginx
        log_success "Конфигурация NGINX восстановлена из ${backup_path}"
        return 0
    else
        log_error "Восстановленная конфигурация содержит ошибки"
        return 1
    fi
}
