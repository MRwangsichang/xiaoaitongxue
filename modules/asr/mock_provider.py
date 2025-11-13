"""
Mock ASR Provider - for offline testing
Generates fixed phrases without accessing microphone
"""
import asyncio
import random
import time
from typing import Optional

class MockProvider:
    """Mock ASR provider that generates fake transcriptions"""
    
    MOCK_PHRASES = [
        "你好",
        "测试一二三",
        "今天天气不错",
        "智能助手工作正常",
        "这是模拟语音识别"
    ]
    
    def __init__(self, config: dict, logger):
        self.config = config
        self.logger = logger
        self.running = False
        self._task: Optional[asyncio.Task] = None
        
    async def start(self, callback):
        """Start mock recognition session"""
        if self.running:
            self.logger.warning("Mock provider already running")
            return
            
        self.running = True
        self.logger.info("Mock provider started")
        self._task = asyncio.create_task(self._generate_mock_text(callback))
        
    async def stop(self):
        """Stop mock recognition session"""
        self.running = False
        if self._task and not self._task.done():
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        self.logger.info("Mock provider stopped")
        
    async def _generate_mock_text(self, callback):
        """Generate 3-5 mock phrases with random intervals"""
        try:
            num_phrases = random.randint(3, 5)
            phrases = random.sample(self.MOCK_PHRASES, min(num_phrases, len(self.MOCK_PHRASES)))
            
            for phrase in phrases:
                if not self.running:
                    break
                    
                # Random interval 0.8-1.2s
                await asyncio.sleep(random.uniform(0.8, 1.2))
                
                result = {
                    "text": phrase,
                    "lang": "zh-CN",
                    "confidence": round(random.uniform(0.85, 0.98), 2),
                    "ts": time.time()
                }
                
                await callback(result)
                self.logger.debug(f"Mock generated: {phrase}")
                
        except asyncio.CancelledError:
            self.logger.debug("Mock generation cancelled")
        except Exception as e:
            self.logger.error(f"Mock provider error: {e}", exc_info=True)
