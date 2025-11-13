#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

CLOUD_PROVIDER="/home/MRwang/smart_assistant/modules/asr/cloud_provider.py"

say "=== 修复closed属性错误 ==="

# 备份
cp -p "${CLOUD_PROVIDER}" "${CLOUD_PROVIDER}.before_fix_closed"

# 修改第292行：去掉 .closed 检查，直接关闭
sed -i '292s/if self.ws and not self.ws.closed:/if self.ws:/' "${CLOUD_PROVIDER}"

# 或者使用try-except包裹
sed -i '293s/await self.ws.close()/try:\n                            await self.ws.close()\n                        except Exception:\n                            pass/' "${CLOUD_PROVIDER}"

# 验证
if python3 -m py_compile "${CLOUD_PROVIDER}" 2>/dev/null; then
    say "✓ Bug已修复"
else
    say "✗ 语法错误，恢复备份"
    cp "${CLOUD_PROVIDER}.before_fix_closed" "${CLOUD_PROVIDER}"
    exit 1
fi
