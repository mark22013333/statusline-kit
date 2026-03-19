# Statusline Kit

可配置的 Claude Code 狀態列工具包。

## 預覽

```
Opus 4.6 (1M context) │ ctx ●●○○○○○○○○ 15% (150k/1.0m) │ $1.23 │ ⏱ 12m5s │ +42 -7 │ main
```

## 前置需求

### jq（必要）

statusline 腳本使用 jq 解析 JSON 資料。

```bash
# macOS
brew install jq

# Ubuntu / Debian
sudo apt install jq

# RHEL / CentOS / Fedora
sudo dnf install jq

# Windows (scoop)
scoop install jq

# 驗證安裝
jq --version
```

### git（可選）

用於顯示 Git 分支名稱與未提交變更標記。大多數開發環境已內建。

```bash
git --version
```

## 安裝

### 步驟一：註冊 Marketplace

開啟你的 Claude Code settings.json（`~/.claude/settings.json` 或 `~/.claude-company/settings.json`），在 `extraKnownMarketplaces` 中加入：

```jsonc
{
  "extraKnownMarketplaces": {
    "statusline-kit": {
      "source": {
        "source": "github",
        "repo": "mark22013333/statusline-kit"
      }
    }
  }
}
```

### 步驟二：啟用 Plugin

在同一個 settings.json 的 `enabledPlugins` 中加入：

```jsonc
{
  "enabledPlugins": {
    "statusline-kit@statusline-kit": true
  }
}
```

### 步驟三：重啟 Claude Code

關閉並重新開啟 Claude Code，讓 plugin 生效。

### 步驟四：執行安裝精靈

在 Claude Code 中執行：

```
/statusline-setup
```

安裝精靈會自動：
1. 偵測安裝目標路徑（`~/.claude-company/` 或 `~/.claude/`）
2. 讓你選擇初始模版（standard / minimal / dev / full）
3. 複製 statusline 腳本
4. 建立設定檔
5. 更新 settings.json 的 `statusLine` 設定

## 使用

| 指令 | 功能 |
|------|------|
| `/session-info` | 查看完整 session 資訊 |
| `/session-info config` | 互動調整顯示欄位 |
| `/session-info template <名稱>` | 快速切換模版 |

## 預設模版

| 模版 | 包含欄位 | 預覽 |
|------|---------|------|
| minimal | model, context, cost | `Opus │ ctx ●○○○ 7% │ $0.12` |
| standard | + duration, lines, git_branch | `Opus │ ctx ●○○○ 7% (66k/1.0m) │ $0.12 │ ⏱ 5m │ +42 -7 │ main` |
| dev | + api_duration, git_dirty, thinking | `Opus │ ctx ●○○○ 7% │ $0.12 │ ⏱ 5m │ API 1m │ +42 -7 │ main* │ ◐ thinking` |
| full | 全部 12 個欄位 | 同 dev + version + exceeds_200k |
| monitor | context_tokens, api_duration, exceeds_200k | `Opus │ ctx ●○○○ 7% (66k/1.0m) │ $0.12 │ ⏱ 5m │ API 1m` |

## 可配置欄位

| # | 欄位 | 說明 |
|---|------|------|
| 1 | model | 模型名稱 |
| 2 | context_bar | Context 進度條 + 百分比 |
| 3 | context_tokens | Context token 數 |
| 4 | cost | Session 累計費用 |
| 5 | duration | Session 經過時間 |
| 6 | api_duration | API 等待時間 |
| 7 | lines | 新增/刪除行數 |
| 8 | git_branch | Git 分支名稱 |
| 9 | git_dirty | 未提交變更標記 |
| 10 | thinking | Thinking 模式狀態 |
| 11 | version | Claude Code 版本號 |
| 12 | exceeds_200k | 超過 200k tokens 警告 |

## 授權

MIT
