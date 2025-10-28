#!/usr/bin/env bash
# Logging System for Remnawave Ultimate Installer
# Description: Comprehensive logging with timestamps and file output
# Author: DigneZzZ
# Version: 1.0.0

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/display.sh"

# =============================================================================
# CONFIGURATION
# =============================================================================

# Default log file location
INSTALLER_LOG_FILE="${INSTALLER_LOG_FILE:-/var/log/remnawave-installer.log}"
INSTALLER_LOG_ENABLED="${INSTALLER_LOG_ENABLED:-true}"
INSTALLER_DEBUG="${INSTALLER_DEBUG:-false}"

# Maximum log file size (in bytes) - 10MB
LOG_MAX_SIZE=$((10 * 1024 * 1024))

# =============================================================================
# LOG FILE MANAGEMENT
# =============================================================================

# Initialize log file
init_logging() {
    if [ "$INSTALLER_LOG_ENABLED" != "true" ]; then
        return 0
    fi
    
    # Create log directory if doesn't exist
    local log_dir=$(dirname "$INSTALLER_LOG_FILE")
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir" 2>/dev/null || {
            # If can't create in /var/log, use /tmp
            INSTALLER_LOG_FILE="/tmp/remnawave-installer.log"
            log_dir="/tmp"
        }
    fi
    
    # Check if we have write permissions
    if [ ! -w "$log_dir" ]; then
        INSTALLER_LOG_FILE="/tmp/remnawave-installer.log"
    fi
    
    # Rotate if log file is too large
    if [ -f "$INSTALLER_LOG_FILE" ]; then
        local file_size=$(stat -f%z "$INSTALLER_LOG_FILE" 2>/dev/null || stat -c%s "$INSTALLER_LOG_FILE" 2>/dev/null || echo 0)
        if [ "$file_size" -gt "$LOG_MAX_SIZE" ]; then
            rotate_log
        fi
    fi
    
    # Write session header
    {
        echo ""
        echo "============================================================"
        echo "Remnawave Ultimate Installer - Session Started"
        echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "User: $(whoami)"
        echo "Hostname: $(hostname)"
        echo "OS: $(uname -s) $(uname -r)"
        echo "============================================================"
        echo ""
    } >> "$INSTALLER_LOG_FILE" 2>/dev/null
}

# Rotate log file
rotate_log() {
    if [ ! -f "$INSTALLER_LOG_FILE" ]; then
        return 0
    fi
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local rotated_log="${INSTALLER_LOG_FILE}.${timestamp}"
    
    mv "$INSTALLER_LOG_FILE" "$rotated_log" 2>/dev/null || true
    
    # Keep only last 5 rotated logs
    find "$(dirname "$INSTALLER_LOG_FILE")" -name "$(basename "$INSTALLER_LOG_FILE").*" -type f | sort -r | tail -n +6 | xargs rm -f 2>/dev/null || true
}

# Get timestamp for log entries
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Write to log file
write_log() {
    local level="$1"
    local message="$2"
    
    if [ "$INSTALLER_LOG_ENABLED" != "true" ]; then
        return 0
    fi
    
    echo "[$(get_timestamp)] [$level] $message" >> "$INSTALLER_LOG_FILE" 2>/dev/null
}

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

log_info() {
    local message="$1"
    display_info "$message"
    write_log "INFO" "$message"
}

log_success() {
    local message="$1"
    display_success "$message"
    write_log "SUCCESS" "$message"
}

log_error() {
    local message="$1"
    display_error "$message"
    write_log "ERROR" "$message"
}

log_warning() {
    local message="$1"
    display_warning "$message"
    write_log "WARNING" "$message"
}

log_step() {
    local message="$1"
    display_step "$message"
    write_log "STEP" "$message"
}

log_debug() {
    local message="$1"
    
    if [ "$INSTALLER_DEBUG" = "true" ]; then
        echo -e "${GRAY}[DEBUG] $message${NC}"
        write_log "DEBUG" "$message"
    else
        write_log "DEBUG" "$message"
    fi
}

