#!/usr/bin/env bash
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

