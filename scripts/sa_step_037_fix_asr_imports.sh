#!/usr/bin/env bash
set -euo pipefail

say(){ printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

# 检查core模块是否存在
if [ -f "/home/MRwang/smart_assistant/core/module_base.py" ]; then
    say "core.module_base 存在"
else
    say "错误: core.module_base 不存在"
    say "创建基础的module_base.py..."
    
    cat > /home/MRwang/smart_assistant/core/module_base.py <<'PYCODE'
#!/usr/bin/env python3
"""模块基类"""

import asyncio
import logging
from typing import Optional, Dict, Any
from asyncio_mqtt import Client as MQTTClient
import json
import time
import uuid

class ModuleBase:
    """所有模块的基类"""
    
    def __init__(self, module_name: str):
        self.module_name = module_name
        self.logger = logging.getLogger(module_name)
        self.mqtt_client = None
        self.running = False
        
    async def publish(self, topic: str, payload: Dict[str, Any]):
        """发布消息到MQTT"""
        if not self.mqtt_client:
            self.logger.error("MQTT客户端未初始化")
            return
            
        message = {
            "id": str(uuid.uuid4()),
            "ts": time.strftime("%Y-%m-%dT%H:%M:%S.%fZ"),
            "source": self.module_name,
            "type": topic.split("/")[-1],
            "corr": str(uuid.uuid4()),
            "payload": payload,
            "meta": {"ver": "1.0"}
        }
        
        try:
            await self.mqtt_client.publish(topic, json.dumps(message))
            self.logger.debug(f"发布消息到 {topic}: {payload}")
        except Exception as e:
            self.logger.error(f"发布消息失败: {e}")
            
    async def subscribe(self, topic: str, handler):
        """订阅主题（简化版）"""
        self.logger.info(f"订阅主题: {topic}")
        # 实际订阅逻辑需要在子类中实现
        
    async def initialize(self) -> bool:
        """初始化模块"""
        return True
        
    async def start_module(self):
        """启动模块"""
        self.running = True
        self.logger.info(f"{self.module_name} 模块已启动")
        
    async def stop_module(self):
        """停止模块"""
        self.running = False
        self.logger.info(f"{self.module_name} 模块已停止")
        
    async def cleanup(self):
        """清理资源"""
        await self.stop_module()
PYCODE
fi

# 检查config_manager
if [ ! -f "/home/MRwang/smart_assistant/core/config_manager.py" ]; then
    say "创建config_manager.py..."
    
    cat > /home/MRwang/smart_assistant/core/config_manager.py <<'PYCODE'
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
PYCODE
fi

# 创建简化的ASR测试脚本（不依赖复杂模块）
cat > /home/MRwang/smart_assistant/test_asr_simple.py <<'PYCODE'
#!/usr/bin/env python3
"""简化的ASR测试"""

import asyncio
import json
import logging
from asyncio_mqtt import Client as MQTTClient

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("asr_test")

async def simulate_asr():
    """模拟ASR识别并发布结果"""
    
    async with MQTTClient("localhost") as client:
        logger.info("连接到MQTT broker")
        
        # 模拟几个识别结果
        test_texts = [
            "你好小爱",
            "今天天气怎么样",
            "播放音乐",
            "退下"
        ]
        
        for text in test_texts:
            # 构建ASR事件
            message = {
                "id": "test-asr-001",
                "ts": "2025-10-17T13:30:00.000Z",
                "source": "asr",
                "type": "text",
                "corr": "test-asr-001",
                "payload": {
                    "text": text,
                    "timestamp": 1760707800.0,
                    "final": True
                },
                "meta": {"ver": "1.0"}
            }
            
            # 发布到sa/asr/text
            await client.publish("sa/asr/text", json.dumps(message))
            logger.info(f"发布ASR结果: {text}")
            
            # 等待3秒看规则引擎反应
            await asyncio.sleep(3)
            
    logger.info("测试完成")

if __name__ == "__main__":
    asyncio.run(simulate_asr())
PYCODE

chmod +x /home/MRwang/smart_assistant/test_asr_simple.py
say "ASR测试脚本已创建"
say "可以运行: python3 /home/MRwang/smart_assistant/test_asr_simple.py"
