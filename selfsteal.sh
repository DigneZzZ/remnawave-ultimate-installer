#!/usr/bin/env bash
# Caddy for Reality Selfsteal Installation Script
# This script installs and manages Caddy for Reality traffic masking
# VERSION=2.1.5

# Handle @ prefix for consistency with other scripts
if [ $# -gt 0 ] && [ "$1" = "@" ]; then
    shift  
fi

set -e
SCRIPT_VERSION="2.1.5"
GITHUB_REPO="dignezzz/remnawave-scripts"
UPDATE_URL="https://raw.githubusercontent.com/$GITHUB_REPO/main/selfsteal.sh"
SCRIPT_URL="$UPDATE_URL"  # Алиас для совместимости
CONTAINER_NAME="caddy-selfsteal"
VOLUME_PREFIX="caddy"
CADDY_VERSION="2.9.1"

# Configuration
APP_NAME="selfsteal"
APP_DIR="/opt/caddy"
CADDY_CONFIG_DIR="$APP_DIR"
HTML_DIR="/opt/caddy/html"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color


# Parse command line arguments
COMMAND=""
if [ $# -gt 0 ]; then
    case "$1" in
        --help|-h)
            show_help
            exit 0
            ;;
        --version|-v)
            echo "Caddy Selfsteal Management Script v$SCRIPT_VERSION"
            exit 0
            ;;
        *)
            COMMAND="$1"
            ;;
    esac
fi
# Fetch IP address
NODE_IP=$(curl -s -4 ifconfig.io 2>/dev/null || echo "127.0.0.1")
if [ -z "$NODE_IP" ] || [ "$NODE_IP" = "" ]; then
    NODE_IP="127.0.0.1"
fi

# Check if running as root
check_running_as_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}❌ This script must be run as root (use sudo)${NC}"
        exit 1
    fi
}

