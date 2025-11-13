#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
RULES_MODULE="${ROOT}/modules/rules/rules_module.py"
GPT_FALLBACK="${ROOT}/modules/rules/gpt_fallback.py"

say "=== 最终版：完整集成Grok ==="

# 备份
cp -p "${RULES_MODULE}" "${RULES_MODULE}.final_backup"
cp -p "${GPT_FALLBACK}" "${GPT_FALLBACK}.final_backup"

say "步骤1：修改rules_module.py，初始化Grok"

python3 - <<'PYCODE1'
file_path = "/home/MRwang/smart_assistant/modules/rules/rules_module.py"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 在self.logger后面添加self.grok初始化
for i in range(len(lines)):
    if 'self.logger = get_logger(self.module_name)' in lines[i]:
        # 在下一行插入
        indent = '        '
        lines.insert(i+1, f'{indent}self.grok = GrokClient(self.logger)\n')
        lines.insert(i+2, f'{indent}self.conversation_history = []  # Grok对话历史\n')
        print(f"✓ 在第{i+1}行后插入Grok初始化")
        break

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("✓ rules_module.py修改完成")
PYCODE1

say "步骤2：修改gpt_fallback.py，使用Grok"

python3 - <<'PYCODE2'
file_path = "/home/MRwang/smart_assistant/modules/rules/gpt_fallback.py"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 修改__init__，接收grok_client
content = content.replace(
    '    def __init__(self, logger):',
    '    def __init__(self, logger, grok_client=None):'
)

# 添加grok_client赋值
content = content.replace(
    '        self.logger = logger',
    '        self.logger = logger\n        self.grok = grok_client'
)

# 修改generate_response，优先使用Grok
old_generate = '''    async def generate_response(self, user_input: str, context: Optional[dict] = None) -> str:
        """
        调用GPT生成回复
        Args:
            user_input: 用户输入
            context: 上下文信息（可选）
        Returns:
            GPT生成的回复文本
        """
        if not self.api_key:
            return "抱歉，我现在脑子有点转不动，您能换个说法吗？"'''

new_generate = '''    async def generate_response(self, user_input: str, context: Optional[dict] = None) -> str:
        """
        调用Grok生成回复（优先），失败则尝试GPT
        Args:
            user_input: 用户输入
            context: 上下文信息（可选）
        Returns:
            生成的回复文本
        """
        # 优先使用Grok
        if self.grok:
            try:
                # 构建对话历史
                conv_history = []
                if context and context.get('history'):
                    history = context['history'][-5:]  # 最近5轮
                    for h in history:
                        conv_history.append({"role": "user", "content": h['user']})
                        conv_history.append({"role": "assistant", "content": h['assistant']})
                
                reply = await self.grok.chat(
                    user_message=user_input,
                    conversation_history=conv_history
                )
                self.logger.info(f"Grok回复: {reply}")
                return reply
            except Exception as e:
                self.logger.error(f"Grok调用失败: {e}")
                # 继续尝试OpenAI作为备用
        
        # OpenAI作为备用
        if not self.api_key:
            return "抱歉，我现在脑子有点转不动，您能换个说法吗？"'''

content = content.replace(old_generate, new_generate)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✓ gpt_fallback.py修改完成")
PYCODE2

say "步骤3：修改rules_module.py，传递grok给GPTFallback"

python3 - <<'PYCODE3'
file_path = "/home/MRwang/smart_assistant/modules/rules/rules_module.py"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 找到GPTFallback初始化，添加grok参数
import re
pattern = r'GPTFallback\(self\.logger\)'
replacement = 'GPTFallback(self.logger, self.grok)'
content = re.sub(pattern, replacement, content)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✓ GPTFallback调用已修改")
PYCODE3

# 验证语法
say "验证语法..."

if python3 -m py_compile "${RULES_MODULE}" 2>/dev/null && \
   python3 -m py_compile "${GPT_FALLBACK}" 2>/dev/null; then
    say "✓ 所有文件语法检查通过"
else
    say "✗ 语法错误，恢复备份"
    cp "${RULES_MODULE}.final_backup" "${RULES_MODULE}"
    cp "${GPT_FALLBACK}.final_backup" "${GPT_FALLBACK}"
    say "查看错误："
    python3 -m py_compile "${RULES_MODULE}"
    python3 -m py_compile "${GPT_FALLBACK}"
    exit 1
fi

say ""
say "✅ Grok完全集成完成！"
say ""
say "重启Rules测试："
echo "  【终端2】Ctrl+C 停止"
echo "  cd /home/MRwang/smart_assistant"
echo "  bash scripts/start_rules.sh"
echo ""
say "测试步骤："
echo "  1. 发送start命令"
echo "  2. 说：今天天气怎么样？"
echo "  3. 观察终端2，应该看到Grok回复"
