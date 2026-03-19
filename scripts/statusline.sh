#!/bin/bash
# Statusline Kit — 配置驅動的 Claude Code 狀態列
# 設定檔自動偵測: ~/.claude-company/statusline-config.json → ~/.claude/statusline-config.json
set -f

input=$(cat)

if [ -z "$input" ]; then
    printf "Claude"
    exit 0
fi

# 儲存最新 JSON 供 session-info skill 使用
mkdir -p /tmp/claude
echo "$input" > /tmp/claude/statusline-last-input.json

# ── 設定檔路徑解析 ─────────────────────────────────────
# 優先使用環境變數，否則依序嘗試 ~/.claude-company → ~/.claude
config_file="${STATUSLINE_CONFIG:-}"
if [ -z "$config_file" ]; then
    if [ -f "$HOME/.claude-company/statusline-config.json" ]; then
        config_file="$HOME/.claude-company/statusline-config.json"
    elif [ -f "$HOME/.claude/statusline-config.json" ]; then
        config_file="$HOME/.claude/statusline-config.json"
    fi
fi

field_enabled() {
    local field="$1"
    if [ -n "$config_file" ] && [ -f "$config_file" ]; then
        local val
        val=$(jq -r ".fields.${field} // true" "$config_file" 2>/dev/null)
        [ "$val" = "true" ] && return 0
        return 1
    fi
    # 無設定檔時預設全開
    return 0
}

# ── Colors ──────────────────────────────────────────────
blue='\033[38;2;0;153;255m'
orange='\033[38;2;255;176;85m'
green='\033[38;2;0;175;80m'
cyan='\033[38;2;86;182;194m'
red='\033[38;2;255;85;85m'
yellow='\033[38;2;230;200;0m'
white='\033[38;2;220;220;220m'
magenta='\033[38;2;180;140;255m'
dim='\033[2m'
reset='\033[0m'

sep=" ${dim}│${reset} "

# ── Helpers ─────────────────────────────────────────────
format_tokens() {
    local num=$1
    if [ "$num" -ge 1000000 ]; then
        awk "BEGIN {printf \"%.1fm\", $num / 1000000}"
    elif [ "$num" -ge 1000 ]; then
        awk "BEGIN {printf \"%.0fk\", $num / 1000}"
    else
        printf "%d" "$num"
    fi
}

color_for_pct() {
    local pct=$1
    if [ "$pct" -ge 90 ]; then printf "$red"
    elif [ "$pct" -ge 70 ]; then printf "$yellow"
    elif [ "$pct" -ge 50 ]; then printf "$orange"
    else printf "$green"
    fi
}

build_bar() {
    local pct=$1
    local width=$2
    [ "$pct" -lt 0 ] 2>/dev/null && pct=0
    [ "$pct" -gt 100 ] 2>/dev/null && pct=100

    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local bar_color
    bar_color=$(color_for_pct "$pct")

    local filled_str="" empty_str=""
    for ((i=0; i<filled; i++)); do filled_str+="●"; done
    for ((i=0; i<empty; i++)); do empty_str+="○"; done

    printf "${bar_color}${filled_str}${dim}${empty_str}${reset}"
}

format_duration() {
    local ms=$1
    local secs=$(( ms / 1000 ))
    if [ "$secs" -ge 3600 ]; then
        printf "%dh%dm" $(( secs / 3600 )) $(( (secs % 3600) / 60 ))
    elif [ "$secs" -ge 60 ]; then
        printf "%dm%ds" $(( secs / 60 )) $(( secs % 60 ))
    else
        printf "%ds" "$secs"
    fi
}

# ── Extract all data ────────────────────────────────────
model_name=$(echo "$input" | jq -r '.model.display_name // "Claude"')

size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
[ "$size" -eq 0 ] 2>/dev/null && size=200000

input_tokens=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
cache_create=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
current=$(( input_tokens + cache_create + cache_read ))

used_tokens=$(format_tokens $current)
total_tokens=$(format_tokens $size)

if [ "$size" -gt 0 ]; then
    pct_used=$(( current * 100 / size ))
else
    pct_used=0
fi

total_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
cost_str=$(awk "BEGIN {printf \"%.2f\", $total_cost}")

duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
duration_str=$(format_duration "$duration_ms")

api_ms=$(echo "$input" | jq -r '.cost.total_api_duration_ms // 0')
api_str=$(format_duration "$api_ms")

lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

cwd=$(echo "$input" | jq -r '.cwd // ""')
[ -z "$cwd" ] || [ "$cwd" = "null" ] && cwd=$(pwd)

version=$(echo "$input" | jq -r '.version // ""')
exceeds=$(echo "$input" | jq -r '.exceeds_200k_tokens // false')

git_branch=""
git_dirty=""
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
    if [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ]; then
        git_dirty="*"
    fi
fi

# Thinking 狀態 — 依序嘗試多個 settings 路徑
thinking_on=false
for sp in "$HOME/.claude-company/settings.json" "$HOME/.claude/settings.json"; do
    if [ -f "$sp" ]; then
        thinking_val=$(jq -r '.alwaysThinkingEnabled // false' "$sp" 2>/dev/null)
        [ "$thinking_val" = "true" ] && thinking_on=true
        break
    fi
done

# ── Build output ────────────────────────────────────────
pct_color=$(color_for_pct "$pct_used")
line=""

append() {
    [ -n "$line" ] && line+="${sep}"
    line+="$1"
}

# Model
field_enabled "model" && append "${blue}${model_name}${reset}"

# Context bar
if field_enabled "context_bar"; then
    ctx_bar=$(build_bar "$pct_used" 10)
    local_seg="ctx ${ctx_bar} ${pct_color}${pct_used}%${reset}"
    if field_enabled "context_tokens"; then
        local_seg+=" ${dim}(${used_tokens}/${total_tokens})${reset}"
    fi
    append "$local_seg"
fi

# Cost
field_enabled "cost" && append "${white}\$${cost_str}${reset}"

# Duration
field_enabled "duration" && append "${dim}⏱${reset} ${white}${duration_str}${reset}"

# API duration
field_enabled "api_duration" && append "${dim}API${reset} ${white}${api_str}${reset}"

# Lines +/-
if field_enabled "lines"; then
    if [ "$lines_added" -gt 0 ] || [ "$lines_removed" -gt 0 ]; then
        append "${green}+${lines_added}${reset} ${red}-${lines_removed}${reset}"
    fi
fi

# Git branch
if field_enabled "git_branch" && [ -n "$git_branch" ]; then
    local_seg="${cyan}${git_branch}${reset}"
    field_enabled "git_dirty" && [ -n "$git_dirty" ] && local_seg+="${red}${git_dirty}${reset}"
    append "$local_seg"
fi

# Thinking
if field_enabled "thinking"; then
    if $thinking_on; then
        append "${magenta}◐ thinking${reset}"
    else
        append "${dim}◑ thinking${reset}"
    fi
fi

# Version
if field_enabled "version" && [ -n "$version" ] && [ "$version" != "null" ]; then
    append "${dim}v${version}${reset}"
fi

# Exceeds 200k warning
field_enabled "exceeds_200k" && [ "$exceeds" = "true" ] && append "${red}⚠ >200k${reset}"

printf "%b" "$line"
exit 0
