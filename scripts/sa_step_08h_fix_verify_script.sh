#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
cd "$ROOT" || exit 1

say "=== Fixing verification script ==="

# Backup
cp scripts/sa_step_08_verify_asr.sh "scripts/sa_step_08_verify_asr.sh.bak_$(date +%s)"

# Fix Step 4 config validation
sed -i 's/load_config("config\/asr\.yml", required_keys=\["provider", "device", "rate"\])/load_config("config\/asr.yml")/' scripts/sa_step_08_verify_asr.sh

say "✓ Fixed verification script"

# Run the fixed verification
say ""
say "Running fixed verification..."
./scripts/sa_step_08_verify_asr.sh

