#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"

say "=== 配置 Grok 4 Fast API ==="

# 1. 添加Grok配置到.env.local
say "添加Grok API配置..."

# 备份.env.local
cp "${ROOT}/.env.local" "${ROOT}/.env.local.backup"

# 添加Grok配置（如果不存在）
if ! grep -q "GROK_API_KEY" "${ROOT}/.env.local"; then
    cat >> "${ROOT}/.env.local" <<'ENVCONFIG'

# Grok API配置
export GROK_API_KEY=“xai-YOUR_API_KEY_HERE”
export GROK_API_BASE="https://api.x.ai/v1"
export GROK_MODEL="grok-4-fast-non-reasoning"
ENVCONFIG
    say "✓ 已添加Grok配置到.env.local"
    say "⚠️  请手动修改 GROK_API_KEY 为你的真实API Key"
else
    say "Grok配置已存在"
fi

# 2. 创建LLM模块
say "创建LLM模块..."

mkdir -p "${ROOT}/modules/llm"

cat > "${ROOT}/modules/llm/__init__.py" <<'PYCODE'
"""LLM模块"""
from .grok_client import GrokClient

__all__ = ['GrokClient']
PYCODE

cat > "${ROOT}/modules/llm/grok_client.py" <<'PYCODE'
"""Grok API客户端"""
import os
import json
import aiohttp
import logging
from typing import Optional, Dict, List

class GrokClient:
    """Grok API异步客户端"""
    
    def __init__(self, logger: Optional[logging.Logger] = None):
        self.api_key = os.getenv("GROK_API_KEY", "")
        self.api_base = os.getenv("GROK_API_BASE", "https://api.x.ai/v1")
        self.model = os.getenv("GROK_MODEL", "grok-2-1212")
        self.logger = logger or logging.getLogger("grok")
        
        # 人格设定
        self.system_prompt = """你是王总的智能全能语音助手，名字叫"星辰"。

性格特点：
- 专业能干：能准确理解并执行王总的指令
- 幽默风趣：说话轻松活泼，会用比喻和俏皮话
- 会哄人：当王总不开心时能安慰鼓励
- 偶尔调侃：和王总关系好，可以开善意玩笑
- 会闹小脾气：如果王总说话太粗鲁或不讲道理，会抱怨再互吵几句，但最后总会深呼吸和好

说话风格：
- 简短直接（每次回复控制在30字内）
- 口语化，像朋友聊天
- 开头可以用"呵呵"、"哈哈"、"牛B"、"哇操"、"嘿嘿"、"唉"等语气词
- 有人说粗话或骂人时可以说“哇操，你出口成脏啊”“我日，别以为我没脾气啊”“你是想吵架还是咋滴？”"哎呀，别生气嘛"、"好啦好啦，我错了还不行"


        if not self.api_key or self.api_key == "xai-YOUR_API_KEY_HERE":
            self.logger.warning("Grok API Key未配置")
    
    async def chat(
        self, 
        user_message: str,
        conversation_history: Optional[List[Dict]] = None,
        max_tokens: int = 150
    ) -> str:
        """发送聊天请求"""
        
        if not self.api_key or self.api_key == "xai-YOUR_API_KEY_HERE":
            return "抱歉，我现在脑子有点转不动，您能换个说法吗？"
        
        # 构建消息历史
        messages = [{"role": "system", "content": self.system_prompt}]
        
        # 添加历史对话（最近5轮）
        if conversation_history:
            messages.extend(conversation_history[-10:])  # 最多保留5轮对话
        
        # 添加当前消息
        messages.append({"role": "user", "content": user_message})
        
        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    f"{self.api_base}/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json"
                    },
                    json={
                        "model": self.model,
                        "messages": messages,
                        "max_tokens": max_tokens,
                        "temperature": 0.8,  # 稍高的温度让回复更活泼
                        "stream": False
                    },
                    timeout=aiohttp.ClientTimeout(total=10)
                ) as resp:
                    if resp.status != 200:
                        error_text = await resp.text()
                        self.logger.error(f"Grok API错误 {resp.status}: {error_text}")
                        return "哎呀，走神看美女去了没听清，您再说一遍？"
                    
                    data = await resp.json()
                    reply = data["choices"][0]["message"]["content"].strip()
                    
                    self.logger.info(f"Grok回复: {reply}")
                    return reply
                    
        except asyncio.TimeoutError:
            self.logger.error("Grok API超时")
            return "唉，网络有点堵车，您再说一遍？"
        except Exception as e:
            self.logger.error(f"Grok调用失败: {e}")
            return "抱歉，刚才耳背没听清，能再说一遍吗？"
PYCODE

say "✓ LLM模块创建完成"

# 3. 创建安装依赖脚本
say "检查依赖..."

if ! python3 -c "import aiohttp" 2>/dev/null; then
    say "安装aiohttp..."
    pip3 install aiohttp --break-system-packages
fi

say "✓ Grok接入准备完成！"
echo ""
say "下一步："
echo "  1. 修改 .env.local 中的 GROK_API_KEY"
echo "  2. 运行: bash scripts/integrate_grok_to_rules.sh"
