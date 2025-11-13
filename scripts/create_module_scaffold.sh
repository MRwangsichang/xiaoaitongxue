#!/usr/bin/env bash
set -euo pipefail

# 模块脚手架生成器
# 用法: ./create_module_scaffold.sh <module_name> [DRY_RUN=1|0]

MODULE_NAME="${1:-}"
DRY_RUN="${DRY_RUN:-1}"
ROOT="/home/MRwang/smart_assistant"

say(){ printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }
ok(){ printf "✓ %s\n" "$*"; }
fail(){ printf "✗ %s\n" "$*"; exit 1; }

if [ -z "$MODULE_NAME" ]; then
  echo "用法: $0 <module_name> [DRY_RUN=1|0]"
  echo "示例: DRY_RUN=1 $0 my_sensor"
  exit 1
fi

# 验证模块名（只允许字母数字下划线）
if ! [[ "$MODULE_NAME" =~ ^[a-z][a-z0-9_]*$ ]]; then
  fail "模块名格式错误，只允许小写字母、数字、下划线，且以字母开头"
fi

echo "=== 创建模块脚手架: $MODULE_NAME ==="

if [ "$DRY_RUN" = "1" ]; then
  say "DRY-RUN: 仅预览，不创建实际文件"
  say "  - modules/$MODULE_NAME/"
  say "  - config/${MODULE_NAME}.yml"
  say "  - tests/test_${MODULE_NAME}_module.py"
  say "执行: DRY_RUN=0 $0 $MODULE_NAME 以创建文件"
  exit 0
fi

# 检查是否已存在
if [ -d "$ROOT/modules/$MODULE_NAME" ]; then
  fail "模块已存在: modules/$MODULE_NAME"
fi

say "创建目录结构..."
mkdir -p "$ROOT/modules/$MODULE_NAME"

# 1. 创建模块主文件
say "生成 modules/$MODULE_NAME/${MODULE_NAME}_module.py..."
cat > "$ROOT/modules/$MODULE_NAME/${MODULE_NAME}_module.py" <<PYMODULE
"""
${MODULE_NAME} 模块 - 自动生成的脚手架
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


class ${MODULE_NAME^}Module:
    """${MODULE_NAME} 模块实现"""
    
    def __init__(self):
        self.module_name = "${MODULE_NAME}"
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
    module = ${MODULE_NAME^}Module()
    
    loop = asyncio.get_running_loop()
    
    def signal_handler():
        print(f"\\n收到停止信号，正在优雅退出...")
        asyncio.create_task(module.stop())
    
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, signal_handler)
    
    try:
        await module.run()
    except KeyboardInterrupt:
        print("\\n键盘中断，停止模块...")
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
PYMODULE
ok "modules/$MODULE_NAME/${MODULE_NAME}_module.py"

# 2. 创建__init__.py
cat > "$ROOT/modules/$MODULE_NAME/__init__.py" <<'INIT'
"""${MODULE_NAME} 模块"""
INIT
ok "modules/$MODULE_NAME/__init__.py"

# 3. 创建配置文件
say "生成 config/${MODULE_NAME}.yml..."
cat > "$ROOT/config/${MODULE_NAME}.yml" <<YMLCONFIG
# ${MODULE_NAME} 模块配置

${MODULE_NAME}:
  enabled: true
  health_interval: 30  # 健康心跳间隔（秒）
  
  # TODO: 添加模块特定配置
  # 示例:
  # device_path: /dev/ttyUSB0
  # timeout: 5
YMLCONFIG
ok "config/${MODULE_NAME}.yml"

# 4. 创建测试文件
say "生成 tests/test_${MODULE_NAME}_module.py..."
cat > "$ROOT/tests/test_${MODULE_NAME}_module.py" <<PYTEST
"""
${MODULE_NAME} 模块测试
"""
import asyncio
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(ROOT))

from modules.${MODULE_NAME}.${MODULE_NAME}_module import ${MODULE_NAME^}Module
from core.event_bus import EventBus


async def test_basic_lifecycle():
    """测试基本生命周期"""
    print("=== 测试 ${MODULE_NAME} 模块生命周期 ===")
    
    module = ${MODULE_NAME^}Module()
    
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
    
    module = ${MODULE_NAME^}Module()
    
    # 订阅错误主题
    subscriber = EventBus(module_name="test_sub")
    received_errors = []
    
    async def error_callback(envelope):
        received_errors.append(envelope.payload)
    
    task = asyncio.create_task(
        subscriber.start_listening({f"sa/${MODULE_NAME}/error": error_callback})
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
    
    module = ${MODULE_NAME^}Module()
    
    # 订阅心跳主题
    subscriber = EventBus(module_name="test_sub")
    received_health = []
    
    async def health_callback(envelope):
        received_health.append(envelope.payload)
    
    task = asyncio.create_task(
        subscriber.start_listening({f"sa/${MODULE_NAME}/health": health_callback})
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
    print(f"${MODULE_NAME} 模块测试套件")
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
PYTEST
ok "tests/test_${MODULE_NAME}_module.py"

# 5. 创建README
say "生成 modules/${MODULE_NAME}/README.md..."
cat > "$ROOT/modules/${MODULE_NAME}/README.md" <<README
# ${MODULE_NAME} 模块

## 功能说明

TODO: 描述模块功能

## 主题规范

### 订阅
- \`sa/${MODULE_NAME}/cmd/#\` - 接收命令

### 发布
- \`sa/${MODULE_NAME}/event/#\` - 事件结果
- \`sa/${MODULE_NAME}/health\` - 健康心跳
- \`sa/${MODULE_NAME}/error\` - 错误报告

## 配置

参见 \`config/${MODULE_NAME}.yml\`

## 测试

\`\`\`bash
python3 tests/test_${MODULE_NAME}_module.py
\`\`\`

## 运行

\`\`\`bash
python3 modules/${MODULE_NAME}/${MODULE_NAME}_module.py
\`\`\`
README
ok "modules/${MODULE_NAME}/README.md"

echo ""
echo "=== 模块脚手架创建完成 ==="
echo ""
echo "生成文件:"
echo "  ✓ modules/${MODULE_NAME}/${MODULE_NAME}_module.py"
echo "  ✓ modules/${MODULE_NAME}/__init__.py"
echo "  ✓ modules/${MODULE_NAME}/README.md"
echo "  ✓ config/${MODULE_NAME}.yml"
echo "  ✓ tests/test_${MODULE_NAME}_module.py"
echo ""
echo "下一步:"
echo "  1. 编辑 config/${MODULE_NAME}.yml 添加配置"
echo "  2. 实现 _process_command() 业务逻辑"
echo "  3. 运行测试: python3 tests/test_${MODULE_NAME}_module.py"
echo ""
