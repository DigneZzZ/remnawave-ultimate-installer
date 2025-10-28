#!/usr/bin/env bash
# Docker Installation Library
# Simplified Docker installation using official get.docker.com script
# Author: DigneZzZ

source "$(dirname "${BASH_SOURCE[0]}")/../core/colors.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../core/display.sh"
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

# =============================================================================
# DOCKER CHECK
# =============================================================================

check_docker_installed() {
    if command -v docker >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

check_docker_running() {
    if docker info >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

check_docker_compose() {
    if docker compose version >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

get_docker_version() {
    if check_docker_installed; then
        docker --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1
    else
        echo "not installed"
    fi
}

get_docker_compose_version() {
    if check_docker_compose; then
        docker compose version --short 2>/dev/null
    else
        echo "not installed"
    fi
}

# =============================================================================
# DOCKER INSTALLATION
# =============================================================================

install_docker() {
    log_section "Docker Installation"
    
    # Check if Docker is already installed
    if check_docker_installed && check_docker_compose; then
        local docker_version=$(get_docker_version)
        local compose_version=$(get_docker_compose_version)
        
        log_success "Docker already installed: $docker_version"
        log_info "Docker Compose: $compose_version"
        
        if check_docker_running; then
            log_success "Docker daemon is running"
            return 0
        else
            log_warning "Docker is installed but not running"
            log_info "Starting Docker service..."
            
            if systemctl start docker 2>/dev/null; then
                log_success "Docker service started"
                return 0
            else
                log_error "Failed to start Docker service"
                return 1
            fi
        fi
    fi
    
    log_info "Docker not found, installing..."
    echo
    
    # Check for conflicting packages (only snap/flatpak Docker, not official Docker)
    log_step "Checking for conflicting Docker installations..."
    
    local conflict_packages=(
        docker.io
        docker-doc
        podman-docker
    )
    
    local conflicts_found=false
    for pkg in "${conflict_packages[@]}"; do
        if command -v apt-get >/dev/null 2>&1 && dpkg -l | grep -q "^ii.*$pkg"; then
            log_warning "Found conflicting package: $pkg"
            conflicts_found=true
        fi
    done
    
    if [ "$conflicts_found" = true ]; then
        log_warning "Conflicting Docker installations detected"
        log_info "These are unofficial Docker packages that may cause issues"
        echo
        read -p "$(echo -e ${YELLOW}Remove conflicting packages? [y/N]:${NC} )" -r confirm
        
        if [[ $confirm =~ ^[Yy]$ ]]; then
            log_step "Removing conflicting packages..."
            if command -v apt-get >/dev/null 2>&1; then
                apt-get remove -y --purge "${conflict_packages[@]}" 2>/dev/null || true
                apt-get autoremove -y 2>/dev/null || true
            fi
            log_success "Conflicting packages removed"
        else
            log_warning "Skipping removal - installation may fail"
        fi
    else
        log_success "No conflicting packages found"
    fi
    echo
    
    # Install Docker using official script
    log_step "Installing Docker using official script..."
    log_info "Running: curl -fsSL https://get.docker.com | sh"
    echo
    
    # Download and run Docker installation script
    if curl -fsSL https://get.docker.com -o /tmp/get-docker.sh 2>/dev/null; then
        log_success "Docker installation script downloaded"
        
        # Make script executable
        chmod +x /tmp/get-docker.sh
        
        # Run installation
        if sh /tmp/get-docker.sh; then
            log_success "Docker installed successfully"
            
            # Clean up
            rm -f /tmp/get-docker.sh
            
            # Start and enable Docker service
            log_step "Starting Docker service..."
            
            if systemctl enable docker 2>/dev/null && systemctl start docker 2>/dev/null; then
                log_success "Docker service started and enabled"
            else
                log_warning "Could not enable Docker service automatically"
                log_info "You may need to start it manually: systemctl start docker"
            fi
            
            # Verify installation
            echo
            log_step "Verifying Docker installation..."
            
            local docker_version=$(get_docker_version)
            local compose_version=$(get_docker_compose_version)
            
            if check_docker_running; then
                log_success "Docker daemon is running"
                log_info "Docker version: $docker_version"
                log_info "Docker Compose version: $compose_version"
                echo
                log_success "Docker installation completed successfully!"
                return 0
            else
                log_error "Docker installed but not running"
                return 1
            fi
        else
            log_error "Docker installation failed"
            log_info "Please check the error messages above"
            rm -f /tmp/get-docker.sh
            return 1
        fi
    else
        log_error "Failed to download Docker installation script"
        log_info "Please check your internet connection"
        return 1
    fi
}

# =============================================================================
# DOCKER POST-INSTALL
# =============================================================================

configure_docker_permissions() {
    local user="${1:-$(logname 2>/dev/null || echo $SUDO_USER)}"
    
    if [ -z "$user" ] || [ "$user" = "root" ]; then
        log_warning "Running as root, skipping user group configuration"
        return 0
    fi
    
    log_step "Configuring Docker permissions for user: $user"
    
    # Add user to docker group
    if usermod -aG docker "$user" 2>/dev/null; then
        log_success "User $user added to docker group"
        log_warning "User needs to log out and back in for group changes to take effect"
        log_info "Or run: newgrp docker"
        return 0
    else
        log_warning "Could not add user to docker group"
        return 1
    fi
}

# =============================================================================
# DOCKER CLEANUP
# =============================================================================

docker_cleanup() {
    log_section "Docker Cleanup"
    
    log_info "Removing unused Docker resources..."
    
    # Remove stopped containers
    log_step "Removing stopped containers..."
    local stopped_containers=$(docker ps -aq -f status=exited 2>/dev/null | wc -l)
    if [ "$stopped_containers" -gt 0 ]; then
        docker container prune -f >/dev/null 2>&1
        log_success "Removed $stopped_containers stopped containers"
    else
        log_info "No stopped containers to remove"
    fi
    
    # Remove unused images
    log_step "Removing unused images..."
    local dangling_images=$(docker images -f "dangling=true" -q 2>/dev/null | wc -l)
    if [ "$dangling_images" -gt 0 ]; then
        docker image prune -f >/dev/null 2>&1
        log_success "Removed $dangling_images unused images"
    else
        log_info "No unused images to remove"
    fi
    
    # Remove unused volumes
    log_step "Removing unused volumes..."
    local unused_volumes=$(docker volume ls -qf dangling=true 2>/dev/null | wc -l)
    if [ "$unused_volumes" -gt 0 ]; then
        docker volume prune -f >/dev/null 2>&1
        log_success "Removed $unused_volumes unused volumes"
    else
        log_info "No unused volumes to remove"
    fi
    
    # Remove unused networks
    log_step "Removing unused networks..."
    docker network prune -f >/dev/null 2>&1
    log_success "Unused networks removed"
    
    echo
    log_success "Docker cleanup completed"
}

# =============================================================================
# DOCKER INFO
# =============================================================================

show_docker_info() {
    log_section "Docker Information"
    
    if ! check_docker_installed; then
        log_error "Docker is not installed"
        return 1
    fi
    
    local docker_version=$(get_docker_version)
    local compose_version=$(get_docker_compose_version)
    
    echo -e "${WHITE}Docker Version:${NC} $docker_version"
    echo -e "${WHITE}Compose Version:${NC} $compose_version"
    
    if check_docker_running; then
        echo -e "${WHITE}Status:${NC} ${GREEN}Running${NC}"
        
        # Show containers count
        local running_containers=$(docker ps -q 2>/dev/null | wc -l)
        local total_containers=$(docker ps -aq 2>/dev/null | wc -l)
        echo -e "${WHITE}Containers:${NC} $running_containers running / $total_containers total"
        
        # Show images count
        local images_count=$(docker images -q 2>/dev/null | wc -l)
        echo -e "${WHITE}Images:${NC} $images_count"
        
        # Show volumes count
        local volumes_count=$(docker volume ls -q 2>/dev/null | wc -l)
        echo -e "${WHITE}Volumes:${NC} $volumes_count"
        
        # Show disk usage
        echo
        log_info "Disk Usage:"
        docker system df 2>/dev/null | tail -n +2
    else
        echo -e "${WHITE}Status:${NC} ${RED}Not Running${NC}"
    fi
    
    echo
}

# =============================================================================
# DOCKER VALIDATION
# =============================================================================

ensure_docker() {
    if check_docker_installed && check_docker_compose && check_docker_running; then
        return 0
    fi
    
    if ! check_docker_installed; then
        log_warning "Docker is not installed"
        
        read -p "$(echo -e ${YELLOW}Install Docker now? [Y/n]:${NC} )" -r confirm
        if [[ ! $confirm =~ ^[Nn]$ ]]; then
            install_docker
            return $?
        else
            log_error "Docker installation cancelled"
            return 1
        fi
    fi
    
    if ! check_docker_running; then
        log_warning "Docker is not running"
        log_info "Starting Docker service..."
        
        if systemctl start docker 2>/dev/null; then
            log_success "Docker service started"
            return 0
        else
            log_error "Failed to start Docker service"
            return 1
        fi
    fi
    
    return 0
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f check_docker_installed
export -f check_docker_running
export -f check_docker_compose
export -f get_docker_version
export -f get_docker_compose_version
export -f install_docker
export -f configure_docker_permissions
export -f docker_cleanup
export -f show_docker_info
export -f ensure_docker
