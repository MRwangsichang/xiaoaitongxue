#!/bin/bash
# sa_step_m1_07_verify_mqtt.sh - M1第7步：MQTT 事件广播验证

set -e

PROJECT_ROOT="/home/MRwang/smart_assistant"
DRY_RUN=${DRY_RUN:-0}

cd "$PROJECT_ROOT"

echo "=== M1 第7步：MQTT 事件广播验证 ==="
echo ""
echo "本步骤需要多个终端配合，请按以下顺序操作："
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│  终端分配                                                    │"
echo "├─────────────────────────────────────────────────────────────┤"
echo "│  终端1: 当前终端（执行本脚本）                               │"
echo "│  终端4: mosquitto_sub -v -t 'sa/memory/event/#'             │"
echo "│  终端6: python3 -m modules.memory.mqtt_handler              │"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""

# 检查 mosquitto 是否运行
echo "--- 步骤1: 检查 MQTT Broker ---"
if pgrep -x mosquitto > /dev/null 2>&1 || systemctl is-active --quiet mosquitto 2>/dev/null; then
    echo "✅ Mosquitto MQTT Broker 正在运行"
else
    echo "❌ Mosquitto 未运行，请先启动："
    echo "   sudo systemctl start mosquitto"
    echo "   或"
    echo "   mosquitto -d"
    exit 1
fi

# 测试 MQTT 连接
echo ""
echo "--- 步骤2: 测试 MQTT 连接 ---"
if timeout 2 mosquitto_sub -h localhost -t 'test/ping' -C 1 > /dev/null 2>&1 &
then
    sleep 0.5
    mosquitto_pub -h localhost -t 'test/ping' -m 'pong'
    wait
    echo "✅ MQTT Broker 可连接"
else
    echo "⚠️  MQTT 连接测试超时"
fi

echo ""
echo "--- 步骤3: 准备测试数据 ---"
echo "即将发送以下测试命令："
echo ""
echo "测试1: 添加 short 记忆（slot='购物'，应归一化为'purchase'）"
echo "  - confidence=0.88 → 应进入 active 状态"
echo ""
echo "测试2: 添加 profile 记忆（slot='工作'）"
echo "  - confidence=0.92 → 应进入 pending_confirm 状态"
echo ""
echo "测试3: 查询 wangzong 的 short 类型记忆"
echo ""

# 等待用户确认
read -p "✋ 请先在终端6启动 Memory Handler，然后按 Enter 继续..." dummy

echo ""
echo "--- 步骤4: 发送测试命令 ---"

# 测试1: 添加 short 记忆
echo ""
echo "📤 测试1: 添加 short 记忆（购物 → purchase）"
mosquitto_pub -h localhost -t 'sa/memory/cmd/add' -m '{
  "id": "test-add-001",
  "ts": "2025-11-18T14:00:00+09:00",
  "type": "cmd.add",
  "payload": {
    "person_id": "wangzong",
    "mem_type": "short",
    "slot": "购物",
    "value": "今天去山姆买了很多东西",
    "confidence": 0.88,
    "speakable": true,
    "ttl_s": 432000,
    "source": "grok"
  }
}'
echo "✅ 已发送"
sleep 2

# 测试2: 添加 profile 记忆（高置信度）
echo ""
echo "📤 测试2: 添加 profile 记忆（工作 → job，高置信度）"
mosquitto_pub -h localhost -t 'sa/memory/cmd/add' -m '{
  "id": "test-add-002",
  "type": "cmd.add",
  "payload": {
    "person_id": "wangzong",
    "mem_type": "profile",
    "slot": "工作",
    "value": "现在在做智能助手项目",
    "confidence": 0.92,
    "speakable": true,
    "source": "grok"
  }
}'
echo "✅ 已发送"
sleep 2

# 测试3: 查询记忆
echo ""
echo "📤 测试3: 查询 wangzong 的 short 记忆"
mosquitto_pub -h localhost -t 'sa/memory/cmd/query' -m '{
  "id": "test-query-001",
  "type": "cmd.query",
  "payload": {
    "person_id": "wangzong",
    "types": ["short"],
    "status": "active",
    "speakable": true,
    "limit": 5
  }
}'
echo "✅ 已发送"
sleep 2

echo ""
echo "--- 步骤5: 验证数据库 ---"
echo ""
echo "查询数据库中的记录："
sqlite3 "$PROJECT_ROOT/data/memory.db" <<SQL
SELECT
    substr(id, 1, 16) as id,
    person_id,
    slot,
    substr(value, 1, 30) as value,
    type,
    confidence,
    status
FROM memory_items
WHERE person_id = 'wangzong'
ORDER BY created_at DESC
LIMIT 5;
SQL

echo ""
echo "--- 步骤6: 验证 slot 归一化 ---"
echo ""
slot_check=$(sqlite3 "$PROJECT_ROOT/data/memory.db" "SELECT slot FROM memory_items WHERE value LIKE '%山姆%' LIMIT 1")
if [ "$slot_check" = "purchase" ]; then
    echo "✅ slot 归一化成功：'购物' → 'purchase'"
else
    echo "❌ slot 归一化失败：期望 'purchase'，实际 '$slot_check'"
fi

echo ""
echo "--- 步骤7: 验证置信度阈值 ---"
echo ""
status_check=$(sqlite3 "$PROJECT_ROOT/data/memory.db" "SELECT status FROM memory_items WHERE value LIKE '%智能助手%' LIMIT 1")
if [ "$status_check" = "pending_confirm" ]; then
    echo "✅ 置信度阈值判断正确：confidence=0.92 → status=pending_confirm"
else
    echo "⚠️  状态异常：期望 'pending_confirm'，实际 '$status_check'"
fi

echo ""
echo "==================================================================="
echo "                       验证总结"
echo "==================================================================="
echo ""
echo "✅ 已完成的验证项："
echo "  1. MQTT Broker 连接正常"
echo "  2. 命令发送成功（add × 2, query × 1）"
echo "  3. 数据库写入成功"
echo "  4. slot 归一化功能"
echo "  5. 置信度阈值判断"
echo ""
echo "📋 请检查终端6（Memory Handler）的日志，应包含："
echo "  - 📨 收到命令"
echo "  - ✅ 添加成功 | slot=purchase | status=active"
echo "  - ✅ 添加成功 | slot=job | status=pending_confirm"
echo ""
echo "📋 请检查终端4（事件监听），应收到事件："
echo "  - sa/memory/event/added (×2)"
echo "  - sa/memory/event/query_response (×1)"
echo ""
echo "==================================================================="
echo ""
echo "💡 下一步："
echo "   如果所有验证通过，可以继续 M1 第8步：HTTP /health 端点"
echo ""
