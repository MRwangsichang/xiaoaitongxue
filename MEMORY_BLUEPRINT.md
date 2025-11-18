# 《Memory Orchestrator（记忆模块）实施蓝图 v1.3》
## 给 Claude Code 的开发执行文档

---

## 0. 本版核心确认（相对 v1.2）

| 配置项 | 确认值 | 说明 |
|--------|--------|------|
| **MQTT Topic 前缀** | `sa/` | 与现有 TTS 模块一致 |
| **离场超时** | 20s | 人离开摄像头 20 秒判定离场 |
| **person_id 命名** | `wangzong` | 与 Vision 模块 `data/faces/wangzong/` 对齐 |
| **客人模式** | 暂不实现 | 后续有需求再增加 |
| **profile 确认流程** | `pending_confirm` 状态 | 两次未确认则删除 |
| **时区** | `Asia/Tokyo` | 与台北同一时区 |

---

## 1. 目标与范围

### 1.1 目标
在树莓派本地实现"记忆管家"，按 `person_id` 绑定个人记忆，支撑"识别 → 个性问候 → 轻对话 → 记忆更新"的稳定闭环。

### 1.2 范围
- ✅ 数据模型、写入/更新/删除策略
- ✅ 接口（MQTT 为主，HTTP 可选）
- ✅ 状态机、去重/冲突/配额
- ✅ 可观测与运维、失败与恢复
- ✅ 测试与验收
- ✅ 与视觉/对话模块的时序集成

### 1.3 不含
- ❌ UI/管理前端
- ❌ 跨设备一致性
- ❌ 客人模式（后续增加）

---

## 2. 术语与约定

| 术语 | 定义 |
|------|------|
| `person_id` | 稳定标识，拼音小写（如 `wangzong`、`wangyanhao`） |
| `session`（当轮） | 从问候/首句起，至静默 60s / 离场 20s / 退出口令 / 10min 上限 / 人物切换止 |
| `turn` | 用户一句 → 系统一句 |
| `speakable` | 该条记忆是否允许在对话中"说出口"（bool） |
| `ttl_s` | 到期秒数（0=永久；>0 到期归档） |
| `pinned` | 是否置顶（优先被读取） |
| `priority` | 优先级（1–5，5最高） |
| 时区 | `Asia/Tokyo`；相对时间 → 绝对时间后写盘 |

---

## 3. 角色与职责

### 3.1 模块职责矩阵

| 模块 | 职责 |
|------|------|
| **Vision** | 输出 `person_id`、离场/切换信号 |
| **ASR** | 输出有效语音、静默时长 |
| **SessionManager** | 聚合 Vision/ASR，判定当轮开始/结束，广播 `sa/session/start\|end` |
| **Rules** | query → 拼 Prompt → Grok → 解析候选 → 发 memory cmd；串起全链路 |
| **Grok（LLM）** | 按抽取规约输出候选记忆 JSON + 删除/清空意图；根据 memory.query 结果生成自然回复（只读） |
| **Memory Orchestrator** | **唯一事实源**；存/改/删/查、阈值/去重/冲突/审计、过期清理、事件广播、备份 |
| **TTS** | 只读；与 ASR 停/启配合 |

### 3.2 SessionManager 判定规则

会话结束条件（任一触发）：
1. 静默超时：60s 无语音输入
2. 离场超时：20s 无人脸检测
3. 退出口令："退下"、"别唠叨了"、"滚"、"别当歪"、"静音"、"别说话"
4. 时间上限：10min
5. 人物切换：检测到不同 `person_id`

---

## 4. 数据模型

### 4.1 MemoryItem Schema

