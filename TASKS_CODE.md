# Claude Code 任务清单

**项目**: 智能家居助手 - 记忆系统实现  
**目标**: 实现MVP记忆系统，为对话提供上下文召回能力  
**优先级**: P0 (核心功能)  
**预计工期**: 2-3周

---

## ⚠️ **开发约束与原则**

### 强制约束
1. **语言**: 全程使用中文注释和文档
2. **禁用工具**: 不使用 Web Search（项目已有完整文档）
3. **路径保护**: 不修改 `/home/MRwang/smart_assistant/modules/` 已有模块
4. **分支策略**: 所有改动走新分支 + PR，禁止直接推送到 main
5. **验收要求**: 每个里程碑必须通过验收测试才能合并

### 开发原则
- ✅ **小步快跑**: 每个任务1-2小时完成，立即验证
- ✅ **测试优先**: 先写测试，再写实现
- ✅ **备份先行**: 修改前自动备份（.bak_timestamp）
- ✅ **文档同步**: 代码与文档同步更新
- ✅ **日志完整**: 所有操作记录到 logs/

### 回滚保障
每个PR必须包含：
1. 变更清单（修改了哪些文件）
2. 回滚命令（一键恢复）
3. 验收步骤（如何测试）

---

## 📋 **里程碑规划**
```
MVP (Week 1-2)     → 基础记忆存储与召回
  ↓
M1 (Week 3)        → 时间衰减与标签召回
  ↓
M2 (Week 4+)       → 与Rules/Grok集成
```

---

## 🎯 **MVP: 基础记忆系统**

**目标**: 实现简单的对话存储与召回，支持最近N条查询

### 任务列表

#### Task-MVP-001: 创建数据库表结构
**预计时间**: 30分钟  
**分支名**: `feature/memory-db-schema`

**需求**:
创建 SQLite 数据库，包含以下表：
- `conversations`: 对话记录（ID、时间戳、用户输入、助手回复、会话ID）
- `tags`: 标签表（ID、对话ID、标签名）
- `metadata`: 元数据表（键值对，存储系统配置）

**实现路径**:
```
/home/MRwang/smart_assistant/modules/memory/storage/database.py
/home/MRwang/smart_assistant/data/memory/conversations.db
```

**验收标准**:
```bash
# 1. 数据库文件存在
ls -lh data/memory/conversations.db

# 2. 表结构正确
sqlite3 data/memory/conversations.db ".schema" | grep "CREATE TABLE"
# 期望: 看到 conversations, tags, metadata 三张表

# 3. 可以插入测试数据
python3 <<'PY'
from modules.memory.storage.database import MemoryDB
db = MemoryDB()
db.save_conversation("你好", "你好，我是星辰", session_id="test_001")
print("✓ 插入成功")
PY
```

**回滚命令**:
```bash
rm data/memory/conversations.db
git checkout main -- modules/memory/storage/database.py
```

---

#### Task-MVP-002: 实现基础存储API
**预计时间**: 1小时  
**分支名**: `feature/memory-basic-api`  
**依赖**: Task-MVP-001

**需求**:
实现 `MemoryManager` 类，提供：
- `save(user_input, assistant_reply, session_id)`: 保存对话
- `recall_recent(n=5, session_id=None)`: 召回最近N条
- `clear_session(session_id)`: 清空会话

**实现路径**:
```
/home/MRwang/smart_assistant/modules/memory/memory_manager.py
```

**API示例**:
```python
from modules.memory.memory_manager import MemoryManager

mm = MemoryManager()

# 保存对话
mm.save("今天天气怎么样", "今天天气晴朗，最高温度25度", session_id="user_001")

# 召回最近5条
recent = mm.recall_recent(n=5, session_id="user_001")
print(recent)
# 输出: [
#   {"user": "今天天气怎么样", "assistant": "今天天气晴朗...", "timestamp": "2025-11-06T20:00:00Z"},
#   ...
# ]
```

**验收标准**:
```bash
# 运行单元测试
cd ~/smart_assistant
python3 -m pytest tests/test_memory_manager.py -v

# 期望输出:
# test_save_conversation PASSED
# test_recall_recent PASSED
# test_clear_session PASSED
# ✓ 3 passed in 0.5s
```

**回滚命令**:
```bash
git checkout main -- modules/memory/memory_manager.py
rm tests/test_memory_manager.py
```

---

#### Task-MVP-003: 编写单元测试
**预计时间**: 1小时  
**分支名**: `feature/memory-tests`  
**依赖**: Task-MVP-002

