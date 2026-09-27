# Statusline Kit

可配置的 Claude Code 狀態列工具包：模型、context 用量、花費、git 分支，以及 session／每週的用量條。
一支 bash 腳本、一個設定檔，裝好就會出現在 Claude Code 最底下。

## 預覽

```
✦ Opus 5 (1M context) ✦ · ctx ▰▰▰▰▱▱▱▱▱▱ 38% · $1.24 · ⧗ 12m03s · my-project · main · ◈ think
session    ▰▰▱▱▱▱▱▱▱▱  21%  resets in 2h 54m
weekly all ▰▰▰▰▰▱▱▱▱▱  47%  resets thu 4:00am
extra      ▰▰▰▰▰▰▰▰▰▰ $11.05/$10.00
```

數字是示意值。實際畫面是彩色的：

- **模型名稱**：Fable／Opus 系列會有流動的粉彩彩虹（30 秒一圈），其他模型顯示淡紫 `◆`
- **用量條**：填滿的格子依「在整條中的位置」上色，綠 → 琥珀 → 珊瑚兩段漸層；百分比數字用同一套漸層
- **thinking**：開啟時 `◈`／`◉` 每秒交替脈動

下面三行用量條需要授權才會出現，見下一段。

## ⚠ 用量條會讀你的 Keychain

`session`、`weekly`、`extra` 那幾條用量條，資料來自 Anthropic 的用量 API。
腳本會去 **macOS Keychain 讀你自己的 Claude Code OAuth token**（`security find-generic-password -s "Claude Code-credentials"`；Linux 用 `secret-tool`），再拿它呼叫 `api.anthropic.com/api/oauth/usage`，結果快取 60 秒。

- token 只會送到 Anthropic 官方的用量 API，不送往其他地方；傳給 curl 時走 stdin（`curl --config -`），不會出現在 `ps` 看得到的指令參數裡
- **預設關閉**：四個 `usage_*` 欄位沒在設定檔寫成 `true` 就不會執行那段程式碼，其餘功能完全不受影響
- 環境變數 `CLAUDE_CODE_OAUTH_TOKEN` 有值時優先使用它；設定檔的 `keychain_entry` 可指定別的 Keychain 項目名稱

## 前置需求

| 需要 | 用途 | 沒有的話 |
|------|------|----------|
| `jq` | 解析 Claude Code 餵進來的 JSON | 整條狀態列不會動 |
| `python3` 或 `perl` | 取毫秒時間戳，給彩虹動畫用 | 退化成秒級，動畫會頓 |
| `git` | 分支名稱與未提交標記 | 不顯示分支 |
| `security`／`secret-tool` | 從 Keychain 取 token（選用） | 用量條不顯示，其餘正常 |

macOS 內建 `security` 與 `python3`。安裝 jq：

```bash
brew install jq          # macOS
sudo apt install jq      # Ubuntu / Debian
sudo dnf install jq      # RHEL / Fedora
```

## 安裝

### 用 plugin（推薦）

在 Claude Code 中依序執行：

```bash
/plugin marketplace add mark22013333/statusline-kit
/plugin install statusline-kit@statusline-kit
/reload-plugins
/statusline-setup
```

安裝精靈會自動：
1. 偵測安裝目標路徑（`~/.claude-company/` 或 `~/.claude/`）
2. 讓你選擇初始模版（standard / minimal / dev / full / monitor）
3. 詢問要不要開用量條（會讀 Keychain，預設不開）
4. 複製腳本與設定檔、更新 `settings.json` 的 `statusLine`

### 手動

```bash
curl -fsSL https://raw.githubusercontent.com/mark22013333/statusline-kit/master/scripts/statusline.sh -o ~/.claude/statusline.sh
curl -fsSL https://raw.githubusercontent.com/mark22013333/statusline-kit/master/references/default-config.json -o ~/.claude/statusline-config.json
chmod +x ~/.claude/statusline.sh
```

