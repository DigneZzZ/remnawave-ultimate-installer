#!/usr/bin/env bash
# HTTP Functions for Remnawave Ultimate Installer
# Provides download, API request, and URL checking utilities
# Author: DigneZzZ
# Version: 1.0.0

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/display.sh"
source "$SCRIPT_DIR/../core/validation.sh"

# =============================================================================
# URL CHECKING
# =============================================================================

check_url_exists() {
    local url="$1"
    local timeout="${2:-10}"
    
    if ! validate_url "$url"; then
        return 1
    fi
    
    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout "$timeout" "$url" 2>/dev/null)
    
    if [[ "$status_code" =~ ^(200|301|302)$ ]]; then
        return 0
    fi
    
    return 1
}

check_url_reachable() {
    local url="$1"
    local retries="${2:-3}"
    local timeout="${3:-5}"
    
    for i in $(seq 1 "$retries"); do
        if curl -s --connect-timeout "$timeout" --max-time "$((timeout * 2))" -f "$url" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done
    
    return 1
}

get_url_content_type() {
    local url="$1"
    
    curl -s -I "$url" 2>/dev/null | grep -i "content-type:" | awk '{print $2}' | tr -d '\r\n'
}

get_url_status_code() {
    local url="$1"
    
    curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null
}

# =============================================================================
# BASIC DOWNLOAD
# =============================================================================

download_file() {
    local url="$1"
    local destination="$2"
    local silent="${3:-false}"
    
    if ! validate_url "$url"; then
        [ "$silent" = "false" ] && display_error "Неверный URL: $url"
        return 1
    fi
    
    # Create destination directory if needed
    local dest_dir
    dest_dir=$(dirname "$destination")
    mkdir -p "$dest_dir"
    
    # Download
    if [ "$silent" = "false" ]; then
        display_step "Загрузка: $(basename "$destination")"
    fi
    
    if curl -fsSL -o "$destination" "$url" 2>/dev/null; then
        [ "$silent" = "false" ] && display_success "Файл загружен: $destination"
        return 0
    else
        [ "$silent" = "false" ] && display_error "Ошибка загрузки: $url"
        return 1
    fi
}

download_file_with_retry() {
    local url="$1"
    local destination="$2"
    local retries="${3:-3}"
    local silent="${4:-false}"
    
    for i in $(seq 1 "$retries"); do
        if download_file "$url" "$destination" "$silent"; then
            return 0
        fi
        
        if [ $i -lt "$retries" ]; then
            [ "$silent" = "false" ] && display_warning "Повторная попытка ($i/$retries)..."
            sleep 2
        fi
    done
    
    return 1
}

# =============================================================================
# DOWNLOAD WITH PROGRESS
# =============================================================================

download_with_progress() {
    local url="$1"
    local destination="$2"
    local show_speed="${3:-true}"
    
    if ! validate_url "$url"; then
        display_error "Неверный URL: $url"
        return 1
    fi
    
    # Create destination directory
    local dest_dir
    dest_dir=$(dirname "$destination")
    mkdir -p "$dest_dir"
    
    display_step "Загрузка: $(basename "$destination")"
    echo
    
    # Download with progress bar
    if [ "$show_speed" = "true" ]; then
        curl -# -L -o "$destination" "$url" 2>&1 | \
            while IFS= read -r line; do
                echo -ne "\r${CYAN}${line}${NC}"
            done
    else
        curl -# -L -o "$destination" "$url"
    fi
    
    echo
    
    if [ -f "$destination" ]; then
        local size
        size=$(du -h "$destination" | cut -f1)
        display_success "Загружено: $size"
        return 0
    else
        display_error "Ошибка загрузки"
        return 1
    fi
}

download_to_temp() {
    local url="$1"
    local filename="${2:-$(basename "$url")}"
    
    local temp_file="/tmp/remnawave-$$-$filename"
    
    if download_file "$url" "$temp_file" "true"; then
        echo "$temp_file"
        return 0
    fi
    
    return 1
}

# =============================================================================
# GITHUB DOWNLOADS
# =============================================================================

download_github_release() {
    local repo="$1"
    local tag="$2"
    local asset="$3"
    local destination="$4"
    
    local url="https://github.com/$repo/releases/download/$tag/$asset"
    
    download_with_progress "$url" "$destination"
}

get_latest_github_release() {
    local repo="$1"
    
    curl -s "https://api.github.com/repos/$repo/releases/latest" | \
        grep '"tag_name":' | \
        sed -E 's/.*"([^"]+)".*/\1/'
}

download_github_raw() {
    local repo="$1"
    local branch="$2"
    local filepath="$3"
    local destination="$4"
    
    local url="https://raw.githubusercontent.com/$repo/$branch/$filepath"
    
    download_file "$url" "$destination" "false"
}

# =============================================================================
# API REQUESTS
# =============================================================================