# Check system requirements
check_system_requirements() {
    echo -e "${WHITE}🔍 Checking System Requirements${NC}"
    echo -e "${GRAY}$(printf '─%.0s' $(seq 1 40))${NC}"
    echo

    local requirements_met=true

    # Check Docker
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker is not installed${NC}"
        echo -e "${GRAY}   Please install Docker first${NC}"
        requirements_met=false
    else
        local docker_version=$(docker --version | cut -d' ' -f3 | tr -d ',')
        echo -e "${GREEN}✅ Docker installed: $docker_version${NC}"
    fi

    # Check Docker Compose
    if ! docker compose version >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker Compose V2 is not available${NC}"
        requirements_met=false
    else
        local compose_version=$(docker compose version --short 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✅ Docker Compose V2: $compose_version${NC}"
    fi

    # Check curl
    if ! command -v curl >/dev/null 2>&1; then
        echo -e "${RED}❌ curl is not installed${NC}"
        requirements_met=false
    else
        echo -e "${GREEN}✅ curl is available${NC}"
    fi

    # Check available disk space
    local available_space=$(df / | tail -1 | awk '{print $4}')
    local available_gb=$((available_space / 1024 / 1024))
    
    if [ $available_gb -lt 1 ]; then
        echo -e "${RED}❌ Insufficient disk space: ${available_gb}GB available${NC}"
        requirements_met=false
    else
        echo -e "${GREEN}✅ Sufficient disk space: ${available_gb}GB available${NC}"
    fi

    echo

    if [ "$requirements_met" = false ]; then
        echo -e "${RED}❌ System requirements not met!${NC}"
        return 1
    else
        echo -e "${GREEN}🎉 All system requirements satisfied!${NC}"
        return 0
    fi
}


validate_domain_dns() {
    local domain="$1"
    local server_ip="$2"
    
    echo -e "${WHITE}🔍 Validating DNS Configuration${NC}"
    echo -e "${GRAY}$(printf '─%.0s' $(seq 1 40))${NC}"
    echo
    
    # Check if domain format is valid
    if ! [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        echo -e "${RED}❌ Invalid domain format!${NC}"
        echo -e "${GRAY}   Domain should be in format: subdomain.domain.com${NC}"
        return 1
    fi
    
    echo -e "${WHITE}📝 Domain:${NC} $domain"
    echo -e "${WHITE}🖥️  Server IP:${NC} $server_ip"
    echo
    
    # Check if dig is available
    if ! command -v dig >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Installing dig utility...${NC}"
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update >/dev/null 2>&1
            apt-get install -y dnsutils >/dev/null 2>&1
        elif command -v yum >/dev/null 2>&1; then
            yum install -y bind-utils >/dev/null 2>&1
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y bind-utils >/dev/null 2>&1
        else
            echo -e "${RED}❌ Cannot install dig utility automatically${NC}"
            echo -e "${GRAY}   Please install manually: apt install dnsutils${NC}"
            return 1
        fi
        
        if ! command -v dig >/dev/null 2>&1; then
            echo -e "${RED}❌ Failed to install dig utility${NC}"
            return 1
        fi
        echo -e "${GREEN}✅ dig utility installed${NC}"
        echo
    fi
    
    # Perform DNS lookups
    echo -e "${WHITE}🔍 Checking DNS Records:${NC}"
    echo
    
    # A record check
    echo -e "${GRAY}   Checking A record...${NC}"
    local a_records=$(dig +short A "$domain" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
    
    if [ -z "$a_records" ]; then
        echo -e "${RED}   ❌ No A record found${NC}"
        local dns_status="failed"
    else
        echo -e "${GREEN}   ✅ A record found:${NC}"
        while IFS= read -r ip; do
            echo -e "${GRAY}      → $ip${NC}"
            if [ "$ip" = "$server_ip" ]; then
                local dns_match="true"
            fi
        done <<< "$a_records"
    fi
    
    # AAAA record check (IPv6)
    echo -e "${GRAY}   Checking AAAA record...${NC}"
    local aaaa_records=$(dig +short AAAA "$domain" 2>/dev/null)
    
    if [ -z "$aaaa_records" ]; then
        echo -e "${GRAY}   ℹ️  No AAAA record found (IPv6)${NC}"
    else
        echo -e "${GREEN}   ✅ AAAA record found:${NC}"
        while IFS= read -r ip; do
            echo -e "${GRAY}      → $ip${NC}"
        done <<< "$aaaa_records"
    fi
    
    # CNAME record check
    echo -e "${GRAY}   Checking CNAME record...${NC}"
    local cname_record=$(dig +short CNAME "$domain" 2>/dev/null)
    
    if [ -n "$cname_record" ]; then
        echo -e "${GREEN}   ✅ CNAME record found:${NC}"
        echo -e "${GRAY}      → $cname_record${NC}"
        
        # Check CNAME target
        echo -e "${GRAY}   Resolving CNAME target...${NC}"
        local cname_a_records=$(dig +short A "$cname_record" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
        
        if [ -n "$cname_a_records" ]; then
            echo -e "${GREEN}   ✅ CNAME target resolved:${NC}"
            while IFS= read -r ip; do
                echo -e "${GRAY}      → $ip${NC}"
                if [ "$ip" = "$server_ip" ]; then
                    local dns_match="true"
                fi
            done <<< "$cname_a_records"
        fi
    else
        echo -e "${GRAY}   ℹ️  No CNAME record found${NC}"
    fi
    
    echo
    
    # DNS propagation check with multiple servers
    echo -e "${WHITE}🌐 Checking DNS Propagation:${NC}"
    echo
    
    local dns_servers=("8.8.8.8" "1.1.1.1" "208.67.222.222" "9.9.9.9")
    local propagation_count=0
    
    for dns_server in "${dns_servers[@]}"; do
        echo -e "${GRAY}   Checking via $dns_server...${NC}"
        local remote_a=$(dig @"$dns_server" +short A "$domain" 2>/dev/null | head -1)
        
        if [ -n "$remote_a" ] && [[ "$remote_a" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            if [ "$remote_a" = "$server_ip" ]; then
                echo -e "${GREEN}   ✅ $remote_a (matches server)${NC}"
                ((propagation_count++))
            else
                echo -e "${YELLOW}   ⚠️  $remote_a (different IP)${NC}"
            fi
        else
            echo -e "${RED}   ❌ No response${NC}"
        fi
    done
    
    echo
    
    # Port availability check (только важные для Reality)
    echo -e "${WHITE}🔧 Checking Port Availability:${NC}"
    echo
    
    # Check if port 443 is free (should be free for Xray)
    echo -e "${GRAY}   Checking port 443 availability...${NC}"
    if ss -tlnp | grep -q ":443 "; then
        echo -e "${YELLOW}   ⚠️  Port 443 is occupied${NC}"
        echo -e "${GRAY}      This port will be needed for Xray Reality${NC}"
        local port_info=$(ss -tlnp | grep ":443 " | head -1 | awk '{print $1, $4}')
        echo -e "${GRAY}      Current: $port_info${NC}"
    else
        echo -e "${GREEN}   ✅ Port 443 is available for Xray${NC}"
    fi
    
    # Check if port 80 is free (will be used by Caddy)
    echo -e "${GRAY}   Checking port 80 availability...${NC}"
    if ss -tlnp | grep -q ":80 "; then
        echo -e "${YELLOW}   ⚠️  Port 80 is occupied${NC}"
        echo -e "${GRAY}      This port will be used by Caddy for HTTP redirects${NC}"
        local port80_occupied=$(ss -tlnp | grep ":80 " | head -1)
        echo -e "${GRAY}      Current: $port80_occupied${NC}"
    else
        echo -e "${GREEN}   ✅ Port 80 is available for Caddy${NC}"
    fi
    
    echo
    
    # Summary and recommendations
    echo -e "${WHITE}📋 DNS Validation Summary:${NC}"
    echo -e "${GRAY}$(printf '─%.0s' $(seq 1 35))${NC}"
    
    if [ "$dns_match" = "true" ]; then
        echo -e "${GREEN}✅ Domain correctly points to this server${NC}"
        echo -e "${GREEN}✅ DNS propagation: $propagation_count/4 servers${NC}"
        
        if [ "$propagation_count" -ge 2 ]; then
            echo -e "${GREEN}✅ DNS propagation looks good${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠️  DNS propagation is limited${NC}"
            echo -e "${GRAY}   This might cause issues if needed${NC}"
        fi
    else
        echo -e "${RED}❌ Domain does not point to this server${NC}"
        echo -e "${GRAY}   Expected IP: $server_ip${NC}"
        
        if [ -n "$a_records" ]; then
            echo -e "${GRAY}   Current IPs: $(echo "$a_records" | tr '\n' ' ')${NC}"
        fi
    fi
    
    echo
    echo -e "${WHITE}🔧 Setup Requirements for Reality:${NC}"
    echo -e "${GRAY}   • Domain must point to this server ✓${NC}"
    echo -e "${GRAY}   • Port 443 must be free for Xray ✓${NC}"
    echo -e "${GRAY}   • Port 80 will be used by Caddy for redirects${NC}"
    echo -e "${GRAY}   • Caddy will serve content on internal port (9443)${NC}"
    echo -e "${GRAY}   • Configure Xray Reality AFTER Caddy installation${NC}"
    
    echo
    
    # Ask user decision
    if [ "$dns_match" = "true" ] && [ "$propagation_count" -ge 2 ]; then
        echo -e "${GREEN}🎉 DNS validation passed! Ready for installation.${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  DNS validation has warnings.${NC}"
        echo
        read -p "Do you want to continue anyway? [y/N]: " -r continue_anyway
        
        if [[ $continue_anyway =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}⚠️  Continuing with installation despite DNS issues...${NC}"
            return 0
        else
            echo -e "${GRAY}Installation cancelled. Please fix DNS configuration first.${NC}"
            return 1
        fi
    fi
}

# Install function
install_command() {
    check_running_as_root
    
    clear
    echo -e "${WHITE}🚀 Caddy for Reality Selfsteal Installation${NC}"
    echo -e "${GRAY}$(printf '─%.0s' $(seq 1 50))${NC}"
    echo

    # Check if already installed
    if [ -d "$APP_DIR" ]; then
        echo -e "${YELLOW}⚠️  Caddy installation already exists at $APP_DIR${NC}"
        echo
        read -p "Do you want to reinstall? [y/N]: " -r confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            echo -e "${GRAY}Installation cancelled${NC}"
            return 0
        fi
        echo
        echo -e "${YELLOW}🗑️  Removing existing installation...${NC}"
        stop_services
        rm -rf "$APP_DIR"
        echo -e "${GREEN}✅ Existing installation removed${NC}"
        echo
    fi

    # Check system requirements
    if ! check_system_requirements; then
        return 1
    fi

    # Collect configuration
    echo -e "${WHITE}📝 Configuration Setup${NC}"
    echo -e "${GRAY}$(printf '─%.0s' $(seq 1 30))${NC}"
    echo

    # Domain configuration
    echo -e "${WHITE}🌐 Domain Configuration${NC}"
    echo -e "${GRAY}This domain should match your Xray Reality configuration (realitySettings.serverNames)${NC}"
    echo
    
    local domain=""
    local skip_dns_check=false
    
    while [ -z "$domain" ]; do
        read -p "Enter your domain (e.g., reality.example.com): " domain
        if [ -z "$domain" ]; then
            echo -e "${RED}❌ Domain cannot be empty!${NC}"
            continue
        fi
        
        echo
        echo -e "${WHITE}🔍 DNS Validation Options:${NC}"
        echo -e "   ${WHITE}1)${NC} ${GRAY}Validate DNS configuration (recommended)${NC}"
        echo -e "   ${WHITE}2)${NC} ${GRAY}Skip DNS validation (for testing/development)${NC}"
        echo
        
        read -p "Select option [1-2]: " dns_choice
        
        case "$dns_choice" in
            1)
                echo
                if ! validate_domain_dns "$domain" "$NODE_IP"; then
                    echo
                    read -p "Try a different domain? [Y/n]: " -r try_again
                    if [[ ! $try_again =~ ^[Nn]$ ]]; then
                        domain=""
                        continue
                    else
                        return 1
                    fi
                fi
                ;;
            2)
                echo -e "${YELLOW}⚠️  Skipping DNS validation...${NC}"
                skip_dns_check=true
                ;;
            *)
                echo -e "${RED}❌ Invalid option!${NC}"
                domain=""
                continue
                ;;
        esac
    done

    # Port configuration
    echo
    echo -e "${WHITE}🔌 Port Configuration${NC}"
    echo -e "${GRAY}This port should match your Xray Reality configuration (realitySettings.dest)${NC}"
    echo
    
    local port="9443"
    read -p "Enter Caddy HTTPS port (default: 9443): " input_port
    if [ -n "$input_port" ]; then
        port="$input_port"
    fi

    # Validate port
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo -e "${RED}❌ Invalid port number!${NC}"
        return 1
    fi

    # Summary
    echo
    echo -e "${WHITE}📋 Installation Summary${NC}"
    echo -e "${GRAY}$(printf '─%.0s' $(seq 1 30))${NC}"
    printf "   ${WHITE}%-20s${NC} ${GRAY}%s${NC}\n" "Domain:" "$domain"
    printf "   ${WHITE}%-20s${NC} ${GRAY}%s${NC}\n" "HTTPS Port:" "$port"
    printf "   ${WHITE}%-20s${NC} ${GRAY}%s${NC}\n" "Installation Path:" "$APP_DIR"
    printf "   ${WHITE}%-20s${NC} ${GRAY}%s${NC}\n" "HTML Path:" "$HTML_DIR"
    printf "   ${WHITE}%-20s${NC} ${GRAY}%s${NC}\n" "Server IP:" "$NODE_IP"
    
    if [ "$skip_dns_check" = true ]; then
        printf "   ${WHITE}%-20s${NC} ${YELLOW}%s${NC}\n" "DNS Validation:" "SKIPPED"
    else
        printf "   ${WHITE}%-20s${NC} ${GREEN}%s${NC}\n" "DNS Validation:" "PASSED"
    fi
    
    echo

    read -p "Proceed with installation? [Y/n]: " -r confirm
    if [[ $confirm =~ ^[Nn]$ ]]; then
        echo -e "${GRAY}Installation cancelled${NC}"
        return 0
    fi

    # Create directories
    echo
    echo -e "${WHITE}📁 Creating Directory Structure${NC}"
    echo -e "${GRAY}$(printf '─%.0s' $(seq 1 40))${NC}"
    
    mkdir -p "$APP_DIR"
    mkdir -p "$HTML_DIR"
    mkdir -p "$APP_DIR/logs"
    
    echo -e "${GREEN}✅ Directories created${NC}"

    # Create .env file
    echo
    echo -e "${WHITE}⚙️  Creating Configuration Files${NC}"
    echo -e "${GRAY}$(printf '─%.0s' $(seq 1 40))${NC}"

    cat > "$APP_DIR/.env" << EOF
# Caddy for Reality Selfsteal Configuration
# Domain Configuration
SELF_STEAL_DOMAIN=$domain
SELF_STEAL_PORT=$port

# Generated on $(date)
# Server IP: $NODE_IP
EOF

    echo -e "${GREEN}✅ .env file created${NC}"

    # Create docker-compose.yml
    cat > "$APP_DIR/docker-compose.yml" << EOF
services:
  caddy:
    image: caddy:2.9.1
    container_name: $CONTAINER_NAME
    restart: unless-stopped
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - $HTML_DIR:/var/www/html
      - ./logs:/var/log/caddy
      - ${VOLUME_PREFIX}_data:/data
      - ${VOLUME_PREFIX}_config:/config
    env_file:
      - .env
    network_mode: "host"
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  ${VOLUME_PREFIX}_data:
  ${VOLUME_PREFIX}_config:
EOF

    echo -e "${GREEN}✅ docker-compose.yml created${NC}"

    # Create Caddyfile
    cat > "$APP_DIR/Caddyfile" << 'EOF'
{
    https_port {$SELF_STEAL_PORT}
    default_bind 127.0.0.1
    servers {
        listener_wrappers {
            proxy_protocol {
                allow 127.0.0.1/32
            }
            tls
        }
    }
    auto_https disable_redirects
    log {
        output file /var/log/caddy/access.log {
            roll_size 10MB
            roll_keep 5
            roll_keep_for 720h
            roll_compression gzip
        }
        level ERROR
        format json 
    }
}

http://{$SELF_STEAL_DOMAIN} {
    bind 0.0.0.0
    redir https://{$SELF_STEAL_DOMAIN}{uri} permanent
    log {
        output file /var/log/caddy/redirect.log {
            roll_size 5MB
            roll_keep 3
            roll_keep_for 168h
        }
    }
}

https://{$SELF_STEAL_DOMAIN} {
    root * /var/www/html
    try_files {path} /index.html
    file_server
    log {
        output file /var/log/caddy/access.log {
            roll_size 10MB
            roll_keep 5
            roll_keep_for 720h
            roll_compression gzip
        }
        level ERROR
    }
}

:{$SELF_STEAL_PORT} {
    tls internal
    respond 204
    log off
}

:80 {
    bind 0.0.0.0
    respond 204
    log off
}
EOF

    echo -e "${GREEN}✅ Caddyfile created${NC}"    # Install random template instead of default HTML
    echo
    echo -e "${WHITE}🎨 Installing Random Template${NC}"
    echo -e "${GRAY}$(printf '─%.0s' $(seq 1 35))${NC}"
    
    # List of available templates
    local templates=("1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11")
    local template_names=("10gag" "Converter" "Convertit" "Downloader" "FileCloud" "Games-site" "ModManager" "SpeedTest" "YouTube" "503 Error v1" "503 Error v2")
    
    # Select random template
    local random_index=$((RANDOM % ${#templates[@]}))
    local selected_template=${templates[$random_index]}
    local selected_name=${template_names[$random_index]}
    local installed_template=""
    
    echo -e "${CYAN}🎲 Selected template: ${selected_name}${NC}"
    echo
    
    if download_template "$selected_template"; then
        echo -e "${GREEN}✅ Random template installed successfully${NC}"
        installed_template="$selected_name template"
    else
        echo -e "${YELLOW}⚠️  Failed to download template, creating fallback${NC}"
        create_default_html
        installed_template="Default template (fallback)"
    fi

    # Install management script
    install_management_script

    # Start services
    echo
    echo -e "${WHITE}🚀 Starting Caddy Services${NC}"
    echo -e "${GRAY}$(printf '─%.0s' $(seq 1 30))${NC}"
    
    cd "$APP_DIR"
    echo -e "${WHITE}🔍 Validating Caddyfile...${NC}"

    if [ ! -f "$APP_DIR/Caddyfile" ]; then
        echo -e "${RED}❌ Caddyfile not found at $APP_DIR/Caddyfile${NC}"
        return 1
    fi

    if validate_caddyfile; then
        echo -e "${GREEN}✅ Caddyfile is valid${NC}"
    else
        echo -e "${RED}❌ Invalid Caddyfile configuration${NC}"
        echo -e "${YELLOW}💡 Check syntax: sudo $APP_NAME edit${NC}"
        return 1
    fi

    if docker compose up -d; then
        echo -e "${GREEN}✅ Caddy services started successfully${NC}"
    else
        echo -e "${RED}❌ Failed to start Caddy services${NC}"
        return 1
    fi

    # Installation complete
    echo
    echo -e "${GRAY}$(printf '─%.0s' $(seq 1 50))${NC}"
    echo -e "${WHITE}🎉 Installation Completed Successfully!${NC}"
    echo -e "${GRAY}$(printf '─%.0s' $(seq 1 50))${NC}"
    echo
      printf "   ${WHITE}%-20s${NC} ${GRAY}%s${NC}\n" "Domain:" "$domain"
    printf "   ${WHITE}%-20s${NC} ${GRAY}%s${NC}\n" "HTTPS Port:" "$port"
    printf "   ${WHITE}%-20s${NC} ${GRAY}%s${NC}\n" "Installation Path:" "$APP_DIR"
    printf "   ${WHITE}%-20s${NC} ${GRAY}%s${NC}\n" "HTML Content:" "$HTML_DIR"
    printf "   ${WHITE}%-20s${NC} ${GRAY}%s${NC}\n" "Installed Template:" "$installed_template"
    printf "   ${WHITE}%-20s${NC} ${GRAY}%s${NC}\n" "Management Command:" "$APP_NAME"
      echo
    echo -e "${WHITE}📋 Next Steps:${NC}"
    echo -e "${GRAY}   • Configure your Xray Reality with:${NC}"
    echo -e "${GRAY}     - serverNames: [\"$domain\"]${NC}"
    echo -e "${GRAY}     - dest: \"127.0.0.1:$port\"${NC}"
    echo -e "${GRAY}   • Change template: sudo $APP_NAME template${NC}"
    echo -e "${GRAY}   • Customize HTML content in: $HTML_DIR${NC}"
    echo -e "${GRAY}   • Check status: sudo $APP_NAME status${NC}"
    echo -e "${GRAY}   • View logs: sudo $APP_NAME logs${NC}"
    echo -e "${GRAY}$(printf '─%.0s' $(seq 1 50))${NC}"
}

validate_caddyfile() {
    echo -e "${BLUE}🔍 Validating Caddyfile...${NC}"
    
    # Загружаем переменные из .env файла для валидации
    if [ -f "$APP_DIR/.env" ]; then
        export $(grep -v '^#' "$APP_DIR/.env" | xargs)
    fi
    
    # Проверяем, что обязательные переменные установлены
    if [ -z "$SELF_STEAL_DOMAIN" ] || [ -z "$SELF_STEAL_PORT" ]; then
        echo -e "${YELLOW}⚠️ Environment variables not set, using defaults for validation${NC}"
        export SELF_STEAL_DOMAIN="example.com"
        export SELF_STEAL_PORT="9443"
    fi
    
    # Валидация с теми же volume что и в рабочем контейнере
    if docker run --rm \
        -v "$APP_DIR/Caddyfile:/etc/caddy/Caddyfile:ro" \
        -v "/etc/letsencrypt:/etc/letsencrypt:ro" \
        -v "$APP_DIR/html:/var/www/html:ro" \
        -e "SELF_STEAL_DOMAIN=$SELF_STEAL_DOMAIN" \
        -e "SELF_STEAL_PORT=$SELF_STEAL_PORT" \
        caddy:${CADDY_VERSION}-alpine \
        caddy validate --config /etc/caddy/Caddyfile 2>&1; then
        echo -e "${GREEN}✅ Caddyfile is valid${NC}"
        return 0
    else
        echo -e "${RED}❌ Invalid Caddyfile configuration${NC}"
        echo -e "${YELLOW}💡 Check syntax: sudo $APP_NAME edit${NC}"
        return 1
    fi
}

show_current_template_info() {
    echo -e "${WHITE}📄 Current Template Information${NC}"
    echo -e "${GRAY}$(printf '─%.0s' $(seq 1 35))${NC}"
    echo
    
    if [ ! -d "$HTML_DIR" ] || [ ! "$(ls -A "$HTML_DIR" 2>/dev/null)" ]; then
        echo -e "${GRAY}   No template installed${NC}"
        return
    fi
    
    # Проверить наличие основных файлов
    if [ -f "$HTML_DIR/index.html" ]; then
        local title=$(grep -o '<title>[^<]*</title>' "$HTML_DIR/index.html" 2>/dev/null | sed 's/<title>\|<\/title>//g' | head -1)
        local meta_comment=$(grep -o '<!-- [a-f0-9]\{16\} -->' "$HTML_DIR/index.html" 2>/dev/null | head -1)
        local file_count=$(find "$HTML_DIR" -type f | wc -l)
        local total_size=$(du -sh "$HTML_DIR" 2>/dev/null | cut -f1)
        
        echo -e "${WHITE}   Title:${NC} ${GRAY}${title:-"Unknown"}${NC}"
        echo -e "${WHITE}   Files:${NC} ${GRAY}$file_count${NC}"
        echo -e "${WHITE}   Size:${NC} ${GRAY}$total_size${NC}"
        echo -e "${WHITE}   Path:${NC} ${GRAY}$HTML_DIR${NC}"
        
        if [ -n "$meta_comment" ]; then
            echo -e "${WHITE}   ID:${NC} ${GRAY}$meta_comment${NC}"
        fi
        
        # Показать последнее изменение
        local last_modified=$(stat -c %y "$HTML_DIR/index.html" 2>/dev/null | cut -d' ' -f1)
        if [ -n "$last_modified" ]; then
            echo -e "${WHITE}   Modified:${NC} ${GRAY}$last_modified${NC}"
        fi
    else
        echo -e "${GRAY}   Custom or unknown template${NC}"
        echo -e "${WHITE}   Path:${NC} ${GRAY}$HTML_DIR${NC}"
    fi
    echo
}

download_template() {
    local template_type="$1"
    local template_folder=""
    local template_name=""
    
    # Определяем папку для скачивания в зависимости от выбранного шаблона
    case "$template_type" in
        "1"|"10gag")
            template_folder="10gag"
            template_name="10gag - Сайт мемов"
            ;;
        "2"|"converter")
            template_folder="converter"
            template_name="Converter - Видеостудия-конвертер"
            ;;
        "3"|"convertit")
            template_folder="convertit"
            template_name="Convertit - Конвертер файлов"
            ;;
        "4"|"downloader")
            template_folder="downloader"
            template_name="Downloader - Даунлоадер"
            ;;
        "5"|"filecloud")
            template_folder="filecloud"
            template_name="FileCloud - Облачное хранилище"
            ;;
        "6"|"games-site")
            template_folder="games-site"
            template_name="Games-site - Ретро игровой портал"
            ;;
        "7"|"modmanager")
            template_folder="modmanager"
            template_name="ModManager - Мод-менеджер для игр"
            ;;
        "8"|"speedtest")
            template_folder="speedtest"
            template_name="SpeedTest - Спидтест"
            ;;
        "9"|"youtube")
            template_folder="YouTube"
            template_name="YouTube - Видеохостинг с капчей"
            ;;
        "10"|"503")
            template_folder="503-1"
            template_name="503 Error - Страница ошибки 503 - вариант 1"
            ;;
        "11"|"503")
            template_folder="503-2"
            template_name="503 Error - Страница ошибки 503 - вариант 2"
        ;;
        *)
            echo -e "${RED}❌ Unknown template type: $template_type${NC}"
            return 1
            ;;
    esac
    
    echo -e "${WHITE}🎨 Downloading Template: $template_name${NC}"
    echo -e "${GRAY}$(printf '─%.0s' $(seq 1 50))${NC}"
    echo
    
    # Создаем директорию
    mkdir -p "$HTML_DIR"
    rm -rf "$HTML_DIR"/*
    cd "$HTML_DIR"
    
    # Попробуем сначала через git (если доступен)
    if command -v git >/dev/null 2>&1; then
        echo -e "${WHITE}📦 Using Git for download...${NC}"
        
        # Создаем временную директорию
        local temp_dir="/tmp/selfsteal-template-$$"
        mkdir -p "$temp_dir"
        
        # Клонируем только нужную папку через sparse-checkout
        if git clone --filter=blob:none --sparse "https://github.com/DigneZzZ/remnawave-scripts.git" "$temp_dir" 2>/dev/null; then
            cd "$temp_dir"
            git sparse-checkout set "sni-templates/$template_folder" 2>/dev/null
            
            # Копируем файлы
            local source_path="$temp_dir/sni-templates/$template_folder"
            if [ -d "$source_path" ]; then
                if cp -r "$source_path"/* "$HTML_DIR/" 2>/dev/null; then
                    local files_copied=$(find "$HTML_DIR" -type f | wc -l)
                    echo -e "${GREEN}✅ Template files copied: $files_copied files${NC}"
                    
                    # Очистка
                    rm -rf "$temp_dir"
                    
                    # Устанавливаем правильные права доступа
                    setup_file_permissions
                    
                    show_download_summary "$files_copied" "$template_name"
                    return 0
                else
                    echo -e "${YELLOW}⚠️  Git method failed, trying wget...${NC}"
                fi
            else
                echo -e "${YELLOW}⚠️  Template not found in repository, trying wget...${NC}"
            fi
            
            # Очистка в случае неудачи
            rm -rf "$temp_dir"
        else
            echo -e "${YELLOW}⚠️  Git clone failed, trying wget...${NC}"
        fi
    fi
    
    # Fallback: используем wget для рекурсивного скачивания
    if command -v wget >/dev/null 2>&1; then
        echo -e "${WHITE}📦 Using wget for recursive download...${NC}"
        
        local base_url="https://raw.githubusercontent.com/DigneZzZ/remnawave-scripts/main/sni-templates/$template_folder"
        
        # Получаем структуру папки через GitHub API
        local api_url="https://api.github.com/repos/DigneZzZ/remnawave-scripts/git/trees/main?recursive=1"
        local tree_data
        tree_data=$(curl -s "$api_url" 2>/dev/null)
        
        if [ -n "$tree_data" ] && echo "$tree_data" | grep -q '"path"'; then
            echo -e "${GREEN}✅ Repository structure retrieved${NC}"
            echo -e "${WHITE}📥 Downloading files...${NC}"
            
            # Извлекаем пути файлов для нашего шаблона
            local template_files
            template_files=$(echo "$tree_data" | grep -o "\"path\":[^,]*" | sed 's/"path":"//' | sed 's/"//' | grep "^sni-templates/$template_folder/")
            
            local files_downloaded=0
            local failed_downloads=0
            
            if [ -n "$template_files" ]; then
                while IFS= read -r file_path; do
                    if [ -n "$file_path" ]; then
                        # Получаем относительный путь (убираем sni-templates/$template_folder/)
                        local relative_path="${file_path#sni-templates/$template_folder/}"
                        local file_url="https://raw.githubusercontent.com/DigneZzZ/remnawave-scripts/main/$file_path"
                        
                        # Создаем директорию если нужно
                        local file_dir=$(dirname "$relative_path")
                        if [ "$file_dir" != "." ]; then
                            mkdir -p "$file_dir"
                        fi
                        
                        echo -e "${GRAY}   Downloading $relative_path...${NC}"
                        
                        if wget -q "$file_url" -O "$relative_path" 2>/dev/null; then
                            echo -e "${GREEN}   ✅ $relative_path${NC}"
                            ((files_downloaded++))
                        else
                            echo -e "${YELLOW}   ⚠️  $relative_path (failed)${NC}"
                            ((failed_downloads++))
                        fi
                    fi
                done <<< "$template_files"
                
                if [ $files_downloaded -gt 0 ]; then
                    setup_file_permissions
                    show_download_summary "$files_downloaded" "$template_name"
                    return 0
                fi
            else
                echo -e "${YELLOW}⚠️  No files found for template, trying curl fallback...${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️  Could not get repository structure, trying curl fallback...${NC}"
        fi
    fi
    
    # Последний fallback: curl с предопределенным списком файлов
    echo -e "${WHITE}📦 Using curl fallback method...${NC}"
    
    # Базовые файлы, которые должны быть в большинстве шаблонов
    local common_files=("index.html" "favicon.ico" "favicon.svg" "site.webmanifest" "apple-touch-icon.png" "favicon-96x96.png" "web-app-manifest-192x192.png" "web-app-manifest-512x512.png")
    local asset_files=("assets/style.css" "assets/script.js" "assets/main.js")
    
    local base_url="https://raw.githubusercontent.com/DigneZzZ/remnawave-scripts/main/sni-templates/$template_folder"
    local files_downloaded=0
    local failed_downloads=0
    
    echo -e "${WHITE}📥 Downloading common files...${NC}"
    
    # Скачиваем основные файлы
    for file in "${common_files[@]}"; do
        local url="$base_url/$file"
        echo -e "${GRAY}   Downloading $file...${NC}"
        
        if curl -fsSL "$url" -o "$file" 2>/dev/null; then
            echo -e "${GREEN}   ✅ $file${NC}"
            ((files_downloaded++))
        else
            echo -e "${YELLOW}   ⚠️  $file (optional file not found)${NC}"
            ((failed_downloads++))
        fi
    done
    
    # Скачиваем файлы assets
    mkdir -p assets
    echo -e "${WHITE}📁 Downloading assets...${NC}"
    
    for file in "${asset_files[@]}"; do
        local url="$base_url/$file"
        local filename=$(basename "$file")
        echo -e "${GRAY}   Downloading assets/$filename...${NC}"
        
        if curl -fsSL "$url" -o "assets/$filename" 2>/dev/null; then
            echo -e "${GREEN}   ✅ assets/$filename${NC}"
            ((files_downloaded++))
        else
            echo -e "${YELLOW}   ⚠️  assets/$filename (optional file not found)${NC}"
            ((failed_downloads++))
        fi
    done
    
    if [ $files_downloaded -gt 0 ]; then
        setup_file_permissions
        show_download_summary "$files_downloaded" "$template_name"
        return 0
    else
        echo -e "${RED}❌ Failed to download any files${NC}"
        echo -e "${YELLOW}⚠️  Creating fallback template...${NC}"
        create_fallback_html "$template_name"
        return 1
    fi
}

# Функция для установки правильных прав доступа
setup_file_permissions() {
    echo -e "${WHITE}🔒 Setting up file permissions...${NC}"
    
    # Устанавливаем права на файлы
    chmod -R 644 "$HTML_DIR"/* 2>/dev/null || true
    
    # Устанавливаем права на директории
    find "$HTML_DIR" -type d -exec chmod 755 {} \; 2>/dev/null || true
    
    # Устанавливаем владельца (если возможно)
    chown -R www-data:www-data "$HTML_DIR" 2>/dev/null || true
    
    echo -e "${GREEN}✅ File permissions configured${NC}"
}

# Функция для показа итогов скачивания
show_download_summary() {
    local files_count="$1"
    local template_name="$2"
    
    echo
    echo -e "${WHITE}📊 Download Summary:${NC}"
    echo -e "${GRAY}$(printf '─%.0s' $(seq 1 25))${NC}"
    printf "   ${WHITE}%-20s${NC} ${GREEN}%d${NC}\n" "Files downloaded:" "$files_count"
    printf "   ${WHITE}%-20s${NC} ${GRAY}%s${NC}\n" "Template:" "$template_name"
    printf "   ${WHITE}%-20s${NC} ${GRAY}%s${NC}\n" "Location:" "$HTML_DIR"
    
    # Показать размер
    local total_size=$(du -sh "$HTML_DIR" 2>/dev/null | cut -f1 || echo "Unknown")
    printf "   ${WHITE}%-20s${NC} ${GRAY}%s${NC}\n" "Total size:" "$total_size"
    
    echo
    echo -e "${GREEN}✅ Template downloaded successfully${NC}"
}

# Fallback функция для создания базового HTML если скачивание не удалось
create_fallback_html() {
    local template_name="$1"
    
    cat > "index.html" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$template_name</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
        }
        .container {
            text-align: center;
            max-width: 600px;
            padding: 2rem;
        }
        h1 {
            font-size: 3rem;
            margin-bottom: 1rem;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        p {
            font-size: 1.2rem;
            opacity: 0.9;
            margin-bottom: 2rem;
        }
        .status {
            background: rgba(255,255,255,0.1);
            padding: 1rem 2rem;
            border-radius: 10px;
            backdrop-filter: blur(10px);
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Service Ready</h1>
        <p>$template_name template is now active</p>
        <div class="status">
            <p>✅ System Online</p>
        </div>
    </div>
</body>
</html>
EOF
}

# Create default HTML content for initial installation
create_default_html() {
    echo -e "${WHITE}🌐 Creating Default Website${NC}"
    
    cat > "$HTML_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 40px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container {
            background: white;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.3);
            text-align: center;
            max-width: 500px;
        }
        h1 {
            color: #333;
            margin-bottom: 20px;
        }
        p {
            color: #666;
            line-height: 1.6;
            margin-bottom: 15px;
        }
        .status {
            display: inline-block;
            background: #4CAF50;
            color: white;
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 14px;
            margin-top: 20px;
        }
        .info {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            margin-top: 20px;
            border-left: 4px solid #667eea;
        }
        .info h3 {
            color: #333;
            margin-bottom: 10px;
        }
        .command {
            background: #2d3748;
            color: #e2e8f0;
            padding: 10px;
            border-radius: 4px;
            font-family: monospace;
            margin: 10px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🌐 Caddy for Reality Selfsteal</h1>
        <p>Caddy server is running correctly and ready to serve your content.</p>
        <div class="status">✅ Service Active</div>
        <div class="info">
            <h3>🎨 Ready for Templates</h3>
            <p>Use the template manager to install website templates:</p>
            <div class="command">sudo selfsteal template</div>
            <p>Choose from 10 pre-built AI-generated templates including meme sites, downloaders, file converters, and more!</p>
        </div>
    </div>
</body>
</html>
EOF

    # Create 404 page
    cat > "$HTML_DIR/404.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>404 - Page Not Found</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 40px;
            background: #f5f5f5;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container {
            background: white;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
            text-align: center;
            max-width: 500px;
        }
        h1 {
            color: #e74c3c;
            font-size: 4rem;
            margin-bottom: 20px;
        }
        h2 {
            color: #333;
            margin-bottom: 15px;
        }
        p {
            color: #666;
            line-height: 1.6;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>404</h1>        <h2>Page Not Found</h2>
        <p>The page you are looking for does not exist.</p>
    </div>
</body>
</html>
EOF
    echo -e "${GREEN}✅ Default HTML content created${NC}"
}

# Function to show template options
show_template_options() {
    echo -e "${WHITE}🎨 Website Template Options${NC}"
    echo -e "${GRAY}$(printf '─%.0s' $(seq 1 35))${NC}"
    echo
    echo -e "${WHITE}Select template type:${NC}"
    echo -e "   ${WHITE}1)${NC} ${CYAN}😂 10gag - Сайт мемов${NC}"
    echo -e "   ${WHITE}2)${NC} ${CYAN}🎬 Converter - Видеостудия-конвертер${NC}"
    echo -e "   ${WHITE}3)${NC} ${CYAN}📁 Convertit - Конвертер файлов${NC}"
    echo -e "   ${WHITE}4)${NC} ${CYAN}⬇️ Downloader - Даунлоадер${NC}"
    echo -e "   ${WHITE}5)${NC} ${CYAN}☁️ FileCloud - Облачное хранилище${NC}"
    echo -e "   ${WHITE}6)${NC} ${CYAN}🎮 Games-site - Ретро игровой портал${NC}"
    echo -e "   ${WHITE}7)${NC} ${CYAN}🛠️ ModManager - Мод-менеджер для игр${NC}"
    echo -e "   ${WHITE}8)${NC} ${CYAN}🚀 SpeedTest - Спидтест${NC}"
    echo -e "   ${WHITE}9)${NC} ${CYAN}📺 YouTube - Видеохостинг с капчей${NC}"
    echo -e "   ${WHITE}10)${NC} ${CYAN}⚠️ 503 Error - Страница ошибки 503 v1${NC}"
    echo -e "   ${WHITE}11)${NC} ${CYAN}⚠️ 503 Error - Страница ошибки 503 v2${NC}"
    echo
    echo -e "   ${WHITE}v)${NC} ${GRAY}📄 View Current Template${NC}"
    echo -e "   ${WHITE}k)${NC} ${GRAY}📝 Keep Current Template${NC}"
    echo
    echo -e "   ${GRAY}0)${NC} ${GRAY}⬅️  Cancel${NC}"
    echo
}


# Template management command
template_command() {
    check_running_as_root
    if ! docker --version >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker is not available${NC}"
        return 1
    fi

    if [ ! -d "$APP_DIR" ]; then
        echo -e "${RED}❌ Caddy is not installed. Run 'sudo $APP_NAME install' first.${NC}"
        return 1
    fi
    

    local running_services=$(cd "$APP_DIR" && docker compose ps -q 2>/dev/null | wc -l || echo "0")
    if [ "$running_services" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Caddy is currently running${NC}"
        echo -e "${GRAY}   Template changes will be applied immediately${NC}"
        echo
        read -p "Continue with template download? [Y/n]: " -r continue_template
        if [[ $continue_template =~ ^[Nn]$ ]]; then
            return 0
        fi
    fi
    
    
    while true; do
        clear
        show_template_options
        
        read -p "Select template option [0-11, v, k]: " choice
        
        case "$choice" in
            1)
                echo
                if download_template "1"; then
                    echo -e "${GREEN}🎉 10gag template downloaded successfully!${NC}"
                    echo
                    local running_services=$(cd "$APP_DIR" && docker compose ps -q 2>/dev/null | wc -l || echo "0")
                    if [ "$running_services" -gt 0 ]; then
                        read -p "Restart Caddy to apply changes? [Y/n]: " -r restart_caddy
                        if [[ ! $restart_caddy =~ ^[Nn]$ ]]; then
                            echo -e "${YELLOW}🔄 Restarting Caddy...${NC}"
                            cd "$APP_DIR" && docker compose restart
                            echo -e "${GREEN}✅ Caddy restarted${NC}"
                        fi
                    fi
                else
                    echo -e "${RED}❌ Failed to download 10gag template${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            2)
                echo
                if download_template "2"; then
                    echo -e "${GREEN}🎉 Converter template downloaded successfully!${NC}"
                    echo
                    local running_services=$(cd "$APP_DIR" && docker compose ps -q 2>/dev/null | wc -l || echo "0")
                    if [ "$running_services" -gt 0 ]; then
                        read -p "Restart Caddy to apply changes? [Y/n]: " -r restart_caddy
                        if [[ ! $restart_caddy =~ ^[Nn]$ ]]; then
                            echo -e "${YELLOW}🔄 Restarting Caddy...${NC}"
                            cd "$APP_DIR" && docker compose restart
                            echo -e "${GREEN}✅ Caddy restarted${NC}"
                        fi
                    fi
                else
                    echo -e "${RED}❌ Failed to download converter template${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            3)
                echo
                if download_template "3"; then
                    echo -e "${GREEN}🎉 Convertit template downloaded successfully!${NC}"
                    echo
                    local running_services=$(cd "$APP_DIR" && docker compose ps -q 2>/dev/null | wc -l || echo "0")
                    if [ "$running_services" -gt 0 ]; then
                        read -p "Restart Caddy to apply changes? [Y/n]: " -r restart_caddy
                        if [[ ! $restart_caddy =~ ^[Nn]$ ]]; then
                            echo -e "${YELLOW}🔄 Restarting Caddy...${NC}"
                            cd "$APP_DIR" && docker compose restart
                            echo -e "${GREEN}✅ Caddy restarted${NC}"
                        fi
                    fi
                else
                    echo -e "${RED}❌ Failed to download convertit template${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            4)
                echo
                if download_template "4"; then
                    echo -e "${GREEN}🎉 Downloader template downloaded successfully!${NC}"
                    echo
                    local running_services=$(cd "$APP_DIR" && docker compose ps -q 2>/dev/null | wc -l || echo "0")
                    if [ "$running_services" -gt 0 ]; then
                        read -p "Restart Caddy to apply changes? [Y/n]: " -r restart_caddy
                        if [[ ! $restart_caddy =~ ^[Nn]$ ]]; then
                            echo -e "${YELLOW}🔄 Restarting Caddy...${NC}"
                            cd "$APP_DIR" && docker compose restart
                            echo -e "${GREEN}✅ Caddy restarted${NC}"
                        fi
                    fi
                else
                    echo -e "${RED}❌ Failed to download downloader template${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            5)
                echo
                if download_template "5"; then
                    echo -e "${GREEN}🎉 FileCloud template downloaded successfully!${NC}"
                    echo
                    local running_services=$(cd "$APP_DIR" && docker compose ps -q 2>/dev/null | wc -l || echo "0")
                    if [ "$running_services" -gt 0 ]; then
                        read -p "Restart Caddy to apply changes? [Y/n]: " -r restart_caddy
                        if [[ ! $restart_caddy =~ ^[Nn]$ ]]; then
                            echo -e "${YELLOW}🔄 Restarting Caddy...${NC}"
                            cd "$APP_DIR" && docker compose restart
                            echo -e "${GREEN}✅ Caddy restarted${NC}"
                        fi
                    fi
                else
                    echo -e "${RED}❌ Failed to download filecloud template${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            6)
                echo
                if download_template "6"; then
                    echo -e "${GREEN}🎉 Games-site template downloaded successfully!${NC}"
                    echo
                    local running_services=$(cd "$APP_DIR" && docker compose ps -q 2>/dev/null | wc -l || echo "0")
                    if [ "$running_services" -gt 0 ]; then
                        read -p "Restart Caddy to apply changes? [Y/n]: " -r restart_caddy
                        if [[ ! $restart_caddy =~ ^[Nn]$ ]]; then
                            echo -e "${YELLOW}🔄 Restarting Caddy...${NC}"
                            cd "$APP_DIR" && docker compose restart
                            echo -e "${GREEN}✅ Caddy restarted${NC}"
                        fi
                    fi
                else
                    echo -e "${RED}❌ Failed to download games-site template${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            7)
                echo
                if download_template "7"; then
                    echo -e "${GREEN}🎉 ModManager template downloaded successfully!${NC}"
                    echo
                    local running_services=$(cd "$APP_DIR" && docker compose ps -q 2>/dev/null | wc -l || echo "0")
                    if [ "$running_services" -gt 0 ]; then
                        read -p "Restart Caddy to apply changes? [Y/n]: " -r restart_caddy
                        if [[ ! $restart_caddy =~ ^[Nn]$ ]]; then
                            echo -e "${YELLOW}🔄 Restarting Caddy...${NC}"
                            cd "$APP_DIR" && docker compose restart
                            echo -e "${GREEN}✅ Caddy restarted${NC}"
                        fi
                    fi
                else
                    echo -e "${RED}❌ Failed to download modmanager template${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            8)
                echo
                if download_template "8"; then
                    echo -e "${GREEN}🎉 SpeedTest template downloaded successfully!${NC}"
                    echo
                    local running_services=$(cd "$APP_DIR" && docker compose ps -q 2>/dev/null | wc -l || echo "0")
                    if [ "$running_services" -gt 0 ]; then
                        read -p "Restart Caddy to apply changes? [Y/n]: " -r restart_caddy
                        if [[ ! $restart_caddy =~ ^[Nn]$ ]]; then
                            echo -e "${YELLOW}🔄 Restarting Caddy...${NC}"
                            cd "$APP_DIR" && docker compose restart
                            echo -e "${GREEN}✅ Caddy restarted${NC}"
                        fi
                    fi
                else
                    echo -e "${RED}❌ Failed to download speedtest template${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            9)
                echo
                if download_template "9"; then
                    echo -e "${GREEN}🎉 YouTube template downloaded successfully!${NC}"
                    echo
                    local running_services=$(cd "$APP_DIR" && docker compose ps -q 2>/dev/null | wc -l || echo "0")
                    if [ "$running_services" -gt 0 ]; then
                        read -p "Restart Caddy to apply changes? [Y/n]: " -r restart_caddy
                        if [[ ! $restart_caddy =~ ^[Nn]$ ]]; then
                            echo -e "${YELLOW}🔄 Restarting Caddy...${NC}"
                            cd "$APP_DIR" && docker compose restart
                            echo -e "${GREEN}✅ Caddy restarted${NC}"
                        fi
                    fi
                else
                    echo -e "${RED}❌ Failed to download youtube template${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            10)
                echo
                if download_template "10"; then
                    echo -e "${GREEN}🎉 503 Error template downloaded successfully!${NC}"
                    echo
                    local running_services=$(cd "$APP_DIR" && docker compose ps -q 2>/dev/null | wc -l || echo "0")
                    if [ "$running_services" -gt 0 ]; then
                        read -p "Restart Caddy to apply changes? [Y/n]: " -r restart_caddy
                        if [[ ! $restart_caddy =~ ^[Nn]$ ]]; then
                            echo -e "${YELLOW}🔄 Restarting Caddy...${NC}"
                            cd "$APP_DIR" && docker compose restart
                            echo -e "${GREEN}✅ Caddy restarted${NC}"
                        fi
                    fi
                else
                    echo -e "${RED}❌ Failed to download 503 error template${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            11)
                echo
                if download_template "11"; then
                    echo -e "${GREEN}🎉 503 Error v2 template downloaded successfully!${NC}"
                    echo
                    local running_services=$(cd "$APP_DIR" && docker compose ps -q 2>/dev/null | wc -l || echo "0")
                    if [ "$running_services" -gt 0 ]; then
                        read -p "Restart Caddy to apply changes? [Y/n]: " -r restart_caddy
                        if [[ ! $restart_caddy =~ ^[Nn]$ ]]; then
                            echo -e "${YELLOW}🔄 Restarting Caddy...${NC}"
                            cd "$APP_DIR" && docker compose restart
                            echo -e "${GREEN}✅ Caddy restarted${NC}"
                        fi
                    fi
                else
                    echo -e "${RED}❌ Failed to download 503 error v2 template${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            v|V)
                echo
                show_current_template_info
                read -p "Press Enter to continue..."
                ;;
            k|K)
                echo -e "${GRAY}Current template preserved${NC}"
                read -p "Press Enter to continue..."
                ;;
            0)
                return 0
                ;;
            *)
                echo -e "${RED}❌ Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}




install_management_script() {
    echo -e "${WHITE}🔧 Installing Management Script${NC}"
    
    # Определить путь к скрипту
    local script_path
    local target_path="/usr/local/bin/$APP_NAME"
    
    # Проверим, не является ли источник тем же файлом, что и целевой
    if [ -f "$0" ] && [ "$0" != "bash" ] && [ "$0" != "@" ]; then
        # Получаем абсолютные пути для сравнения
        local source_real_path=$(realpath "$0" 2>/dev/null || readlink -f "$0" 2>/dev/null || echo "$0")
        local target_real_path=$(realpath "$target_path" 2>/dev/null || readlink -f "$target_path" 2>/dev/null || echo "$target_path")
        
        # Если это один и тот же файл, пропускаем копирование
        if [ "$source_real_path" = "$target_real_path" ]; then
            echo -e "${GREEN}✅ Management script already installed: $target_path${NC}"
            return 0
        fi
        
        script_path="$0"
    else
        # Попытаться найти скрипт в /tmp или скачать заново
        local temp_script="/tmp/selfsteal-install.sh"
        if curl -fsSL "$UPDATE_URL" -o "$temp_script" 2>/dev/null; then
            script_path="$temp_script"
            echo -e "${GRAY}📥 Downloaded script from remote source${NC}"
        else
            echo -e "${YELLOW}⚠️  Could not install management script automatically${NC}"
            echo -e "${GRAY}   You can download it manually from: $UPDATE_URL${NC}"
            return 1
        fi
    fi
    
    # Установить скрипт только если это разные файлы
    if [ -f "$script_path" ]; then
        if cp "$script_path" "$target_path" 2>/dev/null; then
            chmod +x "$target_path"
            echo -e "${GREEN}✅ Management script installed: $target_path${NC}"
        else
            echo -e "${YELLOW}⚠️  Management script installation skipped (already exists)${NC}"
        fi
        
        # Очистить временный файл если использовался
        if [ "$script_path" = "/tmp/selfsteal-install.sh" ]; then
            rm -f "$script_path"
        fi
    else
        echo -e "${RED}❌ Failed to install management script${NC}"
        return 1
    fi
}
# Service management functions
up_command() {
    check_running_as_root
    
    if [ ! -f "$APP_DIR/docker-compose.yml" ]; then
        echo -e "${RED}❌ Caddy is not installed. Run 'sudo $APP_NAME install' first.${NC}"
        return 1
    fi
    
    echo -e "${WHITE}🚀 Starting Caddy Services${NC}"
    cd "$APP_DIR"
    
    if docker compose up -d; then
        echo -e "${GREEN}✅ Caddy services started successfully${NC}"
    else
        echo -e "${RED}❌ Failed to start Caddy services${NC}"
        return 1
    fi
}

down_command() {
    check_running_as_root
    
    if [ ! -f "$APP_DIR/docker-compose.yml" ]; then
        echo -e "${YELLOW}⚠️  Caddy is not installed${NC}"
        return 0
    fi
    
    echo -e "${WHITE}🛑 Stopping Caddy Services${NC}"
    cd "$APP_DIR"
    
    if docker compose down; then
        echo -e "${GREEN}✅ Caddy services stopped successfully${NC}"
    else
        echo -e "${RED}❌ Failed to stop Caddy services${NC}"
        return 1
    fi
}

restart_command() {
    check_running_as_root
    echo -e "${YELLOW}⚠️  Validate Caddyfile after editing? [Y/n]:${NC}"
    read -p "" validate_choice
    if [[ ! $validate_choice =~ ^[Nn]$ ]]; then
        validate_caddyfile
    fi
    echo -e "${WHITE}🔄 Restarting Caddy Services${NC}"
    down_command
    sleep 2
    up_command
}

status_command() {
    if [ ! -d "$APP_DIR" ]; then
        echo -e "${RED}❌ Caddy not installed${NC}"
        return 1
    fi

    echo -e "${WHITE}📊 Caddy Service Status${NC}"
    echo -e "${GRAY}$(printf '─%.0s' $(seq 1 30))${NC}"
    echo

    cd "$APP_DIR"
    
    # Получаем статус контейнера
    local container_status=$(docker compose ps --format "table {{.Name}}\t{{.State}}\t{{.Status}}" 2>/dev/null)
    local running_count=$(docker compose ps -q --status running 2>/dev/null | wc -l)
    local total_count=$(docker compose ps -q 2>/dev/null | wc -l)
    
    # Проверяем реальный статус
    local actual_status=$(docker compose ps --format "{{.State}}" 2>/dev/null | head -1)
    
    if [ "$actual_status" = "running" ]; then
        echo -e "${GREEN}✅ Status: Running${NC}"
        echo -e "${GREEN}✅ All services are running ($running_count/$total_count)${NC}"
    elif [ "$actual_status" = "restarting" ]; then
        echo -e "${YELLOW}⚠️  Status: Restarting (Error)${NC}"
        echo -e "${RED}❌ Service is failing and restarting ($running_count/$total_count)${NC}"
        echo -e "${YELLOW}🔧 Action needed: Check logs for errors${NC}"
    elif [ -n "$actual_status" ]; then
        echo -e "${RED}❌ Status: $actual_status${NC}"
        echo -e "${RED}❌ Services not running ($running_count/$total_count)${NC}"
    else
        echo -e "${RED}❌ Status: Not running${NC}"
        echo -e "${RED}❌ No services found${NC}"
    fi

    echo
    echo -e "${WHITE}📋 Container Details:${NC}"
    if [ -n "$container_status" ]; then
        echo "$container_status"
    else
        echo -e "${GRAY}No containers found${NC}"
    fi

    # Показать рекомендации при проблемах
    if [ "$actual_status" = "restarting" ]; then
        echo
        echo -e "${YELLOW}🔧 Troubleshooting:${NC}"
        echo -e "${GRAY}   1. Check logs: selfsteal logs${NC}"
        echo -e "${GRAY}   2. Validate config: selfsteal edit${NC}"
        echo -e "${GRAY}   3. Restart services: selfsteal restart${NC}"
    fi
    
    # Show configuration summary
    if [ -f "$APP_DIR/.env" ]; then
        echo
        echo -e "${WHITE}⚙️  Configuration:${NC}"
        local domain=$(grep "SELF_STEAL_DOMAIN=" "$APP_DIR/.env" | cut -d'=' -f2)
        local port=$(grep "SELF_STEAL_PORT=" "$APP_DIR/.env" | cut -d'=' -f2)
        
        printf "   ${WHITE}%-15s${NC} ${GRAY}%s${NC}\n" "Domain:" "$domain"
        printf "   ${WHITE}%-15s${NC} ${GRAY}%s${NC}\n" "HTTPS Port:" "$port"
        printf "   ${WHITE}%-15s${NC} ${GRAY}%s${NC}\n" "HTML Path:" "$HTML_DIR"
    fi
    printf "   ${WHITE}%-15s${NC} ${GRAY}%s${NC}\n" "Script Version:" "v$SCRIPT_VERSION"
}

logs_command() {
    if [ ! -f "$APP_DIR/docker-compose.yml" ]; then
        echo -e "${RED}❌ Caddy is not installed${NC}"
        return 1
    fi
    
    echo -e "${WHITE}📝 Caddy Logs${NC}"
    echo -e "${GRAY}Press Ctrl+C to exit${NC}"
    echo
    
    cd "$APP_DIR"
    docker compose logs -f
}


# Clean logs function
clean_logs_command() {
    check_running_as_root
    
    if [ ! -d "$APP_DIR" ]; then
        echo -e "${RED}❌ Caddy is not installed${NC}"
        return 1
    fi
    
    echo -e "${WHITE}🧹 Cleaning Logs${NC}"
    echo -e "${GRAY}$(printf '─%.0s' $(seq 1 25))${NC}"
    echo
    
    # Show current log sizes
    echo -e "${WHITE}📊 Current log sizes:${NC}"
    
    # Docker logs
    local docker_logs_size
    docker_logs_size=$(docker logs $CONTAINER_NAME 2>&1 | wc -c 2>/dev/null || echo "0")
    docker_logs_size=$((docker_logs_size / 1024))
    echo -e "${GRAY}   Docker logs: ${WHITE}${docker_logs_size}KB${NC}"
    
    # Caddy access logs
    local caddy_logs_path="$APP_DIR/caddy_data/_logs"
    if [ -d "$caddy_logs_path" ]; then
        local caddy_logs_size
        caddy_logs_size=$(du -sk "$caddy_logs_path" 2>/dev/null | cut -f1 || echo "0")
        echo -e "${GRAY}   Caddy logs: ${WHITE}${caddy_logs_size}KB${NC}"
    fi
    
    echo
    read -p "Clean all logs? [y/N]: " -r clean_choice
    
    if [[ $clean_choice =~ ^[Yy]$ ]]; then
        echo -e "${WHITE}🧹 Cleaning logs...${NC}"
        
        # Clean Docker logs by recreating container
        if docker ps -q -f name=$CONTAINER_NAME >/dev/null 2>&1; then
            echo -e "${GRAY}   Stopping Caddy...${NC}"
            cd "$APP_DIR" && docker compose stop
            
            echo -e "${GRAY}   Removing container to clear logs...${NC}"
            docker rm $CONTAINER_NAME 2>/dev/null || true
            
            echo -e "${GRAY}   Starting Caddy...${NC}"
            cd "$APP_DIR" && docker compose up -d
        fi
        
        # Clean Caddy internal logs
        if [ -d "$caddy_logs_path" ]; then
            echo -e "${GRAY}   Cleaning Caddy access logs...${NC}"
            rm -rf "$caddy_logs_path"/* 2>/dev/null || true
        fi
        
        echo -e "${GREEN}✅ Logs cleaned successfully${NC}"
    else
        echo -e "${GRAY}Log cleanup cancelled${NC}"
    fi
}

# Show log sizes function
logs_size_command() {
    check_running_as_root
    
    if [ ! -d "$APP_DIR" ]; then
        echo -e "${RED}❌ Caddy is not installed${NC}"
        return 1
    fi
    
    echo -e "${WHITE}📊 Log Sizes${NC}"
    echo -e "${GRAY}$(printf '─%.0s' $(seq 1 25))${NC}"
    echo
    
    # Docker logs
    local docker_logs_size
    if docker ps -q -f name=$CONTAINER_NAME >/dev/null 2>&1; then
        docker_logs_size=$(docker logs $CONTAINER_NAME 2>&1 | wc -c 2>/dev/null || echo "0")
        docker_logs_size=$((docker_logs_size / 1024))
        echo -e "${WHITE}📋 Docker logs:${NC} ${GRAY}${docker_logs_size}KB${NC}"
    else
        echo -e "${WHITE}📋 Docker logs:${NC} ${GRAY}Container not running${NC}"
    fi
    
    # Caddy access logs
    local caddy_data_dir
    caddy_data_dir=$(cd "$APP_DIR" && docker volume inspect "${APP_DIR##*/}_${VOLUME_PREFIX}_data" --format '{{.Mountpoint}}' 2>/dev/null || echo "")
    
    if [ -n "$caddy_data_dir" ] && [ -d "$caddy_data_dir" ]; then
        local access_log="$caddy_data_dir/access.log"
        if [ -f "$access_log" ]; then
            local access_log_size
            access_log_size=$(du -k "$access_log" 2>/dev/null | cut -f1 || echo "0")
            echo -e "${WHITE}📄 Access log:${NC} ${GRAY}${access_log_size}KB${NC}"
        else
            echo -e "${WHITE}📄 Access log:${NC} ${GRAY}Not found${NC}"
        fi
        
        # Check for rotated logs
        local rotated_logs
        rotated_logs=$(find "$caddy_data_dir" -name "access.log.*" 2>/dev/null | wc -l || echo "0")
        if [ "$rotated_logs" -gt 0 ]; then
            local rotated_size
            rotated_size=$(find "$caddy_data_dir" -name "access.log.*" -exec du -k {} \; 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
            echo -e "${WHITE}🔄 Rotated logs:${NC} ${GRAY}${rotated_size}KB (${rotated_logs} files)${NC}"
        fi
    else
        echo -e "${WHITE}📄 Caddy logs:${NC} ${GRAY}Volume not accessible${NC}"
    fi
    
    # Logs directory
    if [ -d "$APP_DIR/logs" ]; then
        local logs_dir_size
        logs_dir_size=$(du -sk "$APP_DIR/logs" 2>/dev/null | cut -f1 || echo "0")
        echo -e "${WHITE}📁 Logs directory:${NC} ${GRAY}${logs_dir_size}KB${NC}"
    fi
    
    echo
    echo -e "${GRAY}💡 Tip: Use 'sudo $APP_NAME clean-logs' to clean all logs${NC}"
    echo
}

