# 关键决策记录 (ADR - Architecture Decision Records)

**项目**: 智能家居助手  
**更新时间**: 2025-11-06

---

## ADR-001: 选择MQTT作为消息总线

**日期**: 2025-10-11  
**状态**: ✅ 已采纳  

### 背景
需要一个轻量、可靠的消息总线连接各个模块（ASR、TTS、Rules等）。

### 备选方案
1. **MQTT** (Mosquitto)
2. Redis Pub/Sub
3. RabbitMQ
4. 直接HTTP API

### 决策
选择 **MQTT (Mosquitto)**

### 理由
- ✅ 轻量（树莓派资源有限）
- ✅ 支持通配符订阅（sa/#）
- ✅ QoS保证消息可靠性
- ✅ 本地部署，无外网依赖
- ✅ Python库成熟（paho-mqtt）
- ❌ Redis需要额外内存
- ❌ RabbitMQ过重

### 影响
- 所有模块依赖MQTT Broker（127.0.0.1:1883）
- 模块间通信延迟 <10ms
- 需要统一消息格式（EventEnvelope）

### 证据
- `config/*.yml` 中所有模块配置MQTT
- 运行稳定10+小时无消息丢失

---

## ADR-002: ASR采用讯飞实时流式识别

**日期**: 2025-10-18  
**状态**: ✅ 已采纳  

### 背景
需要本地化、低延迟的语音识别。

### 备选方案
1. **讯飞实时ASR** (WebSocket)
2. Google Speech-to-Text
3. 本地Whisper模型
4. Picovoice Leopard

### 决策
选择 **讯飞实时流式ASR**

### 理由
- ✅ 中文识别准确率高（>90%）
- ✅ 实时流式，延迟低（<1秒）
- ✅ WebSocket长连接，避免重复握手
- ✅ 有免费额度
- ❌ Google需要外网，延迟高
- ❌ Whisper树莓派性能不足
- ❌ Picovoice收费贵

### 影响
- 依赖讯飞API密钥（XUNFEI_APP_ID等）
- 需要16kHz单声道音频
- 音频设备冲突问题（PulseAudio占用）

### 未解决问题
- ⚠️ 麦克风设备冲突（PulseAudio/PipeWire）
- 需要手动发送录音命令才启动

### 证据
- `modules/asr/xunfei_asr.py`
- `config/asr.yml`

---

## ADR-003: TTS主用讯飞x5超拟人，Edge-TTS兜底

**日期**: 2025-10-29  
**状态**: ✅ 已采纳  

### 背景
需要高质量、自然的中文语音合成。

### 备选方案
1. **讯飞x5超拟人** + Edge-TTS兜底
2. 仅Edge-TTS
3. Google TTS
4. 本地Festival/eSpeak

### 决策
选择 **讯飞x5超拟人（主）+ Edge-TTS（兜底）**

### 理由
- ✅ 讯飞x5音质最佳（接近真人）
- ✅ Edge-TTS免费、稳定（兜底）
- ✅ 自动切换机制，可靠性高
- ❌ Google TTS需要外网
- ❌ 本地TTS音质差

### 影响
- 讯飞API失败时自动切换Edge-TTS
- 播报延迟 <0.5秒
- HifiBerry DAC音质优秀

### 证据
- `modules/tts/tts_module.py`（自动兜底逻辑）
- `config/tts.yml`（双提供商配置）

---

## ADR-004: 人脸识别使用OpenCV LBPH算法

**日期**: 2025-11-02  
**状态**: ✅ 已采纳  

### 背景
需要在树莓派上实现低成本人脸识别。

### 备选方案
1. **OpenCV LBPH**
2. Dlib + face_recognition
3. 云端API（阿里/腾讯）
4. 深度学习模型（FaceNet）

### 决策
选择 **OpenCV LBPH**

### 理由
- ✅ 轻量，树莓派可实时运行
- ✅ 离线，无隐私问题
- ✅ 训练数据需求少（100+张即可）
- ✅ 识别速度快（<100ms/帧）
- ❌ Dlib对树莓派性能要求高
- ❌ 云端API有延迟+隐私风险
- ❌ FaceNet模型太大