再編輯 `~/.claude/settings.json`，把這段併進去（不要整個覆蓋）：

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash \"$HOME/.claude/statusline.sh\"",
    "refreshInterval": 1
  }
}
```

`refreshInterval` 單位是秒，**最小值就是 1**（官方限制），決定閒置時多久重繪一次。存檔後下次重繪就生效，不用重開 Claude Code。

## 設定檔

腳本依序找：`$STATUSLINE_CONFIG` → `~/.claude-company/statusline-config.json` → `~/.claude/statusline-config.json`。改完立即生效。

- 設定檔不存在、或某個主行欄位沒寫（或值為 `null`）→ 視為開啟
- `usage_*` 沒寫 → 視為關閉（見上面 Keychain 說明）
- 設定檔不是合法 JSON → 全部退回上面的預設值

### 可配置欄位

| # | 欄位 | 顯示什麼 |
|---|------|----------|
| 1 | model | 模型名稱，高階模型有彩虹效果 |
| 2 | context_bar | context 用量條與百分比 |
| 3 | context_tokens | 實際 token 數，例如 `(45k/200k)` |
| 4 | cost | 本次 session 花費 |
| 5 | duration | session 總時長 |
| 6 | api_duration | API 時間 |
| 7 | lines | 本次改了幾行（+/−），沒變動時隱藏 |
| 8 | cwd | 目前目錄名稱 |
| 9 | git_branch | 分支名稱 |
| 10 | git_dirty | 有沒有未提交變更（`*`） |
| 11 | thinking | thinking 模式是否開啟 |
| 12 | version | Claude Code 版本號 |
| 13 | exceeds_200k | 超過 200k tokens 警告 |
| 14 | usage_session | 5 小時 session 用量條 ＋ 重置倒數 🔑 |
| 15 | usage_weekly | 每週用量條 ＋ 重置時間 🔑 |
| 16 | usage_sonnet | 每週 Sonnet 用量條（API 有回才顯示）🔑 |
| 17 | usage_extra | 額外用量已用／上限 🔑 |

🔑 ＝ 會讀 Keychain。

### 預設模版

模版只切換 1～13 號主行欄位，`usage_*` 維持原值。

| 模版 | 包含欄位 |
|------|---------|
| minimal | model, context_bar, cost |
| standard | minimal ＋ context_tokens, duration, lines, cwd, git_branch |
| dev | model, context_bar, cost, duration, api_duration, lines, cwd, git_branch, git_dirty, thinking |
| full | 全部 13 個主行欄位 |
| monitor | model, context_bar, context_tokens, cost, duration, api_duration, exceeds_200k |

## 使用

| 指令 | 功能 |
|------|------|
| `/session-info` | 查看完整 session 資訊 |
| `/session-info config` | 互動調整顯示欄位 |
| `/session-info template <名稱>` | 快速切換模版 |

## 設計筆記

### 用量條為什麼是兩段漸層

直接從綠線性插值到紅，中段必然穿過一段低飽和的泥色：20% 的位置會是 `rgb(165,170,134)`，飽和度只有 0.21，是全程最低，而且跟 0% 幾乎分不出來。
改成 sage `rgb(143,188,143)` → amber `rgb(255,191,71)` → coral `rgb(255,97,97)` 兩段插值後，中段飽和度拉到 0.72，兩端顏色不變。

每一格的顏色以它在整條中的**絕對位置**決定（不是相對於已填滿的長度），所以 21% 只會看到綠色前段，接近 100% 才出現紅格。

### 彩虹動畫為什麼是 30 秒一圈

`refreshInterval` 最小只能設 1 秒，閒置時每秒只重繪一次是硬上限。每次重繪的色相位移＝`360 ÷ 週期秒數`：9.6 秒一圈等於每秒硬跳 37.5 度，看得出在跳格；30 秒一圈降到每秒 12 度，才看得出是流動。打字或 agent 在跑時有事件驅動的額外重繪，會更順。

計數器的模數用 `900000`（正好 30 個週期），回繞時色相剛好從 359 度接回 0 度，不會突兀跳一下。

## 授權

MIT
