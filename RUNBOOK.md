# 运维手册 (Runbook)

**版本**: v1.0  
**更新时间**: 2025-11-06  
**适用环境**: 树莓派4B (192.168.0.155)

---

## 前置依赖检查

### 系统要求
```bash
# 1. 检查Python版本
python3 --version
# 期望: Python 3.11.2

# 2. 检查MQTT服务
sudo systemctl status mosquitto
# 期望: active (running)

# 3. 检查代理服务
curl -x socks5://127.0.0.1:1080 https://api.x.ai/v1/models 2>&1 | head -5
# 期望: 返回JSON（或连接成功）

# 4. 检查音频设备
arecord -l
# 期望: card 1: Device [USB PnP Sound Device]
aplay -l
# 期望: card 0: sndrpihifiberry [snd_rpi_hifiberry_dac]

# 5. 检查摄像头
ls -l /dev/video0
# 期望: 存在设备文件

# 6. 检查用户组权限
groups $USER | grep -E "audio|video"
# 期望: 包含 audio 和 video
```

### Python依赖检查
```bash
cd ~/smart_assistant

# 检查关键库
python3 <<'PY'
import paho.mqtt.client as mqtt
import pyaudio
import cv2
import websocket
import yaml
import aiohttp
print("✓ 所有依赖库正常")
PY
```

### 环境变量检查
```bash
# 检查.env.local是否存在
ls -lh ~/smart_assistant/.env.local

# 检查关键变量（不显示值）
grep -E "^[A-Z_]+=" .env.local | sed 's/=.*/=***/'
# 期望: GROK_API_KEY、XUNFEI_*等变量
```

---

## 启动流程

### 标准启动顺序（7个终端）

#### 终端1: 工作终端（保持空闲）
```bash
cd ~/smart_assistant
# 用于执行临时命令和脚本
```

#### 终端2: Rules模块
```bash
cd ~/smart_assistant
proxychains4 bash scripts/start_rules.sh

# 期望输出:
# [HH:MM:SS] === Starting Rules Module ===
# [YYYY-MM-DD HH:MM:SS] [INFO] [rules] === rules 模块启动 ===
# [YYYY-MM-DD HH:MM:SS] [INFO] [rules] ✓ 加载 X 条规则
# [YYYY-MM-DD HH:MM:SS] [INFO] [rules] ✓ 加载 0 个故事
# [YYYY-MM-DD HH:MM:SS] [INFO] [rules] === rules 模块启动完成 ===
```

**验证**:
```bash
# 在终端1执行
ps aux | grep rules_module | grep -v grep
# 期望: 看到 python3 modules/rules/rules_module.py
```

#### 终端3: ASR模块
```bash
cd ~/smart_assistant
bash scripts/start_asr.sh

# 期望输出:
# [HH:MM:SS] === Starting ASR Module ===
# [YYYY-MM-DD HH:MM:SS] [INFO] [asr] === ASR Module Starting ===
# [YYYY-MM-DD HH:MM:SS] [INFO] [asr] Provider: cloud
# [YYYY-MM-DD HH:MM:SS] [INFO] [asr] ASR module ready
```

**验证**:
```bash
ps aux | grep asr_module | grep -v grep
```

**已知问题**: 如果看到 `OSError: [Errno -9999]`，说明音频设备被占用，见故障排除章节。

#### 终端4: MQTT监控（可选）
```bash
mosquitto_sub -v -t 'sa/#'

# 应该看到:
# sa/sys/health {..."module":"rules","status":"running"...}
# sa/sys/health {..."module":"asr","status":"running"...}
# （每10秒一次）
```

#### 终端5: TTS模块
```bash
cd ~/smart_assistant
bash scripts/start_tts.sh

# 期望输出:
# [HH:MM:SS] === Starting TTS Module ===
# [YYYY-MM-DD HH:MM:SS] [INFO] [tts] === TTS模块启动 ===
# [YYYY-MM-DD HH:MM:SS] [INFO] [tts] 主提供商: xunfei_x5
# [YYYY-MM-DD HH:MM:SS] [INFO] [tts] 兜底提供商: edge
# [YYYY-MM-DD HH:MM:SS] [INFO] [tts] === TTS模块就绪 ===
```

