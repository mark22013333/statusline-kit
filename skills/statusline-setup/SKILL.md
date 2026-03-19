---
name: statusline-setup
description: 安裝並設定 Statusline Kit。自動偵測環境，複製腳本、建立設定檔、更新 settings.json。當使用者提到「安裝 statusline」、「statusline setup」、「設定狀態列」時觸發此 Skill。
user_invocable: true
---

# Statusline Setup — 安裝精靈

一鍵安裝 Statusline Kit 到使用者環境。

---

## 流程

### 1. 偵測安裝目標

自動偵測安裝路徑，**不詢問使用者**：

- `~/.claude-company/` 目錄存在 → 安裝到 `~/.claude-company/`
- 否則 → 安裝到 `~/.claude/`

同時偵測 `settings.json` 位置：安裝目標目錄下的 `settings.json`。

若 `settings.json` 不存在，告知使用者並結束。

### 2. 檢查 jq 依賴

```bash
command -v jq
```

若不存在，提示使用者安裝（macOS: `brew install jq`、Ubuntu: `sudo apt install jq`）後結束。

### 3. 選擇模版

用 AskUserQuestion 讓使用者選擇初始模版：

- **standard**（推薦）— model, context_bar, context_tokens, cost, duration, lines, git_branch
- **minimal** — model, context_bar, cost
- **dev** — model, context_bar, cost, duration, api_duration, lines, git_branch, git_dirty, thinking
- **full** — 全部 12 個欄位

### 4. 安裝檔案

#### 4a. 複製 statusline.sh

從 plugin 目錄複製腳本到安裝目標：

```bash
cp {plugin_base_dir}/scripts/statusline.sh {安裝目標}/statusline.sh
chmod +x {安裝目標}/statusline.sh
```

`{plugin_base_dir}` 是此 SKILL.md 的上兩層目錄（即 `statusline-kit/`）。

用 Bash 工具執行複製，**不要用 Write 工具重寫腳本內容**。

#### 4b. 建立設定檔

讀取 `{plugin_base_dir}/references/default-config.json` 作為基底，按使用者選擇的模版修改 fields，然後用 Write 工具寫入 `{安裝目標}/statusline-config.json`。

模版定義參考 `{plugin_base_dir}/references/templates.md`。

#### 4c. 更新 settings.json

讀取 `{安裝目標}/settings.json`，新增或更新 `statusLine` 欄位：

```json
"statusLine": {
  "type": "command",
  "command": "bash \"$HOME/{相對路徑}/statusline.sh\""
}
```

- `{相對路徑}` 根據安裝目標決定（`.claude-company` 或 `.claude`）
- 如果 `statusLine` 已存在，詢問使用者是否覆蓋
- 使用 Edit 工具修改，不要覆寫整個 settings.json

### 5. 驗證

執行一次 statusline 腳本驗證輸出：

```bash
echo '{"model":{"display_name":"Test"},"context_window":{"context_window_size":200000,"current_usage":{"input_tokens":1000,"output_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":0},"used_percentage":1,"remaining_percentage":99},"cost":{"total_cost_usd":0,"total_duration_ms":0,"total_api_duration_ms":0,"total_lines_added":0,"total_lines_removed":0},"cwd":"/tmp","version":"2.1.79","exceeds_200k_tokens":false}' | bash {安裝目標}/statusline.sh
```

### 6. 完成提示

```
## Statusline Kit 安裝完成

- 腳本: {安裝目標}/statusline.sh
- 設定: {安裝目標}/statusline-config.json
- 模版: {選擇的模版}
- settings.json: 已更新

### 使用方式
- `/session-info` — 查看完整 session 資訊
- `/session-info config` — 互動調整顯示欄位
- `/session-info template <名稱>` — 快速切換模版（minimal / standard / full / dev / monitor）

狀態列會在下次 Claude Code 更新畫面時自動生效。
```

---

## 注意事項

- 不要修改使用者的 settings.json 中 statusLine 以外的設定
- 如果已有 statusline 設定，先備份再覆蓋
- jq 是必要依賴，安裝前檢查
