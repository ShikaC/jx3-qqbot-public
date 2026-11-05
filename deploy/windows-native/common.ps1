Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-DotEnv {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing config file: $Path. Copy .env.example to .env and fill it in."
    }

    # Windows PowerShell 5.1 默认把无 BOM 文件按 ANSI 读，中文会乱码。
    $text = [System.IO.File]::ReadAllText(
        (Resolve-Path -LiteralPath $Path).Path,
        (New-Object System.Text.UTF8Encoding($false))
    )
    $map = @{}
    foreach ($line in ($text -split "`r?`n")) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
        $index = $trimmed.IndexOf('=')
        if ($index -lt 1) { continue }
        $key = $trimmed.Substring(0, $index).Trim()
        $value = $trimmed.Substring($index + 1).Trim()
        $map[$key] = $value
    }
    return $map
}

function Get-ConfigValue {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Config,
        [Parameter(Mandatory = $true)][string]$Key,
        [string]$Default = ''
    )

    if ($Config.ContainsKey($Key) -and $Config[$Key] -ne '') { return $Config[$Key] }
    return $Default
}

function Resolve-NapCatConfigDir {
    param([Parameter(Mandatory = $true)][hashtable]$Config)

    $configured = Get-ConfigValue -Config $Config -Key 'NAPCAT_CONFIG_DIR'
    if ($configured -ne '' -and (Test-Path -LiteralPath $configured)) { return $configured }

    $root = Get-ConfigValue -Config $Config -Key 'NAPCAT_ROOT'
    if ($root -eq '' -or -not (Test-Path -LiteralPath $root)) {
        throw "NAPCAT_ROOT not found: $root. Run the OneKey installer or edit .env."
    }

    $found = Get-ChildItem -LiteralPath $root -Recurse -Directory -Filter 'config' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\napcat\\config$' } |
        Select-Object -First 1
    if (-not $found) {
        throw "Could not find napcat/config under $root."
    }
    return $found.FullName
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Value
    )

    $json = $Value | ConvertTo-Json -Depth 12
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $json, $encoding)
}

function Get-PortListener {
    param([Parameter(Mandatory = $true)][int]$Port)

    return Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue
}

function Get-RepoRoot {
    # deploy/windows-native -> 仓库根目录
    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
}

function Test-LocalPort {
    # 只做一次 TCP 连接探测。比 Get-NetTCPConnection 快得多，适合轮询。
    param(
        [Parameter(Mandatory = $true)][int]$Port,
        [int]$TimeoutMs = 800
    )

    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $async = $client.BeginConnect('127.0.0.1', $Port, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne($TimeoutMs)) { return $false }
        $client.EndConnect($async)
        return $true
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

function Get-ListeningProcess {
    param([Parameter(Mandatory = $true)][int]$Port)

    $result = @()
    foreach ($listener in @(Get-PortListener -Port $Port)) {
        $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$($listener.OwningProcess)" -ErrorAction SilentlyContinue
        $name = '?'
        $path = ''
        if ($proc) {
            $name = $proc.Name
            $path = $proc.ExecutablePath
        }
        $result += [pscustomobject]@{
            Port        = $Port
            Address     = $listener.LocalAddress
            ProcessId   = $listener.OwningProcess
            ProcessName = $name
            Path        = $path
        }
    }
    return $result
}

function Sync-AstrBotOneBotConfig {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Token,
        [int]$Port = 6199
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Warning "AstrBot config not found; start AstrBot once, then rerun: $Path"
        return
    }

    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $text = [System.IO.File]::ReadAllText($Path, $utf8Bom)
    $config = $text | ConvertFrom-Json
    $changed = $false

    foreach ($platform in @($config.platform)) {
        if ($platform.type -ne 'aiocqhttp' -and $platform.id -ne 'aiocqhttp') {
            continue
        }
        if ($platform.enable -ne $true) {
            $platform.enable = $true
            $changed = $true
        }
        if ($platform.ws_reverse_host -ne '127.0.0.1') {
            $platform.ws_reverse_host = '127.0.0.1'
            $changed = $true
        }
        if ([int]$platform.ws_reverse_port -ne $Port) {
            $platform.ws_reverse_port = $Port
            $changed = $true
        }
        if ($platform.ws_reverse_token -ne $Token) {
            $platform.ws_reverse_token = $Token
            $changed = $true
        }
    }

    if ($changed) {
        $json = $config | ConvertTo-Json -Depth 100
        [System.IO.File]::WriteAllText($Path, $json, $utf8NoBom)
        Write-Host "AstrBot OneBot config synced: $Path"
    }
}
