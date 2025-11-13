"""
事件总线测试 (v2)
"""
import asyncio
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(ROOT))

from core.event_bus import EventBus, EventEnvelope


async def test_envelope():
    """测试消息信封"""
    envelope = EventEnvelope(
        event_type="test.event",
        payload={"key": "value"},
        source="test_module"
    )
    
    assert envelope.id
    assert envelope.ts
    assert envelope.type == "test.event"
    
    # JSON序列化
    json_str = envelope.to_json()
    parsed = EventEnvelope.from_json(json_str)
    assert parsed is not None
    assert parsed.type == envelope.type
    
    # 错误JSON
    bad_envelope = EventEnvelope.from_json("invalid json")
    assert bad_envelope is None
    
    print("✓ test_envelope")


async def test_topic_matching():
    """测试主题匹配"""
    bus = EventBus()
    
    # 测试 + 单层通配
    assert bus._topic_matches("sa/vision/health", "sa/+/health")
    assert not bus._topic_matches("sa/vision/status", "sa/+/health")
    
    # 测试 # 多层通配
    assert bus._topic_matches("sa/vision/health", "sa/#")
    assert bus._topic_matches("sa/vision/face/detected", "sa/#")
    assert bus._topic_matches("sa/asr/text", "sa/#")
    
    # 测试精确匹配
    assert bus._topic_matches("sa/test/ping", "sa/test/ping")
    assert not bus._topic_matches("sa/test/pong", "sa/test/ping")
    
    print("✓ test_topic_matching")


async def test_pubsub():
    """测试发布订阅"""
    bus = EventBus(module_name="test")
    received = []
    
    async def callback(envelope: EventEnvelope):
        received.append(envelope)
    
    # 启动监听
    task = asyncio.create_task(bus.start_listening({"sa/test/+": callback}))
    await asyncio.sleep(1)  # 等待订阅完成
    
    # 发布
    await bus.publish(
        topic="sa/test/event",
        event_type="test.ping",
        payload={"msg": "hello"}
    )
    
    await asyncio.sleep(1)
    
    # 停止
    bus.stop()
    await asyncio.sleep(0.5)
    task.cancel()
    
    assert len(received) == 1
    assert received[0].payload["msg"] == "hello"
    
    print("✓ test_pubsub")


async def main():
    print("=== 事件总线测试 (v2) ===")
    await test_envelope()
    await test_topic_matching()
    await test_pubsub()
    print("=== 所有测试通过 ===")


if __name__ == "__main__":
    asyncio.run(main())
