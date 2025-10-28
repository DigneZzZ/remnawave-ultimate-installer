#!/usr/bin/env bash
#!/usr/bin/env bash
# Validation Functions Library
# Comprehensive validation for Remnawave Ultimate Installer
# Author: DigneZzZ
# Combines best practices from selfsteal.sh, eGames, and xxphantom

source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
source "$(dirname "${BASH_SOURCE[0]}")/display.sh"

# =============================================================================
# SYSTEM VALIDATION
# =============================================================================

validate_root() {
    if [ "$EUID" -ne 0 ]; then
        display_error "This script must be run as root"
        echo -e "${GRAY}   Please run: sudo bash install.sh${NC}"
        return 1
    fi
    return 0
}

validate_os() {
    if [ ! -f /etc/os-release ]; then
        display_error "Cannot detect operating system"
        return 1
    fi
    
    source /etc/os-release
    
    case "$ID" in
        ubuntu|debian)
            display_success "Supported OS detected: $PRETTY_NAME"
            return 0
            ;;
        centos|rhel|fedora|rocky|almalinux)
            display_success "Supported OS detected: $PRETTY_NAME"
            return 0
            ;;
        *)
            display_warning "Untested OS: $PRETTY_NAME"
            display_info "Proceed at your own risk"
            return 0
            ;;
    esac
}

validate_architecture() {
    local arch=$(uname -m)
    
    case "$arch" in
        x86_64|amd64)
            display_success "Supported architecture: $arch"
            return 0
            ;;
        aarch64|arm64)
            display_success "Supported architecture: $arch"
            return 0
            ;;
        *)
            display_error "Unsupported architecture: $arch"
            echo -e "${GRAY}   Supported: x86_64, amd64, aarch64, arm64${NC}"
            return 1
            ;;
    esac
}

# =============================================================================
# DEPENDENCIES VALIDATION
# =============================================================================

validate_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        display_error "Docker is not installed"
        return 1
    fi
    
    local docker_version=$(docker --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
    display_success "Docker installed: $docker_version"
    return 0
}

validate_docker_compose() {
    if ! docker compose version >/dev/null 2>&1; then
        display_error "Docker Compose V2 is not installed"
        return 1
    fi
    
    local compose_version=$(docker compose version --short 2>/dev/null)
    display_success "Docker Compose V2: $compose_version"
    return 0
}

validate_curl() {
    if ! command -v curl >/dev/null 2>&1; then
        display_error "curl is not installed"
        return 1
    fi
    
    display_success "curl is available"
    return 0
}

validate_openssl() {
    if ! command -v openssl >/dev/null 2>&1; then
        display_error "openssl is not installed"
        return 1
    fi
    
    display_success "openssl is available"
    return 0
}

validate_system_requirements() {
    display_section "$ICON_SEARCH" "System Requirements Check"
    
    local all_ok=true
    
    # Check Docker
    if ! validate_docker; then
        all_ok=false
    fi
    
    # Check Docker Compose
    if ! validate_docker_compose; then
        all_ok=false
    fi
    
    # Check curl
    if ! validate_curl; then
        all_ok=false
    fi
    
    # Check openssl
    if ! validate_openssl; then
        all_ok=false
    fi
    
    # Check disk space
    local available_space=$(df / | tail -1 | awk '{print $4}')
    local available_gb=$((available_space / 1024 / 1024))
    
    if [ $available_gb -lt 5 ]; then
        display_warning "Low disk space: ${available_gb}GB available"
        display_info "Recommended: at least 5GB free space"
    else
        display_success "Sufficient disk space: ${available_gb}GB available"
    fi
    
    # Check memory
    local total_mem=$(free -g | awk '/^Mem:/{print $2}')
    if [ $total_mem -lt 1 ]; then
        display_warning "Low memory: ${total_mem}GB RAM"
        display_info "Recommended: at least 2GB RAM"
    else
        display_success "Sufficient memory: ${total_mem}GB RAM"
    fi
    
    echo
    
    if [ "$all_ok" = false ]; then
        display_error "System requirements not met"
        return 1
    else
        display_success "All system requirements met"
        return 0
    fi
}

# =============================================================================
# NETWORK VALIDATION
# =============================================================================

