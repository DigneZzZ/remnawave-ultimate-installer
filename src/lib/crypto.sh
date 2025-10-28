#!/usr/bin/env bash
# Cryptographic Utilities Library
# Advanced crypto generation for Remnawave infrastructure
# Author: DigneZzZ

# Prevent double loading
[[ -n "${CRYPTO_LOADED}" ]] && return 0
readonly CRYPTO_LOADED=1

source "$(dirname "${BASH_SOURCE[0]}")/../core/colors.sh"

# =============================================================================
# RANDOM GENERATION
# =============================================================================

generate_random_string() {
    local length="${1:-32}"
    local chars="${2:-A-Za-z0-9}"
    
    tr -dc "$chars" < /dev/urandom | head -c "$length"
}

generate_random_hex() {
    local length="${1:-32}"
    
    openssl rand -hex "$length"
}

generate_random_base64() {
    local length="${1:-32}"
    
    openssl rand -base64 "$length" | tr -d '=+/' | cut -c1-"$length"
}

generate_random_alphanumeric() {
    local length="${1:-32}"
    
    generate_random_string "$length" "A-Za-z0-9"
}

generate_random_number() {
    local min="${1:-1000}"
    local max="${2:-9999}"
    
    shuf -i "$min-$max" -n 1
}

# =============================================================================
# PASSWORD GENERATION
# =============================================================================

generate_password() {
    local length="${1:-16}"
    local special="${2:-true}"
    
    if [ "$special" = "true" ]; then
        tr -dc 'A-Za-z0-9!@#$%^&*()_+=' < /dev/urandom | head -c "$length"
    else
        tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
    fi
}

generate_secure_password() {
    local length="${1:-24}"
    
    # Generate password with at least one of each: uppercase, lowercase, number, special
    local upper=$(tr -dc 'A-Z' < /dev/urandom | head -c 4)
    local lower=$(tr -dc 'a-z' < /dev/urandom | head -c 4)
    local numbers=$(tr -dc '0-9' < /dev/urandom | head -c 4)
    local special=$(tr -dc '!@#$%^&*()_+-=' < /dev/urandom | head -c 4)
    local rest_length=$((length - 16))
    local rest=$(tr -dc 'A-Za-z0-9!@#$%^&*()_+-=' < /dev/urandom | head -c "$rest_length")
    
    # Combine and shuffle
    echo "${upper}${lower}${numbers}${special}${rest}" | fold -w1 | shuf | tr -d '\n'
}

generate_db_password() {
    # Database-safe password (no special chars that might cause issues)
    local length="${1:-20}"
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
}

# =============================================================================
# KEY GENERATION
# =============================================================================

generate_jwt_secret() {
    local length="${1:-64}"
    
    openssl rand -base64 "$length" | tr -d '\n'
}

generate_api_key() {
    local prefix="${1:-rw}"
    local length="${2:-32}"
    
    echo "${prefix}_$(generate_random_alphanumeric "$length")"
}

generate_secret_key() {
    # Generate multiline secret key for node
    local lines="${1:-5}"
    
    local secret=""
    for i in $(seq 1 "$lines"); do
        secret+="$(generate_random_base64 48)"
        [ "$i" -lt "$lines" ] && secret+="\n"
    done
    
    echo -e "$secret"
}

generate_cookie_secret() {
    # Cookie secret for authentication
    openssl rand -hex 32
}

generate_encryption_key() {
    # 256-bit encryption key
    openssl rand -base64 32
}

# =============================================================================
# UUID GENERATION
# =============================================================================

generate_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    else
        # Fallback UUID v4 generation
        local N B T
        
        for i in {1..16}; do
            B=$(( RANDOM%256 ))
            
            case $i in
                7) printf '4%x' $(( B%16 )) ;;
                9) printf '%x' $(( B%16 + 8 )) ;;
                4|6|8|10) printf '%02x-' $B ;;
                *) printf '%02x' $B ;;
            esac
        done
        echo
    fi
}

