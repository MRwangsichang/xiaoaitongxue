# 当前稳定基线

**快照时间**: 2025-11-06 20:56  
**基线标识**: MVP-v1.0-wakeword-integrated  
**证据来源**: claude.txt（项目状态检查）

---

## 端口映射

| 服务 | 地址 | 状态 | 进程PID | 用途 | 证据 |
|------|------|------|--------|------|------|
| **MQTT Broker** | 127.0.0.1:1883 | ✅ LISTEN | 699(mosquitto) | 消息总线 | `sudo netstat -tlnp` |
| **MQTT Broker (IPv6)** | ::1:1883 | ✅ LISTEN | 699 | 消息总线 | 同上 |
| **SOCKS5 Proxy** | 127.0.0.1:1080 | ✅ 运行 | TBD | 闪连VPN，Grok API代理 | proxychains4配置 |
| **Web界面** | 127.0.0.1:5050 | ❌ 未启用 | - | 管理界面(未实现) | N/A |

**网络拓扑**:
```
[外网Grok API] ← SOCKS5(1080) ← proxychains4 ← Rules/Greeting/Wakeword
[本地MQTT] ← 1883 ← 所有模块
```

---

## Systemd服务状态

**当前未使用Systemd**，全部手动终端启动。

可用的Systemd模板（未启用）：
- `docs/sa-template.service.example`

---

## 硬件设备与参数

### 摄像头
| 参数 | 值 | 证据 |
|------|---|------|
| **型号** | IMX219 8MP | config/vision_config.yaml |
| **分辨率** | 640x480 | 同上 |
| **帧率** | 10 FPS | 同上 |
| **设备路径** | /dev/video0 | 推测（TBD：需验证） |
| **扫描间隔** | 30分钟 | config/vision_config.yaml `scan_interval: 1800` |
| **识别阈值** | 60 | config/vision_config.yaml `confidence_threshold: 60` |

### 麦克风
| 参数 | 值 | 证据 |
|------|---|------|
| **型号** | USB PnP Sound Device | `arecord -l` (card 1) |
| **设备** | plughw:1,0 | config/asr.yml `device: "plughw:1,0"` |
| **采样率** | 16000 Hz | config/asr.yml `rate: 16000` |
| **声道** | 单声道(1) | config/asr.yml `channels: 1` |
| **当前状态** | ⚠️ 冲突 | ASR启动失败，PulseAudio占用 |

### 音箱
| 参数 | 值 | 证据 |
|------|---|------|
| **型号** | HifiBerry DAC | TBD（需确认） |
| **设备** | plughw:0,0 | config/tts.yml `audio_device: "plughw:0,0"` |
| **采样率** | 16000 Hz | config/tts.yml `sample_rate: 16000` |
| **当前状态** | ✅ 正常 | TTS播报成功 |

---

## 关键配置参数

### ASR配置 (`config/asr.yml`)
```yaml
provider: cloud              # 讯飞云端ASR
device: "plughw:1,0"         # USB麦克风
rate: 16000                  # 采样率
channels: 1                  # 单声道
chunk_size: 1280             # 音频块大小
vad:
  enabled: true              # 语音活动检测
  aggressiveness: 2          # VAD灵敏度(1-3)
  min_speech_duration: 0.5   # 最短语音时长
  max_silence_duration: 1.5  # 最长静音时长
```

### TTS配置 (`config/tts.yml`)
```yaml
provider: xunfei_x5          # 主提供商：讯飞x5超拟人
fallback_provider: edge      # 兜底：Edge-TTS
audio_device: "plughw:0,0"   # HifiBerry DAC
sample_rate: 16000           # 采样率
volume: 1.0                  # 音量(0.0-1.0)
speed: 1.0                   # 语速
```

### Vision配置 (`config/vision_config.yaml`)
```yaml
camera:
  resolution: [640, 480]     # 分辨率
  framerate: 10              # 帧率
  warmup_time: 2             # 相机预热时间(秒)

scanner:
  scan_interval: 1800        # 扫描间隔(秒) = 30分钟
  frames_per_scan: 3         # 每次扫描帧数
  frame_delay: 0.5           # 帧间延迟(秒)

face_recognition:
  model_path: "data/faces/王总_v2.yml"  # 识别模型
  confidence_threshold: 60   # 识别阈值
  min_neighbors: 5           # 最小邻居数（降噪）
  scale_factor: 1.1          # 缩放因子
```

### Wakeword配置 (`config/wakeword.yml`)
```yaml
wakewords:                   # 唤醒词列表(8条)
  - "星辰在吗"
  - "在吗星辰"
  - "星辰星辰"
  - "星辰出来"
  - "你好星辰"
  - "星辰滚出来"
  - "屌毛星辰出来"
  - "老辰出来"

cooldown_seconds: 5          # 冷却时间(秒)
```

### Rules配置 (`data/rules.json`)
```json
{
  "rules": [
    {
      "id": "wake.voice",
      "enabled": false,      // 已禁用，由wakeword_service接管
      ...
    },
    {
      "id": "exit.hardstop", // 退出词规则
      "enabled": true,
      "any_keywords": ["退下", "别啰嗦了", "滚", "别废话", "静音", "别说话"]
    }
  ],
  "stories": []              // 已清空，避免干扰唤醒词
}
```

---

## 文件版本与哈希

