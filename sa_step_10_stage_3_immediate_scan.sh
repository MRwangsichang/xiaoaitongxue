#!/bin/bash
# Step 10 阶段3: 优化 - 服务启动时立即执行一次过期扫描
# 方便测试，避免等待1小时

set -euo pipefail

PROJECT_ROOT="/home/MRwang/smart_assistant"
HANDLER_FILE="$PROJECT_ROOT/modules/memory/mqtt_handler.py"
BACKUP_FILE="$HANDLER_FILE.bak_step10_stage3"

cd "$PROJECT_ROOT"

echo "=== Step 10 阶段3: 添加启动时立即扫描 ==="
echo ""

# 1. 备份
echo "[1/2] 备份mqtt_handler.py"
cp "$HANDLER_FILE" "$BACKUP_FILE"
echo "✓ 备份到: $BACKUP_FILE"
echo ""

# 2. 在扫描器启动后立即执行一次扫描
echo "[2/2] 添加启动时立即扫描"
python3 << 'EOFPY'
import sys

file_path = "/home/MRwang/smart_assistant/modules/memory/mqtt_handler.py"
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

modified = False
new_lines = []
for i, line in enumerate(lines):
    new_lines.append(line)

    # 在 self._start_expiration_scanner() 后添加立即扫描
    if 'self._start_expiration_scanner()' in line and not modified:
        indent = len(line) - len(line.lstrip())
        new_lines.append(' ' * indent + '# 启动时立即执行一次扫描\n')
        new_lines.append(' ' * indent + 'self._scan_and_expire()\n')
        modified = True
        print(f"✓ 在第{i+1}行后添加立即扫描")

if modified:
    with open(file_path, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    print("✓ 启动时立即扫描已添加")
else:
    print("⚠ 未找到插入位置")
    sys.exit(1)
EOFPY

echo ""

# 3. 语法检查
echo "=== 语法检查 ==="
python3 -m py_compile "$HANDLER_FILE" && echo "✓ 语法正确" || {
    echo "✗ 语法错误，回滚..."
    cp "$BACKUP_FILE" "$HANDLER_FILE"
    exit 1
}
echo ""

echo "=== 阶段3 完成 ==="
echo ""
echo "【优化效果】"
echo "  ✓ 服务启动时立即执行一次过期扫描"
echo "  ✓ 测试时无需等待1小时"
echo "  ✓ 之后仍按3600秒间隔定时扫描"
echo ""
echo "【测试流程】"
echo "  1. 执行阶段2脚本准备测试数据"
echo "  2. 重启Memory服务"
echo "  3. 服务启动时会立即扫描并处理过期记忆"
echo "  4. 观察终端6日志查看扫描结果"
echo ""
