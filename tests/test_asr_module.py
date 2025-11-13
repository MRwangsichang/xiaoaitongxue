"""
ASR Module Tests - Mock mode only
"""
import asyncio
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from core import EventBus


class ASRTester:
    def __init__(self):
        self.received_texts = []
        self.received_health = []
        
    async def run_tests(self):
        print("\n=== ASR Module Tests (Mock Mode) ===\n")
        
        bus = EventBus(module_name="asr_tester")
        
        subscriptions = {
            "sa/asr/text": self._on_text,
            "sa/sys/health": self._on_health,
        }
        
        listen_task = asyncio.create_task(bus.start_listening(subscriptions))
        
        # 等待更长时间确保订阅建立
        print("Setting up MQTT subscriptions...")
        await asyncio.sleep(3)
        print("✓ Subscriptions ready\n")
        
        # Test 1: Text generation
        test1_passed = await self._test_text_generation(bus)
        
        # Test 2: Health heartbeat (需要等待心跳间隔)
        test2_passed = await self._test_health_heartbeat()
        
        # Cleanup
        bus.stop()
        listen_task.cancel()
        try:
            await listen_task
        except asyncio.CancelledError:
            pass
        
        all_passed = all([test1_passed, test2_passed])
        print(f"\n{'='*50}")
        print(f"Test Results: {'✅ ALL PASSED (2/2)' if all_passed else '❌ SOME FAILED'}")
        print(f"{'='*50}\n")
        
        return all_passed
        
    async def _test_text_generation(self, bus):
        print("Test 1: Text Generation (Mock)...")
        self.received_texts.clear()
        
        try:
            await bus.publish(
                topic="sa/asr/cmd/start",
                event_type="cmd.start",
                payload={}
            )
            print("  → Sent start command")
            
            # 等待mock生成完成（5条需要约5秒）
            print("  → Waiting for mock texts (8 seconds)...")
            await asyncio.sleep(8)
            
            if len(self.received_texts) < 3:
                print(f"  ❌ FAIL: Expected ≥3 texts, got {len(self.received_texts)}")
                print(f"     Hint: Check if ASR module is running and publishing to sa/asr/text")
                return False
                
            print(f"  ✅ PASS: Received {len(self.received_texts)} texts:")
            for i, text in enumerate(self.received_texts[:5], 1):
                print(f"     {i}. {text}")
            
            # Send stop
            await bus.publish(
                topic="sa/asr/cmd/stop",
                event_type="cmd.stop",
                payload={}
            )
            print("  → Sent stop command")
            await asyncio.sleep(1)
            
            return True
            
        except Exception as e:
            print(f"  ❌ FAIL: {e}")
            import traceback
            traceback.print_exc()
            return False
            
    async def _test_health_heartbeat(self):
        print("\nTest 2: Health Heartbeat...")
        print("  → Waiting for health messages (12 seconds)...")
        
        try:
            initial_count = len(self.received_health)
            await asyncio.sleep(12)
            
            new_count = len(self.received_health) - initial_count
            
            if new_count < 1:
                print(f"  ❌ FAIL: No new health messages (total: {len(self.received_health)})")
                return False
                
            print(f"  ✅ PASS: Received {new_count} new health message(s)")
            print(f"     Total health messages: {len(self.received_health)}")
            return True
            
        except Exception as e:
            print(f"  ❌ FAIL: {e}")
            return False
            
    async def _on_text(self, envelope):
        text = envelope.payload.get("text", "")
        self.received_texts.append(text)
        print(f"     [Received] {text}")
        
    async def _on_health(self, envelope):
        self.received_health.append(envelope.payload)
        print(f"     [Health] heartbeat #{len(self.received_health)}")


async def main():
    print("\n" + "="*50)
    print("ASR Module Test Suite")
    print("Prerequisites: ASR module must be running")
    print("="*50)
    
    tester = ASRTester()
    success = await tester.run_tests()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
