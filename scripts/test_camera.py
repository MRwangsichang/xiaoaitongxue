#!/usr/bin/env python3
import cv2
from pathlib import Path
from datetime import datetime

cap = cv2.VideoCapture(0)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 960)

print("相机预热中，等待3秒...")
for i in range(30):
    cap.read()

print("拍摄测试照片...")
ret, frame = cap.read()
cap.release()

if ret:
    output = Path("/home/MRwang/smart_assistant/data/test_photo.jpg")
    cv2.imwrite(str(output), frame)
    print(f"✓ 照片已保存: {output}")
    print(f"  分辨率: {frame.shape[1]}x{frame.shape[0]}")
else:
    print("✗ 拍摄失败")
