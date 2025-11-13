#!/usr/bin/env bash
set -euo pipefail

# ============================================
# 功能：适配asr_module.py到新EventBus API
# 执行终端：终端3
# ============================================

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
ASR_MODULE="${ROOT}/modules/asr/asr_module.py"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

say "=== 适配ASR模块到新EventBus API ==="

# 1. 备份
cp -p "${ASR_MODULE}" "${ASR_MODULE}.before_api_fix_${TIMESTAMP}"
say "备份: asr_module.py.before_api_fix_${TIMESTAMP}"

# 2. 修改导入（第7行）
say "修改第7行: MQTTEventBus → EventBus"
sed -i 's/from core import get_logger, load_config, MQTTEventBus, HealthReporter/from core import get_logger, load_config, HealthReporter\nfrom core.event_bus import EventBus/' "${ASR_MODULE}"

# 3. 修改类型注解（第31行附近）
say "修改第31行: 类型注解"
sed -i 's/self.bus: Optional\[MQTTEventBus\]/self.bus: Optional[EventBus]/' "${ASR_MODULE}"

# 4. 修改初始化（第47行附近）
say "修改第47行: 初始化参数"
sed -i 's/self.bus = MQTTEventBus()/self.bus = EventBus(module_name="asr")/' "${ASR_MODULE}"

# 5. 删除connect调用（第48行）
say "删除第48行: bus.connect()"
sed -i '/await self.bus.connect()/d' "${ASR_MODULE}"

# 6. 修改publish调用 - text（第187行附近）
say "修改第187行: publish调用(text)"
sed -i 's|await self.bus.publish("sa/asr/text", payload)|await self.bus.publish("sa/asr/text", "text", payload)|' "${ASR_MODULE}"

# 7. 修改publish调用 - error（第193行附近）
say "修改第193行: publish调用(error)"
sed -i 's|await self.bus.publish("sa/asr/error",|await self.bus.publish("sa/asr/error", "error",|' "${ASR_MODULE}"

# 8. 验证修改
FAIL=0

if ! grep -q "from core.event_bus import EventBus" "${ASR_MODULE}"; then
    say "✗ EventBus导入失败"
    FAIL=1
fi

if grep -q "await self.bus.connect()" "${ASR_MODULE}"; then
    say "✗ connect()未删除"
    FAIL=1
fi

if ! grep -q 'publish("sa/asr/text", "text"' "${ASR_MODULE}"; then
    say "✗ publish(text)修改失败"
    FAIL=1
fi

if [ $FAIL -eq 1 ]; then
    say "✗ 修改失败，正在回滚..."
    cp -p "${ASR_MODULE}.before_api_fix_${TIMESTAMP}" "${ASR_MODULE}"
    exit 1
fi

say "✓ API适配完成"
echo ""
say "下一步:"
echo "  终端3: bash scripts/start_asr.sh"
echo "  应该能正常启动了"
