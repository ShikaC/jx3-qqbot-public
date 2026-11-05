[CmdletBinding()]
param(
    [string]$EnvFile,
    [string]$Jx3Token,
    [string]$LlmApiKey,
    [string]$LlmBaseUrl = 'https://api.deepseek.com/v1',
    [string]$LlmModel = 'deepseek-flash',
    [string]$LlmProvider = 'deepseek',
    [string]$NapCatRoot,
    [string]$PipIndexUrl = 'https://pypi.tuna.tsinghua.edu.cn/simple',
    [int]$DashboardPort = 6185,
    [int]$OneBotPort = 6199,
    [switch]$Reconfigure,
    [switch]$NoStart,
    [switch]$CheckOnly,
    [switch]$NoOpenBrowser,
    [switch]$SkipNapCatDownload
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Python 子进程输出统一按 UTF-8 处理，避免中文在 Windows PowerShell 5.1 下乱码
# （与 start.ps1 同一处理，见 docs/pitfalls.md 第 23 条）
$env:PYTHONIOENCODING = 'utf-8'
try {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
} catch {
    # 输出被重定向时设置可能失败，忽略即可
}

# Windows PowerShell 5.1 默认可能只用 TLS 1.0，下载 GitHub / PyPI 会失败。
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {
    # 旧系统不支持时忽略，后续下载失败会给出提示
}

if ([string]::IsNullOrWhiteSpace($EnvFile)) {
    $EnvFile = Join-Path $PSScriptRoot '.env'
}
$EnvFile = [System.IO.Path]::GetFullPath($EnvFile)

. (Join-Path $PSScriptRoot 'common.ps1')

$repoRoot = Get-RepoRoot
$runtimeRoot = Join-Path $repoRoot '.runtime'
$downloadRoot = Join-Path $runtimeRoot 'downloads'
$venvRoot = Join-Path $repoRoot '.venv'
$venvPython = Join-Path $venvRoot 'Scripts\python.exe'
$venvAstrbot = Join-Path $venvRoot 'Scripts\astrbot.exe'
$astrbotRootDefault = Join-Path $runtimeRoot 'astrbot'
$requirementsFile = Join-Path $PSScriptRoot 'requirements.txt'
$configureScript = Join-Path $PSScriptRoot 'configure_instance.py'
$personaFile = Join-Path $repoRoot 'deploy\config\default-persona.txt'

function Write-Step {
    param([Parameter(Mandatory = $true)][string]$Text)
    Write-Host ''
    Write-Host "== $Text ==" -ForegroundColor Cyan
}

function Read-SecretText {
    # 用掩码读取密钥，避免 Token / API Key 直接显示在屏幕上。
    param([Parameter(Mandatory = $true)][string]$Prompt)
    $secure = Read-Host $Prompt -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function New-RandomHex {
    param([int]$Bytes = 16)
    $buffer = New-Object byte[] $Bytes
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($buffer) } finally { $rng.Dispose() }
    return -join ($buffer | ForEach-Object { $_.ToString('x2') })
}

function New-DashboardPassword {
    $upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
    $lower = 'abcdefghijkmnopqrstuvwxyz'
    $digits = '23456789'
    $all = $upper + $lower + $digits
    $chars = New-Object System.Collections.Generic.List[string]
    $chars.Add([string]$upper[(Get-Random -Maximum $upper.Length)])
    $chars.Add([string]$lower[(Get-Random -Maximum $lower.Length)])
    $chars.Add([string]$digits[(Get-Random -Maximum $digits.Length)])
    for ($i = 0; $i -lt 17; $i++) {
        $chars.Add([string]$all[(Get-Random -Maximum $all.Length)])
    }
    return -join ($chars | Sort-Object { Get-Random })
}

function Test-PortInUse {
    param([Parameter(Mandatory = $true)][int]$Port)
    return [bool](Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue)
}

function Get-FreePort {
    param(
        [Parameter(Mandatory = $true)][int]$Preferred,
        [int]$Span = 100
    )
    for ($port = $Preferred; $port -lt ($Preferred + $Span); $port++) {
        if (-not (Test-PortInUse -Port $port)) { return $port }
    }
    throw "从 $Preferred 开始连续 $Span 个端口都被占用，请手动指定端口。"
}

function Invoke-Download {
    param(
        [Parameter(Mandatory = $true)][string[]]$Urls,
        [Parameter(Mandatory = $true)][string]$OutFile,
        [string]$Sha256
    )
    New-Item -ItemType Directory -Path (Split-Path -Parent $OutFile) -Force | Out-Null
    foreach ($url in $Urls) {
        try {
            Write-Host "下载：$url"
            Invoke-WebRequest -Uri $url -OutFile $OutFile -UseBasicParsing -TimeoutSec 180
            if ((Get-Item -LiteralPath $OutFile).Length -le 0) { throw '下载内容为空。' }
            if ($Sha256) {
                $actual = (Get-FileHash -LiteralPath $OutFile -Algorithm SHA256).Hash
                if ($actual -ne $Sha256) {
                    Write-Warning "SHA256 校验失败：$url（期望 $Sha256，实际 $actual）"
                    continue
                }
                Write-Host "SHA256 校验通过：$actual"
            }
            return
        } catch {
            Write-Warning "下载失败：$($_.Exception.Message)"
        }
    }
    throw "所有下载地址都失败或未通过校验：$OutFile"
}

function Get-PythonLauncher {
    $candidates = New-Object System.Collections.Generic.List[object]
    $py = Get-Command py.exe -ErrorAction SilentlyContinue
    if ($py) {
        $candidates.Add([pscustomobject]@{ Exe = $py.Source; Prefix = @('-3.12') })
        $candidates.Add([pscustomobject]@{ Exe = $py.Source; Prefix = @('-3') })
    }
    foreach ($name in @('python.exe', 'python3.exe')) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) {
            $candidates.Add([pscustomobject]@{ Exe = $cmd.Source; Prefix = @() })
        }
    }

    foreach ($candidate in $candidates) {
        $checkArgs = @($candidate.Prefix) + @(
            '-c',
            'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)'
        )
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
        try {
            & $candidate.Exe @checkArgs *> $null
            $code = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $previous
        }
        if ($code -eq 0) { return $candidate }
    }
    return $null
}

