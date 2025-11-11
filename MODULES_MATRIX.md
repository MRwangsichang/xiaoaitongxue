# 模块状态矩阵

**更新时间**: 2025-11-06 20:56  
**证据来源**: claude.txt（项目状态检查）

---

| 模块名称 | 角色/职责 | 入口脚本 | 启动方式 | 订阅主题 | 发布主题 | 关键依赖 | 配置文件 | 最后修改 | 健康检查 | 现网状态 | 备注 |
|---------|----------|---------|---------|---------|---------|---------|---------|---------|---------|---------|------|
| **asr_module** | 语音识别 | `/home/MRwang/smart_assistant/modules/asr/asr_module.py` | `bash scripts/start_asr.sh` | `sa/asr/cmd/#` | `sa/asr/text` | 讯飞ASR WebSocket、PyAudio、USB麦克风(plughw:1,0) | `config/asr.yml` | 2025-10-19 15:11 | ✅ 10秒心跳 | ⚠️ 音频设备冲突 | 需等待录音命令才启动 |
| **rules_module** | 规则引擎+Grok兜底 | `/home/MRwang/smart_assistant/modules/rules/rules_module.py` | `proxychains4 bash scripts/start_rules.sh` | `sa/asr/text` | `sa/tts/say`, `sa/chat/response` | Grok API(api.x.ai)、SOCKS5代理(127.0.0.1:1080) | `config/rules.yml`, `data/rules.json` | 2025-11-06 19:50 | ✅ 10秒心跳 | ✅ 运行中 | 已过滤唤醒词，避免双重回复 |
| **tts_module** | 语音合成 | `/home/MRwang/smart_assistant/modules/tts/tts_module.py` | `bash scripts/start_tts.sh` | `sa/tts/say` | `sa/tts/done` | 讯飞TTS x5超拟人、Edge-TTS(兜底)、HifiBerry DAC(plughw:0,0) | `config/tts.yml` | 2025-10-29 16:29 | ✅ 10秒心跳 | ✅ 运行中 | 主用讯飞x5，失败切换Edge-TTS |
| **wakeword_service** | 唤醒词检测 | `/home/MRwang/smart_assistant/modules/wakeword/wakeword_service.py` | `proxychains4 bash scripts/start_wakeword.sh` | `sa/asr/text` | `sa/tts/say` | Grok API、唤醒词列表(8条) | `config/wakeword.yml`, `config/grok_scenarios.yaml` | 2025-11-06 14:01 | ✅ 10秒心跳 | ✅ 运行中 | 检测唤醒词→Grok选模板→快速回复，5秒冷却 |
| **greeting_service** | 人脸问候 | `/home/MRwang/smart_assistant/modules/greeting/greeting_service.py` | `proxychains4 bash scripts/start_greeting.sh` | `sa/vision/face_detected` | `sa/tts/say` | Grok API、问候语模板(16条) | `config/greeting.yml`, `config/grok_scenarios.yaml` | 2025-11-04 01:16 | ✅ 10秒心跳 | ✅ 运行中 | 收到人脸识别→Grok选模板→问候 |
| **vision/scanner** | 人脸扫描 | `/home/MRwang/smart_assistant/modules/vision/scanner.py` | `bash scripts/start_vision_scanner.sh` | - | `sa/vision/face_detected` | IMX219 8MP摄像头、OpenCV、LBPH模型(`王总_v2.yml`) | `config/vision_config.yaml` | 2025-11-04 20:05 | ✅ 10秒心跳 | ✅ 运行中 | 30分钟扫描间隔(可调)，识别阈值60 |
| **face_recognizer** | 人脸识别核心 | `/home/MRwang/smart_assistant/modules/vision/recognizer/face_recognizer.py` | 被scanner调用 | - | - | OpenCV LBPH、训练数据(142张人脸) | 硬编码配置 | 2025-11-02 22:31 | N/A | ✅ 正常 | v2模型：包含眼镜、多光线训练 |

---

## 模块依赖关系图
```
┌─────────────┐
│   麦克风    │
└──────┬──────┘
       │
       ↓ (录音)
┌─────────────┐     ┌──────────────┐
│ asr_module  ├────→│ sa/asr/text  │
└─────────────┘     └──────┬───────┘
                           │
              ┌────────────┴────────────┐
              ↓                         ↓
    ┌─────────────────┐      ┌─────────────────┐
    │ wakeword_service│      │  rules_module   │
    │ (唤醒词检测)    │      │  (规则+Grok)    │
    └────────┬────────┘      └────────┬────────┘
             │                        │
             │                        │
             └────────┬───────────────┘
                      ↓
             ┌──────────────┐
             │ sa/tts/say   │
             └──────┬───────┘
                    ↓
             ┌─────────────┐
             │ tts_module  │
             └──────┬──────┘
                    ↓
             ┌─────────────┐
             │   音箱播报  │
             └─────────────┘

┌─────────────┐
│   摄像头    │
└──────┬──────┘
       │
       ↓ (30分钟扫描)
┌──────────────────┐     ┌────────────────────┐
│ vision/scanner   ├────→│ sa/vision/face_    │
│                  │     │    detected        │
└──────────────────┘     └──────┬─────────────┘
                                │
                                ↓
                      ┌─────────────────┐
                      │ greeting_service│
                      └────────┬────────┘
                               ↓
                      ┌──────────────┐
                      │ sa/tts/say   │
                      └──────────────┘
```

---

## 模块版本与哈希

| 模块 | Git哈希/版本 | 最后修改时间 | 备份文件 |
|------|------------|------------|---------|
| rules_module.py | TBD | 2025-11-06 19:50:43 | `rules_module.py.bak_1762429443` |
| wakeword_service.py | TBD | 2025-11-06 14:01:00 | 无备份（新创建） |
| tts_module.py | TBD | 2025-10-29 16:29:00 | `tts_module.py.bak_20251029_162925` |
| asr_module.py | TBD | 2025-10-19 15:11:00 | 无备份 |
| greeting_service.py | TBD | 2025-11-04 01:16:00 | 无备份 |
| scanner.py | TBD | 2025-11-04 20:05:00 | 无备份 |

**注**: Git哈希待补充（项目未初始化Git仓库）

---

## KPI与监控指标

| 模块 | 关键指标 | 目标值 | 实际值 | 监控方式 |
|------|---------|-------|-------|---------|
| ASR | 识别准确率 | >90% | TBD | 手动测试 |
| ASR | 响应延迟 | <1秒 | TBD | MQTT时间戳 |
| Wakeword | 唤醒响应 | <2秒 | ~1.5秒 | 终端日志 |
| TTS | 播报延迟 | <1秒 | <0.5秒 | MQTT时间戳 |
| Vision | 识别准确率 | >85% | ~90% | 手动测试 |
| Vision | 扫描间隔 | 30分钟 | 30分钟 | 配置文件 |
| Rules | Grok调用成功率 | >95% | TBD | 日志统计 |

---

## 模块状态总结

- ✅ **稳定运行**: TTS、Wakeword、Greeting、Vision Scanner
- ⚠️ **有问题待修**: ASR（音频设备冲突）
- 🔄 **最近修改**: Rules（唤醒词过滤，2025-11-06）
- 📝 **配置变更**: grok_scenarios.yaml（退出词模板，2025-11-06）

---

**证据来源**: claude.txt（2025-11-06 ps aux输出、文件时间戳）
