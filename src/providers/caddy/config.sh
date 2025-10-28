#!/usr/bin/env bash
# Caddy Configuration Module
# Description: Generates and manages Caddyfile configurations
# Author: DigneZzZ
# Version: 1.0.0

# Prevent double loading
[[ -n "${CADDY_CONFIG_LOADED}" ]] && return 0
readonly CADDY_CONFIG_LOADED=1

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../config.sh"
source "$SCRIPT_DIR/../../core/display.sh"
source "$SCRIPT_DIR/../../lib/crypto.sh"

# =============================================================================
# CADDYFILE GENERATION - BASIC
# =============================================================================

generate_caddyfile_basic() {
    local domain="$1"
    local backend_url="$2"
    local email="${3:-admin@$domain}"
    local output="${4:-$CADDY_DIR/config/Caddyfile}"
    
    cat > "$output" <<EOF
{
    admin off
    email $email
}

$domain {
    reverse_proxy $backend_url {
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up Host {host}
    }
    
    encode gzip
    
    log {
        output file /var/log/caddy/access.log
        format json
    }
}

# HTTP redirect
http://$domain {
    redir https://{host}{uri} permanent
}

# Health check
:2019 {
    respond /health 200
}
EOF
}

# =============================================================================
# CADDYFILE GENERATION - COOKIE AUTH
# =============================================================================

generate_caddyfile_cookie_auth() {
    local domain="$1"
    local backend_url="$2"
    local secret_key="$3"
    local static_site_domain="${4:-}"
    local email="${5:-admin@$domain}"
    local output="${6:-$CADDY_DIR/config/Caddyfile}"
    
    cat > "$output" <<EOF
{
    admin off
    email $email
}

$domain {
    # Set cookie when secret param is present
    @has_token_param {
        query caddy=$secret_key
    }
    
    handle @has_token_param {
        header +Set-Cookie "caddy=$secret_key; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=31536000"
        redir / 302
    }
    
    # Show static site or block if no cookie
    @unauthorized {
        not header Cookie *caddy=$secret_key*
        not query caddy=$secret_key
    }
    
    handle @unauthorized {
EOF

    if [ -n "$static_site_domain" ]; then
        cat >> "$output" <<EOF
        # Show static site
        root * /var/www/html
        try_files {path} /index.html
        file_server
EOF
    else
        cat >> "$output" <<EOF
        # Block access
        respond "Access Denied" 403
EOF
    fi

    cat >> "$output" <<EOF
    }
    
    # Authorized users - reverse proxy
    reverse_proxy $backend_url {
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up Host {host}
    }
    
    encode gzip
    
    log {
        output file /var/log/caddy/access.log
        format json
    }
}
EOF

    # Add static site domain if provided
    if [ -n "$static_site_domain" ]; then
        cat >> "$output" <<EOF

# Static selfsteal site
https://$static_site_domain {
    root * /var/www/html
    try_files {path} /index.html
    file_server
    
    encode gzip
}
EOF
    fi

    cat >> "$output" <<EOF

# HTTP redirect
http://$domain {
    redir https://{host}{uri} permanent
}

# Health check
:2019 {
    respond /health 200
}
EOF
}

# =============================================================================
# CADDYFILE GENERATION - FULL AUTH (2FA)
# =============================================================================

generate_caddyfile_full_auth() {
    local domain="$1"
    local backend_url="$2"
    local username="$3"
    local password="$4"
    local static_site_domain="${5:-}"
    local email="${6:-admin@$domain}"
    local output="${7:-$CADDY_DIR/config/Caddyfile}"
    
    # Generate password hash for basicauth
    local password_hash
    password_hash=$(docker run --rm "$CADDY_IMAGE" caddy hash-password --plaintext "$password" 2>/dev/null)
    
    cat > "$output" <<EOF
{
    admin off
    email $email
}

$domain {
    # Basic Auth for all requests
    basicauth {
        $username $password_hash
    }
    
    reverse_proxy $backend_url {
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up Host {host}
    }
    
    encode gzip
    
    log {
        output file /var/log/caddy/access.log
        format json
    }
}
EOF

    # Add static site domain if provided
    if [ -n "$static_site_domain" ]; then
        cat >> "$output" <<EOF

# Static selfsteal site
https://$static_site_domain {
    root * /var/www/html
    try_files {path} /index.html
    file_server
    
    encode gzip
}
EOF
    fi

    cat >> "$output" <<EOF

