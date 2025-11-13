#!/usr/bin/env bash
set -e
cd /home/MRwang/smart_assistant
export PYTHONPATH=/home/MRwang/smart_assistant:$PYTHONPATH
export SA_CONFIG="/home/MRwang/smart_assistant/config/app.json"
python3 -m core.main --smoke
