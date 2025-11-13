#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
cd "$ROOT" || exit 1

say "=== Extending load_config() with required_keys ==="

# Backup original
cp core/config_loader.py "core/config_loader.py.bak_$(date +%s)"

# Check current load_config implementation
say "Current load_config signature: config_path only"

# Add required_keys parameter to load_config function
# We'll use Python to do the modification
python3 <<'PYEOF'
import re

# Read original file
with open("core/config_loader.py", "r") as f:
    content = f.read()

# Find and replace the load_config function signature and body
old_signature = r'def load_config\(config_path: Optional\[str\] = None\) -> Dict\[str, Any\]:'
new_signature = 'def load_config(config_path: Optional[str] = None, required_keys: Optional[list] = None) -> Dict[str, Any]:'

content = re.sub(old_signature, new_signature, content)

# Find the function body and add validation logic after loader creation
old_body = r'(    loader = ConfigLoader\(config_path\)\n)'
new_body = r'''\1
    # Validate required keys if specified
    if required_keys:
        config_dict = loader.config
        missing_keys = [k for k in required_keys if k not in config_dict]
        if missing_keys:
            raise ValueError(f"Missing required config keys: {missing_keys}")
'''

content = re.sub(old_body, new_body, content)

# Write back
with open("core/config_loader.py", "w") as f:
    f.write(content)

print("[✓] Extended load_config() with required_keys parameter")
PYEOF

say "✓ Modified core/config_loader.py"

# Test the new functionality
say ""
say "Testing with valid config..."
python3 <<'PYTEST'
import sys
sys.path.insert(0, ".")
from core import load_config

try:
    config = load_config("config/asr.yml", required_keys=["provider", "device", "rate"])
    print(f"[✓] Valid config loaded: provider={config['provider']}")
except Exception as e:
    print(f"[✗] Failed: {e}")
    sys.exit(1)
PYTEST

say ""
say "Testing with missing keys..."
python3 <<'PYTEST2'
import sys
sys.path.insert(0, ".")
from core import load_config

try:
    config = load_config("config/asr.yml", required_keys=["provider", "nonexistent_key"])
    print("[✗] Should have raised ValueError for missing key")
    sys.exit(1)
except ValueError as e:
    print(f"[✓] Missing keys detected correctly: {e}")
except Exception as e:
    print(f"[✗] Unexpected error: {e}")
    sys.exit(1)
PYTEST2

say ""
say "✓ load_config() extended successfully"

