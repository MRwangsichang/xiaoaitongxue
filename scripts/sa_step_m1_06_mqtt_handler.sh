#!/bin/bash
# sa_step_m1_06_mqtt_handler.sh - M1第6步：MQTT 命令处理器

set -e

PROJECT_ROOT="/home/MRwang/smart_assistant"
DRY_RUN=${DRY_RUN:-0}

cd "$PROJECT_ROOT"

echo "=== [$([ $DRY_RUN -eq 1 ] && echo 'DRY_RUN' || echo 'REAL')] 创建 MQTT 命令处理器 ==="

# 1. 创建 mqtt_handler.py
if [ $DRY_RUN -eq 1 ]; then
    echo "[DRY_RUN] 创建 modules/memory/mqtt_handler.py"
else
    cat > modules/memory/mqtt_handler.py <<'EOF'
"""
Memory MQTT Handler
MQTT 命令处理器 - 订阅命令、发布事件
"""

import json
import logging
import time
from typing import Dict, Any, Optional, Callable
import paho.mqtt.client as mqtt

from modules.memory.db import MemoryDB
from modules.memory.models import (
    Command, Event, MemoryItem,
    AddCommandPayload, QueryCommandPayload,
    UpdateCommandPayload, DeleteCommandPayload,
    ConfirmCommandPayload
)
from modules.memory.normalizer import get_normalizer
from core.config import load_config


