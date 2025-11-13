#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
cd "$ROOT" || exit 1

say "=== Fixing core/__init__.py with EventBus alias ==="

# Backup
cp core/__init__.py "core/__init__.py.bak_$(date +%s)"

# Create corrected __init__.py
cat > core/__init__.py <<'INIT_EOF'
"""
Core Module - Framework components
Exports: config_loader, logger, event_bus, health
"""

# Config loader
from .config_loader import load_config

# Logger
from .logger import get_logger, setup_logger

# Event bus (MQTT) - import EventBus and alias as MQTTEventBus
from .event_bus import EventBus, EventBus as MQTTEventBus

# Health reporter
from .health import HealthReporter

__all__ = [
    "load_config",
    "get_logger",
    "setup_logger",
    "EventBus",
    "MQTTEventBus",
    "HealthReporter",
]
INIT_EOF

say "✓ Updated core/__init__.py with EventBus alias"

# Verify imports
say ""
say "Testing imports..."
python3 <<PYEOF
import sys
sys.path.insert(0, ".")
try:
    from core import get_logger, load_config, MQTTEventBus, HealthReporter, EventBus
    print("[✓] All core imports successful")
    print(f"  - EventBus and MQTTEventBus point to same class: {EventBus is MQTTEventBus}")
except ImportError as e:
    print(f"[✗] Import failed: {e}")
    sys.exit(1)
PYEOF

say ""
say "✓ EventBus alias fixed successfully"

