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
