#!/bin/bash
# Step 10 阶段1: TTL过期处理 - 定时任务实现
# 在 mqtt_handler.py 中添加过期扫描逻辑

set -euo pipefail

PROJECT_ROOT="/home/MRwang/smart_assistant"
HANDLER_FILE="$PROJECT_ROOT/modules/memory/mqtt_handler.py"
BACKUP_FILE="$HANDLER_FILE.bak_step10_stage1"

cd "$PROJECT_ROOT"

echo "=== Step 10 阶段1: 添加TTL过期处理 ==="
echo ""

# 1. 备份
echo "[1/5] 备份mqtt_handler.py"
cp "$HANDLER_FILE" "$BACKUP_FILE"
echo "✓ 备份到: $BACKUP_FILE"
echo ""

# 2. 添加导入语句（在文件顶部添加threading相关）
echo "[2/5] 检查导入语句"
if grep -q "from threading import Thread" "$HANDLER_FILE"; then
    echo "✓ threading 导入已存在"
else
    echo "⚠ 需要手动检查导入"
fi
echo ""

# 3. 添加过期扫描方法
echo "[3/5] 添加过期扫描方法"
cat > /tmp/add_expiration_methods.py << 'EOFPY'
import sys

file_path = sys.argv[1]
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 在 _handle_confirm 方法后添加过期扫描方法
expiration_methods = '''
    # ===================== TTL 过期处理（Step 10）=====================

    def _start_expiration_scanner(self):
        """启动过期扫描定时任务"""
        def scanner_loop():
            while not self._stop_scanner.is_set():
                try:
                    self._scan_and_expire()
                except Exception as e:
                    logger.error(f"过期扫描异常: {e}")
                # 每小时扫描一次
                self._stop_scanner.wait(3600)

        self._stop_scanner = threading.Event()
        self._scanner_thread = threading.Thread(
            target=scanner_loop,
            name='ExpirationScanner',
            daemon=True
        )
        self._scanner_thread.start()
        logger.info("过期扫描线程已启动（间隔: 3600s）")

    def _stop_expiration_scanner(self):
        """停止过期扫描任务"""
        if hasattr(self, '_stop_scanner'):
            self._stop_scanner.set()
            if hasattr(self, '_scanner_thread'):
                self._scanner_thread.join(timeout=2)
            logger.info("过期扫描线程已停止")

    def _scan_and_expire(self):
        """扫描并处理过期记忆"""
        start_time = time.time()
        expired_count = 0
        archived_count = 0
        deleted_count = 0

        try:
            db = self._get_db()
            now = datetime.now(timezone.utc)

            # 1. 处理 active → archived（TTL到期）
            cursor = db.conn.execute("""
                SELECT id, person_id, type, expired_at
                FROM memory_items
                WHERE status = 'active'
                  AND expired_at IS NOT NULL
                  AND expired_at < ?
            """, (now.isoformat(),))

            active_expired = cursor.fetchall()
            for row in active_expired:
                try:
                    new_status, reason = state_machine.archive('active', 'TTL到期')

                    # 更新数据库（带并发保护）
                    result = db.conn.execute("""
                        UPDATE memory_items
                        SET status = ?, updated_at = ?
                        WHERE id = ? AND status = 'active'
                    """, (new_status, now.isoformat(), row[0]))

                    if result.rowcount > 0:
                        db.conn.commit()
                        expired_count += 1

                        # 发送expired事件
                        start_mono = time.monotonic()
                        self._send_event('expired', row[0], row[1], None, start_mono,
                                       old_status='active', new_status=new_status, reason=reason)

                        logger.info(f"✓ TTL过期归档: {row[0]} (active → archived)")
                except Exception as e:
                    logger.error(f"归档失败 {row[0]}: {e}")

            # 2. 处理 archived → deleted（30天后）
            archived_threshold = now - timedelta(days=30)
            cursor = db.conn.execute("""
                SELECT id, person_id
                FROM memory_items
                WHERE status = 'archived'
                  AND updated_at < ?
            """, (archived_threshold.isoformat(),))

            archived_old = cursor.fetchall()
            for row in archived_old:
                try:
                    new_status, reason = state_machine.soft_delete('archived', '归档30天后软删除')

                    result = db.conn.execute("""
                        UPDATE memory_items
                        SET status = ?, updated_at = ?
                        WHERE id = ? AND status = 'archived'
                    """, (new_status, now.isoformat(), row[0]))

                    if result.rowcount > 0:
                        db.conn.commit()
                        archived_count += 1
                        logger.info(f"✓ 归档转删除: {row[0]} (archived → deleted)")
                except Exception as e:
                    logger.error(f"软删除失败 {row[0]}: {e}")

            # 3. 处理 deleted → 物理删除（7天后）
            deleted_threshold = now - timedelta(days=7)
            cursor = db.conn.execute("""
                SELECT id
                FROM memory_items
                WHERE status = 'deleted'
                  AND updated_at < ?
            """, (deleted_threshold.isoformat(),))

            deleted_old = cursor.fetchall()
            for row in deleted_old:
                try:
                    db.conn.execute("DELETE FROM memory_items WHERE id = ? AND status = 'deleted'", (row[0],))
                    db.conn.commit()
                    deleted_count += 1
                    logger.info(f"✓ 物理删除: {row[0]}")
                except Exception as e:
                    logger.error(f"物理删除失败 {row[0]}: {e}")

            elapsed = time.time() - start_time
            logger.info(
                f"过期扫描完成: TTL归档={expired_count}, "
                f"软删除={archived_count}, 物理删除={deleted_count}, "
                f"耗时={elapsed:.2f}s"
            )

        except Exception as e:
            logger.error(f"过期扫描失败: {e}")

'''

