#!/usr/bin/env bash
# Display Functions Library
# Beautiful terminal UI for Remnawave Ultimate Installer
# Author: DigneZzZ
# Based on DigneZzZ style with enhancements from both eGames and xxphantom

# Prevent double loading
[[ -n "${DISPLAY_LOADED}" ]] && return 0
readonly DISPLAY_LOADED=1

# Source colors
source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

# =============================================================================
# BANNER & HEADERS
# =============================================================================

display_banner() {
    local version="${1:-1.0.0}"
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${WHITE}🚀 Remnawave Ultimate Installer v${version}${NC}                 ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo
}

display_header() {
    local title="$1"
    local width="${2:-50}"
    echo
    echo -e "${WHITE}${title}${NC}"
    printf "${GRAY}%${width}s${NC}\n" | tr ' ' '─'
    echo
}

display_section() {
    local icon="$1"
    local title="$2"
    echo
    echo -e "${WHITE}${icon} ${title}${NC}"
    echo -e "${GRAY}$(printf '─%.0s' $(seq 1 40))${NC}"
    echo
}

# =============================================================================
# BOXES & FRAMES
# =============================================================================

display_box() {
    local title="$1"
    local content="$2"
    local width="${3:-60}"
    
    echo -e "${CYAN}╔$(printf '═%.0s' $(seq 1 $((width-2))))╗${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}${title}${NC}$(printf ' %.0s' $(seq 1 $((width-${#title}-3))))${CYAN}║${NC}"
    echo -e "${CYAN}╠$(printf '═%.0s' $(seq 1 $((width-2))))╣${NC}"
    
    # Print content lines
    while IFS= read -r line; do
        echo -e "${CYAN}║${NC} ${line}$(printf ' %.0s' $(seq 1 $((width-${#line}-3))))${CYAN}║${NC}"
    done <<< "$content"
    
    echo -e "${CYAN}╚$(printf '═%.0s' $(seq 1 $((width-2))))╝${NC}"
}

display_info_box() {
    local content="$1"
    echo
    echo -e "${BLUE}┌─────────────────────────────────────────┐${NC}"
    while IFS= read -r line; do
        printf "${BLUE}│${NC} ${GRAY}%-40s${NC} ${BLUE}│${NC}\n" "$line"
    done <<< "$content"
    echo -e "${BLUE}└─────────────────────────────────────────┘${NC}"
    echo
}

# =============================================================================
# LISTS & MENUS
# =============================================================================

display_menu_item() {
    local number="$1"
    local title="$2"
    local description="$3"
    
    if [ -n "$description" ]; then
        printf "   ${CYAN}%-3s${NC} ${WHITE}%-20s${NC} ${GRAY}%s${NC}\n" "$number" "$title" "$description"
    else
        printf "   ${CYAN}%-3s${NC} ${WHITE}%s${NC}\n" "$number" "$title"
    fi
}

display_separator() {
    local title="${1:-}"
    local width="${2:-40}"
    
    if [ -n "$title" ]; then
        echo -e "${GRAY}   ${title}${NC}"
    fi
    echo -e "${GRAY}   $(printf '─%.0s' $(seq 1 $width))${NC}"
}

display_list_item() {
    local icon="$1"
    local text="$2"
    echo -e "${GRAY}   ${icon} ${text}${NC}"
}

# =============================================================================
# STATUS MESSAGES
# =============================================================================

display_success() {
    local message="$1"
    echo -e "${ICON_SUCCESS} ${GREEN}${message}${NC}"
}

display_error() {
    local message="$1"
    echo -e "${ICON_ERROR} ${RED}${message}${NC}"
}

display_warning() {
    local message="$1"
    echo -e "${ICON_WARNING} ${YELLOW}${message}${NC}"
}

display_info() {
    local message="$1"
    echo -e "${ICON_INFO} ${BLUE}${message}${NC}"
}

display_step() {
    local message="$1"
    echo -e "${ICON_ARROW} ${WHITE}${message}${NC}"
}

display_progress() {
    local current="$1"
    local total="$2"
    local message="$3"
    
    local percent=$((current * 100 / total))
    local filled=$((percent / 5))
    local empty=$((20 - filled))
    
    printf "\r${CYAN}[${NC}"
    printf "${GREEN}%${filled}s${NC}" | tr ' ' '█'
    printf "${GRAY}%${empty}s${NC}" | tr ' ' '░'
    printf "${CYAN}]${NC} ${WHITE}%3d%%${NC} ${GRAY}%s${NC}" "$percent" "$message"
    
    [ "$current" -eq "$total" ] && echo
}

