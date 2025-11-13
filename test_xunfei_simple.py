#!/usr/bin/env python3
"""简化的讯飞ASR测试"""

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

# 配置
config = {
    "app_id": "b43105c1",
    "api_key": "26ad710fb6adb11484dc7b4a955a465f",
    "api_secret": "ZDA4Yzk1Yzc4YWYyZWZkZWM3YThkMzVm"
}

def create_url():
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

async def test_asr():
    """测试ASR"""
    print("开始录音，请说话（3秒）...")
    
    # 初始化PyAudio
    p = pyaudio.PyAudio()
    stream = p.open(format=pyaudio.paInt16, channels=1, rate=16000, input=True, frames_per_buffer=1280)
    
    # 连接讯飞
    ws = await websockets.connect(create_url())
    
    # 录音并发送
    frames_sent = 0
    async def send():
        nonlocal frames_sent
        for i in range(75):  # 约3秒
            audio = stream.read(1280, exception_on_overflow=False)
            
            if i == 0:
                # 第一帧
                data = {
                    "common": {"app_id": config['app_id']},
                    "business": {"language": "zh_cn", "domain": "iat", "accent": "mandarin"},
                    "data": {"status": 0, "format": "audio/L16;rate=16000", "encoding": "raw", 
                            "audio": base64.b64encode(audio).decode()}
                }
            elif i == 74:
                # 最后一帧
                data = {"data": {"status": 2, "format": "audio/L16;rate=16000", "encoding": "raw", "audio": ""}}
            else:
                # 中间帧
                data = {"data": {"status": 1, "format": "audio/L16;rate=16000", "encoding": "raw", 
                                "audio": base64.b64encode(audio).decode()}}
            
            await ws.send(json.dumps(data))
            frames_sent = i + 1
            await asyncio.sleep(0.04)
    
    # 接收结果
    async def receive():
        result_text = ""
        while True:
            try:
                message = await ws.recv()
                data = json.loads(message)
                
                if data.get('code') != 0:
                    print(f"错误: {data.get('message')}")
                    break
                
                # 提取文本
                for ws_item in data.get('data', {}).get('result', {}).get('ws', []):
                    for cw in ws_item.get('cw', []):
                        result_text += cw.get('w', '')
                
                # 结束
                if data.get('data', {}).get('status') == 2:
                    print(f"\n识别结果: {result_text}")
                    
                    # 发布到MQTT
                    async with MQTTClient("localhost") as client:
                        message = {
                            "id": "test-001",
                            "ts": datetime.now().strftime("%Y-%m-%dT%H:%M:%S.%fZ"),
                            "source": "asr",
                            "type": "text",
                            "payload": {"text": result_text, "final": True},
                            "meta": {"ver": "1.0"}
                        }
                        await client.publish("sa/asr/text", json.dumps(message))
                        print("已发布到MQTT")
                    break
            except:
                break
    
    # 并行执行
    await asyncio.gather(send(), receive())
    
    # 清理
    stream.close()
    p.terminate()
    await ws.close()

if __name__ == "__main__":
    asyncio.run(test_asr())