### 核心脚本（以为准）
| 文件 | 绝对路径 | 修改时间 | 大小 | 哈希 | 备份 |
|------|---------|---------|-----|------|------|
| start_asr.sh | `/home/MRwang/smart_assistant/scripts/start_asr.sh` | TBD | TBD | TBD | start_asr.sh.before_env_fix |
| start_rules.sh | `.../scripts/start_rules.sh` | TBD | TBD | TBD | start_rules.sh.backup |
| start_tts.sh | `.../scripts/start_tts.sh` | TBD | TBD | TBD | - |
| start_wakeword.sh | `.../scripts/start_wakeword.sh` | 2025-11-06 | 549字节 | TBD | - |
| start_greeting.sh | `.../scripts/start_greeting.sh` | TBD | TBD | TBD | - |
| start_vision_scanner.sh | `.../scripts/start_vision_scanner.sh` | TBD | TBD | TBD | - |

**注**: 哈希值待补充（执行 `sha256sum <file>`）

### 模块代码（当前运行版本）
见 **docs/MODULES_MATRIX.md**

### 配置文件（当前生效）
| 文件 | 修改时间 | 备份 |
|------|---------|------|
| config/asr.yml | 2025-10-12 17:28 | asr.yml.bak_1760195705 |
| config/tts.yml | 2025-10-29 22:04 | - |
| config/rules.yml | 2025-10-13 13:55 | - |
| config/wakeword.yml | 2025-11-06 14:01 | - (新建) |
| config/greeting.yml | 2025-11-04 01:16 | - |
| config/vision_config.yaml | 2025-11-02 23:13 | - |
| config/grok_scenarios.yaml | 2025-11-06 01:22 | grok_scenarios.yaml.bak_1762363372 |
| data/rules.json | TBD | rules.json.bak_1762410609 |

---

## 人脸识别模型

| 模型 | 路径 | 训练数据 | 训练时间 | 准确率 |
|------|------|---------|---------|-------|
| **王总_v2.yml** | `/home/MRwang/smart_assistant/data/faces/王总_v2.yml` | 142张（包含眼镜、多光线） | 2025-11-02 | ~90% |
| 王总_v1.yml | 同上 | 92张（纯背景） | 2025-11-02 | ~60% (已弃用) |

**训练命令**（参考）：
```bash
bash scripts/sa_step_010_retrain_model.sh
```

---

## 日志轮转策略

- **日志目录**: `/home/MRwang/smart_assistant/logs/`
- **轮转周期**: 按日（.YYYYMMDD后缀）
- **保留天数**: 7天（配置在 `logging.rotate_days`）
- **日志文件**:
  - `asr.log`, `rules.log`, `tts.log`
  - `eventbus.<module>.log`
  - `health.<module>.log`
  - `smart_assistant_YYYY-MM-DD.log`（全局日志）

---

## 备份策略

### 自动备份
所有修改前自动备份：
```
<原文件>.bak_<unix_timestamp>
```

### 手动备份
```bash
# 备份整个项目
tar -czf ~/backups/smart_assistant_$(date +%s).tar.gz ~/smart_assistant

# 备份特定模块
cp -r backups/FINAL_ASR_LOCKED .  # 恢复ASR稳定版本
cp -r backups/grok_stable_20251028_020642 .
```

### 当前备份清单
- `backup_asr_20251019_014358.tar.gz`（ASR稳定版）
- `backups/FINAL_ASR_LOCKED/`（ASR锁定版本）
- `backups/grok_stable_20251028_020642/`（Grok配置稳定版）
- `backups/tts_stable_20251029_225218/`（TTS稳定版）

---

## 环境依赖

### Python版本
```
Python 3.11.2（Debian默认）
```

### 关键Python库
```
paho-mqtt==1.6.1          # MQTT客户端
asyncio-mqtt              # 异步MQTT（警告：已更名为aiomqtt）
pyaudio                   # 音频输入输出
opencv-python             # 计算机视觉
websocket-client          # 讯飞ASR WebSocket
pyyaml                    # YAML配置解析
aiohttp                   # Grok API调用
```

### 系统服务
```
mosquitto                 # MQTT Broker
pipewire / pulseaudio     # 音频服务（当前占用麦克风）
闪连VPN                   # SOCKS5代理
```

---

## 稳定性证明

### 最近运行记录
```
证据来源：claude.txt（2025-11-06 10:16启动，至20:56正常运行10.7小时）

进程运行时长：
- ASR: 10.7小时
- TTS: 10.7小时
- Rules: 10.7小时
- Greeting: 10.7小时
- Vision Scanner: 10.7小时（CPU 11.7%，正常）
- Wakeword: 10.6小时
```

### 已知稳定场景
- ✅ 唤醒词检测（手动MQTT测试）
- ✅ Grok对话（proxychains4正常）
- ✅ TTS播报（讯飞x5正常）
- ✅ 人脸识别（v2模型准确率高）
- ✅ 健康心跳（所有模块10秒间隔）

### 已知不稳定点
- ⚠️ ASR音频设备（PulseAudio冲突，无法录音）
- ⚠️ Grok API（依赖代理稳定性）
- ⚠️ 人脸识别（光线变化可能误触发）

---

**基线快照命令**（建议执行）：
```bash
cd ~/smart_assistant
git init
git add .
git commit -m "MVP v1.0 - Wakeword integrated baseline"
git tag -a v1.0-wakeword -m "2025-11-06 stable baseline"
```

---

**证据来源**: claude.txt（2025-11-06项目状态检查）、config文件、ps aux输出
