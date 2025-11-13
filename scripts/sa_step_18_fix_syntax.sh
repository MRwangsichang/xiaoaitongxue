#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
ASR_MODULE="${ROOT}/modules/asr/asr_module.py"

say "=== 修复f-string语法错误 ==="

# 修改第124行：把内层双引号改成单引号
sed -i "124s/.*/        topic = f\"sa\/asr\/cmd\/{event_type.split('.')[-1] if '.' in event_type else 'unknown'}\"/" "${ASR_MODULE}"

# 验证
if python3 -m py_compile "${ASR_MODULE}" 2>/dev/null; then
    say "✓ 语法错误已修复"
else
    say "✗ 仍有语法错误"
    python3 -m py_compile "${ASR_MODULE}"
    exit 1
fi

say "可以重新启动ASR了"