api_request() {
    local method="$1"
    local url="$2"
    local data="$3"
    local headers="$4"
    local timeout="${5:-30}"
    
    local curl_opts=(-s -X "$method" --connect-timeout "$timeout")
    
    # Add headers
    if [ -n "$headers" ]; then
        while IFS= read -r header; do
            curl_opts+=(-H "$header")
        done <<< "$headers"
    fi
    
    # Add data for POST/PUT/PATCH
    if [[ "$method" =~ ^(POST|PUT|PATCH)$ ]] && [ -n "$data" ]; then
        curl_opts+=(-d "$data")
    fi
    
    # Make request
    curl "${curl_opts[@]}" "$url" 2>/dev/null
}

api_get() {
    local url="$1"
    local headers="$2"
    
    api_request "GET" "$url" "" "$headers"
}

api_post() {
    local url="$1"
    local data="$2"
    local headers="${3:-Content-Type: application/json}"
    
    api_request "POST" "$url" "$data" "$headers"
}

api_put() {
    local url="$1"
    local data="$2"
    local headers="${3:-Content-Type: application/json}"
    
    api_request "PUT" "$url" "$data" "$headers"
}

api_delete() {
    local url="$1"
    local headers="$2"
    
    api_request "DELETE" "$url" "" "$headers"
}

api_request_with_auth() {
    local method="$1"
    local url="$2"
    local token="$3"
    local data="$4"
    local content_type="${5:-application/json}"
    
    local headers="Authorization: Bearer $token"$'\n'"Content-Type: $content_type"
    
    api_request "$method" "$url" "$data" "$headers"
}

# =============================================================================
# JSON API UTILITIES
# =============================================================================

json_api_get() {
    local url="$1"
    local token="${2:-}"
    
    local headers="Content-Type: application/json"
    
    if [ -n "$token" ]; then
        headers="$headers"$'\n'"Authorization: Bearer $token"
    fi
    
    api_get "$url" "$headers"
}

json_api_post() {
    local url="$1"
    local json_data="$2"
    local token="${3:-}"
    
    if ! validate_json "$json_data"; then
        display_error "Неверный JSON"
        return 1
    fi
    
    local headers="Content-Type: application/json"
    
    if [ -n "$token" ]; then
        headers="$headers"$'\n'"Authorization: Bearer $token"
    fi
    
    api_post "$url" "$json_data" "$headers"
}

# =============================================================================
# FILE UPLOAD
# =============================================================================

upload_file() {
    local url="$1"
    local filepath="$2"
    local field_name="${3:-file}"
    local token="${4:-}"
    
    if ! validate_file_exists "$filepath"; then
        display_error "Файл не найден: $filepath"
        return 1
    fi
    
    local curl_opts=(-s -X POST -F "${field_name}=@${filepath}")
    
    if [ -n "$token" ]; then
        curl_opts+=(-H "Authorization: Bearer $token")
    fi
    
    curl "${curl_opts[@]}" "$url" 2>/dev/null
}

# =============================================================================
# SPEED TEST & DIAGNOSTICS
# =============================================================================

measure_download_speed() {
    local url="$1"
    local test_size="${2:-1048576}" # 1MB default
    
    local start_time=$(date +%s)
    curl -s --max-time 10 "$url" -o /dev/null 2>/dev/null
    local end_time=$(date +%s)
    
    local duration=$((end_time - start_time))
    
    if [ "$duration" -gt 0 ]; then
        local speed=$((test_size / duration / 1024))
        echo "${speed} KB/s"
    else
        echo "N/A"
    fi
}

check_internet_connection() {
    local test_urls=(
        "https://www.google.com"
        "https://www.cloudflare.com"
        "https://1.1.1.1"
    )
    
    for url in "${test_urls[@]}"; do
        if curl -s --connect-timeout 5 --max-time 10 -f "$url" >/dev/null 2>&1; then
            return 0
        fi
    done
    
    return 1
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

get_redirect_url() {
    local url="$1"
    
    curl -sI "$url" 2>/dev/null | grep -i "location:" | awk '{print $2}' | tr -d '\r\n'
}

get_final_url() {
    local url="$1"
    
    curl -Ls -o /dev/null -w "%{url_effective}" "$url" 2>/dev/null
}

extract_filename_from_url() {
    local url="$1"
    
    basename "$url" | cut -d'?' -f1
}

url_encode() {
    local string="$1"
    
    echo -n "$string" | jq -sRr @uri 2>/dev/null || \
        python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$string" 2>/dev/null || \
        echo "$string"
}

url_decode() {
    local string="$1"
    
    echo -n "$string" | python3 -c "import sys, urllib.parse; print(urllib.parse.unquote(sys.stdin.read()))" 2>/dev/null || \
        echo "$string"
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f check_url_exists
export -f check_url_reachable
export -f get_url_content_type
export -f get_url_status_code
export -f download_file
export -f download_file_with_retry
export -f download_with_progress
export -f download_to_temp
export -f download_github_release
export -f get_latest_github_release
export -f download_github_raw
export -f api_request
export -f api_get
export -f api_post
export -f api_put
export -f api_delete
export -f api_request_with_auth
export -f json_api_get
export -f json_api_post
export -f upload_file
export -f measure_download_speed
export -f check_internet_connection
export -f get_redirect_url
export -f get_final_url
export -f extract_filename_from_url
export -f url_encode
export -f url_decode
