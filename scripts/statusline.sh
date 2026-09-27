#!/bin/bash
# Statusline Kit — 配置驅動的 Claude Code 狀態列
# 設定檔：$STATUSLINE_CONFIG → ~/.claude-company/statusline-config.json → ~/.claude/statusline-config.json
set -f

input=$(cat)

if [ -z "$input" ]; then
    printf "Claude"
    exit 0
fi

mkdir -p /tmp/claude
# 儲存最新 JSON 供 session-info skill 使用
echo "$input" > /tmp/claude/statusline-last-input.json

# ── Config ───────────────────────────────────────────────────────────────────
config_file="${STATUSLINE_CONFIG:-}"
if [ -z "$config_file" ]; then
    if [ -f "$HOME/.claude-company/statusline-config.json" ]; then
        config_file="$HOME/.claude-company/statusline-config.json"
    else
        config_file="$HOME/.claude/statusline-config.json"
    fi
fi

# 設定檔沒寫到（或值為 null）的欄位：一般欄位預設開啟；usage_* 會讀 Keychain 裡的
# OAuth token，必須在設定檔明確設為 true 才執行（opt-in）。
# 設定檔不是合法 JSON 時一律退回預設值，避免整條狀態列變空白。
field_enabled() {
    local field="$1" default=true
    case "$field" in usage_*) default=false ;; esac
    if [ ! -f "$config_file" ]; then
        [ "$default" = "true" ]
        return
    fi
    local val
    val=$(jq -r --arg f "$field" --arg d "$default" \
        '(.fields // {})[$f] | if . == null then $d else tostring end' \
        "$config_file" 2>/dev/null) || val="$default"
    [ -z "$val" ] && val="$default"
    [ "$val" = "true" ]
}

# ── Base colors ───────────────────────────────────────────────────────────────
coral='\033[38;2;255;111;97m'
salmon='\033[38;2;255;160;122m'
peach='\033[38;2;255;218;185m'
rose='\033[38;2;240;128;128m'
sand='\033[38;2;210;180;140m'
teal='\033[38;2;95;158;160m'
sage='\033[38;2;143;188;143m'
amber='\033[38;2;255;191;71m'
cream='\033[38;2;245;235;220m'
muted='\033[38;2;180;160;150m'
mauve='\033[38;2;203;166;247m'
lav='\033[38;2;180;190;254m'
dim='\033[2m'
bold='\033[1m'
reset='\033[0m'

sep="${dim} · ${reset}"

# ── Rainbow engine ────────────────────────────────────────────────────────────
# HSL(h, 85%, 62%) → R G B  (pure integer math, no bc)
_hue_to_rgb() {
    local h=$1
    # 粉嫩稜鏡色：低飽和 + 高亮度（pastel rainbow）
    local s=52 l=80
    local abs_2l=$(( 2*l - 100 ))
    [ $abs_2l -lt 0 ] && abs_2l=$(( -abs_2l ))
    local C=$(( (100 - abs_2l) * s / 100 ))
    local sector=$(( h / 60 ))
    local h_mod=$(( h % 120 ))
    [ $h_mod -gt 60 ] && h_mod=$(( 120 - h_mod ))
    local X=$(( C * h_mod / 60 ))
    local m=$(( l * 255 / 100 - C * 255 / 200 ))
    [ $m -lt 0 ] && m=0
    local Cs=$(( C * 255 / 100 ))
    local Xs=$(( X * 255 / 100 ))
    local R G B
    case $sector in
        0) R=$(( Cs+m )); G=$(( Xs+m )); B=$m ;;
        1) R=$(( Xs+m )); G=$(( Cs+m )); B=$m ;;
        2) R=$m;          G=$(( Cs+m )); B=$(( Xs+m )) ;;
        3) R=$m;          G=$(( Xs+m )); B=$(( Cs+m )) ;;
        4) R=$(( Xs+m )); G=$m;          B=$(( Cs+m )) ;;
        5) R=$(( Cs+m )); G=$m;          B=$(( Xs+m )) ;;
        *) R=$m; G=$m; B=$m ;;
    esac
    [ $R -gt 255 ] && R=255; [ $G -gt 255 ] && G=255; [ $B -gt 255 ] && B=255
    printf '%d %d %d' $R $G $B
}

