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
