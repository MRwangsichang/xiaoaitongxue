#!/usr/bin/env bash
set -euo pipefail
DRY_RUN="${DRY_RUN:-1}"

say(){ printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
SCANNER_FILE="$ROOT/modules/vision/scanner.py"
START_SCRIPT="$ROOT/scripts/start_scanner.sh"

say "=== 第16步：创建扫描服务主程序 ==="

# 1. 创建scanner.py
if [ "$DRY_RUN" = "0" ]; then
    say "创建扫描服务: $SCANNER_FILE"
    cat > "$SCANNER_FILE" <<'PYTHON_EOF'
#!/usr/bin/env python3
"""
视觉扫描服务 - 定时人脸识别 + MQTT事件发布
"""
import asyncio
import os
import sys
import signal
import subprocess
import time
from datetime import datetime, timedelta
from typing import Dict, Optional

# 确保项目根目录在路径中
ROOT = "/home/MRwang/smart_assistant"
sys.path.insert(0, ROOT)

from core.logger import get_logger
from core.event_bus import EventBus
from modules.vision.recognizer.face_recognizer import FaceRecognizer
import yaml


class VisionScanner:
    """视觉扫描服务"""
    
    def __init__(self, config_path: str):
        self.logger = get_logger("vision.scanner")
        self.config_path = config_path
        self.config = None
        self.mode_config = None
        
        # 组件
        self.recognizer = None
        self.event_bus = None
        
        # 冷却记录（内存存储）
        self.cooldown_records: Dict[str, datetime] = {}  # {person: last_seen_time}
        self.last_any_person_time: Optional[datetime] = None  # 全局冷却
        
        # 运行控制
        self.running = False
        
    def load_config(self):
        """加载配置文件"""
        self.logger.info(f"加载配置: {self.config_path}")
        with open(self.config_path, "r", encoding="utf-8") as f:
            self.config = yaml.safe_load(f)
        
        mode = self.config["mode"]
        self.mode_config = self.config[mode]
        
        self.logger.info(f"当前模式: {mode}")
        self.logger.info(f"扫描间隔: {self.mode_config['scan_interval']}秒")
        self.logger.info(f"全局冷却: {self.mode_config['cooldown_global']}秒")
        self.logger.info(f"单人冷却: {self.mode_config['cooldown_person']}秒")
    
    def init_components(self):
        """初始化组件"""
        # 1. 初始化识别器
        self.logger.info("初始化人脸识别器...")
        vision_cfg = self.config["vision"]
        self.recognizer = FaceRecognizer(
            model_path=vision_cfg["model_path"],
            cascade_path=vision_cfg["cascade_path"]
        )
        
        if not self.recognizer.load_model():
            raise RuntimeError("识别模型加载失败")
        
        self.logger.info("✓ 识别器就绪")
        
        # 2. 初始化EventBus
        self.logger.info("初始化MQTT事件总线...")
        mqtt_cfg = self.config["mqtt"]
        self.event_bus = EventBus(
            broker=mqtt_cfg["broker"],
            port=mqtt_cfg["port"]
        )
        self.logger.info("✓ EventBus就绪")
    
    def is_in_cooldown(self, person: str) -> bool:
        """检查某人是否在冷却期"""
        if person not in self.cooldown_records:
            return False
        
        last_seen = self.cooldown_records[person]
        cooldown_duration = timedelta(seconds=self.mode_config["cooldown_person"])
        
        if datetime.now() - last_seen < cooldown_duration:
            remaining = cooldown_duration - (datetime.now() - last_seen)
            self.logger.debug(f"{person} 在单人冷却期（剩余 {remaining.seconds}秒）")
            return True
        
        return False
    
    def is_global_cooldown(self) -> bool:
        """检查是否在全局冷却期"""
        if self.last_any_person_time is None:
            return False
        
        cooldown_duration = timedelta(seconds=self.mode_config["cooldown_global"])
        
        if datetime.now() - self.last_any_person_time < cooldown_duration:
            remaining = cooldown_duration - (datetime.now() - self.last_any_person_time)
            self.logger.debug(f"全局冷却期（剩余 {remaining.seconds}秒）")
            return True
        
        return False
    
    def update_cooldown(self, person: str):
        """更新冷却记录"""
        now = datetime.now()
        self.cooldown_records[person] = now
        self.last_any_person_time = now
        self.logger.info(f"更新冷却记录: {person}")
    
    def stop_camera_services(self):
        """停止占用相机的服务"""
        self.logger.debug("停止相机占用服务...")
        
        # 停止系统服务
        subprocess.run(
            ["sudo", "systemctl", "stop", "cam.service", "greet.service"],
            stderr=subprocess.DEVNULL,
            check=False
        )
        
        # 停止用户服务
        subprocess.run(
            ["systemctl", "--user", "stop", 
             "pipewire.service", "pipewire.socket", 
             "pipewire-pulse.service", "wireplumber.service"],
            stderr=subprocess.DEVNULL,
            check=False
        )
        
        # 等待服务完全停止
        time.sleep(0.5)
    
    async def perform_recognition(self) -> tuple:
        """执行人脸识别"""
        self.logger.info("开始识别...")
        
        # 停止相机服务
        self.stop_camera_services()
        
        # 调用识别模块（10帧投票）
        vision_cfg = self.config["vision"]
        name, avg_confidence, consistent_frames = self.recognizer.recognize_stable(
            frames=vision_cfg["frames"],
            interval=vision_cfg["frame_interval"]
        )
        
        return name, avg_confidence, consistent_frames
    
    async def publish_event(self, name: str, confidence: float, frames: int):
        """发布人脸识别事件到MQTT"""
        mqtt_cfg = self.config["mqtt"]
        
        payload = {
            "person": name,
            "confidence": confidence,
            "consistent_frames": f"{frames}/{self.config['vision']['frames']}",
            "timestamp": datetime.now().isoformat(),
            "mode": self.config["mode"]
        }
        
        self.logger.info(f"发布MQTT事件: {payload}")
        
        await self.event_bus.publish(
            topic=mqtt_cfg["topic"],
            event_type="person.detected",
            payload=payload
        )
        
        self.logger.info("✓ MQTT事件已发布")
    
    async def scan_loop(self):
        """主扫描循环"""
        self.logger.info("=== 扫描服务启动 ===")
        self.running = True
        
        scan_interval = self.mode_config["scan_interval"]
        min_frames = self.config["vision"]["min_consistent_frames"]
        
        while self.running:
            try:
                self.logger.info(f"--- 新一轮扫描（间隔{scan_interval}秒）---")
                
                # 1. 检查全局冷却
                if self.is_global_cooldown():
                    self.logger.info("跳过本轮：全局冷却中")
                    await asyncio.sleep(scan_interval)
                    continue
                
                # 2. 执行识别
                name, confidence, frames = await self.perform_recognition()
                
                # 3. 判断识别结果
                if name == "Unknown" or frames < min_frames:
                    self.logger.info(f"未识别到有效人脸（{name}, {frames}帧）")
                    await asyncio.sleep(scan_interval)
                    continue
                
                # 4. 检查单人冷却
                if self.is_in_cooldown(name):
                    self.logger.info(f"跳过{name}：单人冷却中")
                    await asyncio.sleep(scan_interval)
                    continue
                
                # 5. 识别成功 - 发布事件
                self.logger.info(f"✓ 识别成功: {name} (置信度={confidence:.1f}, {frames}帧一致)")
                await self.publish_event(name, confidence, frames)
                
                # 6. 更新冷却记录
                self.update_cooldown(name)
                
            except Exception as e:
                self.logger.error(f"扫描循环异常: {e}", exc_info=True)
            
            # 等待下次扫描
            await asyncio.sleep(scan_interval)
    
    async def start(self):
        """启动服务"""
        self.logger.info("=== 视觉扫描服务初始化 ===")
        
        try:
            # 1. 加载配置
            self.load_config()
            
            # 2. 初始化组件
            self.init_components()
            
            # 3. 启动扫描循环
            await self.scan_loop()
            
        except KeyboardInterrupt:
            self.logger.info("收到退出信号")
        except Exception as e:
            self.logger.error(f"服务异常: {e}", exc_info=True)
            raise
        finally:
            self.running = False
            self.logger.info("=== 视觉扫描服务已停止 ===")
    
    def stop(self):
        """停止服务"""
        self.logger.info("正在停止扫描服务...")
        self.running = False


async def main():
    """主入口"""
    config_path = "/home/MRwang/smart_assistant/config/vision_config.yaml"
    
    scanner = VisionScanner(config_path)
    
    # 信号处理
    def signal_handler(sig, frame):
        scanner.stop()
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    await scanner.start()


if __name__ == "__main__":
    asyncio.run(main())
PYTHON_EOF
    
    chmod +x "$SCANNER_FILE"
    say "✓ 已创建: $SCANNER_FILE"
else
    say "DRY-RUN: 将创建 $SCANNER_FILE (约15KB)"
fi

# 2. 创建启动脚本
if [ "$DRY_RUN" = "0" ]; then
    say "创建启动脚本: $START_SCRIPT"
    cat > "$START_SCRIPT" <<'BASH_EOF'
#!/usr/bin/env bash
# 启动视觉扫描服务

cd /home/MRwang/smart_assistant
python3 /home/MRwang/smart_assistant/modules/vision/scanner.py
BASH_EOF
    
    chmod +x "$START_SCRIPT"
    say "✓ 已创建: $START_SCRIPT"
else
    say "DRY-RUN: 将创建 $START_SCRIPT"
fi

# 3. 语法检查
if [ "$DRY_RUN" = "0" ]; then
    say "语法检查..."
    if python3 -m py_compile "$SCANNER_FILE"; then
        say "✓ 语法检查通过"
    else
        say "✗ 语法错误"
        exit 1
    fi
else
    say "DRY-RUN: 将执行语法检查"
fi

# 4. 导入检查
if [ "$DRY_RUN" = "0" ]; then
    say "导入检查..."
    python3 <<'PYCHECK'
import sys
sys.path.insert(0, "/home/MRwang/smart_assistant")

try:
    from modules.vision.recognizer.face_recognizer import FaceRecognizer
    print("✓ FaceRecognizer导入成功")
    
    from core.event_bus import EventBus
    print("✓ EventBus导入成功")
    
    from core.logger import get_logger
    print("✓ Logger导入成功")
    
    print("✓ 所有依赖导入正常")
except ImportError as e:
    print(f"✗ 导入失败: {e}")
    sys.exit(1)
PYCHECK
    
    if [ $? -eq 0 ]; then
        say "✓ 导入检查通过"
    else
        say "✗ 导入检查失败"
        exit 1
    fi
else
    say "DRY-RUN: 将执行导入检查"
fi

say ""
if [ "$DRY_RUN" = "1" ]; then
    say "✓ DRY-RUN: 所有操作仅预演，未修改系统"
else
    say "✓ 第16步完成！扫描服务主程序已就绪"
fi
