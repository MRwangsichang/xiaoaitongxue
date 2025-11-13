#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
cd "$ROOT" || exit 1

# Set PYTHONPATH to include project root
export PYTHONPATH="$ROOT:${PYTHONPATH:-}"
# Load environment variables
if [ -f "${ROOT}/.env.local" ]; then
    source "${ROOT}/.env.local"
    say "Environment variables loaded from .env.local"
fi

say "=== Starting ASR Module ==="
say "PYTHONPATH=$PYTHONPATH"
say "Working directory: $(pwd)"
say ""

# Run ASR module
python3 modules/asr/asr_module.py

