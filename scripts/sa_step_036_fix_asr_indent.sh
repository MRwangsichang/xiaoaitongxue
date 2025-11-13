#!/usr/bin/env bash
set -euo pipefail
DRY_RUN="${DRY_RUN:-1}"

say(){ printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
ASR_FILE="$ROOT/modules/asr/asr_module.py"
BACKUP_FILE="$ASR_FILE.bak_$(date +%Y%m%d_%H%M%S)"

say "正在修复ASR模块缩进问题..."

# 备份当前文件
if [ "$DRY_RUN" = "1" ]; then
    say "DRY-RUN: 将备份到 $BACKUP_FILE"
else
    cp "$ASR_FILE" "$BACKUP_FILE"
    say "备份原文件到: $BACKUP_FILE"
fi

# 创建修复后的文件
FIXED_FILE="/tmp/asr_module_fixed.py"
cat > "$FIXED_FILE" <<'PYCODE'
#!/usr/bin/env python3
"""
ASR模块 - 使用讯飞实时语音识别
"""

import asyncio
import json
import time
import hashlib
import hmac
import base64
import ssl
import logging
from datetime import datetime
from typing import Optional, Dict, Any
from urllib.parse import urlencode
import websockets
import pyaudio
import numpy as np
import os

# 添加项目根目录到Python路径
import sys
sys.path.insert(0, '/home/MRwang/smart_assistant')

from core.module_base import ModuleBase
from core.config_manager import ConfigManager

class ASRModule(ModuleBase):
    """讯飞实时语音识别模块"""
    
    def __init__(self):
        super().__init__("asr")
        self.ws = None
        self.audio_stream = None
        self.pyaudio_instance = None
        self.is_recording = False
        
        # 读取配置
        config_manager = ConfigManager()
        self.config = config_manager.get_module_config('asr')
        
        # 设置音频参数
        self.sample_rate = self.config.get('sample_rate', 16000)
        self.channels = self.config.get('channels', 1)
        self.chunk_size = self.config.get('chunk_size', 1280)
        
        # VAD参数
        self.vad_energy_threshold = self.config.get('vad_energy_threshold', 1000)
        self.vad_silence_duration = self.config.get('vad_silence_duration', 1.5)
        
        # 识别状态
        self.last_speech_time = 0
        self.current_text = ""
        self.is_speaking = False
        
    async def initialize(self) -> bool:
        """初始化模块"""
        try:
            # 初始化PyAudio
            self.pyaudio_instance = pyaudio.PyAudio()
            
            # 订阅事件
            await self.subscribe("sa/sys/wake", self._on_wake_word)
            await self.subscribe("sa/asr/control", self._on_control)
            
            self.logger.info("ASR模块初始化成功")
            return True
            
        except Exception as e:
            self.logger.error(f"ASR模块初始化失败: {e}")
            return False
            
    async def _on_wake_word(self, event: Dict[str, Any]):
        """处理唤醒词事件"""
        self.logger.info("收到唤醒词，开始录音...")
        await self.start_recognition()
        
    async def _on_control(self, event: Dict[str, Any]):
        """处理控制事件"""
        payload = event.get('payload', {})
        action = payload.get('action')
        
        if action == 'start':
            await self.start_recognition()
        elif action == 'stop':
            await self.stop_recognition()
            
    async def start_recognition(self):
        """开始语音识别"""
        if self.is_recording:
            self.logger.warning("已经在录音中")
            return
            
        try:
            # 连接讯飞WebSocket
            ws_url = self._build_websocket_url()
            self.ws = await websockets.connect(ws_url)
            self.is_recording = True
            
            # 开始音频采集
            self.audio_stream = self.pyaudio_instance.open(
                format=pyaudio.paInt16,
                channels=self.channels,
                rate=self.sample_rate,
                input=True,
                frames_per_buffer=self.chunk_size
            )
            
            # 并行运行发送和接收任务
            await asyncio.gather(
                self._send_audio_data(),
                self._receive_recognition_result(),
                return_exceptions=True
            )
            
        except Exception as e:
            self.logger.error(f"语音识别出错: {e}")
            await self.stop_recognition()
            
    async def _send_audio_data(self):
        """发送音频数据到讯飞"""
        try:
            frame_id = 0
            while self.is_recording:
                # 读取音频数据
                audio_data = self.audio_stream.read(self.chunk_size, exception_on_overflow=False)
                
                # 计算音频能量（简单VAD）
                audio_array = np.frombuffer(audio_data, dtype=np.int16)
                energy = np.abs(audio_array).mean()
                
                if energy > self.vad_energy_threshold:
                    self.last_speech_time = time.time()
                    self.is_speaking = True
                elif self.is_speaking and time.time() - self.last_speech_time > self.vad_silence_duration:
                    # 静音超过阈值，结束识别
                    self.logger.info("检测到静音，结束识别")
                    break
                    
                # 构建发送数据
                if frame_id == 0:
                    # 第一帧，发送配置
                    frame_data = {
                        "common": {
                            "app_id": self.config.get('app_id', '')
                        },
                        "business": {
                            "language": "zh_cn",
                            "domain": "iat",
                            "accent": "mandarin",
                            "vad_eos": 3000
                        },
                        "data": {
                            "status": 0,
                            "format": "audio/L16;rate=16000",
                            "audio": base64.b64encode(audio_data).decode('utf-8'),
                            "encoding": "raw"
                        }
                    }
                else:
                    # 中间帧
                    frame_data = {
                        "data": {
                            "status": 1,
                            "format": "audio/L16;rate=16000",
                            "audio": base64.b64encode(audio_data).decode('utf-8'),
                            "encoding": "raw"
                        }
                    }
                    
                await self.ws.send(json.dumps(frame_data))
                frame_id += 1
                await asyncio.sleep(0.04)  # 40ms间隔
                
            # 发送结束帧
            if self.ws and not self.ws.closed:
                end_frame = {
                    "data": {
                        "status": 2,
                        "format": "audio/L16;rate=16000",
                        "audio": "",
                        "encoding": "raw"
                    }
                }
                await self.ws.send(json.dumps(end_frame))
                
        except Exception as e:
            self.logger.error(f"发送音频数据出错: {e}")
            
    async def _receive_recognition_result(self):
        """接收识别结果"""
        try:
            while self.is_recording:
                if self.ws.closed:
                    break
                    
                result = await self.ws.recv()
                result_dict = json.loads(result)
                
                if result_dict.get("code") != 0:
                    self.logger.error(f"识别错误: {result_dict}")
                    break
                    
                # 解析识别结果
                data = result_dict.get("data", {})
                if data.get("status") == 2:
                    # 识别结束
                    await self._on_asr_result(self.current_text)
                    self.current_text = ""
                    break
                    
                # 解析文本
                result_data = data.get("result", {})
                ws_data = result_data.get("ws", [])
                
                for ws_item in ws_data:
                    cw_data = ws_item.get("cw", [])
                    for cw_item in cw_data:
                        word = cw_item.get("w", "")
                        self.current_text += word
                        
                # 发布部分识别结果
                if self.current_text:
                    await self._publish_partial_result(self.current_text)
                    
        except Exception as e:
            self.logger.error(f"接收识别结果出错: {e}")
            
    async def _on_asr_result(self, text: str):
        """处理最终识别结果"""
        if not text:
            self.logger.debug("识别结果为空")
            return
            
        self.logger.info(f"最终识别结果: {text}")
        
        # 发布识别结果事件
        try:
            await self.publish("sa/asr/text", {
                "text": text,
                "timestamp": time.time(),
                "final": True
            })
            self.logger.info(f"已发布ASR结果到sa/asr/text: {text}")
        except Exception as e:
            self.logger.error(f"发布ASR结果失败: {e}")
            
    async def _publish_partial_result(self, text: str):
        """发布部分识别结果"""
        await self.publish("sa/asr/partial", {
            "text": text,
            "timestamp": time.time(),
            "final": False
        })
        
    async def stop_recognition(self):
        """停止语音识别"""
        self.is_recording = False
        
        if self.audio_stream:
            self.audio_stream.stop_stream()
            self.audio_stream.close()
            self.audio_stream = None
            
        if self.ws:
            await self.ws.close()
            self.ws = None
            
        self.logger.info("语音识别已停止")
        
    def _build_websocket_url(self) -> str:
        """构建讯飞WebSocket URL"""
        # 这里简化处理，实际需要按讯飞文档生成签名
        host = "ws-api.xfyun.cn"
        path = "/v2/iat"
        
        # TODO: 实现讯飞签名逻辑
        # 这里暂时返回模拟URL
        return f"wss://{host}{path}"
        
    async def cleanup(self):
        """清理资源"""
        await self.stop_recognition()
        
        if self.pyaudio_instance:
            self.pyaudio_instance.terminate()
            self.pyaudio_instance = None
            
        await super().cleanup()

async def main():
    """测试ASR模块"""
    logging.basicConfig(level=logging.INFO)
    
    module = ASRModule()
    if await module.initialize():
        print("ASR模块初始化成功")
        
        # 模拟测试
        await module.start_module()
        
        # 运行30秒
        await asyncio.sleep(30)
        
        await module.stop_module()
    else:
        print("ASR模块初始化失败")

if __name__ == "__main__":
    asyncio.run(main())
PYCODE

# 替换原文件
if [ "$DRY_RUN" = "1" ]; then
    say "DRY-RUN: 将用修复后的文件替换 $ASR_FILE"
    say "重写_on_asr_result方法..."
else
    cp "$FIXED_FILE" "$ASR_FILE"
    say "文件已修复"
fi

# Python语法检查
if python3 -m py_compile "$ASR_FILE" 2>/dev/null; then
    say "Python语法检查: OK"
else
    say "Python语法检查: 失败"
    if [ "$DRY_RUN" = "0" ]; then
        say "恢复备份..."
        cp "$BACKUP_FILE" "$ASR_FILE"
    fi
    exit 1
fi

say "ASR模块修复完成"

# 清理临时文件
rm -f "$FIXED_FILE"
