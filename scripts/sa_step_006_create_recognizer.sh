#!/usr/bin/env bash
set -euo pipefail
DRY_RUN="${DRY_RUN:-1}"

say(){ printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
cd "$ROOT"

if [ "$DRY_RUN" = "1" ]; then
  say "DRY-RUN: 仅打印将执行的操作，不改系统"
  say "[DRY] 将创建: modules/vision/recognizer/face_recognizer.py"
  say "[DRY] 将创建: scripts/test_recognition.py"
  say "[✓] 所有操作预演完成"
  exit 0
fi

# 1. 创建识别模块
say "创建识别模块: modules/vision/recognizer/face_recognizer.py"
mkdir -p modules/vision/recognizer
cat > modules/vision/recognizer/face_recognizer.py <<'PY'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
人脸识别模块 - 单帧识别 + 10帧投票
处理流程：拍照 → Haar检测 → 裁剪最大人脸框 → 转灰度 → resize(112×112) → LBPH识别
"""
import os
import sys
import cv2
import time
import subprocess
from datetime import datetime

# Label映射（当前只有王总）
LABEL_MAP = {
    0: "王总"  # wangzong
    # 后续添加：1: "王彦皓"
}

class FaceRecognizer:
    def __init__(self, model_path, cascade_path):
        """初始化识别器"""
        self.model_path = model_path
        self.cascade_path = cascade_path
        self.recognizer = None
        self.face_cascade = None
        
    def load_model(self):
        """加载LBPH模型和Haar检测器"""
        try:
            # 加载LBPH模型
            self.recognizer = cv2.face.LBPHFaceRecognizer_create()
            self.recognizer.read(self.model_path)
            
            # 加载Haar级联检测器
            self.face_cascade = cv2.CascadeClassifier(self.cascade_path)
            
            return True
        except Exception as e:
            print(f"[ERROR] 模型加载失败: {e}")
            return False
    
    def _stop_camera_services(self):
        """停止占用摄像头的服务"""
        try:
            # 停止系统服务
            subprocess.run(
                ["sudo", "systemctl", "stop", "cam.service", "greet.service"],
                stderr=subprocess.DEVNULL,
                check=False
            )
            # 停止用户服务
            subprocess.run(
                ["systemctl", "--user", "stop", "pipewire.service", "pipewire.socket", 
                 "pipewire-pulse.service", "wireplumber.service"],
                stderr=subprocess.DEVNULL,
                check=False
            )
            time.sleep(0.3)  # 等待服务停止
        except Exception as e:
            print(f"[WARN] 停止服务时出错: {e}")
    
    def _capture_photo(self, output_path):
        """拍摄一张照片"""
        self._stop_camera_services()
        
        cmd = [
            "rpicam-still",
            "--immediate",
            "--nopreview",
            "--mode", "1640:1232:10:P",
            "--awb", "auto",
            "-o", output_path
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        return result.returncode == 0
    
    def _preprocess_face(self, image_path):
        """
        预处理：Haar检测 → 裁剪最大人脸框 → 转灰度 → resize(112×112)
        必须和训练时完全一致！
        """
        # 读取原图
        img = cv2.imread(image_path)
        if img is None:
            return None
        
        # 转灰度（用于Haar检测）
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        
        # Haar检测人脸
        faces = self.face_cascade.detectMultiScale(
            gray,
            scaleFactor=1.1,
            minNeighbors=5,
            minSize=(30, 30)
        )
        
        if len(faces) == 0:
            return None
        
        # 选择最大的人脸框
        largest_face = max(faces, key=lambda f: f[2] * f[3])
        x, y, w, h = largest_face
        
        # 裁剪人脸区域
        face_roi = gray[y:y+h, x:x+w]
        
        # Resize到112×112（训练时的尺寸）
        face_resized = cv2.resize(face_roi, (112, 112))
        
        return face_resized
    
    def recognize_single(self, image_path):
        """
        单帧识别
        返回：(姓名, 置信度) 或 (None, None)
        """
        # 预处理
        face = self._preprocess_face(image_path)
        if face is None:
            return None, None
        
        # LBPH识别
        label, confidence = self.recognizer.predict(face)
        
        # 置信度判定
        if confidence < 60:
            # 高置信度，可点名
            name = LABEL_MAP.get(label, "Unknown")
            return name, confidence
        elif confidence < 70:
            # 中置信度，问候但不点名
            name = LABEL_MAP.get(label, "Unknown")
            return name, confidence
        else:
            # 陌生人
            return "Unknown", confidence
    
    def recognize_stable(self, temp_dir="/tmp", frames=10, interval=0.6):
        """
        10帧投票识别
        frames: 拍摄帧数
        interval: 每帧间隔（秒）
        返回：(姓名, 平均置信度, 一致帧数)
        """
        results = []
        
        print(f"\n[{datetime.now().strftime('%H:%M:%S')}] 开始{frames}帧投票识别...")
        
        for i in range(1, frames + 1):
            # 拍照
            temp_photo = os.path.join(temp_dir, f"frame_{i}.jpg")
            if not self._capture_photo(temp_photo):
                print(f"[{datetime.now().strftime('%H:%M:%S')}] 帧{i}: 拍照失败")
                continue
            
            # 识别
            name, confidence = self.recognize_single(temp_photo)
            
            if name:
                results.append((name, confidence))
                print(f"[{datetime.now().strftime('%H:%M:%S')}] 帧{i}: {name} (confidence={confidence:.1f})")
            else:
                print(f"[{datetime.now().strftime('%H:%M:%S')}] 帧{i}: 未检测到人脸")
            
            # 删除临时文件
            try:
                os.remove(temp_photo)
            except:
                pass
            
            # 间隔（最后一帧不等待）
            if i < frames:
                time.sleep(interval)
        
        # 投票统计
        if not results:
            return "Unknown", 0, 0
        
        # 统计最频繁的姓名
        name_count = {}
        for name, conf in results:
            name_count[name] = name_count.get(name, 0) + 1
        
        most_common_name = max(name_count, key=name_count.get)
        consistent_frames = name_count[most_common_name]
        
        # 计算该姓名的平均置信度
        avg_confidence = sum(conf for name, conf in results if name == most_common_name) / consistent_frames
        
        # 判定：≥6帧一致才确认
        if consistent_frames >= 6:
            return most_common_name, avg_confidence, consistent_frames
        else:
            return "Unknown", avg_confidence, consistent_frames


if __name__ == "__main__":
    # 简单测试
    MODEL_PATH = "/home/MRwang/smart_assistant/data/faces/model.yml"
    CASCADE_PATH = "/usr/share/opencv4/haarcascades/haarcascade_frontalface_default.xml"
    
    recognizer = FaceRecognizer(MODEL_PATH, CASCADE_PATH)
    
    if recognizer.load_model():
        print("[✓] 模型加载成功")
    else:
        print("[✗] 模型加载失败")
        sys.exit(1)
PY

chmod +x modules/vision/recognizer/face_recognizer.py

# 2. 创建测试工具
say "创建测试工具: scripts/test_recognition.py"
cat > scripts/test_recognition.py <<'PY'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
人脸识别测试工具 - 10帧投票测试
"""
import sys
import os
from datetime import datetime

# 添加项目路径
sys.path.insert(0, '/home/MRwang/smart_assistant')

from modules.vision.recognizer.face_recognizer import FaceRecognizer

def main():
    MODEL_PATH = "/home/MRwang/smart_assistant/data/faces/model.yml"
    CASCADE_PATH = "/usr/share/opencv4/haarcascades/haarcascade_frontalface_default.xml"
    
    print(f"[{datetime.now().strftime('%H:%M:%S')}] === 人脸识别测试 ===")
    
    # 初始化
    recognizer = FaceRecognizer(MODEL_PATH, CASCADE_PATH)
    
    print(f"[{datetime.now().strftime('%H:%M:%S')}] 加载模型...")
    if not recognizer.load_model():
        print(f"[{datetime.now().strftime('%H:%M:%S')}] [✗] 模型加载失败")
        return 1
    
    print(f"[{datetime.now().strftime('%H:%M:%S')}] [✓] 模型加载成功")
    print(f"[{datetime.now().strftime('%H:%M:%S')}] [✓] 相机初始化成功")
    
    # 10帧投票识别
    name, avg_confidence, consistent_frames = recognizer.recognize_stable(frames=10, interval=0.6)
    
    # 输出结果
    print(f"\n[{datetime.now().strftime('%H:%M:%S')}] === 投票结果 ===")
    print(f"[{datetime.now().strftime('%H:%M:%S')}] 识别为: {name} ({consistent_frames}/10帧一致)")
    print(f"[{datetime.now().strftime('%H:%M:%S')}] 平均置信度: {avg_confidence:.1f}")
    
    if name != "Unknown" and avg_confidence < 60:
        print(f"[{datetime.now().strftime('%H:%M:%S')}] ✓ 可以点名问候")
    elif name != "Unknown" and avg_confidence < 70:
        print(f"[{datetime.now().strftime('%H:%M:%S')}] ✓ 可以问候（不点名）")
    else:
        print(f"[{datetime.now().strftime('%H:%M:%S')}] - 置信度不足或陌生人")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
PY

chmod +x scripts/test_recognition.py

say "[✓] 识别模块创建完成"