**验证**:
```bash
ps aux | grep tts_module | grep -v grep
```

#### 终端6: Greeting服务
```bash
cd ~/smart_assistant
proxychains4 bash scripts/start_greeting.sh

# 期望输出:
# [HH:MM:SS] === 启动问候服务 ===
# [YYYY-MM-DD HH:MM:SS] [INFO] [greeting] === 问候服务启动 ===
# [YYYY-MM-DD HH:MM:SS] [INFO] [greeting] ✓ GROK客户端初始化完成
# [YYYY-MM-DD HH:MM:SS] [INFO] [greeting] === 问候服务就绪 ===
```

**验证**:
```bash
ps aux | grep greeting_service | grep -v grep
```

#### 终端7: Vision Scanner
```bash
cd ~/smart_assistant
bash scripts/start_vision_scanner.sh

# 期望输出:
# [HH:MM:SS] === 启动视觉扫描服务 ===
# [YYYY-MM-DD HH:MM:SS] [INFO] [scanner] === 视觉扫描服务启动 ===
# [YYYY-MM-DD HH:MM:SS] [INFO] [scanner] ✓ 摄像头初始化成功
# [YYYY-MM-DD HH:MM:SS] [INFO] [scanner] 扫描间隔: 1800秒
# [YYYY-MM-DD HH:MM:SS] [INFO] [scanner] === 扫描服务就绪 ===
```

**验证**:
```bash
ps aux | grep scanner.py | grep -v grep
```

#### 终端8: Wakeword服务
```bash
cd ~/smart_assistant
proxychains4 bash scripts/start_wakeword.sh

# 期望输出:
# [HH:MM:SS] === 启动唤醒词服务 ===
# [YYYY-MM-DD HH:MM:SS] [INFO] [wakeword] === 唤醒词服务启动 ===
# [YYYY-MM-DD HH:MM:SS] [INFO] [wakeword] 加载唤醒词: ['星辰在吗', ...]
# [YYYY-MM-DD HH:MM:SS] [INFO] [wakeword] === 唤醒词服务就绪 ===
```

**验证**:
```bash
ps aux | grep wakeword_service | grep -v grep
```

---

## 停止流程

### 优雅停止（推荐）
在每个终端按 `Ctrl+C`，顺序：
```
1. 终端8 (Wakeword)
2. 终端7 (Vision)
3. 终端6 (Greeting)
4. 终端5 (TTS)
5. 终端3 (ASR)
6. 终端2 (Rules)
7. 终端4 (MQTT监控)
```

### 强制停止（紧急）
```bash
# 批量杀进程
pkill -f "asr_module|rules_module|tts_module|greeting_service|scanner|wakeword_service"

# 验证已停止
ps aux | grep -E "asr_module|rules_module|tts_module|greeting|scanner|wakeword" | grep -v grep
# 期望: 无输出
```

### 停止MQTT（非必要）
```bash
sudo systemctl stop mosquitto
```

---

## 健康检查

### 快速健康检查
```bash
cd ~/smart_assistant

# 1. 检查所有模块进程
echo "=== 运行中的模块 ==="
ps aux | grep -E "asr_module|rules_module|tts_module|greeting|scanner|wakeword" | grep -v grep | wc -l
# 期望: 6 (ASR、Rules、TTS、Greeting、Scanner、Wakeword)

# 2. 检查MQTT心跳（30秒采样）
echo "=== MQTT心跳检查 ==="
timeout 30 mosquitto_sub -t 'sa/sys/health' -C 6 | jq -r '.payload.module' | sort | uniq
# 期望: asr, greeting, rules, scanner, tts, wakeword

# 3. 检查日志错误
echo "=== 最近错误日志 ==="
tail -100 logs/*.log | grep -i error | tail -5
# 期望: 无或仅有历史错误
```

