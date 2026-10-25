#!/usr/bin/env bash
# WorkBuddy 「截图」技能 - macOS 截图脚本
# 依赖：系统自带 screencapture（无需安装任何东西）
# 用法：./screenshot.sh [region|full|window] [延迟秒数] [输出目录]
# 结果：打印 SCREENSHOT_PATH=<绝对路径>；取消则打印 CANCELLED 并退出 3

set -uo pipefail

MODE="${1:-region}"
DELAY="${2:-0}"
OUTDIR="${3:-$HOME/Pictures/Screenshots}"

mkdir -p "$OUTDIR" 2>/dev/null || true
STAMP="$(date +%Y-%m-%d_%H-%M-%S)"
FILE="$OUTDIR/wb-screenshot-$STAMP.png"

if [ "$DELAY" -gt 0 ] 2>/dev/null; then
  echo "将在 $DELAY 秒后截图，请切到要截取的窗口…"
  sleep "$DELAY"
fi

case "$MODE" in
  region) screencapture -x -i "$FILE" ;;   # -i 交互式拖框选区
  full)   screencapture -x "$FILE" ;;
  window) screencapture -x -w "$FILE" ;;   # -w 点选窗口
  *) echo "未知模式: $MODE" >&2; exit 2 ;;
esac

if [ -f "$FILE" ]; then
  # 复制到剪贴板（便于手动 Cmd+V）
  osascript -e "set the clipboard to (read (POSIX file \"$FILE\") as «class PNGf»)" >/dev/null 2>&1 || true
  echo "SCREENSHOT_PATH=$FILE"
  echo "已保存：$FILE"
  exit 0
else
  echo "CANCELLED"
  exit 3
fi
