#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

START_SCRIPT="/home/MRwang/smart_assistant/scripts/start_asr.sh"

say "=== 修复 start_asr.sh，添加环境变量加载 ==="

# 备份
cp -p "${START_SCRIPT}" "${START_SCRIPT}.before_env_fix"

# 在 PYTHONPATH 设置之后添加 source .env.local
sed -i '/export PYTHONPATH=/a\
# Load environment variables\
if [ -f "${ROOT}/.env.local" ]; then\
    source "${ROOT}/.env.local"\
    say "Environment variables loaded from .env.local"\
fi' "${START_SCRIPT}"

say "✓ start_asr.sh 已修复"
say ""
say "现在启动ASR时会自动加载环境变量"
