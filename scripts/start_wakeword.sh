#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/MRwang/smart_assistant"
cd "$ROOT" || exit 1

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

say "=== 启动唤醒词服务 ==="

# 设置环境变量
export PYTHONPATH="$ROOT:${PYTHONPATH:-}"

# 加载.env.local（GROK API Key等）
if [ -f "${ROOT}/.env.local" ]; then
    set -o allexport
    source "${ROOT}/.env.local"
    set +o allexport
    say "✓ 环境变量已加载"
fi

say "当前目录: $(pwd)"
say ""

# 启动唤醒词服务
python3 modules/wakeword/wakeword_service.py