stop_services() {
    if [ -f "$APP_DIR/docker-compose.yml" ]; then
        cd "$APP_DIR"
        docker compose down 2>/dev/null || true
    fi
}

uninstall_command() {
    check_running_as_root
    
    echo -e "${WHITE}🗑️  Caddy Uninstallation${NC}"
    echo -e "${GRAY}$(printf '─%.0s' $(seq 1 30))${NC}"
    echo
    
    if [ ! -d "$APP_DIR" ]; then
        echo -e "${YELLOW}⚠️  Caddy is not installed${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}⚠️  This will completely remove Caddy and all data!${NC}"
    echo
    read -p "Are you sure you want to continue? [y/N]: " -r confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${GRAY}Uninstallation cancelled${NC}"
        return 0
    fi
    
    echo
    echo -e "${WHITE}🛑 Stopping services...${NC}"
    stop_services
    
    echo -e "${WHITE}🗑️  Removing files...${NC}"
    rm -rf "$APP_DIR"
    
    echo -e "${WHITE}🗑️  Removing management script...${NC}"
    rm -f "/usr/local/bin/$APP_NAME"
    
    echo -e "${GREEN}✅ Caddy uninstalled successfully${NC}"
    echo
    echo -e "${GRAY}Note: HTML content in $HTML_DIR was preserved${NC}"
}

