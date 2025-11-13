#!/usr/bin/env bash
set -euo pipefail
DRY_RUN="${DRY_RUN:-1}"

say(){ printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }
ok(){ printf "✓ %s\n" "$*"; }

ROOT="/home/MRwang/smart_assistant"
echo "=== CREATING HEALTH MODULE ==="

if [ "$DRY_RUN" = "1" ]; then
  say "DRY-RUN: Would create core/health.py"
  say "DRY-RUN: Would create tests/test_health.py"
  exit 0
fi

# 创建健康心跳模块
say "Creating core/health.py..."
cat > "$ROOT/core/health.py" <<'PYCODE'
"""
健康心跳模块 - 定时发布模块状态
"""
# 路径设置（支持直接运行）
import sys
from pathlib import Path
if __name__ == "__main__":
    _ROOT = Path(__file__).parent.parent
    if str(_ROOT) not in sys.path:
        sys.path.insert(0, str(_ROOT))

import asyncio
from datetime import datetime
from enum import Enum
from typing import Optional

from core.logger import get_logger
from core.event_bus import EventBus


class HealthStatus(Enum):
    """健康状态枚举"""
    STARTING = "starting"
    RUNNING = "running"
    ERROR = "error"
    STOPPED = "stopped"


class HealthReporter:
    """健康心跳报告器"""
    
    def __init__(
        self,
        module_name: str,
        interval: int = 30,
        broker: str = "localhost",
        port: int = 1883
    ):
        """
        初始化健康报告器
        
        Args:
            module_name: 模块名称
            interval: 心跳间隔（秒）
            broker: MQTT broker地址
            port: MQTT端口
        """
        self.module_name = module_name
        self.interval = interval
        self.logger = get_logger(f"health.{module_name}")
        
        # EventBus用于发布心跳
        self.event_bus = EventBus(
            module_name=module_name,
            broker=broker,
            port=port
        )
        
        # 状态
        self.status = HealthStatus.STOPPED
        self.start_time: Optional[datetime] = None
        self.last_error: Optional[str] = None
        self._task: Optional[asyncio.Task] = None
        self._running = False
    
    async def start(self):
        """启动心跳"""
        if self._running:
            self.logger.warning("心跳已在运行")
            return
        
        self.status = HealthStatus.STARTING
        self.start_time = datetime.utcnow()
        self._running = True
        self.last_error = None
        
        self.logger.info(f"健康心跳启动，间隔 {self.interval}秒")
        
        # 立即发送一次心跳
        await self._send_heartbeat()
        
        # 创建后台任务
        self._task = asyncio.create_task(self._heartbeat_loop())
        self.status = HealthStatus.RUNNING
    
    async def _heartbeat_loop(self):
        """心跳循环（后台任务）"""
        try:
            while self._running:
                await asyncio.sleep(self.interval)
                if self._running:  # 再次检查（可能在sleep期间被停止）
                    await self._send_heartbeat()
        except asyncio.CancelledError:
            self.logger.debug("心跳任务已取消")
        except Exception as e:
            self.logger.error(f"心跳循环错误: {e}", exc_info=True)
            self.status = HealthStatus.ERROR
            self.last_error = str(e)
    
    async def _send_heartbeat(self):
        """发送单次心跳"""
        try:
            uptime = 0
            if self.start_time:
                uptime = int((datetime.utcnow() - self.start_time).total_seconds())
            
            payload = {
                "module": self.module_name,
                "status": self.status.value,
                "uptime": uptime,
                "timestamp": datetime.utcnow().isoformat() + "Z"
            }
            
            if self.last_error:
                payload["last_error"] = self.last_error
            
            # 使用短连接发布（EventBus内部已是上下文管理器）
            await self.event_bus.publish(
                topic="sa/sys/health",
                event_type="health.heartbeat",
                payload=payload
            )
            
            self.logger.debug(f"心跳: {self.status.value}, uptime={uptime}s")
            
        except Exception as e:
            # 单次心跳失败不影响循环
            self.logger.error(f"发送心跳失败: {e}")
            self.last_error = f"heartbeat_failed: {e}"
    
    async def stop(self):
        """停止心跳"""
        if not self._running:
            return
        
        self._running = False
        self.status = HealthStatus.STOPPED
        
        # 取消后台任务
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        
        # 发送最后一次心跳（状态=STOPPED）
        try:
            await self._send_heartbeat()
        except Exception as e:
            self.logger.warning(f"停止心跳发送失败: {e}")
        
        self.logger.info("健康心跳已停止")
    
    def report_error(self, error: str):
        """
        报告错误（同步方法，便于在异常处理中调用）
        
        Args:
            error: 错误描述
        """
        self.last_error = error
        if self.status == HealthStatus.RUNNING:
            self.status = HealthStatus.ERROR
        self.logger.warning(f"模块错误: {error}")


