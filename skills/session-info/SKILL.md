---
name: session-info
description: 顯示 session 資訊或互動配置 statusline 顯示欄位。支援「session info」、「session 資訊」、「用量」、「花了多少」、「調整 statusline」、「statusline 設定」。
user_invocable: true
---

# Session Info — Session 資訊 + Statusline 配置

根據參數決定執行模式：

- **無參數** `/session-info` → 顯示 session 資訊面板
- **`config`** `/session-info config` → 互動配置 statusline 顯示欄位
- **`template <名稱>`** `/session-info template minimal` → 直接套用預設模版

---

## 模式一：Session 資訊面板（無參數）

### 步驟

1. 讀取 `/tmp/claude/statusline-last-input.json`。檔案不存在則告知使用者「尚未有 statusline 資料，請確認已執行 `/statusline-setup` 完成安裝。」後結束。
2. 解析 JSON 並以 markdown 表格輸出以下區塊：

#### 模型
| 項目 | 值 |
|------|-----|
| 名稱 | `model.display_name` |
| ID | `model.id` |

#### Context Window
| 項目 | 值 |
|------|-----|
| 視窗大小 | `context_window.context_window_size` tokens |
| 已用 / 剩餘 | `used_percentage`% / `remaining_percentage`% |
| 目前 input | `current_usage.input_tokens` tokens |
| 目前 output | `current_usage.output_tokens` tokens |
| Cache 建立 | `cache_creation_input_tokens` tokens |
| Cache 讀取 | `cache_read_input_tokens` tokens |
| 累計 input / output | `total_input_tokens` / `total_output_tokens` tokens |
| 超過 200k | `exceeds_200k_tokens` |

#### 費用與統計
| 項目 | 值 |
|------|-----|
| 費用 | $`cost.total_cost_usd`（4 位小數） |
| Session 時間 | `total_duration_ms` → Xh Xm Xs |
| API 等待時間 | `total_api_duration_ms` → Xm Xs |
| 新增 / 刪除行數 | +N / -N |

#### 工作區
| 項目 | 值 |
|------|-----|
| 目前目錄 | `cwd` |
| 專案目錄 | `workspace.project_dir` |
| Session ID | `session_id` |
| Claude Code 版本 | `version` |

#### 可選區塊（欄位存在才顯示）
- **Vim**: `vim.mode`
- **Agent**: `agent.name`
- **Worktree**: 名稱、路徑、分支

### 格式規則
- token: ≥1M 用 `m`，≥1k 用 `k`
- 時間: 人類可讀（`5m 32s`）
- 費用: `$0.1234`

---

## 模式二：互動配置（`config` 參數）

### 步驟

1. 找到設定檔。自動偵測：
   - `~/.claude-company/statusline-config.json`（若 `~/.claude-company/` 目錄存在）
   - 否則 `~/.claude/statusline-config.json`

   如果設定檔不存在，告知使用者請先執行 `/statusline-setup` 後結束。

2. 讀取設定檔，顯示目前設定狀態：

```
## 目前 Statusline 設定

模版: {template}

| # | 欄位 | 說明 | 狀態 |
|---|------|------|------|
| 1 | model | 模型名稱 | ✅/❌ |
| 2 | context_bar | Context 進度條 + 百分比 | ✅/❌ |
| 3 | context_tokens | Context token 數（如 40k/1.0m） | ✅/❌ |
| 4 | cost | 費用（$） | ✅/❌ |
| 5 | duration | Session 經過時間 | ✅/❌ |
| 6 | api_duration | API 等待時間 | ✅/❌ |
| 7 | lines | 新增/刪除行數 | ✅/❌ |
| 8 | git_branch | Git 分支名稱 | ✅/❌ |
| 9 | git_dirty | Git 未提交變更標記（*） | ✅/❌ |
| 10 | thinking | Thinking 模式狀態 | ✅/❌ |
| 11 | version | Claude Code 版本號 | ✅/❌ |
| 12 | exceeds_200k | 超過 200k tokens 警告 | ✅/❌ |

## 預設模版

| 模版 | 說明 | 包含欄位 |
|------|------|---------|
| minimal | 最精簡 | model, context_bar, cost |
| standard | 標準 | model, context_bar, context_tokens, cost, duration, lines, git_branch |
| full | 完整 | 全部欄位 |
| dev | 開發者 | model, context_bar, cost, duration, api_duration, lines, git_branch, git_dirty, thinking |
| monitor | 監控型 | model, context_bar, context_tokens, cost, duration, api_duration, exceeds_200k |
```

3. 用 AskUserQuestion 讓使用者選擇：
   - 選項提供 5 個模版名 + 「自訂」選項
   - 如選「自訂」，再用 AskUserQuestion（multiSelect）讓使用者勾選要啟用的欄位

4. 根據使用者輸入：

**模版名稱**（minimal / standard / full / dev / monitor）：
- 按下方定義更新所有欄位
- `template` 設為該模版名

**自訂欄位切換**：
- 依選取結果更新欄位
- `template` 設為 `custom`

**模版定義**：
```
minimal:    model, context_bar, cost
standard:   model, context_bar, context_tokens, cost, duration, lines, git_branch
full:       model, context_bar, context_tokens, cost, duration, api_duration, lines, git_branch, git_dirty, thinking, version, exceeds_200k
dev:        model, context_bar, cost, duration, api_duration, lines, git_branch, git_dirty, thinking
monitor:    model, context_bar, context_tokens, cost, duration, api_duration, exceeds_200k
```

5. 用 Write 工具將更新後的 JSON 寫入設定檔。
6. 顯示更新後的預覽（模擬 statusline 輸出格式）。
7. 告知使用者設定已生效，下次狀態列更新時會自動套用。

---

## 模式三：直接套用模版（`template <名稱>` 參數）

快捷方式，跳過互動直接套用模版。

1. 驗證模版名稱是否存在（minimal / standard / full / dev / monitor）。不存在則列出可用模版。
2. 找到設定檔路徑（同模式二步驟 1）。
3. 按模版定義更新設定檔。
4. 顯示套用結果和預覽。

---

## 重要事項

- 修改設定檔後 statusline 會在下次更新時自動套用，**不需要重啟**
- `context_tokens` 依賴 `context_bar`，若 `context_bar` 關閉則 `context_tokens` 無效
- `git_dirty` 依賴 `git_branch`，若 `git_branch` 關閉則 `git_dirty` 無效