edit_command() {
    check_running_as_root
    
    if [ ! -d "$APP_DIR" ]; then
        echo -e "${RED}❌ Caddy is not installed${NC}"
        return 1
    fi
    
    echo -e "${WHITE}📝 Edit Configuration Files${NC}"
    echo -e "${GRAY}$(printf '─%.0s' $(seq 1 30))${NC}"
    echo
    
    echo -e "${WHITE}Select file to edit:${NC}"
    echo -e "   ${WHITE}1)${NC} ${GRAY}.env file (domain and port settings)${NC}"
    echo -e "   ${WHITE}2)${NC} ${GRAY}Caddyfile (Caddy configuration)${NC}"
    echo -e "   ${WHITE}3)${NC} ${GRAY}docker-compose.yml (Docker configuration)${NC}"
    echo -e "   ${WHITE}0)${NC} ${GRAY}Cancel${NC}"
    echo
    
    read -p "Select option [0-3]: " choice
    
    case "$choice" in
        1)
            ${EDITOR:-nano} "$APP_DIR/.env"
            echo -e "${YELLOW}⚠️  Restart Caddy to apply changes: sudo $APP_NAME restart${NC}"
            ;;
        2)
            ${EDITOR:-nano} "$APP_DIR/Caddyfile"
            echo -e "${YELLOW}⚠️  Validate Caddyfile after editing? [Y/n]:${NC}"
            read -p "" validate_choice
            if [[ ! $validate_choice =~ ^[Nn]$ ]]; then
                validate_caddyfile
            fi
            echo -e "${YELLOW}⚠️  Restart Caddy to apply changes: sudo $APP_NAME restart${NC}"
            ;;
        3)
            ${EDITOR:-nano} "$APP_DIR/docker-compose.yml"
            echo -e "${YELLOW}⚠️  Restart Caddy to apply changes: sudo $APP_NAME restart${NC}"
            ;;
        0)
            echo -e "${GRAY}Cancelled${NC}"
            ;;
        *)
            echo -e "${RED}❌ Invalid option${NC}"
            ;;
    esac
}