**需求**:
为 `MemoryManager` 编写完整单元测试，覆盖：
- 正常场景（保存/召回）
- 边界条件（空数据、n=0、不存在的session_id）
- 并发场景（多会话同时保存）

**实现路径**:
```
/home/MRwang/smart_assistant/tests/test_memory_manager.py
```

**测试用例**:
```python
def test_save_and_recall():
    """测试基本保存与召回"""
    mm = MemoryManager(db_path=":memory:")  # 使用内存数据库
    mm.save("你好", "你好，我是星辰", session_id="test")
    recent = mm.recall_recent(n=1, session_id="test")
    assert len(recent) == 1
    assert recent[0]["user"] == "你好"

def test_recall_empty():
    """测试召回空会话"""
    mm = MemoryManager(db_path=":memory:")
    recent = mm.recall_recent(n=5, session_id="nonexistent")
    assert recent == []

def test_recall_limit():
    """测试召回数量限制"""
    mm = MemoryManager(db_path=":memory:")
    for i in range(10):
        mm.save(f"消息{i}", f"回复{i}", session_id="test")
    recent = mm.recall_recent(n=3, session_id="test")
    assert len(recent) == 3
    assert recent[0]["user"] == "消息9"  # 最新的
```

**验收标准**:
```bash
python3 -m pytest tests/test_memory_manager.py -v --cov=modules/memory

# 期望:
# - 所有测试通过
# - 代码覆盖率 >80%
```

**回滚命令**:
```bash
rm tests/test_memory_manager.py
```

---

#### Task-MVP-004: 创建记忆服务模块
**预计时间**: 1.5小时  
**分支名**: `feature/memory-service`  
**依赖**: Task-MVP-003

**需求**:
创建独立的记忆服务模块，监听MQTT消息，自动保存对话：
- 订阅 `sa/asr/text`（用户输入）
- 订阅 `sa/chat/response`（助手回复）
- 自动配对保存到数据库
- 发布 `sa/sys/health` 心跳

**实现路径**:
```
/home/MRwang/smart_assistant/modules/memory/memory_service.py
/home/MRwang/smart_assistant/config/memory.yml
/home/MRwang/smart_assistant/scripts/start_memory.sh
```

**配置文件示例**:
```yaml
# config/memory.yml
mqtt:
  broker: localhost
  port: 1883

memory:
  db_path: "data/memory/conversations.db"
  auto_save: true
  max_history: 1000  # 最多保存1000条对话

logging:
  level: INFO
  dir: logs
```

**验收标准**:
```bash
# 1. 启动记忆服务（新终端）
cd ~/smart_assistant
bash scripts/start_memory.sh

# 期望输出:
# [HH:MM:SS] === 启动记忆服务 ===
# [YYYY-MM-DD HH:MM:SS] [INFO] [memory] ✓ 数据库已连接
# [YYYY-MM-DD HH:MM:SS] [INFO] [memory] === 记忆服务就绪 ===

# 2. 发送测试消息
mosquitto_pub -t 'sa/asr/text' -m '{"payload":{"text":"测试保存"}}'
mosquitto_pub -t 'sa/chat/response' -m '{"payload":{"text":"测试回复"}}'

# 3. 验证数据保存
sqlite3 data/memory/conversations.db "SELECT user_input, assistant_reply FROM conversations ORDER BY timestamp DESC LIMIT 1;"
# 期望: 测试保存|测试回复
```

**回滚命令**:
```bash
pkill -f memory_service.py
rm modules/memory/memory_service.py
rm config/memory.yml
rm scripts/start_memory.sh
```

---

#### Task-MVP-005: 集成健康检查
**预计时间**: 30分钟  
**分支名**: `feature/memory-health`  
**依赖**: Task-MVP-004

**需求**:
为记忆服务添加健康检查，包括：
- 10秒心跳上报
- 数据库连接状态
- 当前记录数

**验收标准**:
```bash
# 监听健康心跳
timeout 30 mosquitto_sub -t 'sa/sys/health' | grep memory

# 期望输出（每10秒一次）:
# {"module":"memory","status":"running","db_connected":true,"total_records":42,...}
```

**回滚命令**:
```bash
git checkout main -- modules/memory/memory_service.py
```

---

### MVP验收总结

**完成标准**:
- ✅ 数据库表创建成功
- ✅ 基础API通过单元测试
- ✅ 记忆服务可独立启动
- ✅ 对话自动保存到数据库
- ✅ 健康心跳正常上报

