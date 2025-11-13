#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
ASR_MODULE="${ROOT}/modules/asr/asr_module.py"

say "=== 修复缩进错误 ==="

# 查看第110-120行的内容
say "检查第110-120行..."
sed -n '110,120p' "${ASR_MODULE}"

# 修复：确保第114行的else前面有12个空格（3个tab缩进）
sed -i '114s/^[[:space:]]*/            /' "${ASR_MODULE}"

# 验证语法
if python3 -m py_compile "${ASR_MODULE}" 2>/dev/null; then
    say "✓ 缩进已修复"
else
    say "✗ 仍有语法错误，显示详细错误："
    python3 -m py_compile "${ASR_MODULE}"
    exit 1
fi
