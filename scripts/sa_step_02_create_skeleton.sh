#!/usr/bin/env bash
set -euo pipefail
DRY_RUN="${DRY_RUN:-1}"

say(){ printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }
ok(){ printf "✓ %s\n" "$*"; }

ROOT="/home/MRwang/smart_assistant"
echo "=== CREATING PROJECT SKELETON ==="

DIRS=(
  "core"
  "modules/vision"
  "modules/rules"
  "modules/asr"
  "modules/tts"
  "modules/ir"
  "modules/music"
  "modules/display"
  "modules/memory"
  "config"
  "data/rules"
  "data/faces"
  "data/ir_codes"
  "data/music_playlists"
  "data/memory"
  "logs"
  "scripts"
  "tests"
  "docs"
)

if [ "$DRY_RUN" = "1" ]; then
  say "DRY-RUN: Would create directories:"
  for d in "${DIRS[@]}"; do
    echo "  - $ROOT/$d"
  done
  exit 0
fi

# 创建目录
say "Creating directories..."
for d in "${DIRS[@]}"; do
  mkdir -p "$ROOT/$d"
  ok "$d/"
done

# 设置权限（确保当前用户可读写）
say "Setting permissions..."
chmod -R u+rwX "$ROOT"

# 创建标记文件（用于验证）
echo "# Smart Assistant Project Root" > "$ROOT/README.md"
echo "Generated at: $(date)" >> "$ROOT/README.md"

# 在每个模块创建占位文件
say "Creating placeholder files..."
for mod in vision rules asr tts ir music display memory; do
  touch "$ROOT/modules/$mod/__init__.py"
  echo "# $mod module" > "$ROOT/modules/$mod/__init__.py"
done

touch "$ROOT/core/__init__.py"
echo "# Core framework" > "$ROOT/core/__init__.py"

# 打印树形结构（仅2层）
say "Directory structure created:"
if command -v tree &>/dev/null; then
  tree -L 2 -d "$ROOT"
else
  find "$ROOT" -maxdepth 2 -type d | sort
fi

echo ""
echo "=== SKELETON CREATED ==="
