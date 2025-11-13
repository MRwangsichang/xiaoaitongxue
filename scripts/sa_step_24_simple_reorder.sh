#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
ASR_MODULE="${ROOT}/modules/asr/asr_module.py"

say "=== 简单粗暴地调整顺序 ==="

# 备份
cp -p "${ASR_MODULE}" "${ASR_MODULE}.before_simple_reorder"

# 删除第58-63行（subscribe那段）
sed -i '58,63d' "${ASR_MODULE}"

# 现在原来的第64-67行变成了58-61行
# 在第61行之后（init_provider和ready之后）插入subscribe代码
sed -i '61a\            # Subscribe to commands\n            await self.bus.start_listening({"sa/asr/cmd/#": self._handle_command})\n            self.logger.info("Subscribed to sa/asr/cmd/#")' "${ASR_MODULE}"

say "✓ 顺序已调整"

# 验证
say "验证修改后的第56-66行："
sed -n '56,66p' "${ASR_MODULE}"

# 语法检查
if python3 -m py_compile "${ASR_MODULE}" 2>/dev/null; then
    say "✓ 语法检查通过"
else
    say "✗ 语法错误，恢复备份"
    cp "${ASR_MODULE}.before_simple_reorder" "${ASR_MODULE}"
    exit 1
fi
