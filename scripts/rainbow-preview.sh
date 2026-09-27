#!/bin/bash
# 彩虹狀態列多版本並排預覽：在同一個終端機裡並排比較模型名稱的各種上色／動畫效果
# 用法：bash rainbow-preview.sh [idle|active] [秒數]
#   請在平常跑 Claude Code 的終端機另開分頁執行（不要用 Claude Code 的 `!` 前綴，看不到動畫）
#   idle   每 1 秒重繪一次（= refreshInterval: 1 閒置時的上限，預設）
#   active 每 0.3 秒重繪一次（模擬打字／agent 在跑時的事件重繪）
#   秒數   跑多久後自動結束，預設 60；Ctrl-C 可隨時離開
set -f

mode="${1:-idle}"
duration="${2:-60}"
case "$mode" in
    idle)   interval=1   ;;
    active) interval=0.3 ;;
    *) echo "模式只能是 idle 或 active"; exit 1 ;;
esac

# 直接從狀態列腳本抽出色相→RGB 函式，確保顏色與實際狀態列一致
# 來源優先序：$STATUSLINE_SCRIPT → 同目錄的 statusline.sh → ~/.claude/statusline.sh
src="${STATUSLINE_SCRIPT:-}"
if [ -z "$src" ]; then
    src="$(cd "$(dirname "$0")" && pwd)/statusline.sh"
    [ -f "$src" ] || src="$HOME/.claude/statusline.sh"
fi
eval "$(awk '/^_hue_to_rgb\(\) \{/,/^\}/' "$src")"
type _hue_to_rgb >/dev/null 2>&1 || { echo "無法從 $src 取出 _hue_to_rgb"; exit 1; }

reset='\033[0m'
dim='\033[2m'
text="✦ Opus 5.5 (1M context) ✦"

# 版本清單：代號|類型|step|period_ms|說明
#   rainbow：彩虹流動（step＝每字色相差，period＝一圈毫秒數）
#   warm   ：珊瑚↔琥珀暖色漸層來回流動（step＝每字相位差，period＝一個來回的毫秒數）
#   shimmer：固定彩虹＋一道亮光由左往右掃（step＝底色每字色相差，period＝掃一趟的毫秒數）
#   wide   ：同 shimmer，但亮光寬約半條字串
#   pulse  ：彩虹流動（step／period 同 rainbow），每 4 秒整串亮一下
#   twinkle：彩虹流動（step／period 同 rainbow），每秒隨機亮 1～2 個字
variants=(
    "A|rainbow|24|30000|原版：每字 24°、30 秒一圈（每秒 ½ 格）"
    "B|rainbow|24|15000|每字 24°、15 秒一圈（每秒 1 格）"
    "C|rainbow|36|15000|每字 36°、15 秒一圈（每秒 ⅔ 格）"
    "D|rainbow|36|10000|每字 36°、10 秒一圈（每秒 1 格）"
    "E|rainbow|36|5000|每字 36°、5 秒一圈（每秒 2 格）"
    "F|rainbow|45|8000|每字 45°、8 秒一圈（每秒 1 格）"
    "G|rainbow|60|6000|每字 60°、6 秒一圈（每秒 1 格）"
    "H|warm|36|10000|暖色漸層（像 max）：10 字一個來回、每秒 1 格"
    "H2|warm|36|20000|暖色漸層（像 max）：10 字一個來回、每秒 ½ 格"
    "I|shimmer|24|16000|固定彩虹＋亮光掃過：一趟 16 秒（每秒約 2 格）"
    "I2|shimmer|24|8000|固定彩虹＋亮光掃過：一趟 8 秒（每秒約 4 格）"
    "I3|wide|24|2000|固定彩虹＋寬亮光：一趟 2 秒（每秒移半條）"
    "J|pulse|36|15000|目前採用：彩虹慢流（同 C）＋每 4 秒整串亮一下"
    "K|twinkle|36|15000|彩虹慢流（同 C）＋每秒隨機亮 1～2 個字"
)

