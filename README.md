# FinMind × Claude 一鍵設定

> 執行一次、貼上一次 token，之後 Claude Desktop 與 Claude Code 都會自動連上 FinMind 抓台股資料，不必再每次重貼 API Key。

由 [A+策略網](https://aplus.trading) 製作分享。

---

## 為什麼需要這支程式

用 Claude 搭配 [FinMind](https://finmindtrade.com/) 開發台股策略非常方便，但實際使用時有幾個麻煩：

- **每次都要重貼 API Key**：每開一個新對話或新專案，都得重新告訴 Claude 你的 token。
- **Key 散落各處**：token 被貼進對話、寫死在程式碼裡，很容易跟著程式一起分享出去。
- **手改 JSON 容易出錯**：Claude Desktop 的 MCP 設定要手動編輯 JSON，少一個逗號整份設定就失效。
- **兩套工具、兩套設定**：Claude Desktop 和 Claude Code 各有一份設定，要分別處理。
- **PowerShell 的小陷阱**：官方指令裡的 `--` 會被 PowerShell 吃掉，照著貼也會出錯。

`setup_finmind.ps1` 把這些事一次自動處理完。

## 程式會做什麼

| 步驟 | 內容 | 好處 |
|---|---|---|
| 1. 驗證 token | 實際呼叫一次 FinMind API | 貼錯會立刻提示，可重新輸入 |
| 2. 設定環境變數 | 存成使用者環境變數 `FINMIND_TOKEN` | 你自己的 Python 程式也能直接讀取 |
| 3. 檢查 uv | 沒有安裝就自動安裝 [uv](https://docs.astral.sh/uv/) | `finmind-mcp` 靠 uv 執行 |
| 4. 設定 Claude Desktop | 將 FinMind MCP 加入 `claude_desktop_config.json` | 自動備份原檔，其他設定不動 |
| 5. 設定 Claude Code | 以 `--scope user` 加入 FinMind MCP | 所有專案通用 |
| 6. 全域 `CLAUDE.md` | 寫入「token 從環境變數讀取」與「台股資料優先用 FinMind」兩條規則 | Claude 不再跟你要 token，並優先採用 FinMind 資料 |

程式可重複執行，不會重複新增設定。換了 token 或換新電腦，再跑一次即可。

## 安裝前準備

- Windows 10 / 11
- 已安裝 [Claude Desktop](https://claude.ai/download)；若也使用 Claude Code，請一併安裝
- FinMind 帳號與 token：登入後到 [使用者頁面](https://finmindtrade.com/analysis/#/account/user) 複製，並確認信箱已完成驗證

## 安裝步驟

1. **下載程式**：點本頁上方綠色的 **Code → Download ZIP**，解壓縮後找到 `setup_finmind.ps1`。
2. **完全關閉 Claude Desktop**：在右下角系統匣的 Claude 圖示按右鍵 →「結束」。只關視窗不夠。
3. **執行程式**：在 `setup_finmind.ps1` 上按右鍵 →「**使用 PowerShell 執行**」。
4. **貼上 token**：出現提示時貼上 token 並按 Enter。輸入時畫面不會顯示，這是正常的。
5. **重新打開 Claude Desktop**：若有開著的終端機或 Claude Code，也請關掉重開，環境變數才會生效。

> **視窗一閃就關掉，或出現「無法執行指令碼」？**
> 這是 Windows 的執行原則擋住了。請打開 PowerShell，切換到檔案所在資料夾後執行：
>
> ```powershell
> powershell -ExecutionPolicy Bypass -File .\setup_finmind.ps1
> ```

## 安裝後怎麼用

### 在 Claude Desktop 對話中

開新對話直接問，Claude 會自己呼叫 FinMind：

- 用 FinMind 資料查台積電近一個月股價與三大法人買賣超
- 使用 FinMind 資料庫，整理台指期近 20 日外資未平倉變化

第一次可以先問「用 FinMind 查一下 2330 的基本資料」，有回傳台積電的產業別就代表成功。

### 在 Claude Code 中

任何專案資料夾都能直接使用。確認方式：

```powershell
claude mcp list
```

看到 `finmind ... ✔ Connected` 就代表成功。

### 在你自己的 Python 程式中

```python
import os
import requests

token = os.environ["FINMIND_TOKEN"]
resp = requests.get(
    "https://api.finmindtrade.com/api/v4/data",
    params={"dataset": "TaiwanStockPrice", "data_id": "0050", "start_date": "2024-01-01"},
    headers={"Authorization": f"Bearer {token}"},
)
print(len(resp.json()["data"]), "筆資料")
```

## 重要建議：提問時明確說「使用 FinMind 資料」

裝好之後，Claude 同時擁有 FinMind 資料庫與網路搜尋兩種取得資料的方式，它會自行判斷要用哪一種，但這個判斷**並非百分之百固定**。網頁上拼湊的數字常常零散、不完整，拿來做策略判斷或回測容易失真。

因此建議**不論一般對話或開發策略，都在提問時明確寫出「使用 FinMind 資料」**，避免 AI 取用其他來源的資料。

| 不建議這樣問 | 建議這樣問 |
|---|---|
| 台積電最近表現如何？ | 用 FinMind 資料查台積電近一個月股價與三大法人買賣超 |
| 幫我回測 0050 均線策略 | 幫我回測 0050 的 120 日均線策略，資料一律從 FinMind API 抓取 |
| 台指期最近籌碼怎麼樣？ | 使用 FinMind 資料庫，整理台指期近 20 日外資未平倉變化 |

需要查新聞或事件解讀時，可以分開交代：「股價數據用 FinMind，原因請搜尋新聞」。

## 常見問題

<details>
<summary>token 換了怎麼辦？</summary>

在 FinMind 重設 token 後舊的會立即失效。關閉 Claude Desktop，重新執行 `setup_finmind.ps1` 貼上新 token，所有地方會一起更新。
</details>

<details>
<summary>Claude 回覆「Token is illegal」？</summary>

通常是改完設定後沒有「完全」重開 Claude Desktop，MCP 還在用舊 token。請從系統匣圖示按右鍵結束後再打開。仍失敗的話，確認 token 複製完整、FinMind 信箱已驗證，再重新執行程式。
</details>

<details>
<summary>怎麼還原 Claude Desktop 的設定？</summary>

程式修改前會自動備份成 `claude_desktop_config.json.bak`（位於 `%APPDATA%\Claude\`），把 `.bak` 改回原檔名即可。
</details>

<details>
<summary>token 會不會外流？</summary>

token 只存在你電腦上的三個地方：使用者環境變數、Claude Desktop 設定檔、Claude Code 設定檔，程式不會上傳到任何地方（除了向 FinMind 驗證）。請勿把這些設定檔分享給他人，也不要把 token 貼到對話或公開的程式碼中。
</details>

<details>
<summary>沒有用 Claude Code 也能執行嗎？</summary>

可以，偵測不到 Claude Code 時會自動略過該步驟。
</details>

<details>
<summary>Mac 可以用嗎？</summary>

本程式僅支援 Windows。Mac 使用者請參考 FinMind 官方的 [MCP 安裝說明](https://finmind.github.io/tutor/ai/Mcp/)。
</details>

---

## 關於 A+策略網

[**A+策略網**](https://aplus.trading) 是股票、期貨程式交易策略分享平台，專注於程式交易策略的研究、回測與實戰分享，適合想用程式化、數據化方式交易台股與期貨的投資人。

| 你想要… | 到這裡 |
|---|---|
| 看策略文章與回測 | [全部文章](https://aplus.trading/blog/) |
| 比較各策略的績效 | [策略統計表](https://aplus.trading/strategy-stats/) |
| 跟同好交流、拿免費工具 | [社團](https://aplus.trading/groups/) |
| 下載交易工具 | [工具](https://aplus.trading/product-category/product-type/tool/) |
| 系統化學習程式交易 | [實體／直播課程](https://aplus.trading/product-category/product-type/learn/)・[預錄課程](https://aplus.trading/courses/) |
| 解鎖 VIP 專屬策略 | [申請免費加入 VIP](https://aplus.trading/apply-vip/) |

這支一鍵設定程式，就是 A+策略網在用 AI 開發策略時整理出來的工具。更多 AI × 程式交易的實戰內容，歡迎到 [aplus.trading](https://aplus.trading) 逛逛。

### 聯絡我們

- 🌐 網站：[https://aplus.trading](https://aplus.trading)
- 💬 LINE 官方帳號：[@aplustrading](https://line.me/R/ti/p/@aplustrading)
- ✉️ Email：[contact@aplus.trading](mailto:contact@aplus.trading)

使用上有任何問題，也歡迎在本 repo 開 [Issue](../../issues) 回報。

## 授權

本專案以 [MIT License](LICENSE) 釋出，歡迎自由使用與修改。

## 免責聲明

本程式僅協助設定開發環境，不構成任何投資建議。FinMind 為第三方資料服務，資料內容與服務條款請以 [FinMind 官網](https://finmindtrade.com/) 為準。投資有風險，請審慎評估。
