#!/usr/bin/env bash
set -euo pipefail

# ============================================
# 功能：适配EventBus订阅API
# 执行终端：终端3
# ============================================

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
ASR_MODULE="${ROOT}/modules/asr/asr_module.py"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

say "=== 适配EventBus订阅API ==="

# 1. 备份
cp -p "${ASR_MODULE}" "${ASR_MODULE}.before_subscribe_fix_${TIMESTAMP}"
say "备份: asr_module.py.before_subscribe_fix_${TIMESTAMP}"

# 2. 替换subscribe为start_listening（第60行）
say "修改第60行: subscribe → start_listening"
sed -i 's/await self.bus.subscribe("sa\/asr\/cmd\/#", self._handle_command)/await self.bus.start_listening({"sa\/asr\/cmd\/#": self._handle_command})/' "${ASR_MODULE}"

# 3. 验证
if grep -q "bus.subscribe" "${ASR_MODULE}"; then
    say "✗ subscribe未替换"
    cp -p "${ASR_MODULE}.before_subscribe_fix_${TIMESTAMP}" "${ASR_MODULE}"
    exit 1
fi

if ! grep -q "start_listening" "${ASR_MODULE}"; then
    say "✗ start_listening未添加"
    cp -p "${ASR_MODULE}.before_subscribe_fix_${TIMESTAMP}" "${ASR_MODULE}"
    exit 1
fi

say "✓ 订阅API适配完成"
echo ""
say "下一步:"
echo "  bash scripts/start_asr.sh"
echo "  这次应该真的能启动了！"