### 详细健康检查
```bash
# 创建健康检查脚本
cat > /tmp/health_check.sh <<'HEALTH_EOF'
#!/bin/bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

say "=== 智能助手健康检查 ==="
say ""

# 1. 进程检查
say "1. 进程状态"
MODULES=("asr_module" "rules_module" "tts_module" "greeting_service" "scanner.py" "wakeword_service")
for mod in "${MODULES[@]}"; do
    if pgrep -f "$mod" > /dev/null; then
        echo "  ✓ $mod 运行中"
    else
        echo "  ✗ $mod 未运行"
    fi
done

# 2. MQTT连接
say ""
say "2. MQTT Broker"
if sudo systemctl is-active --quiet mosquitto; then
    echo "  ✓ Mosquitto 运行中"
else
    echo "  ✗ Mosquitto 未运行"
fi

# 3. 端口监听
say ""
say "3. 端口状态"
if sudo netstat -tlnp | grep -q ":1883"; then
    echo "  ✓ MQTT端口 1883 监听中"
else
    echo "  ✗ MQTT端口 1883 未监听"
fi

# 4. 磁盘空间
say ""
say "4. 磁盘空间"
df -h /home | tail -1 | awk '{print "  使用率: "$5", 剩余: "$4}'

# 5. 日志大小
say ""
say "5. 日志大小"
du -sh logs/ 2>/dev/null | awk '{print "  总大小: "$1}'

# 6. 最近错误
say ""
say "6. 最近错误（最多5条）"
tail -200 logs/*.log 2>/dev/null | grep -i "error\|exception" | tail -5 || echo "  ✓ 无错误"

say ""
say "=== 检查完成 ==="
HEALTH_EOF

chmod +x /tmp/health_check.sh
bash /tmp/health_check.sh
```

---

## 功能验证

### 验证1: 唤醒词功能
```bash
# 手动发送唤醒词消息
mosquitto_pub -h localhost -t 'sa/asr/text' -m '{
  "id":"test-'$(date +%s)'",
  "ts":"'$(date -Iseconds)'",
  "source":"manual",
  "type":"asr.text",
  "payload":{"text":"星辰在吗","lang":"zh","partial":false},
  "meta":{"ver":"1.0"}
}'

# 期望: 
# 1. 终端8 (Wakeword) 显示: "检测到唤醒词: 星辰在吗"
# 2. 终端5 (TTS) 显示: "播放文本: 我在" (或其他15条模板)
# 3. 音箱播报: "我在"
```

### 验证2: 对话功能
```bash
# 发送普通对话
mosquitto_pub -h localhost -t 'sa/asr/text' -m '{
  "id":"test-'$(date +%s)'",
  "ts":"'$(date -Iseconds)'",
  "source":"manual",
  "type":"asr.text",
  "payload":{"text":"今天天气怎么样","lang":"zh","partial":false},
  "meta":{"ver":"1.0"}
}'

# 期望:
# 1. 终端2 (Rules) 显示: "触发GPT兜底" → "Grok回复: ..."
# 2. 终端5 (TTS) 播报Grok的回复
```

### 验证3: 人脸识别（需要走到摄像头前）
```bash
# 查看Scanner日志
tail -f logs/smart_assistant_$(date +%Y-%m-%d).log | grep -i "face\|识别"

# 期望:
# 1. 30分钟后自动扫描
# 2. 识别到人脸 → 发布 sa/vision/face_detected
# 3. 终端6 (Greeting) 触发 → 播报问候语
```

---

## 故障排除

### 问题1: ASR音频设备错误
**症状**:
```
OSError: [Errno -9999] Unanticipated host error
PulseAudio: Unable to create stream
```

**原因**: PulseAudio/PipeWire占用麦克风

**解决**:
```bash
# 方案A: 重启音频服务
systemctl --user restart pipewire pipewire-pulse

# 方案B: 杀掉占用进程
pkill -f pulseaudio
pkill -f pipewire

# 方案C: 手动测试麦克风
timeout 3 arecord -d 3 -f cd /tmp/test.wav
# 如果失败，重启树莓派
sudo reboot
```