# Wrap each non-space character in a different hue, scrolling via timestamp
rainbow_str() {
    local text="$1"
    # 取得毫秒級時間戳（三種方式，依環境選最精確的）
    local now_ms
    # 方式1：python3（macOS 14+ 預設有，最可靠）
    now_ms=$(python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null)
    # 方式2：perl（舊版 macOS fallback，使用 %s 避免大整數截斷問題）
    if [ -z "$now_ms" ] || [ "$now_ms" -lt 1000000000000 ] 2>/dev/null; then
        now_ms=$(perl -MTime::HiRes=time -e 'use POSIX qw(floor); printf "%s", floor(time()*1000)' 2>/dev/null)
    fi
    # 方式3：純 bash（秒級精度，最後手段）
    if [ -z "$now_ms" ] || [ "$now_ms" -lt 1000000000000 ] 2>/dev/null; then
        now_ms=$(( $(date +%s) * 1000 ))
    fi
    # offset：以絕對時間戳算 hue，完整一圈 15 秒（與刷新率無關）
    #
    # 速度的硬上限：statusLine 的 refreshInterval 官方最小值就是 1（單位為秒，見
    # code.claude.com/docs/en/statusline），閒置時每秒只重繪一次，而且腳本每次
    # 執行只產生一張靜態畫面，一秒內不可能有動畫。所以每次重繪的 hue 位移＝
    # 360÷週期秒數，週期越短看起來越「跳」。
    #   9.6 秒一圈（最早的版本）→ 每秒跳 37.5 度，不是 step 的倍數，每個字各自亂換色
    #   15  秒一圈、每字 36 度  → 每秒 24 度＝⅔ 格，慢慢流動（2026-09-27 多版本並排預覽後選定）
    # 打字或 agent 在跑時有事件驅動的額外重繪（debounce 300ms），會比這更順。
    #
    # 模數必須是週期的整數倍：900000 = 60 圈 × 15000ms，
    # 回繞時剛好從 359 度接回 0 度，不會突兀跳一下。
    local ms_tail=$(( now_ms % 900000 ))
    local offset=$(( ( ms_tail * 360 / 15000 ) % 360 ))
    local step=36   # hue degrees per character：10 個字走完一整圈彩虹
    # 脈動：每 4 秒中的第 1 秒整串往白色混 55% 並加粗，下一秒恢復。
    # 只有「亮／不亮」兩個狀態，一秒一幀也不會被看成卡頓。
    local lit=false
    [ $(( now_ms / 1000 % 4 )) -eq 0 ] && lit=true
    local out="" i r g b
    for (( i=0; i<${#text}; i++ )); do
        local ch="${text:$i:1}"
        if [ "$ch" = " " ]; then
            out+=" "
        else
            local hue=$(( (offset + i * step) % 360 ))
            read -r r g b <<< "$(_hue_to_rgb $hue)"
            if $lit; then
                r=$(( r + (255 - r) * 55 / 100 ))
                g=$(( g + (255 - g) * 55 / 100 ))
                b=$(( b + (255 - b) * 55 / 100 ))
                out+="\033[1;38;2;${r};${g};${b}m${ch}"
            else
                out+="\033[38;2;${r};${g};${b}m${ch}"
            fi
        fi
    done
    printf '%b%b' "$out" "$reset"
}

# ── Premium model detection ───────────────────────────────────────────────────
is_premium() {
    local name
    name=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    # 旗艦系列：Fable 與 Opus 全系列都算高階
    echo "$name" | grep -qE "fable|opus" && return 0
    return 1
}

# ── Gradient progress bar ─────────────────────────────────────────────────────
# Filled blocks smoothly shift green → amber → coral as bar fills
# 使用全域變數 _bar_result 回傳，完全避開 $() 命令替換對 ANSI/UTF-8 的截斷問題
_bar_result=""
gradient_bar() {
    local pct=$1 width=${2:-10}
    [ "$pct" -lt 0 ] 2>/dev/null && pct=0
    [ "$pct" -gt 100 ] 2>/dev/null && pct=100
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local ESC=$'\033'
    local FILLED_CHAR=$'\xe2\x96\xb0'   # ▰  U+25B0
    local EMPTY_CHAR=$'\xe2\x96\xb1'    # ▱  U+25B1
    local i result=""
    for (( i=0; i<filled; i++ )); do
        # 顏色以「該格在整條 bar 的絕對位置」為基準（用 width，不是 filled）：
        # 這樣部分填滿時只會顯示漸變的綠色前段，唯有接近末端（接近 100%）的
        # 格子才會偏紅。與 extra 滿格時看到的完整綠→紅漸變一致。
        # 之前用 (filled-1) 當基準會讓最後一格永遠是滿紅，導致 21% 也出現紅格。
        local ratio
        if [ "$width" -gt 1 ]; then
            ratio=$(( i * 100 / (width - 1) ))
        else
            ratio=$pct
        fi
        # 兩段插值 sage → amber → coral（2026-09-04 改，原本是 sage 直接線性到 coral）
        # 直接線性插值會穿過低飽和的泥色帶：20% 處是 rgb(165,170,134)、
        # 飽和度只有 0.21（全程最低），看起來髒且與 0% 幾乎分不出來。
        # 中間插入 amber 後最低飽和度回到 0.24、中段拉到 0.72，兩端顏色不變。
        local r g b t
        if [ "$ratio" -le 50 ]; then
            t=$(( ratio * 2 ))                       # 0→100 對應 sage→amber
            r=$(( 143 + (255 - 143) * t / 100 ))
            g=$(( 188 + (191 - 188) * t / 100 ))
            b=$(( 143 - (143 -  71) * t / 100 ))
        else
            t=$(( (ratio - 50) * 2 ))                # 0→100 對應 amber→coral
            r=255
            g=$(( 191 - (191 -  97) * t / 100 ))
            b=$((  71 + ( 97 -  71) * t / 100 ))
        fi
        result+="${ESC}[1;38;2;${r};${g};${b}m${FILLED_CHAR}"
    done
    result+="${ESC}[0;2m"
    for (( i=0; i<empty; i++ )); do result+="${EMPTY_CHAR}"; done
    result+="${ESC}[0m"
    _bar_result="$result"
}

# ⚠️ 2026-09-04 起已無呼叫者（ctx 改用下方的 gradient_color_for_pct）。
# 保留備用：若哪天想要「跨過 90% 就明確變紅」的門檻式提示可以改回來，
# 但要知道代價——實測門檻處的單步色差是 161（49→50%）、82（69→70%）、
# 106（89→90%），而連續漸層版最大只有 6。
color_for_pct() {
    local pct=$1
    if   [ "$pct" -ge 90 ]; then printf '%b' "$coral"
    elif [ "$pct" -ge 70 ]; then printf '%b' "$amber"
    elif [ "$pct" -ge 50 ]; then printf '%b' "$salmon"
    else                         printf '%b' "$sage"
    fi
}

# 與 gradient_bar 完全相同的兩段插值：低用量偏綠，中段琥珀，高用量才偏紅
# 使用全域變數 _grad_color_result 回傳，避開命令替換對 ANSI 的截斷問題
# 這兩個函式的插值公式必須保持一致，改一邊就要改另一邊。
_grad_color_result=""
gradient_color_for_pct() {
    local pct=$1
    [ "$pct" -lt 0 ] 2>/dev/null && pct=0
    [ "$pct" -gt 100 ] 2>/dev/null && pct=100
    local r g b t
    if [ "$pct" -le 50 ]; then
        t=$(( pct * 2 ))                             # 0→100 對應 sage→amber
        r=$(( 143 + (255 - 143) * t / 100 ))
        g=$(( 188 + (191 - 188) * t / 100 ))
        b=$(( 143 - (143 -  71) * t / 100 ))
    else
        t=$(( (pct - 50) * 2 ))                      # 0→100 對應 amber→coral
        r=255
        g=$(( 191 - (191 -  97) * t / 100 ))
        b=$((  71 + ( 97 -  71) * t / 100 ))
    fi
    _grad_color_result=$'\033'"[38;2;${r};${g};${b}m"
}

format_tokens() {
    local num=$1
    if   [ "$num" -ge 1000000 ]; then awk "BEGIN{printf \"%.1fm\",$num/1000000}"
    elif [ "$num" -ge 1000 ];    then awk "BEGIN{printf \"%.0fk\",$num/1000}"
    else printf "%d" "$num"
    fi
}

format_duration() {
    local ms=$1
    local secs=$(( ms / 1000 ))
    if   [ "$secs" -ge 3600 ]; then printf "%dh%dm" $(( secs/3600 )) $(( (secs%3600)/60 ))
    elif [ "$secs" -ge 60 ];   then printf "%dm%ds" $(( secs/60 ))   $(( secs%60 ))
    else                            printf "%ds" "$secs"
    fi
}

# ── Extract data ──────────────────────────────────────────────────────────────
model_name=$(echo "$input" | jq -r '.model.display_name // "Claude"')
size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
[ "$size" -eq 0 ] 2>/dev/null && size=200000
input_tokens=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
cache_create=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
cache_read=$(echo "$input"   | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
current=$(( input_tokens + cache_create + cache_read ))
used_tokens=$(format_tokens $current)
total_tokens=$(format_tokens $size)
pct_used=$(( size > 0 ? current * 100 / size : 0 ))
total_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
cost_str=$(awk "BEGIN{printf \"%.2f\",$total_cost}")
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
duration_str=$(format_duration "$duration_ms")
api_ms=$(echo "$input" | jq -r '.cost.total_api_duration_ms // 0')
api_str=$(format_duration "$api_ms")
lines_added=$(echo "$input"   | jq -r '.cost.total_lines_added // 0')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
cwd=$(echo "$input" | jq -r '.cwd // ""')
[ -z "$cwd" ] || [ "$cwd" = "null" ] && cwd=$(pwd)
version=$(echo "$input" | jq -r '.version // ""')
exceeds=$(echo "$input" | jq -r '.exceeds_200k_tokens // false')

git_branch="" git_dirty=""
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
    [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ] && git_dirty="*"
fi

thinking_on=false
for settings_path in "$HOME/.claude-company/settings.json" "$HOME/.claude/settings.json"; do
    if [ -f "$settings_path" ]; then
        thinking_val=$(jq -r '.alwaysThinkingEnabled // false' "$settings_path" 2>/dev/null)
        [ "$thinking_val" = "true" ] && thinking_on=true
        break
    fi
done

# ── Pulsing thinking indicator (alternates ◈ / ◉ every second) ───────────────
thinking_icon() {
    local t=$(date +%s)
    if [ $(( t % 2 )) -eq 0 ]; then printf '◈'
    else                             printf '◉'
    fi
}

# ── Build main line ───────────────────────────────────────────────────────────
# ctx 的百分比數字改用連續漸層（2026-09-04），與 session／weekly 各行一致。
# 原本用 color_for_pct 的 4 段門檻（50/70/90%），會在跨門檻時瞬間換色，
# 而同一列其他行都是連續漸層——同一個 statusline 兩套規則並存。
# 注意：gradient 版用全域變數回傳，不能寫成 $(...)，命令替換會截斷 ANSI。
gradient_color_for_pct "$pct_used"; pct_color="$_grad_color_result"
line=""

# Model — rainbow for premium, lavender ◆ for standard
if field_enabled "model"; then
    if is_premium "$model_name"; then
        line+="$(rainbow_str "✦ ${model_name} ✦")"
    else
        line+="${lav}◆${reset} ${lav}${model_name}${reset}"
    fi
fi

# Context bar (gradient)
if field_enabled "context_bar"; then
    gradient_bar "$pct_used" 10; ctx_bar="$_bar_result"
    [ -n "$line" ] && line+="$sep"
    line+="${muted}ctx${reset} ${ctx_bar} ${pct_color}${pct_used}%${reset}"
    if field_enabled "context_tokens"; then
        line+=" ${dim}(${used_tokens}/${total_tokens})${reset}"
    fi
fi

# Cost
if field_enabled "cost"; then
    [ -n "$line" ] && line+="$sep"
    line+="${peach}\$${cost_str}${reset}"
fi

# Duration
if field_enabled "duration"; then
    [ -n "$line" ] && line+="$sep"
    line+="${dim}⧗${reset} ${sand}${duration_str}${reset}"
fi

# API duration
if field_enabled "api_duration"; then
    [ -n "$line" ] && line+="$sep"
    line+="${dim}api${reset} ${sand}${api_str}${reset}"
fi

# Lines +/-
if field_enabled "lines"; then
    if [ "$lines_added" -gt 0 ] || [ "$lines_removed" -gt 0 ]; then
        [ -n "$line" ] && line+="$sep"
        line+="${sage}+${lines_added}${reset} ${coral}-${lines_removed}${reset}"
    fi
fi

# CWD
if field_enabled "cwd"; then
    dirname=$(basename "$cwd")
    [ -n "$line" ] && line+="$sep"
    line+="${teal}${dirname}${reset}"
fi

# Git branch
if field_enabled "git_branch" && [ -n "$git_branch" ]; then
    [ -n "$line" ] && line+="$sep"
    line+="${teal}${git_branch}${reset}"
    if field_enabled "git_dirty" && [ -n "$git_dirty" ]; then
        line+="${salmon}${git_dirty}${reset}"
    fi
fi

# Thinking (pulsing)
if field_enabled "thinking"; then
    [ -n "$line" ] && line+="$sep"
    if $thinking_on; then
        line+="${mauve}$(thinking_icon) think${reset}"
    else
        line+="${dim}$(thinking_icon) think${reset}"
    fi
fi

# Version
if field_enabled "version" && [ -n "$version" ] && [ "$version" != "null" ]; then
    [ -n "$line" ] && line+="$sep"
    line+="${dim}v${version}${reset}"
fi

# Exceeds 200k
if field_enabled "exceeds_200k" && [ "$exceeds" = "true" ]; then
    [ -n "$line" ] && line+="$sep"
    line+="${coral}⚠ >200k${reset}"
fi

# ── OAuth token ───────────────────────────────────────────────────────────────
get_oauth_token() {
    [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ] && echo "$CLAUDE_CODE_OAUTH_TOKEN" && return 0
    local preferred_entry=""
    [ -f "$config_file" ] && preferred_entry=$(jq -r '.keychain_entry // empty' "$config_file" 2>/dev/null)
    if command -v security >/dev/null 2>&1; then
        if [ -n "$preferred_entry" ]; then
            local blob token
            blob=$(security find-generic-password -s "$preferred_entry" -w 2>/dev/null)
            token=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
            [ -n "$token" ] && [ "$token" != "null" ] && echo "$token" && return 0
        fi
        local blob token
        blob=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
        token=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
        [ -n "$token" ] && [ "$token" != "null" ] && echo "$token" && return 0
    fi
    if command -v secret-tool >/dev/null 2>&1; then
        local svc="${preferred_entry:-Claude Code-credentials}"
        local blob token
        blob=$(timeout 2 secret-tool lookup service "$svc" 2>/dev/null)
        token=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
        [ -n "$token" ] && [ "$token" != "null" ] && echo "$token" && return 0
    fi
    echo ""
}

iso_to_epoch() {
    local iso_str="$1" epoch
    epoch=$(date -d "${iso_str}" +%s 2>/dev/null) && echo "$epoch" && return 0
    local stripped="${iso_str%%.*}"; stripped="${stripped%%Z}"; stripped="${stripped%%+*}"
    stripped="${stripped%%-[0-9][0-9]:[0-9][0-9]}"
    if [[ "$iso_str" == *"Z"* ]] || [[ "$iso_str" == *"+00:00"* ]]; then
        epoch=$(env TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
    else
        epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
    fi
    [ -n "$epoch" ] && echo "$epoch" && return 0
    return 1
}

format_countdown() {
    local target_epoch="$1"; [ -z "$target_epoch" ] && return
    local now diff hours mins secs
    now=$(date +%s); diff=$(( target_epoch - now ))
    [ "$diff" -le 0 ] && printf "now" && return
    hours=$(( diff/3600 )); mins=$(( (diff%3600)/60 )); secs=$(( diff%60 ))
    if   [ "$hours" -gt 0 ]; then printf "%dh %02dm" "$hours" "$mins"
    elif [ "$mins"  -gt 0 ]; then printf "%dm %02ds" "$mins"  "$secs"
    else                          printf "%ds" "$secs"
    fi
}

format_reset_time() {
    local iso_str="$1"
    [ -z "$iso_str" ] || [ "$iso_str" = "null" ] && return
    local epoch; epoch=$(iso_to_epoch "$iso_str") || return
    date -j -r "$epoch" +"%a %-I:%M%p" 2>/dev/null | sed 's/\.//g' | tr '[:upper:]' '[:lower:]' || \
    date -d "@$epoch"   +"%a %-I:%M%P" 2>/dev/null | sed 's/\.//g' | tr '[:upper:]' '[:lower:]'
}

# ── Usage data (cached 60s) ───────────────────────────────────────────────────
usage_needed=false
field_enabled "usage_session" && usage_needed=true
field_enabled "usage_weekly"  && usage_needed=true
field_enabled "usage_sonnet"  && usage_needed=true
field_enabled "usage_extra"   && usage_needed=true

rate_lines=""

if $usage_needed; then
    cache_file="/tmp/claude/statusline-usage-cache.json"
    needs_refresh=true; usage_data=""
    if [ -f "$cache_file" ]; then
        cache_mtime=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null)
        cache_age=$(( $(date +%s) - cache_mtime ))
        [ "$cache_age" -lt 60 ] && needs_refresh=false && usage_data=$(cat "$cache_file" 2>/dev/null)
    fi
    if $needs_refresh; then
        token=$(get_oauth_token)
        if [ -n "$token" ] && [ "$token" != "null" ]; then
            # token 經 stdin 交給 curl，不放在指令參數裡：放參數的話，本機任何
            # 同使用者的程序都能用 ps 抓到完整憑證，而且不需要任何授權
            # （讀 Keychain 至少還要過 ACL）。
            response=$(printf '%s\n' \
                'header = "Accept: application/json"' \
                'header = "Content-Type: application/json"' \
                "header = \"Authorization: Bearer ${token}\"" \
                'header = "anthropic-beta: oauth-2025-04-20"' \
                'header = "User-Agent: claude-code/2.1.34"' \
                'silent' \
                'max-time = 5' \
                'url = "https://api.anthropic.com/api/oauth/usage"' \
                | curl --config - 2>/dev/null)
            if [ -n "$response" ] && echo "$response" | jq -e 'has("five_hour")' >/dev/null 2>&1; then
                usage_data="$response"
                echo "$response" > "$cache_file"
            fi
        fi
        [ -z "$usage_data" ] && [ -f "$cache_file" ] && usage_data=$(cat "$cache_file" 2>/dev/null)
    fi

    if [ -n "$usage_data" ] && echo "$usage_data" | jq -e . >/dev/null 2>&1; then
        bar_width=10

        if field_enabled "usage_session"; then
            five_null=$(echo "$usage_data" | jq -r '.five_hour // "null"')
            if [ "$five_null" != "null" ]; then
                five_pct=$(echo "$usage_data" | jq -r '.five_hour.utilization // 0' | awk '{printf "%.0f",$1}')
                five_reset_iso=$(echo "$usage_data" | jq -r '.five_hour.resets_at // empty')
                five_epoch=$(iso_to_epoch "$five_reset_iso" 2>/dev/null)
                five_cd=$(format_countdown "$five_epoch")
                gradient_bar "$five_pct" "$bar_width"; five_bar="$_bar_result"
                gradient_color_for_pct "$five_pct"; five_color="$_grad_color_result"
                rate_lines+="${cream}session   ${reset} ${five_bar} ${five_color}$(printf "%3d" "$five_pct")%${reset}"
                [ -n "$five_cd" ] && rate_lines+="  ${dim}resets in${reset} ${peach}${five_cd}${reset}"
            fi
        fi

        if field_enabled "usage_weekly"; then
            week_null=$(echo "$usage_data" | jq -r '.seven_day // "null"')
            if [ "$week_null" != "null" ]; then
                week_pct=$(echo "$usage_data" | jq -r '.seven_day.utilization // 0' | awk '{printf "%.0f",$1}')
                week_reset_iso=$(echo "$usage_data" | jq -r '.seven_day.resets_at // empty')
                week_reset=$(format_reset_time "$week_reset_iso")
                gradient_bar "$week_pct" "$bar_width"; week_bar="$_bar_result"
                gradient_color_for_pct "$week_pct"; week_color="$_grad_color_result"
                [ -n "$rate_lines" ] && rate_lines+="\n"
                rate_lines+="${cream}weekly ${dim}all${reset} ${week_bar} ${week_color}$(printf "%3d" "$week_pct")%${reset}"
                [ -n "$week_reset" ] && rate_lines+="  ${dim}resets${reset} ${peach}${week_reset}${reset}"
            fi
        fi

        if field_enabled "usage_sonnet"; then
            son_pct=$(echo "$usage_data" | jq -r '.seven_day_sonnet.utilization // empty' | awk '{if($1!="")printf "%.0f",$1}')
            [ -z "$son_pct" ] && son_pct=$(echo "$usage_data" | jq -r '.sonnet.utilization // empty' | awk '{if($1!="")printf "%.0f",$1}')
            if [ -n "$son_pct" ]; then
                son_reset_iso=$(echo "$usage_data" | jq -r '.seven_day_sonnet.resets_at // .sonnet.resets_at // empty')
                son_reset=$(format_reset_time "$son_reset_iso")
                gradient_bar "$son_pct" "$bar_width"; son_bar="$_bar_result"
                gradient_color_for_pct "$son_pct"; son_color="$_grad_color_result"
                [ -n "$rate_lines" ] && rate_lines+="\n"
                rate_lines+="${cream}weekly ${teal}son${reset} ${son_bar} ${son_color}$(printf "%3d" "$son_pct")%${reset}"
                [ -n "$son_reset" ] && rate_lines+="  ${dim}resets${reset} ${peach}${son_reset}${reset}"
            fi
        fi

        if field_enabled "usage_extra"; then
            extra_enabled=$(echo "$usage_data" | jq -r '.extra_usage.is_enabled // false')
            if [ "$extra_enabled" = "true" ]; then
                extra_pct=$(echo "$usage_data" | jq -r '.extra_usage.utilization // 0' | awk '{printf "%.0f",$1}')
                extra_used=$(echo "$usage_data" | jq -r '.extra_usage.used_credits // 0' | awk '{printf "%.2f",$1/100}')
                extra_limit=$(echo "$usage_data" | jq -r '.extra_usage.monthly_limit // 0' | awk '{printf "%.2f",$1/100}')
                gradient_bar "$extra_pct" "$bar_width"; extra_bar="$_bar_result"
                gradient_color_for_pct "$extra_pct"; extra_color="$_grad_color_result"
                [ -n "$rate_lines" ] && rate_lines+="\n"
                rate_lines+="${cream}extra     ${reset} ${extra_bar} ${extra_color}\$${extra_used}${dim}/\$${extra_limit}${reset}"
            fi
        fi
    fi
fi

# ── Output ────────────────────────────────────────────────────────────────────
printf "%b" "$line"

if [ -n "$rate_lines" ]; then
    # 用量區緊貼主行（僅單一換行，無額外空行）
    printf "\n%b" "$rate_lines"
fi

exit 0