show_help() {
    echo -e "${WHITE}Caddy for Reality Selfsteal Management Script v$SCRIPT_VERSION${NC}"
    echo
    echo -e "${WHITE}Usage:${NC}"
    echo -e "  ${CYAN}$APP_NAME${NC} [${GRAY}command${NC}]"
    echo
    echo -e "${WHITE}Commands:${NC}"
    printf "   ${CYAN}%-12s${NC} %s\n" "install" "🚀 Install Caddy for Reality masking"
    printf "   ${CYAN}%-12s${NC} %s\n" "up" "▶️  Start Caddy services"
    printf "   ${CYAN}%-12s${NC} %s\n" "down" "⏹️  Stop Caddy services"
    printf "   ${CYAN}%-12s${NC} %s\n" "restart" "🔄 Restart Caddy services"
    printf "   ${CYAN}%-12s${NC} %s\n" "status" "📊 Show service status"
    printf "   ${CYAN}%-12s${NC} %s\n" "logs" "📝 Show service logs"
    printf "   ${CYAN}%-12s${NC} %s\n" "logs-size" "📊 Show log sizes"
    printf "   ${CYAN}%-12s${NC} %s\n" "clean-logs" "🧹 Clean all logs"
    printf "   ${CYAN}%-12s${NC} %s\n" "edit" "✏️  Edit configuration files"
    printf "   ${CYAN}%-12s${NC} %s\n" "uninstall" "🗑️  Remove Caddy installation"
    printf "   ${CYAN}%-12s${NC} %s\n" "template" "🎨 Manage website templates"
    printf "   ${CYAN}%-12s${NC} %s\n" "menu" "📋 Show interactive menu"
    printf "   ${CYAN}%-12s${NC} %s\n" "update" "🔄 Check for script updates"
    echo
    echo -e "${WHITE}Examples:${NC}"
    echo -e "  ${GRAY}sudo $APP_NAME install${NC}"
    echo -e "  ${GRAY}sudo $APP_NAME status${NC}"
    echo -e "  ${GRAY}sudo $APP_NAME logs${NC}"
    echo
    echo -e "${WHITE}For more information, visit:${NC}"
    echo -e "  ${BLUE}https://github.com/remnawave/${NC}"
}

