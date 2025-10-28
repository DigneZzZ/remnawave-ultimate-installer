#!/usr/bin/env bash
# Backup & Restore Module
# Description: Backup and restore configurations, databases, and data
# Author: DigneZzZ
# Version: 1.0.0

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"
source "$SCRIPT_DIR/../core/display.sh"
source "$SCRIPT_DIR/../core/validation.sh"
source "$SCRIPT_DIR/../lib/crypto.sh"

# =============================================================================
# BACKUP FUNCTIONS
# =============================================================================

# =============================================================================
# BACKUP FUNCTIONS
# =============================================================================
# NOTE: Backup functionality now uses remnawave script
# These functions are kept for fallback compatibility only

backup_all() {
    display_error "Используйте remnawave backup для создания резервных копий"
    display_info "Установите remnawave: bash install.sh → 10) Management Scripts"
    return 1
}

restore_from_backup() {
    display_error "Используйте remnawave restore для восстановления"
    display_info "Установите remnawave: bash install.sh → 10) Management Scripts"
    return 1
}

list_backups() {
    display_error "Используйте remnawave для просмотра резервных копий"
    display_info "Установите remnawave: bash install.sh → 10) Management Scripts"
    return 1
}

delete_backup() {
    display_error "Используйте remnawave для удаления резервных копий"
    display_info "Установите remnawave: bash install.sh → 10) Management Scripts"
    return 1
}

cleanup_old_backups() {
    display_error "Используйте remnawave для очистки старых копий"
    display_info "Установите remnawave: bash install.sh → 10) Management Scripts"
    return 1
}

setup_automatic_backup() {
    display_error "Используйте remnawave для настройки автоматических резервных копий"
    display_info "Установите remnawave: bash install.sh → 10) Management Scripts"
    return 1
}

disable_automatic_backup() {
    display_error "Используйте remnawave для отключения автоматических резервных копий"
    display_info "Установите remnawave: bash install.sh → 10) Management Scripts"
    return 1
}

export_backup_to_remote() {
    display_error "Используйте remnawave для экспорта резервных копий"
    display_info "Установите remnawave: bash install.sh → 10) Management Scripts"
    return 1
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f backup_all
export -f restore_from_backup
export -f list_backups
export -f delete_backup
export -f cleanup_old_backups
export -f setup_automatic_backup
export -f disable_automatic_backup
export -f export_backup_to_remote
