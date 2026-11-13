# FinMind 一鍵設定：Claude Desktop + Claude Code + 環境變數 + 全域 CLAUDE.md
# 使用方式：在檔案上按右鍵 →「使用 PowerShell 執行」

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$utf8 = New-Object System.Text.UTF8Encoding $false

function Ok($m)   { Write-Host "  [OK] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  [!]  $m" -ForegroundColor Yellow }
function Step($m) { Write-Host "`n== $m ==" -ForegroundColor Cyan }

try {
    Write-Host "FinMind 一鍵設定" -ForegroundColor Cyan
    Write-Host "開始前請先完全關閉 Claude Desktop（系統匣圖示按右鍵 → 結束）。"
    Read-Host "已關閉的話按 Enter 繼續"

    # 1. 輸入並驗證 token
    Step "1/6 輸入 FinMind token"
    while ($true) {
        $sec = Read-Host "貼上 FinMind token（輸入時不會顯示）" -AsSecureString
        $t = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)).Trim()
        if (-not $t) { Warn "沒有輸入內容，請再貼一次"; continue }
        try {
            $r = Invoke-RestMethod "https://api.finmindtrade.com/api/v4/data?dataset=TaiwanStockInfo&data_id=2330" `
                    -Headers @{ Authorization = "Bearer $t" } -TimeoutSec 30
            if ($r.status -eq 200) { Ok "token 驗證成功"; break }
            Warn "token 驗證失敗：$($r.msg)"
        } catch {
            Warn "token 驗證失敗：$($_.Exception.Message)"
        }
        $again = Read-Host "要重新輸入嗎？(Y/n)"
        if ($again -match '^[nN]') { throw "已取消" }
    }

    # 2. 系統環境變數
    Step "2/6 設定環境變數 FINMIND_TOKEN"
    [Environment]::SetEnvironmentVariable("FINMIND_TOKEN", $t, "User")
    $env:FINMIND_TOKEN = $t
    Ok "已設定（你的策略程式可用 os.environ[""FINMIND_TOKEN""] 讀取）"

    # 3. uv / uvx
    Step "3/6 檢查 uv"
    $env:Path = [Environment]::GetEnvironmentVariable("Path","User") + ";" + [Environment]::GetEnvironmentVariable("Path","Machine")
    $uvxCmd = Get-Command uvx -ErrorAction SilentlyContinue
    if (-not $uvxCmd) {
        Warn "找不到 uv，開始自動安裝..."
        powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
        $env:Path = "$env:USERPROFILE\.local\bin;" + [Environment]::GetEnvironmentVariable("Path","User") + ";" + [Environment]::GetEnvironmentVariable("Path","Machine")
        $uvxCmd = Get-Command uvx -ErrorAction SilentlyContinue
        if (-not $uvxCmd) { throw "uv 安裝失敗，請手動安裝後重新執行本程式" }
    }
    $uvx = $uvxCmd.Source
    Ok "uvx 位置：$uvx"

    # 4. Claude Desktop 設定檔
    Step "4/6 設定 Claude Desktop"
    $candidates = @("$env:APPDATA\Claude\claude_desktop_config.json")
    $candidates += Get-ChildItem "$env:LOCALAPPDATA\Packages" -Directory -Filter "Claude_*" -ErrorAction SilentlyContinue |
                   ForEach-Object { Join-Path $_.FullName "LocalCache\Roaming\Claude\claude_desktop_config.json" }
    $cfg = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $cfg) {
        $cfg = $candidates[0]
        New-Item -ItemType Directory -Force (Split-Path $cfg) | Out-Null
        [IO.File]::WriteAllText($cfg, '{ "mcpServers": {} }', $utf8)
        Warn "原本沒有設定檔，已新建：$cfg"
    }
    Copy-Item $cfg "$cfg.bak" -Force
    $json = [IO.File]::ReadAllText($cfg, [Text.Encoding]::UTF8) | ConvertFrom-Json
    if (-not $json.PSObject.Properties["mcpServers"]) {
        $json | Add-Member -NotePropertyName mcpServers -NotePropertyValue ([pscustomobject]@{})
    }
    $entry = [pscustomobject]@{
        command = $uvx
        args    = @("finmind-mcp")
        env     = [pscustomobject]@{ FINMIND_TOKEN = $t }
    }
    $json.mcpServers | Add-Member -NotePropertyName finmind -NotePropertyValue $entry -Force
    [IO.File]::WriteAllText($cfg, ($json | ConvertTo-Json -Depth 100), $utf8)
    Ok "已加入 finmind（原檔備份：$cfg.bak）"

    # 5. Claude Code
    Step "5/6 設定 Claude Code"
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        $ErrorActionPreference = "Continue"
        & claude mcp remove finmind --scope user 2>$null | Out-Null
        $addArgs = @('mcp','add','finmind','--scope','user','-e',"FINMIND_TOKEN=$t",'--',$uvx,'finmind-mcp')
        & claude @addArgs
        $ErrorActionPreference = "Stop"
        if ($LASTEXITCODE -eq 0) { Ok "已加入 Claude Code（所有專案通用）" }
        else { Warn "Claude Code 加入失敗，可稍後手動處理" }
    } else {
        Warn "沒有安裝 Claude Code，略過"
    }

    # 6. 全域 CLAUDE.md
    Step "6/6 設定全域 CLAUDE.md"
    $dir = "$env:USERPROFILE\.claude"
    $md  = "$dir\CLAUDE.md"
    $rules = @(
        @{
            key  = "FINMIND_TOKEN"
            name = "token 規則"
            text = @"

## FinMind
- FinMind API token 存在環境變數 FINMIND_TOKEN，程式一律用 os.environ["FINMIND_TOKEN"] 讀取。
- 不要向我要 token，也不要把 token 寫進任何檔案。
- 查詢資料可直接使用 finmind MCP 工具。
"@
        },
        @{
            key  = "台股資料來源"
            name = "資料來源規則"
            text = @"

## 台股資料來源
- 台股資料（股價、K線、三大法人、融資融券、月營收、財報、期貨選擇權）一律優先用 FinMind（MCP 或 API）。
- 網路搜尋只用於新聞與事件解讀。
- 不同來源數字有出入時，以 FinMind 為準，並告訴我差異。
"@
        }
    )
    New-Item -ItemType Directory -Force $dir | Out-Null
    if (-not (Test-Path $md)) { [IO.File]::WriteAllText($md, "", $utf8) }
    foreach ($r in $rules) {
        $content = [IO.File]::ReadAllText($md, [Text.Encoding]::UTF8)
        if ($content.Contains($r.key)) {
            Ok "CLAUDE.md 已有$($r.name)，未變更"
        } else {
            $add = if ($content.Trim().Length -eq 0) { $r.text.TrimStart() } else { $r.text }
            [IO.File]::AppendAllText($md, $add, $utf8)
            Ok "已加入$($r.name)"
        }
    }

    Write-Host "`n全部完成！請重新打開 Claude Desktop。" -ForegroundColor Green
    Write-Host "若 Claude Code 或其他終端機正開著，也請關掉重開，環境變數才會生效。"
}
catch {
    Write-Host "`n發生錯誤：$($_.Exception.Message)" -ForegroundColor Red
}
Read-Host "`n按 Enter 關閉視窗"
