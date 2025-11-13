【模块名称】
旧框架隔离（窗口0）

【完成时间】
20251011_145350

【实现功能】
- 旧服务停用并禁自启
- 摄像头/端口资源释放
- 新命名空间建立：/home/MRwang/smart_assistant
- 快照保全旧代码/配置/数据（可回滚）

【技术路径】
- 使用的库/API：rsync、systemd（systemctl）、lsof/ss
- 核心算法：基于盘点报告(paths_raw.txt)归类快照；白名单跳过系统网络/SSH服务
- 配置参数：DRY_RUN 可切换；服务关键词 KEY/SAFE_SKIP

【文件清单】
- 快照：/home/MRwang/smart_assistant/_legacy_snapshots/legacy_20251011_142957
- 盘点报告：/home/MRwang/smart_assistant/reports/inventory_deep_20251011_141559
- 校验脚本：/home/MRwang/sa_verify_isolation.sh
- 候选服务清单：/home/MRwang/sa_step3_candidates.txt
- 新目录：/home/MRwang/smart_assistant/{core,modules,config,data,logs,tests,scripts}

【接口说明】
- 无（本模块为环境隔离与资源治理）

【测试结果】
- 校验结论：PASS
- 关键端口：5050/8554/5000/8000/3000/1883 均空闲
- 摄像头：空闲
- 已停/禁用服务：
- camfix.service
- cam.service
- display-manager.service
- greet.service
- rpi-display-backlight.service
- smart_speaker.service
- systemd-firstboot.service
- user-runtime-dir@.service
- vncserver-virtuald.service

【已知问题】
- （无）

【下一步建议】
- 推荐模块：窗口1《核心框架与配置管理》
- 集成注意：仍需确保新服务使用 /run/lock/sa_*.lock 单实例与资源锁
