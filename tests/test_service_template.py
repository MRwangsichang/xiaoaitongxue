"""
服务模板测试
"""
import asyncio
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(ROOT))

from modules.template.service_template import ServiceTemplate


async def test_lifecycle():
    """测试服务生命周期"""
    print("=== 测试服务模板 ===")
    
    service = ServiceTemplate("test_template")
    
    await service.start()
    print("✓ 服务启动成功")
    
    await asyncio.sleep(5)
    
    await service.stop()
    print("✓ 服务停止成功")
    
    print("=== 测试通过 ===")


if __name__ == "__main__":
    asyncio.run(test_lifecycle())
