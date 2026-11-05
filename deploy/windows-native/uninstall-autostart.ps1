[CmdletBinding()]
param(
    [string]$TaskName = 'JX3QQBot-NapCat'
)

$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if (-not $task) {
    Write-Host "Task not found: $TaskName"
    exit 0
}

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
Write-Host "Autostart task removed: $TaskName"
