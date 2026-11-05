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
$astrbotRoot = Get-ConfigValue -Config $config -Key 'ASTRBOT_ROOT' -Default (Join-Path $repoRoot '.runtime\astrbot')
$dashboardPort = [int](Get-ConfigValue -Config $config -Key 'ASTRBOT_DASHBOARD_PORT' -Default '6185')
$onebotPort = [int](Get-ConfigValue -Config $config -Key 'ONEBOT_WS_PORT' -Default '6199')

Write-Host '=== AstrBot（本机） ==='
$pidFile = Join-Path $PSScriptRoot '.astrbot.pid'
if (Test-Path -LiteralPath $pidFile) {
    $astrbotPid = [int](Get-Content -LiteralPath $pidFile -Raw)
    if (Get-Process -Id $astrbotPid -ErrorAction SilentlyContinue) {
        Write-Host "pid file: PID $astrbotPid (running)"
    } else {
        Write-Host "pid file: PID $astrbotPid (not running)"
    }
} else {
    Write-Host 'pid file: none'
}
Write-Host "root: $astrbotRoot"

foreach ($item in @(
    @{ Port = $dashboardPort; Label = 'Dashboard' },
    @{ Port = $onebotPort; Label = 'OneBot WS' }
)) {
    $listeners = @(Get-ListeningProcess -Port $item.Port)
    if ($listeners.Count -eq 0) {
        Write-Host "$($item.Label) $($item.Port): NOT listening"
        continue
    }
    foreach ($listener in $listeners) {
        Write-Host "$($item.Label) $($listener.Port): listening on $($listener.Address) (PID $($listener.ProcessId), $($listener.ProcessName))"
        if ($listener.ProcessName -ieq 'ssh.exe') {
            Write-Warning "端口 $($listener.Port) 被 ssh.exe 占用，说明旧版 SSH 隧道还在跑；本机部署不需要它，先停掉再跑 start.ps1。"
        }
    }
}

Write-Host '=== NapCat / QQ ==='
if ($napcatRoot -eq '' -or -not (Test-Path -LiteralPath $napcatRoot)) {
    Write-Host "NAPCAT_ROOT invalid: $napcatRoot"
} else {
    $procs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($napcatRoot, [System.StringComparison]::OrdinalIgnoreCase) }
    if ($procs) {
        $procs | Select-Object Name, ProcessId | Format-Table -AutoSize | Out-String | Write-Host
        $pids = $procs | Select-Object -ExpandProperty ProcessId
        $ports = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
            Where-Object { $_.OwningProcess -in $pids -and $_.LocalPort -ge 1024 }
        if ($ports) {
            $configuredPort = [int](Get-ConfigValue -Config $config -Key 'NAPCAT_WEBUI_PORT' -Default '6099')
            $webuiPort = $ports | Where-Object { $_.LocalPort -eq $configuredPort }
            if ($webuiPort) {
                Write-Host "WebUI: http://127.0.0.1:$configuredPort/webui?token=<NAPCAT_WEBUI_TOKEN>"
            } else {
                Write-Host "Configured port $configuredPort not listening; candidates:"
                $ports | Select-Object LocalAddress, LocalPort, OwningProcess | Format-Table -AutoSize | Out-String | Write-Host
            }
        }
    } else {
        Write-Host 'NapCat is not running.'
    }
}
