#!/usr/bin/env bash
set -euo pipefail

say(){ printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ASR_FILE="/home/MRwang/smart_assistant/modules/asr/xunfei_asr.py"

say "修复WebSocket属性问题..."

# 备份
cp "$ASR_FILE" "$ASR_FILE.bak_ws_fix"

# 修复closed属性为state检查
sed -i 's/self.ws.closed/self.ws.state.value > 1/g' "$ASR_FILE"
sed -i 's/not self.ws.closed/self.ws.state.value <= 1/g' "$ASR_FILE"

# 添加websockets.State导入
sed -i '/import websockets/a from websockets.client import WebSocketClientProtocol' "$ASR_FILE"

say "修复完成"
say "重新测试ASR..."