check_for_updates() {
    echo -e "${WHITE}🔍 Checking for updates...${NC}"
    
    # Check if curl is available
    if ! command -v curl >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  curl not available, cannot check for updates${NC}"
        return 1
    fi
    
    # Get latest version from GitHub script
    echo -e "${WHITE}📝 Fetching latest script version...${NC}"
    local remote_script_version
    remote_script_version=$(curl -s "$UPDATE_URL" 2>/dev/null | grep "^SCRIPT_VERSION=" | cut -d'"' -f2)
    
    if [ -z "$remote_script_version" ]; then
        echo -e "${YELLOW}⚠️  Unable to fetch latest version${NC}"
        return 1
    fi
    
    echo -e "${WHITE}📝 Current version: ${GRAY}v$SCRIPT_VERSION${NC}"
    echo -e "${WHITE}📦 Latest version:  ${GRAY}v$remote_script_version${NC}"
    echo
    
    # Compare versions
    if [ "$SCRIPT_VERSION" = "$remote_script_version" ]; then
        echo -e "${GREEN}✅ You are running the latest version${NC}"
        return 0
    else
        echo -e "${YELLOW}🔄 A new version is available!${NC}"
        echo
        
        # Try to get changelog/release info if available
        echo -e "${WHITE}What's new in v$remote_script_version:${NC}"
        echo -e "${GRAY}• Bug fixes and improvements${NC}"
        echo -e "${GRAY}• Enhanced stability${NC}"
        echo -e "${GRAY}• Updated features${NC}"
        
        echo
        read -p "Would you like to update now? [Y/n]: " -r update_choice
        
        if [[ ! $update_choice =~ ^[Nn]$ ]]; then
            update_script
        else
            echo -e "${GRAY}Update skipped${NC}"
        fi
    fi
}

