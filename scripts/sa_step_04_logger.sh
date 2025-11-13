#!/usr/bin/env bash
set -euo pipefail
DRY_RUN="${DRY_RUN:-1}"

say(){ printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }
ok(){ printf "✓ %s\n" "$*"; }

ROOT="/home/MRwang/smart_assistant"
echo "=== CREATING LOGGER ==="

if [ "$DRY_RUN" = "1" ]; then
  say "DRY-RUN: Would create core/logger.py"
  say "DRY-RUN: Would create tests/test_logger.py"
  exit 0
fi

# 1. 创建日志器
say "Creating core/logger.py..."
cat > "$ROOT/core/logger.py" <<'PYCODE'
"""
结构化日志器 - 按日滚动、带建议动作
"""
import logging
import sys
from datetime import datetime
from logging.handlers import TimedRotatingFileHandler
from pathlib import Path
from typing import Optional


class SuggestedActionFilter(logging.Filter):
    """为ERROR级别日志添加建议动作字段"""
    
    SUGGESTIONS = {
        "配置": "检查 config/app.yml 是否存在且格式正确",
        "MQTT": "确认 mosquitto 服务运行: sudo systemctl status mosquitto",
        "连接": "检查网络连接或服务是否启动",
        "权限": "检查文件/目录权限: ls -la",
        "设备": "检查硬件连接（摄像头/麦克风/红外）: ls /dev/video* /dev/snd/*",
    }
    
    def filter(self, record):
        """为ERROR日志添加建议动作"""
        if record.levelno >= logging.ERROR:
            # 根据消息内容匹配建议
            suggestion = "检查日志上下文确定原因"
            for keyword, action in self.SUGGESTIONS.items():
                if keyword in record.getMessage():
                    suggestion = action
                    break
            record.suggestion = f" [建议: {suggestion}]"
        else:
            record.suggestion = ""
        return True


class StructuredFormatter(logging.Formatter):
    """结构化格式化器"""
    
    def format(self, record):
        # 时间戳
        timestamp = datetime.fromtimestamp(record.created).strftime('%Y-%m-%d %H:%M:%S')
        
        # 级别（对齐）
        level = record.levelname.ljust(7)
        
        # 模块名（缩短路径）
        module = record.name
        if '.' in module:
            module = module.split('.')[-1]
        module = module[:15].ljust(15)
        
        # 消息
        message = record.getMessage()
        
        # 建议动作（仅ERROR）
        suggestion = getattr(record, 'suggestion', '')
        
        # 异常信息
        exc_text = ""
        if record.exc_info:
            exc_text = "\n" + self.formatException(record.exc_info)
        
        return f"{timestamp} | {level} | {module} | {message}{suggestion}{exc_text}"


def setup_logger(
    name: str,
    log_dir: str = "logs",
    level: str = "INFO",
    rotate_days: int = 7,
    console: bool = True
) -> logging.Logger:
    """
    设置日志器
    
    Args:
        name: 日志器名称（通常为模块名）
        log_dir: 日志目录
        level: 日志级别
        rotate_days: 日志保留天数
        console: 是否同时输出到控制台
        
    Returns:
        配置好的日志器
    """
    # 创建日志器
    logger = logging.getLogger(name)
    logger.setLevel(getattr(logging, level.upper()))
    logger.handlers.clear()  # 清除已有handler
    
    # 添加建议动作过滤器
    logger.addFilter(SuggestedActionFilter())
    
    # 格式化器
    formatter = StructuredFormatter()
    
    # 文件处理器（按日滚动）
    log_path = Path(log_dir)
    log_path.mkdir(parents=True, exist_ok=True)
    
    file_handler = TimedRotatingFileHandler(
        filename=log_path / f"{name}.log",
        when='midnight',
        interval=1,
        backupCount=rotate_days,
        encoding='utf-8'
    )
    file_handler.setFormatter(formatter)
    file_handler.suffix = "%Y%m%d"  # 备份文件后缀
    logger.addHandler(file_handler)
    
    # 控制台处理器
    if console:
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setFormatter(formatter)
        logger.addHandler(console_handler)
    
    return logger


def get_logger(name: str) -> logging.Logger:
    """
    获取已配置的日志器（如果不存在则创建）
    
    Args:
        name: 日志器名称
        
    Returns:
        日志器实例
    """
    logger = logging.getLogger(name)
    if not logger.handlers:
        # 使用默认配置
        setup_logger(name)
    return logger


if __name__ == "__main__":
    # 自检模式
    print("=== 日志器自检 ===")
    
    # 创建测试日志器
    logger = setup_logger("test_logger", log_dir="/tmp/sa_logs_test", level="DEBUG")
    
    # 测试各级别
    logger.debug("这是DEBUG消息（调试用）")
    logger.info("这是INFO消息（正常运行）")
    logger.warning("这是WARNING消息（需要注意）")
    logger.error("配置文件加载失败")
    logger.error("MQTT连接超时")
    
    # 测试异常
    try:
        1 / 0
    except Exception as e:
        logger.error("运算错误", exc_info=True)
    
    print("\n✓ 日志已写入: /tmp/sa_logs_test/test_logger.log")
    print("✓ 查看日志: cat /tmp/sa_logs_test/test_logger.log")
PYCODE
ok "core/logger.py"

# 2. 创建测试用例
say "Creating tests/test_logger.py..."
cat > "$ROOT/tests/test_logger.py" <<'PYTEST'
"""
日志器测试
"""
import sys
import shutil
from pathlib import Path

# 添加项目根到路径
ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(ROOT))

from core.logger import setup_logger, get_logger


def test_basic_logging():
    """测试基本日志功能"""
    log_dir = "/tmp/sa_test_logs"
    Path(log_dir).mkdir(parents=True, exist_ok=True)
    
    logger = setup_logger("test_basic", log_dir=log_dir, console=False)
    
    logger.info("测试消息1")
    logger.warning("测试消息2")
    logger.error("配置错误消息")  # 应该有建议动作
    
    # 检查日志文件存在
    log_file = Path(log_dir) / "test_basic.log"
    assert log_file.exists(), "日志文件不存在"
    
    # 检查内容
    content = log_file.read_text()
    assert "测试消息1" in content
    assert "建议" in content  # ERROR应该有建议
    
    print("✓ test_basic_logging")
    
    # 清理
    shutil.rmtree(log_dir)


def test_get_logger():
    """测试get_logger"""
    logger1 = get_logger("module_a")
    logger2 = get_logger("module_a")
    
    assert logger1 is logger2, "同名日志器应该是同一实例"
    print("✓ test_get_logger")


if __name__ == "__main__":
    print("=== 日志器测试 ===")
    test_basic_logging()
    test_get_logger()
    print("=== 所有测试通过 ===")
PYTEST
ok "tests/test_logger.py"

echo ""
echo "=== LOGGER CREATED ==="