# 與 statusline.sh 的 rainbow_str 相同的迴圈邏輯，只是 step／period 改成參數，
# 且同一幀共用一個時間戳，讓各列可以公平比較
render() {
    local now_ms=$1 step=$2 period=$3
    local ms_tail=$(( now_ms % 900000 ))
    local offset=$(( ( ms_tail * 360 / period ) % 360 ))
    local out="" i r g b ch hue
    for (( i=0; i<${#text}; i++ )); do
        ch="${text:$i:1}"
        if [ "$ch" = " " ]; then
            out+=" "
        else
            hue=$(( (offset + i * step) % 360 ))
            read -r r g b <<< "$(_hue_to_rgb $hue)"
            out+="\033[38;2;${r};${g};${b}m${ch}"
        fi
    done
    printf '%b%b' "$out" "$reset"
}

# 暖色版：相位以三角波在 coral(255,111,97) 與 amber(255,191,71) 之間來回，
# 兩端都是 statusline.sh 既有色票；粗體模仿 /effort 選單的 max
render_warm() {
    local now_ms=$1 step=$2 period=$3
    local ms_tail=$(( now_ms % 900000 ))
    local offset=$(( ( ms_tail * 360 / period ) % 360 ))
    local out="" i ch phase tri t r g b
    for (( i=0; i<${#text}; i++ )); do
        ch="${text:$i:1}"
        if [ "$ch" = " " ]; then out+=" "; continue; fi
        phase=$(( (offset + i * step) % 360 ))
        tri=$(( phase <= 180 ? phase : 360 - phase ))   # 0→180→0
        t=$(( tri * 100 / 180 ))
        r=255
        g=$(( 111 + (191 - 111) * t / 100 ))
        b=$((  97 - ( 97 -  71) * t / 100 ))
        out+="\033[1;38;2;${r};${g};${b}m${ch}"
    done
    printf '%b%b' "$out" "$reset"
}

# 亮光版：底色是固定的彩虹（亮度壓到 80% 讓亮光明顯），
# 亮光中心往白色混 70%，左右各 2.5 個字線性衰減；掃完一趟後留 8 個字的空檔
render_shimmer() {
    local now_ms=$1 step=$2 period=$3 halfw=${4:-25} gap=${5:-8}   # halfw：亮光半寬，單位 0.1 字
    local len=${#text}
    local span=$(( len + gap ))
    local pos10=$(( (now_ms % period) * span * 10 / period ))   # 亮光中心，單位 0.1 字
    local out="" i ch r g b d w
    for (( i=0; i<len; i++ )); do
        ch="${text:$i:1}"
        if [ "$ch" = " " ]; then out+=" "; continue; fi
        read -r r g b <<< "$(_hue_to_rgb $(( (i * step) % 360 )))"
        r=$(( r * 80 / 100 )); g=$(( g * 80 / 100 )); b=$(( b * 80 / 100 ))
        d=$(( i * 10 - pos10 )); [ $d -lt 0 ] && d=$(( -d ))
        if [ $d -lt $halfw ]; then
            w=$(( (halfw - d) * 70 / halfw ))
            r=$(( r + (255 - r) * w / 100 ))
            g=$(( g + (255 - g) * w / 100 ))
            b=$(( b + (255 - b) * w / 100 ))
            out+="\033[1;38;2;${r};${g};${b}m${ch}\033[22m"
        else
            out+="\033[38;2;${r};${g};${b}m${ch}"
        fi
    done
    printf '%b%b' "$out" "$reset"
}

# 把 (r g b) 往白色混 w%
_lighten() { echo "$(( $1 + (255 - $1) * $4 / 100 )) $(( $2 + (255 - $2) * $4 / 100 )) $(( $3 + (255 - $3) * $4 / 100 ))"; }

# 脈動版：底色照彩虹流動；每 4 秒中的第 1 秒整串往白混 55% 並加粗
render_pulse() {
    local now_ms=$1 step=$2 period=$3
    local sec=$(( now_ms / 1000 ))
    local lit=0; [ $(( sec % 4 )) -eq 0 ] && lit=1
    local ms_tail=$(( now_ms % 900000 ))
    local offset=$(( ( ms_tail * 360 / period ) % 360 ))
    local out="" i ch r g b
    for (( i=0; i<${#text}; i++ )); do
        ch="${text:$i:1}"
        if [ "$ch" = " " ]; then out+=" "; continue; fi
        read -r r g b <<< "$(_hue_to_rgb $(( (offset + i * step) % 360 )))"
        if [ $lit -eq 1 ]; then
            read -r r g b <<< "$(_lighten $r $g $b 55)"
            out+="\033[1;38;2;${r};${g};${b}m${ch}"
        else
            out+="\033[22;38;2;${r};${g};${b}m${ch}"
        fi
    done
    printf '%b%b' "$out" "$reset"
}

# 星光版：底色照彩虹流動（亮度 85%）；每秒用秒數雜湊挑 2 個位置往白混 75% 並加粗
# （挑到空白就等於那顆不亮，所以每秒是 1～2 個字）
render_twinkle() {
    local now_ms=$1 step=$2 period=$3
    local len=${#text} sec=$(( now_ms / 1000 ))
    local p1=$(( (sec * 7919) % len )) p2=$(( (sec * 104729 + 13) % len ))
    local ms_tail=$(( now_ms % 900000 ))
    local offset=$(( ( ms_tail * 360 / period ) % 360 ))
    local out="" i ch r g b
    for (( i=0; i<len; i++ )); do
        ch="${text:$i:1}"
        if [ "$ch" = " " ]; then out+=" "; continue; fi
        read -r r g b <<< "$(_hue_to_rgb $(( (offset + i * step) % 360 )))"
        if [ $i -eq $p1 ] || [ $i -eq $p2 ]; then
            read -r r g b <<< "$(_lighten $r $g $b 75)"
            out+="\033[1;38;2;${r};${g};${b}m${ch}\033[22m"
        else
            r=$(( r * 85 / 100 )); g=$(( g * 85 / 100 )); b=$(( b * 85 / 100 ))
            out+="\033[38;2;${r};${g};${b}m${ch}"
        fi
    done
    printf '%b%b' "$out" "$reset"
}

now_millis() {
    python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null \
        || perl -MTime::HiRes=time -e 'use POSIX qw(floor); printf "%s", floor(time()*1000)'
}

cleanup() { printf '\033[?25h\n'; exit 0; }
trap cleanup INT TERM

printf '\033[2J\033[?25l'   # 清畫面、隱藏游標
start=$(date +%s)
frame=0
while :; do
    now=$(now_millis)
    buf="\033[H"
    buf+="彩虹狀態列預覽　模式：${mode}（每 ${interval} 秒重繪）　第 ${frame} 幀　Ctrl-C 離開\n\n"
    for v in "${variants[@]}"; do
        IFS='|' read -r id kind step period desc <<< "$v"
        case "$kind" in
            warm)    row=$(render_warm    "$now" "$step" "$period") ;;
            shimmer) row=$(render_shimmer "$now" "$step" "$period") ;;
            wide)    row=$(render_shimmer "$now" "$step" "$period" 65 4) ;;
            pulse)   row=$(render_pulse   "$now" "$step" "$period") ;;
            twinkle) row=$(render_twinkle "$now" "$step" "$period") ;;
            *)       row=$(render         "$now" "$step" "$period") ;;
        esac
        buf+="  $(printf '%-2s' "$id")  ${row}   ${dim}${desc}${reset}\033[K\n"
    done
    printf '%b' "$buf"
    frame=$(( frame + 1 ))
    [ $(( $(date +%s) - start )) -ge "$duration" ] && cleanup
    # 扣掉這一幀的繪製時間，讓重繪間隔貼近真實的 interval
    elapsed_ms=$(( $(now_millis) - now ))
    sleep "$(awk -v i="$interval" -v e="$elapsed_ms" 'BEGIN{s=i-e/1000; if(s<0.05)s=0.05; printf "%.3f", s}')"
done
