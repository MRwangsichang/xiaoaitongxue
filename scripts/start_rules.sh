#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"

say "=== Starting Rules Module ==="

# Set PYTHONPATH
export PYTHONPATH="${ROOT}:${PYTHONPATH:-}"
say "PYTHONPATH=${PYTHONPATH}"

# Change to project root
cd "${ROOT}"
say "Working directory: $(pwd)"
echo ""

# Load environment variables
if [ -f "${ROOT}/.env.local" ]; then
    source "${ROOT}/.env.local"
    say "Environment variables loaded from .env.local"
fi

# Run rules module
python3 modules/rules/rules_module.py