**集成测试**:
```bash
# 端到端测试脚本
cd ~/smart_assistant

# 1. 启动记忆服务
bash scripts/start_memory.sh &
MEMORY_PID=$!

# 2. 模拟5轮对话
for i in {1..5}; do
  mosquitto_pub -t 'sa/asr/text' -m "{\"payload\":{\"text\":\"用户消息$i\"}}"
  sleep 1
  mosquitto_pub -t 'sa/chat/response' -m "{\"payload\":{\"text\":\"助手回复$i\"}}"
  sleep 1
done

# 3. 验证保存数量
COUNT=$(sqlite3 data/memory/conversations.db "SELECT COUNT(*) FROM conversations;")
if [ "$COUNT" -ge 5 ]; then
  echo "✓ MVP验收通过：保存了 $COUNT 条对话"
else
  echo "✗ MVP验收失败：仅保存了 $COUNT 条对话"
fi

# 4. 清理
kill $MEMORY_PID
```

---

## 🚀 **M1: 时间衰减与标签召回**

**目标**: 增强记忆召回能力，支持时间加权和标签过滤

### 任务列表

#### Task-M1-001: 实现时间衰减算法
**预计时间**: 2小时  
**分支名**: `feature/memory-time-decay`  
**依赖**: MVP完成

**需求**:
实现记忆召回的时间衰减权重：
- 最近1小时：权重1.0
- 1天前：权重0.7
- 1周前：权重0.3
- 1个月前：权重0.1

**算法**:
```python
def time_decay_weight(timestamp_str: str) -> float:
    """计算时间衰减权重"""
    now = datetime.now()
    timestamp = datetime.fromisoformat(timestamp_str)
    hours_ago = (now - timestamp).total_seconds() / 3600
    
    if hours_ago <= 1:
        return 1.0
    elif hours_ago <= 24:
        return 0.7
    elif hours_ago <= 168:  # 1周
        return 0.3
    elif hours_ago <= 720:  # 30天
        return 0.1
    else:
        return 0.05
```

**新增API**:
```python
mm = MemoryManager()
results = mm.recall_weighted(query="电影", n=5, session_id="user_001")
# 返回: [
#   {"user": "...", "assistant": "...", "timestamp": "...", "weight": 0.8},
#   ...
# ] (按weight排序)
```

**验收标准**:
```bash
python3 -m pytest tests/test_memory_time_decay.py -v

# 测试用例:
# - test_recent_weight_high (最近对话权重1.0)
# - test_old_weight_low (旧对话权重低)
# - test_weighted_recall_order (按权重排序)
```

---

#### Task-M1-002: 实现标签系统
**预计时间**: 2小时  
**分支名**: `feature/memory-tags`  
**依赖**: Task-M1-001

**需求**:
支持为对话添加标签（手动或自动），并按标签召回：
- 手动标签：用户/开发者指定
- 自动标签：基于关键词提取（简单版）

**新增API**:
```python
# 保存时添加标签
mm.save("推荐一部科幻电影", "我推荐《星际穿越》", tags=["电影", "科幻"])

# 按标签召回
results = mm.recall_by_tags(tags=["电影"], n=5)
```

**自动标签提取（简单版）**:
```python
def auto_extract_tags(text: str) -> list:
    """简单关键词提取"""
    keywords = ["电影", "天气", "音乐", "新闻", "时间", "日期"]
    return [kw for kw in keywords if kw in text]
```

**验收标准**:
```bash
python3 -m pytest tests/test_memory_tags.py -v

# 测试用例:
# - test_save_with_tags (保存带标签)
# - test_recall_by_tags (按标签召回)
# - test_auto_tag_extraction (自动提取)
```

---

#### Task-M1-003: 添加Metrics埋点
**预计时间**: 1小时  
**分支名**: `feature/memory-metrics`  
**依赖**: Task-M1-002

**需求**:
为记忆系统添加性能指标监控：
- 每秒保存速率（writes/sec）
- 平均召回延迟（recall_latency_ms）
- 数据库大小（db_size_mb）
- 命中率（recall_hit_rate）

**实现方式**:
```python
class MemoryMetrics:
    def __init__(self):
        self.write_count = 0
        self.recall_count = 0
        self.total_recall_time = 0.0
    
    def record_write(self):
        self.write_count += 1
    
    def record_recall(self, duration_ms):
        self.recall_count += 1
        self.total_recall_time += duration_ms
    
    def get_stats(self) -> dict:
        return {
            "writes_per_sec": self.write_count / uptime,
            "avg_recall_latency_ms": self.total_recall_time / self.recall_count,
            ...
        }
```

