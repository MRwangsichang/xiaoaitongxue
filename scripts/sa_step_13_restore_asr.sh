#!/usr/bin/env bash
set -euo pipefail

# ============================================
# 功能：恢复10月12号验收通过的ASR模块
# 执行终端：终端3
# ============================================

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
ASR_MODULE="${ROOT}/modules/asr/asr_module.py"
BACKUP_FINAL="${ROOT}/modules/asr/asr_module.py.bak_final_1760198734"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

say "=== 恢复10月12号ASR模块 ==="

# 1. 备份当前的错误版本
if [ -f "${ASR_MODULE}" ]; then
    cp -p "${ASR_MODULE}" "${ASR_MODULE}.broken_${TIMESTAMP}"
    say "备份当前版本: asr_module.py.broken_${TIMESTAMP}"
fi

# 2. 恢复最终版本
if [ -f "${BACKUP_FINAL}" ]; then
    cp -p "${BACKUP_FINAL}" "${ASR_MODULE}"
    say "恢复最终版本: asr_module.py.bak_final_1760198734"
else
    say "✗ 备份文件不存在: ${BACKUP_FINAL}"
    exit 1
fi

# 3. 验证恢复
if grep -q "cloud_provider" "${ASR_MODULE}"; then
    say "✓ 恢复完成"
    say "验证: 第100行引用cloud_provider ✓"
else
    say "✗ 恢复失败，正在回滚..."
    cp -p "${ASR_MODULE}.broken_${TIMESTAMP}" "${ASR_MODULE}"
    exit 1
fi

echo ""
say "下一步:"
echo "  终端1: mosquitto_sub -t 'sa/asr/text' -v"
echo "  终端3: bash scripts/start_asr.sh"
echo "  说话测试，观察终端1只出现1条完整消息"
