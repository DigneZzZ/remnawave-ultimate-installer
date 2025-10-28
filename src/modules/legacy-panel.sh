#!/usr/bin/env bash
# Legacy Panel Installation using original remnawave.sh
# This module wraps the original installation script for Panel + Subscription Page
# Author: DigneZzZ
# Version: 1.0.0

# Prevent double loading
[[ -n "${LEGACY_PANEL_LOADED}" ]] && return 0
readonly LEGACY_PANEL_LOADED=1

install_panel_with_subscription() {
    local root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    local legacy_script="$root_dir/remnawave.sh"
    
    if [ ! -f "$legacy_script" ]; then
        display_error "remnawave.sh not found at: $legacy_script"
        return 1
    fi
    
    # Source the legacy script functions
    # We'll extract and call specific functions for Panel installation
    
    display_step "Using original remnawave.sh for Panel + Subscription Page installation"
    
    # Execute the legacy installer in non-interactive mode
    bash "$legacy_script"
}

export -f install_panel_with_subscription
