#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
人脸识别测试工具 - 使用v2模型（142张训练）
"""
import sys
import os
from datetime import datetime

# 添加项目路径
sys.path.insert(0, '/home/MRwang/smart_assistant')

from modules.vision.recognizer.face_recognizer import FaceRecognizer

def main():
    MODEL_PATH = "/home/MRwang/smart_assistant/data/faces/model_v2.yml"
    CASCADE_PATH = "/usr/share/opencv4/haarcascades/haarcascade_frontalface_default.xml"
    
    print(f"[{datetime.now().strftime('%H:%M:%S')}] === 人脸识别测试（v2模型）===")
    print(f"[{datetime.now().strftime('%H:%M:%S')}] 加载模型: model_v2.yml")
    
    # 初始化
    recognizer = FaceRecognizer(MODEL_PATH, CASCADE_PATH)
    
    if not recognizer.load_model():
        print(f"[{datetime.now().strftime('%H:%M:%S')}] [✗] 模型加载失败")
        return 1
    
    print(f"[{datetime.now().strftime('%H:%M:%S')}] [✓] 模型加载成功")
    print(f"[{datetime.now().strftime('%H:%M:%S')}] [✓] 相机初始化成功")
    
    # 10帧投票识别（间隔1.5秒，避免相机崩溃）
    name, avg_confidence, consistent_frames = recognizer.recognize_stable(frames=10, interval=1.5)
    
    # 输出结果
    print(f"\n[{datetime.now().strftime('%H:%M:%S')}] === 投票结果 ===")
    print(f"[{datetime.now().strftime('%H:%M:%S')}] 识别为: {name} ({consistent_frames}/10帧一致)")
    print(f"[{datetime.now().strftime('%H:%M:%S')}] 平均置信度: {avg_confidence:.1f}")
    
    if name != "Unknown" and avg_confidence < 75:
        print(f"[{datetime.now().strftime('%H:%M:%S')}] ✓ 可以点名问候")
    elif name != "Unknown" and avg_confidence < 85:
        print(f"[{datetime.now().strftime('%H:%M:%S')}] ✓ 可以问候（不点名）")
    else:
        print(f"[{datetime.now().strftime('%H:%M:%S')}] - 置信度不足或陌生人")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
