#!/usr/bin/env bash
# WorkBuddy 「截图」技能 - 一键安装（macOS / Linux 目录结构一致）
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${1:-$HOME/.workbuddy/skills}"
DEST="$ROOT/screenshot"

echo "源目录：$SRC"
echo "安装到：$DEST"

mkdir -p "$ROOT"
if [ -d "$DEST" ]; then
  BAK="$DEST.bak-$(date +%Y%m%d-%H%M%S)"
  echo "检测到已安装，旧版本备份到：$BAK"
  mv "$DEST" "$BAK"
fi
mkdir -p "$DEST"

cp "$SRC/SKILL.md" "$DEST/"
cp -R "$SRC/scripts" "$DEST/"
[ -f "$SRC/README.md" ] && cp "$SRC/README.md" "$DEST/"
[ -f "$SRC/LICENSE" ] && cp "$SRC/LICENSE" "$DEST/"

rm -f "$DEST"/scripts/_* 2>/dev/null || true
chmod +x "$DEST"/scripts/screenshot.sh 2>/dev/null || true

echo
echo "安装完成。"
echo "验证：在 WorkBuddy 里输入「帮我截个图」"
echo "手动运行：bash \"$DEST/scripts/screenshot.sh\" region"
