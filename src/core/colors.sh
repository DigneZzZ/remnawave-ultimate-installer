#!/usr/bin/env bash
# Color Definitions for Remnawave Ultimate Installer
# Based on DigneZzZ style from selfsteal.sh

# Prevent double loading
[[ -n "${COLORS_LOADED}" ]] && return 0
export COLORS_LOADED=1

# Basic colors
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[1;37m'
export GRAY='\033[0;37m'
export NC='\033[0m'

# Extended colors
export LIGHT_RED='\033[1;31m'
export LIGHT_GREEN='\033[1;32m'
export LIGHT_BLUE='\033[1;34m'
export LIGHT_PURPLE='\033[1;35m'
export LIGHT_CYAN='\033[1;36m'

# Background colors
export BG_RED='\033[41m'
export BG_GREEN='\033[42m'
export BG_YELLOW='\033[43m'
export BG_BLUE='\033[44m'
export BG_WHITE='\033[47m'

# Text styles
export BOLD='\033[1m'
export DIM='\033[2m'
export UNDERLINE='\033[4m'
export BLINK='\033[5m'
export REVERSE='\033[7m'

# Icons with colors
export ICON_SUCCESS="${GREEN}✅${NC}"
export ICON_ERROR="${RED}❌${NC}"
export ICON_WARNING="${YELLOW}⚠️${NC}"
export ICON_INFO="${BLUE}ℹ️${NC}"
export ICON_ROCKET="${CYAN}🚀${NC}"
export ICON_GEAR="${WHITE}⚙️${NC}"
export ICON_CHECK="${GREEN}✓${NC}"
export ICON_CROSS="${RED}✗${NC}"
export ICON_ARROW="${CYAN}→${NC}"
export ICON_STAR="${YELLOW}★${NC}"
export ICON_FOLDER="${BLUE}📁${NC}"
export ICON_FILE="${GRAY}📄${NC}"
export ICON_DOWNLOAD="${CYAN}📥${NC}"
export ICON_UPLOAD="${CYAN}📤${NC}"
export ICON_LOCK="${YELLOW}🔒${NC}"
export ICON_UNLOCK="${GREEN}🔓${NC}"
export ICON_KEY="${YELLOW}🔑${NC}"
export ICON_SEARCH="${WHITE}🔍${NC}"
export ICON_PACKAGE="${PURPLE}📦${NC}"
export ICON_PLUG="${BLUE}🔌${NC}"
export ICON_TOOL="${GRAY}🛠️${NC}"
export ICON_CHART="${GREEN}📊${NC}"
export ICON_GLOBE="${BLUE}🌐${NC}"
export ICON_SERVER="${PURPLE}🖥️${NC}"
export ICON_NETWORK="${CYAN}🌍${NC}"
export ICON_SHIELD="${YELLOW}🛡️${NC}"
export ICON_FIRE="${RED}🔥${NC}"
export ICON_LIGHTNING="${YELLOW}⚡${NC}"
export ICON_CLOCK="${GRAY}🕐${NC}"
export ICON_PARTY="${GREEN}🎉${NC}"
export ICON_THINKING="${BLUE}🤔${NC}"
export ICON_WRITING="${WHITE}📝${NC}"
export ICON_BOOK="${CYAN}📚${NC}"

# Function to test if terminal supports colors
colors_supported() {
    [ -t 1 ] && [ "$(tput colors 2>/dev/null)" -ge 8 ]
}

# Function to strip color codes (for logging to files)
strip_colors() {
    echo -e "$1" | sed 's/\x1B\[[0-9;]*[mK]//g'
}

# Function to colorize text
colorize() {
    local color="$1"
    local text="$2"
    echo -e "${color}${text}${NC}"
}

# Export functions
export -f colors_supported
export -f strip_colors
export -f colorize