### 训练优化
- **v1模型**（92张纯背景）: 准确率~60%
- **v2模型**（142张含眼镜/多光线）: 准确率~90%

### 影响
- 需要收集100+训练样本
- 识别阈值设为60（越低越严格）
- 30分钟扫描间隔（可调）

### 证据
- `modules/vision/recognizer/face_recognizer.py`
- `data/faces/王总_v2.yml`（训练模型）

---

## ADR-005: Grok AI作为对话兜底

**日期**: 2025-10-28  
**状态**: ✅ 已采纳  

### 背景
Rules规则引擎无法覆盖所有对话，需要LLM兜底。

### 备选方案
1. **Grok AI** (via api.x.ai)
2. OpenAI GPT-4
3. Claude API
4. 本地Llama模型

### 决策
选择 **Grok AI**

### 理由
- ✅ 响应速度快（<2秒）
- ✅ 中文支持好
- ✅ 个性化配置（星辰人设）
- ✅ 价格合理
- ❌ GPT-4贵
- ❌ Claude API国内访问困难
- ❌ 本地Llama树莓派跑不动

### 网络方案
- 使用 **proxychains4 + SOCKS5代理**（127.0.0.1:1080）
- 闪连VPN提供稳定连接

### 影响
- 依赖代理稳定性
- API调用失败时无兜底（TBD：可增加本地规则）
- 每次对话消耗Token

### 证据
- `modules/llm/grok_client.py`
- `scripts/start_rules.sh`（使用proxychains4）

---

## ADR-006: 唤醒词独立服务，不走完整对话流程

**日期**: 2025-11-06  
**状态**: ✅ 已采纳  

### 背景
用户说"星辰在吗"后，不需要完整的Grok对话，只需要快速回复"我在"。

### 备选方案
1. **独立Wakeword服务**（检测→快速回复）
2. Rules规则处理（现状：已禁用）
3. ASR后处理（增加复杂度）

### 决策
选择 **独立Wakeword服务**

### 理由
- ✅ 响应快（从15条模板选，不调用Grok）
- ✅ 职责清晰（Wakeword vs Rules）
- ✅ 冷却机制防止重复触发（5秒）
- ✅ 8条唤醒词灵活配置
- ❌ Rules处理会触发Grok（慢+浪费Token）

### 实现细节
- Wakeword服务订阅 `sa/asr/text`
- 检测到唤醒词 → Grok从15条模板选一句
- Rules模块过滤唤醒词，避免双重处理

### 影响
- 新增模块（终端8）
- Rules模块需过滤唤醒词列表

### 证据
- `modules/wakeword/wakeword_service.py`
- `config/wakeword.yml`（8条唤醒词）
- `modules/rules/rules_module.py`（唤醒词过滤逻辑）

---

## ADR-007: 不启用Systemd，手动终端启动

**日期**: 2025-10-11  
**状态**: ✅ 已采纳（暂定）  

### 背景
开发阶段需要频繁调试和重启模块。

### 备选方案
1. **手动终端启动**（当前）
2. Systemd服务自动启动
3. Supervisor进程管理
4. Docker容器化

### 决策
选择 **手动终端启动**（开发阶段）

### 理由
- ✅ 调试方便（实时日志）
- ✅ 快速重启单个模块
- ✅ 灵活修改代码
- ❌ Systemd需要配置+调试困难
- ❌ Supervisor增加复杂度
- ❌ Docker树莓派性能损耗

### 后续计划
- **MVP阶段**：手动启动
- **生产阶段**：迁移到Systemd

### 影响
- 需要7个终端窗口
- 重启树莓派后需手动启动
- 无守护进程（进程崩溃不自动重启）

### 证据
- `docs/sa-template.service.example`（Systemd模板已准备）
- 当前运行方式：SSH多终端

---

## ADR-008: Stories规则引擎清空，避免与Wakeword冲突

**日期**: 2025-11-06  
**状态**: ✅ 已采纳  

### 背景
旧的Stories规则（home_smalltalk）会匹配"星辰在吗"，导致与Wakeword服务双重回复。

### 备选方案
1. **清空Stories数组**
2. 禁用特定Story（enabled: false）
3. 提高Story匹配阈值

### 决策
选择 **清空Stories数组**

