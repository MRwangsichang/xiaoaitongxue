#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
ASR_MODULE="${ROOT}/modules/asr/asr_module.py"

say "=== 修复调试日志语法错误 ==="

# 找到包含 "__dict__" 的行并修复引号
sed -i "s/getattr(envelope, \"__dict__\", None)/getattr(envelope, '__dict__', None)/g" "${ASR_MODULE}"

# 验证语法
if python3 -m py_compile "${ASR_MODULE}" 2>/dev/null; then
    say "✓ 语法错误已修复"
else
    say "✗ 仍有语法错误"
    python3 -m py_compile "${ASR_MODULE}"
    exit 1
fi
