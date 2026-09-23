# 台指期 24 小時 SMA 回測試算

這是一個以 Ruby on Rails 製作的台指期簡易回測網頁。系統會從外部分 K API 取得近 24 小時的 1 分 K 資料，依照使用者設定的進場與出場簡單移動平均線（SMA）週期進行多單回測，並以圖表、績效摘要及交易明細呈現結果。

> 本專案僅供策略研究與程式開發示範，不構成任何投資建議。回測結果未計入手續費、交易稅、滑價、流動性與實際成交限制，不應直接視為真實交易績效。

## 功能

- 自外部 API 讀取台指期 1 分 K 資料
- 自訂進場與出場 SMA 週期，允許範圍為 2～720
- 顯示收盤價、兩條 SMA 與進出場標記
- 統計總損益點數、交易次數、勝率、平均損益與最大回撤
- 顯示每筆交易的進出場時間、價格、持有時間、損益與出場原因
- 顯示最近 80 根分 K 及其 SMA、交易訊號
- API 無法連線或資料格式錯誤時顯示錯誤訊息
- 提供 `/up` 健康檢查端點

## 回測邏輯

目前策略只做多，並以訊號 K 棒的收盤價成交：

1. **進場**：收盤價由下往上穿越進場 SMA 時建立多單。
2. **出場**：持有多單期間，收盤價由上往下跌破出場 SMA 時平倉。
3. **資料結束**：若最後一根 K 棒仍持有部位，會以最後收盤價強制平倉。
4. **預設參數**：進場 SMA 為 60，出場 SMA 為 20；不合法的查詢參數會恢復成各自的預設值。

損益以指數點數計算，起始累積損益為 0。最大回撤是依照每筆已平倉交易的累積損益曲線計算。

## 技術環境

- Ruby 4.0.6
- Rails 8.1.3.1
- Puma
- ERB、原生 CSS 與 SVG 圖表
- Docker / Docker Compose（選用）

本專案未啟用 Active Record，因此不需要建立或遷移資料庫。

## 快速開始

### 使用 Docker Compose

需先安裝 Docker Desktop 或 Docker Engine 與 Compose 外掛。

```bash
docker compose up --build
```

啟動後開啟 <http://localhost:3001>。停止服務可按 `Ctrl+C`，或在另一個終端執行：

```bash
docker compose down
```

### 在本機執行

請先安裝 Ruby 4.0.6 與 Bundler，接著執行：

```bash
bundle install
bin/rails server
```

Windows PowerShell 若無法直接執行 `bin/rails`，可改用：

```powershell
ruby bin/rails server
```

啟動後開啟 <http://localhost:3000>。

也可以使用專案提供的初始化腳本；它會安裝缺少的 gem、清除舊的記錄與暫存檔，然後啟動伺服器：

```bash
bin/setup
```

## 分 K API 設定

預設資料來源為：

```text
https://futuresmonitor.cjhwork.com/api/minute-k-bars
```

如需改用其他相容 API，可設定 `MINUTE_K_BARS_API_URL` 環境變數。

macOS / Linux：

```bash
MINUTE_K_BARS_API_URL=https://example.com/api/minute-k-bars bin/rails server
```

Windows PowerShell：

```powershell
$env:MINUTE_K_BARS_API_URL = "https://example.com/api/minute-k-bars"
ruby bin/rails server
```

Docker Compose 可在 `compose.yaml` 的 `environment` 區段加入：

```yaml
environment:
  RAILS_ENV: development
  MINUTE_K_BARS_API_URL: https://example.com/api/minute-k-bars
```

### API 回傳格式

API 須回傳 JSON。應用程式會使用以下欄位：

```json
{
  "isConnected": true,
  "message": "ok",
  "symbol": "WTX&",
  "intervalMinutes": 1,
  "generatedAtTaipei": "2026-09-24T12:00:00+08:00",
  "fromTaipei": "2026-09-23T12:00:00+08:00",
  "toTaipei": "2026-09-24T12:00:00+08:00",
  "bars": [
    {
      "barStartTaipei": "2026-09-24T11:59:00+08:00",
      "barEndTaipei": "2026-09-24T12:00:00+08:00",
      "open": 25000,
      "high": 25010,
      "low": 24995,
      "close": 25005,
      "sourceCount": 12,
      "updatedAtTaipei": "2026-09-24T12:00:01+08:00"
    }
  ]
}
```

每根 K 棒至少要有可解析的 `barStartTaipei` 與 `close`；缺少這兩個欄位的資料會被略過。時間建議使用包含時區的 ISO 8601 格式。

## 使用方式

首頁即為回測頁面。輸入兩組 SMA 週期後按下「重新回測」，或直接使用查詢參數：

```text
http://localhost:3000/backtest?entry_ma=60&exit_ma=20
```

主要路由如下：

| 路徑 | 說明 |
| --- | --- |
| `/` | 回測首頁 |
| `/backtest` | 執行並顯示指定 SMA 參數的回測 |
| `/up` | Rails 健康檢查 |

## 專案結構

```text
app/
├─ controllers/backtests_controller.rb  # 接收參數、取得行情並執行回測
├─ services/minute_k_bars_client.rb      # 呼叫及正規化分 K API
├─ services/sma_backtester.rb            # SMA 計算、交易模擬與績效統計
├─ helpers/backtests_helper.rb            # 數字格式與 SVG 圖表資料
└─ views/backtests/                       # 回測頁面與價格圖表
config/routes.rb                          # 網頁與健康檢查路由
compose.yaml                              # 本機 Docker 開發服務
```

## 檢查專案

確認 Rails 可以正常載入並檢視路由：

```bash
bin/rails zeitwerk:check
bin/rails routes
```

目前儲存庫尚未包含自動化測試。若調整回測規則，建議優先為 `SmaBacktester` 補上單元測試，以涵蓋 SMA 尚未形成、交叉進出場、無交易及資料結束強制平倉等情境。

2026/09/24
