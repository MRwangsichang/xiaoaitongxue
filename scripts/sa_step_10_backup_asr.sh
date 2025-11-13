#!/usr/bin/env bash
set -euo pipefail

# ============================================
# 功能：备份ASR模块（代码+配置）
# 执行终端：终端2 或任意空闲终端
# 依赖：tar, date
# ============================================

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${ROOT}/backup_asr_${TIMESTAMP}"
TARBALL="${ROOT}/backup_asr_${TIMESTAMP}.tar.gz"

say "=== 备份ASR模块 ==="

# 1. 创建备份目录
say "创建备份目录: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}/modules/asr"
mkdir -p "${BACKUP_DIR}/config"

# 2. 复制ASR代码文件
say "复制文件: modules/asr/*.py → backup"
cp -p "${ROOT}/modules/asr"/*.py "${BACKUP_DIR}/modules/asr/" 2>/dev/null || {
    say "警告: 部分.py文件复制失败，继续..."
}

# 3. 复制配置文件
if [ -f "${ROOT}/config/asr.yml" ]; then
    say "复制配置: config/asr.yml → backup"
    cp -p "${ROOT}/config/asr.yml" "${BACKUP_DIR}/config/"
fi

if [ -f "${ROOT}/config/xunfei_asr.json" ]; then
    say "复制配置: config/xunfei_asr.json → backup"
    cp -p "${ROOT}/config/xunfei_asr.json" "${BACKUP_DIR}/config/"
fi

# 4. 打包压缩
say "打包压缩: $(basename ${TARBALL})"
cd "${ROOT}"
tar -czf "${TARBALL}" "$(basename ${BACKUP_DIR})" 2>/dev/null

# 5. 清理临时目录
rm -rf "${BACKUP_DIR}"

# 6. 验证打包
if [ -f "${TARBALL}" ]; then
    SIZE=$(du -h "${TARBALL}" | cut -f1)
    say "✓ 备份完成: ${TARBALL} (${SIZE})"
    echo ""
    say "回滚命令:"
    echo "  tar -xzf ${TARBALL} -C ${ROOT} --strip-components=1"
    echo ""
else
    say "✗ 打包失败"
    exit 1
fi
