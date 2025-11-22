#!/bin/bash
# Step 10 阶段2: TTL过期功能测试
# 测试三级过期策略：active → archived → deleted → 物理删除

set -euo pipefail

PROJECT_ROOT="/home/MRwang/smart_assistant"
DB_FILE="$PROJECT_ROOT/data/memory.db"

cd "$PROJECT_ROOT"

echo "=== Step 10 阶段2: TTL过期功能测试 ==="
echo ""

# 前提检查
echo "[前提检查]"
if ! pgrep -f "mqtt_handler" > /dev/null; then
    echo "✗ Memory服务未运行"
    echo "请先启动: bash scripts/start_memory_handler.sh"
    exit 1
fi
echo "✓ Memory服务运行中"
echo ""

# 测试1: TTL到期自动归档（active → archived）
echo "=== 测试1: TTL到期自动归档 ==="
echo "[1.1] 添加短期记忆（TTL=10秒）"

# 监听事件
timeout 65 mosquitto_sub -h 127.0.0.1 -t "sa/memory/event/#" -v > /tmp/expiration_events.txt 2>&1 &
SUB_PID=$!
sleep 0.5

# 添加记忆（TTL=10秒）
mosquitto_pub -h 127.0.0.1 -t "sa/memory/cmd/add" -m '{
    "person_id": "wangzong",
    "slot": "mood",
    "value": "开心",
    "mem_type": "short",
    "source": "user",
    "confidence": 0.85,
    "ttl_s": 10
}'

sleep 2

# 获取Memory ID
MEMORY_ID=$(grep -o '"memory_id":"[^"]*"' /tmp/expiration_events.txt | head -1 | cut -d'"' -f4)
echo "Memory ID: $MEMORY_ID"

if [ -z "$MEMORY_ID" ]; then
    echo "✗ 未获取到Memory ID"
    kill $SUB_PID 2>/dev/null || true
    exit 1
fi

# 查看当前状态
echo ""
echo "[1.2] 查看当前状态"
sqlite3 "$DB_FILE" "SELECT id, status, expired_at FROM memory_items WHERE id = '$MEMORY_ID';"

echo ""
echo "[1.3] 等待TTL到期（10秒）+ 扫描触发..."
echo "  ⏳ 注意：定时扫描间隔为3600秒（1小时）"
echo "  ⏳ 为了测试，需要手动触发扫描或修改时间戳"
echo ""

# 提供两种测试方案
echo "【测试方案A: 修改时间戳模拟过期】"
echo "执行以下命令立即模拟过期："
echo ""
cat << 'EOFTEST'
# 将 expired_at 改为1小时前，模拟已过期
MEMORY_ID="<上面的Memory ID>"
sqlite3 data/memory.db "UPDATE memory_items SET expired_at = datetime('now', '-1 hour') WHERE id = '$MEMORY_ID';"

# 手动触发扫描（需要添加HTTP端点或MQTT命令）
# 或者重启服务触发立即扫描
EOFTEST

echo ""
echo "【测试方案B: 等待定时扫描】"
echo "  如需立即测试，建议使用方案A"
echo "  否则需要等待最多1小时直到下次扫描"
echo ""

# 停止事件监听
kill $SUB_PID 2>/dev/null || true

echo "=== 测试2: 手动模拟三级过期 ==="
echo ""

# 创建测试记忆并手动推进状态
echo "[2.1] 创建测试记忆"
TEST_ID="test_exp_$(date +%s)"

sqlite3 "$DB_FILE" << EOFSQL
INSERT INTO memory_items (
    id, person_id, slot, value, type, source, confidence,
    status, expired_at, created_at, updated_at
) VALUES (
    '$TEST_ID',
    'wangzong',
    'test_mood',
    '测试过期',
    'short',
    'user',
    0.85,
    'active',
    datetime('now', '-1 hour'),  -- 已过期
    datetime('now', '-2 hours'),
    datetime('now', '-2 hours')
);
EOFSQL

echo "✓ 测试记忆已创建: $TEST_ID"

echo ""
echo "[2.2] 模拟 archived → deleted 转换（30天后）"
sqlite3 "$DB_FILE" << EOFSQL
INSERT INTO memory_items (
    id, person_id, slot, value, type, source, confidence,
    status, created_at, updated_at
) VALUES (
    '${TEST_ID}_archived',
    'wangzong',
    'test_old',
    '旧记忆',
    'short',
    'user',
    0.85,
    'archived',
    datetime('now', '-35 days'),  -- 35天前
    datetime('now', '-35 days')
);
EOFSQL

echo "✓ 测试记忆已创建: ${TEST_ID}_archived"

echo ""
echo "[2.3] 模拟 deleted → 物理删除（7天后）"
sqlite3 "$DB_FILE" << EOFSQL
INSERT INTO memory_items (
    id, person_id, slot, value, type, source, confidence,
    status, created_at, updated_at
) VALUES (
    '${TEST_ID}_deleted',
    'wangzong',
    'test_very_old',
    '很旧记忆',
    'short',
    'user',
    0.85,
    'deleted',
    datetime('now', '-10 days'),  -- 10天前
    datetime('now', '-10 days')
);
EOFSQL

echo "✓ 测试记忆已创建: ${TEST_ID}_deleted"

echo ""
echo "[2.4] 查看测试数据"
sqlite3 "$DB_FILE" << EOFSQL
.mode column
.headers on
SELECT id, status,
       CASE
           WHEN expired_at IS NOT NULL THEN datetime(expired_at)
           ELSE 'NULL'
       END as expired_at,
       datetime(updated_at) as updated_at
FROM memory_items
WHERE id LIKE '${TEST_ID}%'
ORDER BY id;
EOFSQL

echo ""
echo "=== 触发扫描验证 ==="
echo ""
echo "【方法1: 重启服务】（推荐）"
echo "  终端6: Ctrl+C"
echo "  终端6: bash scripts/start_memory_handler.sh"
echo "  服务启动时会立即执行一次扫描"
echo ""
echo "【方法2: 等待定时扫描】"
echo "  等待最多1小时，观察终端6日志"
echo ""
echo "【方法3: 添加手动触发端点】（需要额外实现）"
echo "  mosquitto_pub -t sa/memory/cmd/trigger_scan -m '{}'"
echo ""

echo "=== 验证结果 ==="
echo "执行以下命令查看扫描后的状态变化："
echo ""
cat << 'EOFVERIFY'
# 查看所有测试记忆的最终状态
sqlite3 data/memory.db << EOFSQL
.mode column
.headers on
SELECT id, status, datetime(updated_at) as updated_at
FROM memory_items
WHERE id LIKE 'test_exp_%'
ORDER BY id;
EOFSQL

# 预期结果：
# - test_exp_<timestamp>: active → archived
# - test_exp_<timestamp>_archived: archived → deleted
# - test_exp_<timestamp>_deleted: 应该被物理删除（不存在）
EOFVERIFY

echo ""
echo "=== 阶段2 测试准备完成 ==="
echo ""
echo "【下一步】"
echo "  1. 重启Memory服务触发扫描"
echo "  2. 观察终端6的扫描日志"
echo "  3. 查看测试记忆状态变化"
echo "  4. 监听 sa/memory/event/expired 事件"
echo ""
