"""讯飞超拟人TTS Provider - WebSocket实时合成"""
import asyncio
import websockets
import json
import hmac
import hashlib
import base64
from urllib.parse import urlencode, urlparse
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
        
        # 从ws_url中提取host和path（用于鉴权）
        parsed = urlparse(self.ws_url)
        self.host = parsed.netloc
        self.path = parsed.path
        
        self.ws = None
        self.logger.info(f"讯飞TTS初始化完成 [host={self.host}, path={self.path}]")

    async def synthesize(self, text: str) -> str:
        """合成音频，返回文件路径"""
        url = self._create_auth_url()

        async with websockets.connect(url) as ws:
            self.ws = ws
            await self._send_request(text)
            audio_data = await self._receive_audio()
            return self._save_audio(audio_data)

    def _create_auth_url(self) -> str:
        """生成认证URL（动态使用ws_url的host和path）"""
        date = datetime.utcnow().strftime("%a, %d %b %Y %H:%M:%S GMT")

        # 使用动态提取的host和path
        signature_origin = f"host: {self.host}\ndate: {date}\nGET {self.path} HTTP/1.1"
        signature_sha = hmac.new(
            self.api_secret.encode("utf-8"),
            signature_origin.encode("utf-8"),
            digestmod=hashlib.sha256
        ).digest()
        signature = base64.b64encode(signature_sha).decode()

        authorization_origin = (
            f'api_key="{self.api_key}", algorithm="hmac-sha256", '
            f'headers="host date request-line", signature="{signature}"'
        )
        authorization = base64.b64encode(authorization_origin.encode()).decode()

        params = {
            "authorization": authorization,
            "date": date,
            "host": self.host
        }

        return f"{self.ws_url}?{urlencode(params)}"

    async def _send_request(self, text: str):
        """发送合成请求（x5格式）"""
        params = {
            "header": {
                "app_id": self.app_id,
                "status": 2
            },
            "parameter": {
                "tts": {
                    "vcn": self.config["xunfei"]["vcn"],
                    "speed": self.config["xunfei"]["speed"],
                    "volume": self.config["xunfei"]["volume"],
                    "pitch": self.config["xunfei"]["pitch"],
                    "audio": {
                        "encoding": self.config["xunfei"]["aue"],
                        "sample_rate": 24000,
                        "channels": 1,
                        "bit_depth": 16,
                        "frame_size": 0
                    }
                }
            },
            "payload": {
                "text": {
                    "encoding": "utf8",
                    "compress": "raw",
                    "format": "plain",
                    "status": 2,
                    "seq": 0,
                    "text": base64.b64encode(text.encode("utf-8")).decode()
                }
            }
        }

        await self.ws.send(json.dumps(params))

    async def _receive_audio(self) -> bytes:
        """接收音频数据流（x5格式）"""
        audio_chunks = []
        timeout = self.config["xunfei"]["timeout"]

        try:
            while True:
                msg = await asyncio.wait_for(self.ws.recv(), timeout=timeout)
                data = json.loads(msg)
                code = data.get("header", {}).get("code")

                if code != 0:
                    self.logger.error(f"讯飞错误: {json.dumps(data, ensure_ascii=False)}")
                    raise Exception(f"讯飞TTS错误 {code}: {data.get('header', {}).get('message', 'Unknown')}")

                audio_b64 = data.get("payload", {}).get("audio", {}).get("audio")
                if audio_b64:
                    audio_chunks.append(base64.b64decode(audio_b64))

                status = data.get("header", {}).get("status")
                if status == 2:
                    break

            return b"".join(audio_chunks)

        except asyncio.TimeoutError:
            raise Exception("讯飞TTS超时")

    def _save_audio(self, audio_data: bytes) -> str:
        """保存音频到临时文件"""
        cache_dir = self.config["audio"]["cache_dir"]
        os.makedirs(cache_dir, exist_ok=True)

        filename = f"tts_xunfei_{int(datetime.now().timestamp() * 1000)}.mp3"
        filepath = os.path.join(cache_dir, filename)

        with open(filepath, "wb") as f:
            f.write(audio_data)

        self.logger.info(f"✓ 讯飞音频已保存: {filepath}")
        return filepath
