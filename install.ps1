<#
 .SYNOPSIS
    WorkBuddy 「截图」技能 - 一键安装（Windows）
 .DESCRIPTION
    把本仓库复制到 %USERPROFILE%\.workbuddy\skills\screenshot，装完即可在 WorkBuddy 里喊"截个图"。
 .PARAMETER TargetRoot
    自定义技能根目录（默认 ~\.workbuddy\skills）
 .EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1
#>
param(
    [string]$TargetRoot = (Join-Path $env:USERPROFILE '.workbuddy\skills')
)

$ErrorActionPreference = 'Stop'
$src = Split-Path -Parent $MyInvocation.MyCommand.Path
$dest = Join-Path $TargetRoot 'screenshot'

Write-Host "源目录：$src"
Write-Host "安装到：$dest"

if (-not (Test-Path $TargetRoot)) { New-Item -ItemType Directory -Path $TargetRoot -Force | Out-Null }

if (Test-Path $dest) {
    $backup = "$dest.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Write-Host "检测到已安装，旧版本备份到：$backup"
    Move-Item -Path $dest -Destination $backup
}
New-Item -ItemType Directory -Path $dest -Force | Out-Null

Copy-Item -Path (Join-Path $src 'SKILL.md') -Destination $dest -Force
Copy-Item -Path (Join-Path $src 'scripts') -Destination $dest -Recurse -Force
if (Test-Path (Join-Path $src 'README.md')) { Copy-Item (Join-Path $src 'README.md') -Destination $dest -Force }
if (Test-Path (Join-Path $src 'LICENSE'))   { Copy-Item (Join-Path $src 'LICENSE')   -Destination $dest -Force }

# 清掉开发用的临时文件，别带到安装目录
Get-ChildItem -Path (Join-Path $dest 'scripts') -Filter '_*' -File -ErrorAction SilentlyContinue | Remove-Item -Force

Write-Host ''
Write-Host '安装完成。'
Write-Host '验证：在 WorkBuddy 里输入 "帮我截个图"，或直接说 "截一块屏幕看看"'
Write-Host "手动运行：powershell -STA -ExecutionPolicy Bypass -File `"$dest\scripts\screenshot.ps1`" -Mode region"
