#!/bin/bash
# Step 9 阶段2.4: 将confirm命令接入MQTT路由
# 修改 mqtt_handler.py 添加confirm路由和订阅

set -euo pipefail

PROJECT_ROOT="/home/MRwang/smart_assistant"
HANDLER_FILE="$PROJECT_ROOT/modules/memory/mqtt_handler.py"
BACKUP_FILE="$HANDLER_FILE.bak_step9_stage24"

cd "$PROJECT_ROOT"

echo "=== Step 9 阶段2.4: 接入confirm命令路由 ==="
echo ""

# 1. 备份
echo "[1/4] 备份mqtt_handler.py"
cp "$HANDLER_FILE" "$BACKUP_FILE"
echo "✓ 备份到: $BACKUP_FILE"
echo ""

# 2. 查找命令路由位置
echo "[2/4] 定位命令路由代码"
grep -n "def _on_message" "$HANDLER_FILE" | head -3
echo ""

# 3. 添加confirm路由（在_on_message方法中）
echo "[3/4] 添加confirm命令路由"
cat > /tmp/add_confirm_routing.py << 'EOFPY'
import sys

file_path = sys.argv[1]
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

modified = False
new_lines = []
for i, line in enumerate(lines):
    new_lines.append(line)

    # 在 'update': self._handle_update 后添加 confirm
    if "'update': self._handle_update" in line and not modified:
        indent = len(line) - len(line.lstrip())
        new_lines.append(' ' * indent + "'confirm': self._handle_confirm,\n")
        modified = True
        print(f"✓ 在第{i+1}行后添加confirm路由")

if modified:
    with open(file_path, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    print("✓ confirm路由添加成功")
else:
    print("✗ 未找到路由映射位置，请手动检查")
    sys.exit(1)
EOFPY

python3 /tmp/add_confirm_routing.py "$HANDLER_FILE"
echo ""

# 4. 添加confirm主题订阅
echo "[4/4] 添加confirm主题订阅"
cat > /tmp/add_confirm_subscription.py << 'EOFPY'
import sys

file_path = sys.argv[1]
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 查找订阅部分并添加confirm主题
if 'cmd_topics = [' in content:
    # 在cmd_topics列表中添加confirm
    old_pattern = '''cmd_topics = [
            f"{cmd_prefix}/add",
            f"{cmd_prefix}/query",
            f"{cmd_prefix}/update",
            f"{cmd_prefix}/delete"
        ]'''

    new_pattern = '''cmd_topics = [
            f"{cmd_prefix}/add",
            f"{cmd_prefix}/query",
            f"{cmd_prefix}/update",
            f"{cmd_prefix}/delete",
            f"{cmd_prefix}/confirm"
        ]'''

    if old_pattern in content:
        content = content.replace(old_pattern, new_pattern)
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print("✓ confirm主题已添加到订阅列表")
    else:
        print("⚠ 未找到标准cmd_topics列表，尝试直接插入...")
        # 备选方案：在delete订阅后添加
        if 'f"{cmd_prefix}/delete"' in content:
            content = content.replace(
                'f"{cmd_prefix}/delete"',
                'f"{cmd_prefix}/delete",\n            f"{cmd_prefix}/confirm"'
            )
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print("✓ confirm主题已添加")
        else:
            print("✗ 未找到订阅列表，请手动添加")
            sys.exit(1)
else:
    print("✗ 未找到cmd_topics定义")
    sys.exit(1)
EOFPY

python3 /tmp/add_confirm_subscription.py "$HANDLER_FILE"
echo ""

# 5. 语法检查
echo "[5/5] 语法检查"
python3 -m py_compile "$HANDLER_FILE" && echo "✓ 语法正确" || {
    echo "✗ 语法错误，回滚..."
    cp "$BACKUP_FILE" "$HANDLER_FILE"
    exit 1
}
echo ""

# 6. 验证修改
echo "=== 验证结果 ==="
echo "--- confirm路由 ---"
grep -A 1 "'update': self._handle_update" "$HANDLER_FILE" | grep -E "(update|confirm)" || echo "（未找到）"
echo ""
echo "--- confirm订阅 ---"
grep -A 5 "cmd_topics = \[" "$HANDLER_FILE" | grep "confirm" || echo "（未找到）"
echo ""

echo "=== 阶段2.4 完成 ==="
echo ""
echo "【下一步】阶段3: 单元测试"
echo "  python3 -m pytest tests/test_memory/test_state_machine.py -v"
echo ""
echo "【如需回滚】"
echo "  cp $BACKUP_FILE $HANDLER_FILE"
echo ""
