#!/bin/bash
# Step 9 阶段4: Confirm命令集成测试
# 端到端测试 pending_confirm → active/deleted 流程

set -euo pipefail

PROJECT_ROOT="/home/MRwang/smart_assistant"
cd "$PROJECT_ROOT"

echo "=== Step 9 阶段4: Confirm命令集成测试 ==="
echo ""

# 测试前提检查
echo "[前提检查]"
if ! pgrep -f "mqtt_handler" > /dev/null; then
    echo "✗ Memory服务未运行"
    echo "请先启动: bash scripts/start_memory_handler.sh"
    exit 1
fi
echo "✓ Memory服务运行中"

if ! curl -s http://localhost:8081/health > /dev/null; then
    echo "✗ 健康检查端点无响应"
    exit 1
fi
echo "✓ 健康检查端点正常"
echo ""

# 测试用例1: 正常confirm流程
echo "=== 测试1: 正常confirm流程 ==="
echo "[1.1] 添加profile记忆（置信度0.91 → pending_confirm）"
REQ_ID_1="test_confirm_$(date +%s)"

mosquitto_pub -h 127.0.0.1 -t "sa/memory/cmd/add" -m "{
    \"person_id\": \"wangzong\",
    \"slot\": \"家庭住址\",
    \"value\": \"东京都涩谷区\",
    \"mem_type\": \"profile\",
    \"source\": \"test_step9\",
    \"confidence\": 0.91,
    \"req_id\": \"$REQ_ID_1\"
}"

sleep 0.5

echo "[1.2] 检查响应（应为pending_confirm）"
RESP_1=$(mosquitto_sub -h 127.0.0.1 -t "sa/memory/resp/add" -W 2 -C 1 2>/dev/null || echo "{}")
echo "响应: $RESP_1"

if echo "$RESP_1" | grep -q "pending_confirm"; then
    echo "✓ 状态正确: pending_confirm"
    MEMORY_ID=$(echo "$RESP_1" | grep -o '"memory_id":"[^"]*"' | cut -d'"' -f4)
    echo "  Memory ID: $MEMORY_ID"
else
    echo "✗ 状态错误，期望pending_confirm"
    exit 1
fi
echo ""

echo "[1.3] 发送confirm命令"
REQ_ID_2="test_confirm_exec_$(date +%s)"
mosquitto_pub -h 127.0.0.1 -t "sa/memory/cmd/confirm" -m "{
    \"memory_id\": \"$MEMORY_ID\",
    \"decision\": \"confirm\",
    \"req_id\": \"$REQ_ID_2\"
}"

sleep 0.5

echo "[1.4] 检查confirm响应（应为active）"
RESP_2=$(mosquitto_sub -h 127.0.0.1 -t "sa/memory/resp/confirm" -W 2 -C 1 2>/dev/null || echo "{}")
echo "响应: $RESP_2"

if echo "$RESP_2" | grep -q '"success":true'; then
    echo "✓ Confirm成功"
    if echo "$RESP_2" | grep -q '"new_status":"active"'; then
        echo "✓ 状态已转换为active"
    else
        echo "✗ 状态未转换"
        exit 1
    fi
else
    echo "✗ Confirm失败"
    exit 1
fi
echo ""

# 测试用例2: Reject流程
echo "=== 测试2: Reject流程 ==="
echo "[2.1] 添加另一个profile记忆"
REQ_ID_3="test_reject_$(date +%s)"

mosquitto_pub -h 127.0.0.1 -t "sa/memory/cmd/add" -m "{
    \"person_id\": \"wangzong\",
    \"slot\": \"生日\",
    \"value\": \"1990-05-15\",
    \"mem_type\": \"profile\",
    \"source\": \"test_step9\",
    \"confidence\": 0.92,
    \"req_id\": \"$REQ_ID_3\"
}"

sleep 0.5

RESP_3=$(mosquitto_sub -h 127.0.0.1 -t "sa/memory/resp/add" -W 2 -C 1 2>/dev/null || echo "{}")
MEMORY_ID_2=$(echo "$RESP_3" | grep -o '"memory_id":"[^"]*"' | cut -d'"' -f4)
echo "Memory ID: $MEMORY_ID_2"

echo "[2.2] 发送reject命令"
REQ_ID_4="test_reject_exec_$(date +%s)"
mosquitto_pub -h 127.0.0.1 -t "sa/memory/cmd/confirm" -m "{
    \"memory_id\": \"$MEMORY_ID_2\",
    \"decision\": \"reject\",
    \"req_id\": \"$REQ_ID_4\"
}"

sleep 0.5

echo "[2.3] 检查reject响应（应为deleted）"
RESP_4=$(mosquitto_sub -h 127.0.0.1 -t "sa/memory/resp/confirm" -W 2 -C 1 2>/dev/null || echo "{}")
echo "响应: $RESP_4"

if echo "$RESP_4" | grep -q '"new_status":"deleted"'; then
    echo "✓ Reject成功，状态已转换为deleted"
else
    echo "✗ Reject失败"
    exit 1
fi
echo ""

# 测试用例3: 边界情况 - 重复confirm（幂等性）
echo "=== 测试3: 幂等性验证 ==="
echo "[3.1] 重复发送相同confirm命令"
mosquitto_pub -h 127.0.0.1 -t "sa/memory/cmd/confirm" -m "{
    \"memory_id\": \"$MEMORY_ID\",
    \"decision\": \"confirm\",
    \"req_id\": \"$REQ_ID_2\"
}"

sleep 0.5

RESP_5=$(mosquitto_sub -h 127.0.0.1 -t "sa/memory/resp/confirm" -W 2 -C 1 2>/dev/null || echo "{}")
echo "响应: $RESP_5"

if echo "$RESP_5" | grep -q '"success":true'; then
    echo "✓ 幂等性正常（返回缓存结果）"
else
    echo "✗ 幂等性异常"
    exit 1
fi
echo ""

# 测试用例4: 错误情况 - 无效decision
echo "=== 测试4: 参数校验 ==="
echo "[4.1] 发送无效decision"
REQ_ID_5="test_invalid_$(date +%s)"
mosquitto_pub -h 127.0.0.1 -t "sa/memory/cmd/confirm" -m "{
    \"memory_id\": \"$MEMORY_ID\",
    \"decision\": \"invalid\",
    \"req_id\": \"$REQ_ID_5\"
}"

sleep 0.5

RESP_6=$(mosquitto_sub -h 127.0.0.1 -t "sa/memory/resp/confirm" -W 2 -C 1 2>/dev/null || echo "{}")
echo "响应: $RESP_6"

if echo "$RESP_6" | grep -q '"success":false'; then
    echo "✓ 参数校验正常（拒绝无效decision）"
else
    echo "✗ 参数校验失败"
    exit 1
fi
echo ""

# 汇总结果
echo "=== ✓ 阶段4集成测试通过 (4/4) ==="
echo ""
echo "【测试覆盖】"
echo "  ✓ 正常confirm流程 (pending_confirm → active)"
echo "  ✓ Reject流程 (pending_confirm → deleted)"
echo "  ✓ 幂等性验证（重复请求）"
echo "  ✓ 参数校验（无效decision）"
echo ""
echo "【下一步】阶段5: 实现state_changed事件广播"
echo "  编辑 mqtt_handler.py 添加事件发布逻辑"
echo ""
