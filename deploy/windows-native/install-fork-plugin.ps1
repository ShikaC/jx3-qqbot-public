[CmdletBinding()]
param(
    [string]$EnvFile,
    [switch]$NoReload
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$env:PYTHONIOENCODING = 'utf-8'
try {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
} catch {
    # 输出被重定向时设置可能失败，忽略即可
}

# Windows PowerShell 5.1 默认可能只用 TLS 1.0，下载 GitHub 会失败。
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

# 修改版插件来源。功能开关位于 feature/feature-switch 分支；
# 如需固定到某个提交或标签，请把 $PluginRef 改成对应值并重新验证下载地址。
$PluginRepo = 'ShikaC/astrbot_plugin_jx3'
$PluginRef = 'feature/feature-switch'
$ArchiveUrl = "https://codeload.github.com/$PluginRepo/zip/refs/heads/$PluginRef"

$repoRoot = Get-RepoRoot
$config = Read-DotEnv -Path $EnvFile
$astrbotRoot = Get-ConfigValue -Config $config -Key 'ASTRBOT_ROOT' -Default (Join-Path $repoRoot '.runtime\astrbot')
$astrbotRoot = [System.IO.Path]::GetFullPath($astrbotRoot)

$storeDir = Join-Path $astrbotRoot 'data\plugins'
$targetDir = Join-Path $storeDir 'astrbot_plugin_jx3'
$runtimeRoot = Join-Path $repoRoot '.runtime'
$downloadRoot = Join-Path $runtimeRoot 'downloads'
$extractRoot = Join-Path $runtimeRoot 'astrbot-plugin-fork'

function Assert-UnderRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Label
    )
    $full = [System.IO.Path]::GetFullPath($Path)
    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    if (-not $full.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "$Label 不在预期目录内，拒绝操作：$full（应在 $rootFull 下）"
    }
    return $full
}

function Remove-DirectoryTree {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    [System.IO.Directory]::Delete($Path, $true)
}

New-Item -ItemType Directory -Path $downloadRoot -Force | Out-Null
$archiveRef = $PluginRef.Replace('/', '-')
$archive = Join-Path $downloadRoot "astrbot_plugin_jx3-$archiveRef.zip"

Write-Host "下载修改版剑三插件：$ArchiveUrl"
Invoke-WebRequest -Uri $ArchiveUrl -OutFile $archive -UseBasicParsing -TimeoutSec 300
if ((Get-Item -LiteralPath $archive).Length -le 0) {
    throw "下载内容为空：$ArchiveUrl"
}

Assert-UnderRoot -Path $extractRoot -Root $runtimeRoot -Label '解压目录' | Out-Null
Remove-DirectoryTree -Path $extractRoot
New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null
Expand-Archive -LiteralPath $archive -DestinationPath $extractRoot -Force

# codeload 解压后目录名形如 astrbot_plugin_jx3-<ref>，这里只认唯一一个目录。
$extracted = Get-ChildItem -LiteralPath $extractRoot -Directory | Select-Object -First 1
if (-not $extracted) {
    throw "解压后没有找到插件目录：$extractRoot"
}

New-Item -ItemType Directory -Path $storeDir -Force | Out-Null
Assert-UnderRoot -Path $targetDir -Root $storeDir -Label '插件目录' | Out-Null
$backupPath = $null
if (Test-Path -LiteralPath $targetDir) {
    $backupPath = Join-Path $astrbotRoot ('.plugin-deploy\backups\fork-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    New-Item -ItemType Directory -Path (Split-Path -Parent $backupPath) -Force | Out-Null
    Move-Item -LiteralPath $targetDir -Destination $backupPath
    Write-Host "已把旧插件目录备份到：$backupPath"
}

Move-Item -LiteralPath $extracted.FullName -Destination $targetDir

Write-Host ''
Write-Host '修改版剑三插件已安装：' -ForegroundColor Green
Write-Host "  $targetDir"
Write-Host "来源：https://github.com/$PluginRepo/tree/$PluginRef"
Write-Host '基于上游 qsc20001102/astrbot_plugin_jx3 修改，保留原作者与 AGPL-3.0 许可。'
Write-Host 'AstrBot 自带的「更新插件」可能用上游默认分支覆盖修改版；覆盖后请重新运行本脚本。'
if (-not $NoReload) {
    Write-Host '重启或重载 AstrBot 后生效。'
}
