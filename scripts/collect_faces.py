#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
人脸采集工具 - 图形界面版
功能：自动化采集人脸照片，10张一组，组间自动停顿5秒
作者：MRwang
创建：2025-10-30
"""

import cv2
import os
import sys
import time
from pathlib import Path
from datetime import datetime

# ============================================================
# 配置参数
# ============================================================
DRY_RUN = os.environ.get('DRY_RUN', '1') == '1'
ROOT = Path("/home/MRwang/smart_assistant")
TARGET_NAME = "王总"
TOTAL_IMAGES = 100
BATCH_SIZE = 10
BATCH_PAUSE = 5  # 组间停顿秒数

# 采集方案（每组的引导语）
COLLECTION_PLAN = [
    "正脸 - 目视前方",      # 第1组
    "正脸 - 目视前方",      # 第2组
    "正脸 - 目视前方",      # 第3组
    "左侧脸 - 头向左转45度", # 第4组
    "右侧脸 - 头向右转45度", # 第5组
    "正脸 - 目视前方",      # 第6组
    "正脸 - 目视前方",      # 第7组
    "微笑 - 露出牙齿",      # 第8组
    "其他表情 - 自然放松",   # 第9组
    "其他表情 - 随意发挥",   # 第10组
]

# 相机和检测参数
CAMERA_INDEX = 0
CAPTURE_WIDTH = 1280
CAPTURE_HEIGHT = 960
DISPLAY_WIDTH = 640
DISPLAY_HEIGHT = 480
BLUR_THRESHOLD = 100  # Laplacian方差阈值
CASCADE_PATH = "/usr/share/opencv4/haarcascades/haarcascade_frontalface_default.xml"

# ============================================================
# 工具函数
# ============================================================
def log(msg):
    """带时间戳的日志"""
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}")

def check_blur(image):
    """检测图像是否模糊（Laplacian方差法）"""
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    variance = cv2.Laplacian(gray, cv2.CV_64F).var()
    return variance

def detect_faces(image, face_cascade):
    """检测人脸，返回人脸框列表"""
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    faces = face_cascade.detectMultiScale(
        gray,
        scaleFactor=1.1,
        minNeighbors=5,
        minSize=(100, 100)
    )
    return faces

def draw_overlay(frame, batch_num, img_count, total, instruction, faces_detected):
    """在画面上绘制覆盖文字"""
    overlay = frame.copy()
    h, w = frame.shape[:0]
    
    # 半透明黑色背景
    cv2.rectangle(overlay, (0, 0), (w, 120), (0, 0, 0), -1)
    cv2.addWeighted(overlay, 0.6, frame, 0.4, 0, frame)
    
    # 标题
    cv2.putText(frame, f"Face Collection - {TARGET_NAME}", 
                (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 255), 2)
    
    # 进度信息
    progress_text = f"Batch {batch_num}/10 | Photo {img_count}/{total}"
    cv2.putText(frame, progress_text, 
                (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
    
    # 当前任务
    cv2.putText(frame, f"Task: {instruction}", 
                (10, 90), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (100, 255, 100), 2)
    
    # 人脸检测状态
    status_color = (0, 255, 0) if faces_detected > 0 else (0, 0, 255)
    status_text = f"Faces: {faces_detected}" if faces_detected > 0 else "No Face Detected!"
    cv2.putText(frame, status_text, 
                (10, 115), cv2.FONT_HERSHEY_SIMPLEX, 0.6, status_color, 2)
    
    # 底部提示
    cv2.putText(frame, "Press SPACE to capture | Press Q to quit", 
                (10, h - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)
    
    return frame

def countdown_overlay(frame, seconds):
    """显示倒计时覆盖"""
    overlay = frame.copy()
    h, w = frame.shape[:2]
    
    # 半透明覆盖
    cv2.rectangle(overlay, (0, 0), (w, h), (0, 0, 0), -1)
    cv2.addWeighted(overlay, 0.7, frame, 0.3, 0, frame)
    
    # 大号倒计时
    text = f"Next batch in {seconds}s"
    font_scale = 2.0
    thickness = 3
    text_size = cv2.getTextSize(text, cv2.FONT_HERSHEY_SIMPLEX, font_scale, thickness)[0]
    text_x = (w - text_size[0]) // 2
    text_y = (h + text_size[1]) // 2
    
    cv2.putText(frame, text, (text_x, text_y), 
                cv2.FONT_HERSHEY_SIMPLEX, font_scale, (0, 255, 255), thickness)
    
    cv2.putText(frame, "Adjust your pose now!", 
                (text_x - 50, text_y + 60), 
                cv2.FONT_HERSHEY_SIMPLEX, 1.0, (100, 255, 100), 2)
    
    return frame

# ============================================================
# 主采集流程
# ============================================================
def main():
    if CASCADE_PATH is None:
        log("[✗] 无法找到 Haar Cascade 文件")
        log("请安装完整的 opencv-contrib-python:")
        log("  pip3 install opencv-contrib-python --break-system-packages")
        return 1
    
    if DRY_RUN:
        log("=== 人脸采集工具 - 预演模式 ===")
    else:
        log(f"=== 开始采集{TARGET_NAME}的人脸照片 ===")
    
    log(f"目标人物: {TARGET_NAME}")
    log(f"采集数量: {TOTAL_IMAGES}张")
    log(f"分组策略: {TOTAL_IMAGES//BATCH_SIZE}组 × {BATCH_SIZE}张/组，组间停顿{BATCH_PAUSE}秒")
    
    # 准备输出目录
    output_dir = ROOT / "data" / "faces" / TARGET_NAME / "raw"
    if not DRY_RUN:
        output_dir.mkdir(parents=True, exist_ok=True)
        # 如果目录中已有文件，备份
        existing_files = list(output_dir.glob("*.png"))
        if existing_files:
            backup_dir = output_dir.parent / f"raw_backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
            backup_dir.mkdir(exist_ok=True)
            log(f"发现已有{len(existing_files)}张照片，备份至: {backup_dir.name}")
            for f in existing_files:
                f.rename(backup_dir / f.name)
    
    # 初始化相机
    cap = cv2.VideoCapture(CAMERA_INDEX)
    if not cap.isOpened():
        log("[✗] 无法打开相机设备")
        return 1
    
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, CAPTURE_WIDTH)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, CAPTURE_HEIGHT)
    log("[✓] 相机初始化成功: /dev/video0")
    
    # 加载人脸检测器
    face_cascade = cv2.CascadeClassifier(CASCADE_PATH)
    if face_cascade.empty():
        log(f"[✗] 无法加载人脸检测器: {CASCADE_PATH}")
        cap.release()
        return 1
    log(f"[✓] 人脸检测器加载成功: {CASCADE_PATH}")
    
    if DRY_RUN:
        log("DRY-RUN: GUI窗口将打开，但不会保存照片")
    
    log("按 SPACE 键启动自动连拍 | 按 Q 键退出")
    
    # 采集循环
    img_counter = 0
    batch_num = 1
    batch_counter = 0
    
    cv2.namedWindow("Face Collection", cv2.WINDOW_NORMAL)
    cv2.resizeWindow("Face Collection", DISPLAY_WIDTH, DISPLAY_HEIGHT)
    
    auto_capture = False  # 自动连拍模式
    
    while img_counter < TOTAL_IMAGES:
        ret, frame = cap.read()
        if not ret:
            log("[✗] 无法读取相机画面")
            break
        
        # 检测人脸
        faces = detect_faces(frame, face_cascade)
        
        # 绘制人脸框
        for (x, y, w, h) in faces:
            cv2.rectangle(frame, (x, y), (x+w, y+h), (0, 255, 0), 2)
        
        # 获取当前任务指令
        instruction = COLLECTION_PLAN[batch_num - 1]
        
        # 绘制覆盖信息
        display_frame = cv2.resize(frame, (DISPLAY_WIDTH, DISPLAY_HEIGHT))
        display_frame = draw_overlay(
            display_frame, 
            batch_num, 
            img_counter, 
            TOTAL_IMAGES, 
            instruction,
            len(faces)
        )
        
        cv2.imshow("Face Collection", display_frame)
        
        # 自动连拍模式
        if auto_capture and batch_counter < BATCH_SIZE:
            if len(faces) > 0:
                # 质量检查
                blur_score = check_blur(frame)
                if blur_score > BLUR_THRESHOLD:
                    img_counter += 1
                    batch_counter += 1
                    
                    if not DRY_RUN:
                        img_name = f"img_{img_counter:04d}.png"
                        img_path = output_dir / img_name
                        cv2.imwrite(str(img_path), frame)
                        log(f"[{batch_counter}/{BATCH_SIZE}] 拍摄成功 → {img_name}")
                    else:
                        log(f"[{batch_counter}/{BATCH_SIZE}] DRY-RUN: 模拟拍摄 (未保存)")
                    
                    time.sleep(0.3)  # 短暂延迟，避免拍到重复画面
                else:
                    log(f"[!] 图像模糊 (score={blur_score:.1f})，跳过")
                    time.sleep(0.1)
            else:
                log("[!] 未检测到人脸，等待...")
                time.sleep(0.2)
        
        # 检查是否完成一组
        if batch_counter == BATCH_SIZE and batch_num < TOTAL_IMAGES // BATCH_SIZE:
            auto_capture = False
            log(f">>> 第{batch_num}组完成！停顿{BATCH_PAUSE}秒，请调整姿势...")
            
            # 倒计时显示
            for i in range(BATCH_PAUSE, 0, -1):
                ret, frame = cap.read()
                if ret:
                    display_frame = cv2.resize(frame, (DISPLAY_WIDTH, DISPLAY_HEIGHT))
                    display_frame = countdown_overlay(display_frame, i)
                    cv2.imshow("Face Collection", display_frame)
                    cv2.waitKey(1000)
            
            # 开始下一组
            batch_num += 1
            batch_counter = 0
            log(f"第{batch_num}组/共{TOTAL_IMAGES//BATCH_SIZE}组 - 任务：{COLLECTION_PLAN[batch_num-1]}")
            auto_capture = True
            continue
        
        # 键盘控制
        key = cv2.waitKey(1) & 0xFF
        if key == ord(' '):  # 空格键：启动自动连拍
            if not auto_capture:
                log(f"第{batch_num}组/共{TOTAL_IMAGES//BATCH_SIZE}组 - 任务：{instruction}")
                auto_capture = True
        elif key == ord('q') or key == 27:  # Q键或ESC：退出
            log("用户手动退出")
            break
    
    # 清理资源
    cap.release()
    cv2.destroyAllWindows()
    
    if img_counter >= TOTAL_IMAGES:
        if not DRY_RUN:
            log(f"=== 采集完成！共保存{img_counter}张照片 ===")
            log(f"照片保存路径: {output_dir}")
        else:
            log(f"=== DRY-RUN 完成！模拟采集{img_counter}张照片 ===")
        return 0
    else:
        log(f"[!] 采集未完成，仅采集了{img_counter}张")
        return 1

if __name__ == "__main__":
    sys.exit(main())
