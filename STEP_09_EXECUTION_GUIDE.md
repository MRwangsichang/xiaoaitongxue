# Step 9 阶段2.4-4 执行指南

**更新时间**: 2025-11-21
**当前阶段**: 阶段2.4（将confirm命令接入MQTT路由）

---

## 📋 执行清单

### 准备工作

1. **SSH登录树莓派**
   ```bash
   ssh MRwang@192.168.0.155
   ```

2. **进入项目目录**
   ```bash
   cd /home/MRwang/smart_assistant
   ```

3. **从GitHub拉取最新脚本**
   ```bash
   git fetch origin claude/memory-orchestrator-continuation-01SJWq33RhGxvpBwPVfrJNWW
   git checkout claude/memory-orchestrator-continuation-01SJWq33RhGxvpBwPVfrJNWW
   git pull
   ```

4. **复制测试文件到项目**
   ```bash
   # 测试文件在仓库的tests/目录，需要复制到项目
   cp -r tests/test_memory/test_state_machine.py /home/MRwang/smart_assistant/tests/test_memory/
   ```

---

## 🚀 阶段2.4: 接入confirm命令路由

**目标**: 将`_handle_confirm`方法连接到MQTT消息路由系统

### 执行步骤

1. **运行接入脚本**
   ```bash
   bash sa_step_09_stage_2_4_wire_confirm.sh
   ```

2. **预期输出**
   ```
   === Step 9 阶段2.4: 接入confirm命令路由 ===

   [1/4] 备份mqtt_handler.py
   ✓ 备份到: modules/memory/mqtt_handler.py.bak_step9_stage24

   [2/4] 定位命令路由代码
   [行号]: def _on_message...

   [3/4] 添加confirm命令路由
   ✓ 在第XXX行后添加confirm路由
   ✓ confirm路由添加成功

   [4/4] 添加confirm主题订阅
   ✓ confirm主题已添加到订阅列表

   [5/5] 语法检查
   ✓ 语法正确

   === 验证结果 ===
   --- confirm路由 ---
   'update': self._handle_update,
   'confirm': self._handle_confirm,

   --- confirm订阅 ---
   f"{cmd_prefix}/confirm"

   === 阶段2.4 完成 ===
   ```

3. **重启Memory服务**（应用修改）
   ```bash
   # 停止旧服务
   pkill -9 -f mqtt_handler

   # 启动新服务
   bash scripts/start_memory_handler.sh

   # 验证服务运行
   curl http://localhost:8081/health
   ```

---

## 🧪 阶段3: 状态机单元测试

**目标**: 验证状态机核心逻辑的正确性（22项测试）

### 执行步骤

1. **运行测试脚本**
   ```bash
   bash sa_step_09_stage_3_test.sh
   ```

2. **预期输出**（所有测试通过）
   ```
   === Step 9 阶段3: 状态机单元测试 ===

   [1/3] 检查测试文件
   ✓ 测试文件存在

   [2/3] 运行单元测试（22项测试）

   tests/test_memory/test_state_machine.py::TestDetermineInitialStatus::test_low_confidence_rejected PASSED
   tests/test_memory/test_state_machine.py::TestDetermineInitialStatus::test_boundary_confidence_accepted PASSED
   ...（共22项）

   ======================== 22 passed in 0.XX s ========================

   === ✓ 阶段3测试通过 ===

   【测试覆盖】
     ✓ 初始状态判断 (7项)
     ✓ 确认转换 (4项)
     ✓ 软删除 (3项)
     ✓ 归档转换 (2项)
     ✓ 阈值常量 (2项)
   ```

3. **如果测试失败**
   - 检查`modules/memory/state_machine.py`是否正确创建（来自阶段1）
   - 查看详细错误信息
   - 运行单个测试定位问题:
     ```bash
     pytest tests/test_memory/test_state_machine.py::TestDetermineInitialStatus::test_low_confidence_rejected -v
     ```

---

## 🔗 阶段4: Confirm命令集成测试

**目标**: 端到端验证confirm/reject流程通过MQTT工作正常

### 前提条件
- Memory服务必须运行中
- MQTT Broker正常（127.0.0.1:1883）

### 执行步骤

