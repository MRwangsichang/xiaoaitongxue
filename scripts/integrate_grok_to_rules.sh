#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
RULES_MODULE="${ROOT}/modules/rules/rules_module.py"

say "=== 集成Grok到Rules模块 ==="

# 备份
cp -p "${RULES_MODULE}" "${RULES_MODULE}.before_grok"

# 使用Python修改
python3 - <<'PYCODE'
import re

file_path = "/home/MRwang/smart_assistant/modules/rules/rules_module.py"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. 在import部分添加GrokClient（在asyncio之后）
if 'from modules.llm.grok_client import GrokClient' not in content:
    content = content.replace(
        'import asyncio\n',
        'import asyncio\nfrom modules.llm.grok_client import GrokClient\n'
    )

# 2. 在__init__中初始化GrokClient
if 'self.grok = GrokClient' not in content:
    content = content.replace(
        '        self.logger = setup_logger("rules")\n',
        '        self.logger = setup_logger("rules")\n        self.grok = GrokClient(self.logger)\n        self.conversation_history = []  # 对话历史\n'
    )

# 3. 修改GPT兜底逻辑
# 找到 reply_text = "抱歉，我现在脑子有点转不动..." 
pattern = r'(self\.logger\.info\(f"触发GPT兜底.*?\n)([\s\S]*?)(reply_text = "抱歉，我现在脑子有点转不动，您能换个说法吗\?")'

replacement = r'''\1        # 调用Grok获取回复
        try:
            grok_reply = await self.grok.chat(
                user_message=text,
                conversation_history=self.conversation_history
            )
            
            # 更新对话历史
            self.conversation_history.append({"role": "user", "content": text})
            self.conversation_history.append({"role": "assistant", "content": grok_reply})
            
            # 保持最近10轮对话
            if len(self.conversation_history) > 20:
                self.conversation_history = self.conversation_history[-20:]
            
            reply_text = grok_reply
        except Exception as e:
            self.logger.error(f"Grok调用失败: {e}")
            reply_text = "抱歉，我现在脑子有点转不动，您能换个说法吗？"'''

content = re.sub(pattern, replacement, content)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✓ Grok已集成到Rules模块")
PYCODE

# 验证语法
if python3 -m py_compile "${RULES_MODULE}" 2>/dev/null; then
    say "✓ 集成完成，语法检查通过"
else
    say "✗ 语法错误，恢复备份"
    cp "${RULES_MODULE}.before_grok" "${RULES_MODULE}"
    exit 1
fi

say ""
say "下一步："
echo "  【终端2】Ctrl+C 停止Rules"
echo "  cd /home/MRwang/smart_assistant"
echo "  bash scripts/start_rules.sh"
