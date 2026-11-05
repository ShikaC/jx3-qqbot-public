<#
    NapCat / QQ 手动看门狗

    双击运行或：
    powershell -ExecutionPolicy Bypass -File .\deploy\windows-native\watchdog-napcat.ps1

    每次运行做一轮检查：
      1) NapCat 进程 / WebUI 是否存活；
      2) QQ 是否在线（走 NapCat 本机 WebUI，只访问 127.0.0.1，零计费）；
      3) 掉线则先用保存的登录态做快速登录，重试不成功再提示扫码。

    本脚本只读配置、只连本机 NapCat WebUI，不碰 JX3API、不发 QQ 消息。
#>

[CmdletBinding()]
param(
    [string]$EnvFile,
    [int]$TimeoutSec = 6,
    [int]$Attempts = 3,
    [int]$RetryDelaySec = 8
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($EnvFile)) {
    $EnvFile = Join-Path $PSScriptRoot '.env'
}

. (Join-Path $PSScriptRoot 'common.ps1')

$config = Read-DotEnv -Path $EnvFile
$napcatRoot = Get-ConfigValue -Config $config -Key 'NAPCAT_ROOT'
$webuiHost = Get-ConfigValue -Config $config -Key 'NAPCAT_WEBUI_HOST' -Default '127.0.0.1'
$webuiPort = [int](Get-ConfigValue -Config $config -Key 'NAPCAT_WEBUI_PORT' -Default '6099')
$webuiToken = Get-ConfigValue -Config $config -Key 'NAPCAT_WEBUI_TOKEN'
$qqAccount = Get-ConfigValue -Config $config -Key 'NAPCAT_QQ_ACCOUNT'

if ($napcatRoot -eq '' -or -not (Test-Path -LiteralPath $napcatRoot)) {
    throw "NAPCAT_ROOT not found: $napcatRoot"
}
if ($webuiToken -eq '') {
    throw 'NAPCAT_WEBUI_TOKEN is empty. Check deploy/windows-native/.env.'
}

$baseUrl = "http://${webuiHost}:${webuiPort}"

function Write-Step([string]$Text) {
    Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Text)
}

function Get-NapCatProcesses {
    return @(
        Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
            Where-Object {
                $_.ExecutablePath -and
                $_.ExecutablePath.StartsWith($napcatRoot, [System.StringComparison]::OrdinalIgnoreCase)
            }
    )
}

function Test-NapCatWebUi {
    # 端口探活只做一次 TCP 连接，不依赖鉴权，用于判断进程是否还活着。
    return Test-LocalPort -Port $webuiPort -TimeoutMs ($TimeoutSec * 1000)
}

function Invoke-NapCatApi {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [hashtable]$Body = @{},
        [string]$Credential
    )

    $headers = @{}
    if ($Credential) {
        $headers.Authorization = "Bearer $Credential"
    }

    try {
        return Invoke-RestMethod `
            -Uri ($baseUrl + $Path) `
            -Method Post `
            -Headers $headers `
            -ContentType 'application/json' `
            -Body ($Body | ConvertTo-Json -Compress) `
            -TimeoutSec $TimeoutSec
    } catch {
        return $null
    }
}

function Get-NapCatCredential {
    # NapCat 的 WebUI 登录：sha256(token + '.napcat') 换取临时凭证。
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $raw = [System.Text.Encoding]::UTF8.GetBytes($webuiToken + '.napcat')
        $digest = $sha.ComputeHash($raw)
        $hash = -join ($digest | ForEach-Object { $_.ToString('x2') })
    } finally {
        $sha.Dispose()
    }

    $login = Invoke-NapCatApi -Path '/api/auth/login' -Body @{ hash = $hash }
    if ($null -eq $login -or $login.code -ne 0 -or -not $login.data.Credential) {
        return $null
    }
    return [string]$login.data.Credential
}

function Get-QqState {
    param([string]$Credential)
    return Invoke-NapCatApi -Path '/api/QQLogin/CheckLoginStatus' -Credential $Credential
}

function Invoke-QuickLogin {
    param(
        [string]$Credential,
        [string]$Uin
    )
    return Invoke-NapCatApi -Path '/api/QQLogin/SetQuickLogin' `
        -Body @{ uin = $Uin } `
        -Credential $Credential
}

