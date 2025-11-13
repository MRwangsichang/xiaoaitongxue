#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ASR_MODULE="/home/MRwang/smart_assistant/modules/asr/asr_module.py"

say "=== 修复导入路径 ==="

# 备份
cp -p "${ASR_MODULE}" "${ASR_MODULE}.before_fix_imports"

# 替换所有相对导入为绝对导入
sed -i 's/from \.cloud_provider import/from modules.asr.cloud_provider import/g' "${ASR_MODULE}"
sed -i 's/from \.mock_provider import/from modules.asr.mock_provider import/g' "${ASR_MODULE}"

# 验证
if python3 -m py_compile "${ASR_MODULE}" 2>/dev/null; then
    say "✓ 导入已修复，语法检查通过"
else
    say "✗ 语法错误，恢复备份"
    cp "${ASR_MODULE}.before_fix_imports" "${ASR_MODULE}"
    exit 1
fi
