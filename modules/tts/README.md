# TTS模块使用说明

## 概述

TTS（Text-to-Speech）模块负责将文本转换为语音并播放。

**功能特性**：
- 主Provider：讯飞x5超拟人TTS（聆飞逸男声）
- 兜底Provider：Edge-TTS（云希男声）
- 自动切换：讯飞失败时自动使用Edge-TTS
- MQTT通信：订阅 `sa/tts/say` 主题接收播报请求

---

## 快速启动

### 1. 启动TTS模块
```bash
cd ~/smart_assistant && source .env.local && python3 modules/tts/tts_module.py
```

**预期输出**：
```
INFO | tts | === TTS Module Starting ===
INFO | tts | 讯飞TTS初始化完成
INFO | tts | 主Provider: 讯飞标准TTS
INFO | tts | Edge-TTS初始化完成，音色: zh-CN-YunxiNeural
INFO | tts | 兜底Provider: Edge-TTS
INFO | tts | ✓ TTS module ready
INFO | tts | 已连接到 MQTT broker: localhost:1883
INFO | tts | 订阅主题: sa/tts/say
```

### 2. 测试播报
```bash
mosquitto_pub -h localhost -t 'sa/tts/say' -m '{"id":"test-001","ts":"'$(date -Iseconds)'","source":"manual","type":"tts.say","payload":{"text":"你好，我是智能助手"},"meta":{"ver":"1.0"}}'
```

---

## MQTT消息格式

### 订阅主题
- `sa/tts/say` - 接收播报请求

### 消息格式
```json
{
  "id": "unique-message-id",
  "ts": "2025-10-29T23:00:00+08:00",
  "source": "rules",
  "type": "tts.say",
  "payload": {
    "text": "要播报的文本内容"
  },
  "meta": {
    "ver": "1.0"
  }
}
```

**字段说明**：
- `id`: 唯一消息ID
- `ts`: ISO 8601格式时间戳
- `source`: 消息来源（rules/manual/asr等）
- `type`: 固定值 `tts.say`
- `payload.text`: 要播报的文本（必填）
- `meta.ver`: 协议版本

---

## 配置说明

配置文件：`config/tts.yml`

**基本配置**：
```yaml
provider: xunfei          # 主Provider（xunfei/edge）
audio:
  device: plughw:0,0      # 音频输出设备
  cache_dir: /tmp/tts_cache  # 音频缓存目录
```

**讯飞x5配置**：
```yaml
xunfei:
  ws_url: wss://cbm01.cn-huabei-1.xf-yun.com/v1/private/mcd9m97e6
  aue: lame               # 音频编码格式
  timeout: 10             # 超时时间（秒）
```

**Edge-TTS配置**：
```yaml
edge:
  voice: zh-CN-YunxiNeural  # 音色（男声）
  rate: +0%                 # 语速调整
  volume: +100%             # 音量调整（最大）
```

**环境变量**（`.env.local`）：
```bash
export XF_TTS_APPID=your_app_id
export XF_TTS_API_KEY=your_api_key
export XF_TTS_API_SECRET=your_api_secret
```

---

## 日志说明

**正常日志**：
```
INFO | tts | 收到TTS请求: 你好
INFO | tts | ✓ 讯飞音频已保存: /tmp/tts_cache/tts_xunfei_*.mp3
INFO | tts | ✓ 播放完成
```

**兜底切换日志**：
```
WARNING | tts | 主Provider合成失败: HTTP 401
INFO | tts | 切换到兜底Provider（Edge-TTS）
INFO | tts | Edge-TTS开始合成...
INFO | tts | ✓ Edge-TTS音频已保存: /tmp/tts_cache/tts_edge_*.mp3
INFO | tts | ✓ 播放完成
```

---

## 常用操作

### 切换音色

修改 `config/tts.yml`：
```yaml
edge:
  voice: zh-CN-XiaoxiaoNeural  # 女声（晓晓）
```

重启TTS模块生效。

### 调整音量

**系统音量**（推荐）：
```bash
amixer sset Master 75%
```

**Edge-TTS音量**：
修改 `config/tts.yml`：
```yaml
edge:
  volume: +50%  # 范围：-100% 到 +100%
```

### 调整语速

修改 `config/tts.yml`：
```yaml
edge:
  rate: +10%  # 范围：-100% 到 +100%
```

---

## 备份与恢复

### 查看备份
```bash
ls -lh ~/smart_assistant/backups/tts_stable_*/
```

### 恢复备份
```bash
bash ~/smart_assistant/backups/tts_stable_20251029_225218/RESTORE.sh
```

恢复后需重启TTS模块。

---

## 维护建议

1. **定期检查**：
   - 讯飞API配额使用情况
   - 音频缓存目录大小（/tmp/tts_cache）

2. **日志监控**：
   - 注意兜底切换频率（频繁切换说明讯飞不稳定）
   - 关注错误日志

3. **性能优化**：
   - 定期清理缓存：`rm -f /tmp/tts_cache/tts_*`
   - 网络不稳定时考虑调整timeout参数

---

版本：tts_stable_20251029_225218  
最后更新：2025-10-29
