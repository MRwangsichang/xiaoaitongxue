#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
ASR_MODULE="${ROOT}/modules/asr/asr_module.py"

say "=== 调整初始化顺序 ==="

# 备份
cp -p "${ASR_MODULE}" "${ASR_MODULE}.before_reorder_$(date +%Y%m%d_%H%M%S)"

# 使用Python脚本调整顺序
python3 - <<'PYCODE'
file_path = "/home/MRwang/smart_assistant/modules/asr/asr_module.py"

with open(file_path, 'r') as f:
    content = f.read()

# 找到并交换两段代码的顺序
# 将 "Subscribe to commands" 段落移到 "Initialize provider" 后面

import re

# 匹配并提取两段
pattern = r'(            # Subscribe to commands\n            await self\.bus\.start_listening.*?\n            self\.logger\.info\("订阅主题: sa/asr/cmd/#"\)\n)(            # Initialize provider\n            await self\._init_provider\(\)\n            self\.running = True\n            self\.logger\.info\("ASR module ready"\)\n)'

def swap(match):
    subscribe_block = match.group(1)
    init_block = match.group(2)
    return init_block + subscribe_block

content = re.sub(pattern, swap, content, flags=re.DOTALL)

with open(file_path, 'w') as f:
    f.write(content)

print("✓ 顺序已调整")
PYCODE

# 验证语法
if python3 -m py_compile "${ASR_MODULE}" 2>/dev/null; then
    say "✓ 语法检查通过"
else
    say "✗ 语法错误"
    python3 -m py_compile "${ASR_MODULE}"
    exit 1
fi

say "重启ASR，provider会先初始化，然后才启动监听"
