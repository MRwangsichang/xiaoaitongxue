#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/MRwang/smart_assistant"
cd "$ROOT" || exit 1

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

say "=== 启动视觉扫描服务 ==="

# 设置环境变量
export PYTHONPATH="$ROOT:${PYTHONPATH:-}"

# 停止可能占用相机的服务
sudo systemctl stop cam.service greet.service 2>/dev/null || true
systemctl --user stop pipewire.service pipewire.socket pipewire-pulse.service wireplumber.service 2>/dev/null || true

say "✓ 相机服务已停止"
say "当前目录: $(pwd)"
say ""

# 启动扫描服务
python3 modules/vision/scanner.py