# Log command execution
log_command() {
    local command="$1"
    local description="${2:-Executing command}"
    
    log_debug "$description: $command"
    
    if [ "$INSTALLER_DEBUG" = "true" ]; then
        eval "$command" 2>&1 | tee -a "$INSTALLER_LOG_FILE"
        return ${PIPESTATUS[0]}
    else
        local output
        local exit_code
        
        output=$(eval "$command" 2>&1)
        exit_code=$?
        
        echo "$output" >> "$INSTALLER_LOG_FILE" 2>/dev/null
        
        if [ $exit_code -ne 0 ]; then
            log_error "Command failed (exit code: $exit_code)"
            log_debug "Command output: $output"
        fi
        
        return $exit_code
    fi
}

# Log section start
log_section() {
    local title="$1"
    
    write_log "SECTION" "==== $title ===="
    display_section "$ICON_CONFIG" "$title"
}

# Log installation step with progress
log_install_step() {
    local step_num="$1"
    local total_steps="$2"
    local description="$3"
    
    local message="[$step_num/$total_steps] $description"
    log_step "$message"
}

# =============================================================================
# ERROR LOGGING
# =============================================================================

# Log error with context
log_error_context() {
    local error_message="$1"
    local function_name="${2:-unknown}"
    local line_number="${3:-unknown}"
    
    log_error "$error_message"
    write_log "ERROR_CONTEXT" "Function: $function_name, Line: $line_number"
}

# Log and exit with error
log_fatal() {
    local message="$1"
    local exit_code="${2:-1}"
    
    log_error "FATAL: $message"
    write_log "FATAL" "$message (exit code: $exit_code)"
    
    # Write session footer
    {
        echo ""
        echo "Session ended with FATAL ERROR at $(get_timestamp)"
        echo "============================================================"
        echo ""
    } >> "$INSTALLER_LOG_FILE" 2>/dev/null
    
    exit "$exit_code"
}

# =============================================================================
# LOG ANALYSIS
# =============================================================================

# Show log file location
show_log_location() {
    if [ "$INSTALLER_LOG_ENABLED" = "true" ]; then
        echo -e "${BLUE}ℹ Логи установки: $INSTALLER_LOG_FILE${NC}"
    fi
}

# Show recent log entries
show_recent_logs() {
    local lines="${1:-50}"
    
    if [ ! -f "$INSTALLER_LOG_FILE" ]; then
        log_warning "Лог файл не найден"
        return 1
    fi
    
    echo -e "${WHITE}Последние $lines строк лога:${NC}"
    echo -e "${GRAY}$(printf '─%.0s' {1..60})${NC}"
    
    tail -n "$lines" "$INSTALLER_LOG_FILE"
}

# Show errors from log
show_log_errors() {
    if [ ! -f "$INSTALLER_LOG_FILE" ]; then
        log_warning "Лог файл не найден"
        return 1
    fi
    
    echo -e "${WHITE}Ошибки в логе:${NC}"
    echo -e "${GRAY}$(printf '─%.0s' {1..60})${NC}"
    
    grep -E '\[(ERROR|FATAL)\]' "$INSTALLER_LOG_FILE" | tail -n 20
}

# =============================================================================
# SESSION MANAGEMENT
# =============================================================================

# End logging session
end_logging_session() {
    local status="${1:-SUCCESS}"
    
    {
        echo ""
        echo "Session ended: $status"
        echo "Date: $(get_timestamp)"
        echo "============================================================"
        echo ""
    } >> "$INSTALLER_LOG_FILE" 2>/dev/null
}

# =============================================================================
# CLEANUP
# =============================================================================

# Cleanup old logs
cleanup_old_logs() {
    local log_dir=$(dirname "$INSTALLER_LOG_FILE")
    local keep_days="${1:-30}"
    
    log_info "Очистка логов старше $keep_days дней..."
    
    find "$log_dir" -name "remnawave-installer.log.*" -type f -mtime +$keep_days -delete 2>/dev/null
    
    log_success "Очистка завершена"
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f init_logging
export -f rotate_log
export -f write_log
export -f log_info
export -f log_success
export -f log_error
export -f log_warning
export -f log_step
export -f log_debug
export -f log_command
export -f log_section
export -f log_install_step
export -f log_error_context
export -f log_fatal
export -f show_log_location
export -f show_recent_logs
export -f show_log_errors
export -f end_logging_session
export -f cleanup_old_logs

# Auto-initialize if not disabled
if [ "${AUTO_INIT_LOGGING:-true}" = "true" ]; then
    init_logging
fi
