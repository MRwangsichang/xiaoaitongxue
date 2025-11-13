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
