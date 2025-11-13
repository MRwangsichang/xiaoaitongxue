"""
Edge-TTS Provider (兜底方案)
使用微软Azure语音服务（免费，离线可用）
"""
import asyncio
import os
import edge_tts
from datetime import datetime


class EdgeTTSProvider:
    def __init__(self, config, logger):
        self.config = config
        self.logger = logger
        
        # 从配置读取参数
        self.voice = config.get('edge', {}).get('voice', 'zh-CN-YunxiNeural')
        self.rate = config.get('edge', {}).get('rate', '+0%')
        self.volume = config.get('edge', {}).get('volume', '+0%')
        
        self.logger.info(f"Edge-TTS初始化完成，音色: {self.voice}")

    async def synthesize(self, text: str) -> str:
        """
        使用Edge-TTS合成音频
        
        Args:
            text: 要合成的文本
            
        Returns:
            str: 音频文件路径
        """
        cache_dir = self.config['audio']['cache_dir']
        os.makedirs(cache_dir, exist_ok=True)
        
        # 生成文件名（带时间戳）
        timestamp = int(datetime.now().timestamp() * 1000)
        filename = f"tts_edge_{timestamp}.mp3"
        filepath = os.path.join(cache_dir, filename)
        
        self.logger.info(f"Edge-TTS开始合成: {text[:30]}...")
        
        try:
            # 创建Communicate对象
            communicate = edge_tts.Communicate(
                text=text,
                voice=self.voice,
                rate=self.rate,
                volume=self.volume
            )
            
            # 保存音频文件
            await communicate.save(filepath)
            
            self.logger.info(f"✓ Edge-TTS音频已保存: {filepath}")
            return filepath
            
        except Exception as e:
            self.logger.error(f"Edge-TTS合成失败: {e}", exc_info=True)
            raise
