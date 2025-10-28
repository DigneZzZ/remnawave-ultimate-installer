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

backup_all() {
    local backup_name="${1:-backup-$(date +%Y%m%d-%H%M%S)}"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    display_section "$ICON_BACKUP" "Создание резервной копии"
    
    mkdir -p "$backup_path"
    
    # Backup panel if installed
    if is_installed "panel"; then
        display_step "Резервное копирование панели..."
        backup_panel "$backup_path"
    fi
    
    # Backup node if installed
    if is_installed "node"; then
        display_step "Резервное копирование node..."
        backup_node "$backup_path"
    fi
    
    # Backup caddy if installed
    if is_installed "caddy"; then
        display_step "Резервное копирование Caddy..."
        backup_caddy "$backup_path"
    fi
    
    # Backup nginx if installed
    if is_installed "nginx"; then
        display_step "Резервное копирование NGINX..."
        backup_nginx "$backup_path"
    fi
    
    # Create archive
    display_step "Создание архива..."
    cd "$BACKUP_DIR" || return 1
    tar -czf "${backup_name}.tar.gz" "$backup_name"
    rm -rf "$backup_path"
    
    local backup_size=$(du -h "${backup_name}.tar.gz" | cut -f1)
    
    display_success "Резервная копия создана"
    display_info "Файл: $BACKUP_DIR/${backup_name}.tar.gz"
    display_info "Размер: $backup_size"
    
    return 0
}

backup_panel() {
    local backup_path="$1"
    local panel_backup="$backup_path/panel"
    
    mkdir -p "$panel_backup"
    
    # Backup configuration
    if [ -f "$PANEL_DIR/.env" ]; then
        cp "$PANEL_DIR/.env" "$panel_backup/"
    fi
    
    if [ -f "$PANEL_DIR/docker-compose.yml" ]; then
        cp "$PANEL_DIR/docker-compose.yml" "$panel_backup/"
    fi
    
    # Backup database
    if docker ps | grep -q "$DB_CONTAINER"; then
        display_step "Экспорт базы данных..."
        docker exec "$DB_CONTAINER" pg_dump -U "$DEFAULT_DB_USER" "$DEFAULT_DB_NAME" > "$panel_backup/database.sql"
    fi
    
    # Backup panel data
    if [ -d "$PANEL_DIR/data" ]; then
        cp -r "$PANEL_DIR/data" "$panel_backup/"
    fi
    
    display_success "Панель скопирована"
}

backup_node() {
    local backup_path="$1"
    local node_backup="$backup_path/node"
    
    mkdir -p "$node_backup"
    
    # Backup configuration
    if [ -f "$NODE_DIR/.env" ]; then
        cp "$NODE_DIR/.env" "$node_backup/"
    fi
    
    if [ -f "$NODE_DIR/docker-compose.yml" ]; then
        cp "$NODE_DIR/docker-compose.yml" "$node_backup/"
    fi
    
    # Backup Xray config if exists
    if [ -f "$NODE_DIR/xray/config.json" ]; then
        mkdir -p "$node_backup/xray"
        cp "$NODE_DIR/xray/config.json" "$node_backup/xray/"
    fi
    
    # Backup node data
    if [ -d "$NODE_DIR/data" ]; then
        cp -r "$NODE_DIR/data" "$node_backup/"
    fi
    
    display_success "Node скопирован"
}

backup_caddy() {
    local backup_path="$1"
    local caddy_backup="$backup_path/caddy"
    
    mkdir -p "$caddy_backup"
    
    # Backup Caddyfile
    if [ -f "$CADDY_DIR/config/Caddyfile" ]; then
        cp "$CADDY_DIR/config/Caddyfile" "$caddy_backup/"
    fi
    
    # Backup docker-compose
    if [ -f "$CADDY_DIR/docker-compose.yml" ]; then
        cp "$CADDY_DIR/docker-compose.yml" "$caddy_backup/"
    fi
    
    # Backup static site
    if [ -d "$CADDY_DIR/html" ]; then
        cp -r "$CADDY_DIR/html" "$caddy_backup/"
    fi
    
    display_success "Caddy скопирован"
}

