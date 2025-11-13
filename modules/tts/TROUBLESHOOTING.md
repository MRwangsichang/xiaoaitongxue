# TTS模块故障排查指南

## 常见问题

### 1. 无语音输出

**症状**：TTS模块运行正常，但听不到声音

**排查步骤**：

1. 检查系统音量
```bash
amixer sget Master
```
应该显示音量大于0%，且未静音（[on]）

2. 测试音频设备
```bash
speaker-test -t sine -f 1000 -l 1
```
应该能听到蜂鸣声

3. 检查音频文件是否生成
```bash
ls -lh /tmp/tts_cache/tts_*.mp3 | tail -5
```
应该能看到最新的音频文件

4. 手动播放音频测试
```bash
mpg123 -a plughw:0,0 /tmp/tts_cache/tts_xunfei_*.mp3
```

**解决方案**：
- 调整系统音量：`amixer sset Master 75%`
- 检查配置文件中的音频设备设置
- 确认音箱/耳机已连接

---

### 2. 讯飞鉴权失败

**症状**：日志显示 `HTTP 401` 或 `鉴权失败`

**可能原因**：
- API_KEY错误
- API_SECRET错误
- APPID错误
- 凭据未添加export

**排查步骤**：

1. 检查环境变量
```bash
grep "XF_TTS" ~/.env.local
```
应该显示三个变量，且都有 `export` 关键字

2. 验证凭据格式
```bash
source ~/.env.local
echo "APPID: $XF_TTS_APPID"
echo "API_KEY: $XF_TTS_API_KEY"
echo "API_SECRET: $XF_TTS_API_SECRET"
```
应该都有值，不为空

**解决方案**：
- 检查讯飞控制台，确认凭据正确
- 确保 `.env.local` 中所有变量有 `export`
- 重启TTS模块使新凭据生效

---

### 3. 频繁切换到Edge-TTS

**症状**：日志频繁显示 `切换到兜底Provider`

**可能原因**：
- 网络不稳定
- 讯飞服务异常
- 讯飞配额用尽

**排查步骤**：

1. 测试网络连接
```bash
ping -c 3 cbm01.cn-huabei-1.xf-yun.com
```

2. 检查讯飞控制台
- 登录讯飞控制台
- 查看API调用量和配额
- 确认服务状态

**解决方案**：
- 网络问题：等待网络恢复或调整timeout参数
- 配额用尽：联系讯飞续费或临时切换到Edge-TTS
- 服务异常：等待讯飞恢复

---

### 4. Edge-TTS音量太小

**症状**：Edge-TTS播报时声音很小

**解决方案**：

方案1：调整系统音量（推荐）
```bash
amixer sset Master 75%
```

方案2：调整Edge-TTS配置
编辑 `config/tts.yml`：
```yaml
edge:
  volume: +100%  # 已经是最大值
```

如果+100%仍然不够：
- 检查音箱/耳机音量
- 考虑外接功放
- 调整系统音频增益

---

### 5. TTS模块无法启动

**症状**：启动时报错退出

**常见错误及解决方案**：

错误1：`ModuleNotFoundError: No module named 'edge_tts'`
```bash
pip3 install edge-tts --break-system-packages
```

错误2：`ValueError: Missing XF_TTS credentials`
```bash
# 确保 .env.local 存在且有export
cat ~/.env.local | grep "export XF_TTS"
```

错误3：`KeyError: 'ws_url'`
```bash
# 检查 config/tts.yml 是否有 ws_url 配置
grep "ws_url" ~/smart_assistant/config/tts.yml
```

---

### 6. 音频播放卡顿

**症状**：语音播放断断续续

**可能原因**：
- CPU占用过高
- 内存不足
- 音频缓存目录问题

**排查步骤**：

1. 检查系统资源
```bash
top
```

2. 清理音频缓存
```bash
rm -f /tmp/tts_cache/tts_*
```

3. 重启TTS模块

---

### 7. 如何完全重置TTS模块

如果遇到无法解决的问题，可以完全重置：
```bash
# 1. 停止TTS（终端5按Ctrl+C）

# 2. 使用稳定备份恢复
bash ~/smart_assistant/backups/tts_stable_20251029_225218/RESTORE.sh

# 3. 清理缓存
rm -rf /tmp/tts_cache/*

# 4. 重新启动TTS
cd ~/smart_assistant && source .env.local && python3 modules/tts/tts_module.py
```

---

## 获取帮助

如果以上方法无法解决问题：

1. 查看完整日志（终端5）
2. 检查MQTT消息流（终端4）
3. 查看验收报告中的测试用例

文档位置：
- 验收报告：`~/smart_assistant/backups/tts_stable_20251029_225218/ACCEPTANCE_REPORT.txt`
- 配置文件：`~/smart_assistant/config/tts.yml`
- 环境变量：`~/smart_assistant/.env.local`

---

最后更新：2025-10-29
