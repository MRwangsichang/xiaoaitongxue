#!/usr/bin/env bash
set -euo pipefail

# ============================================
# 功能：适配HealthReporter API
# 执行终端：终端3
# ============================================

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
ASR_MODULE="${ROOT}/modules/asr/asr_module.py"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

say "=== 适配HealthReporter API ==="

# 1. 备份
cp -p "${ASR_MODULE}" "${ASR_MODULE}.before_health_fix_${TIMESTAMP}"
say "备份: asr_module.py.before_health_fix_${TIMESTAMP}"

# 2. 删除event_bus参数（使用多行sed删除）
say "删除 event_bus=self.bus 参数"
sed -i '/event_bus=self.bus,/d' "${ASR_MODULE}"

# 3. 验证
if grep -q "event_bus=self.bus" "${ASR_MODULE}"; then
    say "✗ event_bus参数未删除"
    cp -p "${ASR_MODULE}.before_health_fix_${TIMESTAMP}" "${ASR_MODULE}"
    exit 1
fi

say "✓ HealthReporter API适配完成"
echo ""
say "下一步:"
echo "  bash scripts/start_asr.sh"
