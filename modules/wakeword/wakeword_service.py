"""
Wakeword Service - 唤醒词检测服务
功能：监听ASR文本，检测唤醒词，调用GROK选择回复模板
"""
import asyncio
import time
import yaml
from typing import Optional, Dict
from pathlib import Path

from core import get_logger, load_config, HealthReporter
from core.event_bus import EventBus, EventEnvelope
from modules.llm.grok_client import GrokClient


class WakewordService:
    """唤醒词服务"""
    
    def __init__(self, config_path: str = "config/wakeword.yml"):
        self.config = load_config(config_path)
        self.logger = get_logger("wakeword")
        
        self.bus: Optional[EventBus] = None
        self.health: Optional[HealthReporter] = None
        self.grok: Optional[GrokClient] = None
        
        # 加载GROK场景配置
        self.grok_scenarios = self._load_grok_scenarios()
        
        # 唤醒词列表
        self.wakewords = self.config.get("wakewords", [])
        self.logger.info(f"加载唤醒词: {self.wakewords}")
        
        # 冷却管理（防止短时间重复唤醒）
        self.last_wakeup_time = 0
        self.cooldown_seconds = self.config.get("cooldown_seconds", 5)
        
        self.running = False
    
    def _load_grok_scenarios(self) -> dict:
        """加载GROK场景配置"""
        scenarios_file = self.config.get("grok_scenarios_file", "config/grok_scenarios.yaml")
        scenarios_path = Path(self.config["system"]["project_root"]) / scenarios_file
        
        try:
            with open(scenarios_path, "r", encoding="utf-8") as f:
                scenarios = yaml.safe_load(f)
            self.logger.info(f"✓ 加载GROK场景配置: {scenarios_path}")
            return scenarios
        except Exception as e:
            self.logger.error(f"加载GROK场景配置失败: {e}")
            raise
    
    def _check_wakeword(self, text: str) -> bool:
        """检查文本中是否包含唤醒词"""
        text = text.strip()
        for wakeword in self.wakewords:
            if wakeword in text:
                self.logger.info(f"检测到唤醒词: {wakeword}")
                return True
        return False
    
    def _check_cooldown(self) -> bool:
        """检查是否在冷却期内"""
        now = time.time()
        if now - self.last_wakeup_time < self.cooldown_seconds:
            remaining = int(self.cooldown_seconds - (now - self.last_wakeup_time))
            self.logger.debug(f"冷却期内，跳过唤醒 (剩余{remaining}秒)")
            return False
        
        self.last_wakeup_time = now
        return True
    
    async def _generate_wakeup_response(self, wakeword: str) -> str:
        """调用GROK生成唤醒回复"""
        try:
            # 获取唤醒词回复场景配置
            wakeword_config = self.grok_scenarios["wakeword_response"]
            prompt_template = wakeword_config["prompt_template"]
            response_templates = wakeword_config["response_templates"]
            
            # 构建prompt
            templates_str = "\n".join([f"- {t}" for t in response_templates])
            prompt = prompt_template.format(
                wakeword=wakeword,
                response_templates=templates_str
            )
            
            # 调用GROK（不需要对话历史，max_tokens少一点）
            self.logger.info(f"调用GROK生成唤醒回复...")
            response = await self.grok.chat(
                user_message=prompt,
                conversation_history=None,
                max_tokens=30
            )
            
            self.logger.info(f"GROK回复: {response}")
            return response.strip()
            
        except Exception as e:
            self.logger.error(f"生成唤醒回复失败: {e}", exc_info=True)
            # 兜底回复
            return "我在"
    
    async def _handle_asr_text(self, envelope: EventEnvelope):
        """处理ASR文本事件"""
        try:
            payload = envelope.payload
            text = payload.get("text", "")
            
            if not text:
                return
            
            # 检查是否包含唤醒词
            if not self._check_wakeword(text):
                return
            
            # 检查冷却期
            if not self._check_cooldown():
                return
            
            self.logger.info(f"唤醒词触发: {text}")
            
            # 生成回复
            response_text = await self._generate_wakeup_response(text)
            
            # 发布到TTS
            tts_topic = self.config.get("tts_topic", "sa/tts/say")
            await self.bus.publish(
                topic=tts_topic,
                event_type="tts.say",
                payload={
                    "text": response_text,
                    "voice": "default",
                    "priority": 10  # 高优先级
                }
            )
            
            self.logger.info(f"✓ 唤醒流程完成: {response_text}")
            
        except Exception as e:
            self.logger.error(f"处理ASR文本失败: {e}", exc_info=True)
    
    async def start(self):
        """启动唤醒词服务"""
        self.logger.info("=== 唤醒词服务启动 ===")
        
        # 1. 初始化GROK客户端
        self.grok = GrokClient(self.logger)
        self.logger.info("✓ GROK客户端初始化完成")
        
        # 2. 初始化EventBus
        self.bus = EventBus(module_name="wakeword")
        
        # 3. 初始化健康心跳
        self.health = HealthReporter(
            module_name="wakeword",
            interval=self.config.get("health_interval", 10)
        )
        await self.health.start()
        
        # 4. 订阅ASR文本事件
        subscribe_topic = self.config.get("subscribe_topic", "sa/asr/text")
        await self.bus.start_listening({
            subscribe_topic: self._handle_asr_text
        })
        
        self.logger.info(f"✓ 订阅主题: {subscribe_topic}")
        self.logger.info(f"✓ 唤醒词列表: {self.wakewords}")
        self.logger.info("=== 唤醒词服务就绪 ===")
        
        self.running = True
        
        # 保持运行
        try:
            while self.running:
                await asyncio.sleep(1)
        except KeyboardInterrupt:
            self.logger.info("收到停止信号")
        finally:
            await self.stop()
    
    async def stop(self):
        """停止服务"""
        self.logger.info("正在停止唤醒词服务...")
        self.running = False
        
        if self.health:
            await self.health.stop()
        
        if self.bus:
            await self.bus.stop()
        
        self.logger.info("✓ 唤醒词服务已停止")


async def main():
    """主函数"""
    service = WakewordService()
    await service.start()


if __name__ == "__main__":
    asyncio.run(main())
