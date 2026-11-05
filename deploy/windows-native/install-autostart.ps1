[CmdletBinding()]
param(
    [string]$EnvFile,
    [string]$TaskName = 'JX3QQBot-NapCat',
    [int]$DelaySeconds = 30
)

if ([string]::IsNullOrWhiteSpace($EnvFile)) {
    $EnvFile = Join-Path $PSScriptRoot '.env'
}

if (-not (Test-Path -LiteralPath $EnvFile)) {
    throw "Missing config file: $EnvFile. Copy .env.example to .env first."
}

$startScript = Join-Path $PSScriptRoot 'start.ps1'
if (-not (Test-Path -LiteralPath $startScript)) {
    throw "start.ps1 not found: $startScript"
}

$powershellExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$arguments = @(
    '-NoProfile'
    '-ExecutionPolicy', 'Bypass'
    '-WindowStyle', 'Hidden'
    '-File', ('"{0}"' -f $startScript)
    '-EnvFile', ('"{0}"' -f (Resolve-Path -LiteralPath $EnvFile).Path)
) -join ' '

$action = New-ScheduledTaskAction -Execute $powershellExe -Argument $arguments -WorkingDirectory $PSScriptRoot

$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$trigger.Delay = "PT${DelaySeconds}S"

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit ([TimeSpan]::Zero)

$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal -Force | Out-Null

Write-Host "Autostart task registered: $TaskName"
Write-Host "Trigger: at logon of $env:USERNAME, delay ${DelaySeconds}s"
Write-Host "Action: $powershellExe $arguments"
Write-Host "Remove with: powershell -ExecutionPolicy Bypass -File .\uninstall-autostart.ps1"
