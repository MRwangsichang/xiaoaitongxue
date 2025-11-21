#!/bin/bash
# Step 9 阶段3: 状态机单元测试
# 测试所有状态转换逻辑和边界条件

set -euo pipefail

PROJECT_ROOT="/home/MRwang/smart_assistant"
cd "$PROJECT_ROOT"

echo "=== Step 9 阶段3: 状态机单元测试 ==="
echo ""

# 1. 检查测试文件
echo "[1/3] 检查测试文件"
if [ -f "tests/test_memory/test_state_machine.py" ]; then
    echo "✓ 测试文件存在"
else
    echo "✗ 测试文件不存在: tests/test_memory/test_state_machine.py"
    echo "请先从GitHub仓库复制测试文件到此路径"
    exit 1
fi
echo ""

# 2. 运行单元测试
echo "[2/3] 运行单元测试（22项测试）"
echo ""
python3 -m pytest tests/test_memory/test_state_machine.py -v --tb=short
TEST_RESULT=$?
echo ""

# 3. 显示测试摘要
if [ $TEST_RESULT -eq 0 ]; then
    echo "=== ✓ 阶段3测试通过 ==="
    echo ""
    echo "【测试覆盖】"
    echo "  ✓ 初始状态判断 (7项)"
    echo "    - 置信度边界 (0.49/0.50/0.79/0.80/0.89/0.90)"
    echo "    - profile高置信度确认逻辑"
    echo "    - 不同类型记忆处理"
    echo "  ✓ 确认转换 (4项)"
    echo "    - pending_confirm → active"
    echo "    - 权限检查 (can_confirm)"
    echo "  ✓ 软删除 (3项)"
    echo "    - 多状态 → deleted"
    echo "  ✓ 归档转换 (2项)"
    echo "    - active → archived"
    echo "  ✓ 阈值常量 (2项)"
    echo ""
    echo "【下一步】阶段4: 集成测试confirm命令"
    echo "  bash scripts/sa_step_09_stage_4_integration_test.sh"
    echo ""
else
    echo "=== ✗ 测试失败 ==="
    echo ""
    echo "【排查建议】"
    echo "  1. 检查state_machine.py是否正确实现"
    echo "  2. 查看上方错误详情"
    echo "  3. 运行单个测试: pytest tests/test_memory/test_state_machine.py::TestDetermineInitialStatus::test_low_confidence_rejected -v"
    echo ""
    exit 1
fi
