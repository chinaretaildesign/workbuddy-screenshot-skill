<#
 .SYNOPSIS
    WorkBuddy 「截图」技能 - 全局热键常驻组件（Windows）
 .DESCRIPTION
    常驻后台监听 Ctrl+Alt+A，按下即弹出区域选框，截完自动存盘并复制到剪贴板。
    零外部依赖（纯 PowerShell + .NET）。注意：它只负责"截图+进剪贴板"，
    不会自动把图片发进对话——需要你在输入框按 Ctrl+V。
 .PARAMETER Hotkey
    组合键，目前支持 Ctrl+Alt+A（默认）与 Ctrl+Shift+A
 .PARAMETER InstallStartup
    在当前用户启动文件夹创建快捷方式，实现开机自启
 .PARAMETER UninstallStartup
    移除开机自启快捷方式
#>
param(
    [ValidateSet('ctrl+alt+a','ctrl+shift+a')]
    [string]$Hotkey = 'ctrl+alt+a',
    [switch]$InstallStartup,
    [switch]$UninstallStartup
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class HotkeyApi {
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
    [DllImport("user32.dll")]
    public static extern int GetMessage(out MSG lpMsg, IntPtr hWnd, uint wMsgFilterMin, uint wMsgFilterMax);
    [DllImport("user32.dll")]
    public static extern bool TranslateMessage(ref MSG lpMsg);
    [DllImport("user32.dll")]
    public static extern IntPtr DispatchMessage(ref MSG lpMsg);
    [StructLayout(LayoutKind.Sequential)]
    public struct MSG {
        public IntPtr hwnd; public uint message; public IntPtr wParam; public IntPtr lParam;
        public uint time; public int ptX; public int ptY;
    }
}
"@

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$SHOT = Join-Path $SCRIPT_DIR 'screenshot.ps1'
if (-not (Test-Path $SHOT)) { Write-Error "找不到 screenshot.ps1（应与本脚本同目录）"; exit 1 }

# ---------- 开机自启 ----------
$startupDir = [Environment]::GetFolderPath('Startup')
$lnkPath = Join-Path $startupDir 'WorkBuddy-Screenshot-Hotkey.lnk'

if ($InstallStartup) {
    $ws = New-Object -ComObject WScript.Shell
    $lnk = $ws.CreateShortcut($lnkPath)
    $lnk.TargetPath = 'powershell.exe'
    $lnk.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    $lnk.WorkingDirectory = $SCRIPT_DIR
    $lnk.WindowStyle = 7
    $lnk.Description = 'WorkBuddy 截图全局热键'
    $lnk.Save()
    Write-Host "已加入开机自启：$lnkPath"
    exit 0
}
if ($UninstallStartup) {
    if (Test-Path $lnkPath) { Remove-Item $lnkPath -Force; Write-Host "已移除开机自启" }
    else { Write-Host "未找到开机自启快捷方式" }
    exit 0
}

# ---------- 注册热键 ----------
$MOD_ALT = 0x0001; $MOD_CONTROL = 0x0002; $MOD_SHIFT = 0x0004
$MOD_NOREPEAT = 0x4000
switch ($Hotkey) {
    'ctrl+alt+a'   { $mods = $MOD_CONTROL -bor $MOD_ALT -bor $MOD_NOREPEAT;   $vk = 0x41 }
    'ctrl+shift+a' { $mods = $MOD_CONTROL -bor $MOD_SHIFT -bor $MOD_NOREPEAT; $vk = 0x41 }
}

$id = 0x5753
if (-not [HotkeyApi]::RegisterHotKey([IntPtr]::Zero, $id, [uint32]$mods, [uint32]$vk)) {
    Write-Error "热键注册失败（可能已被其他程序占用）。请换一个组合键或在参数里指定 -Hotkey ctrl+shift+a"
    exit 1
}
Write-Host "热键已就绪：$Hotkey （按 Ctrl+C 或关闭窗口退出）"

try {
    $msg = New-Object HotkeyApi+MSG
    while ([HotkeyApi]::GetMessage([ref]$msg, [IntPtr]::Zero, 0, 0) -gt 0) {
        if ($msg.message -eq 0x0312) {  # WM_HOTKEY
            # 用独立进程跑截图，避免阻塞热键消息循环
            Start-Process -FilePath 'powershell.exe' `
                -ArgumentList @('-STA','-WindowStyle','Hidden','-ExecutionPolicy','Bypass','-File',"`"$SHOT`"",'-Mode','region','-Quiet') `
                -WindowStyle Hidden | Out-Null
        } else {
            [void][HotkeyApi]::TranslateMessage([ref]$msg)
            [void][HotkeyApi]::DispatchMessage([ref]$msg)
        }
    }
} finally {
    [void][HotkeyApi]::UnregisterHotKey([IntPtr]::Zero, $id)
    Write-Host "热键已注销"
}
