<#
 .SYNOPSIS
    WorkBuddy 「截图」技能 - Windows 截图脚本
 .DESCRIPTION
    区域选框 / 全屏 / 当前窗口 / 延迟截图。
    依赖：仅 .NET Framework（WinForms + GDI+），无需安装任何第三方软件。
    输出：图片存到 -OutputDir（默认 图片\Screenshots），并复制到剪贴板。
    机器可读结果：结束时打印一行  SCREENSHOT_PATH=<绝对路径>
 .PARAMETER Mode
    region（默认，拖框选区域）/ full（整屏）/ window（当前前台窗口）
 .PARAMETER Delay
    截图前等待的秒数（默认 0）。用于截取右键菜单、下拉框、悬停提示等瞬逝界面。
 .PARAMETER OutputDir
    保存目录，默认 $env:USERPROFILE\Pictures\Screenshots
 .PARAMETER Quiet
    不打印过程信息（仍会打印 SCREENSHOT_PATH）
#>
param(
    [ValidateSet('region','full','window')]
    [string]$Mode = 'region',
    [int]$Delay = 0,
    [string]$OutputDir = '',
    [switch]$Quiet,
    [switch]$SelTest,  # 隐藏：用合成图验证区域裁剪数学，不弹窗
    [int]$TimeoutSec = 120   # 选框最长等待秒数，超时自动取消，避免遮罩卡死
)

$ErrorActionPreference = 'Stop'

function Write-Info($m){ if(-not $Quiet){ Write-Host $m } }

# ---------- 依赖加载 ----------
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Native {
    [DllImport("shcore.dll")]
    public static extern int SetProcessDpiAwareness(int value);
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, int nFlags);
    public struct RECT { public int Left, Top, Right, Bottom; }
}
"@

try { [void][Native]::SetProcessDpiAwareness(2) } catch { Write-Info "DPI_WARN: $_" }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---------- 输出目录 ----------
if ([string]::IsNullOrEmpty($OutputDir)) {
    $OutputDir = Join-Path $env:USERPROFILE 'Pictures\Screenshots'
}
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }

function New-ScreenshotFile {
    $stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    return Join-Path $OutputDir ("wb-screenshot-$stamp.png")
}

# ---------- 计算虚拟屏幕范围（物理像素） ----------
function Get-VirtualBounds {
    $screens = [System.Windows.Forms.Screen]::AllScreens
    $minLeft = [int]($screens | ForEach-Object { $_.Bounds.Left }  | Measure-Object -Minimum).Minimum
    $minTop  = [int]($screens | ForEach-Object { $_.Bounds.Top }   | Measure-Object -Minimum).Minimum
    $maxRight= [int]($screens | ForEach-Object { $_.Bounds.Right } | Measure-Object -Maximum).Maximum
    $maxBottom=[int]($screens | ForEach-Object { $_.Bounds.Bottom }| Measure-Object -Maximum).Maximum
    return @{ X=$minLeft; Y=$minTop; W=($maxRight-$minLeft); H=($maxBottom-$minTop) }
}

# ---------- 抓取整张虚拟屏幕到 Bitmap ----------
function Get-FullBitmap {
    $vb = Get-VirtualBounds
    $bmp = New-Object System.Drawing.Bitmap($vb.W, $vb.H)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    foreach ($s in [System.Windows.Forms.Screen]::AllScreens) {
        $g.CopyFromScreen([int]$s.Bounds.X, [int]$s.Bounds.Y,
                          [int]($s.Bounds.X - $vb.X), [int]($s.Bounds.Y - $vb.Y),
                          [System.Drawing.Size]::new([int]$s.Bounds.Width, [int]$s.Bounds.Height))
    }
    $g.Dispose()
    return $bmp
}

