"""
最小服务模板 - 完整集成示例
功能：配置加载 → 日志 → 事件总线 → 健康心跳 → 信号处理
"""
# 路径设置
import sys
from pathlib import Path
_ROOT = Path(__file__).parent.parent.parent
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))

import asyncio
import signal
from typing import Optional

from core.config_loader import load_config, ConfigError
from core.logger import setup_logger
from core.event_bus import EventBus, EventEnvelope
from core.health import HealthReporter, HealthStatus


class ServiceTemplate:
    """最小服务模板"""
    
    def __init__(self, module_name: str = "template"):
        self.module_name = module_name
        self.config = None
        self.logger = None
        self.event_bus: Optional[EventBus] = None
        self.health: Optional[HealthReporter] = None
        
        self._listen_task: Optional[asyncio.Task] = None
        self._demo_task: Optional[asyncio.Task] = None
        self._shutdown = False
    
    async def start(self):
        """启动服务"""
        try:
            # 1. 加载配置
            self.logger = setup_logger(self.module_name, console=True)
            self.logger.info("=== 服务启动 ===")
            
            try:
                self.config = load_config()
                self.logger.info("✓ 配置加载成功")
            except ConfigError as e:
                self.logger.error(f"配置加载失败: {e}")
                raise
            
            # 2. 初始化事件总线
            mqtt_config = self.config.get("mqtt")
            self.event_bus = EventBus(
                module_name=self.module_name,
                broker=mqtt_config["broker"],
                port=mqtt_config["port"],
                qos=mqtt_config["qos"],
                keepalive=mqtt_config["keepalive"]
            )
            self.logger.info("✓ 事件总线初始化")
            
            # 3. 启动健康心跳
            self.health = HealthReporter(
                module_name=self.module_name,
                interval=30,
                broker=mqtt_config["broker"],
                port=mqtt_config["port"]
            )
            await self.health.start()
            self.logger.info("✓ 健康心跳已启动")
            
            # 4. 订阅主题（示例）
            subscriptions = {
                "sa/test/#": self._handle_test_event,
                "sa/sys/health": self._handle_health_event
            }
            
            self._listen_task = asyncio.create_task(
                self.event_bus.start_listening(subscriptions)
            )
            self.logger.info("✓ 开始监听事件")
            
            # 5. 启动示例任务
            self._demo_task = asyncio.create_task(self._demo_publisher())
            
            self.logger.info("=== 服务启动完成 ===")
            
        except Exception as e:
            self.logger.error(f"启动失败: {e}", exc_info=True)
            if self.health:
                self.health.report_error(f"启动失败: {e}")
            await self.stop()
            raise
    
    async def _handle_test_event(self, envelope: EventEnvelope):
        """处理测试事件"""
        self.logger.info(f"收到测试事件: {envelope.type} | {envelope.payload}")
    
    async def _handle_health_event(self, envelope: EventEnvelope):
        """处理健康事件"""
        payload = envelope.payload
        if payload.get("status") == "error":
            self.logger.warning(
                f"模块 {payload.get('module')} 报告错误: {payload.get('last_error')}"
            )
    
    async def _demo_publisher(self):
        """示例：定时发布测试事件"""
        try:
            while not self._shutdown:
                await asyncio.sleep(60)
                
                if not self._shutdown:
                    await self.event_bus.publish(
                        topic="sa/test/demo",
                        event_type="demo.ping",
                        payload={"message": "hello from template"}
                    )
                    self.logger.debug("发布了测试事件")
                    
        except asyncio.CancelledError:
            self.logger.debug("示例发布任务已取消")
        except Exception as e:
            self.logger.error(f"示例发布任务错误: {e}", exc_info=True)
            if self.health:
                self.health.report_error(f"demo_publisher: {e}")
    
    async def stop(self):
        """停止服务"""
        if self._shutdown:
            return
        
        self._shutdown = True
        self.logger.info("=== 正在停止服务 ===")
        
        # 1. 取消任务
        if self._demo_task:
            self._demo_task.cancel()
            try:
                await self._demo_task
            except asyncio.CancelledError:
                pass
        
        # 2. 停止监听
        if self.event_bus:
            self.event_bus.stop()
        
        if self._listen_task:
            self._listen_task.cancel()
            try:
                await self._listen_task
            except asyncio.CancelledError:
                pass
        
        # 3. 停止健康心跳
        if self.health:
            await self.health.stop()
        
        self.logger.info("=== 服务已停止 ===")
    
    async def run(self):
        """运行服务"""
        await self.start()
        
        while not self._shutdown:
            await asyncio.sleep(1)


async def main():
    """主入口"""
    service = ServiceTemplate("template")
    
    loop = asyncio.get_running_loop()
    
    def signal_handler():
        print("\n收到停止信号，正在优雅退出...")
        asyncio.create_task(service.stop())
    
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, signal_handler)
    
    try:
        await service.run()
    except KeyboardInterrupt:
        print("\n键盘中断，停止服务...")
        await service.stop()
    except Exception as e:
        print(f"服务异常: {e}")
        await service.stop()
        raise


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("已退出")
