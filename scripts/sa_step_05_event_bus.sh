#!/usr/bin/env bash
set -euo pipefail
DRY_RUN="${DRY_RUN:-1}"

say(){ printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }
ok(){ printf "✓ %s\n" "$*"; }

ROOT="/home/MRwang/smart_assistant"
echo "=== CREATING EVENT BUS ==="

if [ "$DRY_RUN" = "1" ]; then
  say "DRY-RUN: Would install asyncio-mqtt (pip3)"
  say "DRY-RUN: Would create core/event_bus.py"
  say "DRY-RUN: Would create tests/test_event_bus.py"
  exit 0
fi

# 1. 安装依赖（asyncio-mqtt）
say "Installing asyncio-mqtt..."
pip3 install --quiet asyncio-mqtt 2>/dev/null || pip3 install asyncio-mqtt
ok "asyncio-mqtt installed"

# 2. 创建事件总线
say "Creating core/event_bus.py..."
cat > "$ROOT/core/event_bus.py" <<'PYCODE'
"""
MQTT事件总线 - asyncio驱动、自动重连、统一消息信封
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
    def from_json(cls, json_str: str) -> 'EventEnvelope':
        """从JSON解析"""
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


class EventBus:
    """MQTT事件总线"""
    
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
        self._client: Optional[aiomqtt.Client] = None
        self._subscriptions: Dict[str, Callable] = {}
        self._running = False
        self._reconnect_interval = 5  # 秒
    
    async def connect(self):
        """连接到MQTT broker"""
        try:
            self._client = aiomqtt.Client(
                hostname=self.broker,
                port=self.port,
                keepalive=self.keepalive
            )
            await self._client.__aenter__()
            self.logger.info(f"已连接到 MQTT broker: {self.broker}:{self.port}")
            self._running = True
        except Exception as e:
            self.logger.error(f"MQTT连接失败: {e}")
            raise
    
    async def disconnect(self):
        """断开连接"""
        self._running = False
        if self._client:
            try:
                await self._client.__aexit__(None, None, None)
                self.logger.info("已断开 MQTT 连接")
            except Exception as e:
                self.logger.warning(f"断开连接时出错: {e}")
    
    async def publish(
        self,
        topic: str,
        event_type: str,
        payload: Dict[str, Any],
        correlation_id: Optional[str] = None
    ):
        """
        发布事件
        
        Args:
            topic: MQTT主题（如 sa/vision/face_recognized）
            event_type: 事件类型
            payload: 有效载荷
            correlation_id: 关联ID（用于追踪）
        """
        if not self._client:
            raise RuntimeError("未连接到MQTT broker")
        
        envelope = EventEnvelope(
            event_type=event_type,
            payload=payload,
            source=self.module_name,
            correlation_id=correlation_id
        )
        
        message = envelope.to_json()
        await self._client.publish(topic, message, qos=self.qos)
        self.logger.debug(f"发布事件: {topic} | {event_type}")
    
    async def subscribe(self, topic: str, callback: Callable):
        """
        订阅主题
        
        Args:
            topic: MQTT主题（支持通配符，如 sa/+/health）
            callback: 回调函数 async def callback(envelope: EventEnvelope)
        """
        if not self._client:
            raise RuntimeError("未连接到MQTT broker")
        
        await self._client.subscribe(topic, qos=self.qos)
        self._subscriptions[topic] = callback
        self.logger.info(f"订阅主题: {topic}")
    
    async def start_listening(self):
        """启动消息监听循环（带自动重连）"""
        while self._running:
            try:
                if not self._client:
                    await self.connect()
                    # 重新订阅所有主题
                    for topic in self._subscriptions:
                        await self._client.subscribe(topic, qos=self.qos)
                
                async for message in self._client.messages:
                    await self._handle_message(message)
                    
            except aiomqtt.MqttError as e:
                self.logger.error(f"MQTT错误: {e}，{self._reconnect_interval}秒后重连...")
                await asyncio.sleep(self._reconnect_interval)
                self._client = None
            except Exception as e:
                self.logger.error(f"消息处理错误: {e}", exc_info=True)
    
    async def _handle_message(self, message):
        """处理接收到的消息"""
        try:
            # 解析信封
            envelope = EventEnvelope.from_json(message.payload.decode())
            
            # 查找匹配的回调
            for topic_pattern, callback in self._subscriptions.items():
                if self._topic_matches(message.topic.value, topic_pattern):
                    await callback(envelope)
                    break
        except json.JSONDecodeError as e:
            self.logger.warning(f"消息JSON解析失败: {e}")
        except Exception as e:
            self.logger.error(f"回调执行失败: {e}", exc_info=True)
    
    def _topic_matches(self, topic: str, pattern: str) -> bool:
        """简单的主题匹配（支持+单层通配符）"""
        topic_parts = topic.split('/')
        pattern_parts = pattern.split('/')
        
        if len(topic_parts) != len(pattern_parts):
            return False
        
        for t, p in zip(topic_parts, pattern_parts):
            if p != '+' and p != t:
                return False
        return True


if __name__ == "__main__":
    # 自检模式（简单发布/订阅测试）
    import sys
    
    async def test_pubsub():
        print("=== 事件总线自检 ===")
        
        # 创建发布者和订阅者
        publisher = EventBus(module_name="test_publisher")
        subscriber = EventBus(module_name="test_subscriber")
        
        await publisher.connect()
        await subscriber.connect()
        
        # 订阅测试主题
        received = []
        
        async def test_callback(envelope: EventEnvelope):
            received.append(envelope.payload)
            print(f"✓ 收到消息: {envelope.type} | {envelope.payload}")
        
        await subscriber.subscribe("sa/test/#", test_callback)
        
        # 启动监听（后台任务）
        listen_task = asyncio.create_task(subscriber.start_listening())
        
        # 等待订阅生效
        await asyncio.sleep(0.5)
        
        # 发布测试消息
        await publisher.publish(
            topic="sa/test/ping",
            event_type="test.ping",
            payload={"message": "hello"}
        )
        
        # 等待接收
        await asyncio.sleep(1)
        
        # 清理
        await publisher.disconnect()
        subscriber._running = False
        await subscriber.disconnect()
        listen_task.cancel()
        
        # 验证
        if received:
            print(f"✓ 自检通过，收到 {len(received)} 条消息")
        else:
            print("✗ 自检失败，未收到消息", file=sys.stderr)
            sys.exit(1)
    
    asyncio.run(test_pubsub())
PYCODE
ok "core/event_bus.py"

# 3. 创建测试用例
say "Creating tests/test_event_bus.py..."
cat > "$ROOT/tests/test_event_bus.py" <<'PYTEST'
"""
事件总线测试
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
    
    # 验证字段
    assert envelope.id
    assert envelope.ts
    assert envelope.type == "test.event"
    assert envelope.payload["key"] == "value"
    
    # JSON序列化
    json_str = envelope.to_json()
    parsed = EventEnvelope.from_json(json_str)
    assert parsed.type == envelope.type
    assert parsed.payload == envelope.payload
    
    print("✓ test_envelope")


async def test_pubsub():
    """测试发布订阅"""
    pub = EventBus(module_name="test_pub")
    sub = EventBus(module_name="test_sub")
    
    await pub.connect()
    await sub.connect()
    
    received = []
    
    async def callback(envelope: EventEnvelope):
        received.append(envelope)
    
    await sub.subscribe("sa/test/+", callback)
    
    # 启动监听
    task = asyncio.create_task(sub.start_listening())
    await asyncio.sleep(0.5)
    
    # 发布
    await pub.publish(
        topic="sa/test/event",
        event_type="test.ping",
        payload={"msg": "hello"}
    )
    
    await asyncio.sleep(1)
    
    # 清理
    await pub.disconnect()
    sub._running = False
    await sub.disconnect()
    task.cancel()
    
    assert len(received) == 1
    assert received[0].payload["msg"] == "hello"
    
    print("✓ test_pubsub")


async def main():
    print("=== 事件总线测试 ===")
    await test_envelope()
    await test_pubsub()
    print("=== 所有测试通过 ===")


if __name__ == "__main__":
    asyncio.run(main())
PYTEST
ok "tests/test_event_bus.py"

echo ""
echo "=== EVENT BUS CREATED ==="