backup_nginx() {
    local backup_path="$1"
    local nginx_backup="$backup_path/nginx"
    
    mkdir -p "$nginx_backup"
    
    # Backup nginx configs
    if [ -d "$NGINX_DIR/conf.d" ]; then
        cp -r "$NGINX_DIR/conf.d" "$nginx_backup/"
    fi
    
    # Backup docker-compose
    if [ -f "$NGINX_DIR/docker-compose.yml" ]; then
        cp "$NGINX_DIR/docker-compose.yml" "$nginx_backup/"
    fi
    
    display_success "NGINX скопирован"
}

# =============================================================================
# RESTORE FUNCTIONS
# =============================================================================

restore_from_backup() {
    local backup_file="$1"
    
    display_section "$ICON_RESTORE" "Восстановление из резервной копии"
    
    # Validate backup file
    if ! validate_file_exists "$backup_file"; then
        display_error "Файл резервной копии не найден: $backup_file"
        return 1
    fi
    
    # Extract archive
    display_step "Извлечение архива..."
    local temp_dir="/tmp/remnawave-restore-$$"
    mkdir -p "$temp_dir"
    
    tar -xzf "$backup_file" -C "$temp_dir"
    
    # Find backup directory
    local backup_dir=$(find "$temp_dir" -maxdepth 1 -type d ! -path "$temp_dir" | head -n1)
    
    if [ -z "$backup_dir" ]; then
        display_error "Неверная структура резервной копии"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Restore panel if exists
    if [ -d "$backup_dir/panel" ]; then
        display_step "Восстановление панели..."
        restore_panel "$backup_dir/panel"
    fi
    
    # Restore node if exists
    if [ -d "$backup_dir/node" ]; then
        display_step "Восстановление node..."
        restore_node "$backup_dir/node"
    fi
    
    # Restore caddy if exists
    if [ -d "$backup_dir/caddy" ]; then
        display_step "Восстановление Caddy..."
        restore_caddy "$backup_dir/caddy"
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    
    display_success "Восстановление завершено"
    display_warning "Перезапустите сервисы: docker compose restart"
    
    return 0
}

restore_panel() {
    local backup_path="$1"
    
    # Restore configuration
    if [ -f "$backup_path/.env" ]; then
        cp "$backup_path/.env" "$PANEL_DIR/"
    fi
    
    if [ -f "$backup_path/docker-compose.yml" ]; then
        cp "$backup_path/docker-compose.yml" "$PANEL_DIR/"
    fi
    
    # Restore database
    if [ -f "$backup_path/database.sql" ]; then
        if docker ps | grep -q "$DB_CONTAINER"; then
            display_step "Импорт базы данных..."
            docker exec -i "$DB_CONTAINER" psql -U "$DEFAULT_DB_USER" "$DEFAULT_DB_NAME" < "$backup_path/database.sql"
        else
            display_warning "База данных не запущена, пропускаем импорт"
        fi
    fi
    
    # Restore data
    if [ -d "$backup_path/data" ]; then
        cp -r "$backup_path/data" "$PANEL_DIR/"
    fi
    
    display_success "Панель восстановлена"
}

restore_node() {
    local backup_path="$1"
    
    # Restore configuration
    if [ -f "$backup_path/.env" ]; then
        cp "$backup_path/.env" "$NODE_DIR/"
    fi
    
    if [ -f "$backup_path/docker-compose.yml" ]; then
        cp "$backup_path/docker-compose.yml" "$NODE_DIR/"
    fi
    
    # Restore Xray config
    if [ -f "$backup_path/xray/config.json" ]; then
        mkdir -p "$NODE_DIR/xray"
        cp "$backup_path/xray/config.json" "$NODE_DIR/xray/"
    fi
    
    # Restore data
    if [ -d "$backup_path/data" ]; then
        cp -r "$backup_path/data" "$NODE_DIR/"
    fi
    
    display_success "Node восстановлен"
}

restore_caddy() {
    local backup_path="$1"
    
    # Restore Caddyfile
    if [ -f "$backup_path/Caddyfile" ]; then
        mkdir -p "$CADDY_DIR/config"
        cp "$backup_path/Caddyfile" "$CADDY_DIR/config/"
    fi
    
    # Restore docker-compose
    if [ -f "$backup_path/docker-compose.yml" ]; then
        cp "$backup_path/docker-compose.yml" "$CADDY_DIR/"
    fi
    
    # Restore static site
    if [ -d "$backup_path/html" ]; then
        cp -r "$backup_path/html" "$CADDY_DIR/"
    fi
    
    display_success "Caddy восстановлен"
}

