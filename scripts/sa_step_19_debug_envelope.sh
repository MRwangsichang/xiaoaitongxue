#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
ASR_MODULE="${ROOT}/modules/asr/asr_module.py"

say "=== 添加调试日志 ==="

# 在第120行后插入详细的调试日志
sed -i '120a\        # DEBUG: 打印envelope结构\n        self.logger.info(f"DEBUG envelope类型: {type(envelope)}")\n        self.logger.info(f"DEBUG envelope内容: {envelope}")\n        self.logger.info(f"DEBUG envelope.__dict__: {getattr(envelope, \"__dict__\", None)}")\n        if hasattr(envelope, "payload"):\n            self.logger.info(f"DEBUG payload: {envelope.payload}")\n        if hasattr(envelope, "event_type"):\n            self.logger.info(f"DEBUG event_type: {envelope.event_type}")' "${ASR_MODULE}"

say "✓ 调试日志已添加"
say "重启ASR，再发送start命令，观察DEBUG日志"
