#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
cd "$ROOT" || exit 1

say "=== Fixing core/__init__.py ==="

# 1) Backup existing file
if [ -f "core/__init__.py" ]; then
    cp core/__init__.py "core/__init__.py.bak_$(date +%s)"
    say "✓ Backed up existing core/__init__.py"
fi

# 2) Create proper __init__.py with exports
cat > core/__init__.py <<'INIT_EOF'
"""
Core Module - Framework components
Exports: config_loader, logger, event_bus, health
"""

# Config loader
from .config_loader import load_config

# Logger
from .logger import get_logger, setup_logger

# Event bus (MQTT)
from .event_bus import MQTTEventBus

# Health reporter
from .health import HealthReporter

__all__ = [
    "load_config",
    "get_logger",
    "setup_logger",
    "MQTTEventBus",
    "HealthReporter",
]
INIT_EOF

say "✓ Updated core/__init__.py with proper exports"

# 3) Verify imports
say ""
say "Testing imports..."
python3 <<PYEOF
import sys
sys.path.insert(0, ".")
try:
    from core import get_logger, load_config, MQTTEventBus, HealthReporter
    print("[✓] All core imports successful")
    print(f"  - get_logger: {get_logger}")
    print(f"  - load_config: {load_config}")
    print(f"  - MQTTEventBus: {MQTTEventBus}")
    print(f"  - HealthReporter: {HealthReporter}")
except ImportError as e:
    print(f"[✗] Import failed: {e}")
    sys.exit(1)
PYEOF

say ""
say "✓ core/__init__.py fixed successfully"

