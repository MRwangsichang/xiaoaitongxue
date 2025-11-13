"""讯飞超拟人TTS Provider - x5系列专用"""
import asyncio
import websockets
import json
import hmac
import hashlib
import base64
from urllib.parse import urlencode
from datetime import datetime
import os

class XunfeiX5TTSProvider:
    def __init__(self, config, logger):
        self.config = config
        self.logger = logger
        
        self.app_id = os.getenv("XF_TTS_APPID")
        self.api_key = os.getenv("XF_TTS_API_KEY")
        self.api_secret = os.getenv("XF_TTS_API_SECRET")
        
        if not all([self.app_id, self.api_key, self.api_secret]):
            raise ValueError("Missing XF_TTS credentials")
        
        # x5专用端点
        self.ws_url = "wss://cbm01.cn-huabei-1.xf-yun.com/v1/private/mcd9m97e6"
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
        """生成认证URL（ws接口鉴权）"""
        # 解析URL
        host = "cbm01.cn-huabei-1.xf-yun.com"
        path = "/v1/private/mcd9m97e6"
        
        date = datetime.utcnow().strftime("%a, %d %b %Y %H:%M:%S GMT")
        
        signature_origin = f"host: {host}\ndate: {date}\nGET {path} HTTP/1.1"
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
            "host": host
        }
        
        return f"{self.ws_url}?{urlencode(params)}"

    async def _send_request(self, text: str):
        """发送合成请求（x5专用格式）"""
        params = {
            "header": {
                "app_id": self.app_id,
                "status": 2  # 一次性合成
            },
            "parameter": {
                "tts": {
                    "vcn": "x5_lingfeiyi_flow",
                    "speed": 50,
                    "volume": 50,
                    "pitch": 50,
                    "audio": {
                        "encoding": "lame",
                        "sample_rate": 24000,
                        "channels": 1,
                        "bit_depth": 16,
                        "frame_size": 0
                    }
                }
                # 注意：x5系列不支持 oral 参数！
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
        
        self.logger.info(f"[DEBUG] x5请求:\n{json.dumps(params, indent=2, ensure_ascii=False)}")
        
        await self.ws.send(json.dumps(params))

    async def _receive_audio(self) -> bytes:
        """接收音频数据流"""
        audio_chunks = []
        timeout = self.config["xunfei"]["timeout"]
        
        try:
            while True:
                msg = await asyncio.wait_for(self.ws.recv(), timeout=timeout)
                data = json.loads(msg)
                
                code = data.get("header", {}).get("code")
                
                if not audio_chunks:
                    self.logger.info(f"[DEBUG] x5首条返回:\n{json.dumps(data, indent=2, ensure_ascii=False)}")
                
                if code != 0:
                    message = data.get("header", {}).get("message", "Unknown")
                    raise Exception(f"讯飞x5错误 {code}: {message}")
                
                # x5返回格式：payload.audio.audio
                audio_b64 = data.get("payload", {}).get("audio", {}).get("audio")
                if audio_b64:
                    audio_chunks.append(base64.b64decode(audio_b64))
                
                # 检查状态
                status = data.get("payload", {}).get("audio", {}).get("status")
                if status == 2:
                    break
            
            return b"".join(audio_chunks)
        
        except asyncio.TimeoutError:
            raise Exception("讯飞x5超时")

    def _save_audio(self, audio_data: bytes) -> str:
        """保存音频到临时文件"""
        cache_dir = self.config["audio"]["cache_dir"]
        os.makedirs(cache_dir, exist_ok=True)
        
        filename = f"tts_x5_{int(datetime.now().timestamp() * 1000)}.mp3"
        filepath = os.path.join(cache_dir, filename)
        
        with open(filepath, "wb") as f:
            f.write(audio_data)
        
        self.logger.info(f"✓ x5音频已保存: {filepath}")
        return filepath
