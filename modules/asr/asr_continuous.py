#!/usr/bin/env python3
"""
讯飞ASR持续监听版本
"""

import asyncio
import json
import base64
import hashlib
import hmac
import time
from datetime import datetime
from urllib.parse import urlencode
import websockets
import pyaudio
import numpy as np
from asyncio_mqtt import Client as MQTTClient
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s | %(levelname)-7s | %(message)s',
    datefmt='%H:%M:%S'
)
logger = logging.getLogger("asr")

# 配置
config = {
    "app_id": "b43105c1",
    "api_key": "26ad710fb6adb11484dc7b4a955a465f",
    "api_secret": "ZDA4Yzk1Yzc4YWYyZWZkZWM3YThkMzVm"
}

class ContinuousASR:
    def __init__(self):
        self.mqtt_client = None
        self.pyaudio_instance = None
        self.stream = None
        self.is_listening = False
        self.is_recording = False
        
        # VAD参数
        self.energy_threshold = 500  # 能量阈值
        self.silence_frames = 15     # 静音帧数（约1.5秒）
        
    def create_url(self):
        """生成讯飞WebSocket URL"""
        url = 'wss://ws-api.xfyun.cn/v2/iat'
        date = datetime.now().strftime('%a, %d %b %Y %H:%M:%S GMT')
        
        signature_origin = f"host: ws-api.xfyun.cn\ndate: {date}\nGET /v2/iat HTTP/1.1"
        signature_sha = hmac.new(
            config['api_secret'].encode('utf-8'),
            signature_origin.encode('utf-8'),
            digestmod=hashlib.sha256
        ).digest()
        
        signature_sha_base64 = base64.b64encode(signature_sha).decode('utf-8')
        authorization_origin = f'api_key="{config["api_key"]}", algorithm="hmac-sha256", headers="host date request-line", signature="{signature_sha_base64}"'
        authorization = base64.b64encode(authorization_origin.encode('utf-8')).decode('utf-8')
        
        v = {"authorization": authorization, "date": date, "host": "ws-api.xfyun.cn"}
        return url + '?' + urlencode(v)
        
    async def connect_mqtt(self):
        """连接MQTT"""
        self.mqtt_client = MQTTClient("localhost")
        await self.mqtt_client.connect()
        logger.info("连接到MQTT broker")
        
    async def publish_result(self, text):
        """发布识别结果"""
        if not text.strip():
            return
            
        message = {
            "id": f"asr-{int(time.time()*1000)}",
            "ts": datetime.now().strftime("%Y-%m-%dT%H:%M:%S.%fZ"),
            "source": "asr",
            "type": "text",
            "payload": {"text": text, "timestamp": time.time(), "final": True},
            "meta": {"ver": "1.0"}
        }
        
        await self.mqtt_client.publish("sa/asr/text", json.dumps(message))
        logger.info(f"发布: {text}")
        
    async def recognize_once(self, audio_buffer):
        """识别一次语音"""
        try:
            ws = await websockets.connect(self.create_url())
            logger.info("开始识别...")
            
            result_text = ""
            
            # 发送音频数据
            async def send():
                # 第一帧
                first_frame = {
                    "common": {"app_id": config['app_id']},
                    "business": {"language": "zh_cn", "domain": "iat", "accent": "mandarin"},
                    "data": {
                        "status": 0,
                        "format": "audio/L16;rate=16000",
                        "encoding": "raw",
                        "audio": base64.b64encode(audio_buffer[0]).decode()
                    }
                }
                await ws.send(json.dumps(first_frame))
                
                # 中间帧
                for chunk in audio_buffer[1:-1]:
                    frame = {
                        "data": {
                            "status": 1,
                            "format": "audio/L16;rate=16000",
                            "encoding": "raw",
                            "audio": base64.b64encode(chunk).decode()
                        }
                    }
                    await ws.send(json.dumps(frame))
                    await asyncio.sleep(0.04)
                    
                # 最后一帧
                last_frame = {"data": {"status": 2, "format": "audio/L16;rate=16000", "encoding": "raw", "audio": ""}}
                await ws.send(json.dumps(last_frame))
                
            # 接收结果
            async def receive():
                nonlocal result_text
                while True:
                    try:
                        message = await ws.recv()
                        data = json.loads(message)
                        
                        if data.get('code') != 0:
                            logger.error(f"识别错误: {data.get('message')}")
                            break
                            
                        # 提取文本
                        for ws_item in data.get('data', {}).get('result', {}).get('ws', []):
                            for cw in ws_item.get('cw', []):
                                result_text += cw.get('w', '')
                                
                        # 结束
                        if data.get('data', {}).get('status') == 2:
                            break
                    except:
                        break
                        
            await asyncio.gather(send(), receive())
            await ws.close()
            
            return result_text
            
        except Exception as e:
            logger.error(f"识别失败: {e}")
            return ""
            
    async def listen_continuous(self):
        """持续监听"""
        # 初始化PyAudio
        self.pyaudio_instance = pyaudio.PyAudio()
        self.stream = self.pyaudio_instance.open(
            format=pyaudio.paInt16,
            channels=1,
            rate=16000,
            input=True,
            frames_per_buffer=1280
        )
        
        logger.info("=== 持续监听模式启动 ===")
        logger.info("请说话，静音1.5秒后自动识别")
        logger.info("按Ctrl+C退出")
        
        audio_buffer = []
        silence_count = 0
        is_speaking = False
        
        while True:
            try:
                # 读取音频
                chunk = self.stream.read(1280, exception_on_overflow=False)
                
                # 计算能量
                audio_array = np.frombuffer(chunk, dtype=np.int16)
                energy = np.abs(audio_array).mean()
                if energy > 100:
                    print(f"能量: {energy:.0f}", end="\r")
                
                if energy > self.energy_threshold:
                    # 检测到声音
                    if not is_speaking:
                        logger.info("检测到语音...")
                        is_speaking = True
                        audio_buffer = []
                    
                    audio_buffer.append(chunk)
                    silence_count = 0
                    
                elif is_speaking:
                    # 正在说话但当前静音
                    audio_buffer.append(chunk)
                    silence_count += 1
                    
                    if silence_count > self.silence_frames:
                        # 静音超过阈值，开始识别
                        logger.info(f"静音结束，开始识别（{len(audio_buffer)}帧）")
                        
                        if len(audio_buffer) > 5:  # 至少要有一些内容
                            text = await self.recognize_once(audio_buffer)
                            if text:
                                await self.publish_result(text)
                                
                        # 重置状态
                        is_speaking = False
                        silence_count = 0
                        audio_buffer = []
                        
            except KeyboardInterrupt:
                logger.info("退出监听")
                break
            except Exception as e:
                logger.error(f"错误: {e}")
                await asyncio.sleep(1)
                
async def main():
    asr = ContinuousASR()
    await asr.connect_mqtt()
    await asr.listen_continuous()

if __name__ == "__main__":
    asyncio.run(main())