**验收标准**:
```bash
# 查看记忆服务健康心跳（包含metrics）
timeout 30 mosquitto_sub -t 'sa/sys/health' | grep memory | jq '.payload.metrics'

# 期望输出:
# {
#   "writes_per_sec": 0.5,
#   "avg_recall_latency_ms": 12.3,
#   "db_size_mb": 0.8,
#   "total_records": 42
# }
```

---

### M1验收总结

**完成标准**:
- ✅ 时间衰减算法通过测试
- ✅ 标签系统正常工作
- ✅ Metrics埋点上报正常
- ✅ 召回延迟 <50ms

**性能测试**:
```bash
# 性能基准测试
python3 <<'PY'
from modules.memory.memory_manager import MemoryManager
import time

mm = MemoryManager()

# 1. 写入性能
start = time.time()
for i in range(100):
    mm.save(f"用户消息{i}", f"助手回复{i}", session_id="perf_test")
write_time = time.time() - start
print(f"✓ 100条写入耗时: {write_time:.2f}秒 ({100/write_time:.1f} writes/sec)")

# 2. 召回性能
start = time.time()
for i in range(100):
    mm.recall_recent(n=10, session_id="perf_test")
recall_time = time.time() - start
print(f"✓ 100次召回耗时: {recall_time:.2f}秒 ({recall_time*10:.1f} ms/recall)")

# 期望:
# - 写入速率 >50 writes/sec
# - 召回延迟 <50ms
PY
```

---

## 🔗 **M2: 与Rules/Grok集成**

**目标**: 让Rules模块和Grok可以利用记忆提供上下文

### 任务列表

#### Task-M2-001: Rules模块集成记忆召回
**预计时间**: 2小时  
**分支名**: `feature/rules-memory-integration`  
**依赖**: M1完成

**需求**:
在Rules模块处理ASR文本前，先召回相关记忆：
```python
# modules/rules/rules_module.py

async def _on_asr_text(self, envelope):
    text = envelope.payload.get("text", "")
    
    # 召回最近5条对话
    from modules.memory.memory_manager import MemoryManager
    mm = MemoryManager()
    context = mm.recall_recent(n=5, session_id="default")
    
    # 如果触发Grok，附加上下文
    if result.get('need_gpt'):
        context_str = "\n".join([f"用户: {c['user']}\n助手: {c['assistant']}" for c in context])
        prompt = f"历史对话:\n{context_str}\n\n当前问题: {text}"
        response = await self.grok.chat(prompt, ...)
```

**验收标准**:
```bash
# 1. 进行多轮对话
mosquitto_pub -t 'sa/asr/text' -m '{"payload":{"text":"我喜欢科幻电影"}}'
sleep 2
mosquitto_pub -t 'sa/asr/text' -m '{"payload":{"text":"推荐一部给我"}}'

# 2. 查看Rules日志，应包含上下文
tail -20 logs/rules.log | grep "历史对话"

# 期望: Grok收到的prompt包含"我喜欢科幻电影"这个上下文
```

**⚠️ 注意**: 此任务会修改已有模块 `rules_module.py`，需要：
1. 完整备份当前版本
2. 在新分支开发
3. 充分测试后才能合并

---

#### Task-M2-002: Grok prompt优化
**预计时间**: 1小时  
**分支名**: `feature/grok-context-prompt`  
**依赖**: Task-M2-001

**需求**:
优化Grok的prompt模板，更好地利用记忆上下文：
```python
CONTEXT_PROMPT_TEMPLATE = """
你是星辰，王总的智能助手。以下是最近的对话历史：

{context}

王总刚才说: {current_input}

请根据对话历史，给出自然、连贯的回复。如果历史中有相关信息，请引用。
"""
```

**验收标准**:
```bash
# 测试上下文理解
# 第1轮:
mosquitto_pub -t 'sa/asr/text' -m '{"payload":{"text":"我叫张三"}}'
# 期望回复: "好的，张三，很高兴认识你"

# 第2轮:
mosquitto_pub -t 'sa/asr/text' -m '{"payload":{"text":"我叫什么"}}'
# 期望回复: "你叫张三"（利用了第1轮的记忆）
```

---

#### Task-M2-003: 记忆管理命令
**预计时间**: 1小时  
**分支名**: `feature/memory-cli`  
**依赖**: M2完成