# ---------- 捕获指定窗口（PrintWindow，失败回退 CopyFromScreen） ----------
function Get-WindowBitmap {
    $hwnd = [Native]::GetForegroundWindow()
    if ($hwnd -eq [IntPtr]::Zero) { return $null }
    $r = New-Object Native+RECT
    if (-not [Native]::GetWindowRect($hwnd, [ref]$r)) { return $null }
    $w = $r.Right - $r.Left; $h = $r.Bottom - $r.Top
    if ($w -le 0 -or $h -le 0) { return $null }

    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $g.GetHdc()
    # PW_RENDERFULLCONTENT = 2：能抓到部分 DirectComposition 窗口内容
    $ok = [Native]::PrintWindow($hwnd, $hdc, 2)
    $g.ReleaseHdc($hdc)
    $g.Dispose()

    if (-not $ok) {
        # 回退：直接复制屏幕对应区域（要求窗口可见）
        $g2 = [System.Drawing.Graphics]::FromImage($bmp)
        $g2.CopyFromScreen($r.Left, $r.Top, 0, 0, [System.Drawing.Size]::new($w, $h))
        $g2.Dispose()
    }
    return $bmp
}

# ---------- 区域选框（冻结快照 + 遮罩拖拽） ----------
function Get-RegionBitmap($fullBmp) {
    $vb = Get-VirtualBounds
    $form = New-Object System.Windows.Forms.Form
    $form.FormBorderStyle = 'None'
    $form.WindowState = 'Normal'
    $form.StartPosition = 'Manual'
    $form.Location = [System.Drawing.Point]::new($vb.X, $vb.Y)
    $form.Size = [System.Drawing.Size]::new($vb.W, $vb.H)
    $form.TopMost = $true
    $form.ShowInTaskbar = $false
    $form.AutoScaleMode = 'None'
    $form.Cursor = [System.Windows.Forms.Cursors]::Cross
    $form.KeyPreview = $true

    # 暗化背景（冻结画面，避免遮罩本身进入截图）
    $dim = New-Object System.Drawing.Bitmap($vb.W, $vb.H)
    $dg = [System.Drawing.Graphics]::FromImage($dim)
    $dg.DrawImage($fullBmp, 0, 0)
    $dg.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(120,0,0,0))), 0, 0, $vb.W, $vb.H)
    $dg.Dispose()
    $form.BackgroundImage = $dim
    $form.BackgroundImageLayout = 'None'

    # 注意：事件处理器的 scriptblock 只能可靠访问 script 作用域，
    # 因此这里必须用 $script: 前缀，否则 Run 返回后读到的是函数局部变量（永远 null）
    $script:sel = $null
    $script:start = $null
    $script:dragging = $false
    $script:cancel = $false

    $form.Add_KeyDown({
        if ($_.KeyCode -eq 'Escape') { $script:cancel = $true; $form.Close() }
    })
    $form.Add_MouseDown({
        if ($_.Button -ne 'Left') { return }
        $script:dragging = $true
        $script:start = [System.Drawing.Point]::new($_.X, $_.Y)
        $script:sel = New-Object System.Drawing.Rectangle($_.X, $_.Y, 0, 0)
    })
    $form.Add_MouseMove({
        if (-not $script:dragging) { return }
        $x = [Math]::Min($script:start.X, $_.X)
        $y = [Math]::Min($script:start.Y, $_.Y)
        $w = [Math]::Abs($_.X - $script:start.X)
        $h = [Math]::Abs($_.Y - $script:start.Y)
        $script:sel = [System.Drawing.Rectangle]::new($x, $y, $w, $h)
        $form.Invalidate()
    })
    $form.Add_MouseUp({
        if ($_.Button -ne 'Left') { return }
        $script:dragging = $false
        if ($script:sel -and $script:sel.Width -gt 2 -and $script:sel.Height -gt 2) {
            $form.Close()
        } else {
            # 视为误点，重置
            $script:sel = $null
            $form.Invalidate()
        }
    })
    $form.Add_Paint({
        if ($script:sel -and $script:sel.Width -gt 0 -and $script:sel.Height -gt 0) {
            # 选区内部显示清晰原图
            $e.Graphics.DrawImage($fullBmp, $script:sel, $script:sel, [System.Drawing.GraphicsUnit]::Pixel)
            # 红色描边
            $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,255,64,64), 2)
            $e.Graphics.DrawRectangle($pen, $script:sel)
            $pen.Dispose()
            # 尺寸提示
            $txt = "$($script:sel.Width) x $($script:sel.Height)"
            $f = New-Object System.Drawing.Font('Consolas', 12)
            $sz = $e.Graphics.MeasureString($txt, $f)
            $bx = $script:sel.X; $by = $script:sel.Y - 22
            if ($by -lt 0) { $by = $script:sel.Y + 4 }
            $e.Graphics.FillRectangle([System.Drawing.Brushes]::FromArgb(200,0,0,0), $bx, $by, $sz.Width+8, $sz.Height+4)
            $e.Graphics.DrawString($txt, $f, [System.Drawing.Brushes]::White, $bx+4, $by+2)
            $f.Dispose()
        }
    })

    [System.Windows.Forms.Application]::EnableVisualStyles() | Out-Null
    if ($TimeoutSec -gt 0) {
        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = $TimeoutSec * 1000
        $timer.Add_Tick({ $script:cancel = $true; $form.Close() })
        $timer.Start()
    }
    [System.Windows.Forms.Application]::Run($form)

    if ($script:cancel -or $null -eq $script:sel -or $script:sel.Width -le 2 -or $script:sel.Height -le 2) {
        $dim.Dispose(); $fullBmp.Dispose()
        return $null
    }
    $sel = $script:sel
    # 从冻结全图裁剪选区
    $crop = New-Object System.Drawing.Bitmap($sel.Width, $sel.Height)
    $cg = [System.Drawing.Graphics]::FromImage($crop)
    $cg.DrawImage($fullBmp, [System.Drawing.Rectangle]::new(0,0,$sel.Width,$sel.Height), $sel, [System.Drawing.GraphicsUnit]::Pixel)
    $cg.Dispose()
    $dim.Dispose(); $fullBmp.Dispose()
    return $crop
}

