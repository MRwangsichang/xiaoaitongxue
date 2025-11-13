#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

GPT_FALLBACK="/home/MRwang/smart_assistant/modules/rules/gpt_fallback.py"

say "=== 修复generate_response方法 ==="

# 备份
cp -p "${GPT_FALLBACK}" "${GPT_FALLBACK}.before_fix_generate"

# 使用Python精确替换
python3 - <<'PYCODE'
file_path = "/home/MRwang/smart_assistant/modules/rules/gpt_fallback.py"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 找到generate_response方法的开始位置
start_line = -1
for i in range(len(lines)):
    if 'async def generate_response' in lines[i]:
        start_line = i
        break

if start_line == -1:
    print("✗ 未找到generate_response方法")
    exit(1)

print(f"✓ 找到generate_response在第{start_line+1}行")

# 找到方法的结束位置（下一个def或文件末尾）
end_line = len(lines)
for i in range(start_line + 1, len(lines)):
    if lines[i].strip().startswith('def ') or lines[i].strip().startswith('async def '):
        end_line = i
        break

print(f"✓ 方法结束在第{end_line}行")

# 替换整个方法
new_method = '''    async def generate_response(self, user_input: str, context: Optional[dict] = None) -> str:
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
            return "抱歉，我现在脑子有点转不动，您能换个说法吗？"
        
        try:
            # 使用gpt-4o-mini
            import aiohttp
            messages = [
                {"role": "system", "content": self.system_prompt},
                {"role": "user", "content": user_input}
            ]
            
            # 如果有上下文，添加历史对话
            if context and context.get('history'):
                history = context['history'][-3:]  # 最近3轮
                for h in history:
                    messages.insert(-1, {"role": "user", "content": h['user']})
                    messages.insert(-1, {"role": "assistant", "content": h['assistant']})
            
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    f'{self.api_base}/v1/chat/completions',
                    headers={
                        'Authorization': f'Bearer {self.api_key}',
                        'Content-Type': 'application/json'
                    },
                    json={
                        'model': 'gpt-4o-mini',
                        'messages': messages,
                        'max_tokens': 200,
                        'temperature': 0.8
                    },
                    timeout=aiohttp.ClientTimeout(total=10)
                ) as resp:
                    if resp.status != 200:
                        error_text = await resp.text()
                        self.logger.error(f"GPT API错误: {resp.status} - {error_text}")
                        return "嗯...我想了想，还是没想明白。您能再详细说说吗？"
                    
                    data = await resp.json()
                    reply = data['choices'][0]['message']['content'].strip()
                    self.logger.info(f"GPT回复: {reply[:50]}...")
                    return reply
        
        except asyncio.TimeoutError:
            self.logger.error("GPT调用超时")
            return "哎呀，我反应有点慢，您再说一遍？"
        except Exception as e:
            self.logger.error(f"GPT调用失败: {e}")
            return "抱歉，刚才没听清，能再说一遍吗？"

'''

# 删除旧方法，插入新方法
del lines[start_line:end_line]
lines.insert(start_line, new_method)

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("✓ generate_response方法已替换")
PYCODE

# 验证语法
if python3 -m py_compile "${GPT_FALLBACK}" 2>/dev/null; then
    say "✓ 语法检查通过"
else
    say "✗ 语法错误，恢复备份"
    cp "${GPT_FALLBACK}.before_fix_generate" "${GPT_FALLBACK}"
    exit 1
fi

say ""
say "✅ 修复完成！"
say ""
say "立刻重启Rules："
echo "  【终端2】Ctrl+C"
echo "  bash scripts/start_rules.sh"