**需求**:
创建命令行工具，方便管理记忆：
```bash
# 查看最近10条记忆
python3 scripts/memory_cli.py list --recent 10

# 按标签查看
python3 scripts/memory_cli.py list --tags "电影,科幻"

# 清空特定会话
python3 scripts/memory_cli.py clear --session "user_001"

# 导出记忆（备份）
python3 scripts/memory_cli.py export --output backup.json

# 导入记忆（恢复）
python3 scripts/memory_cli.py import --input backup.json
```

**验收标准**:
```bash
# 运行所有命令，无报错
python3 scripts/memory_cli.py list --recent 5
python3 scripts/memory_cli.py export --output /tmp/test.json
ls -lh /tmp/test.json
# 期望: 文件存在，大小>0
```

---

### M2验收总结

**完成标准**:
- ✅ Rules模块成功集成记忆召回
- ✅ Grok能利用上下文生成连贯回复
- ✅ 记忆管理命令行工具可用
- ✅ 端到端测试通过

**端到端测试**:
```bash
# 完整对话场景测试
cd ~/smart_assistant

# 1. 启动所有服务（包括记忆服务）
# （各终端启动...）

# 2. 进行3轮对话，测试上下文记忆
echo "第1轮: 建立上下文"
mosquitto_pub -t 'sa/asr/text' -m '{"payload":{"text":"我最近在看《三体》"}}'
sleep 3

echo "第2轮: 引用上下文"
mosquitto_pub -t 'sa/asr/text' -m '{"payload":{"text":"这本书讲的是什么"}}'
sleep 3

echo "第3轮: 深度对话"
mosquitto_pub -t 'sa/asr/text' -m '{"payload":{"text":"推荐类似的书"}}'
sleep 3

# 3. 查看记忆数据库
sqlite3 data/memory/conversations.db "SELECT user_input, assistant_reply FROM conversations ORDER BY timestamp DESC LIMIT 3;"

# 期望: 
# - 保存了3轮完整对话
# - 助手回复中体现了对《三体》的理解
```

---

## 📊 **总体验收矩阵**

| 里程碑 | 功能点 | 测试方法 | 期望结果 | 状态 |
|-------|--------|---------|---------|------|
| **MVP** | 数据库创建 | `ls data/memory/conversations.db` | 文件存在 | ⏳ |
| MVP | 基础API | `pytest tests/test_memory_manager.py` | 所有测试通过 | ⏳ |
| MVP | 记忆服务 | `bash scripts/start_memory.sh` | 正常启动 | ⏳ |
| MVP | 自动保存 | 发送MQTT消息 | 对话保存到DB | ⏳ |
| **M1** | 时间衰减 | `pytest tests/test_memory_time_decay.py` | 权重计算正确 | ⏳ |
| M1 | 标签系统 | `mm.recall_by_tags(["电影"])` | 返回相关对话 | ⏳ |
| M1 | Metrics | 查看健康心跳 | 包含性能指标 | ⏳ |
| **M2** | Rules集成 | 多轮对话测试 | 上下文连贯 | ⏳ |
| M2 | Grok优化 | "我叫什么"测试 | 正确引用记忆 | ⏳ |
| M2 | CLI工具 | `memory_cli.py list` | 正常显示 | ⏳ |

---

## 🔍 **风险与缓解**

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| SQLite并发写入冲突 | 中 | 高 | 使用 WAL 模式 + 重试机制 |
| 记忆服务崩溃丢失数据 | 低 | 高 | 定期自动备份 + 事务保护 |
| 召回延迟过高 | 中 | 中 | 索引优化 + 限制召回数量 |
| 与现有模块冲突 | 低 | 高 | 独立模块 + 充分测试 |
| 数据库膨胀 | 高 | 低 | 定期清理旧数据 + 压缩 |

---

## 📝 **文档更新清单**

每个里程碑完成后，需更新以下文档：

- ✅ `docs/MODULES_MATRIX.md` - 添加memory模块信息
- ✅ `docs/RUNBOOK.md` - 添加记忆服务启动步骤
- ✅ `docs/BASELINE.md` - 更新端口和服务列表
- ✅ `docs/COMMAND_LOG.md` - 添加记忆相关命令
- ✅ `.project_state/progress.json` - 更新进度状态

---

## 🚀 **后续优化方向（M3+）**

- **向量检索**: 使用 embedding 实现语义相似度召回
- **多模态记忆**: 支持图片、文件等非文本记忆
- **记忆压缩**: 自动总结旧对话，减少存储
- **隐私保护**: 敏感信息自动脱敏
- **分布式存储**: 支持多设备同步

---

**证据来源**: 项目现状分析、记忆系统需求、最佳实践