# ================= 主流程 =================
if ($SelTest) {
    # 合成一张 4 色块全图，裁剪右下角区域，验证裁剪坐标正确
    $vb = Get-VirtualBounds
    $full = New-Object System.Drawing.Bitmap(400, 300)
    $fg = [System.Drawing.Graphics]::FromImage($full)
    $fg.FillRectangle([System.Drawing.Brushes]::Red,    0,0,200,150)
    $fg.FillRectangle([System.Drawing.Brushes]::Green,200,0,200,150)
    $fg.FillRectangle([System.Drawing.Brushes]::Blue,   0,150,200,150)
    $fg.FillRectangle([System.Drawing.Brushes]::Yellow,200,150,200,150)
    $fg.Dispose()
    $sel = [System.Drawing.Rectangle]::new(200,150,150,100)  # 应包含黄+部分绿蓝
    $crop = New-Object System.Drawing.Bitmap($sel.Width, $sel.Height)
    $cg = [System.Drawing.Graphics]::FromImage($crop)
    $cg.DrawImage($full, [System.Drawing.Rectangle]::new(0,0,$sel.Width,$sel.Height), $sel, [System.Drawing.GraphicsUnit]::Pixel)
    $cg.Dispose(); $full.Dispose()
    $path = Join-Path $OutputDir "wb-seltest.png"
    $crop.Save($path, [System.Drawing.Imaging.ImageFormat]::Png); $crop.Dispose()
    Write-Host "SCREENSHOT_PATH=$path"
    exit 0
}

try {
    if ($Delay -gt 0) {
        Write-Info "将在 $Delay 秒后截图，请切到要截取的窗口…"
        Start-Sleep -Seconds $Delay
    }

    $bmp = $null
    switch ($Mode) {
        'full'   { $bmp = Get-FullBitmap }
        'window' {
            $bmp = Get-WindowBitmap
            if ($null -eq $bmp) {
                Write-Error "无法获取前台窗口，已取消。"
                exit 2
            }
        }
        'region' {
            $full = Get-FullBitmap
            $bmp = Get-RegionBitmap $full
            if ($null -eq $bmp) {
                Write-Info "已取消截图（Esc 或无效选区）。"
                exit 3
            }
        }
    }

    $path = New-ScreenshotFile
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)

    # 复制到剪贴板
    try { [System.Windows.Forms.Clipboard]::SetImage($bmp) } catch { Write-Info "CLIP_WARN: 复制到剪贴板失败" }

    $bmp.Dispose()
    Write-Host "SCREENSHOT_PATH=$path"
    $w,$h = 0,0
    Write-Info "已保存：$path"
    exit 0
} catch {
    Write-Error "截图失败：$_"
    exit 1
}