# =============================================================================
# TABLES
# =============================================================================

display_table_header() {
    local col1_width="${1:-20}"
    local col2_width="${2:-40}"
    
    echo -e "${GRAY}$(printf '─%.0s' $(seq 1 $((col1_width + col2_width + 3))))${NC}"
}

display_table_row() {
    local key="$1"
    local value="$2"
    local key_width="${3:-20}"
    
    printf "   ${WHITE}%-${key_width}s${NC} ${GRAY}%s${NC}\n" "$key:" "$value"
}

display_table() {
    local -n data=$1
    local key_width="${2:-20}"
    
    display_table_header "$key_width" 40
    
    for key in "${!data[@]}"; do
        display_table_row "$key" "${data[$key]}" "$key_width"
    done
    
    display_table_header "$key_width" 40
}

# =============================================================================
# SUMMARY & REPORTS
# =============================================================================

display_summary() {
    local title="$1"
    shift
    local -a items=("$@")
    
    echo
    echo -e "${WHITE}📋 ${title}${NC}"
    display_separator "" 50
    
    for item in "${items[@]}"; do
        IFS='|' read -r key value <<< "$item"
        display_table_row "$key" "$value" 25
    done
    
    echo
}

display_completion() {
    local title="$1"
    local message="$2"
    
    echo
    echo -e "${GRAY}$(printf '─%.0s' $(seq 1 60))${NC}"
    echo -e "${WHITE}${ICON_PARTY} ${title}${NC}"
    echo -e "${GRAY}$(printf '─%.0s' $(seq 1 60))${NC}"
    echo
    
    if [ -n "$message" ]; then
        echo -e "${GRAY}${message}${NC}"
        echo
    fi
}

# =============================================================================
# PROMPTS
# =============================================================================

display_prompt() {
    local message="$1"
    local default="$2"
    
    if [ -n "$default" ]; then
        echo -ne "${WHITE}${message}${NC} ${GRAY}[${default}]${NC}: "
    else
        echo -ne "${WHITE}${message}${NC}: "
    fi
}

display_confirm() {
    local message="$1"
    local default="${2:-n}"
    
    if [[ "$default" =~ ^[Yy]$ ]]; then
        echo -ne "${WHITE}${message}${NC} ${GRAY}[Y/n]${NC}: "
    else
        echo -ne "${WHITE}${message}${NC} ${GRAY}[y/N]${NC}: "
    fi
}

# =============================================================================
# SPINNERS & LOADING
# =============================================================================

display_spinner() {
    local pid=$1
    local message="${2:-Processing}"
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\r${CYAN}[%c]${NC} ${GRAY}%s${NC}" "$spinstr" "$message"
        spinstr=$temp${spinstr%"$temp"}
        sleep 0.1
    done
    
    printf "\r"
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

display_divider() {
    local char="${1:-─}"
    local width="${2:-60}"
    echo -e "${GRAY}$(printf "${char}%.0s" $(seq 1 width))${NC}"
}

display_blank_lines() {
    local count="${1:-1}"
    printf '\n%.0s' $(seq 1 "$count")
}

clear_line() {
    printf "\r\033[K"
}

display_animated_dots() {
    local duration="${1:-3}"
    local message="${2:-Loading}"
    
    for i in $(seq 1 "$duration"); do
        printf "\r${WHITE}${message}${NC}${CYAN}.${NC}  "
        sleep 0.3
        printf "\r${WHITE}${message}${NC}${CYAN}..${NC} "
        sleep 0.3
        printf "\r${WHITE}${message}${NC}${CYAN}...${NC}"
        sleep 0.3
        printf "\r${WHITE}${message}${NC}   "
    done
    echo
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f display_banner
export -f display_header
export -f display_section
export -f display_box
export -f display_info_box
export -f display_menu_item
export -f display_separator
export -f display_list_item
export -f display_success
export -f display_error
export -f display_warning
export -f display_info
export -f display_step
export -f display_progress
export -f display_table_header
export -f display_table_row
export -f display_table
export -f display_summary
export -f display_completion
export -f display_prompt
export -f display_confirm
export -f display_spinner
export -f display_divider
export -f display_blank_lines
export -f clear_line
export -f display_animated_dots
