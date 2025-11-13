#!/usr/bin/env python3
"""配置管理器"""

import json
import os
from typing import Dict, Any

class ConfigManager:
    """配置管理器"""
    
    def __init__(self):
        self.config_dir = "/home/MRwang/smart_assistant/config"
        self.config = {}
        self._load_config()
        
    def _load_config(self):
        """加载配置文件"""
        config_file = os.path.join(self.config_dir, "modules.json")
        if os.path.exists(config_file):
            try:
                with open(config_file, 'r') as f:
                    self.config = json.load(f)
            except:
                self.config = {}
                
    def get_module_config(self, module_name: str) -> Dict[str, Any]:
        """获取模块配置"""
        return self.config.get(module_name, {
            "enabled": True,
            "mqtt_host": "localhost",
            "mqtt_port": 1883,
            "sample_rate": 16000,
            "channels": 1,
            "chunk_size": 1280,
            "vad_energy_threshold": 1000,
            "vad_silence_duration": 1.5
        })
