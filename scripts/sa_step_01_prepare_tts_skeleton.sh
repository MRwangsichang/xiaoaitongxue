#!/usr/bin/env bash
set -euo pipefail

DRY_RUN="${DRY_RUN:-1}"
say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
cd "$ROOT" || { echo "ERROR: 无法进入 $ROOT"; exit 1; }

# ==================== 1. 创建目录 ====================
TTS_DIR="$ROOT/modules/tts"
if [ "$DRY_RUN" = "1" ]; then
    say "DRY-RUN: 将创建目录 modules/tts/"
else
    mkdir -p "$TTS_DIR"
    touch "$TTS_DIR/__init__.py"
    say "✓ 已创建 $TTS_DIR/ 及 __init__.py"
fi

# ==================== 2. 创建配置文件 ====================
CONFIG_FILE="$ROOT/config/tts.yml"
CONFIG_CONTENT='# ==================== MQTT (required) ====================
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

# ==================== TTS-specific config ====================
provider: xunfei

audio:
  device: plughw:0,0
  player: aplay
  cache_dir: /tmp/tts_cache

xunfei:
  ws_url: wss://tts-api.xfyun.cn/v2/tts
  vcn: x5_lingfeiyi_flow
  speed: 50
  volume: 50
  pitch: 50
  aue: lame
  timeout: 10

edge:
  voice: zh-CN-XiaoxiaoNeural
  rate: +0%
  volume: +0%

queue:
  max_size: 10
  timeout_sec: 30

asr_control:
  pause_before_play: true
  resume_after_play: true
  pause_delay_ms: 100

health_interval: 10

auth:
  env_keys:
    - XF_TTS_APPID
    - XF_TTS_API_KEY
    - XF_TTS_API_SECRET
'

if [ "$DRY_RUN" = "1" ]; then
    say "DRY-RUN: 将创建文件 config/tts.yml ($(echo "$CONFIG_CONTENT" | wc -c) bytes)"
else
    echo "$CONFIG_CONTENT" > "$CONFIG_FILE"
    say "✓ 已创建 $CONFIG_FILE"
fi

# ==================== 3. 创建启动脚本 ====================
START_SCRIPT="$ROOT/scripts/start_tts.sh"
START_CONTENT='#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
cd "$ROOT" || exit 1

export PYTHONPATH="$ROOT:${PYTHONPATH:-}"

if [ -f "${ROOT}/.env.local" ]; then
    set -o allexport
    source "${ROOT}/.env.local"
    set +o allexport
    say "Environment variables loaded from .env.local"
fi

say "=== Starting TTS Module ==="
say "PYTHONPATH=$PYTHONPATH"
say "Working directory: $(pwd)"
say ""

python3 modules/tts/tts_module.py
'

if [ "$DRY_RUN" = "1" ]; then
    say "DRY-RUN: 将创建文件 scripts/start_tts.sh (可执行)"
else
    echo "$START_CONTENT" > "$START_SCRIPT"
    chmod +x "$START_SCRIPT"
    say "✓ 已创建 $START_SCRIPT (可执行)"
fi

# ==================== 4. 备份并修改 .env.local ====================
ENV_FILE="$ROOT/.env.local"
BACKUP_FILE="$ENV_FILE.backup_before_tts_$(date +%s)"
TTS_CREDS='
# === TTS Module Credentials (讯飞超拟人语音合成) ===
XF_TTS_APPID=b43105c1
XF_TTS_API_KEY=26ad710fb6adb11484dc7b4a955a465f
XF_TTS_API_SECRET=ZDA4Yzk1Yzc4YWYyZWZkZWM3YThkMzVm
'

if [ "$DRY_RUN" = "1" ]; then
    say "DRY-RUN: 将备份 .env.local → $(basename $BACKUP_FILE)"
    say "DRY-RUN: 将追加 3 行到 .env.local"
else
    if [ -f "$ENV_FILE" ]; then
        cp "$ENV_FILE" "$BACKUP_FILE"
        say "✓ 已备份 .env.local → $BACKUP_FILE"
    else
        say "警告: .env.local 不存在，将创建新文件"
    fi
    
    echo "$TTS_CREDS" >> "$ENV_FILE"
    say "✓ 已追加 TTS 凭证到 .env.local"
fi

# ==================== 完成 ====================
if [ "$DRY_RUN" = "1" ]; then
    say "✓ DRY-RUN完成，未改动任何文件"
    say "执行真实操作: DRY_RUN=0 bash $0"
else
    say "✓✓✓ 步骤1完成 ✓✓✓"
fi
