---
name: screenshot
version: 1.0.0
display_name: 截图
display_name_en: Screenshot
description: "在对话框里直接截屏并让 AI 看图说话。当用户说 截图、截屏、抓屏、截个图、帮我截图、看一下我的屏幕、截这块、截报错、screenshot、screen capture、capture screen 时使用。支持区域选框、全屏、当前窗口、延迟截图，截完自动存盘+进剪贴板并让 AI 直接读图分析。"
description_zh: "WorkBuddy 缺失的屏幕截图能力：一句话让 AI 自己截屏、看图、回答。区域选框 / 全屏 / 当前窗口 / 延迟截图四种模式，截完自动存到 图片\Screenshots 并复制到剪贴板，AI 直接读图分析，不用再手动粘贴。支持 Windows 与 macOS，零第三方依赖。"
description_en: "Screenshot inside the chat: one command captures your screen, then the AI reads and answers. Region selection, full screen, active window, and delayed capture; saved to Pictures/Screenshots and copied to clipboard. Windows and macOS, no third-party dependencies."
allowed-tools: PowerShell,Bash,Read
visibility: "public"
---

# 截图（Screenshot）

让 WorkBuddy 具备"截图提问"能力：**截 → 存 → 复制剪贴板 → AI 直接看图回答**，一条命令完成，
用户不需要再用 `Win+Shift+S` + `Ctrl+V` 的两段操作。

## 什么时候用

用户说这些话时触发本技能：

- 截图 / 截屏 / 抓屏 / 截个图 / 帮我截图 / 截一下
- 看一下我的屏幕 / 看看这个界面 / 截这块
- 截个报错 / 把这个弹窗截下来 / 这个报错怎么修（配合截图意图）
- screenshot / screen capture / capture my screen

## 执行流程（Agent 必读）

1. **判断平台**：Windows 用 `scripts/screenshot.ps1`，macOS 用 `scripts/screenshot.sh`。
2. **判断模式**（从用户措辞推断，拿不准就用 `region`）：

   | 用户说法 | Mode | 说明 |
   |---|---|---|
   | 截一块 / 截这块 / 截个图 | `region` | 默认。弹出遮罩，用户拖框选区 |
   | 全屏 / 整个屏幕 | `full` | 直接抓整个虚拟屏幕（多显示器会合并成一张） |
   | 当前窗口 / 这个窗口 | `window` | 抓当前前台窗口 |
   | 截右键菜单 / 下拉框 / 悬停提示 / 3 秒后截 | 加 `-Delay N` | 瞬逝界面必须先延迟，让用户切窗口+展开菜单 |

3. **执行脚本**：

   Windows —— 必须用 **PowerShell 工具**调用（`-STA` 是弹窗必要条件），不要用 Bash 转 PowerShell：

   ```powershell
   powershell -STA -ExecutionPolicy Bypass -File "<技能目录>/scripts/screenshot.ps1" -Mode region
   ```

   带延迟的例子：

   ```powershell
   powershell -STA -ExecutionPolicy Bypass -File "<技能目录>/scripts/screenshot.ps1" -Mode full -Delay 3
   ```

   macOS：

   ```bash
   bash "<技能目录>/scripts/screenshot.sh" region 0
   ```

4. **解析输出**：stdout 里会有一行 `SCREENSHOT_PATH=<绝对路径>`。取这个路径。
5. **读图**：用 Read 工具读取该 PNG 路径（Read 支持图片，能直接"看见"）。
6. **回答**：
   - 用户**带了问题**（如"截个报错，这个怎么修"）→ 直接针对图中内容回答。
   - 用户**没带问题**（只说"截个图"）→ 先用一两句话概括画面是什么，再问他要做什么。不要干看着不说话。
7. **异常处理**：
   - 退出码 `3` 或输出 `CANCELLED` → 用户主动取消（Esc / 超时）。回一句"已取消"，**不要自动重试**。
   - 退出码 `1`/`2` → 把错误原文告诉用户，别自己瞎猜原因。

## 参数速查

| 参数 | 取值 | 默认 | 说明 |
|---|---|---|---|
| `-Mode` | `region` / `full` / `window` | `region` | 取景方式 |
| `-Delay` | 秒数 | `0` | 截图前等待，截菜单/下拉必需的 |
| `-OutputDir` | 目录 | `图片\Screenshots` | 保存位置 |
| `-TimeoutSec` | 秒数 | `120` | 选框最长等待，超时自动取消 |
| `-Quiet` | 开关 | 关 | 少打印过程信息 |

## 重要约束

- **绝不把截图上传到任何外部服务**。图片只落本地磁盘 + 系统剪贴板。
- 不要用模拟按键（SendKeys）把图片"自动粘"进输入框——会粘错窗口、打乱用户正在输入的文本。
  剪贴板已经准备好了，需要时提示用户 `Ctrl+V` 即可。
- 脚本文件是 **UTF-8 with BOM**，改动时不要去掉 BOM，否则 Windows PowerShell 会把中文读成乱码并报语法错。
- 多显示器 + 高 DPI：脚本已做 DPI 感知（`SetProcessDpiAwareness(2)`），坐标用物理像素。
  若用户反馈多屏截图错位，先确认是否在缩放不同的屏幕之间拖框，属已知待优化项。

## 清理旧截图

用户说"清理截图 / 删掉旧截图"时，先列出候选（按时间倒序），**确认后再删**：

```powershell
Get-ChildItem "$env:USERPROFILE\Pictures\Screenshots\wb-screenshot-*.png" |
  Sort-Object LastWriteTime -Descending | Select-Object Name, Length, LastWriteTime
```

删除时只删匹配 `wb-screenshot-*.png` 的文件，**不要碰用户的其他截图**。

## 全局热键（可选组件）

`scripts/hotkey.ps1` 常驻监听 `Ctrl+Alt+A`：按下 → 弹框选区 → 存盘 + 复制到剪贴板。
它**不会**把图自动送进对话，用户仍需在输入框 `Ctrl+V`。开启/关闭开机自启：

```powershell
powershell -ExecutionPolicy Bypass -File "<技能目录>/scripts/hotkey.ps1" -InstallStartup
powershell -ExecutionPolicy Bypass -File "<技能目录>/scripts/hotkey.ps1" -UninstallStartup
```
