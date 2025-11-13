#!/usr/bin/env bash
set -euo pipefail
DRY_RUN="${DRY_RUN:-1}"

say(){ printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }
ok(){ printf "✓ %s\n" "$*"; }

ROOT="/home/MRwang/smart_assistant"
echo "=== CREATING EVENT BUS (V2 - OPTIMIZED) ==="

if [ "$DRY_RUN" = "1" ]; then
  say "DRY-RUN: Would check asyncio-mqtt"
  say "DRY-RUN: Would create core/event_bus.py (optimized)"
  say "DRY-RUN: Would create tests/test_event_bus.py"
  exit 0
fi

# 1. 检查依赖
say "Checking asyncio-mqtt..."
if python3 -c "import asyncio_mqtt" 2>/dev/null; then
  ok "asyncio-mqtt available"
else
  echo "✗ asyncio-mqtt not found. Install with:"
  echo "  pip3 install --break-system-packages asyncio-mqtt"
  exit 1
fi

# 2. 创建优化版事件总线
say "Creating core/event_bus.py (v2 - optimized)..."
cat > "$ROOT/core/event_bus.py" <<'PYCODE'
"""
MQTT事件总线 - asyncio驱动、上下文管理器规范、健壮重连
版本: v2（采纳GPT审查建议）
"""
import asyncio
import json
import uuid
from datetime import datetime
from typing import Any, Callable, Dict, Optional
import asyncio_mqtt as aiomqtt

from core.logger import get_logger


class EventEnvelope:
    """统一消息信封"""
    
    def __init__(
        self,
        event_type: str,
        payload: Dict[str, Any],
        source: str,
        correlation_id: Optional[str] = None,
        version: str = "1.0"
    ):
        self.id = str(uuid.uuid4())
        self.ts = datetime.utcnow().isoformat() + "Z"
        self.source = source
        self.type = event_type
        self.corr = correlation_id or self.id
        self.payload = payload
        self.meta = {"ver": version}
    
    def to_dict(self) -> Dict[str, Any]:
        """转为字典"""
        return {
            "id": self.id,
            "ts": self.ts,
            "source": self.source,
            "type": self.type,
            "corr": self.corr,
            "payload": self.payload,
            "meta": self.meta
        }
    
    def to_json(self) -> str:
        """转为JSON"""
        return json.dumps(self.to_dict(), ensure_ascii=False)
    
    @classmethod
    def from_json(cls, json_str: str) -> Optional['EventEnvelope']:
        """
        从JSON解析（防御性）
        
        Returns:
            解析成功返回信封，失败返回None
        """
        try:
            data = json.loads(json_str)
            envelope = cls(
                event_type=data["type"],
                payload=data["payload"],
                source=data["source"],
                correlation_id=data.get("corr"),
                version=data.get("meta", {}).get("ver", "1.0")
            )
            envelope.id = data["id"]
            envelope.ts = data["ts"]
            return envelope
        except (json.JSONDecodeError, KeyError, TypeError) as e:
            # 解析失败返回None，由调用方处理
            return None


