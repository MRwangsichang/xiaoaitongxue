#!/usr/bin/env bash
set -euo pipefail
DRY_RUN="${DRY_RUN:-1}"

say(){ printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
cd "$ROOT"

if [ "$DRY_RUN" = "1" ]; then
  say "DRY-RUN: 仅打印将执行的操作"
  say "[DRY] 将创建: core/logger.py"
  say "[DRY] 将创建: logs/ 目录"
  say "[✓] 预演完成"
  exit 0
fi

say "创建日志模块: core/logger.py"
mkdir -p core
mkdir -p logs

cat > core/logger.py <<'PY'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
结构化日志模块
- 统一日志格式：[时间] [级别] [模块] 消息
- 按日期自动切分日志文件
- 支持DEBUG/INFO/WARN/ERROR级别
- 同时输出到终端和文件
"""
import os
import sys
import logging
from datetime import datetime
from pathlib import Path

# 项目根目录
PROJECT_ROOT = Path(__file__).parent.parent
LOGS_DIR = PROJECT_ROOT / "logs"

class SmartAssistantLogger:
    """智能助手日志器"""
    
    def __init__(self, name="smart_assistant", level=logging.INFO):
        """
        初始化日志器
        
        Args:
            name: 日志器名称（通常是模块名）
            level: 日志级别（DEBUG/INFO/WARNING/ERROR）
        """
        self.name = name
        self.logger = logging.getLogger(name)
        self.logger.setLevel(level)
        
        # 避免重复添加handler
        if self.logger.handlers:
            return
        
        # 确保日志目录存在
        LOGS_DIR.mkdir(parents=True, exist_ok=True)
        
        # 日志格式
        formatter = logging.Formatter(
            '[%(asctime)s] [%(levelname)s] [%(name)s] %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        
        # 文件Handler - 按日期切分
        log_file = LOGS_DIR / f"smart_assistant_{datetime.now().strftime('%Y-%m-%d')}.log"
        file_handler = logging.FileHandler(log_file, encoding='utf-8')
        file_handler.setLevel(level)
        file_handler.setFormatter(formatter)
        self.logger.addHandler(file_handler)
        
        # 终端Handler
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setLevel(level)
        console_handler.setFormatter(formatter)
        self.logger.addHandler(console_handler)
        
        self.log_file = log_file
    
    def debug(self, msg, *args, **kwargs):
        """调试信息"""
        self.logger.debug(msg, *args, **kwargs)
    
    def info(self, msg, *args, **kwargs):
        """一般信息"""
        self.logger.info(msg, *args, **kwargs)
    
    def warning(self, msg, *args, **kwargs):
        """警告信息"""
        self.logger.warning(msg, *args, **kwargs)
    
    def warn(self, msg, *args, **kwargs):
        """警告信息（别名）"""
        self.logger.warning(msg, *args, **kwargs)
    
    def error(self, msg, *args, **kwargs):
        """错误信息"""
        self.logger.error(msg, *args, **kwargs)
    
    def get_log_file(self):
        """获取当前日志文件路径"""
        return str(self.log_file)


def get_logger(name="smart_assistant", level=logging.INFO):
    """
    获取日志器实例（推荐使用此函数）
    
    Args:
        name: 模块名称
        level: 日志级别
        
    Returns:
        SmartAssistantLogger实例
    """
    return SmartAssistantLogger(name, level)


if __name__ == "__main__":
    # Smoke测试
    print(f"[{datetime.now().strftime('%H:%M:%S')}] === 日志模块Smoke测试 ===")
    
    logger = get_logger("test_module", level=logging.DEBUG)
    
    print(f"[{datetime.now().strftime('%H:%M:%S')}] 测试DEBUG级别...")
    logger.debug("这是一条DEBUG消息")
    
    print(f"[{datetime.now().strftime('%H:%M:%S')}] 测试INFO级别...")
    logger.info("这是一条INFO消息")
    
    print(f"[{datetime.now().strftime('%H:%M:%S')}] 测试WARN级别...")
    logger.warn("这是一条WARN消息")
    
    print(f"[{datetime.now().strftime('%H:%M:%S')}] 测试ERROR级别...")
    logger.error("这是一条ERROR消息")
    
    print(f"[{datetime.now().strftime('%H:%M:%S')}] [✓] 日志写入成功")
    print(f"[{datetime.now().strftime('%H:%M:%S')}] 日志文件: {logger.get_log_file()}")
PY

chmod +x core/logger.py

# 创建__init__.py使core成为包
touch core/__init__.py

say "[✓] 日志模块创建完成"