```sql
CREATE TABLE memory_items (
    id TEXT PRIMARY KEY,                    -- UUID
    person_id TEXT NOT NULL,                -- 'wangzong'
    slot TEXT NOT NULL,                     -- 归一化后的槽位
    value TEXT NOT NULL,                    -- ≤200字
    type TEXT NOT NULL CHECK(type IN ('profile', 'short', 'todo')),
    source TEXT NOT NULL CHECK(source IN ('grok', 'user', 'system')),
    confidence REAL NOT NULL,               -- 0.0-1.0
    speakable INTEGER NOT NULL DEFAULT 1,   -- 0/1
    ttl_s INTEGER NOT NULL DEFAULT 0,       -- 0=永久
    pinned INTEGER NOT NULL DEFAULT 0,      -- 0/1
    priority INTEGER NOT NULL DEFAULT 3 CHECK(priority BETWEEN 1 AND 5),
    status TEXT NOT NULL DEFAULT 'candidate' CHECK(status IN ('candidate', 'pending_confirm', 'active', 'archived', 'deleted')),
    created_at TEXT NOT NULL,               -- ISO8601 Asia/Tokyo
    updated_at TEXT NOT NULL,               -- ISO8601 Asia/Tokyo
    tags TEXT DEFAULT '[]'                  -- JSON array
);

-- 索引
CREATE INDEX idx_person_type_status ON memory_items(person_id, type, status);
CREATE INDEX idx_updated_at ON memory_items(updated_at);
CREATE INDEX idx_slot ON memory_items(slot);
CREATE INDEX idx_status ON memory_items(status);
```

### 4.2 存储配置

- **数据库**：`/home/MRwang/smart_assistant/data/memory.db`
- **模式**：SQLite WAL
- **权限**：600
- **查询 SLO**：p99 ≤ 50ms
- **慢查询日志**：独立文件 `logs/memory_slow.log`（>50ms 记录）

---

## 5. 状态机

### 5.1 状态流转

```
candidate ──(≥0.8 自动 或 "记一下")──→ active
    │                                      │
    │ (<0.5 丢弃)                          │ (short TTL到期)
    ↓                                      ↓
 [丢弃]                                archived
                                           │
                                           │ (30天后)
                                           ↓
                                       deleted
                                           │
                                           │ (7天后)
                                           ↓
                                     [物理删除]

profile 特殊流转：
candidate ──(≥0.9)──→ pending_confirm ──(确认)──→ active
                            │
                            │ (两次未确认)
                            ↓
                        deleted
```

### 5.2 状态说明

| 状态 | 说明 |
|------|------|
| `candidate` | 候选，0.5-0.8 置信度，不落盘不外放 |
| `pending_confirm` | profile 待确认，≥0.9 置信度，需口头确认 |
| `active` | 生效中，可被 query 读取 |
| `archived` | 已归档，保留 30 天 |
| `deleted` | 已删除，保留 7 天后物理删除 |

---

## 6. 写入策略

### 6.1 阈值规则

| 置信度 | 处理 |
|--------|------|
| ≥ 0.90（profile） | 进入 `pending_confirm`，等待口头确认 |
| ≥ 0.80 | 自动写入 `active` |
| 0.50 - 0.79 | 保持 `candidate`，不落盘 |
| < 0.50 | 丢弃 |

### 6.2 写入模式

- **全自动**：偏好、待办
- **半自动**：金钱、健康（需口头确认）

### 6.3 profile 确认流程

1. Grok 识别到 profile 变更（如"我换工作了"）
2. confidence ≥ 0.9 → 写入 `pending_confirm`
3. 系统问："我记下你现在在 XX 公司了，对吗？"
4. 用户确认："对/没错/是的" → 改为 `active`，旧值 → `archived`
5. 用户否认："不对/别记" → 改为 `deleted`
6. 超时未确认：本轮会话结束保留，下次见面再问一次
7. 两次未确认 → 改为 `deleted`

### 6.4 调用策略

- 问候只引用 **1 条** `speakable=true` 的近事/未了
- 上一小时聊过 → 轻问候不续聊
- 手动口令："新增/修改/删除/置顶/禁说/撤回/清空"

---

## 7. 去重、冲突与配额

### 7.1 去重
同 `person_id` + `slot` + `value` 完全重复 → 仅更新 `updated_at`

### 7.2 冲突
同一 `slot` 新值覆盖旧值：
- 旧值 → `archived`
- 新值 → `active`
- 支持"撤回"回滚（从 archived 恢复）

### 7.3 配额
- Home Free 模式：不设每日上限
- 问候调用只读 Top1
- 超量告警（可配置）

---

## 8. slot 归一化

