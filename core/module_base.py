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
