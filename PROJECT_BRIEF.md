# 智能家居助手项目概览

**版本**: MVP v1.0  
**更新时间**: 2025-11-06  
**项目根路径**: `/home/MRwang/smart_assistant`

---

## 项目目标与范围

### In Scope（已实现功能）
- ✅ **语音交互**：ASR语音识别（讯飞实时流式）→ Rules规则引擎 → TTS语音合成（讯飞x5超拟人+Edge-TTS兜底）
- ✅ **唤醒词检测**：独立Wakeword服务，支持8条唤醒词（星辰在吗、在吗星辰等）
- ✅ **人脸识别**：Vision Scanner（基于OpenCV LBPH），30分钟扫描间隔，识别到人脸触发问候
- ✅ **智能对话**：Grok AI兜底（通过proxychains4 + SOCKS5代理）
- ✅ **事件驱动架构**：MQTT消息总线（Mosquitto 127.0.0.1:1883）
- ✅ **健康监控**：每个模块10秒心跳上报到 `sa/sys/health`
- ✅ **配置管理**：统一YAML配置 + .env.local环境变量

### Out of Scope（暂不实现）
- ❌ Systemd自动启动（手动终端启动）
- ❌ Web界面（5050端口未启用）
- ❌ 持久化记忆系统（待实现）
- ❌ 多人脸识别（当前仅单人模型）

---

## 当前运行形态

### 启动方式
**手动终端启动**（7个终端窗口）：
```
终端1: 空闲（执行临时命令）
终端2: Rules模块    - proxychains4 bash scripts/start_rules.sh
终端3: ASR模块      - bash scripts/start_asr.sh
终端4: MQTT监控     - mosquitto_sub -v -t 'sa/#'
终端5: TTS模块      - bash scripts/start_tts.sh
终端6: Greeting服务 - proxychains4 bash scripts/start_greeting.sh
终端7: Vision扫描   - bash scripts/start_vision_scanner.sh
终端8: Wakeword服务 - proxychains4 bash scripts/start_wakeword.sh
```

### 核心端口
- **MQTT Broker**: 127.0.0.1:1883（Mosquitto）
- **SOCKS5 Proxy**: 127.0.0.1:1080（闪连VPN，用于Grok API）
- **Web界面**: 未启用

### 主题订阅关系
| 模块 | 订阅主题 | 发布主题 |
|------|---------|---------|
| ASR | sa/asr/cmd/# | sa/asr/text |
| Rules | sa/asr/text | sa/tts/say, sa/chat/response |
| Wakeword | sa/asr/text | sa/tts/say |
| TTS | sa/tts/say | sa/tts/done |
| Greeting | sa/vision/face_detected | sa/tts/say |
| Vision | - | sa/vision/face_detected |
| 所有模块 | - | sa/sys/health（心跳） |

---

## 验收标准

### 功能验收
- ✅ 说"星辰在吗" → 听到回复（我在/臣在等15条模板随机选）
- ✅ 说其他内容 → Grok对话回复
- ✅ 人脸识别 → 自动问候（王总回来啦等16条模板随机选）
- ✅ 所有模块健康心跳正常（10秒间隔）

### 性能指标（目标）
- **唤醒词响应延迟**: <2秒（检测→Grok→TTS）
- **ASR识别准确率**: >90%（实际表现待测量）
- **人脸识别准确率**: >85%（已重训练，实测达标）
- **TTS播报质量**: 讯飞x5超拟人（主），Edge-TTS（兜底）

### 可运维性
- ✅ 统一日志目录：`logs/`（按日轮转）
- ✅ 配置集中管理：`config/*.yml`
- ✅ 备份机制：所有修改前自动备份（*.bak_<timestamp>）
- ✅ 回滚能力：保留最近10个备份文件

---

## 风险与回滚策略

### 主要风险
1. **ASR音频设备冲突**：PulseAudio/PipeWire占用麦克风
2. **Grok API调用失败**：代理不稳定或API配额耗尽
3. **人脸识别误触发**：光线变化导致频繁触发问候
4. **模块间消息风暴**：多个模块同时处理同一消息

### 回滚策略
```bash
# 1. 回滚代码（以rules_module为例）
LATEST=$(ls -t modules/rules/rules_module.py.bak_* | head -1)
cp "$LATEST" modules/rules/rules_module.py

# 2. 回滚配置
LATEST=$(ls -t data/rules.json.bak_* | head -1)
cp "$LATEST" data/rules.json

# 3. 重启服务
终端2: Ctrl+C → bash scripts/start_rules.sh

# 4. 完全回滚到稳定基线
cd ~/smart_assistant
git checkout <stable-commit-hash>  # TBD：需记录稳定版本哈希
```

### 紧急停止
```bash
# 停止所有模块（在各终端按Ctrl+C）
# 或批量杀进程
pkill -f "asr_module|rules_module|tts_module|greeting_service|scanner|wakeword_service"
```

---

## 下一步优化方向
1. **记忆系统**：SQLite存储对话历史，支持上下文召回
2. **多人脸识别**：扩展识别模型，支持家庭成员识别
3. **退出词服务**：和唤醒词服务类似，快速响应退出指令
4. **ASR音频修复**：解决设备冲突，实现可靠的语音触发
5. **Systemd托管**：生产环境自动启动和守护进程

---

**证据来源**: claude.txt（2025-11-06项目状态检查）