### 8.1 策略
自由文本 + 词表归一，双轨运行：
- 写入前做同义词归一化
- 查询按归一化 slot 聚合

### 8.2 初始词表（20 个高频 slot）

**profile 类**：
- `name`, `birthday`, `job`, `company`, `hobby`, `family`, `health`, `preference`

**short 类**：
- `purchase`, `travel`, `event`, `mood`, `achievement`, `food`

**todo 类**：
- `buy`, `call`, `remind`, `schedule`, `task`, `appointment`

### 8.3 归一化示例
- "购物" / "买东西" / "shopping" → `purchase`
- "工作" / "上班" / "职业" → `job`

---

## 9. 接口规范

### 9.1 MQTT Topics

#### 命令（发给 Memory）
| Topic | 说明 |
|-------|------|
| `sa/memory/cmd/add` | 新增记忆 |
| `sa/memory/cmd/update` | 更新记忆 |
| `sa/memory/cmd/delete` | 删除记忆 |
| `sa/memory/cmd/get` | 获取单条 |
| `sa/memory/cmd/query` | 查询多条 |
| `sa/memory/cmd/confirm` | 确认 pending_confirm |
| `sa/memory/cmd/rollback` | 撤回（从 archived 恢复） |
| `sa/memory/cmd/purge_expired` | 清理过期 |
| `sa/memory/cmd/clear_person` | 清空某人记忆 |

#### 事件（Memory 广播）
| Topic | 说明 |
|-------|------|
| `sa/memory/event/added` | 新增成功 |
| `sa/memory/event/updated` | 更新成功 |
| `sa/memory/event/deleted` | 删除成功 |
| `sa/memory/event/confirmed` | 确认成功 |
| `sa/memory/event/expired` | 过期归档 |
| `sa/memory/event/cleared` | 清空完成 |
| `sa/memory/event/error` | 操作失败 |

#### 会话
| Topic | 说明 |
|-------|------|
| `sa/session/start` | 会话开始 |
| `sa/session/end` | 会话结束 |

### 9.2 Payload 示例

#### 新增
```json
{
  "id": "req-001",
  "ts": "2025-11-18T10:30:00+09:00",
  "type": "cmd.add",
  "payload": {
    "person_id": "wangzong",
    "mem_type": "short",
    "slot": "purchase",
    "value": "2025-11-18 去了山姆大量采购",
    "confidence": 0.90,
    "speakable": true,
    "ttl_s": 432000,
    "source": "grok"
  }
}
```

#### 查询
```json
{
  "id": "req-002",
  "type": "cmd.query",
  "payload": {
    "person_id": "wangzong",
    "types": ["short", "todo"],
    "status": "active",
    "speakable": true,
    "limit": 1
  }
}
```

#### 查询响应
```json
{
  "id": "req-002",
  "type": "resp.query",
  "payload": {
    "items": [
      {
        "id": "uuid-xxx",
        "slot": "purchase",
        "value": "2025-11-18 去了山姆大量采购",
        "type": "short",
        "confidence": 0.90,
        "speakable": true,
        "created_at": "2025-11-18T10:30:00+09:00"
      }
    ],
    "total": 1
  }
}
```

#### 错误响应
```json
{
  "id": "req-003",
  "type": "resp.error",
  "error": "person_id not found",
  "code": "ERR_NOT_FOUND"
}
```

### 9.3 HTTP 接口（可选，仅 127.0.0.1）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/health` | 健康检查 |
| GET | `/memory?person_id=...&types=...&limit=...` | 查询 |
| POST | `/memory/add` | 新增 |
| POST | `/memory/update` | 更新 |
| POST | `/memory/delete` | 删除 |
| POST | `/memory/confirm` | 确认 |
| POST | `/memory/purge_expired` | 清理过期 |
| POST | `/memory/clear_person` | 清空某人 |

---

## 10. Grok × Memory 闘环时序

