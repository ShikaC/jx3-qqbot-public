[CmdletBinding()]
param(
    [string]$EnvFile,
    [switch]$NoReload
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Warning 'install-fork-plugin.ps1 已更名为 install-plugin.ps1；当前入口仍可使用，但后续将移除。'

$params = @{}
if ($PSBoundParameters.ContainsKey('EnvFile')) {
    $params.EnvFile = $EnvFile
}
if ($NoReload) {
    $params.NoReload = $true
}

& (Join-Path $PSScriptRoot 'install-plugin.ps1') @params
