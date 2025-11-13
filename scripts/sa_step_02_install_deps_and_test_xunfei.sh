#!/usr/bin/env bash
set -euo pipefail

DRY_RUN="${DRY_RUN:-1}"
say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
cd "$ROOT" || exit 1

# ==================== 1. 安装依赖 ====================
if [ "$DRY_RUN" = "1" ]; then
    say "DRY-RUN: 将安装 pip3 install websockets edge-tts --break-system-packages"
else
    say "正在安装 websockets..."
    pip3 install websockets --break-system-packages -q
    say "正在安装 edge-tts..."
    pip3 install edge-tts --break-system-packages -q
    say "✓ 依赖安装完成"
fi

# ==================== 2. 创建讯飞Provider ====================
PROVIDER_FILE="$ROOT/modules/tts/xunfei_provider.py"
PROVIDER_CODE='"""讯飞超拟人TTS Provider - WebSocket实时合成"""
import asyncio
import websockets
import json
import hmac
import hashlib
import base64
from urllib.parse import urlencode
from datetime import datetime
import os

class XunfeiTTSProvider:
    def __init__(self, config, logger):
        self.config = config
        self.logger = logger
        
        self.app_id = os.getenv("XF_TTS_APPID")
        self.api_key = os.getenv("XF_TTS_API_KEY")
        self.api_secret = os.getenv("XF_TTS_API_SECRET")
        
        if not all([self.app_id, self.api_key, self.api_secret]):
            raise ValueError("Missing XF_TTS credentials")
        
        self.ws_url = config["xunfei"]["ws_url"]
        self.ws = None

    async def synthesize(self, text: str) -> str:
        """合成音频，返回文件路径"""
        url = self._create_auth_url()
        
        async with websockets.connect(url) as ws:
            self.ws = ws
            await self._send_request(text)
            audio_data = await self._receive_audio()
            return self._save_audio(audio_data)

    def _create_auth_url(self) -> str:
        """生成认证URL"""
        date = datetime.utcnow().strftime("%a, %d %b %Y %H:%M:%S GMT")
        
        signature_origin = f"host: tts-api.xfyun.cn\ndate: {date}\nGET /v2/tts HTTP/1.1"
        signature_sha = hmac.new(
            self.api_secret.encode("utf-8"),
            signature_origin.encode("utf-8"),
            digestmod=hashlib.sha256
        ).digest()
        signature = base64.b64encode(signature_sha).decode()
        
        authorization_origin = (
            f'"'"'api_key="{self.api_key}", algorithm="hmac-sha256", '"'"'
            f'"'"'headers="host date request-line", signature="{signature}"'"'"'
        )
        authorization = base64.b64encode(authorization_origin.encode()).decode()
        
        params = {
            "authorization": authorization,
            "date": date,
            "host": "tts-api.xfyun.cn"
        }
        
        return f"{self.ws_url}?{urlencode(params)}"

    async def _send_request(self, text: str):
        """发送合成请求"""
        params = {
            "common": {"app_id": self.app_id},
            "business": {
                "vcn": self.config["xunfei"]["vcn"],
                "speed": self.config["xunfei"]["speed"],
                "volume": self.config["xunfei"]["volume"],
                "pitch": self.config["xunfei"]["pitch"],
                "aue": self.config["xunfei"]["aue"],
                "tte": "UTF8"
            },
            "data": {
                "text": base64.b64encode(text.encode("utf-8")).decode(),
                "status": 2
            }
        }
        
        await self.ws.send(json.dumps(params))
        self.logger.debug("TTS请求已发送")

    async def _receive_audio(self) -> bytes:
        """接收音频数据流"""
        audio_chunks = []
        timeout = self.config["xunfei"]["timeout"]
        
        try:
            while True:
                msg = await asyncio.wait_for(self.ws.recv(), timeout=timeout)
                data = json.loads(msg)
                code = data.get("code")
                
                if code != 0:
                    raise Exception(f"讯飞TTS错误: {data.get('"'"'message'"'"', '"'"'Unknown'"'"')}")
                
                audio_b64 = data.get("data", {}).get("audio")
                if audio_b64:
                    audio_chunks.append(base64.b64decode(audio_b64))
                
                status = data.get("data", {}).get("status")
                if status == 2:
                    break
            
            return b"".join(audio_chunks)
        
        except asyncio.TimeoutError:
            raise Exception("讯飞TTS超时")

    def _save_audio(self, audio_data: bytes) -> str:
        """保存音频到临时文件"""
        cache_dir = self.config["audio"]["cache_dir"]
        os.makedirs(cache_dir, exist_ok=True)
        
        filename = f"tts_test_{int(datetime.now().timestamp() * 1000)}.mp3"
        filepath = os.path.join(cache_dir, filename)
        
        with open(filepath, "wb") as f:
            f.write(audio_data)
        
        self.logger.info(f"✓ 音频已保存: {filepath}")
        return filepath
'

if [ "$DRY_RUN" = "1" ]; then
    say "DRY-RUN: 将创建 modules/tts/xunfei_provider.py"
else
    echo "$PROVIDER_CODE" > "$PROVIDER_FILE"
    say "✓ 已创建 $PROVIDER_FILE"
fi

# ==================== 3. 创建测试脚本 ====================
TEST_FILE="$ROOT/scripts/test_xunfei_tts.py"
TEST_CODE='#!/usr/bin/env python3
import asyncio
import sys
import os
sys.path.insert(0, "/home/MRwang/smart_assistant")

from core import get_logger, load_config
from modules.tts.xunfei_provider import XunfeiTTSProvider

async def test():
    # 加载环境变量
    if os.path.exists("/home/MRwang/smart_assistant/.env.local"):
        with open("/home/MRwang/smart_assistant/.env.local") as f:
            for line in f:
                if line.startswith("XF_TTS_"):
                    key, val = line.strip().split("=", 1)
                    os.environ[key] = val
    
    config = load_config("config/tts.yml")
    logger = get_logger("test_xunfei")
    
    provider = XunfeiTTSProvider(config, logger)
    
    print("[测试] 正在合成: 你好世界，这是讯飞超拟人语音测试")
    audio_file = await provider.synthesize("你好世界，这是讯飞超拟人语音测试")
    print(f"✓ 测试成功: {audio_file}")
    print(f"可播放: aplay -D plughw:0,0 {audio_file}")

if __name__ == "__main__":
    asyncio.run(test())
'

if [ "$DRY_RUN" = "1" ]; then
    say "DRY-RUN: 将创建 scripts/test_xunfei_tts.py"
else
    echo "$TEST_CODE" > "$TEST_FILE"
    chmod +x "$TEST_FILE"
    say "✓ 已创建 $TEST_FILE"
fi

# ==================== 完成 ====================
if [ "$DRY_RUN" = "1" ]; then
    say "✓ DRY-RUN完成"
else
    say "✓✓✓ 步骤2完成 ✓✓✓"
    say "运行测试: python3 scripts/test_xunfei_tts.py"
fi