if __name__ == "__main__":
    # 自检模式
    async def test_health():
        print("=== 健康心跳自检 ===")
        
        reporter = HealthReporter(
            module_name="test_module",
            interval=2  # 2秒间隔方便测试
        )
        
        # 启动
        await reporter.start()
        print(f"✓ 心跳已启动，状态: {reporter.status.value}")
        
        # 等待发送几次心跳
        await asyncio.sleep(5)
        
        # 报告错误
        reporter.report_error("模拟错误")
        await asyncio.sleep(2)
        
        # 停止
        await reporter.stop()
        print(f"✓ 心跳已停止，状态: {reporter.status.value}")
        print("✓ 自检通过")
    
    asyncio.run(test_health())
PYCODE
ok "core/health.py"

# 创建测试用例
say "Creating tests/test_health.py..."
cat > "$ROOT/tests/test_health.py" <<'PYTEST'
"""
健康心跳测试
"""
import asyncio
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(ROOT))

from core.health import HealthReporter, HealthStatus
from core.event_bus import EventBus


async def test_basic_lifecycle():
    """测试基本生命周期"""
    reporter = HealthReporter("test_mod", interval=1)
    
    # 初始状态
    assert reporter.status == HealthStatus.STOPPED
    
    # 启动
    await reporter.start()
    assert reporter.status == HealthStatus.RUNNING
    assert reporter.start_time is not None
    
    # 等待几次心跳
    await asyncio.sleep(2.5)
    
    # 停止
    await reporter.stop()
    assert reporter.status == HealthStatus.STOPPED
    
    print("✓ test_basic_lifecycle")


async def test_error_reporting():
    """测试错误报告"""
    reporter = HealthReporter("test_mod", interval=10)
    
    await reporter.start()
    
    # 报告错误
    reporter.report_error("测试错误")
    assert reporter.last_error == "测试错误"
    assert reporter.status == HealthStatus.ERROR
    
    await reporter.stop()
    
    print("✓ test_error_reporting")


async def test_heartbeat_reception():
    """测试心跳接收"""
    reporter = HealthReporter("test_mod", interval=1)
    
    # 订阅心跳
    subscriber = EventBus(module_name="test_sub")
    received = []
    
    async def callback(envelope):
        received.append(envelope.payload)
    
    task = asyncio.create_task(
        subscriber.start_listening({"sa/sys/health": callback})
    )
    
    await asyncio.sleep(0.5)  # 等待订阅
    
    # 启动心跳
    await reporter.start()
    await asyncio.sleep(2.5)  # 等待几次心跳
    
    # 停止
    await reporter.stop()
    subscriber.stop()
    await asyncio.sleep(0.5)
    task.cancel()
    
    # 验证
    assert len(received) >= 2, f"应收到至少2次心跳，实际: {len(received)}"
    assert received[0]["module"] == "test_mod"
    assert "uptime" in received[0]
    
    print(f"✓ test_heartbeat_reception (收到 {len(received)} 次心跳)")


async def main():
    print("=== 健康心跳测试 ===")
    await test_basic_lifecycle()
    await test_error_reporting()
    await test_heartbeat_reception()
    print("=== 所有测试通过 ===")


if __name__ == "__main__":
    asyncio.run(main())
PYTEST
ok "tests/test_health.py"

echo ""
echo "=== HEALTH MODULE CREATED ==="
