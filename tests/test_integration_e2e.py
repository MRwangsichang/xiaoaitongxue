"""
端到端集成测试 - 验证配置→日志→事件→心跳全链路
"""
import asyncio
import sys
from pathlib import Path
from datetime import datetime

ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(ROOT))

from core.config_loader import load_config
from core.logger import setup_logger
from core.event_bus import EventBus
from core.health import HealthReporter


class IntegrationTest:
    """集成测试套件"""
    
    def __init__(self):
        self.results = {
            "config_load": False,
            "logging": False,
            "pubsub": False,
            "health": False
        }
        self.received_messages = []
        self.received_health = []
    
    async def test_all(self):
        """运行所有测试"""
        print("=" * 60)
        print("端到端集成测试 - 窗口1核心框架验收")
        print("=" * 60)
        
        # 测试1: 配置加载
        print("\n[测试1] 配置加载...")
        try:
            config = load_config()
            assert "mqtt" in config
            assert "logging" in config
            assert config["mqtt"]["broker"] == "localhost"
            self.results["config_load"] = True
            print("✓ 配置加载成功")
        except Exception as e:
            print(f"✗ 配置加载失败: {e}")
            return
        
        # 测试2: 日志系统
        print("\n[测试2] 日志系统...")
        try:
            logger = setup_logger("test_e2e", console=False)
            logger.info("测试日志输出")
            logger.error("测试错误日志（应有建议动作）")
            
            log_file = Path("logs/test_e2e.log")
            if log_file.exists():
                content = log_file.read_text()
                if "测试日志输出" in content and "建议" in content:
                    self.results["logging"] = True
                    print("✓ 日志系统正常")
                else:
                    print("✗ 日志内容不完整")
            else:
                print("✗ 日志文件不存在")
        except Exception as e:
            print(f"✗ 日志系统异常: {e}")
        
        # 测试3: 事件发布/订阅
        print("\n[测试3] 事件总线（发布/订阅）...")
        try:
            await self._test_pubsub()
        except Exception as e:
            print(f"✗ 事件总线测试失败: {e}")
        
        # 测试4: 健康心跳
        print("\n[测试4] 健康心跳...")
        try:
            await self._test_health()
        except Exception as e:
            print(f"✗ 健康心跳测试失败: {e}")
        
        # 汇总结果
        self._print_summary()
    
    async def _test_pubsub(self):
        """测试发布/订阅"""
        # 创建发布者和订阅者
        publisher = EventBus(module_name="test_publisher")
        subscriber = EventBus(module_name="test_subscriber")
        
        # 订阅回调
        async def callback(envelope):
            self.received_messages.append(envelope.payload)
        
        # 启动订阅
        task = asyncio.create_task(
            subscriber.start_listening({"sa/test/integration": callback})
        )
        
        try:
            # 等待订阅生效
            await asyncio.sleep(1)
            
            # 发布3条测试消息
            for i in range(3):
                await publisher.publish(
                    topic="sa/test/integration",
                    event_type="test.message",
                    payload={"index": i, "msg": f"test_{i}"}
                )
            
            # 等待接收
            await asyncio.sleep(2)
            
            # 验证
            if len(self.received_messages) >= 3:
                self.results["pubsub"] = True
                print(f"✓ 发布/订阅正常（收到 {len(self.received_messages)} 条消息）")
            else:
                print(f"✗ 收到消息不足: {len(self.received_messages)}/3")
                
        finally:
            subscriber.stop()
            await asyncio.sleep(0.5)
            task.cancel()
            try:
                await task
            except asyncio.CancelledError:
                pass
    
    async def _test_health(self):
        """测试健康心跳"""
        # 创建心跳报告器
        reporter = HealthReporter(
            module_name="test_health_module",
            interval=2  # 2秒间隔
        )
        
        # 创建订阅者
        subscriber = EventBus(module_name="test_health_sub")
        
        async def health_callback(envelope):
            self.received_health.append(envelope.payload)
        
        # 启动订阅
        task = asyncio.create_task(
            subscriber.start_listening({"sa/sys/health": health_callback})
        )
        
        try:
            await asyncio.sleep(0.5)
            
            # 启动心跳
            await reporter.start()
            
            # 等待接收几次心跳
            await asyncio.sleep(5)
            
            # 停止心跳
            await reporter.stop()
            
            # 验证
            if len(self.received_health) >= 2:
                # 检查心跳内容
                first_beat = self.received_health[0]
                if "module" in first_beat and "status" in first_beat and "uptime" in first_beat:
                    self.results["health"] = True
                    print(f"✓ 健康心跳正常（收到 {len(self.received_health)} 次心跳）")
                    print(f"  模块: {first_beat['module']}, 状态: {first_beat['status']}")
                else:
                    print(f"✗ 心跳格式不正确: {first_beat}")
            else:
                print(f"✗ 收到心跳不足: {len(self.received_health)}/2")
                
        finally:
            subscriber.stop()
            await asyncio.sleep(0.5)
            task.cancel()
            try:
                await task
            except asyncio.CancelledError:
                pass
    
    def _print_summary(self):
        """打印测试汇总"""
        print("\n" + "=" * 60)
        print("测试结果汇总")
        print("=" * 60)
        
        total = len(self.results)
        passed = sum(1 for v in self.results.values() if v)
        
        for name, result in self.results.items():
            status = "✓ PASS" if result else "✗ FAIL"
            print(f"{status}  {name}")
        
        print("-" * 60)
        print(f"通过率: {passed}/{total} ({passed*100//total}%)")
        
        if passed == total:
            print("\n🎉 所有测试通过！窗口1核心框架验收合格！")
            print("=" * 60)
            return True
        else:
            print(f"\n⚠️  有 {total - passed} 项测试未通过，请检查")
            print("=" * 60)
            return False


async def main():
    """主入口"""
    test = IntegrationTest()
    success = await test.test_all()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
