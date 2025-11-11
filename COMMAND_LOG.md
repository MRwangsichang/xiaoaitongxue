# 可复现命令日志

**更新时间**: 2025-11-06  
**用途**: 记录关键命令与期望输出，便于复现和验证

---

## 项目状态检查命令

### 检查运行中的模块
```bash
ps aux | grep -E "asr_module|rules_module|tts_module|greeting|scanner|wakeword" | grep -v grep
```

**期望输出**（2025-11-06 10:16）:
```
MRwang   3908  0.1  0.7 116268  28864 pts/5  Sl+ 10:16 0:02 python3 modules/asr/asr_module.py
MRwang   4007  0.1  0.9 122056  36128 pts/4  Sl+ 10:16 0:03 python3 modules/tts/tts_module.py
MRwang   4090  0.1  0.8 195012  34616 pts/6  Sl+ 10:16 0:03 python3 modules/rules/rules_module.py
MRwang   4195  0.1  0.8 121196  34360 pts/3  Sl+ 10:16 0:02 python3 modules/greeting/greeting_service.py
MRwang   4280 11.7 10.9 1091944 424584 pts/2 SLl+ 10:16 4:14 python3 modules/vision/scanner.py
MRwang   6244  0.1  0.8 121184  34500 pts/1  Sl+ 10:20 0:02 python3 modules/wakeword/wakeword_service.py
```

**证据来源**: claude.txt 行408-417

---

### 检查MQTT端口
```bash
sudo netstat -tlnp | grep 1883
```

**期望输出**:
```
tcp   0  0 127.0.0.1:1883  0.0.0.0:*  LISTEN  699/mosquitto
tcp6  0  0 ::1:1883        :::*       LISTEN  699/mosquitto
```

**证据来源**: claude.txt 行420-421

---

### 检查音频设备
```bash
arecord -l
```

**期望输出**:
```
**** List of CAPTURE Hardware Devices ****
card 1: Device [USB PnP Sound Device], device 0: USB Audio [USB Audio]
  Subdevices: 0/1
  Subdevice #0: subdevice #0
```

**证据来源**: 实际运行记录

---

### 检查项目结构
```bash
tree -L 2 -I '__pycache__|*.pyc' ~/smart_assistant
```

**期望输出**（主要目录）:
```
.
├── assets
├── backups (5个备份目录)
├── captures (人脸训练照片)
├── config (11个配置文件)
├── core (核心框架)
├── data (规则+人脸模型)
├── docs (4个文档)
├── logs (200+日志文件)
├── modules (9个模块目录)
├── scripts (50+脚本)
└── tests
```

**证据来源**: claude.txt 行1-326

---

## 模块启动命令

### 启动Rules模块
```bash
cd /home/MRwang/smart_assistant && proxychains4 bash scripts/start_rules.sh
```

**期望输出关键行**:
```
[HH:MM:SS] === Starting Rules Module ===
[YYYY-MM-DD HH:MM:SS] [INFO] [rules] === rules 模块启动 ===
[YYYY-MM-DD HH:MM:SS] [INFO] [rules] ✓ 加载 5 条规则
[YYYY-MM-DD HH:MM:SS] [INFO] [rules] ✓ 加载 0 个故事
[YYYY-MM-DD HH:MM:SS] [INFO] [eventbus.rules] 已连接到 MQTT broker: localhost:1883
[YYYY-MM-DD HH:MM:SS] [INFO] [rules] === rules 模块启动完成 ===
```

---

### 启动Wakeword服务
```bash
cd /home/MRwang/smart_assistant && proxychains4 bash scripts/start_wakeword.sh
```

**期望输出关键行**:
```
[HH:MM:SS] === 启动唤醒词服务 ===
[YYYY-MM-DD HH:MM:SS] [INFO] [wakeword] ✓ 加载GROK场景配置
[YYYY-MM-DD HH:MM:SS] [INFO] [wakeword] 加载唤醒词: ['星辰在吗', '在吗星辰', ...]
[YYYY-MM-DD HH:MM:SS] [INFO] [wakeword] === 唤醒词服务就绪 ===
```

---

## 配置文件查看

### 查看唤醒词配置
```bash
grep "wakewords:" -A 10 ~/smart_assistant/config/wakeword.yml
```

**期望输出**:
```yaml
wakewords:
  - "星辰在吗"
  - "在吗星辰"
  - "星辰星辰"
  - "星辰出来"
  - "你好星辰"
  - "星辰滚出来"
  - "屌毛星辰出来"
  - "老辰出来"

cooldown_seconds: 5
```

**证据来源**: claude.txt 行377-392

---

### 查看规则配置
```bash
cat ~/smart_assistant/data/rules.json | jq '{rules_count: (.rules | length), stories_count: (.stories | length)}'
```

**期望输出**:
```json
{
  "rules_count": 5,
  "stories_count": 0
}
```

**证据来源**: 实际修改记录（2025-11-06清空stories）

---

### 查看wake.voice规则状态
```bash
cat ~/smart_assistant/data/rules.json | jq '.rules[] | select(.id=="wake.voice") | {id, enabled, desc}'
```

**期望输出**:
```json
{
  "id": "wake.voice",
  "enabled": false,
  "desc": "语音唤醒（已禁用,由独立唤醒词服务接管）"
}
```

**证据来源**: 实际修改记录（2025-11-06禁用）

---

## 测试命令

### 手动测试唤醒词
```bash
mosquitto_pub -h localhost -t 'sa/asr/text' -m '{
  "id":"test-'$(date +%s)'",
  "ts":"'$(date -Iseconds)'",
  "source":"manual",
  "type":"asr.text",
  "payload":{"text":"星辰在吗","lang":"zh","partial":false},
  "meta":{"ver":"1.0"}
}'
```