function Install-PythonRuntime {
    Write-Host '未找到 Python 3.10+，尝试自动安装 Python 3.12...'
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($winget) {
        try {
            & $winget.Source install -e --id Python.Python.3.12 --scope user --silent `
                --accept-package-agreements --accept-source-agreements --disable-interactivity
        } catch {
            Write-Warning "winget 安装失败：$($_.Exception.Message)"
        }
    }

    $known = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\python.exe'),
        (Join-Path $env:ProgramFiles 'Python312\python.exe')
    )
    foreach ($path in $known) {
        if (Test-Path -LiteralPath $path) {
            return [pscustomobject]@{ Exe = $path; Prefix = @() }
        }
    }

    $installer = Join-Path $downloadRoot 'python-3.12.10-amd64.exe'
    Invoke-Download -Urls @('https://www.python.org/ftp/python/3.12.10/python-3.12.10-amd64.exe') -OutFile $installer
    $signature = Get-AuthenticodeSignature -FilePath $installer
    if ($signature.Status -ne 'Valid') {
        throw "Python 安装器数字签名校验失败（$($signature.Status)）。已保留文件：$installer"
    }
    $proc = Start-Process -FilePath $installer -Wait -PassThru -WindowStyle Hidden -ArgumentList @(
        '/quiet',
        'InstallAllUsers=0',
        'PrependPath=1',
        'Include_launcher=1',
        'Include_test=0'
    )
    if ($proc.ExitCode -ne 0) {
        throw "Python 安装器退出码：$($proc.ExitCode)。请手动安装 Python 3.12 后重试。"
    }
    foreach ($path in $known) {
        if (Test-Path -LiteralPath $path) {
            return [pscustomobject]@{ Exe = $path; Prefix = @() }
        }
    }
    throw 'Python 安装后仍找不到 python.exe，请手动安装 Python 3.12 后重试。'
}

function Ensure-Venv {
    param([Parameter(Mandatory = $true)]$Launcher)
    if (Test-Path -LiteralPath $venvPython) { return }
    Write-Step '创建 Python 虚拟环境'
    $venvArgs = @($Launcher.Prefix) + @('-m', 'venv', $venvRoot)
    & $Launcher.Exe @venvArgs
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $venvPython)) {
        throw '创建 Python 虚拟环境失败。'
    }
}

function Install-Requirements {
    Write-Step '安装 AstrBot 与插件依赖（首次约 1~2 GB，请耐心等待）'
    & $venvPython -m pip install --upgrade pip
    if ($LASTEXITCODE -ne 0) { throw '升级 pip 失败。' }

    $pipArgs = @('-m', 'pip', 'install', '-r', $requirementsFile)
    if ($PipIndexUrl) { $pipArgs += @('-i', $PipIndexUrl) }
    & $venvPython @pipArgs
    if ($LASTEXITCODE -ne 0 -and $PipIndexUrl) {
        Write-Warning '镜像安装失败，改用官方 PyPI 重试。'
        & $venvPython -m pip install -r $requirementsFile
    }
    if ($LASTEXITCODE -ne 0) { throw '依赖安装失败。' }
}

function Ensure-AstrBotInstance {
    param(
        [Parameter(Mandatory = $true)][string]$Password,
        [Parameter(Mandatory = $true)][bool]$ForcePassword
    )
    if (-not (Test-Path -LiteralPath $astrbotRoot)) {
        New-Item -ItemType Directory -Path $astrbotRoot -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath (Join-Path $astrbotRoot '.astrbot'))) {
        Write-Step '初始化 AstrBot 实例'
        Push-Location $astrbotRoot
        try {
            $env:ASTRBOT_DASHBOARD_INITIAL_PASSWORD = $Password
            & $venvAstrbot init -y
            if ($LASTEXITCODE -ne 0) { throw 'AstrBot 初始化失败。' }
        } finally {
            Remove-Item Env:ASTRBOT_DASHBOARD_INITIAL_PASSWORD -ErrorAction SilentlyContinue
            Pop-Location
        }
    } else {
        Write-Host "AstrBot 实例已存在：$astrbotRoot"
        if ($ForcePassword) {
            Push-Location $astrbotRoot
            try {
                & $venvAstrbot conf set dashboard.password $Password
                if ($LASTEXITCODE -ne 0) { throw '设置 Dashboard 密码失败。' }
            } finally {
                Pop-Location
            }
        }
    }
}

function Find-NapCatBootRoot {
    param([Parameter(Mandatory = $true)][string]$SearchRoot)
    $candidates = Get-ChildItem -LiteralPath $SearchRoot -Recurse -Filter 'NapCatWinBootMain.exe' -File -ErrorAction SilentlyContinue
    if (-not $candidates) { return '' }

    # OneKey 解压出的 bootmain 子目录也有同名引导器，但旁边没有 QQ.exe，不能直接运行；
    # 真正可运行的是 QQ.exe 与 NapCatWinBootMain.exe 同目录的 NapCat.x.x.Shell 目录。
    $runnable = $candidates |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.Directory.FullName 'QQ.exe') } |
        Select-Object -First 1
    if ($runnable) { return $runnable.Directory.FullName }

    # 没有带 QQ.exe 的候选时退回第一个，便于用户看到问题后自行处理。
    return @($candidates)[0].Directory.FullName
}

function Resolve-NapCatRoot {
    param(
        [string]$ParamRoot,
        [string]$ConfiguredRoot
    )
    foreach ($candidate in @($ParamRoot, $ConfiguredRoot)) {
        if ([string]::IsNullOrWhiteSpace($candidate) -or -not (Test-Path -LiteralPath $candidate)) {
            continue
        }
        $resolved = Find-NapCatBootRoot -SearchRoot $candidate
        if ($resolved -ne '') { return $resolved }
    }
    return ''
}

function Install-NapCat {
    Write-Step '下载并安装 NapCat（会一并下载 QQ 协议端，约 300~400 MB）'
    $zip = Join-Path $downloadRoot 'NapCat.Shell.Windows.OneKey.zip'
    # 固定版本并校验 SHA-256；digest 来自 NapCatQQ 官方 GitHub Release 的资产元数据。
    $napcatVersion = 'v4.18.42'
    $napcatSha256 = '46c3ec155aa61f12e89bbf97013a21243d00b0019b5565992a88852d7627f39c'
    Invoke-Download -Urls @(
        "https://github.com/NapNeko/NapCatQQ/releases/download/$napcatVersion/NapCat.Shell.Windows.OneKey.zip"
    ) -OutFile $zip -Sha256 $napcatSha256

    $extractRoot = Join-Path $runtimeRoot 'napcat-installer'
    if (Test-Path -LiteralPath $extractRoot) {
        [System.IO.Directory]::Delete($extractRoot, $true)
    }
    New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null
    Expand-Archive -LiteralPath $zip -DestinationPath $extractRoot -Force

    $installer = Join-Path $extractRoot 'NapCatInstaller.exe'
    if (-not (Test-Path -LiteralPath $installer)) {
        throw "OneKey 压缩包内没有 NapCatInstaller.exe：$extractRoot"
    }

    Write-Host '运行 NapCat OneKey 安装器；安装期间不要关闭窗口。'
    $proc = Start-Process -FilePath 'cmd.exe' `
        -ArgumentList @('/c', 'echo.|NapCatInstaller.exe') `
        -WorkingDirectory $extractRoot `
        -Wait -PassThru -WindowStyle Hidden
    if ($proc.ExitCode -ne 0) {
        throw "NapCat 安装器退出码：$($proc.ExitCode)"
    }

    $resolvedRoot = Find-NapCatBootRoot -SearchRoot $extractRoot
    if ($resolvedRoot -eq '') {
        throw "没有找到 NapCatWinBootMain.exe。请手动打开 $extractRoot 里的 NapCatInstaller.exe，然后用 -NapCatRoot 指定安装目录。"
    }
    return $resolvedRoot
}

function Write-SetupEnv {
    param(
        [Parameter(Mandatory = $true)][string]$NapCatRootPath,
        [Parameter(Mandatory = $true)][string]$WebUiToken,
        [Parameter(Mandatory = $true)][string]$OneBotToken,
        [Parameter(Mandatory = $true)][int]$OneBotPort,
        [Parameter(Mandatory = $true)][string]$AstrBotRootPath,
        [Parameter(Mandatory = $true)][int]$DashboardPortValue,
        [Parameter(Mandatory = $true)][string]$DashboardUser,
        [Parameter(Mandatory = $true)][string]$DashboardPasswordValue
    )
    New-Item -ItemType Directory -Path (Split-Path -Parent $EnvFile) -Force | Out-Null
    $lines = @(
        '# 由 setup.ps1 生成；包含本机凭据，不要提交到 Git。',
        '',
        '# --- NapCat ---',
        "NAPCAT_ROOT=$NapCatRootPath",
        'NAPCAT_CONFIG_DIR=',
        'NAPCAT_WEBUI_HOST=127.0.0.1',
        'NAPCAT_WEBUI_PORT=6099',
        "NAPCAT_WEBUI_TOKEN=$WebUiToken",
        'NAPCAT_QQ_ACCOUNT=',
        '',
        '# --- OneBot v11 ---',
        "ONEBOT_WS_URL=ws://127.0.0.1:$OneBotPort/ws",
        "ONEBOT_WS_TOKEN=$OneBotToken",
        "ONEBOT_WS_PORT=$OneBotPort",
        '',
        '# --- AstrBot ---',
        "ASTRBOT_ROOT=$AstrBotRootPath",
        "ASTRBOT_EXE=$venvAstrbot",
        "ASTRBOT_DASHBOARD_PORT=$DashboardPortValue",
        "ASTRBOT_DASHBOARD_USERNAME=$DashboardUser",
        "ASTRBOT_DASHBOARD_PASSWORD=$DashboardPasswordValue"
    )
    [System.IO.File]::WriteAllLines($EnvFile, $lines, (New-Object System.Text.UTF8Encoding($false)))
}

function Invoke-ConfigureInstance {
    param([switch]$PersonaOnly)
    $cliArgs = @(
        $configureScript,
        '--root', $astrbotRoot,
        '--onebot-token', $onebotToken,
        '--onebot-port', "$onebotPort",
        '--dashboard-port', "$dashboardPort",
        '--dashboard-username', $dashboardUsername,
        '--llm-base-url', $LlmBaseUrl,
        '--llm-model', $LlmModel,
        '--llm-provider', $LlmProvider
    )
    if (Test-Path -LiteralPath $personaFile) {
        $cliArgs += @('--persona-file', $personaFile)
    }
    if ($PersonaOnly) { $cliArgs += '--persona-only' }

    $env:JX3_SETUP_JX3_TOKEN = $Jx3Token
    $env:JX3_SETUP_LLM_KEY = $LlmApiKey
    try {
        & $venvPython @cliArgs
        if ($LASTEXITCODE -ne 0) { throw '写入 AstrBot / 插件配置失败。' }
    } finally {
        Remove-Item Env:JX3_SETUP_JX3_TOKEN -ErrorAction SilentlyContinue
        Remove-Item Env:JX3_SETUP_LLM_KEY -ErrorAction SilentlyContinue
    }
}

# --- 读取已有配置 ---
$config = @{}
if (Test-Path -LiteralPath $EnvFile) {
    $config = Read-DotEnv -Path $EnvFile
}

$astrbotRoot = Get-ConfigValue -Config $config -Key 'ASTRBOT_ROOT' -Default $astrbotRootDefault
$astrbotRoot = [System.IO.Path]::GetFullPath($astrbotRoot)
$napcatConfigured = Get-ConfigValue -Config $config -Key 'NAPCAT_ROOT'
$webuiToken = Get-ConfigValue -Config $config -Key 'NAPCAT_WEBUI_TOKEN'
$onebotToken = Get-ConfigValue -Config $config -Key 'ONEBOT_WS_TOKEN'
$dashboardUsername = Get-ConfigValue -Config $config -Key 'ASTRBOT_DASHBOARD_USERNAME' -Default 'astrbot'
$dashboardPassword = Get-ConfigValue -Config $config -Key 'ASTRBOT_DASHBOARD_PASSWORD'
$hadDashboardPassword = -not [string]::IsNullOrWhiteSpace($dashboardPassword)

if ($Reconfigure -or [string]::IsNullOrWhiteSpace($webuiToken)) { $webuiToken = New-RandomHex -Bytes 16 }
if ($Reconfigure -or [string]::IsNullOrWhiteSpace($onebotToken)) { $onebotToken = New-RandomHex -Bytes 16 }
if ($Reconfigure -or [string]::IsNullOrWhiteSpace($dashboardPassword)) { $dashboardPassword = New-DashboardPassword }

$configuredDashboardPort = Get-ConfigValue -Config $config -Key 'ASTRBOT_DASHBOARD_PORT'
if ($configuredDashboardPort) {
    $dashboardPort = [int]$configuredDashboardPort
} else {
    $dashboardPort = Get-FreePort -Preferred $DashboardPort
}
$configuredOneBotPort = Get-ConfigValue -Config $config -Key 'ONEBOT_WS_PORT'
if ($configuredOneBotPort) {
    $onebotPort = [int]$configuredOneBotPort
} else {
    $onebotPort = Get-FreePort -Preferred $OneBotPort
}

# --- 只做环境检查（不写任何文件、不启动服务） ---
if ($CheckOnly) {
    $launcher = Get-PythonLauncher
    Write-Step '环境检查结果'
    Write-Host "项目目录：$repoRoot"
    Write-Host "AstrBot 实例：$astrbotRoot"
    Write-Host "NapCat 目录：$(if ($napcatConfigured) { $napcatConfigured } else { '未配置' })"
    Write-Host "系统 Python：$(if ($launcher) { $launcher.Exe } else { '未找到 3.10+（安装时会自动下载）' })"
    Write-Host "Python 虚拟环境：$(if (Test-Path -LiteralPath $venvPython) { '已存在' } else { '未创建' })"
    Write-Host "Dashboard 端口：$dashboardPort"
    Write-Host "OneBot 端口：$onebotPort"
    return
}

# --- 复用或询问两个 Key ---
$existingJx3Token = ''
$pluginConfigPath = Join-Path $astrbotRoot 'data\config\astrbot_plugin_jx3_config.json'
if (Test-Path -LiteralPath $pluginConfigPath) {
    try {
        $pluginJson = Get-Content -LiteralPath $pluginConfigPath -Raw -Encoding utf8 | ConvertFrom-Json
        $existingJx3Token = [string]$pluginJson.jx3api_token
    } catch {
        $existingJx3Token = ''
    }
}

$existingLlmKey = ''
$cmdConfigPath = Join-Path $astrbotRoot 'data\cmd_config.json'
if (Test-Path -LiteralPath $cmdConfigPath) {
    try {
        $cmdJson = Get-Content -LiteralPath $cmdConfigPath -Raw -Encoding utf8 | ConvertFrom-Json
        $source = @($cmdJson.provider_sources) | Where-Object { $_.id -eq 'deepseek' } | Select-Object -First 1
        if ($source -and $source.key) { $existingLlmKey = [string]$source.key[0] }
    } catch {
        $existingLlmKey = ''
    }
}

if ([string]::IsNullOrWhiteSpace($Jx3Token)) {
    if ($existingJx3Token -and -not $Reconfigure) {
        $Jx3Token = $existingJx3Token
        Write-Host '检测到已有 JX3API Token，本次直接复用。'
    } else {
        $Jx3Token = Read-SecretText -Prompt '请粘贴 JX3API Token 后回车（输入不显示）'
    }
}
if ([string]::IsNullOrWhiteSpace($Jx3Token)) { throw 'JX3API Token 不能为空。' }

if ([string]::IsNullOrWhiteSpace($LlmApiKey)) {
    if ($existingLlmKey -and -not $Reconfigure) {
        $LlmApiKey = $existingLlmKey
        Write-Host '检测到已有 LLM API Key，本次直接复用。'
    } else {
        $LlmApiKey = Read-SecretText -Prompt '请粘贴 LLM API Key 后回车（默认 DeepSeek；直接回车表示只启用剑三查询）'
    }
}

# --- Python / AstrBot ---
if (-not (Test-Path -LiteralPath $venvPython)) {
    $launcher = Get-PythonLauncher
    if (-not $launcher) { $launcher = Install-PythonRuntime }
    Ensure-Venv -Launcher $launcher
}

$astrbotVersion = ''
$previous = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'
try {
    $astrbotVersion = (& $venvPython -c "import importlib.metadata as m; print(m.version('astrbot'))" 2>$null)
} finally {
    $ErrorActionPreference = $previous
}
if ($LASTEXITCODE -ne 0 -or -not $astrbotVersion -or $astrbotVersion.Trim() -ne '4.29.4') {
    Install-Requirements
}

Write-Step '准备 AstrBot 实例'
Ensure-AstrBotInstance -Password $dashboardPassword -ForcePassword:($Reconfigure -or -not $hadDashboardPassword)

# --- NapCat ---
$resolvedNapCatRoot = Resolve-NapCatRoot -ParamRoot $NapCatRoot -ConfiguredRoot $napcatConfigured
if (-not $resolvedNapCatRoot) {
    if ($SkipNapCatDownload) {
        throw "没有找到可用的 NapCat。请手动安装后，用 -NapCatRoot 指定目录。"
    }
    $resolvedNapCatRoot = Install-NapCat
}

# --- 写配置、同步插件 ---
Write-Step '写入本机部署配置'
Write-SetupEnv `
    -NapCatRootPath $resolvedNapCatRoot `
    -WebUiToken $webuiToken `
    -OneBotToken $onebotToken `
    -OneBotPort $onebotPort `
    -AstrBotRootPath $astrbotRoot `
    -DashboardPortValue $dashboardPort `
    -DashboardUser $dashboardUsername `
    -DashboardPasswordValue $dashboardPassword
Write-Host "配置已写入：$EnvFile"

Write-Step '安装 fork 修改版剑三插件'
& (Join-Path $PSScriptRoot 'install-fork-plugin.ps1') -EnvFile $EnvFile -NoReload

Write-Step '写入 AstrBot、LLM 与 JX3 Token 配置'
Invoke-ConfigureInstance

if ($NoStart) {
    Write-Host ''
    Write-Host '安装已完成（按 -NoStart 未启动）。'
    Write-Host "启动命令：powershell -ExecutionPolicy Bypass -File `"$PSScriptRoot\start.ps1`" -EnvFile `"$EnvFile`""
    return
}

Write-Step '启动 AstrBot 与 NapCat'
& (Join-Path $PSScriptRoot 'start.ps1') -EnvFile $EnvFile -OpenBrowser:(!$NoOpenBrowser)

$dashboardReady = $false
for ($i = 0; $i -lt 60; $i++) {
    if (Test-LocalPort -Port $dashboardPort) { $dashboardReady = $true; break }
    Start-Sleep -Seconds 2
}
if (-not $dashboardReady) {
    $errLog = Join-Path $astrbotRoot 'astrbot-run.err.log'
    throw "AstrBot 没有在端口 $dashboardPort 上启动。请查看日志：$errLog"
}

# AstrBot 首次启动后才创建 data_v4.db，此时再写入默认人格。
$dbPath = Join-Path $astrbotRoot 'data\data_v4.db'
for ($i = 0; $i -lt 60; $i++) {
    if (Test-Path -LiteralPath $dbPath) { break }
    Start-Sleep -Seconds 2
}
if (Test-Path -LiteralPath $dbPath) {
    Write-Step '写入默认群友人格'
    Invoke-ConfigureInstance -PersonaOnly
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Green
Write-Host ' 安装完成，接下来只需要做两件事：' -ForegroundColor Green
Write-Host '========================================' -ForegroundColor Green
Write-Host "1. 用 QQ 小号在 NapCat 登录页扫码（地址见上方 start.ps1 打印的登录页）："
Write-Host "   http://127.0.0.1:6099/webui?token=$webuiToken"
Write-Host "2. 在 QQ 群里发送：绑定区服 梦江南"
Write-Host ''
Write-Host "AstrBot 管理后台：http://127.0.0.1:$dashboardPort"
Write-Host "后台账号：$dashboardUsername"
Write-Host "后台密码：$dashboardPassword"
Write-Host ''
Write-Host '剑三查询：在群里发 `功能` 查看菜单。'
Write-Host 'AI 聊天：是否回话由 AstrBot 自身的模型和唤醒规则决定。'
Write-Host '剑三插件为 fork 修改版；后台「更新插件」可能覆盖功能开关，覆盖后请重新运行安装脚本。'
Write-Host ''
Write-Host "本机凭据保存在：$EnvFile（不要上传、不要截图分享）"
Write-Host '以后启动机器人：双击项目根目录的 start.cmd。'
