#!/usr/bin/env python3
import asyncio
import sys
import os
import json

os.chdir("/home/MRwang/smart_assistant")
sys.path.insert(0, "/home/MRwang/smart_assistant")

from core import get_logger, load_config
from modules.tts.xunfei_provider import XunfeiTTSProvider

async def test():
    # 加载环境变量
    if os.path.exists("/home/MRwang/smart_assistant/.env.local"):
        with open("/home/MRwang/smart_assistant/.env.local") as f:
            for line in f:
                if line.startswith("XF_TTS_"):
                    key, val = line.strip().split("=", 1)
                    os.environ[key] = val
    
    config = load_config("config/tts.yml")
    logger = get_logger("test_xunfei")
    
    # 打印配置中的音色
    print(f"[DEBUG] 配置中的音色: {config['xunfei']['vcn']}")
    print(f"[DEBUG] 完整business参数: {json.dumps(config['xunfei'], indent=2, ensure_ascii=False)}")
    
    provider = XunfeiTTSProvider(config, logger)
    
    print("\n[测试] 正在合成男声测试...")
    audio_file = await provider.synthesize("我是聆飞逸男声，这是测试")
    print(f"✓ 生成文件: {audio_file}")
    print(f"播放命令: mpg123 -a plughw:0,0 {audio_file}")

if __name__ == "__main__":
    asyncio.run(test())