# =============================================================================
# BACKUP MANAGEMENT
# =============================================================================

list_backups() {
    display_section "$ICON_LIST" "Список резервных копий"
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        display_warning "Резервные копии не найдены"
        return 1
    fi
    
    echo
    display_table_header "Имя|Размер|Дата" "30|10|20"
    
    for backup in "$BACKUP_DIR"/*.tar.gz; do
        if [ -f "$backup" ]; then
            local name=$(basename "$backup" .tar.gz)
            local size=$(du -h "$backup" | cut -f1)
            local date=$(stat -c %y "$backup" 2>/dev/null || stat -f %Sm "$backup" 2>/dev/null)
            display_table_row "$name|$size|$date" "30|10|20"
        fi
    done
    
    echo
}

delete_backup() {
    local backup_name="$1"
    local backup_file="$BACKUP_DIR/${backup_name}.tar.gz"
    
    if ! validate_file_exists "$backup_file"; then
        display_error "Резервная копия не найдена: $backup_name"
        return 1
    fi
    
    if confirm_action "Удалить резервную копию $backup_name?" "n"; then
        rm -f "$backup_file"
        display_success "Резервная копия удалена"
    fi
}

cleanup_old_backups() {
    local keep_count="${1:-$BACKUP_RETENTION}"
    
    display_step "Очистка старых резервных копий..."
    
    local backup_count=$(ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | wc -l)
    
    if [ "$backup_count" -le "$keep_count" ]; then
        display_info "Нет старых копий для удаления"
        return 0
    fi
    
    # Delete oldest backups
    ls -1t "$BACKUP_DIR"/*.tar.gz | tail -n +$((keep_count + 1)) | xargs rm -f
    
    local deleted=$((backup_count - keep_count))
    display_success "Удалено старых копий: $deleted"
}

# =============================================================================
# AUTOMATED BACKUPS
# =============================================================================

setup_automatic_backup() {
    local schedule="${1:-$BACKUP_SCHEDULE}"
    
    display_section "$ICON_CLOCK" "Настройка автоматического резервного копирования"
    
    # Create backup script
    cat > "/usr/local/bin/remnawave-backup" <<'EOF'
#!/bin/bash
# Automatic Remnawave Backup Script

BACKUP_DIR="/opt/remnawave/backups"
RETENTION=7

# Source the backup module
source /opt/remnawave/remnawave-ultimate.sh

# Create backup
backup_all "auto-backup-$(date +%Y%m%d-%H%M%S)"

# Cleanup old backups
cleanup_old_backups $RETENTION
EOF
    
    chmod +x "/usr/local/bin/remnawave-backup"
    
    # Add cron job
    local cron_job="$schedule /usr/local/bin/remnawave-backup >> /var/log/remnawave-backup.log 2>&1"
    
    (crontab -l 2>/dev/null | grep -v "remnawave-backup"; echo "$cron_job") | crontab -
    
    display_success "Автоматическое резервное копирование настроено"
    display_info "Расписание: $schedule"
    display_info "Логи: /var/log/remnawave-backup.log"
}

disable_automatic_backup() {
    display_step "Отключение автоматического резервного копирования..."
    
    crontab -l 2>/dev/null | grep -v "remnawave-backup" | crontab -
    
    if [ -f "/usr/local/bin/remnawave-backup" ]; then
        rm -f "/usr/local/bin/remnawave-backup"
    fi
    
    display_success "Автоматическое резервное копирование отключено"
}

# =============================================================================
# EXPORT BACKUPS
# =============================================================================

export_backup_to_remote() {
    local backup_file="$1"
    local remote_path="$2"
    
    display_step "Экспорт резервной копии..."
    
    if command -v scp >/dev/null 2>&1; then
        scp "$backup_file" "$remote_path"
        display_success "Резервная копия экспортирована"
    else
        display_error "SCP не установлен"
        return 1
    fi
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f backup_all
export -f backup_panel
export -f backup_node
export -f backup_caddy
export -f backup_nginx
export -f restore_from_backup
export -f restore_panel
export -f restore_node
export -f restore_caddy
export -f list_backups
export -f delete_backup
export -f cleanup_old_backups
export -f setup_automatic_backup
export -f disable_automatic_backup
export -f export_backup_to_remote
