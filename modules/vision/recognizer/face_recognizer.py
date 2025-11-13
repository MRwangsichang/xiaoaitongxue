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

# 添加项目根目录到路径
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__)))))

from core.logger import get_logger

# 初始化日志
logger = get_logger('vision.recognizer')

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
            logger.info(f"加载LBPH模型: {self.model_path}")
            
            # 加载LBPH模型
            self.recognizer = cv2.face.LBPHFaceRecognizer_create()
            self.recognizer.read(self.model_path)
            
            # 加载Haar级联检测器
            self.face_cascade = cv2.CascadeClassifier(self.cascade_path)
            
            logger.info("模型加载成功")
            return True
            
        except Exception as e:
            logger.error(f"模型加载失败: {e}")
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
            time.sleep(0.3)
        except Exception as e:
            logger.warning(f"停止服务时出错: {e}")
    
    def _capture_photo(self, output_path):
        """拍摄一张照片"""
        try:
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
            
            if result.returncode == 0:
                return True
            else:
                logger.error(f"拍照失败: {result.stderr}")
                return False
                
        except Exception as e:
            logger.error(f"拍照异常: {e}")
            return False
    
    def _preprocess_face(self, image_path):
        """
        预处理：Haar检测 → 裁剪最大人脸框 → 转灰度 → resize(112×112)
        必须和训练时完全一致！
        """
        try:
            # 读取原图
            img = cv2.imread(image_path)
            if img is None:
                logger.warning(f"无法读取图片: {image_path}")
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
            
        except Exception as e:
            logger.error(f"预处理异常: {e}")
            return None
    
    def recognize_single(self, image_path):
        """
        单帧识别
        返回：(姓名, 置信度) 或 (None, None)
        """
        try:
            # 预处理
            face = self._preprocess_face(image_path)
            if face is None:
                return None, None
            
            # LBPH识别
            label, confidence = self.recognizer.predict(face)
            
            # 置信度判定
            if confidence < 75:
                # 高置信度，可点名
                name = LABEL_MAP.get(label, "Unknown")
                return name, confidence
            elif confidence < 85:
                # 中置信度，问候但不点名
                name = LABEL_MAP.get(label, "Unknown")
                return name, confidence
            else:
                # 陌生人
                return "Unknown", confidence
                
        except Exception as e:
            logger.error(f"识别异常: {e}")
            return None, None
    
    def recognize_stable(self, temp_dir="/tmp", frames=10, interval=0.6):
        """
        10帧投票识别
        frames: 拍摄帧数
        interval: 每帧间隔（秒）
        返回：(姓名, 平均置信度, 一致帧数)
        """
        results = []
        
        logger.info(f"开始{frames}帧投票识别（间隔{interval}秒）")
        print(f"\n[{datetime.now().strftime('%H:%M:%S')}] 开始{frames}帧投票识别...")
        
        for i in range(1, frames + 1):
            # 拍照
            temp_photo = os.path.join(temp_dir, f"frame_{i}.jpg")
            
            if not self._capture_photo(temp_photo):
                logger.warning(f"帧{i}: 拍照失败")
                print(f"[{datetime.now().strftime('%H:%M:%S')}] 帧{i}: 拍照失败")
                continue
            
            # 识别
            name, confidence = self.recognize_single(temp_photo)
            
            if name:
                results.append((name, confidence))
                logger.info(f"帧{i}: {name} (confidence={confidence:.1f})")
                print(f"[{datetime.now().strftime('%H:%M:%S')}] 帧{i}: {name} (confidence={confidence:.1f})")
            else:
                logger.info(f"帧{i}: 未检测到人脸")
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
            logger.warning("所有帧都未识别到人脸")
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
            logger.info(f"识别结果: {most_common_name} ({consistent_frames}/{frames}帧一致, 平均置信度={avg_confidence:.1f})")
            return most_common_name, avg_confidence, consistent_frames
        else:
            logger.warning(f"识别不稳定: {most_common_name} 仅{consistent_frames}/{frames}帧一致")
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
