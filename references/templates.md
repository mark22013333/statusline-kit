# Statusline 模版定義

## 欄位清單

| # | 欄位 ID | 說明 |
|---|---------|------|
| 1 | model | 模型名稱（如 Opus 4.6） |
| 2 | context_bar | Context 進度條 + 百分比 |
| 3 | context_tokens | Context token 數（如 40k/1.0m） |
| 4 | cost | Session 累計費用（$） |
| 5 | duration | Session 經過時間 |
| 6 | api_duration | API 等待時間 |
| 7 | lines | 新增/刪除行數（+N -N） |
| 8 | git_branch | Git 分支名稱 |
| 9 | git_dirty | Git 未提交變更標記（*） |
| 10 | thinking | Thinking 模式狀態 |
| 11 | version | Claude Code 版本號 |
| 12 | exceeds_200k | 超過 200k tokens 警告 |

## 模版定義

### minimal — 最精簡
啟用: model, context_bar, cost

### standard — 標準
啟用: model, context_bar, context_tokens, cost, duration, lines, git_branch

### full — 完整
啟用: 全部 12 個欄位

### dev — 開發者
啟用: model, context_bar, cost, duration, api_duration, lines, git_branch, git_dirty, thinking

### monitor — 監控型
啟用: model, context_bar, context_tokens, cost, duration, api_duration, exceeds_200k

## 注意事項
- `context_tokens` 依賴 `context_bar`，若 `context_bar` 關閉則 `context_tokens` 無效
- `git_dirty` 依賴 `git_branch`，若 `git_branch` 關閉則 `git_dirty` 無效
- `exceeds_200k` 只在超過 200k tokens 時才會顯示警告圖示
- `lines` 只在有變動時才顯示（+0 -0 時隱藏）