# Update script function
update_script() {
    echo -e "${WHITE}🔄 Updating script...${NC}"
    
    # Create backup
    local backup_file="/tmp/caddy-selfsteal-backup-$(date +%Y%m%d_%H%M%S).sh"
    if cp "$0" "$backup_file" 2>/dev/null; then
        echo -e "${GRAY}💾 Backup created: $backup_file${NC}"
    fi
    
    # Download new version
    local temp_file="/tmp/caddy-selfsteal-update-$$.sh"
    
    if curl -fsSL "$UPDATE_URL" -o "$temp_file" 2>/dev/null; then
        # Verify downloaded file
        if [ -s "$temp_file" ] && head -1 "$temp_file" | grep -q "#!/"; then
            # Get new version from downloaded script
            local new_version=$(grep "^SCRIPT_VERSION=" "$temp_file" | cut -d'"' -f2)
            
            # Check if running as root for system-wide update
            if [ "$EUID" -eq 0 ]; then
                # Update system installation
                if [ -f "/usr/local/bin/$APP_NAME" ]; then
                    cp "$temp_file" "/usr/local/bin/$APP_NAME"
                    chmod +x "/usr/local/bin/$APP_NAME"
                    echo -e "${GREEN}✅ System script updated successfully${NC}"
                fi
                
                # Update current script if different location
                if [ "$0" != "/usr/local/bin/$APP_NAME" ]; then
                    cp "$temp_file" "$0"
                    chmod +x "$0"
                    echo -e "${GREEN}✅ Current script updated successfully${NC}"
                fi
            else
                # User-level update
                cp "$temp_file" "$0"
                chmod +x "$0"
                echo -e "${GREEN}✅ Script updated successfully${NC}"
                echo -e "${YELLOW}💡 Run with sudo to update system-wide installation${NC}"
            fi
            
            rm -f "$temp_file"
            
            echo
            echo -e "${WHITE}🎉 Update completed!${NC}"
            echo -e "${WHITE}📝 Updated to version: ${GRAY}v$new_version${NC}"
            echo -e "${GRAY}Please restart the script to use the new version${NC}"
            echo
            
            read -p "Restart script now? [Y/n]: " -r restart_choice
            if [[ ! $restart_choice =~ ^[Nn]$ ]]; then
                echo -e "${GRAY}Restarting...${NC}"
                exec "$0" "$@"
            fi
        else
            echo -e "${RED}❌ Downloaded file appears to be corrupted${NC}"
            rm -f "$temp_file"
            return 1
        fi
    else
        echo -e "${RED}❌ Failed to download update${NC}"
        rm -f "$temp_file"
        return 1
    fi
}

# Auto-update check (silent)
check_for_updates_silent() {
    # Simple silent check for updates
    if command -v curl >/dev/null 2>&1; then
        local remote_script_version
        remote_script_version=$(timeout 5 curl -s "$UPDATE_URL" 2>/dev/null | grep "^SCRIPT_VERSION=" | cut -d'"' -f2 2>/dev/null)
        
        if [ -n "$remote_script_version" ] && [ "$SCRIPT_VERSION" != "$remote_script_version" ]; then
            echo -e "${YELLOW}💡 Update available: v$remote_script_version (current: v$SCRIPT_VERSION)${NC}"
            echo -e "${GRAY}   Run 'sudo $APP_NAME update' to update${NC}"
            echo
        fi
    fi 2>/dev/null || true  # Suppress any errors completely
}

# Manual update command
update_command() {
    check_running_as_root
    check_for_updates
}