### 问题2: Grok API调用失败
**症状**:
```
[ERROR] [rules] Grok API调用失败
ConnectionError: Cannot connect to host api.x.ai
```

**原因**: 代理失效

**解决**:
```bash
# 1. 检查代理
curl -x socks5://127.0.0.1:1080 https://api.x.ai/v1/models

# 2. 重启闪连VPN
# (具体步骤TBD，取决于你的VPN设置)

# 3. 测试proxychains
proxychains4 curl https://api.x.ai/v1/models
```

### 问题3: 模块启动后立即退出
**症状**: 终端显示启动日志后自动退出

**排查**:
```bash
# 1. 查看完整日志
tail -100 logs/<module>.log

# 2. 检查配置文件
python3 -c "import yaml; yaml.safe_load(open('config/<module>.yml'))"

# 3. 手动运行模块（看完整错误）
cd ~/smart_assistant
python3 modules/<module>/<module>_module.py
```

### 问题4: MQTT消息收不到
**症状**: 终端4监控看不到消息

**排查**:
```bash
# 1. 检查Mosquitto
sudo systemctl status mosquitto

# 2. 测试发布/订阅
# 终端A:
mosquitto_sub -t 'test' -v

# 终端B:
mosquitto_pub -t 'test' -m 'hello'

# 期望: 终端A显示 "test hello"
```

### 问题5: TTS无声音
**症状**: TTS模块显示播放成功，但无声音

**排查**:
```bash
# 1. 测试音箱
speaker-test -D plughw:0,0 -c 2 -t wav

# 2. 检查音量
amixer -c 0 sget 'Digital'
# 如果太低，调高音量
amixer -c 0 sset 'Digital' 80%

# 3. 测试TTS直接播放
cd ~/smart_assistant
python3 <<'PY'
from modules.tts.xunfei_x5_provider import XunfeiX5Provider
import asyncio

async def test():
    provider = XunfeiX5Provider()
    await provider.speak("测试音箱")

asyncio.run(test())
PY
```

---

## 回滚操作

### 回滚单个模块代码
```bash
# 查看备份
ls -lt modules/<module>/*.py.bak_* | head -5

# 回滚到最新备份
LATEST=$(ls -t modules/<module>/<file>.py.bak_* | head -1)
cp "$LATEST" modules/<module>/<file>.py

# 重启模块（在对应终端）
Ctrl+C
bash scripts/start_<module>.sh
```

### 回滚配置文件
```bash
# 查看备份
ls -lt config/*.bak_* data/*.bak_* | head -10

# 回滚rules.json
LATEST=$(ls -t data/rules.json.bak_* | head -1)
cp "$LATEST" data/rules.json

# 回滚grok场景配置
LATEST=$(ls -t config/grok_scenarios.yaml.bak_* | head -1)
cp "$LATEST" config/grok_scenarios.yaml
```

### 完整系统回滚
```bash
# 方案A: 恢复备份目录
cd ~/smart_assistant
cp -r backups/FINAL_ASR_LOCKED/* modules/asr/
cp -r backups/grok_stable_20251028_020642/* modules/llm/
cp -r backups/tts_stable_20251029_225218/* modules/tts/

# 方案B: 恢复压缩包
cd ~
tar -xzf backups/smart_assistant_<timestamp>.tar.gz

# 重启所有服务
```

---

## 日常维护

### 每日检查
```bash
# 运行健康检查
bash /tmp/health_check.sh

# 查看日志增长
du -sh ~/smart_assistant/logs/

# 清理旧日志（保留7天）
find ~/smart_assistant/logs/ -name "*.log.*" -mtime +7 -delete
```

### 每周备份
```bash
# 备份整个项目
cd ~
tar -czf backups/smart_assistant_$(date +%Y%m%d).tar.gz smart_assistant/

# 清理旧备份（保留30天）
find ~/backups/ -name "smart_assistant_*.tar.gz" -mtime +30 -delete
```

---

**证据来源**: claude.txt（启动命令与日志输出）、实际运行经验
