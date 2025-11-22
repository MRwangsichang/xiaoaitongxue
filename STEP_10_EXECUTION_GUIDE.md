# Step 10 完整执行指南

**功能**: TTL过期自动处理
**创建时间**: 2025-11-22
**预计执行时间**: 40-60分钟

---

## 📋 功能说明

### 三级过期策略

1. **active → archived** (TTL到期)
   - 记忆的 `expired_at` 时间到期
   - 自动转换为 `archived` 状态
   - 发送 `expired` 事件

2. **archived → deleted** (30天后)
   - archived 状态超过30天
   - 自动软删除（status='deleted'）
   - 数据仍保留在数据库中

3. **deleted → 物理删除** (7天后)
   - deleted 状态超过7天
   - 从数据库彻底删除
   - 无法恢复

### 定时扫描

- **扫描间隔**: 每小时（3600秒）
- **启动扫描**: 服务启动时立即执行一次
- **并发安全**: 使用 WHERE 条件保护，避免重复处理

---

## 🚀 执行步骤

### 准备工作

1. **SSH登录树莓派**
   ```bash
   ssh MRwang@192.168.0.155
   cd /home/MRwang/smart_assistant
   ```

2. **确认当前Git状态**
   ```bash
   git status
   git log --oneline -2
   ```

   应该看到：
   ```
   285fbce - feat(memory): Step 9 阶段5-6
   30d99d6 - feat(memory): Step 9 状态机核心功能实现
   ```

3. **从GitHub拉取脚本**
   ```bash
   git fetch origin claude/memory-orchestrator-continuation-01SJWq33RhGxvpBwPVfrJNWW
   git checkout claude/memory-orchestrator-continuation-01SJWq33RhGxvpBwPVfrJNWW
   git pull
   ```

4. **复制脚本和测试到项目**
   ```bash
   # 复制执行脚本
   cp sa_step_10_stage_*.sh /home/MRwang/smart_assistant/

   # 复制测试文件
   cp tests/test_memory/test_expiration.py /home/MRwang/smart_assistant/tests/test_memory/
   ```

---

### 阶段1: 添加TTL过期处理逻辑

**执行**:
```bash
cd /home/MRwang/smart_assistant
bash sa_step_10_stage_1_ttl_expiration.sh
```

**预期输出**:
```
=== Step 10 阶段1: 添加TTL过期处理 ===

[1/5] 备份mqtt_handler.py
✓ 备份到: modules/memory/mqtt_handler.py.bak_step10_stage1

[2/5] 检查导入语句
✓ threading 导入已存在

[3/5] 添加过期扫描方法
✓ 过期扫描方法已添加

[4/5] 添加必要导入
✓ 添加 threading 导入
✓ 添加 timedelta 导入

[5/5] 在 run() 方法中启动扫描器
✓ 在第XXX行后添加扫描器启动
✓ 扫描器启动代码已添加

=== 语法检查 ===
✓ 语法正确

=== 阶段1 完成 ===
```

**验证修改**:
```bash
# 查看添加的方法
grep -n "def _scan_and_expire" modules/memory/mqtt_handler.py

# 查看扫描器启动
grep -n "_start_expiration_scanner" modules/memory/mqtt_handler.py
```

---

### 阶段2: 优化启动时立即扫描

**执行**:
```bash
bash sa_step_10_stage_3_immediate_scan.sh
```

**预期输出**:
```
=== Step 10 阶段3: 添加启动时立即扫描 ===

[1/2] 备份mqtt_handler.py
✓ 备份到: modules/memory/mqtt_handler.py.bak_step10_stage3

[2/2] 添加启动时立即扫描
✓ 在第XXX行后添加立即扫描
✓ 启动时立即扫描已添加

=== 语法检查 ===
✓ 语法正确

=== 阶段3 完成 ===
```

---

### 阶段3: 单元测试

**执行**:
```bash
python3 -m pytest tests/test_memory/test_expiration.py -v
```

**预期输出**:
```
============= test session starts ==============
collected 10 items

tests/test_memory/test_expiration.py::TestArchiveTransition::test_archive_active_memory PASSED
tests/test_memory/test_expiration.py::TestArchiveTransition::test_cannot_archive_candidate PASSED
tests/test_memory/test_expiration.py::TestArchiveTransition::test_cannot_archive_deleted PASSED
tests/test_memory/test_expiration.py::TestSoftDeleteFromArchived::test_soft_delete_archived PASSED
tests/test_memory/test_expiration.py::TestSoftDeleteFromArchived::test_soft_delete_keeps_reason PASSED
tests/test_memory/test_expiration.py::TestExpirationThresholds::test_ttl_thresholds_exist PASSED
tests/test_memory/test_expiration.py::TestExpirationThresholds::test_state_transitions_are_atomic PASSED
tests/test_memory/test_expiration.py::TestExpirationReasons::test_ttl_expiry_reason PASSED
tests/test_memory/test_expiration.py::TestExpirationReasons::test_archived_cleanup_reason PASSED
tests/test_memory/test_expiration.py::TestExpirationReasons::test_reason_preserved_in_return PASSED

============ 10 passed in 0.XX s ===============
```

---

### 阶段4: 集成测试

#### 4.1 准备测试数据

**执行**:
```bash
bash sa_step_10_stage_2_test_expiration.sh
```

这个脚本会：
- 创建3个测试记忆（模拟不同过期阶段）
- 提供测试验证命令

#### 4.2 重启服务触发扫描

**在终端6**（Memory服务运行的终端）:
```bash
# 按 Ctrl+C 停止服务

# 重新启动
bash scripts/start_memory_handler.sh
```