class MemoryMQTTHandler:
    """Memory 模块的 MQTT 处理器"""

    def __init__(self, config_path: str = '/home/MRwang/smart_assistant'):
        """
        初始化 MQTT 处理器

        Args:
            config_path: 项目根目录
        """
        # 加载配置
        self.config = load_config('memory', config_path)

        # 初始化日志
        self.logger = logging.getLogger('memory.mqtt')

        # 初始化数据库
        db_path = self.config['memory']['db_path']
        slow_threshold = self.config['memory']['query']['slow_threshold_ms']
        self.db = MemoryDB(db_path, slow_threshold)

        # 初始化归一化器
        self.normalizer = get_normalizer()

        # MQTT 配置
        mqtt_cfg = self.config['mqtt']
        self.broker = mqtt_cfg['broker']
        self.port = mqtt_cfg['port']
        self.client_id = mqtt_cfg['client_id']
        self.cmd_prefix = mqtt_cfg['topics']['cmd_prefix']
        self.event_prefix = mqtt_cfg['topics']['event_prefix']

        # 创建 MQTT 客户端
        self.client = mqtt.Client(client_id=self.client_id)
        self.client.on_connect = self._on_connect
        self.client.on_message = self._on_message
        self.client.on_disconnect = self._on_disconnect

        # 命令路由表
        self.command_handlers: Dict[str, Callable] = {
            f'{self.cmd_prefix}/add': self._handle_add,
            f'{self.cmd_prefix}/query': self._handle_query,
            f'{self.cmd_prefix}/update': self._handle_update,
            f'{self.cmd_prefix}/delete': self._handle_delete,
            f'{self.cmd_prefix}/confirm': self._handle_confirm,
            f'{self.cmd_prefix}/get': self._handle_get,
            f'{self.cmd_prefix}/purge_expired': self._handle_purge_expired,
        }

        self.running = False

    def _on_connect(self, client, userdata, flags, rc):
        """连接回调"""
        if rc == 0:
            self.logger.info(f"✅ 已连接到 MQTT Broker: {self.broker}:{self.port}")

            # 订阅所有命令主题
            for topic in self.command_handlers.keys():
                client.subscribe(topic)
                self.logger.info(f"📡 订阅主题: {topic}")
        else:
            self.logger.error(f"❌ MQTT 连接失败，错误代码: {rc}")

    def _on_disconnect(self, client, userdata, rc):
        """断开连接回调"""
        if rc != 0:
            self.logger.warning(f"⚠️ 与 MQTT Broker 意外断开，错误代码: {rc}")
        else:
            self.logger.info("🔌 已断开 MQTT 连接")

    def _on_message(self, client, userdata, msg):
        """消息回调"""
        try:
            topic = msg.topic
            payload_str = msg.payload.decode('utf-8')

            self.logger.info(f"📨 收到命令 | topic={topic}")
            self.logger.debug(f"   payload={payload_str[:200]}")

            # 解析 JSON
            try:
                payload = json.loads(payload_str)
            except json.JSONDecodeError as e:
                self.logger.error(f"JSON 解析失败: {e}")
                self._publish_error(topic, "JSON_PARSE_ERROR", str(e))
                return

            # 路由到对应处理器
            handler = self.command_handlers.get(topic)
            if handler:
                handler(payload)
            else:
                self.logger.warning(f"未知命令主题: {topic}")
                self._publish_error(topic, "UNKNOWN_COMMAND", f"Unknown topic: {topic}")

        except Exception as e:
            self.logger.error(f"消息处理异常: {e}", exc_info=True)
            self._publish_error(msg.topic, "INTERNAL_ERROR", str(e))

    def _handle_add(self, payload: Dict[str, Any]):
        """处理添加命令"""
        try:
            # 验证 payload
            cmd_payload = AddCommandPayload(**payload.get('payload', {}))

            # slot 归一化
            normalized_slot = self.normalizer.normalize(cmd_payload.slot)

            # 构建 MemoryItem
            item_dict = {
                'person_id': cmd_payload.person_id,
                'slot': normalized_slot,
                'value': cmd_payload.value,
                'type': cmd_payload.mem_type,
                'source': cmd_payload.source,
                'confidence': cmd_payload.confidence,
                'speakable': cmd_payload.speakable,
                'ttl_s': cmd_payload.ttl_s,
                'tags': cmd_payload.tags,
            }

            # 根据置信度设置状态
            confidence = cmd_payload.confidence
            if cmd_payload.mem_type == 'profile' and confidence >= 0.90:
                item_dict['status'] = 'pending_confirm'
            elif confidence >= 0.80:
                item_dict['status'] = 'active'
            else:
                item_dict['status'] = 'candidate'

            # 写入数据库
            item_id = self.db.add(item_dict)

            # 发布成功事件
            self._publish_event('added', {
                'item_id': item_id,
                'person_id': cmd_payload.person_id,
                'slot': normalized_slot,
                'status': item_dict['status']
            })

            self.logger.info(f"✅ 添加成功 | id={item_id} | slot={normalized_slot} | status={item_dict['status']}")

        except Exception as e:
            self.logger.error(f"添加失败: {e}", exc_info=True)
            self._publish_error('add', 'ADD_FAILED', str(e))

    def _handle_query(self, payload: Dict[str, Any]):
        """处理查询命令"""
        try:
            # 验证 payload
            cmd_payload = QueryCommandPayload(**payload.get('payload', {}))

            # 查询数据库
            items = self.db.query(
                person_id=cmd_payload.person_id,
                types=cmd_payload.types,
                status=cmd_payload.status,
                speakable=cmd_payload.speakable,
                limit=cmd_payload.limit
            )

            # 发布响应
            response = {
                'id': payload.get('id', 'unknown'),
                'type': 'resp.query',
                'payload': {
                    'items': items,
                    'total': len(items)
                }
            }

            # 发布到响应主题（或原主题的 /resp 后缀）
            response_topic = f"{self.event_prefix}/query_response"
            self.client.publish(response_topic, json.dumps(response, ensure_ascii=False))

            self.logger.info(f"✅ 查询成功 | person_id={cmd_payload.person_id} | 结果数={len(items)}")

        except Exception as e:
            self.logger.error(f"查询失败: {e}", exc_info=True)
            self._publish_error('query', 'QUERY_FAILED', str(e))

    def _handle_update(self, payload: Dict[str, Any]):
        """处理更新命令"""
        try:
            cmd_payload = UpdateCommandPayload(**payload.get('payload', {}))

            # 如果更新 slot，需要归一化
            updates = cmd_payload.updates.copy()
            if 'slot' in updates:
                updates['slot'] = self.normalizer.normalize(updates['slot'])

            # 更新数据库
            success = self.db.update(cmd_payload.id, updates)

            if success:
                self._publish_event('updated', {
                    'item_id': cmd_payload.id,
                    'updates': list(updates.keys())
                })
                self.logger.info(f"✅ 更新成功 | id={cmd_payload.id}")
            else:
                self._publish_error('update', 'UPDATE_FAILED', f"记录不存在: {cmd_payload.id}")

        except Exception as e:
            self.logger.error(f"更新失败: {e}", exc_info=True)
            self._publish_error('update', 'UPDATE_FAILED', str(e))

    def _handle_delete(self, payload: Dict[str, Any]):
        """处理删除命令"""
        try:
            cmd_payload = DeleteCommandPayload(**payload.get('payload', {}))

            success = self.db.delete(cmd_payload.id, hard=cmd_payload.hard)

            if success:
                self._publish_event('deleted', {
                    'item_id': cmd_payload.id,
                    'hard': cmd_payload.hard
                })
                self.logger.info(f"✅ 删除成功 | id={cmd_payload.id} | hard={cmd_payload.hard}")
            else:
                self._publish_error('delete', 'DELETE_FAILED', f"记录不存在: {cmd_payload.id}")

        except Exception as e:
            self.logger.error(f"删除失败: {e}", exc_info=True)
            self._publish_error('delete', 'DELETE_FAILED', str(e))

    def _handle_confirm(self, payload: Dict[str, Any]):
        """处理确认命令（pending_confirm → active）"""
        try:
            cmd_payload = ConfirmCommandPayload(**payload.get('payload', {}))

            if cmd_payload.confirmed:
                # 确认 → active
                success = self.db.update(cmd_payload.id, {'status': 'active'})
                status = 'active'
            else:
                # 拒绝 → deleted
                success = self.db.update(cmd_payload.id, {'status': 'deleted'})
                status = 'deleted'

            if success:
                self._publish_event('confirmed', {
                    'item_id': cmd_payload.id,
                    'confirmed': cmd_payload.confirmed,
                    'new_status': status
                })
                self.logger.info(f"✅ 确认成功 | id={cmd_payload.id} | status={status}")
            else:
                self._publish_error('confirm', 'CONFIRM_FAILED', f"记录不存在: {cmd_payload.id}")

        except Exception as e:
            self.logger.error(f"确认失败: {e}", exc_info=True)
            self._publish_error('confirm', 'CONFIRM_FAILED', str(e))

    def _handle_get(self, payload: Dict[str, Any]):
        """处理获取单条命令"""
        try:
            item_id = payload.get('payload', {}).get('id')
            if not item_id:
                raise ValueError("缺少 id 参数")

            item = self.db.get(item_id)

            if item:
                response = {
                    'id': payload.get('id', 'unknown'),
                    'type': 'resp.get',
                    'payload': {'item': item}
                }
                response_topic = f"{self.event_prefix}/get_response"
                self.client.publish(response_topic, json.dumps(response, ensure_ascii=False))
                self.logger.info(f"✅ 获取成功 | id={item_id}")
            else:
                self._publish_error('get', 'NOT_FOUND', f"记录不存在: {item_id}")

        except Exception as e:
            self.logger.error(f"获取失败: {e}", exc_info=True)
            self._publish_error('get', 'GET_FAILED', str(e))

    def _handle_purge_expired(self, payload: Dict[str, Any]):
        """处理清理过期命令"""
        try:
            count = self.db.purge_expired()

            self._publish_event('expired', {
                'count': count
            })

            self.logger.info(f"✅ 清理过期记录 | 数量={count}")

        except Exception as e:
            self.logger.error(f"清理失败: {e}", exc_info=True)
            self._publish_error('purge_expired', 'PURGE_FAILED', str(e))

    def _publish_event(self, event_type: str, payload: Dict[str, Any]):
        """发布事件"""
        try:
            event = Event(
                type=f'event.{event_type}',
                payload=payload
            )

            topic = f"{self.event_prefix}/{event_type}"
            message = event.model_dump_json(exclude_none=True)

            self.client.publish(topic, message)
            self.logger.debug(f"📤 发布事件 | topic={topic}")

        except Exception as e:
            self.logger.error(f"发布事件失败: {e}", exc_info=True)

    def _publish_error(self, operation: str, code: str, message: str):
        """发布错误事件"""
        try:
            event = Event(
                type='event.error',
                payload={'operation': operation},
                error=message,
                code=code
            )

            topic = f"{self.event_prefix}/error"
            self.client.publish(topic, event.model_dump_json(exclude_none=True))

            self.logger.error(f"📤 发布错误事件 | code={code} | msg={message}")

        except Exception as e:
            self.logger.error(f"发布错误事件失败: {e}", exc_info=True)

    def start(self):
        """启动 MQTT 处理器"""
        try:
            self.logger.info(f"🚀 启动 Memory MQTT Handler...")
            self.logger.info(f"   Broker: {self.broker}:{self.port}")
            self.logger.info(f"   Client ID: {self.client_id}")

            # 连接 broker
            self.client.connect(self.broker, self.port, keepalive=60)

            # 启动循环
            self.running = True
            self.client.loop_start()

            self.logger.info("✅ MQTT Handler 已启动，等待命令...")

            # 保持运行
            while self.running:
                time.sleep(1)

        except KeyboardInterrupt:
            self.logger.info("⏹️ 收到停止信号")
            self.stop()
        except Exception as e:
            self.logger.error(f"启动失败: {e}", exc_info=True)
            self.stop()

    def stop(self):
        """停止 MQTT 处理器"""
        self.logger.info("🛑 正在停止 MQTT Handler...")

        self.running = False

        if self.client:
            self.client.loop_stop()
            self.client.disconnect()

        if self.db:
            self.db.close()

        self.logger.info("✅ MQTT Handler 已停止")


