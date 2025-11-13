#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
ASR_MODULE="${ROOT}/modules/asr/asr_module.py"

say "=== 修复type字段提取逻辑 ==="

# 找到event_type提取那行（约第128行），替换为正确逻辑
sed -i "s/event_type = getattr(envelope, \"event_type\", payload.get(\"type\", \"\"))/event_type = envelope.__dict__.get('type', '') or getattr(envelope, 'type', '')/" "${ASR_MODULE}"

# 验证
if grep -q "envelope.__dict__.get('type'" "${ASR_MODULE}"; then
    say "✓ type提取逻辑已修复"
else
    say "✗ 修复失败"
    exit 1
fi

say "重启ASR，再发送start命令应该就能工作了！"