**观察日志**（应该看到）:
```
[INFO] 过期扫描线程已启动（间隔: 3600s）
[INFO] ✓ TTL过期归档: <memory_id> (active → archived)
[INFO] ✓ 归档转删除: <memory_id> (archived → deleted)
[INFO] ✓ 物理删除: <memory_id>
[INFO] 过期扫描完成: TTL归档=1, 软删除=1, 物理删除=1, 耗时=0.XX s
```

#### 4.3 验证结果

**在终端1**:
```bash
cd /home/MRwang/smart_assistant

# 查看测试记忆的最终状态
sqlite3 data/memory.db << EOFSQL
.mode column
.headers on
SELECT id, status, datetime(updated_at) as updated_at
FROM memory_items
WHERE id LIKE 'test_exp_%'
ORDER BY id;
EOFSQL
```

**预期结果**:
```
id                      status     updated_at
----------------------  ---------  -------------------
test_exp_<timestamp>    archived   2025-11-22 XX:XX:XX
test_exp_<..>_archived  deleted    2025-11-22 XX:XX:XX
                                   (test_exp_<..>_deleted 应该被物理删除，不显示)
```

#### 4.4 监听expired事件

**在终端4**（MQTT监听终端）:
```bash
mosquitto_sub -h 127.0.0.1 -t "sa/memory/event/expired" -v
```

**预期看到**:
```json
sa/memory/event/expired {
  "event_type": "expired",
  "memory_id": "...",
  "person_id": "wangzong",
  "old_status": "active",
  "new_status": "archived",
  "reason": "TTL到期",
  "server_time": "2025-11-22T..."
}
```

---

## ✅ 验证检查点

完成所有阶段后，确认以下检查点：

- [ ] 阶段1脚本执行成功，语法检查通过
- [ ] 阶段3脚本执行成功，添加启动扫描
- [ ] 单元测试 10/10 通过
- [ ] Memory服务成功重启
- [ ] 启动日志显示"过期扫描线程已启动"
- [ ] 启动日志显示扫描完成（TTL归档/软删除/物理删除计数）
- [ ] 测试记忆状态正确转换
- [ ] 捕获到 expired 事件

---

## 🔧 故障排查

### 问题1: 扫描器未启动

**现象**: 启动日志没有"过期扫描线程已启动"

**排查**:
```bash
# 检查扫描器启动代码是否添加
grep -A 2 "_start_expiration_scanner" modules/memory/mqtt_handler.py
```

**解决**: 重新执行阶段1脚本

---

### 问题2: 扫描未执行

**现象**: 重启后没有看到扫描日志

**排查**:
```bash
# 检查是否有过期记忆
sqlite3 data/memory.db << EOFSQL
SELECT COUNT(*) as count
FROM memory_items
WHERE status = 'active'
  AND expired_at IS NOT NULL
  AND expired_at < datetime('now');
EOFSQL
```

**解决**:
- 如果count=0，说明没有过期记忆，使用阶段2脚本创建测试数据
- 如果count>0但未扫描，检查服务日志是否有错误

---

### 问题3: 语法错误

**现象**: 语法检查失败

**解决**:
```bash
# 回滚到备份
cp modules/memory/mqtt_handler.py.bak_step10_stage1 modules/memory/mqtt_handler.py

# 查看详细错误
python3 -m py_compile modules/memory/mqtt_handler.py
```

---

## 📦 提交代码

所有测试通过后，提交代码：

```bash
cd /home/MRwang/smart_assistant

# 查看修改
git status --short

# 添加到暂存区
git add modules/memory/mqtt_handler.py \
        tests/test_memory/test_expiration.py

# 创建提交
git commit -m "$(cat <<'EOF'
feat(memory): Step 10 TTL过期自动处理

实现内容：
- TTL过期扫描定时任务（每小时）
- 三级过期策略：
  * active → archived (TTL到期)
  * archived → deleted (30天)
  * deleted → 物理删除 (7天)
- 并发安全的状态更新
- expired 事件发送
- 启动时立即扫描优化

测试结果：
✓ 10/10 单元测试通过
✓ 三级过期转换正确
✓ expired 事件正常发送
✓ 扫描任务稳定运行
EOF
)"

# 查看提交
git log --oneline -3
```

---

## 📊 完成标志

看到以下输出表示Step 10完成：

```
[INFO] 过期扫描线程已启动（间隔: 3600s）
[INFO] ✓ TTL过期归档: <id> (active → archived)
[INFO] ✓ 归档转删除: <id> (archived → deleted)
[INFO] ✓ 物理删除: <id>
[INFO] 过期扫描完成: TTL归档=X, 软删除=X, 物理删除=X, 耗时=0.XX s
```

**Git提交记录**:
```
<commit_hash> - feat(memory): Step 10 TTL过期自动处理
285fbce - feat(memory): Step 9 阶段5-6 - 事件广播和健康检查增强
30d99d6 - feat(memory): Step 9 状态机核心功能实现
```

---

## 🎯 下一步

Step 10完成后，Memory Orchestrator模块的核心功能全部实现完毕！

**可选优化**:
- 添加手动触发扫描的MQTT命令
- 将扫描间隔改为可配置
- 添加扫描统计到 /health 端点
- 添加扫描性能监控

**生产环境准备**:
- 配置系统服务（systemd）
- 设置日志轮转
- 添加监控告警
- 编写运维文档

---

**文档生成**: Claude Code
**执行人**: 王总
**预计耗时**: 40-60分钟
