"""
配置加载器测试
"""
import sys
from pathlib import Path

# 添加项目根到路径
ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(ROOT))

from core.config_loader import ConfigLoader, ConfigError


def test_load_success():
    """测试正常加载"""
    loader = ConfigLoader()
    config = loader.load()
    
    assert "mqtt" in config
    assert config["mqtt"]["broker"] == "localhost"
    assert config["mqtt"]["port"] == 1883
    assert config["logging"]["level"] == "INFO"
    print("✓ test_load_success")


def test_missing_file():
    """测试文件不存在"""
    loader = ConfigLoader("/tmp/nonexistent.yml")
    try:
        loader.load()
        assert False, "应该抛出ConfigError"
    except ConfigError as e:
        assert "不存在" in str(e)
        print("✓ test_missing_file")


def test_env_override():
    """测试环境变量覆盖"""
    import os
    os.environ["SA_MQTT_PORT"] = "9999"
    
    loader = ConfigLoader()
    config = loader.load()
    
    assert config["mqtt"]["port"] == 9999
    print("✓ test_env_override")
    
    # 清理
    del os.environ["SA_MQTT_PORT"]


if __name__ == "__main__":
    print("=== 配置加载器测试 ===")
    test_load_success()
    test_missing_file()
    test_env_override()
    print("=== 所有测试通过 ===")