class EventBus:
    """MQTT事件总线（规范版）"""
    
    MAX_MESSAGE_SIZE = 1024 * 1024  # 1MB消息体限制
    
    def __init__(
        self,
        broker: str = "localhost",
        port: int = 1883,
        module_name: str = "unknown",
        qos: int = 1,
        keepalive: int = 60
    ):
        self.broker = broker
        self.port = port
        self.module_name = module_name
        self.qos = qos
        self.keepalive = keepalive
        
        self.logger = get_logger(f"eventbus.{module_name}")
        self._subscriptions: Dict[str, Callable] = {}
        self._running = False
        self._reconnect_interval = 5  # 固定重连间隔（秒）
    
    async def publish(
        self,
        topic: str,
        event_type: str,
        payload: Dict[str, Any],
        correlation_id: Optional[str] = None
    ):
        """
        发布事件（短连接模式，使用上下文管理器）
        
        Args:
            topic: MQTT主题
            event_type: 事件类型
            payload: 有效载荷
            correlation_id: 关联ID
        """
        envelope = EventEnvelope(
            event_type=event_type,
            payload=payload,
            source=self.module_name,
            correlation_id=correlation_id
        )
        
        message = envelope.to_json()
        
        # 检查消息大小
        if len(message.encode('utf-8')) > self.MAX_MESSAGE_SIZE:
            self.logger.error(f"消息体过大: {len(message)} bytes，超过 {self.MAX_MESSAGE_SIZE}")
            raise ValueError("Message too large")
        
        # 使用上下文管理器发布
        try:
            async with aiomqtt.Client(
                hostname=self.broker,
                port=self.port,
                keepalive=self.keepalive
            ) as client:
                await client.publish(topic, message, qos=self.qos)
                self.logger.debug(f"发布事件: {topic} | {event_type}")
        except Exception as e:
            self.logger.error(f"发布失败: {e}")
            raise
    
    async def start_listening(self, subscriptions: Dict[str, Callable]):
        """
        启动消息监听循环（带自动重连）
        
        Args:
            subscriptions: {topic: callback} 映射
        """
        self._subscriptions = subscriptions
        self._running = True
        
        while self._running:
            try:
                async with aiomqtt.Client(
                    hostname=self.broker,
                    port=self.port,
                    keepalive=self.keepalive
                ) as client:
                    self.logger.info(f"已连接到 MQTT broker: {self.broker}:{self.port}")
                    
                    # 订阅所有主题
                    for topic in self._subscriptions.keys():
                        await client.subscribe(topic, qos=self.qos)
                        self.logger.info(f"订阅主题: {topic}")
                    
                    # 消息循环（规范用法）
                    async with client.messages() as messages:
                        async for message in messages:
                            if not self._running:
                                break
                            await self._handle_message(message)
                            
            except aiomqtt.MqttError as e:
                if self._running:
                    self.logger.error(f"MQTT错误: {e}，{self._reconnect_interval}秒后重连...")
                    await asyncio.sleep(self._reconnect_interval)
                else:
                    break
            except Exception as e:
                self.logger.error(f"监听循环错误: {e}", exc_info=True)
                if self._running:
                    await asyncio.sleep(self._reconnect_interval)
                else:
                    break
    
    async def _handle_message(self, message):
        """处理接收到的消息（防御性）"""
        try:
            # 检查消息大小
            payload_bytes = message.payload
            if len(payload_bytes) > self.MAX_MESSAGE_SIZE:
                self.logger.warning(f"收到过大消息，已忽略: {len(payload_bytes)} bytes")
                return
            
            # 解析信封（防御性）
            envelope = EventEnvelope.from_json(payload_bytes.decode('utf-8'))
            if envelope is None:
                self.logger.warning(f"消息JSON解析失败，已忽略: {message.topic}")
                return
            
            # 查找匹配的回调
            for topic_pattern, callback in self._subscriptions.items():
                if self._topic_matches(message.topic.value, topic_pattern):
                    try:
                        await callback(envelope)
                    except Exception as e:
                        self.logger.error(f"回调执行失败 [{topic_pattern}]: {e}", exc_info=True)
                    break
                    
        except UnicodeDecodeError as e:
            self.logger.warning(f"消息解码失败: {e}")
        except Exception as e:
            self.logger.error(f"消息处理异常: {e}", exc_info=True)
    
    def _topic_matches(self, topic: str, pattern: str) -> bool:
        """
        主题匹配（支持 + 和 # 通配符）
        
        + : 单层通配符（如 sa/+/health 匹配 sa/vision/health）
        # : 多层通配符（如 sa/# 匹配 sa/vision/health）
        """
        topic_parts = topic.split('/')
        pattern_parts = pattern.split('/')
        
        # # 多层通配符（必须在末尾）
        if '#' in pattern_parts:
            if pattern_parts[-1] != '#':
                return False  # # 只能在末尾
            # 匹配前缀
            for i, p in enumerate(pattern_parts[:-1]):
                if i >= len(topic_parts):
                    return False
                if p != '+' and p != topic_parts[i]:
                    return False
            return True
        
        # 长度必须一致（没有#时）
        if len(topic_parts) != len(pattern_parts):
            return False
        
        # 逐层匹配
        for t, p in zip(topic_parts, pattern_parts):
            if p != '+' and p != t:
                return False
        return True
    
    def stop(self):
        """停止监听"""
        self._running = False
        self.logger.info("正在停止事件总线...")


if __name__ == "__main__":
    # 自检模式
    import sys
    
    async def test_pubsub():
        print("=== 事件总线自检 (v2) ===")
        
        bus = EventBus(module_name="test_bus")
        
        # 接收计数
        received = []
        
        async def test_callback(envelope: EventEnvelope):
            received.append(envelope.payload)
            print(f"✓ 收到消息: {envelope.type} | {envelope.payload}")
        
        # 订阅
        subscriptions = {
            "sa/test/#": test_callback
        }
        
        # 启动监听（后台任务）
        listen_task = asyncio.create_task(bus.start_listening(subscriptions))
        
        # 等待订阅完成
        await asyncio.sleep(1)
        
        # 发布测试消息
        await bus.publish(
            topic="sa/test/ping",
            event_type="test.ping",
            payload={"message": "hello"}
        )
        
        # 等待接收
        await asyncio.sleep(1)
        
        # 停止
        bus.stop()
        await asyncio.sleep(0.5)
        listen_task.cancel()
        
        # 验证
        if received:
            print(f"✓ 自检通过，收到 {len(received)} 条消息")
        else:
            print("✗ 自检失败，未收到消息", file=sys.stderr)
            sys.exit(1)
    
    asyncio.run(test_pubsub())
PYCODE
ok "core/event_bus.py (v2 - optimized)"

# 3. 创建测试用例
say "Creating tests/test_event_bus.py..."
cat > "$ROOT/tests/test_event_bus.py" <<'PYTEST'
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
PYTEST
ok "tests/test_event_bus.py"

echo ""
echo "=== EVENT BUS V2 CREATED ==="
