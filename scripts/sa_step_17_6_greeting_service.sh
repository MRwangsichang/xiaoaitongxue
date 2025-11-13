#!/usr/bin/env bash
set -euo pipefail
DRY_RUN="${DRY_RUN:-1}"

say(){ printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"

say "=== 第17.6步：创建问候服务 ==="

# 1. 创建目录结构
if [ "$DRY_RUN" = "0" ]; then
    mkdir -p "$ROOT/modules/greeting"
    say "✓ 创建目录: modules/greeting/"
else
    say "DRY-RUN: 将创建 modules/greeting/"
fi

# 2. 创建问候服务配置文件
if [ "$DRY_RUN" = "0" ]; then
    cat > "$ROOT/config/greeting.yml" <<'GREETING_CONFIG_EOF'
# Greeting Service Configuration

# ==================== MQTT (required) ====================
mqtt:
  broker: localhost
  port: 1883
  qos: 1
  keepalive: 60

# ==================== Logging (required) ====================
logging:
  level: INFO
  dir: logs
  rotate_days: 7

# ==================== System (required) ====================
system:
  project_root: /home/MRwang/smart_assistant
  service_prefix: sa

# ==================== Greeting-specific config ====================
# 订阅的视觉事件主题
subscribe_topic: "sa/vision/person_detected"

# 发布的TTS主题
tts_topic: "sa/tts/say"

# GROK场景配置文件路径
grok_scenarios_file: "config/grok_scenarios.yaml"

# 问候冷却时间（秒）- 避免短时间内重复问候
cooldown_seconds: 300

# 健康心跳间隔（秒）
health_interval: 10

# 时间段定义（小时）
time_periods:
  morning: [5, 11]      # 5:00-11:59
  afternoon: [12, 17]   # 12:00-17:59
  evening: [18, 23]     # 18:00-23:59
  night: [0, 4]         # 0:00-4:59
GREETING_CONFIG_EOF
    say "✓ 创建配置: config/greeting.yml"
else
    say "DRY-RUN: 将创建 config/greeting.yml"
fi

# 3. 创建问候服务主模块
if [ "$DRY_RUN" = "0" ]; then
    cat > "$ROOT/modules/greeting/greeting_service.py" <<'GREETING_SERVICE_EOF'
"""
Greeting Service - 人脸识别问候服务
功能：监听视觉识别事件，调用GROK生成问候语，发送到TTS播报
"""
import asyncio
import time
import yaml
from datetime import datetime
from typing import Optional, Dict
from pathlib import Path

from core import get_logger, load_config, HealthReporter
from core.event_bus import EventBus, EventEnvelope
from modules.llm.grok_client import GrokClient


class GreetingService:
    """问候服务"""
    
    def __init__(self, config_path: str = "config/greeting.yml"):
        self.config = load_config(config_path)
        self.logger = get_logger("greeting")
        
        self.bus: Optional[EventBus] = None
        self.health: Optional[HealthReporter] = None
        self.grok: Optional[GrokClient] = None
        
        # 加载GROK场景配置
        self.grok_scenarios = self._load_grok_scenarios()
        
        # 冷却管理（防止短时间重复问候）
        self.last_greeting_time: Dict[str, float] = {}
        self.cooldown_seconds = self.config.get("cooldown_seconds", 300)
        
        self.running = False
    
    def _load_grok_scenarios(self) -> dict:
        """加载GROK场景配置"""
        scenarios_file = self.config.get("grok_scenarios_file", "config/grok_scenarios.yaml")
        scenarios_path = Path(self.config["system"]["project_root"]) / scenarios_file
        
        try:
            with open(scenarios_path, "r", encoding="utf-8") as f:
                scenarios = yaml.safe_load(f)
            self.logger.info(f"✓ 加载GROK场景配置: {scenarios_path}")
            return scenarios
        except Exception as e:
            self.logger.error(f"加载GROK场景配置失败: {e}")
            raise
    
    def _get_time_period(self) -> str:
        """获取当前时间段"""
        current_hour = datetime.now().hour
        periods = self.config.get("time_periods", {})
        
        for period_name, (start_hour, end_hour) in periods.items():
            if start_hour <= current_hour <= end_hour:
                return self.grok_scenarios["face_greeting"]["time_periods"][period_name]
        
        # 默认返回"晚上"
        return self.grok_scenarios["face_greeting"]["time_periods"]["evening"]
    
    def _check_cooldown(self, person_id: str) -> bool:
        """检查是否在冷却期内"""
        now = time.time()
        last_time = self.last_greeting_time.get(person_id, 0)
        
        if now - last_time < self.cooldown_seconds:
            remaining = int(self.cooldown_seconds - (now - last_time))
            self.logger.debug(f"冷却期内，跳过问候 (剩余{remaining}秒)")
            return False
        
        self.last_greeting_time[person_id] = now
        return True
    
    async def _generate_greeting(self, person_id: str, time_period: str) -> str:
        """调用GROK生成问候语"""
        try:
            # 获取问候场景配置
            greeting_config = self.grok_scenarios["face_greeting"]
            prompt_template = greeting_config["prompt_template"]
            
            # 替换时间段变量
            prompt = prompt_template.format(time_period=time_period)
            
            # 调用GROK（不需要对话历史，max_tokens少一点）
            self.logger.info(f"调用GROK生成问候语 (时间段: {time_period})...")
            greeting = await self.grok.chat(
                user_message=prompt,
                conversation_history=None,
                max_tokens=50
            )
            
            self.logger.info(f"GROK回复: {greeting}")
            return greeting.strip()
            
        except Exception as e:
            self.logger.error(f"生成问候语失败: {e}", exc_info=True)
            # 兜底回复
            return "王总，您回来啦！"
    
    async def _handle_person_detected(self, envelope: EventEnvelope):
        """处理人脸识别事件"""
        try:
            payload = envelope.payload
            person_id = payload.get("person_id", "unknown")
            confidence = payload.get("confidence", 0)
            
            self.logger.info(f"收到人脸识别事件: person_id={person_id}, confidence={confidence:.2f}")
            
            # 只处理王总的识别事件
            if person_id != "wangzong":
                self.logger.debug(f"非王总识别事件，跳过 (person_id={person_id})")
                return
            
            # 检查冷却期
            if not self._check_cooldown(person_id):
                return
            
            # 获取时间段
            time_period = self._get_time_period()
            self.logger.info(f"当前时间段: {time_period}")
            
            # 生成问候语
            greeting_text = await self._generate_greeting(person_id, time_period)
            
            # 发布到TTS
            tts_topic = self.config.get("tts_topic", "sa/tts/say")
            await self.bus.publish(
                topic=tts_topic,
                event_type="tts.say",
                payload={
                    "text": greeting_text,
                    "voice": "default",
                    "priority": 5
                }
            )
            
            self.logger.info(f"✓ 问候流程完成: {greeting_text}")
            
        except Exception as e:
            self.logger.error(f"处理人脸识别事件失败: {e}", exc_info=True)
    
    async def start(self):
        """启动问候服务"""
        self.logger.info("=== 问候服务启动 ===")
        
        # 1. 初始化GROK客户端
        self.grok = GrokClient(self.logger)
        self.logger.info("✓ GROK客户端初始化完成")
        
        # 2. 初始化EventBus
        self.bus = EventBus(module_name="greeting")
        
        # 3. 初始化健康心跳
        self.health = HealthReporter(
            module_name="greeting",
            interval=self.config.get("health_interval", 10)
        )
        await self.health.start()
        
        # 4. 订阅人脸识别事件
        subscribe_topic = self.config.get("subscribe_topic", "sa/vision/person_detected")
        await self.bus.start_listening({
            subscribe_topic: self._handle_person_detected
        })
        
        self.logger.info(f"✓ 订阅主题: {subscribe_topic}")
        self.logger.info("=== 问候服务就绪 ===")
        
        self.running = True
        
        # 保持运行
        try:
            while self.running:
                await asyncio.sleep(1)
        except KeyboardInterrupt:
            self.logger.info("收到停止信号")
        finally:
            await self.stop()
    
    async def stop(self):
        """停止服务"""
        self.logger.info("正在停止问候服务...")
        self.running = False
        
        if self.health:
            await self.health.stop()
        
        if self.bus:
            await self.bus.stop()
        
        self.logger.info("✓ 问候服务已停止")


async def main():
    """主函数"""
    service = GreetingService()
    await service.start()


if __name__ == "__main__":
    asyncio.run(main())
GREETING_SERVICE_EOF
    say "✓ 创建服务: modules/greeting/greeting_service.py"
else
    say "DRY-RUN: 将创建 modules/greeting/greeting_service.py"
fi

# 4. 创建__init__.py
if [ "$DRY_RUN" = "0" ]; then
    cat > "$ROOT/modules/greeting/__init__.py" <<'INIT_EOF'
"""Greeting Service Module"""
from .greeting_service import GreetingService

__all__ = ["GreetingService"]
INIT_EOF
    say "✓ 创建: modules/greeting/__init__.py"
else
    say "DRY-RUN: 将创建 modules/greeting/__init__.py"
fi

# 5. 创建启动脚本
if [ "$DRY_RUN" = "0" ]; then
    cat > "$ROOT/scripts/start_greeting.sh" <<'START_GREETING_EOF'
#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/MRwang/smart_assistant"
cd "$ROOT" || exit 1

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

say "=== 启动问候服务 ==="

# 设置环境变量
export PYTHONPATH="$ROOT:${PYTHONPATH:-}"

# 加载.env.local（GROK API Key等）
if [ -f "${ROOT}/.env.local" ]; then
    set -o allexport
    source "${ROOT}/.env.local"
    set +o allexport
    say "✓ 环境变量已加载"
fi

say "当前目录: $(pwd)"
say ""

# 启动问候服务
python3 modules/greeting/greeting_service.py
START_GREETING_EOF
    chmod +x "$ROOT/scripts/start_greeting.sh"
    say "✓ 创建启动脚本: scripts/start_greeting.sh (可执行)"
else
    say "DRY-RUN: 将创建 scripts/start_greeting.sh"
fi

say ""
if [ "$DRY_RUN" = "1" ]; then
    say "✓ DRY-RUN: 所有操作仅预演，未修改系统"
else
    say "✓ 第17.6步完成！问候服务已创建"
    say ""
    say "下一步："
    say "  1. 启动问候服务: bash scripts/start_greeting.sh"
    say "  2. 或者用proxychains4: proxychains4 bash scripts/start_greeting.sh"
    say "  3. 触发人脸识别，观察问候流程"
fi
