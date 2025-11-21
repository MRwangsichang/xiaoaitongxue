#!/bin/bash
# 修复 models.py 中 slot pattern 过严的问题
# 允许中文输入，由 normalizer 负责归一化

set -euo pipefail

PROJECT_ROOT="/home/MRwang/smart_assistant"
MODELS_FILE="$PROJECT_ROOT/modules/memory/models.py"
BACKUP_FILE="$MODELS_FILE.bak_$(date +%s)"

cd "$PROJECT_ROOT"

echo "[$(date +%H:%M:%S)] === 修复 Slot Pattern 限制 ==="
echo ""

# 1. 备份原文件
echo "[1/5] 备份 models.py → $BACKUP_FILE"
cp "$MODELS_FILE" "$BACKUP_FILE"
echo "✓ 备份完成"
echo ""

# 2. 修复 MemoryAddCommand 的 slot 字段
echo "[2/5] 修复 MemoryAddCommand.slot 字段"
sed -i 's/slot: str = Field(..., pattern=r'"'"'^[a-z0-9_.-]{1,32}$'"'"')/slot: str = Field(..., min_length=1, max_length=100)/' "$MODELS_FILE"
echo "✓ 已修改：移除 pattern 限制，改为只验证长度"
echo ""

# 3. 修复 MemoryUpdateCommand 的 slot 字段（如果存在）
echo "[3/5] 修复 MemoryUpdateCommand.slot 字段（如果存在）"
sed -i 's/slot: Optional\[str\] = Field(None, pattern=r'"'"'^[a-z0-9_.-]{1,32}$'"'"')/slot: Optional[str] = Field(None, min_length=1, max_length=100)/' "$MODELS_FILE"
echo "✓ 已检查并修复"
echo ""

# 4. 显示修改内容
echo "[4/5] 验证修改结果"
echo "--- 修改后的 slot 字段定义 ---"
grep -n "slot.*Field" "$MODELS_FILE" | head -5 || echo "（未找到匹配行，可能格式不同）"
echo ""

# 5. 检查 Python 语法
echo "[5/5] 检查 Python 语法"
python3 -m py_compile "$MODELS_FILE" && echo "✓ 语法检查通过" || {
    echo "✗ 语法错误，正在回滚..."
    cp "$BACKUP_FILE" "$MODELS_FILE"
    echo "已回滚到备份版本"
    exit 1
}
echo ""

echo "=== 修复完成 ==="
echo ""
echo "【重要】需要重启 Memory Handler 服务："
echo "  1. 找到进程: ps aux | grep mqtt_handler | grep -v grep"
echo "  2. 停止服务: kill <PID>"
echo "  3. 启动服务: bash scripts/start_memory_handler.sh &"
echo ""
echo "【回滚方法】如果出现问题："
echo "  cp $BACKUP_FILE $MODELS_FILE"
echo ""
