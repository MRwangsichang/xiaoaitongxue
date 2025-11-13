#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
BACKUP_DIR="${ROOT}/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

say "=== 备份当前可工作的ASR模块 ==="

# 创建备份目录
mkdir -p "${BACKUP_DIR}/asr_working_${TIMESTAMP}"

# 备份整个asr模块
cp -r "${ROOT}/modules/asr" "${BACKUP_DIR}/asr_working_${TIMESTAMP}/"

# 备份启动脚本
cp "${ROOT}/scripts/start_asr.sh" "${BACKUP_DIR}/asr_working_${TIMESTAMP}/"

# 备份配置
cp "${ROOT}/config/asr.yml" "${BACKUP_DIR}/asr_working_${TIMESTAMP}/" 2>/dev/null || true

say "✓ 备份完成："
say "  ${BACKUP_DIR}/asr_working_${TIMESTAMP}/"
echo ""
say "如需恢复，执行："
echo "  cp -r ${BACKUP_DIR}/asr_working_${TIMESTAMP}/asr/* ${ROOT}/modules/asr/"
echo "  cp ${BACKUP_DIR}/asr_working_${TIMESTAMP}/start_asr.sh ${ROOT}/scripts/"
