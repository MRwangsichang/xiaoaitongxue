#!/usr/bin/env bash
set -euo pipefail
DRY_RUN="${DRY_RUN:-1}"

say(){ printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
CONFIG_FILE="$ROOT/config/vision_config.yaml"

say "=== 第15步：创建视觉扫描配置模块 ==="

# 1. 创建配置文件
if [ "$DRY_RUN" = "0" ]; then
    say "创建配置文件: $CONFIG_FILE"
    cat > "$CONFIG_FILE" <<'YAML_EOF'
# 视觉扫描服务配置
# 模式说明：
#   test       - 测试模式（高频扫描，快速验证）
#   production - 正式模式（低频扫描，节省资源）

mode: test  # 当前模式（切换到正式时改为 production）

# 测试模式配置（用于开发和验证）
test:
  scan_interval: 300       # 扫描间隔（秒）= 5分钟
  cooldown_global: 300     # 全局冷却（秒）= 5分钟（识别到任何人后）
  cooldown_person: 300     # 单人冷却（秒）= 5分钟（同一人再次识别）

# 正式模式配置（用于日常运行）
production:
  scan_interval: 1800      # 扫描间隔（秒）= 30分钟（每小时2次）
  cooldown_global: 300     # 全局冷却（秒）= 5分钟
  cooldown_person: 3600    # 单人冷却（秒）= 1小时

# 视觉识别参数（两种模式共用）
vision:
  model_path: "/home/MRwang/smart_assistant/data/faces/model.yml"
  cascade_path: "/usr/share/opencv4/haarcascades/haarcascade_frontalface_default.xml"
  frames: 10               # 投票帧数
  frame_interval: 1.5      # 帧间隔（秒）
  confidence_threshold: 75 # 置信度阈值（<75可点名，>85陌生人）
  min_consistent_frames: 6 # 最少一致帧数（10帧中至少6帧）

# MQTT事件发布配置
mqtt:
  broker: "localhost"
  port: 1883
  topic: "sa/vision/person_detected"  # 发布主题
  qos: 1

# 日志配置
logging:
  level: "INFO"            # DEBUG/INFO/WARNING/ERROR
  module_name: "vision.scanner"
YAML_EOF
    say "✓ 配置文件已创建"
else
    say "DRY-RUN: 将创建 $CONFIG_FILE"
fi

# 2. 验证配置文件可加载（使用Python测试）
if [ "$DRY_RUN" = "0" ]; then
    say "验证配置加载..."
    python3 <<'PYTHON_EOF'
import sys
import yaml

config_path = "/home/MRwang/smart_assistant/config/vision_config.yaml"

try:
    with open(config_path, "r", encoding="utf-8") as f:
        config = yaml.safe_load(f)
    
    mode = config["mode"]
    mode_config = config[mode]
    
    print(f"当前模式: {mode}")
    print(f"扫描间隔: {mode_config['scan_interval']}秒（{mode_config['scan_interval']//60}分钟）")
    print(f"全局冷却: {mode_config['cooldown_global']}秒（{mode_config['cooldown_global']//60}分钟）")
    print(f"单人冷却: {mode_config['cooldown_person']}秒（{mode_config['cooldown_person']//60}分钟）")
    print(f"MQTT主题: {config['mqtt']['topic']}")
    print()
    print("✓ 配置加载测试通过")
    sys.exit(0)
    
except Exception as e:
    print(f"✗ 配置加载失败: {e}")
    sys.exit(1)
PYTHON_EOF
    
    if [ $? -eq 0 ]; then
        say "✓ 配置验证通过"
    else
        say "✗ 配置验证失败"
        exit 1
    fi
else
    say "DRY-RUN: 将验证配置文件加载"
fi

say ""
if [ "$DRY_RUN" = "1" ]; then
    say "✓ DRY-RUN: 所有操作仅预演，未修改系统"
else
    say "✓ 第15步完成！配置模块已就绪"
fi
