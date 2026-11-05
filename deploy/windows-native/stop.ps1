[CmdletBinding()]
param(
    [string]$EnvFile
)

if ([string]::IsNullOrWhiteSpace($EnvFile)) {
    $EnvFile = Join-Path $PSScriptRoot '.env'
}

. (Join-Path $PSScriptRoot 'common.ps1')

$config = Read-DotEnv -Path $EnvFile
$napcatRoot = Get-ConfigValue -Config $config -Key 'NAPCAT_ROOT'
$repoRoot = Get-RepoRoot
$venvRoot = Join-Path $repoRoot '.venv'
$dashboardPort = [int](Get-ConfigValue -Config $config -Key 'ASTRBOT_DASHBOARD_PORT' -Default '6185')
$onebotPort = [int](Get-ConfigValue -Config $config -Key 'ONEBOT_WS_PORT' -Default '6199')

# AstrBot 是「astrbot.exe → python.exe → python.exe」的进程链，真正监听端口的是最里层，
# 所以必须按进程树杀，只杀顶层会留下仍在监听 6185/6199 的孤儿进程。
$targets = New-Object System.Collections.Generic.List[int]
$pidFile = Join-Path $PSScriptRoot '.astrbot.pid'
if (Test-Path -LiteralPath $pidFile) {
    $astrbotPid = [int](Get-Content -LiteralPath $pidFile -Raw)
    if (Get-Process -Id $astrbotPid -ErrorAction SilentlyContinue) {
        $targets.Add($astrbotPid)
    }
    [System.IO.File]::Delete($pidFile)
}

# 兜底一：仓库 .venv 下的 astrbot.exe
foreach ($proc in @(Get-CimInstance Win32_Process -Filter "Name='astrbot.exe'" -ErrorAction SilentlyContinue)) {
    if ($proc.ExecutablePath -and $proc.ExecutablePath.StartsWith($venvRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        $targets.Add([int]$proc.ProcessId)
    }
}

# 兜底二：占用 6185 / 6199 且可执行文件在仓库 .venv 下的进程（进程链里层的 python.exe）
foreach ($port in @($dashboardPort, $onebotPort)) {
    foreach ($listener in @(Get-ListeningProcess -Port $port)) {
        if ($listener.Path -and $listener.Path.StartsWith($venvRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            $targets.Add([int]$listener.ProcessId)
        }
    }
}

foreach ($target in ($targets | Select-Object -Unique)) {
    if (-not (Get-Process -Id $target -ErrorAction SilentlyContinue)) { continue }
    & taskkill /PID $target /T /F | Out-Null
    Write-Host "Stopped AstrBot process tree (PID $target)."
}

# NapCat / QQ
if ($napcatRoot -ne '') {
    foreach ($name in @('NapCatWinBootMain.exe', 'QQ.exe')) {
        Get-CimInstance Win32_Process -Filter "Name='$name'" -ErrorAction SilentlyContinue |
            Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($napcatRoot, [System.StringComparison]::OrdinalIgnoreCase) } |
            ForEach-Object {
                Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
                Write-Host "Stopped $name (PID $($_.ProcessId))."
            }
    }
}