```
┌─────────┐     ┌───────────────┐     ┌───────┐     ┌──────┐     ┌────────┐     ┌─────┐
│ Vision  │     │SessionManager │     │ Rules │     │Memory│     │  Grok  │     │ TTS │
└────┬────┘     └───────┬───────┘     └───┬───┘     └──┬───┘     └───┬────┘     └──┬──┘
     │                  │                 │            │             │             │
     │ person_id        │                 │            │             │             │
     ├─────────────────>│                 │            │             │             │
     │                  │ session/start   │            │             │             │
     │                  ├────────────────>│            │             │             │
     │                  │                 │ query      │             │             │
     │                  │                 ├───────────>│             │             │
     │                  │                 │   items    │             │             │
     │                  │                 │<───────────┤             │             │
     │                  │                 │ prompt+items              │             │
     │                  │                 ├────────────────────────-->│             │
     │                  │                 │ reply+candidates         │             │
     │                  │                 │<────────────────────────-─┤             │
     │                  │                 │ cmd.add    │             │             │
     │                  │                 ├───────────>│             │             │
     │                  │                 │ event/added│             │             │
     │                  │                 │<───────────┤             │             │
     │                  │                 │ say        │             │             │
     │                  │                 ├─────────────────────────────────────-->│
     │                  │                 │            │             │             │
     │ 离场/静默        │                 │            │             │             │
     ├─────────────────>│                 │            │             │             │
     │                  │ session/end     │            │             │             │
     │                  ├────────────────>│            │             │             │
```

---

## 11. 清理策略

| 状态变更 | 时机 | 动作 |
|----------|------|------|
| `active` → `archived` | short TTL 到期 / 被新值覆盖 | 自动 |
| `todo` → `deleted` | 完成 | 手动或自动 |
| `archived` → `deleted` | 30 天后 | 定时任务 |
| `deleted` → 物理删除 | 7 天后 | 定时任务 |

定时任务运行频率：每天 03:00

---

## 12. 可观测与运维

### 12.1 指标
- `memory_op_total{op="add|update|delete|query"}` — 操作计数
- `memory_reject_total` — 拒绝计数（低置信度）
- `memory_expired_total` — 过期计数
- `memory_db_size_bytes` — 数据库大小
- `memory_query_duration_ms` — 查询延迟
- `memory_error_total` — 错误计数

### 12.2 健康检查

`GET /health` 响应：
```json
{
  "status": "healthy",
  "db_ok": true,
  "pending_confirm": 0,
  "active_count": 42,
  "db_size_mb": 1.2,
  "uptime_s": 3600
}
```

### 12.3 日志
- 主日志：`logs/smart_assistant_YYYY-MM-DD.log`
- 慢查询：`logs/memory_slow.log`
- 切割：logrotate 周切割保 4 周

### 12.4 SLO
- 两周 error_rate < 1%
- 查询 p99 ≤ 50ms
- 撤回/清空可靠

---

## 13. 失败与恢复

| 故障 | 处理 |
|------|------|
| DB 锁/损坏 | 切备份只读 + 提示恢复 |
| MQTT 断线 | 命令缓冲 ≤100，恢复即重放；超过丢弃并报错 |
| 磁盘不足 | 停止写入，仅保读，并告警 |

---

## 14. 备份策略

- **频率**：每日 02:00
- **保留**：7 天
- **路径**：`/home/MRwang/smart_assistant/backups/memory/memory_YYYYMMDD.db`
- **加密**：可选（密钥路径 `~/.smart_assistant/secrets/memory.key`，权限 400）

---

## 15. 可配置项（默认值）

```yaml
# config/memory.yaml

memory:
  db_path: "/home/MRwang/smart_assistant/data/memory.db"
  wal_mode: true
  
  # 阈值
  confidence:
    auto_write: 0.80
    profile_confirm: 0.90
    candidate_low: 0.50
  
  # 默认值
  defaults:
    speakable: true
    ttl_short: 432000  # 5天
    ttl_todo: 0        # 完成即删
    priority: 3
  
  # 清理
  cleanup:
    archived_days: 30
    deleted_days: 7
    run_at: "03:00"
  
  # 查询
  query:
    default_limit: 1
    max_limit: 20
    slow_threshold_ms: 50
  
  # 会话
  session:
    silence_timeout_s: 60
    leave_timeout_s: 20
    max_duration_s: 600
    cooldown_same_person_s: 3600  # 上一小时聊过轻问候
  
  # profile 确认
  profile_confirm:
    max_attempts: 2
    timeout_action: "keep"  # keep=下次再问, delete=直接删除

mqtt:
  broker: "localhost"
  port: 1883
  client_id: "memory_orchestrator"
  topics:
    cmd_prefix: "sa/memory/cmd"
    event_prefix: "sa/memory/event"
    session_prefix: "sa/session"

http:
  enabled: true
  host: "127.0.0.1"
  port: 8081

logging:
  level: "INFO"
  slow_query_file: "logs/memory_slow.log"
```