### 理由
- ✅ 彻底解决冲突
- ✅ 当前不需要多轮对话（Stories用途）
- ✅ 简化Rules逻辑
- ❌ 禁用仍会执行匹配逻辑（浪费性能）

### 影响
- `data/rules.json` 中 `stories: []`
- Rules模块仅处理单轮规则（退出词等）
- 未匹配的走Grok兜底

### 证据
- `data/rules.json`（stories数组为空）
- 测试：说"星辰在吗"只触发Wakeword，无双重回复

---

## ADR-009: 人脸扫描间隔设为30分钟

**日期**: 2025-11-04  
**状态**: ✅ 已采纳  

### 背景
需要平衡识别及时性和系统资源消耗。

### 备选方案
1. 持续扫描（实时检测）
2. **30分钟间隔**（当前）
3. 5分钟间隔
4. 事件触发（门磁传感器）

### 决策
选择 **30分钟间隔扫描**

### 理由
- ✅ 树莓派CPU占用可控（扫描时11.7%）
- ✅ 满足家庭场景（回家频率不高）
- ✅ 降低误触发（频繁扫描→频繁问候→打扰）
- ❌ 持续扫描CPU 100%
- ❌ 5分钟间隔仍过于频繁

### 可调参数
```yaml
# config/vision_config.yaml
scanner:
  scan_interval: 1800  # 秒（30分钟）
```

### 影响
- 回家后最多等待30分钟才触发问候
- 可根据实际使用调整（测试期可改为5分钟）

### 证据
- `config/vision_config.yaml`
- Vision Scanner CPU占用11.7%（可接受）

---

## ADR-010: 记忆系统待实现（暂不启动）

**日期**: 2025-11-06  
**状态**: ⏳ 待实现  

### 背景
需要上下文记忆，让对话更智能（例如"我刚才说的电影叫什么"）。

### 备选方案
1. **SQLite本地存储**（计划采纳）
2. Redis缓存
3. 向量数据库（Chroma/Pinecone）
4. 纯文本文件

### 计划决策
选择 **SQLite本地存储**

### 理由（预期）
- ✅ 轻量，树莓派友好
- ✅ 支持结构化查询（时间/标签过滤）
- ✅ 离线，隐私安全
- ✅ Python集成简单（sqlite3模块）
- ❌ Redis需要额外内存
- ❌ 向量数据库过重

### 计划实现
- **MVP**: 简单KV存储（用户说过什么）
- **M1**: 时间衰减、标签召回
- **M2**: 与Rules/Grok集成

### 影响（预期）
- 新增 `modules/memory/` 目录
- 数据库路径: `data/memory/conversations.db`
- Rules模块调用记忆API

### 证据
- `modules/memory/` 目录已存在（待实现）
- 详见 **docs/TASKS_CODE.md**

---

## 决策总结表

| ADR | 决策 | 状态 | 影响范围 | 可逆性 |
|-----|------|------|---------|--------|
| 001 | MQTT消息总线 | ✅ 已采纳 | 全系统 | ⚠️ 低（重构成本高） |
| 002 | 讯飞实时ASR | ✅ 已采纳 | ASR模块 | ✅ 高（Provider可替换） |
| 003 | 讯飞x5 TTS + Edge兜底 | ✅ 已采纳 | TTS模块 | ✅ 高（Provider可替换） |
| 004 | OpenCV LBPH人脸识别 | ✅ 已采纳 | Vision模块 | ✅ 中（算法可替换） |
| 005 | Grok AI兜底 | ✅ 已采纳 | Rules模块 | ✅ 高（LLM可替换） |
| 006 | 独立Wakeword服务 | ✅ 已采纳 | Wakeword+Rules | ✅ 高（可合并回Rules） |
| 007 | 手动启动（非Systemd） | ✅ 暂定 | 运维方式 | ✅ 高（可迁移Systemd） |
| 008 | 清空Stories规则 | ✅ 已采纳 | Rules模块 | ✅ 高（可恢复） |
| 009 | 30分钟扫描间隔 | ✅ 已采纳 | Vision Scanner | ✅ 高（配置可调） |
| 010 | SQLite记忆系统 | ⏳ 待实现 | 未来全系统 | N/A |

---

**证据来源**: 项目开发历史、代码实现、配置文件
