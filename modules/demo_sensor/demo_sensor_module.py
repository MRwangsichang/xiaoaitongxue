"""
demo_sensor 模块 - 自动生成的脚手架
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


class Demo_sensorModule:
    """demo_sensor 模块实现"""
    
    def __init__(self):
        self.module_name = "demo_sensor"
        self.config = None
        self.logger = None
        self.event_bus: Optional[EventBus] = None
        self.health: Optional[HealthReporter] = None
        
        self._listen_task: Optional[asyncio.Task] = None
        self._worker_task: Optional[asyncio.Task] = None
        self._shutdown = False
        self._error_count = 0
        self._max_errors = 5
    
    async def start(self):
        """启动模块"""
        try:
            # 1. 初始化日志
            self.logger = setup_logger(self.module_name, console=True)
            self.logger.info(f"=== {self.module_name} 模块启动 ===")
            
            # 2. 加载配置
            try:
                all_config = load_config()
                self.config = all_config.get(self.module_name, {})
                self.logger.info("✓ 配置加载成功")
            except ConfigError as e:
                self.logger.error(f"配置加载失败: {e}")
                raise
            
            # 3. 初始化事件总线
            mqtt_config = all_config.get("mqtt")
            self.event_bus = EventBus(
                module_name=self.module_name,
                broker=mqtt_config["broker"],
                port=mqtt_config["port"],
                qos=mqtt_config["qos"],
                keepalive=mqtt_config["keepalive"]
            )
            self.logger.info("✓ 事件总线初始化")
            
            # 4. 启动健康心跳
            self.health = HealthReporter(
                module_name=self.module_name,
                interval=self.config.get("health_interval", 30),
                broker=mqtt_config["broker"],
                port=mqtt_config["port"]
            )
            await self.health.start()
            self.logger.info("✓ 健康心跳已启动")
            
            # 5. 订阅命令主题
            subscriptions = {
                f"sa/{self.module_name}/cmd/#": self._handle_command,
            }
            
            self._listen_task = asyncio.create_task(
                self.event_bus.start_listening(subscriptions)
            )
            self.logger.info(f"✓ 订阅主题: sa/{self.module_name}/cmd/#")
            
            # 6. 启动业务逻辑（可选）
            self._worker_task = asyncio.create_task(self._worker_loop())
            
            self.logger.info(f"=== {self.module_name} 模块启动完成 ===")
            
        except Exception as e:
            self.logger.error(f"启动失败: {e}", exc_info=True)
            if self.health:
                self.health.report_error(f"启动失败: {e}")
            await self.stop()
            raise
    
    async def _handle_command(self, envelope: EventEnvelope):
        """处理命令事件"""
        try:
            cmd_type = envelope.type
            payload = envelope.payload
            
            self.logger.info(f"收到命令: {cmd_type} | {payload}")
            
            # 业务逻辑：根据命令类型处理
            result = await self._process_command(cmd_type, payload)
            
            # 发布事件结果
            if result:
                await self.event_bus.publish(
                    topic=f"sa/{self.module_name}/event/{cmd_type}",
                    event_type=f"{self.module_name}.{cmd_type}.result",
                    payload=result,
                    correlation_id=envelope.corr
                )
            
            self._error_count = 0  # 重置错误计数
            
        except Exception as e:
            self.logger.error(f"命令处理失败: {e}", exc_info=True)
            await self._report_error(f"命令处理错误: {e}")
    
    async def _process_command(self, cmd_type: str, payload: dict) -> Optional[dict]:
        """
        处理具体业务逻辑（需要子类或扩展实现）
        
        Returns:
            处理结果字典，或None
        """
        # TODO: 在此实现具体业务逻辑
        self.logger.debug(f"处理命令: {cmd_type}")
        
        # 示例：echo命令
        if cmd_type == "echo":
            return {"echo": payload.get("message", "empty")}
        
        return {"status": "not_implemented", "cmd": cmd_type}
    
    async def _worker_loop(self):
        """后台工作循环（可选）"""
        try:
            while not self._shutdown:
                # TODO: 在此实现周期性任务
                await asyncio.sleep(10)
                
                if not self._shutdown:
                    # 示例：定期发布心跳事件
                    await self.event_bus.publish(
                        topic=f"sa/{self.module_name}/health",
                        event_type=f"{self.module_name}.heartbeat",
                        payload={"status": "working"}
                    )
                    
        except asyncio.CancelledError:
            self.logger.debug("工作循环已取消")
        except Exception as e:
            self.logger.error(f"工作循环错误: {e}", exc_info=True)
            await self._report_error(f"工作循环异常: {e}")
    
    async def _report_error(self, error_msg: str):
        """报告错误"""
        self._error_count += 1
        
        if self.health:
            self.health.report_error(error_msg)
        
        # 发布错误事件
        try:
            await self.event_bus.publish(
                topic=f"sa/{self.module_name}/error",
                event_type=f"{self.module_name}.error",
                payload={
                    "error": error_msg,
                    "count": self._error_count
                }
            )
        except Exception as e:
            self.logger.error(f"发布错误事件失败: {e}")
        
        # 错误退避
        if self._error_count >= self._max_errors:
            self.logger.error(f"错误次数达到上限 ({self._max_errors})，模块停止")
            await self.stop()
    
    async def stop(self):
        """停止模块"""
        if self._shutdown:
            return
        
        self._shutdown = True
        self.logger.info(f"=== 正在停止 {self.module_name} 模块 ===")
        
        # 1. 取消工作任务
        if self._worker_task:
            self._worker_task.cancel()
            try:
                await self._worker_task
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
        
        self.logger.info(f"=== {self.module_name} 模块已停止 ===")
    
    async def run(self):
        """运行模块（阻塞）"""
        await self.start()
        
        while not self._shutdown:
            await asyncio.sleep(1)


async def main():
    """主入口"""
    module = Demo_sensorModule()
    
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
