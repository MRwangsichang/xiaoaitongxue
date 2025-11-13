【模块名称】
核心框架与配置管理（窗口1）

【完成时间】
20251011_151852

【实现功能】
- 创建项目命名空间：/home/MRwang/smart_assistant/{core,modules,config,data,logs,tests,docs,scripts}
- 配置中心：/home/MRwang/smart_assistant/config/app.json（JSON）
- 运行脚本：/home/MRwang/smart_assistant/scripts/run_core_smoke.sh（内置 PYTHONPATH）
- 核心程序：/home/MRwang/smart_assistant/core/main.py（--smoke 冒烟验证）

【技术路径】
- 使用的库/API：Python3 标准库（argparse、json）
- 目录规范：/home/MRwang/smart_assistant 下分层（core/modules/config/data/logs/tests/docs/scripts）
- 配置加载：环境变量 SA_CONFIG 指向 /home/MRwang/smart_assistant/config/app.json
- 运行环境：通过脚本设置 PYTHONPATH=/home/MRwang/smart_assistant

【文件清单】
- 配置：/home/MRwang/smart_assistant/config/app.json
- 核心：/home/MRwang/smart_assistant/core/main.py
- 运行脚本：/home/MRwang/smart_assistant/scripts/run_core_smoke.sh
- 日志目录：/home/MRwang/smart_assistant/logs
- 数据目录：/home/MRwang/smart_assistant/data

【接口说明】
- 启动（冒烟）：bash /home/MRwang/smart_assistant/scripts/run_core_smoke.sh
- 预期输出：SMOKE OK
- 退出：进程结束即退出（无常驻）

【测试结果】
- 命令：bash /home/MRwang/smart_assistant/scripts/run_core_smoke.sh
- 结果：SMOKE OK（已通过）

【已知问题】
- 当前仅最小可运行骨架；事件总线/日志封装在下一子步骤落盘

【下一步建议】
- 推荐的下一个模块：窗口2《讯飞 ASR 实时识别（API接入）》
- 集成注意事项：
  1) 保持 PYTHONPATH 指向 /home/MRwang/smart_assistant
  2) 新模块写到 /home/MRwang/smart_assistant/modules/ 下，配置写入 /home/MRwang/smart_assistant/config/，日志走 /home/MRwang/smart_assistant/logs/
  3) 资源锁建议：/run/lock/sa_*.lock（后续统一加入）
