#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

CLOUD_PROVIDER="/home/MRwang/smart_assistant/modules/asr/cloud_provider.py"

say "=== 优化WebSocket重连速度 ==="

# 备份
cp -p "${CLOUD_PROVIDER}" "${CLOUD_PROVIDER}.before_optimize_reconnect"

# 在第290行（清空_last_result之后）插入主动关闭逻辑
sed -i '290a\                        # 主动关闭WebSocket，不等讯飞超时\n                        if self.ws and not self.ws.closed:\n                            await self.ws.close()\n                            self.logger.debug("WebSocket主动关闭，准备下一轮")' "${CLOUD_PROVIDER}"

# 验证语法
if python3 -m py_compile "${CLOUD_PROVIDER}" 2>/dev/null; then
    say "✓ 优化完成"
    say ""
    say "预期效果："
    say "  - 识别结果出来后立刻关闭WebSocket"
    say "  - 不再等待5秒超时"
    say "  - 下次录音间隔从12秒缩短到7秒"
else
    say "✗ 语法错误，恢复备份"
    cp "${CLOUD_PROVIDER}.before_optimize_reconnect" "${CLOUD_PROVIDER}"
    exit 1
fi
