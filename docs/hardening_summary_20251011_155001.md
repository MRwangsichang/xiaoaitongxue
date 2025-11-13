# 旧框架硬化总结
- 时间：20251011_155001
- 掩码服务：greet.service, cam.service, camfix.service, smart_speaker.service
- 备份目录：/etc/systemd/system.disabled/
- 掩码位置：/etc/systemd/system/<service> -> /dev/null
- 验证：
✅ 新目录存在
✅ logs/data 可写
✅ 已停止：camfix.service
✅ 禁自启：camfix.service
✅ 已停止：cam.service
✅ 禁自启：cam.service
✅ 已停止：greet.service
✅ 禁自启：greet.service
✅ 已停止：smart_speaker.service
✅ 禁自启：smart_speaker.service
✅ 已停止：vncserver-virtuald.service
✅ 禁自启：vncserver-virtuald.service
✅ 已停止：greet.service
✅ 禁自启：greet.service
✅ 已停止：cam.service
✅ 禁自启：cam.service
✅ 已停止：camfix.service
✅ 禁自启：camfix.service
✅ 已停止：smart_speaker.service
✅ 禁自启：smart_speaker.service
✅ 端口空闲：5050
✅ 端口空闲：8554
✅ 端口空闲：5000
✅ 端口空闲：8000
✅ 端口空闲：3000
✅ 端口空闲：1883
✅ 摄像头空闲
ISOLATION CHECK: PASS ✅

## 回滚方式
bash /home/MRwang/smart_assistant/scripts/rollback_legacy_units.sh
