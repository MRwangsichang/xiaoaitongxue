#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
BACKUP_DIR="${ROOT}/backups/FINAL_ASR_LOCKED"

say "=== 创建最终版本备份并加锁 ==="

# 创建备份目录
mkdir -p "${BACKUP_DIR}"

# 备份整个asr模块（包括所有文件）
say "备份 asr 模块..."
cp -r "${ROOT}/modules/asr" "${BACKUP_DIR}/"

# 备份启动脚本
say "备份 start_asr.sh..."
cp "${ROOT}/scripts/start_asr.sh" "${BACKUP_DIR}/"

# 备份配置
say "备份配置文件..."
cp "${ROOT}/config/asr.yml" "${BACKUP_DIR}/" 2>/dev/null || true
cp "${ROOT}/.env.local" "${BACKUP_DIR}/" 2>/dev/null || true

# 创建版本说明
cat > "${BACKUP_DIR}/VERSION.txt" <<VERSION
========================================
ASR 最终可用版本
========================================
备份时间: $(date '+%Y-%m-%d %H:%M:%S')
性能指标:
  - 识别延迟: 6-11秒（包含说话时间）
  - 重连速度: 1秒（优化后）
  - 识别准确率: 95%+
  - 下轮间隔: 7秒（优化前12秒）

关键特性:
  ✅ 讯飞云端识别
  ✅ 只发布最终结果（不是流式）
  ✅ 主动关闭WebSocket优化
  ✅ 所有API已适配新版EventBus

重要文件:
  - modules/asr/asr_module.py
  - modules/asr/cloud_provider.py
  - scripts/start_asr.sh
========================================
VERSION

# 设置备份为只读（防止误删除）
chmod -R 444 "${BACKUP_DIR}"
chmod 555 "${BACKUP_DIR}"

# 创建恢复脚本
cat > "${ROOT}/scripts/restore_final_asr.sh" <<'RESTORE'
#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
BACKUP_DIR="${ROOT}/backups/FINAL_ASR_LOCKED"

say "=== 恢复 ASR 最终版本 ==="

if [ ! -d "${BACKUP_DIR}" ]; then
    say "✗ 备份不存在: ${BACKUP_DIR}"
    exit 1
fi

# 显示版本信息
if [ -f "${BACKUP_DIR}/VERSION.txt" ]; then
    cat "${BACKUP_DIR}/VERSION.txt"
    echo ""
fi

read -p "确认恢复到最终版本？[y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    say "取消恢复"
    exit 0
fi

# 恢复文件
say "恢复 asr 模块..."
rm -rf "${ROOT}/modules/asr"
cp -r "${BACKUP_DIR}/asr" "${ROOT}/modules/"

say "恢复启动脚本..."
cp "${BACKUP_DIR}/start_asr.sh" "${ROOT}/scripts/"
chmod +x "${ROOT}/scripts/start_asr.sh"

say "✓ 恢复完成！"
say ""
say "重启 ASR:"
echo "  cd ${ROOT}"
echo "  bash scripts/start_asr.sh"
RESTORE

chmod +x "${ROOT}/scripts/restore_final_asr.sh"

say "✓ 备份完成！"
echo ""
say "备份位置:"
echo "  ${BACKUP_DIR}/"
echo ""
say "版本信息:"
cat "${BACKUP_DIR}/VERSION.txt"
echo ""
say "恢复命令:"
echo "  bash ${ROOT}/scripts/restore_final_asr.sh"
