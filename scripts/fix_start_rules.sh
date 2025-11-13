#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

START_SCRIPT="/home/MRwang/smart_assistant/scripts/start_rules.sh"

say "=== 修复 start_rules.sh ==="

# 备份
cp -p "${START_SCRIPT}" "${START_SCRIPT}.backup"

# 重写脚本
cat > "${START_SCRIPT}" <<'RULES_SCRIPT'
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
RULES_SCRIPT

chmod +x "${START_SCRIPT}"

say "✓ start_rules.sh 已修复"