---

## 16. 项目结构

```
/home/MRwang/smart_assistant/
├── core/
│   ├── __init__.py
│   ├── logger.py                    # 已有
│   └── config.py                    # 配置加载器
├── modules/
│   ├── memory/
│   │   ├── __init__.py
│   │   ├── orchestrator.py          # 主控模块
│   │   ├── db.py                    # 数据层 CRUD
│   │   ├── mqtt_handler.py          # MQTT 命令处理
│   │   ├── http_handler.py          # HTTP 接口（可选）
│   │   ├── state_machine.py         # 状态机逻辑
│   │   ├── normalizer.py            # slot 归一化
│   │   ├── scheduler.py             # 定时任务（清理/备份）
│   │   └── models.py                # Pydantic 模型
│   ├── vision/                      # 已有
│   ├── asr/                         # 已有
│   ├── rules/                       # 已有
│   └── tts/                         # 已有
├── config/
│   ├── memory.yaml                  # 记忆模块配置
│   └── ...
├── data/
│   ├── memory.db                    # SQLite 数据库
│   └── faces/                       # 已有
├── logs/
│   ├── smart_assistant_*.log        # 主日志
│   └── memory_slow.log              # 慢查询日志
├── backups/
│   └── memory/                      # 数据库备份
├── scripts/
│   ├── sa_step_*.sh                 # 小步脚本
│   ├── run_memory_health.sh         # 健康检查
│   └── ...
└── tests/
    └── test_memory/
        ├── test_db.py
        ├── test_mqtt.py
        └── test_state_machine.py
```

---

## 17. M1 小步拆分（10 步）

### 第 1 小步：目录骨架 + 依赖检查
**目标**：创建 memory 模块目录结构，检查 Python 依赖

**产物**：
- `modules/memory/__init__.py`
- `modules/memory/models.py`（空）
- `config/memory.yaml`（基础配置）

**验证**：`tree modules/memory`

---

### 第 2 小步：配置加载器
**目标**：实现 YAML 配置读取和验证

**产物**：
- `core/config.py`
- 完整的 `config/memory.yaml`

**验证**：`python3 -c "from core.config import load_config; print(load_config('memory'))"`

---

### 第 3 小步：SQLite 表结构 + 索引
**目标**：创建数据库和表

**产物**：
- `data/memory.db`
- 表 `memory_items` + 索引

**验证**：`sqlite3 data/memory.db ".schema memory_items"`

---

### 第 4 小步：数据层 CRUD
**目标**：实现基础增删改查

**产物**：
- `modules/memory/db.py`

**验证**：`pytest tests/test_memory/test_db.py`

---

### 第 5 小步：Pydantic 模型 + slot 归一化
**目标**：定义数据模型，实现 slot 归一化

**产物**：
- `modules/memory/models.py`
- `modules/memory/normalizer.py`

**验证**：单测归一化逻辑

---

### 第 6 小步：MQTT 命令处理器
**目标**：实现 add/query/delete 命令

**产物**：
- `modules/memory/mqtt_handler.py`

**验证**：`mosquitto_pub -t 'sa/memory/cmd/add' -m '{...}'` + `mosquitto_sub -t 'sa/memory/event/#'`

---

### 第 7 小步：MQTT 事件广播
**目标**：实现事件发布

**产物**：
- 完善 `mqtt_handler.py`

**验证**：`mosquitto_sub` 收到 `event/added`

---

### 第 8 小步：HTTP /health 端点
**目标**：实现健康检查接口

**产物**：
- `modules/memory/http_handler.py`

**验证**：`curl http://127.0.0.1:8081/health`

---