# --- 1. 进程存活检查 ---
$procs = Get-NapCatProcesses
if ($procs.Count -eq 0) {
    Write-Step 'NapCat 进程不存在，调用 start.ps1 拉起。'
    & (Join-Path $PSScriptRoot 'start.ps1') -EnvFile $EnvFile
    Write-Host '已请求 start.ps1，等待 NapCat 就绪。'
    $ready = $false
    for ($i = 0; $i -lt 30; $i++) {
        if (Test-NapCatWebUi) { $ready = $true; break }
        Start-Sleep -Seconds 2
    }
    if (-not $ready) {
        Write-Warning 'NapCat 未在 60 秒内就绪，请检查 astrbot-run 日志与 NapCat 目录。'
        exit 1
    }
} elseif (-not (Test-NapCatWebUi)) {
    Write-Warning 'NapCat 进程存在但 WebUI 端口未监听，可能需要重启。'
    Write-Step '调用 start.ps1 尝试恢复。'
    & (Join-Path $PSScriptRoot 'start.ps1') -EnvFile $EnvFile
    Start-Sleep -Seconds 10
    if (-not (Test-NapCatWebUi)) {
        Write-Warning 'WebUI 仍不可用，请手动检查 NapCat。'
        exit 1
    }
}

# --- 2. QQ 登录态检查与恢复 ---
$credential = $null
for ($i = 0; $i -lt $Attempts -and -not $credential; $i++) {
    $credential = Get-NapCatCredential
    if (-not $credential) { Start-Sleep -Seconds 2 }
}
if (-not $credential) {
    Write-Warning '无法登录 NapCat WebUI，跳过 QQ 状态检查。'
    exit 1
}

$state = Get-QqState -Credential $credential
if ($null -eq $state) {
    Write-Warning '查询 QQ 登录状态失败。'
    exit 1
}

$data = $state.data
$isLogin = [bool]$data.isLogin
$coreReady = [bool]$data.coreReady

if ($isLogin -and $coreReady) {
    Write-Step 'QQ 在线，链路正常，无需处理。'
    exit 0
}

if ($isLogin -and -not $coreReady) {
    Write-Step 'QQ 已登录但核心未就绪，等待后重查。'
    Start-Sleep -Seconds $RetryDelaySec
    $state = Get-QqState -Credential $credential
    $data = $state.data
    $isLogin = [bool]$data.isLogin
    $coreReady = [bool]$data.coreReady
    if ($isLogin -and $coreReady) {
        Write-Step '核心已就绪，无需处理。'
        exit 0
    }
}

# --- 3. 掉线恢复：优先快速登录，需要时给提示 ---
$uin = $qqAccount
if ($uin -eq '') {
    # 未配 NAPCAT_QQ_ACCOUNT 时，从登录列表里取第一个可快速登录的账号。
    $list = Invoke-NapCatApi -Path '/api/QQLogin/GetQuickLoginListNew' -Credential $credential
    if ($null -ne $list -and $list.code -eq 0) {
        $candidate = @($list.data | Where-Object { $_.isQuickLogin }) | Select-Object -First 1
        if ($candidate) { $uin = [string]$candidate.uin }
    }
}

if ($uin -eq '') {
    Write-Warning 'QQ 已掉线，且没有可用快速登录账号。请打开 NapCat WebUI 扫码。'
    Write-Host "NapCat 登录页: ${baseUrl}/webui?token=$webuiToken"
    exit 1
}

Write-Step "QQ 掉线，尝试用账号 ${uin} 快速登录。"
$ok = $false
for ($i = 0; $i -lt $Attempts -and -not $ok; $i++) {
    Invoke-QuickLogin -Credential $credential -Uin $uin | Out-Null
    Start-Sleep -Seconds $RetryDelaySec
    $state = Get-QqState -Credential $credential
    if ($null -ne $state) {
        $data = $state.data
        $ok = [bool]$data.isLogin -and [bool]$data.coreReady
    }
    if ($ok) {
        Write-Step '快速登录成功，QQ 已恢复在线。'
    } else {
        Write-Step "快速登录未成功，第 $($i + 1)/$Attempts 次。"
    }
}

if (-not $ok) {
    Write-Warning '快速登录未能恢复 QQ。请打开 NapCat WebUI 扫码登录。'
    Write-Host "NapCat 登录页: ${baseUrl}/webui?token=$webuiToken"
    exit 1
}

exit 0
