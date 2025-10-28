#!/usr/bin/env bash
# Color Definitions for Remnawave Ultimate Installer
# Based on DigneZzZ style from selfsteal.sh

# Basic colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly GRAY='\033[0;37m'
readonly NC='\033[0m'

# Extended colors
readonly LIGHT_RED='\033[1;31m'
readonly LIGHT_GREEN='\033[1;32m'
readonly LIGHT_BLUE='\033[1;34m'
readonly LIGHT_PURPLE='\033[1;35m'
readonly LIGHT_CYAN='\033[1;36m'

# Background colors
readonly BG_RED='\033[41m'
readonly BG_GREEN='\033[42m'
readonly BG_YELLOW='\033[43m'
readonly BG_BLUE='\033[44m'
readonly BG_WHITE='\033[47m'

# Text styles
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly UNDERLINE='\033[4m'
readonly BLINK='\033[5m'
readonly REVERSE='\033[7m'

# Icons with colors
readonly ICON_SUCCESS="${GREEN}✅${NC}"
readonly ICON_ERROR="${RED}❌${NC}"
readonly ICON_WARNING="${YELLOW}⚠️${NC}"
readonly ICON_INFO="${BLUE}ℹ️${NC}"
readonly ICON_ROCKET="${CYAN}🚀${NC}"
readonly ICON_GEAR="${WHITE}⚙️${NC}"
readonly ICON_CHECK="${GREEN}✓${NC}"
readonly ICON_CROSS="${RED}✗${NC}"
readonly ICON_ARROW="${CYAN}→${NC}"
readonly ICON_STAR="${YELLOW}★${NC}"
readonly ICON_FOLDER="${BLUE}📁${NC}"
readonly ICON_FILE="${GRAY}📄${NC}"
readonly ICON_DOWNLOAD="${CYAN}📥${NC}"
readonly ICON_UPLOAD="${CYAN}📤${NC}"
readonly ICON_LOCK="${YELLOW}🔒${NC}"
readonly ICON_UNLOCK="${GREEN}🔓${NC}"
readonly ICON_KEY="${YELLOW}🔑${NC}"
readonly ICON_SEARCH="${WHITE}🔍${NC}"
readonly ICON_PACKAGE="${PURPLE}📦${NC}"
readonly ICON_PLUG="${BLUE}🔌${NC}"
readonly ICON_TOOL="${GRAY}🛠️${NC}"
readonly ICON_CHART="${GREEN}📊${NC}"
readonly ICON_GLOBE="${BLUE}🌐${NC}"
readonly ICON_SERVER="${PURPLE}🖥️${NC}"
readonly ICON_NETWORK="${CYAN}🌍${NC}"
readonly ICON_SHIELD="${YELLOW}🛡️${NC}"
readonly ICON_FIRE="${RED}🔥${NC}"
readonly ICON_LIGHTNING="${YELLOW}⚡${NC}"
readonly ICON_CLOCK="${GRAY}🕐${NC}"
readonly ICON_PARTY="${GREEN}🎉${NC}"
readonly ICON_THINKING="${BLUE}🤔${NC}"
readonly ICON_WRITING="${WHITE}📝${NC}"
readonly ICON_BOOK="${CYAN}📚${NC}"

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
