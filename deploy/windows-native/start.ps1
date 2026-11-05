[CmdletBinding()]
param(
    [string]$EnvFile,
    [switch]$OpenBrowser
)

if ([string]::IsNullOrWhiteSpace($EnvFile)) {
    $EnvFile = Join-Path $PSScriptRoot '.env'
}

. (Join-Path $PSScriptRoot 'common.ps1')

$config = Read-DotEnv -Path $EnvFile
$napcatRoot = Get-ConfigValue -Config $config -Key 'NAPCAT_ROOT'
if ($napcatRoot -eq '' -or -not (Test-Path -LiteralPath $napcatRoot)) {
    throw "NAPCAT_ROOT not found: $napcatRoot"
}

$repoRoot = Get-RepoRoot
$astrbotRoot = Get-ConfigValue -Config $config -Key 'ASTRBOT_ROOT' -Default (Join-Path $repoRoot '.runtime\astrbot')
$astrbotExe = Get-ConfigValue -Config $config -Key 'ASTRBOT_EXE' -Default (Join-Path $repoRoot '.venv\Scripts\astrbot.exe')
$dashboardPort = [int](Get-ConfigValue -Config $config -Key 'ASTRBOT_DASHBOARD_PORT' -Default '6185')
$onebotPort = [int](Get-ConfigValue -Config $config -Key 'ONEBOT_WS_PORT' -Default '6199')
$onebotToken = Get-ConfigValue -Config $config -Key 'ONEBOT_WS_TOKEN'
if ($onebotToken -eq '') {
    throw 'ONEBOT_WS_TOKEN must not be empty.'
}

# 1) NapCat 侧：把 OneBot WS 客户端指向本机 AstrBot
& (Join-Path $PSScriptRoot 'setup-napcat.ps1') -EnvFile $EnvFile

# 2) AstrBot 侧：反向 WS 的端口与令牌跟 .env 对齐，两端不一致会连不上
Sync-AstrBotOneBotConfig -Path (Join-Path $astrbotRoot 'data\cmd_config.json') -Token $onebotToken -Port $onebotPort

# 3) 本机 AstrBot：已在监听就跳过，避免起第二个实例抢端口
if (Test-LocalPort -Port $dashboardPort) {
    Write-Host "AstrBot is already running (port $dashboardPort)."
} else {
    if (-not (Test-Path -LiteralPath $astrbotRoot)) {
        throw "AstrBot root not found: $astrbotRoot. Set ASTRBOT_ROOT in .env."
    }
    if (-not (Test-Path -LiteralPath $astrbotExe)) {
        throw "AstrBot executable not found: $astrbotExe. Set ASTRBOT_EXE in .env."
    }

    $stdoutLog = Join-Path $astrbotRoot 'astrbot-run.out.log'
    $stderrLog = Join-Path $astrbotRoot 'astrbot-run.err.log'
    # AstrBot 默认拿 CWD 当根目录，显式设 ASTRBOT_ROOT 双保险（见 docs/pitfalls.md 第 11 条）
    $env:ASTRBOT_ROOT = $astrbotRoot
    # 重定向到文件时 Python 会按系统 ANSI 码页（中文 Windows 是 GBK）写，强制 UTF-8
    $env:PYTHONIOENCODING = 'utf-8'
    $proc = Start-Process -FilePath $astrbotExe `
        -ArgumentList @('run', '-p', "$dashboardPort") `
        -WorkingDirectory $astrbotRoot `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdoutLog `
        -RedirectStandardError $stderrLog `
        -PassThru
    Set-Content -LiteralPath (Join-Path $PSScriptRoot '.astrbot.pid') -Value $proc.Id
    Write-Host "AstrBot started (PID $($proc.Id)); log: $stdoutLog"
}

# 先等 OneBot 端口起来再拉 NapCat，省掉一次必然失败的重连
$onebotReady = $false
for ($i = 0; $i -lt 60; $i++) {
    if (Test-LocalPort -Port $onebotPort) { $onebotReady = $true; break }
    Start-Sleep -Seconds 1
}
if ($onebotReady) {
    Write-Host "OneBot WS is listening on 127.0.0.1:${onebotPort}."
} else {
    Write-Warning "AstrBot did not open OneBot port ${onebotPort} within 60s; check $stderrLog"
}

# 4) NapCat / QQ
$launcher = Join-Path $napcatRoot 'NapCatWinBootMain.exe'
if (-not (Test-Path -LiteralPath $launcher)) {
    throw "Launcher not found: $launcher"
}

$already = Get-CimInstance Win32_Process -Filter "Name='NapCatWinBootMain.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($napcatRoot, [System.StringComparison]::OrdinalIgnoreCase) }
if ($already) {
    Write-Host "NapCat is already running."
} else {
    $account = Get-ConfigValue -Config $config -Key 'NAPCAT_QQ_ACCOUNT'
    if ($account -ne '') {
        # 传账号给启动器 = OneKey 的快速登录模式，登录态存在时不用再扫码。
        Start-Process -FilePath $launcher -ArgumentList @($account) -WorkingDirectory $napcatRoot -WindowStyle Hidden
    } else {
        Start-Process -FilePath $launcher -WorkingDirectory $napcatRoot -WindowStyle Hidden
    }
    Write-Host "NapCat started."
}

$webuiHost = Get-ConfigValue -Config $config -Key 'NAPCAT_WEBUI_HOST' -Default '127.0.0.1'
$webuiPort = Get-ConfigValue -Config $config -Key 'NAPCAT_WEBUI_PORT' -Default '6099'
$webuiToken = Get-ConfigValue -Config $config -Key 'NAPCAT_WEBUI_TOKEN'

$actualPort = $null
for ($i = 0; $i -lt 30; $i++) {
    $napcatPids = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($napcatRoot, [System.StringComparison]::OrdinalIgnoreCase) } |
        Select-Object -ExpandProperty ProcessId
    $listen = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
        Where-Object { $_.OwningProcess -in $napcatPids -and $_.LocalPort -ge 1024 }

    $preferred = $listen | Where-Object { $_.LocalPort -eq [int]$webuiPort }
    if ($preferred) { $actualPort = $preferred.LocalPort; break }

    foreach ($candidate in ($listen | Sort-Object LocalPort)) {
        try {
            $probe = Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 `
                -Uri "http://${webuiHost}:$($candidate.LocalPort)/webui"
            if ($probe.StatusCode -eq 200) { $actualPort = $candidate.LocalPort; break }
        } catch { }
    }
    if ($actualPort) { break }
    Start-Sleep -Seconds 1
}

Write-Host ''
Write-Host "AstrBot WebUI: http://127.0.0.1:${dashboardPort}"
if ($actualPort) {
    if ($actualPort -ne [int]$webuiPort) {
        Write-Warning "Configured port ${webuiPort} was busy; NapCat is listening on ${actualPort}."
    }
    Write-Host "NapCat login page: http://${webuiHost}:${actualPort}/webui?token=$webuiToken"
} else {
    Write-Warning "NapCat did not open a WebUI port within 30s; check whether it is already logged in."
    Write-Host "Configured NapCat port: ${webuiPort}"
}

if ($OpenBrowser) {
    $openPort = if ($actualPort) { $actualPort } else { [int]$webuiPort }
    try {
        Start-Process "http://${webuiHost}:${openPort}/webui?token=$webuiToken"
        Write-Host 'Opened the NapCat login page in the default browser.'
    } catch {
        Write-Warning "Could not open the browser automatically: $($_.Exception.Message)"
    }
}
