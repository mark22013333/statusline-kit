# Statusline Kit

可配置的 Claude Code 狀態列工具包。

## 功能

- **可配置狀態列** — 12 個欄位自由組合，5 種預設模版
- **Session 資訊面板** — 一鍵查看 context、費用、API 時間等完整資訊
- **互動配置** — 在 Claude Code 內直接切換顯示欄位

## 安裝

```bash
# 1. 在 settings.json 加入 marketplace
"extraKnownMarketplaces": {
  "statusline-kit": {
    "source": {
      "source": "github",
      "repo": "<your-org>/statusline-kit"
    }
  }
}

# 2. 啟用 plugin
"enabledPlugins": {
  "statusline-kit@statusline-kit": true
}

# 3. 在 Claude Code 中執行
/statusline-setup
```

## 使用

| 指令 | 功能 |
|------|------|
| `/session-info` | 查看完整 session 資訊 |
| `/session-info config` | 互動調整顯示欄位 |
| `/session-info template <名稱>` | 快速切換模版 |

## 預設模版

| 模版 | 說明 |
|------|------|
| minimal | 最精簡：model + context + cost |
| standard | 標準：+ duration + lines + git_branch |
| full | 完整：全部 12 個欄位 |
| dev | 開發者：+ api_duration + git_dirty + thinking |
| monitor | 監控型：+ api_duration + exceeds_200k |

## 依賴

- `jq`（JSON 解析）
- `git`（分支資訊，可選）

## 授權

MIT