if __name__ == '__main__':
    # 配置日志
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )

    # 启动处理器
    handler = MemoryMQTTHandler()
    handler.start()
EOF
    echo "✅ 创建 modules/memory/mqtt_handler.py"
fi

echo ""
echo "=== 创建测试脚本 ==="

if [ $DRY_RUN -eq 1 ]; then
    echo "[DRY_RUN] 创建 tests/test_memory/test_mqtt.sh"
else
    cat > tests/test_memory/test_mqtt.sh <<'TESTEOF'
#!/bin/bash
# MQTT 命令测试脚本

set -e

MQTT_BROKER="localhost"
CMD_PREFIX="sa/memory/cmd"
EVENT_PREFIX="sa/memory/event"

echo "=== Memory MQTT 测试脚本 ==="
echo ""
echo "📌 使用方法："
echo "   终端1: python3 -m modules.memory.mqtt_handler"
echo "   终端2: ./tests/test_memory/test_mqtt.sh"
echo ""

# 测试1: 添加记忆
echo "--- 测试1: 添加记忆 ---"
mosquitto_pub -h "$MQTT_BROKER" -t "${CMD_PREFIX}/add" -m '{
  "id": "test-add-001",
  "ts": "2025-11-18T14:00:00+09:00",
  "type": "cmd.add",
  "payload": {
    "person_id": "wangzong",
    "mem_type": "short",
    "slot": "购物",
    "value": "今天去山姆买了很多东西",
    "confidence": 0.88,
    "speakable": true,
    "ttl_s": 432000,
    "source": "grok"
  }
}'
echo "✅ 已发送 add 命令"
sleep 1