# HTTP redirect
http://$domain {
    redir https://{host}{uri} permanent
}

# Health check
:2019 {
    respond /health 200
}
EOF
}

# =============================================================================
# CADDYFILE GENERATION - MULTI-DOMAIN
# =============================================================================

generate_caddyfile_multi_domain() {
    local output="${1:-$CADDY_DIR/config/Caddyfile}"
    local email="${2:-admin@example.com}"
    
    cat > "$output" <<EOF
{
    admin off
    email $email
}

# This is a template for multiple domains
# Add your domain configurations below

# Example domain
# example.com {
#     reverse_proxy localhost:3000
#     encode gzip
# }

# Health check
:2019 {
    respond /health 200
}
EOF
}

# =============================================================================
# CADDYFILE SNIPPETS
# =============================================================================

add_domain_to_caddyfile() {
    local domain="$1"
    local backend_url="$2"
    local caddyfile="${3:-$CADDY_DIR/config/Caddyfile}"
    
    # Check if domain already exists
    if grep -q "^$domain {" "$caddyfile"; then
        display_warning "Домен $domain уже существует в конфигурации"
        return 1
    fi
    
    # Add domain before health check section
    local temp_file=$(mktemp)
    
    # Find health check section and insert before it
    awk -v domain="$domain" -v backend="$backend_url" '
    /^:2019 \{/ {
        print ""
        print domain " {"
        print "    reverse_proxy " backend " {"
        print "        header_up X-Real-IP {remote_host}"
        print "        header_up X-Forwarded-For {remote_host}"
        print "        header_up Host {host}"
        print "    }"
        print "    encode gzip"
        print "}"
        print ""
    }
    {print}
    ' "$caddyfile" > "$temp_file"
    
    mv "$temp_file" "$caddyfile"
    display_success "Домен $domain добавлен в конфигурацию"
}

remove_domain_from_caddyfile() {
    local domain="$1"
    local caddyfile="${2:-$CADDY_DIR/config/Caddyfile}"
    
    # Remove domain block
    local temp_file=$(mktemp)
    
    awk -v domain="$domain" '
    BEGIN { skip=0 }
    $0 ~ "^" domain " \\{" { skip=1; next }
    skip && /^\}/ { skip=0; next }
    !skip { print }
    ' "$caddyfile" > "$temp_file"
    
    mv "$temp_file" "$caddyfile"
    display_success "Домен $domain удален из конфигурации"
}

# =============================================================================
# SSL CONFIGURATION
# =============================================================================

configure_ssl_letsencrypt() {
    local domain="$1"
    local email="$2"
    local caddyfile="${3:-$CADDY_DIR/config/Caddyfile}"
    
    # Let's Encrypt is default in Caddy, just ensure email is set
    if ! grep -q "email $email" "$caddyfile"; then
        # Add email to global options
        sed -i "/{/a\\    email $email" "$caddyfile"
    fi
    
    display_success "SSL настроен для $domain (Let's Encrypt)"
}

configure_ssl_cloudflare() {
    local domain="$1"
    local api_token="$2"
    local email="$3"
    local caddyfile="${4:-$CADDY_DIR/config/Caddyfile}"
    
    # Add Cloudflare DNS challenge configuration
    sed -i "/{/a\\    email $email\\n    acme_dns cloudflare $api_token" "$caddyfile"
    
    display_success "SSL настроен для $domain (Cloudflare DNS)"
}

