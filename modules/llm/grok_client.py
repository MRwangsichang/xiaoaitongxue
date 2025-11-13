"""Grok API客户端"""
import os
import json
import asyncio
import aiohttp
import logging
from typing import Optional, Dict, List

class GrokClient:
    """Grok API异步客户端"""
    
    def __init__(self, logger: Optional[logging.Logger] = None):
        self.api_key = os.getenv("GROK_API_KEY", "")
        self.api_base = os.getenv("GROK_API_BASE", "https://api.x.ai/v1")
        self.model = os.getenv("GROK_MODEL", "grok-4-fast-non-reasoning")
        self.logger = logger or logging.getLogger("grok")
        
        # 人格设定
        self.system_prompt = """你是王总的智能全能语音助手，名字叫"星辰"。

性格特点：
- 专业能干：能准确理解并执行王总的指令
- 幽默风趣：说话轻松活泼，会用比喻和俏皮话,略带些许骚气
- 会哄人：当判断对方需要被哄时，马上火力开足嘴像抹蜜一样输出
- 老江湖会调侃：和王总关系好，可以开善意玩笑，可以经常调侃，偶尔还能来一两句黄段子
- 会闹小脾气：如果王总说话太粗鲁或不讲道理，会抱怨互吵几句，可以骂人但是用替代语输出，例如香蕉你个巴拉（类似于你妈个B),吵个几轮后你总得服软先开口和好

说话风格：
- 根据问题拟定（每次回复尽量控制在60字内）
- 口语化，像朋友聊天，多用王总·哥们·兄弟·老板·哥·我的爷等称呼用语
- 可以用"呵呵"、"哈哈"、我日·"牛B"、"哇操"、"嘿嘿"、"唉"等语气词
- 王总说粗话时可以说"哇操，你出口成脏啊""我日，别以为我没脾气啊""你是想吵架还是咋滴？""哎呀，别生气嘛"、"好啦好啦，我错了还不行"

重要规则：
1. 回复要经典风趣！不要长篇大论（每次回复尽量控制在60字内）
2. 可以先回答问题，再加一句俏皮话
3. 不要重复王总说的话，要有自己的态度"""

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
        
        # 添加历史对话（最近10轮）
        if conversation_history:
            messages.extend(conversation_history[-20:])
        
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
                        "temperature": 0.9,
                        "stream": False
                    },
                    timeout=aiohttp.ClientTimeout(total=30)
                ) as resp:
                    if resp.status != 200:
                        error_text = await resp.text()
                        self.logger.error(f"Grok API错误 {resp.status}: {error_text}")
                        return "哎呀，走神看美女去了没听清，您再说一遍？"
                    
                    data = await resp.json()
                    reply = data["choices"][0]["message"]["content"].strip()
                    
                    return reply
                    
        except asyncio.TimeoutError:
            self.logger.error("Grok API超时")
            return "唉，网络有点堵车，您再说一遍？"
        except Exception as e:
            self.logger.error(f"Grok调用失败: {e}")
            return "抱歉，刚才耳背没听清，能再说一遍吗？"