# =============================================================================
# HASH GENERATION
# =============================================================================

generate_sha256_hash() {
    local input="$1"
    
    echo -n "$input" | sha256sum | awk '{print $1}'
}

generate_md5_hash() {
    local input="$1"
    
    echo -n "$input" | md5sum | awk '{print $1}'
}

generate_file_hash() {
    local file="$1"
    local algorithm="${2:-sha256}"
    
    case "$algorithm" in
        sha256)
            sha256sum "$file" | awk '{print $1}'
            ;;
        md5)
            md5sum "$file" | awk '{print $1}'
            ;;
        sha1)
            sha1sum "$file" | awk '{print $1}'
            ;;
        *)
            echo "Unsupported algorithm: $algorithm" >&2
            return 1
            ;;
    esac
}

# =============================================================================
# SSL/TLS CERTIFICATE GENERATION
# =============================================================================

generate_self_signed_cert() {
    local domain="$1"
    local cert_path="$2"
    local key_path="$3"
    local days="${4:-365}"
    
    openssl req -x509 -nodes -days "$days" -newkey rsa:2048 \
        -keyout "$key_path" \
        -out "$cert_path" \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=$domain" \
        2>/dev/null
}

generate_csr() {
    local domain="$1"
    local key_path="$2"
    local csr_path="$3"
    
    openssl req -new -newkey rsa:2048 -nodes \
        -keyout "$key_path" \
        -out "$csr_path" \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=$domain" \
        2>/dev/null
}

# =============================================================================
# XRAY KEYS (from xxphantom)
# =============================================================================

generate_xray_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen
    else
        generate_uuid
    fi
}

generate_xray_private_key() {
    openssl genpkey -algorithm x25519 2>/dev/null | \
        openssl pkey -text 2>/dev/null | \
        grep -A 1 "priv:" | tail -1 | \
        tr -d ' \n:' | \
        xxd -r -p | base64
}

generate_xray_public_key() {
    local private_key="$1"
    
    echo "$private_key" | base64 -d | xxd -p -c 32 | \
        openssl ec -pubin -inform DER 2>/dev/null | \
        openssl ec -text -noout 2>/dev/null | \
        grep -A 1 "pub:" | tail -1 | \
        tr -d ' \n:' | \
        xxd -r -p | base64
}

generate_xray_keys() {
    # Generate both private and public keys
    local private_key=$(generate_xray_private_key)
    local public_key=$(generate_xray_public_key "$private_key")
    
    echo "PRIVATE_KEY=$private_key"
    echo "PUBLIC_KEY=$public_key"
}

generate_xray_short_id() {
    openssl rand -hex 8
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

is_valid_uuid() {
    local uuid="$1"
    
    [[ "$uuid" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]
}

is_valid_hex() {
    local hex="$1"
    
    [[ "$hex" =~ ^[0-9a-fA-F]+$ ]]
}

is_valid_base64() {
    local base64_string="$1"
    
    [[ "$base64_string" =~ ^[A-Za-z0-9+/]*={0,2}$ ]]
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f generate_random_string
export -f generate_random_hex
export -f generate_random_base64
export -f generate_random_alphanumeric
export -f generate_random_number
export -f generate_password
export -f generate_secure_password
export -f generate_db_password
export -f generate_jwt_secret
export -f generate_api_key
export -f generate_secret_key
export -f generate_cookie_secret
export -f generate_encryption_key
export -f generate_uuid
export -f generate_sha256_hash
export -f generate_md5_hash
export -f generate_file_hash
export -f generate_self_signed_cert
export -f generate_csr
export -f generate_xray_uuid
export -f generate_xray_private_key
export -f generate_xray_public_key
export -f generate_xray_keys
export -f generate_xray_short_id
export -f is_valid_uuid
export -f is_valid_hex
export -f is_valid_base64
