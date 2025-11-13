#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
cd "$ROOT" || exit 1

say "=== Fixing config/asr.yml with required sections ==="

# Backup
cp config/asr.yml "config/asr.yml.bak_$(date +%s)"

# Create complete asr.yml
cat > config/asr.yml <<'YML_EOF'
# ASR Module Configuration

# ==================== MQTT (required by ConfigLoader) ====================
mqtt:
  broker: localhost
  port: 1883
  qos: 1
  keepalive: 60

# ==================== Logging (required by ConfigLoader) ====================
logging:
  level: INFO
  dir: logs
  rotate_days: 7

# ==================== System (required by ConfigLoader) ====================
system:
  project_root: /home/MRwang/smart_assistant
  service_prefix: sa

# ==================== ASR-specific config ====================
# Provider: mock (offline testing) or cloud (iFlytek WebSocket)
provider: mock

# Audio device settings
device: default
rate: 16000
channels: 1

# VAD (Voice Activity Detection) - for cloud provider
vad:
  start_thresh: 0.3
  tail_thresh: 0.2
  tail_sil_ms: 800
  min_chunk_ms: 200

# Session management
max_session_sec: 60
dedup_ms: 2000

# Reconnection backoff
reconnect:
  initial_delay: 1
  max_delay: 30
  multiplier: 2

# Health reporter
health_interval: 10

# Authentication (cloud only)
auth:
  env_keys:
    - XF_APPID
    - XF_API_KEY
    - XF_API_SECRET
YML_EOF

say "✓ Updated config/asr.yml with required sections"

# Verify loading
say ""
say "Testing config load..."
python3 <<PYTEST
import sys
sys.path.insert(0, ".")
from core import load_config

try:
    config = load_config("config/asr.yml", required_keys=["provider", "device", "rate"])
    print(f"[✓] Config loaded successfully")
    print(f"  - provider: {config['provider']}")
    print(f"  - device: {config['device']}")
    print(f"  - rate: {config['rate']}")
    print(f"  - mqtt.broker: {config['mqtt']['broker']}")
except Exception as e:
    print(f"[✗] Failed: {e}")
    sys.exit(1)
PYTEST

say ""
say "✓ config/asr.yml fixed successfully"

