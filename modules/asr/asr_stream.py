#!/usr/bin/env python3
"""
讯飞ASR流式识别版本 - 边录边传
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
import threading
from queue import Queue

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

class StreamASR:
    def __init__(self):
        self.mqtt_client = None
        self.audio_queue = Queue()
        self.is_recording = False
        
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
        logger.info(f"识别结果: {text}")
        
    def audio_recorder(self):
        """录音线程"""
        p = pyaudio.PyAudio()
        stream = p.open(
            format=pyaudio.paInt16,
            channels=1,
            rate=16000,
            input=True,
            frames_per_buffer=1280
        )
        
        logger.info("录音线程启动")
        
        energy_threshold = 800
        silence_frames = 30
        silence_count = 0
        is_speaking = False
        
        while True:
            chunk = stream.read(1280, exception_on_overflow=False)
            
            # 计算能量
            audio_array = np.frombuffer(chunk, dtype=np.int16)
            energy = np.abs(audio_array).mean()
            
            if energy > energy_threshold:
                if not is_speaking:
                    logger.info("检测到语音，开始识别...")
                    is_speaking = True
                    self.is_recording = True
                    silence_count = 0
                    
                self.audio_queue.put(chunk)
                
            elif is_speaking:
                self.audio_queue.put(chunk)
                silence_count += 1
                
                if silence_count > silence_frames:
                    logger.info("语音结束")
                    self.audio_queue.put(None)  # 结束标记
                    is_speaking = False
                    self.is_recording = False
                    silence_count = 0
                    
    async def recognize_stream(self):
        """流式识别"""
        while True:
            # 等待开始录音
            while not self.is_recording:
                await asyncio.sleep(0.1)
                
            try:
                ws = await websockets.connect(self.create_url())
                result_text = ""
                frame_id = 0
                
                # 发送任务
                async def send():
                    nonlocal frame_id
                    while True:
                        # 从队列获取音频
                        chunk = self.audio_queue.get()
                        
                        if chunk is None:  # 结束标记
                            # 发送结束帧
                            end_frame = {
                                "data": {
                                    "status": 2,
                                    "format": "audio/L16;rate=16000",
                                    "encoding": "raw",
                                    "audio": ""
                                }
                            }
                            await ws.send(json.dumps(end_frame))
                            break
                            
                        # 构建帧
                        if frame_id == 0:
                            # 第一帧
                            frame = {
                                "common": {"app_id": config['app_id']},
                                "business": {
                                    "language": "zh_cn",
                                    "domain": "iat",
                                    "accent": "mandarin",
                                    "vad_eos": 3000
                                },
                                "data": {
                                    "status": 0,
                                    "format": "audio/L16;rate=16000",
                                    "encoding": "raw",
                                    "audio": base64.b64encode(chunk).decode()
                                }
                            }
                        else:
                            # 中间帧
                            frame = {
                                "data": {
                                    "status": 1,
                                    "format": "audio/L16;rate=16000",
                                    "encoding": "raw",
                                    "audio": base64.b64encode(chunk).decode()
                                }
                            }
                            
                        await ws.send(json.dumps(frame))
                        frame_id += 1
                        
                # 接收任务
                async def receive():
                    nonlocal result_text
                    while True:
                        try:
                            msg = await ws.recv()
                            data = json.loads(msg)
                            
                            if data.get('code') != 0:
                                logger.error(f"错误: {data.get('message')}")
                                break
                                
                            # 提取文本
                            for ws_item in data.get('data', {}).get('result', {}).get('ws', []):
                                for cw in ws_item.get('cw', []):
                                    result_text += cw.get('w', '')
                                    
                            # 识别结束
                            if data.get('data', {}).get('status') == 2:
                                break
                        except:
                            break
                            
                # 并行执行
                await asyncio.gather(send(), receive())
                await ws.close()
                
                # 发布结果
                if result_text:
                    await self.publish_result(result_text)
                    
                # 清空队列
                while not self.audio_queue.empty():
                    self.audio_queue.get()
                    
            except Exception as e:
                logger.error(f"识别错误: {e}")
                self.is_recording = False
                
    async def run(self):
        """主运行"""
        await self.connect_mqtt()
        
        # 启动录音线程
        recorder_thread = threading.Thread(target=self.audio_recorder, daemon=True)
        recorder_thread.start()
        
        logger.info("=== 流式识别启动 ===")
        logger.info("说话后自动识别，按Ctrl+C退出")
        
        # 运行识别
        await self.recognize_stream()

async def main():
    asr = StreamASR()
    await asr.run()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("退出")
