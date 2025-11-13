#!/usr/bin/env python3
import asyncio
import sys
import os

os.chdir("/home/MRwang/smart_assistant")
sys.path.insert(0, "/home/MRwang/smart_assistant")

from core import get_logger, load_config
from modules.tts.xunfei_x5_provider import XunfeiX5TTSProvider

async def test():
    # 加载环境变量
    if os.path.exists("/home/MRwang/smart_assistant/.env.local"):
        with open("/home/MRwang/smart_assistant/.env.local") as f:
            for line in f:
                if line.startswith("XF_TTS_"):
                    key, val = line.strip().split("=", 1)
                    os.environ[key] = val
    
    config = load_config("config/tts.yml")
    logger = get_logger("test_x5")
    
    provider = XunfeiX5TTSProvider(config, logger)
    
    print("[测试] 正在合成x5聆飞逸男声...")
    audio_file = await provider.synthesize("我是聆飞逸男声，这是超拟人语音测试")
    print(f"✓ 测试成功: {audio_file}")
    print(f"播放命令: mpg123 -a plughw:0,0 {audio_file}")

if __name__ == "__main__":
    asyncio.run(test())
