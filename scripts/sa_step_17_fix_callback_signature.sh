#!/usr/bin/env bash
set -euo pipefail

# ============================================
# 功能：适配回调函数签名到新EventBus API
# 执行终端：终端3或任意空闲终端
# ============================================

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
ASR_MODULE="${ROOT}/modules/asr/asr_module.py"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

say "=== 适配回调函数签名 ==="

# 1. 备份
cp -p "${ASR_MODULE}" "${ASR_MODULE}.before_callback_fix_${TIMESTAMP}"
say "备份: asr_module.py.before_callback_fix_${TIMESTAMP}"

# 2. 修改_handle_command签名（第118行）
say "修改第118行: _handle_command签名"
sed -i 's/async def _handle_command(self, topic: str, payload: dict):/async def _handle_command(self, envelope):/' "${ASR_MODULE}"

# 3. 在方法开头插入envelope解析逻辑（在第119行后插入）
say "插入envelope解析逻辑"
sed -i '119a\        # 从envelope提取信息\n        payload = envelope.payload if hasattr(envelope, "payload") else envelope\n        event_type = getattr(envelope, "event_type", payload.get("type", ""))\n        # 重构topic以兼容旧逻辑\n        topic = f"sa/asr/cmd/{event_type.split(\".\")[-1] if \".\" in event_type else \"unknown\"}"' "${ASR_MODULE}"

# 4. 验证
if ! grep -q "async def _handle_command(self, envelope):" "${ASR_MODULE}"; then
    say "✗ 签名修改失败"
    cp -p "${ASR_MODULE}.before_callback_fix_${TIMESTAMP}" "${ASR_MODULE}"
    exit 1
fi

if ! grep -q "envelope.payload" "${ASR_MODULE}"; then
    say "✗ envelope解析未添加"
    cp -p "${ASR_MODULE}.before_callback_fix_${TIMESTAMP}" "${ASR_MODULE}"
    exit 1
fi

say "✓ 回调函数签名适配完成"
echo ""
say "下一步:"
echo "  1. 重启ASR: Ctrl+C 然后 bash scripts/start_asr.sh"
echo "  2. 发送start命令"
echo "  3. 说话测试"
