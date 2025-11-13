#!/usr/bin/env bash
set -euo pipefail

# ============================================
# 功能：优化ASR的VAD参数（防止过早断句）
# 执行终端：终端3
# 参数：silence_frames 15→23 (1.8秒)
# ============================================

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
ASR_FILE="${ROOT}/modules/asr/asr_stream.py"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

say "=== 备份asr_stream.py ==="

# 1. 备份当前文件
if [ -f "${ASR_FILE}" ]; then
    cp -p "${ASR_FILE}" "${ASR_FILE}.bak_${TIMESTAMP}"
    say "备份完成: asr_stream.py.bak_${TIMESTAMP}"
else
    say "✗ 文件不存在: ${ASR_FILE}"
    exit 1
fi

# 2. 修改本地VAD参数（silence_frames: 15→23）
say "修改参数: silence_frames 15→23 (1.2秒→1.8秒)"
sed -i 's/silence_frames = 15/silence_frames = 23/' "${ASR_FILE}"

# 3. 验证修改（讯飞vad_eos保持2000，不需要改）
if grep -q "silence_frames = 23" "${ASR_FILE}"; then
    say "✓ 本地VAD已更新为1.8秒"
else
    say "✗ 修改失败，正在回滚..."
    cp -p "${ASR_FILE}.bak_${TIMESTAMP}" "${ASR_FILE}"
    exit 1
fi

if grep -q '"vad_eos": 2000' "${ASR_FILE}"; then
    say "✓ 讯飞VAD保持2秒（无需修改）"
fi

say "✓ 参数已优化"
echo ""
say "测试建议:"
echo "  终端1: mosquitto_sub -t 'sa/asr/text' -v"
echo "  终端3: python3 ${ASR_FILE}"
echo "  说测试句: \"现在的语音识别（停1.5秒）能识别几秒的一次性？\""
echo ""
say "回滚命令:"
echo "  cp ${ASR_FILE}.bak_${TIMESTAMP} ${ASR_FILE}"
