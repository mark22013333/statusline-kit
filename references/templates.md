# Statusline 模版定義

## 欄位清單

### 主行欄位（模版會切換這 13 個）

| # | 欄位 ID | 說明 |
|---|---------|------|
| 1 | model | 模型名稱；Fable／Opus 系列顯示流動的粉彩彩虹，其他模型顯示淡紫 ◆ |
| 2 | context_bar | Context 用量條（▰▱，綠→琥珀→珊瑚漸層）＋ 百分比 |
| 3 | context_tokens | Context token 數（如 `(45k/200k)`） |
| 4 | cost | Session 累計費用（$） |
| 5 | duration | Session 經過時間（⧗） |
| 6 | api_duration | API 等待時間 |
| 7 | lines | 新增／刪除行數（+N -N） |
| 8 | cwd | 目前目錄名稱 |
| 9 | git_branch | Git 分支名稱 |
| 10 | git_dirty | Git 未提交變更標記（*） |
| 11 | thinking | Thinking 模式狀態（◈／◉ 脈動） |
| 12 | version | Claude Code 版本號 |
| 13 | exceeds_200k | 超過 200k tokens 警告 |

### 用量條欄位（opt-in，模版不會動）

| # | 欄位 ID | 說明 |
|---|---------|------|
| 14 | usage_session | 5 小時 session 用量條 ＋ 重置倒數 |
| 15 | usage_weekly | 每週（全模型）用量條 ＋ 重置時間 |
| 16 | usage_sonnet | 每週 Sonnet 用量條（API 有回這項才顯示） |
| 17 | usage_extra | 額外用量（extra usage）已用／上限金額 |

用量條資料來自 Anthropic 的 OAuth 用量 API：腳本會從 macOS Keychain（Linux 為 `secret-tool`）讀取 Claude Code 自己的 OAuth token 去呼叫，結果快取 60 秒。
因為會碰憑證，這四個欄位**設定檔沒寫就視為關閉**，必須明確設為 `true`。

## 模版定義

### minimal — 最精簡
啟用: model, context_bar, cost

### standard — 標準
啟用: model, context_bar, context_tokens, cost, duration, lines, cwd, git_branch

### dev — 開發者
啟用: model, context_bar, cost, duration, api_duration, lines, cwd, git_branch, git_dirty, thinking

### full — 完整
啟用: 全部 13 個主行欄位

### monitor — 監控型
啟用: model, context_bar, context_tokens, cost, duration, api_duration, exceeds_200k

套用模版時只改 13 個主行欄位，`usage_*` 四個維持原值。

## 注意事項
- 設定檔不存在、或某個主行欄位沒寫（或值為 `null`）：視為開啟；`usage_*` 沒寫：視為關閉
- 設定檔不是合法 JSON：全部退回上述預設值
- `context_tokens` 依賴 `context_bar`，若 `context_bar` 關閉則 `context_tokens` 無效
- `git_dirty` 依賴 `git_branch`，若 `git_branch` 關閉則 `git_dirty` 無效
- `exceeds_200k` 只在超過 200k tokens 時才會顯示警告圖示
- `lines` 只在有變動時才顯示（+0 -0 時隱藏）
