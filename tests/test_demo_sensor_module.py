"""
demo_sensor 模块测试
"""
import asyncio
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(ROOT))

from modules.demo_sensor.demo_sensor_module import Demo_sensorModule
from core.event_bus import EventBus


async def test_basic_lifecycle():
    """测试基本生命周期"""
    print("=== 测试 demo_sensor 模块生命周期 ===")
    
    module = Demo_sensorModule()
    
    # 启动
    await module.start()
    print("✓ 模块启动成功")
    
    # 运行5秒
    await asyncio.sleep(5)
    
    # 停止
    await module.stop()
    print("✓ 模块停止成功")


async def test_error_reporting():
    """测试错误报告"""
    print("=== 测试错误报告机制 ===")
    
    module = Demo_sensorModule()
    
    # 订阅错误主题
    subscriber = EventBus(module_name="test_sub")
    received_errors = []
    
    async def error_callback(envelope):
        received_errors.append(envelope.payload)
    
    task = asyncio.create_task(
        subscriber.start_listening({f"sa/demo_sensor/error": error_callback})
    )
    
    await asyncio.sleep(0.5)
    
    # 启动模块
    await module.start()
    await asyncio.sleep(1)
    
    # 触发错误报告
    await module._report_error("测试错误")
    
    await asyncio.sleep(1)
    
    # 停止
    await module.stop()
    subscriber.stop()
    await asyncio.sleep(0.5)
    task.cancel()
    
    # 验证
    if received_errors:
        print(f"✓ 错误报告正常（收到 {len(received_errors)} 条）")
        print(f"  错误: {received_errors[0].get('error')}")
    else:
        print("✗ 未收到错误事件")


async def test_heartbeat():
    """测试健康心跳"""
    print("=== 测试健康心跳 ===")
    
    module = Demo_sensorModule()
    
    # 订阅心跳主题
    subscriber = EventBus(module_name="test_sub")
    received_health = []
    
    async def health_callback(envelope):
        received_health.append(envelope.payload)
    
    task = asyncio.create_task(
        subscriber.start_listening({f"sa/demo_sensor/health": health_callback})
    )
    
    await asyncio.sleep(0.5)
    
    # 启动模块
    await module.start()
    
    # 等待几次心跳
    await asyncio.sleep(12)
    
    # 停止
    await module.stop()
    subscriber.stop()
    await asyncio.sleep(0.5)
    task.cancel()
    
    # 验证
    if received_health:
        print(f"✓ 健康心跳正常（收到 {len(received_health)} 次）")
    else:
        print("✗ 未收到健康心跳")


async def main():
    print("=" * 60)
    print(f"demo_sensor 模块测试套件")
    print("=" * 60)
    
    await test_basic_lifecycle()
    print()
    await test_error_reporting()
    print()
    await test_heartbeat()
    
    print("=" * 60)
    print("所有测试完成")
    print("=" * 60)


if __name__ == "__main__":
    asyncio.run(main())