### 第 9 小步：状态机 + 阈值策略
**目标**：实现状态流转和置信度阈值

**产物**：
- `modules/memory/state_machine.py`
- 单测覆盖 0.5/0.8/0.9 边界

**验证**：`pytest tests/test_memory/test_state_machine.py`

---

### 第 10 小步：TTL 过期定时任务
**目标**：实现自动过期清理

**产物**：
- `modules/memory/scheduler.py`

**验证**：插入 `ttl_s=5` 记录，等待自动 archived

---

## 18. 关键约束（必须遵守）

### ⚠️ 严格禁止
1. **不得修改已有模块**：`modules/asr/`, `modules/rules/`, `modules/tts/`, `modules/vision/` 一行代码都不能动
2. **不得触碰系统文件**：只在 `/home/MRwang/smart_assistant/` 内操作
3. **不得批量输出多步**：每次只给一个最小可验证小步

### ✅ 必须遵守
1. **小步验证**：每个脚本执行完等用户粘贴输出再继续
2. **DRY_RUN 支持**：所有脚本支持预演模式（`DRY_RUN=1`）
3. **幂等性**：脚本可重复执行不出错
4. **路径用拼音**：避免中文路径
5. **终端标注**：每个脚本前必须明确标注 **【在终端1执行】**

### 🎯 输出格式（严格遵守）
每次必须包含 8 个部分：
```
[本小步目标]
[为什么现在做]
[预计终端回显（示例）]
[执行脚本]（代码块必须单独）
[验证命令]（单独的代码块）
[产物与路径]
[回滚方式]
[下一小步建议]
"已停在此步，等待你粘贴 SSH 输出"
```

---

## 19. 终端分配

| 终端 | 用途 |
|------|------|
| 终端 1 | 开发执行（所有脚本在此执行） |
| 终端 2 | Rules 模块 |
| 终端 3 | ASR 模块 |
| 终端 4 | MQTT 监控：`mosquitto_sub -v -t 'sa/#'` |
| 终端 5 | TTS 模块 |
| **终端 6**（新增） | Memory 模块 |

---

## 20. A4 接力卡（精简版）

```
【Topic】命令：sa/memory/cmd/*；事件：sa/memory/event/*；会话：sa/session/start|end
【会话】静默60s/离场20s/退出口令/10min上限/人物切换
【职责】Rules：query→Prompt→Grok→解析→cmd；Memory：唯一事实源；Grok：只读+候选JSON
【阈值】≥0.9(profile)→pending_confirm；≥0.8→active；0.5-0.8→candidate；<0.5丢弃
【slot】自由文本+词表归一；时间写盘前→Asia/Tokyo绝对时间
【存储】SQLite+WAL；索引5列；p99≤50ms；慢查询日志
【清理】archived保30天→deleted；deleted保7天→物理删除；每日快照保7天
【策略】Home Free；问候读Top1；上一小时轻问候；pending_confirm两次未确认删除
【M1】10小步：骨架→配置→DB→CRUD→模型→MQTT命令→事件→HTTP→状态机→TTL
【person_id】wangzong（与 Vision 对齐）
```

---

## 21. 开始指令

```
你好 Claude，我正在树莓派上开发智能助手的记忆模块（Memory Orchestrator）。

【当前进度】
- ✅ Vision 模块已完成（142张训练，识别准确率90%+）
- ✅ TTS 模块已完成（讯飞x5 + Edge-TTS 兜底）
- ✅ ASR/Rules 模块已完成
- ⏸️ 准备开始 Memory 模块

【任务】
按本文档的 M1 小步拆分，从第 1 小步开始：目录骨架 + 依赖检查

【关键配置】
- MQTT Topic 前缀：sa/
- person_id：wangzong
- 离场超时：20s
- 时区：Asia/Tokyo

【约束】
1. 所有操作在 **终端1** 执行（SSH: MRwang@192.168.0.155）
2. 严格按小步输出格式（8个部分）
3. 不得修改已有模块
4. 每步等我粘贴 SSH 输出再继续

请从第 1 小步开始。
```

---

**文档生成时间**：2025-11-18  8: 00
**版本**：v1.3
**状态**：可交付 Claude Code 执行
