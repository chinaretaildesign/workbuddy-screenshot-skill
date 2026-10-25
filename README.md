# WorkBuddy 截图技能（Screenshot Skill）

> 让 WorkBuddy 拥有「截图提问」能力：**一句话截屏 → AI 自己看图 → 直接回答**，不用再 `Win+Shift+S` 再 `Ctrl+V`。

WorkBuddy 本身没有截图入口。这个技能补上这一块：你说「截个报错，这个怎么修」，
它会自己弹框让你拖选区域，截完自动存盘、进剪贴板，然后**直接读图回答**。

支持 **Windows** 与 **macOS**，零第三方依赖（Windows 只用系统自带 .NET，macOS 只用系统自带 `screencapture`）。

---

## 效果

| 你说 | 它做 |
|---|---|
| 帮我截个图 | 弹出遮罩，拖框选区，截完看图问你要做什么 |
| 截个报错，怎么修 | 选区截图 → 认出错因 → 给出修法 |
| 全屏截一下 | 抓整个桌面（多显示器自动合并） |
| 截当前窗口 | 只抓当前前台窗口 |
| 截个右键菜单 | 延迟 3 秒，等你把菜单展开再抓 |

---

## 安装

### Windows

```powershell
git clone https://github.com/chinaretaildesign/workbuddy-screenshot-skill.git
cd workbuddy-screenshot-skill
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

装完到 `%USERPROFILE%\.workbuddy\skills\screenshot`，重启 WorkBuddy（或新开一个任务）即可。
没有 git 也可以直接下载 ZIP，解压后跑同一条 `install.ps1`。

### macOS

```bash
git clone https://github.com/chinaretaildesign/workbuddy-screenshot-skill.git
cd workbuddy-screenshot-skill
bash install.sh
```

首次截图 macOS 会请求「屏幕录制」权限，去 **系统设置 → 隐私与安全性 → 屏幕录制** 里勾选终端/WorkBuddy。

### 验证

在 WorkBuddy 对话框里输入：

```
帮我截个图
```

看到全屏变暗、可以拖框，就说明装好了。

---

## 用法

全部通过自然语言，不需要记命令。也可以显式指定：

```powershell
# Windows 手动运行
powershell -STA -ExecutionPolicy Bypass -File "$env:USERPROFILE\.workbuddy\skills\screenshot\scripts\screenshot.ps1" -Mode region
```

```bash
# macOS 手动运行
bash ~/.workbuddy/skills/screenshot/scripts/screenshot.sh region
```

参数：

| 参数 | 取值 | 默认 | 说明 |
|---|---|---|---|
| `-Mode` | `region` / `full` / `window` | `region` | 区域选框 / 全屏 / 当前窗口 |
| `-Delay` | 秒 | `0` | 截图前等待，截菜单、下拉框必需 |
| `-OutputDir` | 目录 | `图片\Screenshots` | 保存位置 |
| `-TimeoutSec` | 秒 | `120` | 选框最长等待，超时自动取消 |

截图保存在 `%USERPROFILE%\Pictures\Screenshots\wb-screenshot-<时间戳>.png`，
同时复制进剪贴板——想手动贴到别处随时 `Ctrl+V`。

### 取消

拖框时按 `Esc` 取消；不做任何操作则 120 秒后自动取消，不会卡住你的屏幕。

---

## 全局热键（可选，仅 Windows）

想像系统截图那样随时按一下？加一个常驻热键 `Ctrl+Alt+A`：

```powershell
# 前台启动（关掉窗口就停）
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.workbuddy\skills\screenshot\scripts\hotkey.ps1"

# 加入开机自启
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.workbuddy\skills\screenshot\scripts\hotkey.ps1" -InstallStartup
```

按下即弹框选区，截完存盘 + 进剪贴板。**注意**：热键版只负责截图和剪贴板，
不会自动把图发进对话——需要在输入框按 `Ctrl+V`。这是设计取舍：模拟按键强制粘贴容易粘错窗口。

---

## 隐私

- 截图**只落本地磁盘** + 系统剪贴板，**绝不上传**任何服务器。
- 图片存在你自己的 `Pictures\Screenshots`，跟系统截图同一个地方，随时可查可删。
- 不做自动清理——你的图不该在你不知情时消失。想清理就说「清理旧截图」，它会先列清单等你确认。

---

## 已知限制

- **多显示器 + 不同缩放比例**：已做 DPI 感知，正常场景坐标正确；若在两个缩放不同的屏幕之间跨屏拖框，
  极端情况可能错位，欢迎提 issue。
- **窗口模式**：用 `PrintWindow` 抓取，个别启用硬件加速的应用（部分游戏、播放器）可能抓到黑图，
  此时会回退为屏幕区域复制（要求窗口可见）。
- 标注功能（矩形、箭头、马赛克）尚未实现，见 Roadmap。

## Roadmap

- [x] v1.0.0 区域 / 全屏 / 窗口 / 延迟截图，Windows + macOS
- [ ] v1.1 截图标注：矩形、箭头、马赛克、文字
- [ ] v1.2 截图历史面板（可回看最近 N 张）
- [ ] v1.3 OCR 文本直出（截图里的文字直接可复制）

## 许可

[MIT](LICENSE)

---

# English

A screenshot skill for **WorkBuddy**: one command captures your screen, the AI reads it and answers.
Replaces the two-step `Win+Shift+S` → `Ctrl+V` dance with a single request.

Works on **Windows** and **macOS** with **zero third-party dependencies**
(Windows uses built-in .NET, macOS uses built-in `screencapture`).

## Install

Windows:

```powershell
git clone https://github.com/chinaretaildesign/workbuddy-screenshot-skill.git
cd workbuddy-screenshot-skill
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

macOS:

```bash
git clone https://github.com/chinaretaildesign/workbuddy-screenshot-skill.git
cd workbuddy-screenshot-skill
bash install.sh
```

On macOS grant **Screen Recording** permission on first use
(System Settings → Privacy & Security → Screen Recording).

## Usage

Just ask in chat: *"take a screenshot"*, *"capture this error, how do I fix it"*,
*"screenshot the current window"*, *"capture the right-click menu in 3 seconds"*.

Options: `-Mode region|full|window` (default `region`), `-Delay <sec>`, `-OutputDir <dir>`,
`-TimeoutSec <sec>` (auto-cancel, default 120).

Screenshots are saved to `Pictures/Screenshots/wb-screenshot-<timestamp>.png` and copied to the clipboard.

## Optional global hotkey (Windows)

`Ctrl+Alt+A` to capture anywhere. It only captures and copies to clipboard — it does **not**
auto-paste into the chat (simulated keystrokes are too fragile).

## Privacy

Screenshots stay on your disk and in your clipboard. Nothing is uploaded, ever. No auto-deletion.

## Status

Annotations (rect / arrow / mosaic) are planned for v1.1.

## License

[MIT](LICENSE)
