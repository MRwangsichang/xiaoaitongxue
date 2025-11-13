#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
ENV_FILE="${ROOT}/.env.local"

say "=== 更新Grok配置 ==="

# 备份
cp "${ENV_FILE}" "${ENV_FILE}.before_update_grok"

# 更新API Key
sed -i 's/export GROK_API_KEY=.*/export GROK_API_KEY="xai-YOUR_API_KEY_HERE"/' "${ENV_FILE}"

# 更新模型名称
sed -i 's/export GROK_MODEL=.*/export GROK_MODEL="grok-4-fast-non-reasoning"/' "${ENV_FILE}"

say "✓ 配置已更新"
say ""
say "验证配置："
source "${ENV_FILE}"
echo "  GROK_API_KEY: ${GROK_API_KEY:0:20}..."
echo "  GROK_API_BASE: ${GROK_API_BASE}"
echo "  GROK_MODEL: ${GROK_MODEL}"