# Guide and instructions command
guide_command() {
    clear
    echo -e "${WHITE}📖 Selfsteal Setup Guide${NC}"
    echo -e "${GRAY}$(printf '─%.0s' $(seq 1 50))${NC}"
    echo

    # Get current configuration
    local domain=""
    local port=""
    if [ -f "$APP_DIR/.env" ]; then
        domain=$(grep "SELF_STEAL_DOMAIN=" "$APP_DIR/.env" 2>/dev/null | cut -d'=' -f2)
        port=$(grep "SELF_STEAL_PORT=" "$APP_DIR/.env" 2>/dev/null | cut -d'=' -f2)
    fi

    echo -e "${BLUE}🎯 What is Selfsteal?${NC}"
    echo -e "${GRAY}Selfsteal is a Caddy-based front-end for Xray Reality protocol that provides:"
    echo "• Traffic masking with legitimate-looking websites"
    echo "• SSL/TLS termination and certificate management"
    echo "• Multiple website templates for better camouflage"
    echo "• Easy integration with Xray Reality servers${NC}"
    echo

    echo -e "${BLUE}🔧 How it works:${NC}"
    echo -e "${GRAY}1. Caddy runs on a custom HTTPS port (default: 9443)"
    echo "2. Xray Reality forwards unrecognized traffic to Caddy"
    echo "3. Regular users see a normal website"
    echo "4. VPN clients connect through Reality protocol${NC}"
    echo

    if [ -n "$domain" ] && [ -n "$port" ]; then
        echo -e "${GREEN}✅ Your Current Configuration:${NC}"
        echo -e "${WHITE}   Domain:${NC} ${CYAN}$domain${NC}"
        echo -e "${WHITE}   HTTPS Port:${NC} ${CYAN}$port${NC}"
        echo -e "${WHITE}   Website URL:${NC} ${CYAN}https://$domain:$port${NC}"
        echo
    else
        echo -e "${YELLOW}⚠️  Selfsteal not configured yet. Run installation first!${NC}"
        echo
    fi

    echo -e "${BLUE}📋 Xray Reality Configuration Example:${NC}"
    echo -e "${GRAY}Copy this template and customize it for your Xray server:${NC}"
    echo

    # Generate a random private key if openssl is available
    local private_key="#REPLACE_WITH_YOUR_PRIVATE_KEY"
    if command -v openssl >/dev/null 2>&1; then
        private_key=$(openssl rand -base64 32 | tr -d '=' | head -c 43)
    fi

    cat << EOF
${WHITE}{
    "inbounds": [
        {
            "tag": "VLESS_SELFSTEAL_WITH_CADDY",
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
                "network": "raw",
                "security": "reality",
                "realitySettings": {
                    "show": false,
                    "xver": 1,
                    "target": "127.0.0.1:${port:-9443}",
                    "spiderX": "",
                    "shortIds": [
                        ""
                    ],
                    "privateKey": "$private_key",
                    "serverNames": [
                        "${domain:-reality.example.com}"
                    ]
                }
            }
        }
    ]
}${NC}
EOF

    echo
    echo -e "${YELLOW}🔑 Replace the following values:${NC}"
    echo -e "${GRAY}• ${WHITE}clients[]${GRAY} - Add your client configurations with UUIDs${NC}"
    echo -e "${GRAY}• ${WHITE}shortIds${GRAY} - Add your Reality short IDs${NC}"
    if command -v openssl >/dev/null 2>&1; then
        echo -e "${GRAY}• ${WHITE}privateKey${GRAY} - Generated above (or use your own)${NC}"
    else
        echo -e "${GRAY}• ${WHITE}privateKey${GRAY} - Generate with Reality key tools${NC}"
    fi
    if [ -z "$domain" ]; then
        echo -e "${GRAY}• ${WHITE}reality.example.com${GRAY} - Your actual domain${NC}"
    fi
    if [ -z "$port" ] || [ "$port" != "9443" ]; then
        echo -e "${GRAY}• ${WHITE}9443${GRAY} - Your Caddy HTTPS port${NC}"
    fi
    echo

    echo -e "${BLUE}🔐 Generate Reality Keys${NC}"
    echo -e "${GRAY}• Use ${WHITE}Private key${GRAY} in your Xray server config${NC}"
    echo

    echo -e "${BLUE}📱 Client Configuration Tips:${NC}"
    echo -e "${GRAY}For client apps (v2rayN, v2rayNG, etc.):${NC}"
    echo -e "${WHITE}• Protocol:${NC} VLESS"
    echo -e "${WHITE}• Security:${NC} Reality"
    echo -e "${WHITE}• Server:${NC} ${domain:-your-domain.com}"
    echo -e "${WHITE}• Port:${NC} 443"
    echo -e "${WHITE}• Flow:${NC} xtls-rprx-vision"
    echo -e "${WHITE}• SNI:${NC} ${domain:-your-domain.com}"
    echo -e "${WHITE}• Reality Public Key:${NC} (from x25519 generation)"
    echo

    echo -e "${BLUE}🔍 Testing Your Setup:${NC}"
    echo -e "${GRAY}1. Check if Caddy is running:${NC}"
    echo -e "${CYAN}   curl -k https://${domain:-your-domain.com}${NC}"
    echo
    echo -e "${GRAY}2. Verify website loads in browser:${NC}"
    echo -e "${CYAN}   https://${domain:-your-domain.com}${NC}"
    echo
    echo -e "${GRAY}3. Test Xray Reality connection:${NC}"
    echo -e "${CYAN}   Use your VPN client with the configuration above${NC}"
    echo

    echo -e "${BLUE}🛠️  Troubleshooting:${NC}"
    echo -e "${GRAY}• ${WHITE}Connection refused:${GRAY} Check if Caddy is running (option 5)${NC}"
    echo -e "${GRAY}• ${WHITE}SSL certificate errors:${GRAY} Verify DNS points to your server${NC}"
    echo -e "${GRAY}• ${WHITE}Reality not working:${GRAY} Check port ${port:-9443} is accessible${NC}"
    echo -e "${GRAY}• ${WHITE}Website not loading:${GRAY} Try regenerating templates (option 6)${NC}"
    echo

    echo -e "${GREEN}💡 Pro Tips:${NC}"
    echo -e "${GRAY}• Use different website templates to avoid detection${NC}"
    echo -e "${GRAY}• Keep your domain's DNS properly configured${NC}"
    echo -e "${GRAY}• Monitor logs regularly for any issues${NC}"
    echo -e "${GRAY}• Update both Caddy and Xray regularly${NC}"
    echo


    echo -e "${YELLOW}📚 Additional Resources:${NC}"
    echo -e "${GRAY}• Xray Documentation: ${CYAN}https://xtls.github.io/${NC}"
    echo -e "${GRAY}• Reality Protocol Guide: ${CYAN}https://github.com/XTLS/REALITY${NC}"
    echo
}

main_menu() {    # Auto-check for updates on first run
    # check_for_updates_silent
    
    while true; do
        clear
        echo -e "${WHITE}🔗 Caddy for Reality Selfsteal${NC}"
        echo -e "${GRAY}Management System v$SCRIPT_VERSION${NC}"
        echo -e "${GRAY}$(printf '─%.0s' $(seq 1 40))${NC}"
        echo


        local menu_status="Not installed"
        local status_color="$GRAY"
        local domain=""
        local port=""
        
        if [ -d "$APP_DIR" ]; then
            if [ -f "$APP_DIR/.env" ]; then
                domain=$(grep "SELF_STEAL_DOMAIN=" "$APP_DIR/.env" 2>/dev/null | cut -d'=' -f2)
                port=$(grep "SELF_STEAL_PORT=" "$APP_DIR/.env" 2>/dev/null | cut -d'=' -f2)
            fi
            
            cd "$APP_DIR"
            local container_state=$(docker compose ps --format "{{.State}}" 2>/dev/null | head -1)
            
            case "$container_state" in
                "running")
                    menu_status="Running"
                    status_color="$GREEN"
                    ;;
                "restarting")
                    menu_status="Error (Restarting)"
                    status_color="$YELLOW"
                    ;;
                "exited"|"stopped")
                    menu_status="Stopped"
                    status_color="$RED"
                    ;;
                "paused")
                    menu_status="Paused"
                    status_color="$YELLOW"
                    ;;
                *)
                    if [ -f "$APP_DIR/docker-compose.yml" ]; then
                        menu_status="Not running"
                        status_color="$RED"
                    else
                        menu_status="Not installed"
                        status_color="$GRAY"
                    fi
                    ;;
            esac
        fi
        
        case "$menu_status" in
            "Running")
                echo -e "${status_color}✅ Status: $menu_status${NC}"
                ;;
            "Error (Restarting)")
                echo -e "${status_color}⚠️  Status: $menu_status${NC}"
                ;;
            "Stopped"|"Not running")
                echo -e "${status_color}❌ Status: $menu_status${NC}"
                ;;
            "Paused")
                echo -e "${status_color}⏸️  Status: $menu_status${NC}"
                ;;
            *)
                echo -e "${status_color}📦 Status: $menu_status${NC}"
                ;;
        esac
        
        if [ -n "$domain" ]; then
            printf "   ${WHITE}%-10s${NC} ${GRAY}%s${NC}\n" "Domain:" "$domain"
        fi
        if [ -n "$port" ]; then
            printf "   ${WHITE}%-10s${NC} ${GRAY}%s${NC}\n" "Port:" "$port"
        fi
        
        if [ "$menu_status" = "Error (Restarting)" ]; then
            echo
            echo -e "${YELLOW}⚠️  Service is experiencing issues!${NC}"
            echo -e "${GRAY}   Recommended: Check logs (option 7) or restart services (option 4)${NC}"
        fi
        
        echo
        echo -e "${WHITE}📋 Available Operations:${NC}"
        echo

        echo -e "${WHITE}🔧 Service Management:${NC}"
        echo -e "   ${WHITE}1)${NC} 🚀 Install Caddy"
        echo -e "   ${WHITE}2)${NC} ▶️  Start services"
        echo -e "   ${WHITE}3)${NC} ⏹️  Stop services"
        echo -e "   ${WHITE}4)${NC} 🔄 Restart services"
        echo -e "   ${WHITE}5)${NC} 📊 Service status"
        echo

        echo -e "${WHITE}🎨 Website Management:${NC}"
        echo -e "   ${WHITE}6)${NC} 🎨 Website templates"
        echo -e "   ${WHITE}7)${NC} 📖 Setup guide & examples"
        echo

        echo -e "${WHITE}📝 Logs & Monitoring:${NC}"
        echo -e "   ${WHITE}8)${NC} 📝 View logs"
        echo -e "   ${WHITE}9)${NC} 📊 Log sizes"
        echo -e "   ${WHITE}10)${NC} 🧹 Clean logs"
        echo -e "   ${WHITE}11)${NC} ✏️  Edit configuration"
        echo

        echo -e "${WHITE}🗑️  Maintenance:${NC}"
        echo -e "   ${WHITE}12)${NC} 🗑️  Uninstall Caddy"
        echo -e "   ${WHITE}13)${NC} 🔄 Check for updates"
        echo
        echo -e "   ${GRAY}0)${NC} ⬅️  Exit"
        echo
        case "$menu_status" in
            "Not installed")
                echo -e "${BLUE}💡 Tip: Start with option 1 to install Caddy${NC}"
                ;;
            "Stopped"|"Not running")
                echo -e "${BLUE}💡 Tip: Use option 2 to start services${NC}"
                ;;
            "Error (Restarting)")
                echo -e "${BLUE}💡 Tip: Check logs (7) to diagnose issues${NC}"
                ;;
            "Running")
                echo -e "${BLUE}💡 Tip: Use option 6 to customize website templates${NC}"
                ;;
        esac

        read -p "$(echo -e "${WHITE}Select option [0-13]:${NC} ")" choice

        case "$choice" in
            1) install_command; read -p "Press Enter to continue..." ;;
            2) up_command; read -p "Press Enter to continue..." ;;
            3) down_command; read -p "Press Enter to continue..." ;;
            4) restart_command; read -p "Press Enter to continue..." ;;
            5) status_command; read -p "Press Enter to continue..." ;;
            6) template_command ;;
            7) guide_command; read -p "Press Enter to continue..." ;;
            8) logs_command; read -p "Press Enter to continue..." ;;
            9) logs_size_command; read -p "Press Enter to continue..." ;;
            10) clean_logs_command; read -p "Press Enter to continue..." ;;
            11) edit_command; read -p "Press Enter to continue..." ;;
            12) uninstall_command; read -p "Press Enter to continue..." ;;
            13) update_command; read -p "Press Enter to continue..." ;;
            0) clear; exit 0 ;;
            *) 
                echo -e "${RED}❌ Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}

# Main execution
case "$COMMAND" in
    install) install_command ;;
    up) up_command ;;
    down) down_command ;;
    restart) restart_command ;;
    status) status_command ;;
    logs) logs_command ;;
    logs-size) logs_size_command ;;
    clean-logs) clean_logs_command ;;
    edit) edit_command ;;
    uninstall) uninstall_command ;;
    template) template_command ;;
    guide) guide_command ;;
    menu) main_menu ;;
    update) update_command ;;
    check-update) update_command ;;
    help) show_help ;;
    --version|-v) echo "Caddy Selfsteal Management Script v$SCRIPT_VERSION" ;;
    --help|-h) show_help ;;
    "") main_menu ;;
    *) 
        echo -e "${RED}❌ Unknown command: $COMMAND${NC}"
        echo "Use '$APP_NAME --help' for usage information."
        exit 1
        ;;
esac