1. **运行集成测试**
   ```bash
   bash sa_step_09_stage_4_integration_test.sh
   ```

2. **预期输出**（4/4测试通过）
   ```
   === Step 9 阶段4: Confirm命令集成测试 ===

   [前提检查]
   ✓ Memory服务运行中
   ✓ 健康检查端点正常

   === 测试1: 正常confirm流程 ===
   [1.1] 添加profile记忆（置信度0.91 → pending_confirm）
   [1.2] 检查响应（应为pending_confirm）
   ✓ 状态正确: pending_confirm
     Memory ID: mem_xxxxx
   [1.3] 发送confirm命令
   [1.4] 检查confirm响应（应为active）
   ✓ Confirm成功
   ✓ 状态已转换为active

   === 测试2: Reject流程 ===
   [2.2] 发送reject命令
   [2.3] 检查reject响应（应为deleted）
   ✓ Reject成功，状态已转换为deleted

   === 测试3: 幂等性验证 ===
   ✓ 幂等性正常（返回缓存结果）

   === 测试4: 参数校验 ===
   ✓ 参数校验正常（拒绝无效decision）

   === ✓ 阶段4集成测试通过 (4/4) ===
   ```

3. **测试覆盖说明**
   - **测试1**: profile高置信度 → pending_confirm → confirm → active
   - **测试2**: pending_confirm → reject → deleted
   - **测试3**: 重复confirm请求（幂等性）
   - **测试4**: 无效decision参数拒绝

---

## ❌ 常见问题排查

### 问题1: 端口8081已被占用
**现象**: 启动服务时报错 `Address already in use`

**原因**: 后台进程未正确终止

**解决**:
```bash
pkill -9 -f mqtt_handler
bash scripts/start_memory_handler.sh
```

### 问题2: MQTT订阅无响应
**现象**: 集成测试中`mosquitto_sub`超时

**排查步骤**:
1. 检查MQTT Broker运行:
   ```bash
   systemctl status mosquitto
   ```

2. 检查Memory服务日志:
   ```bash
   tail -f /home/MRwang/smart_assistant/data/memory_handler.log
   ```

3. 手动测试订阅:
   ```bash
   mosquitto_sub -h 127.0.0.1 -t "sa/memory/resp/#" -v
   ```

### 问题3: 测试文件不存在
**现象**: 阶段3脚本报错测试文件缺失

**解决**: 确保从GitHub仓库复制了测试文件
```bash
cp -r tests/test_memory/test_state_machine.py /home/MRwang/smart_assistant/tests/test_memory/
```

---

## 📊 进度检查点

完成以下检查点后可继续阶段5:

- [ ] 阶段2.4脚本执行成功，语法检查通过
- [ ] Memory服务成功重启，`/health`端点正常
- [ ] 阶段3单元测试 22/22 通过
- [ ] 阶段4集成测试 4/4 通过
- [ ] 查看日志无ERROR级别错误

---

## 🎯 下一步行动（阶段5）

阶段2.4-4全部通过后，继续实施：

**阶段5: 实现state_changed事件广播**
- 修改`_send_event`方法支持state_changed事件类型
- 在confirm/reject操作后发布事件
- 事件包含: `old_status`, `new_status`, `reason`, `memory_id`

**阶段6: 更新/health端点**
- 暴露阈值常量（0.5/0.8/0.9）
- 添加状态机版本信息

**阶段7: 完整回归测试**
- 测试所有Step 9功能与Step 1-8的兼容性
- 性能测试（状态转换延迟）

---

## 📞 支持信息

**环境信息**:
- 设备: Raspberry Pi 4B
- 项目路径: `/home/MRwang/smart_assistant/`
- MQTT端口: 1883
- HTTP端口: 8081

**回滚方法**:
```bash
# 如果阶段2.4出现问题
cp modules/memory/mqtt_handler.py.bak_step9_stage24 modules/memory/mqtt_handler.py
pkill -9 -f mqtt_handler
bash scripts/start_memory_handler.sh
```

**日志位置**:
- Memory Handler: `data/memory_handler.log`
- MQTT Broker: `/var/log/mosquitto/mosquitto.log`

---

**文档生成**: Claude Code
**执行人**: 王总
**预计耗时**: 阶段2.4-4约15-20分钟
