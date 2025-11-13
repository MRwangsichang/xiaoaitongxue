#!/usr/bin/env bash
set -euo pipefail

# ============================================
# 功能：三参数VAD优化（能量+静音+端点）
# 执行终端：终端3
# 修改：energy_threshold 500→800
#       silence_frames 23→30 (2.4秒)
#       vad_eos 2000→3000ms
# ============================================

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
ASR_FILE="${ROOT}/modules/asr/asr_stream.py"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

say "=== 三参数VAD优化 ==="

# 1. 备份当前文件
if [ -f "${ASR_FILE}" ]; then
    cp -p "${ASR_FILE}" "${ASR_FILE}.bak_${TIMESTAMP}"
    say "备份完成: asr_stream.py.bak_${TIMESTAMP}"
else
    say "✗ 文件不存在: ${ASR_FILE}"
    exit 1
fi

# 2. 修改能量阈值（500→800）
say "修改 energy_threshold: 500→800"
sed -i 's/energy_threshold = 500/energy_threshold = 800/' "${ASR_FILE}"

# 3. 修改静音帧数（23→30）
say "修改 silence_frames: 23→30 (2.4秒)"
sed -i 's/silence_frames = 23/silence_frames = 30/' "${ASR_FILE}"

# 4. 修改讯飞端点（2000→3000）
say "修改 vad_eos: 2000→3000ms"
sed -i 's/"vad_eos": 2000/"vad_eos": 3000/' "${ASR_FILE}"

# 5. 验证修改
FAIL=0

if ! grep -q "energy_threshold = 800" "${ASR_FILE}"; then
    say "✗ energy_threshold修改失败"
    FAIL=1
fi

if ! grep -q "silence_frames = 30" "${ASR_FILE}"; then
    say "✗ silence_frames修改失败"
    FAIL=1
fi

if ! grep -q '"vad_eos": 3000' "${ASR_FILE}"; then
    say "✗ vad_eos修改失败"
    FAIL=1
fi

if [ $FAIL -eq 1 ]; then
    say "✗ 修改失败，正在回滚..."
    cp -p "${ASR_FILE}.bak_${TIMESTAMP}" "${ASR_FILE}"
    exit 1
fi

say "✓ 三参数已优化"
echo ""
say "测试建议:"
echo "  说完整长句: \"现在的语音识别能识别几秒的一次性，效果还是不错但是还是有需要改进的地方\""
echo "  期望: 终端1只出现1条完整消息"
echo "  延迟: 说完后约2-3秒出结果"
echo ""
say "回滚命令:"
echo "  cp ${ASR_FILE}.bak_${TIMESTAMP} ${ASR_FILE}"
