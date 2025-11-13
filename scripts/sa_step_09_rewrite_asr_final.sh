#!/usr/bin/env bash
set -euo pipefail
DRY_RUN="${DRY_RUN:-1}"

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
cd "$ROOT" || exit 1

if [ "$DRY_RUN" = "1" ]; then
  say "DRY-RUN: 将按照 demo_sensor 模板重写 ASR 模块"
  say "DRY-RUN COMPLETE"
  exit 0
fi

say "=== Rewriting ASR module based on demo_sensor template ==="

cp modules/asr/asr_module.py "modules/asr/asr_module.py.bak_final_$(date +%s)"

cat > modules/asr/asr_module.py <<'PYEOF'
"""
ASR 模块 - 语音识别模块
"""
# 路径设置
import sys
from pathlib import Path
_ROOT = Path(__file__).parent.parent.parent
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))

import asyncio
import signal
import time
from typing import Optional, Dict

from core.config_loader import load_config, ConfigError
from core.logger import setup_logger
from core.event_bus import EventBus, EventEnvelope
from core.health import HealthReporter


class ASRModule:
    """ASR 模块实现"""

    def __init__(self):
        self.module_name = "asr"
        self.config = None
        self.logger = None
        self.event_bus: Optional[EventBus] = None
        self.health: Optional[HealthReporter] = None
        self.provider = None

        self._listen_task: Optional[asyncio.Task] = None
        self._shutdown = False
        self._dedup_cache: Dict[str, float] = {}
        self._dedup_window = 2.0  # seconds

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
                
                # 手动校验必填键
                required = ["provider", "device", "rate"]
                missing = [k for k in required if k not in self.config]
                if missing:
                    raise ConfigError(f"ASR配置缺少必填键: {missing}")
                
                self._dedup_window = self.config.get("dedup_ms", 2000) / 1000.0
                self.logger.info("✓ 配置加载成功")
                self.logger.info(f"  Provider: {self.config['provider']}")
                self.logger.info(f"  Device: {self.config['device']}")
                self.logger.info(f"  Rate: {self.config['rate']}Hz")
            except ConfigError as e:
                self.logger.error(f"配置加载失败: {e}")
                raise

            # 3. 初始化事件总线
            mqtt_config = all_config.get("mqtt")
            self.event_bus = EventBus(
                module_name=self.module_name,
                broker=mqtt_config["broker"],
                port=mqtt_config["port"],
                qos=mqtt_config.get("qos", 1),
                keepalive=mqtt_config.get("keepalive", 60)
            )
            self.logger.info("✓ 事件总线初始化")

            # 4. 启动健康心跳
            self.health = HealthReporter(
                module_name=self.module_name,
                interval=self.config.get("health_interval", 10),
                broker=mqtt_config["broker"],
                port=mqtt_config["port"]
            )
            await self.health.start()
            self.logger.info("✓ 健康心跳已启动")

            # 5. 初始化 provider
            await self._init_provider()

            # 6. 订阅命令主题
            subscriptions = {
                f"sa/{self.module_name}/cmd/#": self._handle_command,
            }

            self._listen_task = asyncio.create_task(
                self.event_bus.start_listening(subscriptions)
            )
            self.logger.info(f"✓ 订阅主题: sa/{self.module_name}/cmd/#")

            self.logger.info(f"=== {self.module_name} 模块启动完成 ===")

        except Exception as e:
            self.logger.error(f"启动失败: {e}", exc_info=True)
            if self.health:
                self.health.report_error(f"启动失败: {e}")
            await self.stop()
            raise

    async def _init_provider(self):
        """初始化 ASR provider"""
        provider_type = self.config["provider"]
        
        if provider_type == "mock":
            from .mock_provider import MockProvider
            self.provider = MockProvider(self.config, self.logger)
            self.logger.info("✓ Mock provider 初始化")
        elif provider_type == "cloud":
            # TODO: 实现 cloud provider
            self.logger.warning("Cloud provider 未实现，降级到 mock")
            from .mock_provider import MockProvider
            self.provider = MockProvider(self.config, self.logger)
        else:
            raise ValueError(f"Unknown provider: {provider_type}")

    async def _handle_command(self, envelope: EventEnvelope):
        """处理命令事件"""
        try:
            topic_parts = envelope.topic.split("/")
            cmd = topic_parts[-1] if topic_parts else "unknown"
            
            self.logger.info(f"收到命令: {cmd}")

            if cmd == "start":
                await self._handle_start(envelope)
            elif cmd == "stop":
                await self._handle_stop(envelope)
            else:
                self.logger.warning(f"未知命令: {cmd}")

        except Exception as e:
            self.logger.error(f"命令处理失败: {e}", exc_info=True)
            await self._publish_error(f"命令处理错误: {e}")

    async def _handle_start(self, envelope: EventEnvelope):
        """处理启动命令"""
        if not self.provider:
            await self._publish_error("Provider 未初始化")
            return
        
        self.logger.info("启动语音识别...")
        await self.provider.start(self._on_recognition_result)

    async def _handle_stop(self, envelope: EventEnvelope):
        """处理停止命令"""
        if not self.provider:
            return
        
        self.logger.info("停止语音识别...")
        await self.provider.stop()

    async def _on_recognition_result(self, result: dict):
        """识别结果回调（带去重）"""
        text = result.get("text", "")
        
        # 去重检查
        now = time.time()
        if text in self._dedup_cache:
            last_time = self._dedup_cache[text]
            if now - last_time < self._dedup_window:
                self.logger.debug(f"去重: {text}")
                return
        
        self._dedup_cache[text] = now
        
        # 清理旧缓存
        self._dedup_cache = {k: v for k, v in self._dedup_cache.items()
                            if now - v < self._dedup_window}
        
        # 发布识别结果
        await self.event_bus.publish(
            topic=f"sa/{self.module_name}/text",
            event_type="asr.text",
            payload={
                "text": text,
                "lang": result.get("lang", "zh-CN"),
                "confidence": result.get("confidence", 0.0),
                "ts": result.get("ts", time.time())
            }
        )
        self.logger.info(f"发布识别结果: {text}")

    async def _publish_error(self, error_msg: str):
        """发布错误事件"""
        if self.health:
            self.health.report_error(error_msg)
        
        try:
            await self.event_bus.publish(
                topic=f"sa/{self.module_name}/error",
                event_type="asr.error",
                payload={"error": error_msg, "ts": time.time()}
            )
        except Exception as e:
            self.logger.error(f"发布错误事件失败: {e}")

    async def stop(self):
        """停止模块"""
        if self._shutdown:
            return

        self._shutdown = True
        self.logger.info(f"=== 正在停止 {self.module_name} 模块 ===")

        # 1. 停止 provider
        if self.provider:
            await self.provider.stop()

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
    module = ASRModule()

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
PYEOF

say "✓ ASR 模块重写完成（基于 demo_sensor 模板）"

