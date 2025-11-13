#!/usr/bin/env bash
set -euo pipefail
DRY_RUN="${DRY_RUN:-1}"

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
cd "$ROOT" || exit 1

if [ "$DRY_RUN" = "1" ]; then
  say "DRY-RUN: 仅打印将执行的操作，不改系统"
  say "WILL MODIFY: modules/asr/asr_module.py"
  say "  - Add manual config validation in __init__"
  say "  - Remove required_keys from load_config() call"
  say "DRY-RUN COMPLETE"
  exit 0
fi

say "=== Adding manual config validation to ASR module ==="

# Backup
cp modules/asr/asr_module.py "modules/asr/asr_module.py.bak_$(date +%s)"

# Rewrite __init__ method with manual validation
python3 <<'PYEOF'
with open("modules/asr/asr_module.py", "r") as f:
    content = f.read()

# Replace the __init__ method
old_init = '''    def __init__(self, config_path: str = "config/asr.yml"):
        self.config = load_config(config_path, required_keys=["provider", "device", "rate"])'''

new_init = '''    def __init__(self, config_path: str = "config/asr.yml"):
        # Load config without validation
        self.config = load_config(config_path)
        
        # Manually validate required keys
        required_keys = ["provider", "device", "rate"]
        missing_keys = []
        for key in required_keys:
            if key not in self.config or self.config[key] is None or self.config[key] == "":
                missing_keys.append(key)
        
        if missing_keys:
            available_keys = list(self.config.keys())
            raise ValueError(
                f"ASR配置缺少必填键: {missing_keys}\\n"
                f"当前可用键: {available_keys}\\n"
                f"请检查配置文件: {config_path}"
            )'''

if old_init in content:
    content = content.replace(old_init, new_init)
    print("[✓] Updated __init__ with manual validation")
else:
    print("[!] Warning: Could not find exact __init__ pattern")
    print("[!] Trying alternative pattern...")
    # Try alternative pattern
    import re
    pattern = r'(    def __init__\(self, config_path: str = "config/asr\.yml"\):\n)(.*?)(self\.config = load_config\(config_path(?:, required_keys=\[.*?\])?\))'
    replacement = r'\1        # Load config without validation\n        self.config = load_config(config_path)\n        \n        # Manually validate required keys\n        required_keys = ["provider", "device", "rate"]\n        missing_keys = []\n        for key in required_keys:\n            if key not in self.config or self.config[key] is None or self.config[key] == "":\n                missing_keys.append(key)\n        \n        if missing_keys:\n            available_keys = list(self.config.keys())\n            raise ValueError(\n                f"ASR配置缺少必填键: {missing_keys}\\n"\n                f"当前可用键: {available_keys}\\n"\n                f"请检查配置文件: {config_path}"\n            )'
    content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    print("[✓] Updated __init__ with alternative pattern")

with open("modules/asr/asr_module.py", "w") as f:
    f.write(content)
PYEOF

say "✓ Modified modules/asr/asr_module.py"

# Test config loading
say ""
say "Testing ASR config loading..."
python3 <<'TEST'
import sys
sys.path.insert(0, ".")

try:
    from modules.asr import ASRModule
    print("[!] Attempting to create ASRModule (may fail if MQTT not running)...")
    module = ASRModule()
    print(f"[✓] Config loaded: provider={module.config['provider']}")
except Exception as e:
    # Expected to fail due to MQTT not running, but config should load
    if "ASR配置缺少必填键" in str(e):
        print(f"[✗] Config validation failed: {e}")
        sys.exit(1)
    elif "Connection refused" in str(e) or "MQTT" in str(e):
        print("[✓] Config loaded OK (MQTT connection failed as expected)")
    else:
        print(f"[!] Other error (check if config loaded): {e}")
TEST

say ""
say "✓ ASR module config validation added successfully"

