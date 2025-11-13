"""
配置加载器 - 支持YAML、环境变量覆盖、Schema校验
"""
import os
import sys
from pathlib import Path
from typing import Any, Dict, Optional
import yaml


class ConfigError(Exception):
    """配置错误异常"""
    pass


class ConfigLoader:
    """配置加载器"""
    
    # Schema定义：必填项、类型、默认值
    SCHEMA = {
        "mqtt": {
            "required": True,
            "fields": {
                "broker": {"type": str, "required": True},
                "port": {"type": int, "default": 1883},
                "qos": {"type": int, "default": 1},
                "keepalive": {"type": int, "default": 60},
            }
        },
        "logging": {
            "required": True,
            "fields": {
                "level": {"type": str, "default": "INFO"},
                "dir": {"type": str, "default": "logs"},
                "rotate_days": {"type": int, "default": 7},
            }
        },
        "system": {
            "required": True,
            "fields": {
                "project_root": {"type": str, "required": True},
                "service_prefix": {"type": str, "default": "sa"},
            }
        },
    }
    
    def __init__(self, config_path: Optional[str] = None):
        """
        初始化配置加载器
        
        Args:
            config_path: 配置文件路径，默认为 config/app.yml
        """
        if config_path is None:
            # 自动推断项目根目录
            current = Path(__file__).parent.parent
            config_path = current / "config" / "app.yml"
        
        self.config_path = Path(config_path)
        self.config: Dict[str, Any] = {}
        
    def load(self) -> Dict[str, Any]:
        """
        加载并校验配置
        
        Returns:
            配置字典
            
        Raises:
            ConfigError: 配置文件不存在、格式错误、校验失败
        """
        # 1. 检查文件存在性
        if not self.config_path.exists():
            raise ConfigError(f"配置文件不存在: {self.config_path}")
        
        # 2. 加载YAML
        try:
            with open(self.config_path, 'r', encoding='utf-8') as f:
                self.config = yaml.safe_load(f) or {}
        except yaml.YAMLError as e:
            raise ConfigError(f"YAML解析失败: {e}")
        
        # 3. 环境变量覆盖（格式：SA_MQTT_BROKER=localhost）
        self._apply_env_overrides()
        
        # 4. Schema校验
        self._validate_schema()
        
        # 5. 应用默认值
        self._apply_defaults()
        
        return self.config
    
    def _apply_env_overrides(self):
        """应用环境变量覆盖（SA_<SECTION>_<KEY>=value）"""
        prefix = "SA_"
        for key, value in os.environ.items():
            if not key.startswith(prefix):
                continue
            
            # SA_MQTT_BROKER -> ['mqtt', 'broker']
            parts = key[len(prefix):].lower().split('_', 1)
            if len(parts) != 2:
                continue
            
            section, field = parts
            if section not in self.config:
                self.config[section] = {}
            
            # 类型转换（简单处理）
            if value.isdigit():
                self.config[section][field] = int(value)
            elif value.lower() in ('true', 'false'):
                self.config[section][field] = value.lower() == 'true'
            else:
                self.config[section][field] = value
    
    def _validate_schema(self):
        """Schema校验：检查必填项和类型"""
        errors = []
        
        for section, section_schema in self.SCHEMA.items():
            # 检查必填section
            if section_schema.get("required") and section not in self.config:
                errors.append(f"缺少必填配置段: [{section}]")
                continue
            
            # 检查字段
            section_config = self.config.get(section, {})
            for field, field_schema in section_schema.get("fields", {}).items():
                # 必填字段
                if field_schema.get("required") and field not in section_config:
                    errors.append(f"缺少必填字段: [{section}].{field}")
                    continue
                
                # 类型检查
                if field in section_config:
                    value = section_config[field]
                    expected_type = field_schema.get("type")
                    if expected_type and not isinstance(value, expected_type):
                        errors.append(
                            f"字段类型错误: [{section}].{field} "
                            f"期望 {expected_type.__name__}, 实际 {type(value).__name__}"
                        )
        
        if errors:
            raise ConfigError("配置校验失败:\n" + "\n".join(f"  - {e}" for e in errors))
    
    def _apply_defaults(self):
        """应用默认值"""
        for section, section_schema in self.SCHEMA.items():
            if section not in self.config:
                self.config[section] = {}
            
            for field, field_schema in section_schema.get("fields", {}).items():
                if field not in self.config[section] and "default" in field_schema:
                    self.config[section][field] = field_schema["default"]
    
    def get(self, section: str, key: Optional[str] = None, default: Any = None) -> Any:
        """
        获取配置值
        
        Args:
            section: 配置段
            key: 键名，为None时返回整个section
            default: 默认值
        """
        if key is None:
            return self.config.get(section, default)
        return self.config.get(section, {}).get(key, default)


def load_config(config_path: Optional[str] = None, required_keys: Optional[list] = None) -> Dict[str, Any]:
    """
    快捷加载配置（全局函数）
    
    Args:
        config_path: 配置文件路径
        
    Returns:
        配置字典
    """
    loader = ConfigLoader(config_path)

    # Validate required keys if specified
    if required_keys:
        config_dict = loader.config
        missing_keys = [k for k in required_keys if k not in config_dict]
        if missing_keys:
            raise ValueError(f"Missing required config keys: {missing_keys}")
    return loader.load()


if __name__ == "__main__":
    # 自检模式
    try:
        config = load_config()
        print("✓ 配置加载成功")
        print(f"  - MQTT Broker: {config['mqtt']['broker']}:{config['mqtt']['port']}")
        print(f"  - 日志目录: {config['logging']['dir']}")
        print(f"  - 项目根: {config['system']['project_root']}")
    except ConfigError as e:
        print(f"✗ 配置加载失败: {e}", file=sys.stderr)
        sys.exit(1)
