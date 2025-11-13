"""
规则引擎模块：订阅ASR结果，匹配规则，发布TTS消息
"""
import asyncio
from modules.llm.grok_client import GrokClient
import sys
import os
import signal
import time
import uuid

sys.path.insert(0, '/home/MRwang/smart_assistant')

from core.logger import get_logger
from core.event_bus import EventBus
from core.config_loader import load_config
from core.health import HealthReporter
from modules.rules.rules_engine import RulesEngine
from modules.rules.gpt_fallback import GPTFallback


class RulesModule:
    """规则引擎模块"""
    
    def __init__(self):
        self.module_name = "rules"
        self.logger = get_logger(self.module_name)
        self.grok = GrokClient(self.logger)
        self.conversation_history = []  # Grok对话历史
        self.config = None
        self.event_bus = None
        self.health = None
        self.engine = None
        self.gpt_fallback = None
        self._listen_task = None
        self._shutdown = False
        
    async def start(self):
        """启动模块"""
        self.logger.info(f"=== {self.module_name} 模块启动 ===")
        
        # 1. 加载配置
        self.config = load_config("config/rules.yml")
        rules_file = self.config.get("rules_file", "data/rules.json")
        
        # 2. 初始化规则引擎和GPT兜底
        self.engine = RulesEngine(rules_file, self.logger)
        self.gpt_fallback = GPTFallback(self.logger, self.grok)
        
        # 3. 初始化EventBus
        mqtt_config = self.config.get("mqtt", {})
        self.event_bus = EventBus(
            module_name=self.module_name,
            broker=mqtt_config.get("broker", "localhost"),
            port=mqtt_config.get("port", 1883),
            qos=mqtt_config.get("qos", 1),
            keepalive=mqtt_config.get("keepalive", 60)
        )
        self.logger.info("✓ 事件总线初始化")
        
        # 4. 订阅主题
        subscriptions = {
            "sa/asr/text": self._on_asr_text,
        }
        
        self._listen_task = asyncio.create_task(
            self.event_bus.start_listening(subscriptions)
        )
        self.logger.info("✓ 订阅主题: sa/asr/text")
        
        # 5. 启动健康心跳
        mqtt_config = self.config.get("mqtt", {})
        self.health = HealthReporter(
            module_name=self.module_name,
            interval=self.config.get("system", {}).get("health_interval", 10),
            broker=mqtt_config.get("broker", "localhost"),
            port=mqtt_config.get("port", 1883)
        )
        await self.health.start()
        
        self.logger.info(f"=== {self.module_name} 模块启动完成 ===")
        
    async def _on_asr_text(self, envelope):
        """处理ASR识别结果"""
        try:
            payload = envelope.payload
            text = payload.get("text", "")
            
            if not text:
                return
            
            # 唤醒词交给wakeword服务处理
            if any(w in text for w in ["星辰在吗", "在吗星辰", "星辰星辰", "星辰出来", "你好星辰", "星辰滚出来", "屌毛星辰出来", "老辰出来"]):
                return

            self.logger.info(f"收到ASR文本: {text}")
            
            # 匹配规则
            session_id = "default"  # TODO: 实现session管理
            result = self.engine.match(text, session_id)
            
            if not result:
                self.logger.info("未匹配到规则")
                return
            
            # 检查是否需要GPT
            if result.get('need_gpt'):
                reason = result.get('reason', 'unknown')
                self.logger.info(f"触发GPT兜底 (原因: {reason})")
                
                # 调用GPT生成回复
                gpt_response = await self.gpt_fallback.generate_response(text)
                
                # 发布GPT回复
                await self._publish_tts(gpt_response)
                return
            
            self.logger.info(f"✓ 匹配规则: {result['rule_id']}")
            
            # 执行actions
            for action in result['actions']:
                await self._execute_action(action)
                
        except Exception as e:
            self.logger.error(f"处理ASR文本失败: {e}", exc_info=True)
            
    async def _execute_action(self, action):
        """执行action"""
        action_type = action['type']
        params = action.get('params', {})
        
        if action_type == 'say':
            text = params.get('text', '')
            await self._publish_tts(text)
            
        elif action_type == 'set_state':
            self.logger.debug(f"状态更新: {params}")
            
        elif action_type == 'play':
            self.logger.info(f"播放音频: {params.get('args')}")
            
        elif action_type == 'wake_llm':
            self.logger.info(f"唤醒LLM: {params.get('text')}")
            
        else:
            self.logger.warning(f"未知action类型: {action_type}")
            
    async def _publish_tts(self, text):
        """发布TTS消息"""
        await self.event_bus.publish(
            topic="sa/tts/say",
            event_type="tts.say",
            payload={
                "text": text,
                "voice": "default",
                "priority": 5
            }
        )
        self.logger.info(f"✓ 发布TTS: {text}")
        
    async def stop(self):
        """停止模块"""
        if self._shutdown:
            return
            
        self._shutdown = True
        self.logger.info(f"=== 正在停止 {self.module_name} 模块 ===")
        
        if self.event_bus:
            self.event_bus.stop()
            
        if self._listen_task:
            self._listen_task.cancel()
            try:
                await self._listen_task
            except asyncio.CancelledError:
                pass
                
        if self.health:
            await self.health.stop()
            
        self.logger.info(f"=== {self.module_name} 模块已停止 ===")
        
    async def run(self):
        """运行模块（阻塞）"""
        await self.start()
        
        while not self._shutdown:
            await asyncio.sleep(1)


async def main():
    """主入口"""
    module = RulesModule()
    loop = asyncio.get_running_loop()
    
    def signal_handler():
        print(f"\n收到停止信号，正在优雅退出...")
        asyncio.create_task(module.stop())
    
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, signal_handler)
    
    try:
        await module.run()
    except KeyboardInterrupt:
        print("\n键盘中断，停止模块...")
        await module.stop()
    except Exception as e:
        print(f"模块异常: {e}")
        await module.stop()
        raise


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("已退出")