# 查找插入位置（在 _send_error_response 方法之前）
if '# ===================== TTL 过期处理（Step 10）' in content:
    print("⚠ 过期处理方法已存在，跳过添加")
    sys.exit(0)

# 在 _send_error_response 前插入
marker = '    def _send_error_response'
if marker in content:
    content = content.replace(marker, expiration_methods + '\n' + marker)
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("✓ 过期扫描方法已添加")
else:
    print("✗ 未找到插入位置")
    sys.exit(1)
EOFPY

python3 /tmp/add_expiration_methods.py "$HANDLER_FILE"
echo ""

# 4. 在 __init__ 中添加导入
echo "[4/5] 添加必要导入"
python3 << 'EOFPY'
file_path = "/home/MRwang/smart_assistant/modules/memory/mqtt_handler.py"
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 添加 threading 导入
if 'import threading' not in content:
    # 在 import time 后添加
    content = content.replace('import time', 'import time\nimport threading')
    print("✓ 添加 threading 导入")

# 添加 timedelta 到 datetime 导入
if 'from datetime import datetime, timezone' in content:
    content = content.replace(
        'from datetime import datetime, timezone',
        'from datetime import datetime, timezone, timedelta'
    )
    print("✓ 添加 timedelta 导入")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
EOFPY
echo ""

# 5. 在 run() 方法中启动扫描器
echo "[5/5] 在 run() 方法中启动扫描器"
python3 << 'EOFPY'
import sys

file_path = "/home/MRwang/smart_assistant/modules/memory/mqtt_handler.py"
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

modified = False
new_lines = []
for i, line in enumerate(lines):
    new_lines.append(line)

    # 在 "启动MQTT客户端" 注释后添加扫描器启动
    if '# 启动MQTT客户端' in line and not modified:
        # 向前查找，在健康检查后添加
        for j in range(len(new_lines)-1, max(0, len(new_lines)-20), -1):
            if 'self.health_server.update_status' in new_lines[j]:
                # 在这个块之后添加
                indent = '        '
                insert_pos = j + 1
                # 找到下一个空行
                while insert_pos < len(new_lines) and new_lines[insert_pos].strip():
                    insert_pos += 1

                new_lines.insert(insert_pos, '\n')
                new_lines.insert(insert_pos + 1, indent + '# 启动过期扫描线程\n')
                new_lines.insert(insert_pos + 2, indent + 'self._start_expiration_scanner()\n')
                modified = True
                print(f"✓ 在第{insert_pos}行后添加扫描器启动")
                break
        break

if modified:
    with open(file_path, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    print("✓ 扫描器启动代码已添加")
else:
    print("⚠ 未找到插入位置，需要手动添加")
EOFPY
echo ""

# 6. 语法检查
echo "=== 语法检查 ==="
python3 -m py_compile "$HANDLER_FILE" && echo "✓ 语法正确" || {
    echo "✗ 语法错误，回滚..."
    cp "$BACKUP_FILE" "$HANDLER_FILE"
    exit 1
}
echo ""

echo "=== 阶段1 完成 ==="
echo ""
echo "【已添加功能】"
echo "  ✓ 过期扫描定时任务（每小时）"
echo "  ✓ active → archived (TTL到期)"
echo "  ✓ archived → deleted (30天)"
echo "  ✓ deleted → 物理删除 (7天)"
echo "  ✓ expired 事件发送"
echo ""
echo "【下一步】重启服务并测试"
echo "  终端6: Ctrl+C 后 bash scripts/start_memory_handler.sh"
echo "  终端1: 执行阶段2测试脚本"
echo ""
echo "【如需回滚】"
echo "  cp $BACKUP_FILE $HANDLER_FILE"
echo ""