**期望行为**:
1. 终端8 (Wakeword): 显示"检测到唤醒词: 星辰在吗"
2. 终端8: 显示"GROK回复: 我在"（或其他模板）
3. 终端5 (TTS): 播放"我在"
4. 音箱: 听到回复

---

### 监控MQTT消息
```bash
mosquitto_sub -v -t 'sa/#' | grep --line-buffered -E "asr/text|tts/say|face_detected"
```

**期望输出**（说"星辰在吗"时）:
```
sa/asr/text {"id":"...","payload":{"text":"星辰在吗",...}}
sa/tts/say {"id":"...","payload":{"text":"我在",...}}
```

---

### 测试Grok API连接
```bash
proxychains4 curl -s https://api.x.ai/v1/models | jq '.data[0].id'
```

**期望输出**:
```
"grok-beta"
```

---

### 测试麦克风录音
```bash
timeout 3 arecord -D plughw:1,0 -f cd -d 3 /tmp/test.wav && ls -lh /tmp/test.wav
```

**期望输出**:
```
-rw-r--r-- 1 MRwang MRwang 529K Nov  6 20:00 /tmp/test.wav
```

**当前状态**: ⚠️ 失败（PulseAudio占用）

---

### 测试音箱播放
```bash
speaker-test -D plughw:0,0 -c 2 -t wav -l 1
```

**期望输出**:
```
speaker-test 1.2.8
Playback device is plughw:0,0
...
Time per period = ...
```

---

## 备份与回滚命令

### 查看最近备份
```bash
ls -lt ~/smart_assistant/modules/rules/rules_module.py.bak_* | head -3
```

**期望输出**:
```
-rw-r--r-- 1 MRwang MRwang 6773 Nov  6 19:44 rules_module.py.bak_1762429443
-rw-r--r-- 1 MRwang MRwang 6773 Nov  6 19:38 rules_module.py.bak_1762429133
-rw-r--r-- 1 MRwang MRwang 6773 Nov  6 19:29 rules_module.py.bak_1762428599
```

**证据来源**: claude.txt 行424-426

---

### 回滚rules_module.py
```bash
LATEST=$(ls -t ~/smart_assistant/modules/rules/rules_module.py.bak_* | head -1)
cp "$LATEST" ~/smart_assistant/modules/rules/rules_module.py
echo "✓ 已回滚到: $LATEST"
```

---

### 回滚rules.json
```bash
LATEST=$(ls -t ~/smart_assistant/data/rules.json.bak_* | head -1)
cp "$LATEST" ~/smart_assistant/data/rules.json
echo "✓ 已回滚到: $LATEST"
```

---

### 创建项目备份
```bash
cd ~
tar -czf backups/smart_assistant_$(date +%Y%m%d_%H%M%S).tar.gz smart_assistant/
ls -lh backups/ | tail -1
```

---

## 调试命令

### 查看模块最近日志
```bash
tail -50 ~/smart_assistant/logs/rules.log
```

---

### 查看今天的全局日志
```bash
tail -100 ~/smart_assistant/logs/smart_assistant_$(date +%Y-%m-%d).log
```

---

### 检查Python语法
```bash
python3 -m py_compile ~/smart_assistant/modules/rules/rules_module.py && echo "✓ 语法正确" || echo "✗ 语法错误"
```

---

### 检查YAML配置格式
```bash
python3 -c "import yaml; yaml.safe_load(open('config/wakeword.yml')); print('✓ YAML格式正确')"
```

---

### 检查JSON配置格式
```bash
jq empty ~/smart_assistant/data/rules.json && echo "✓ JSON格式正确" || echo "✗ JSON格式错误"
```

---

## 人脸识别相关命令

### 查看训练模型
```bash
ls -lh ~/smart_assistant/data/faces/*.yml
```

**期望输出**:
```
-rw-r--r-- 1 MRwang MRwang  47K Nov  2 22:02 王总_v2.yml
-rw-r--r-- 1 MRwang MRwang  31K Nov  2 18:37 王总_v1.yml
```

---

### 查看训练照片数量
```bash
find ~/smart_assistant/data/faces/raw/王总 -name "*.jpg" | wc -l
```

**期望输出**:
```
142
```

---

### 测试人脸识别
```bash
cd ~/smart_assistant
python3 scripts/test_recognition_v2.py
```

**期望输出**:
```
✓ 模型加载成功
✓ 识别到: 王总 (置信度: 45.6)
```

---

## 系统资源监控

### 检查CPU使用率
```bash
top -b -n 1 | grep -E "python3|Cpu"
```

---

### 检查内存使用
```bash
free -h
```

---

### 检查磁盘空间
```bash
df -h /home
```

---

### 检查日志大小
```bash
du -sh ~/smart_assistant/logs/
```

---

## 网络相关命令

### 测试代理连接
```bash
curl -x socks5://127.0.0.1:1080 -I https://api.x.ai
```

**期望输出**:
```
HTTP/2 200
...
```

---

### 检查SSH连接
```bash
ssh MRwang@192.168.0.155 "echo '✓ SSH连接正常'"
```

---

## Git相关命令（未初始化）

### 初始化Git仓库
```bash
cd ~/smart_assistant
git init
git add .
git commit -m "MVP v1.0 baseline"
git tag -a v1.0 -m "2025-11-06 stable baseline"
```

---

### 查看文件哈希
```bash
sha256sum ~/smart_assistant/scripts/start_rules.sh
```

**注**: 当前未执行，待补充

---

**证据来源**: claude.txt（项目状态检查）、实际运行记录、代码实现