# 测试2: 查询记忆
echo ""
echo "--- 测试2: 查询记忆 ---"
mosquitto_pub -h "$MQTT_BROKER" -t "${CMD_PREFIX}/query" -m '{
  "id": "test-query-001",
  "type": "cmd.query",
  "payload": {
    "person_id": "wangzong",
    "types": ["short"],
    "status": "active",
    "speakable": true,
    "limit": 5
  }
}'
echo "✅ 已发送 query 命令"
sleep 1

# 测试3: 添加 profile（需要确认）
echo ""
echo "--- 测试3: 添加 profile（高置信度） ---"
mosquitto_pub -h "$MQTT_BROKER" -t "${CMD_PREFIX}/add" -m '{
  "id": "test-add-002",
  "type": "cmd.add",
  "payload": {
    "person_id": "wangzong",
    "mem_type": "profile",
    "slot": "工作",
    "value": "现在在做智能助手项目",
    "confidence": 0.92,
    "speakable": true,
    "source": "grok"
  }
}'
echo "✅ 已发送 add 命令（profile，应进入 pending_confirm）"
sleep 1

echo ""
echo "=== 测试完成 ==="
echo "💡 提示：在另一个终端运行以下命令监听事件："
echo "   mosquitto_sub -h localhost -v -t 'sa/memory/event/#'"
TESTEOF
    chmod +x tests/test_memory/test_mqtt.sh
    echo "✅ 创建 tests/test_memory/test_mqtt.sh"
fi

echo ""
echo "=== 创建启动脚本 ==="

if [ $DRY_RUN -eq 1 ]; then
    echo "[DRY_RUN] 创建 scripts/start_memory.sh"
else
    mkdir -p scripts
    cat > scripts/start_memory.sh <<'STARTEOF'
#!/bin/bash
# 启动 Memory MQTT Handler

cd /home/MRwang/smart_assistant

echo "🚀 启动 Memory Orchestrator MQTT Handler..."
echo ""

# 激活虚拟环境（如果有）
# source venv/bin/activate

# 启动 MQTT Handler
python3 -m modules.memory.mqtt_handler
STARTEOF
    chmod +x scripts/start_memory.sh
    echo "✅ 创建 scripts/start_memory.sh"
fi

echo ""
echo "=== 验证依赖 ==="

if [ $DRY_RUN -eq 1 ]; then
    echo "[DRY_RUN] 检查 paho-mqtt"
else
    if python3 -c "import paho.mqtt.client" 2>/dev/null; then
        echo "✅ paho-mqtt 已安装"
    else
        echo "⚠️  paho-mqtt 未安装，正在安装..."
        pip3 install paho-mqtt --user
    fi
fi

echo ""
echo "=== 完成 ==="
echo "产物："
echo "  - modules/memory/mqtt_handler.py"
echo "  - tests/test_memory/test_mqtt.sh"
echo "  - scripts/start_memory.sh"
echo ""
echo "📌 下一步操作（手动）："
echo ""
echo "1️⃣ 在新终端（终端6）启动 Memory Handler:"
echo "   cd /home/MRwang/smart_assistant"
echo "   python3 -m modules.memory.mqtt_handler"
echo ""
echo "2️⃣ 在另一终端监听事件（可选）:"
echo "   mosquitto_sub -h localhost -v -t 'sa/memory/event/#'"
echo ""
echo "3️⃣ 在当前终端运行测试:"
echo "   ./tests/test_memory/test_mqtt.sh"
