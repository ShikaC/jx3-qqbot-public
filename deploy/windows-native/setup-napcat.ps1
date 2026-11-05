[CmdletBinding()]
param(
    [string]$EnvFile
)

if ([string]::IsNullOrWhiteSpace($EnvFile)) {
    $EnvFile = Join-Path $PSScriptRoot '.env'
}

. (Join-Path $PSScriptRoot 'common.ps1')

$config = Read-DotEnv -Path $EnvFile
$configDir = Resolve-NapCatConfigDir -Config $config
$webuiToken = Get-ConfigValue -Config $config -Key 'NAPCAT_WEBUI_TOKEN'
$onebotToken = Get-ConfigValue -Config $config -Key 'ONEBOT_WS_TOKEN'
if ($webuiToken -eq '' -or $onebotToken -eq '') {
    throw 'NAPCAT_WEBUI_TOKEN / ONEBOT_WS_TOKEN must not be empty.'
}

$webui = [ordered]@{
    host             = Get-ConfigValue -Config $config -Key 'NAPCAT_WEBUI_HOST' -Default '127.0.0.1'
    port             = [int](Get-ConfigValue -Config $config -Key 'NAPCAT_WEBUI_PORT' -Default '6099')
    token            = $webuiToken
    loginRate        = 3
    autoLoginAccount = ''
}

$onebot = [ordered]@{
    network = [ordered]@{
        httpServers      = @()
        httpSseServers   = @()
        httpClients      = @()
        websocketServers = @()
        websocketClients = @(
            [ordered]@{
                enable            = $true
                name              = 'astrbot'
                url               = Get-ConfigValue -Config $config -Key 'ONEBOT_WS_URL' -Default 'ws://127.0.0.1:6199/ws'
                reportSelfMessage = $false
                messagePostFormat = 'array'
                token             = $onebotToken
                debug             = $false
                heartInterval     = 30000
                reconnectInterval = 30000
            }
        )
        plugins          = @()
    }
    musicSignUrl        = ''
    enableLocalFile2Url = $false
    parseMultMsg        = $false
}

Write-JsonFile -Path (Join-Path $configDir 'webui.json') -Value $webui
Write-JsonFile -Path (Join-Path $configDir 'onebot11.json') -Value $onebot

Write-Host "NapCat config written: $configDir"
$webuiHost = Get-ConfigValue -Config $config -Key 'NAPCAT_WEBUI_HOST' -Default '127.0.0.1'
$webuiPort = Get-ConfigValue -Config $config -Key 'NAPCAT_WEBUI_PORT' -Default '6099'
Write-Host "WebUI: http://${webuiHost}:${webuiPort}"