configure_ssl_self_signed() {
    local domain="$1"
    local caddyfile="${2:-$CADDY_DIR/config/Caddyfile}"
    
    # Add to domain block
    sed -i "/^$domain {/a\\    tls internal" "$caddyfile"
    
    display_success "SSL настроен для $domain (Self-signed)"
}

# =============================================================================
# REVERSE PROXY CONFIGURATION
# =============================================================================

configure_reverse_proxy() {
    local domain="$1"
    local backend_url="$2"
    local options="$3"
    
    generate_caddyfile_basic "$domain" "$backend_url" "admin@$domain"
}

configure_reverse_proxy_with_headers() {
    local domain="$1"
    local backend_url="$2"
    local extra_headers="$3"
    local output="${4:-$CADDY_DIR/config/Caddyfile}"
    
    cat > "$output" <<EOF
$domain {
    reverse_proxy $backend_url {
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up Host {host}
        $extra_headers
    }
    
    encode gzip
}
EOF
}

# =============================================================================
# WEBSOCKET SUPPORT
# =============================================================================

add_websocket_support() {
    local domain="$1"
    local ws_path="$2"
    local backend_url="$3"
    local caddyfile="${4:-$CADDY_DIR/config/Caddyfile}"
    
    # Add WebSocket path to domain configuration
    local temp_file=$(mktemp)
    
    awk -v domain="$domain" -v path="$ws_path" -v backend="$backend_url" '
    $0 ~ "^" domain " \\{" { 
        print
        print "    @websocket {"
        print "        path " path
        print "        header Connection *Upgrade*"
        print "        header Upgrade websocket"
        print "    }"
        print ""
        print "    handle @websocket {"
        print "        reverse_proxy " backend " {"
        print "            header_up Upgrade {http.request.header.Upgrade}"
        print "            header_up Connection {http.request.header.Connection}"
        print "        }"
        print "    }"
        print ""
        next
    }
    {print}
    ' "$caddyfile" > "$temp_file"
    
    mv "$temp_file" "$caddyfile"
}

# =============================================================================
# RATE LIMITING
# =============================================================================

add_rate_limit() {
    local domain="$1"
    local rate="$2"
    local burst="$3"
    local caddyfile="${4:-$CADDY_DIR/config/Caddyfile}"
    
    # Note: Rate limiting requires caddy-ratelimit plugin
    display_warning "Rate limiting требует плагин caddy-ratelimit"
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

backup_caddyfile() {
    local caddyfile="${1:-$CADDY_DIR/config/Caddyfile}"
    local backup_file="$caddyfile.backup.$(date +%Y%m%d_%H%M%S)"
    
    cp "$caddyfile" "$backup_file"
    display_success "Резервная копия: $backup_file"
}

restore_caddyfile() {
    local backup_file="$1"
    local caddyfile="${2:-$CADDY_DIR/config/Caddyfile}"
    
    if [ ! -f "$backup_file" ]; then
        display_error "Файл резервной копии не найден"
        return 1
    fi
    
    cp "$backup_file" "$caddyfile"
    display_success "Конфигурация восстановлена"
}

list_domains_in_caddyfile() {
    local caddyfile="${1:-$CADDY_DIR/config/Caddyfile}"
    
    grep -E "^[a-zA-Z0-9.-]+ \{" "$caddyfile" | sed 's/ {//'
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f generate_caddyfile_basic
export -f generate_caddyfile_cookie_auth
export -f generate_caddyfile_full_auth
export -f generate_caddyfile_multi_domain
export -f add_domain_to_caddyfile
export -f remove_domain_from_caddyfile
export -f configure_ssl_letsencrypt
export -f configure_ssl_cloudflare
export -f configure_ssl_self_signed
export -f configure_reverse_proxy
export -f configure_reverse_proxy_with_headers
export -f add_websocket_support
export -f add_rate_limit
export -f backup_caddyfile
export -f restore_caddyfile
export -f list_domains_in_caddyfile