validate_domain_format() {
    local domain="$1"
    
    # Check if domain format is valid
    if ! [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        display_error "Invalid domain format: $domain"
        return 1
    fi
    
    return 0
}

validate_ip_format() {
    local ip="$1"
    
    if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -ra ADDR <<< "$ip"
        for i in "${ADDR[@]}"; do
            if [ "$i" -gt 255 ]; then
                return 1
            fi
        done
        return 0
    fi
    
    return 1
}

validate_port() {
    local port="$1"
    
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        display_error "Invalid port number: $port"
        echo -e "${GRAY}   Port must be between 1 and 65535${NC}"
        return 1
    fi
    
    return 0
}

validate_port_available() {
    local port="$1"
    
    if ss -tlnp | grep -q ":$port "; then
        local process=$(ss -tlnp | grep ":$port " | awk '{print $6}' | cut -d'"' -f2 | head -1)
        display_warning "Port $port is already in use"
        if [ -n "$process" ]; then
            echo -e "${GRAY}   Used by: $process${NC}"
        fi
        return 1
    fi
    
    return 0
}

validate_dns_resolution() {
    local domain="$1"
    local expected_ip="${2:-}"
    
    display_step "Checking DNS resolution for $domain"
    
    # Check if dig is available
    if ! command -v dig >/dev/null 2>&1; then
        display_warning "dig not available, installing dnsutils..."
        
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update -qq && apt-get install -y -qq dnsutils >/dev/null 2>&1
        elif command -v yum >/dev/null 2>&1; then
            yum install -y -q bind-utils >/dev/null 2>&1
        fi
    fi
    
    # Get A records
    local a_records=$(dig +short A "$domain" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
    
    if [ -z "$a_records" ]; then
        display_error "No DNS A record found for $domain"
        return 1
    fi
    
    display_success "DNS A records found:"
    while IFS= read -r ip; do
        echo -e "${GRAY}   → $ip${NC}"
        
        if [ -n "$expected_ip" ] && [ "$ip" = "$expected_ip" ]; then
            display_success "DNS points to this server: $ip"
            return 0
        fi
    done <<< "$a_records"
    
    if [ -n "$expected_ip" ]; then
        display_warning "DNS does not point to expected IP: $expected_ip"
        return 1
    fi
    
    return 0
}

# Get server IP address (like in remnawave.sh)
get_server_ip() {
    local ip=""
    
    # Try IPv4 first
    ip=$(curl -s -4 --max-time 5 ifconfig.io 2>/dev/null)
    
    # If IPv4 fails, try IPv6
    if [ -z "$ip" ]; then
        ip=$(curl -s -6 --max-time 5 ifconfig.io 2>/dev/null)
    fi
    
    # If both fail, try alternative services
    if [ -z "$ip" ]; then
        ip=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null)
    fi
    
    if [ -z "$ip" ]; then
        ip=$(curl -s --max-time 5 https://icanhazip.com 2>/dev/null)
    fi
    
    if [ -z "$ip" ]; then
        display_error "Cannot detect server IP address"
        return 1
    fi
    
    echo "$ip"
    return 0
}

validate_domain_dns() {
    local domain="$1"
    local auto_detected="${2:-true}"
    
    display_section "$ICON_GLOBE" "DNS Validation"
    
    # Get server IP
    display_step "Detecting server IP address..."
    local server_ip=$(get_server_ip)
    
    if [ -z "$server_ip" ]; then
        display_error "Failed to detect server IP"
        return 1
    fi
    
    display_success "Server IP: $server_ip"
    echo
    
    # Validate domain format
    echo -e "${WHITE}📝 Domain:${NC} $domain"
    
    if ! validate_domain_format "$domain"; then
        return 1
    fi
    
    # Check DNS resolution
    display_step "Checking DNS records for $domain..."
    
    # Install dig if needed
    if ! command -v dig >/dev/null 2>&1; then
        display_info "Installing DNS tools..."
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update -qq && apt-get install -y -qq dnsutils >/dev/null 2>&1
        elif command -v yum >/dev/null 2>&1; then
            yum install -y -q bind-utils >/dev/null 2>&1
        fi
    fi
    
    # Get A records
    local a_records=$(dig +short A "$domain" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
    
    if [ -z "$a_records" ]; then
        echo
        display_error "No DNS A record found for $domain"
        display_warning "Domain is not configured to point to any server"
        echo
        display_info "Please configure DNS:"
        display_list_item "1." "Add an A record for $domain"
        display_list_item "2." "Point it to: $server_ip"
        display_list_item "3." "Wait for DNS propagation (1-24 hours)"
        echo
        return 1
    fi
    
    # Check if any A record matches server IP
    local dns_match=false
    echo -e "${BLUE}   DNS A records found:${NC}"
    
    while IFS= read -r ip; do
        if [ "$ip" = "$server_ip" ]; then
            echo -e "${GREEN}   ✓ $ip${NC} ${GRAY}(matches this server)${NC}"
            dns_match=true
        else
            echo -e "${YELLOW}   ○ $ip${NC} ${GRAY}(different server)${NC}"
        fi
    done <<< "$a_records"
    
    echo
    
    if [ "$dns_match" = true ]; then
        display_success "Domain correctly points to this server!"
        return 0
    else
        display_warning "Domain does NOT point to this server"
        echo
        display_info "Current situation:"
        display_list_item "•" "This server IP: $server_ip"
        display_list_item "•" "Domain points to: $(echo "$a_records" | head -1)"
        echo
        display_info "To fix this:"
        display_list_item "1." "Update A record for $domain"
        display_list_item "2." "Change IP to: $server_ip"
        display_list_item "3." "Wait for DNS propagation"
        echo
        
        read -p "$(echo -e ${YELLOW}Continue installation anyway? [y/N]:${NC} )" -r confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            display_error "Installation cancelled"
            return 1
        fi
        
        display_warning "Proceeding without proper DNS configuration"
        display_warning "SSL certificates may fail to issue"
        return 0
    fi
}

validate_dns_propagation() {
    local domain="$1"
    local expected_ip="$2"
    
    display_step "Checking DNS propagation"
    
    local dns_servers=("8.8.8.8" "1.1.1.1" "208.67.222.222" "9.9.9.9")
    local propagation_count=0
    
    for dns_server in "${dns_servers[@]}"; do
        local resolved_ip=$(dig +short @"$dns_server" A "$domain" 2>/dev/null | head -1)
        
        if [ "$resolved_ip" = "$expected_ip" ]; then
            echo -e "${GREEN}   ✓${NC} ${GRAY}$dns_server: $resolved_ip${NC}"
            ((propagation_count++))
        else
            echo -e "${GRAY}   ○ $dns_server: ${resolved_ip:-no response}${NC}"
        fi
    done
    
    echo
    
    if [ $propagation_count -ge 2 ]; then
        display_success "DNS propagation verified ($propagation_count/4 servers)"
        return 0
    else
        display_warning "DNS not fully propagated ($propagation_count/4 servers)"
        return 1
    fi
}

validate_domain_complete() {
    local domain="$1"
    local server_ip="$2"
    local skip_dns_check="${3:-false}"
    
    display_section "$ICON_GLOBE" "Domain Validation"
    
    echo -e "${WHITE}📝 Domain:${NC} $domain"
    echo -e "${WHITE}🖥️  Server IP:${NC} $server_ip"
    echo
    
    # Format validation
    if ! validate_domain_format "$domain"; then
        return 1
    fi
    display_success "Domain format is valid"
    
    if [ "$skip_dns_check" = "true" ]; then
        display_warning "DNS validation skipped"
        return 0
    fi
    
    # DNS resolution check
    if ! validate_dns_resolution "$domain" "$server_ip"; then
        display_warning "DNS validation failed"
        
        echo
        display_info "Please ensure:"
        display_list_item "•" "Domain has an A record pointing to $server_ip"
        display_list_item "•" "DNS changes have propagated (can take 1-24 hours)"
        display_list_item "•" "No CNAME conflicts exist"
        echo
        
        read -p "Continue anyway? [y/N]: " -r confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    # Propagation check
    validate_dns_propagation "$domain" "$server_ip"
    
    echo
    display_success "Domain validation completed"
    return 0
}

# =============================================================================
# CONFIGURATION VALIDATION
# =============================================================================

validate_email() {
    local email="$1"
    
    if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    fi
    
    display_error "Invalid email format: $email"
    return 1
}

validate_url() {
    local url="$1"
    
    if [[ "$url" =~ ^https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/.*)?$ ]]; then
        return 0
    fi
    
    display_error "Invalid URL format: $url"
    return 1
}

validate_password_strength() {
    local password="$1"
    local min_length="${2:-8}"
    
    if [ ${#password} -lt $min_length ]; then
        display_error "Password too short (minimum $min_length characters)"
        return 1
    fi
    
    # Check for at least one number
    if ! [[ "$password" =~ [0-9] ]]; then
        display_warning "Password should contain at least one number"
    fi
    
    # Check for at least one letter
    if ! [[ "$password" =~ [a-zA-Z] ]]; then
        display_warning "Password should contain at least one letter"
    fi
    
    return 0
}

validate_json() {
    local json_string="$1"
    
    if echo "$json_string" | jq empty 2>/dev/null; then
        return 0
    fi
    
    display_error "Invalid JSON format"
    return 1
}

# =============================================================================
# FILE & PATH VALIDATION
# =============================================================================

validate_directory_writable() {
    local dir="$1"
    
    if [ ! -d "$dir" ]; then
        if ! mkdir -p "$dir" 2>/dev/null; then
            display_error "Cannot create directory: $dir"
            return 1
        fi
    fi
    
    if [ ! -w "$dir" ]; then
        display_error "Directory not writable: $dir"
        return 1
    fi
    
    return 0
}

validate_file_exists() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        display_error "File not found: $file"
        return 1
    fi
    
    return 0
}

validate_executable() {
    local file="$1"
    
    if [ ! -x "$file" ]; then
        display_error "File not executable: $file"
        return 1
    fi
    
    return 0
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f validate_root
export -f validate_os
export -f validate_architecture
export -f validate_docker
export -f validate_docker_compose
export -f validate_curl
export -f validate_openssl
export -f validate_system_requirements
export -f validate_domain_format
export -f validate_ip_format
export -f validate_port
export -f validate_port_available
export -f get_server_ip
export -f validate_domain_dns
export -f validate_dns_resolution
export -f validate_dns_propagation
export -f validate_domain_complete
export -f validate_email
export -f validate_url
export -f validate_password_strength
export -f validate_json
export -f validate_directory_writable
export -f validate_file_exists
export -f validate_executable
