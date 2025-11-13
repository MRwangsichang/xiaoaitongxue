#!/usr/bin/env bash
set -euo pipefail
DRY_RUN="${DRY_RUN:-1}"

say(){ printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
INPUT_DIR="$ROOT/data/faces/wangzong_glasses/raw"
OUTPUT_DIR="$ROOT/data/faces/wangzong_glasses/processed"
CASCADE="/usr/share/opencv4/haarcascades/haarcascade_frontalface_default.xml"

if [ "$DRY_RUN" = "1" ]; then
  say "DRY-RUN: 仅打印将执行的操作"
  say "[DRY] 输入: $INPUT_DIR"
  say "[DRY] 输出: $OUTPUT_DIR"
  say "[DRY] 将预处理50张照片（Haar检测 → 裁剪 → 灰度 → 112×112）"
  say "[✓] 预演完成"
  exit 0
fi

say "=== 预处理新人脸照片 ==="
say "输入: wangzong_glasses/raw/ (50张)"
say "输出: wangzong_glasses/processed/"

mkdir -p "$OUTPUT_DIR"

# 创建Python预处理脚本
cat > /tmp/preprocess_faces.py <<'PY'
#!/usr/bin/env python3
import cv2
import sys
import os

def preprocess_face(input_path, output_path, cascade_path):
    """预处理：Haar检测 → 裁剪最大人脸框 → 转灰度 → resize(112×112)"""
    try:
        # 读取原图
        img = cv2.imread(input_path)
        if img is None:
            return False, "无法读取图片"
        
        # 转灰度
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        
        # Haar检测人脸
        face_cascade = cv2.CascadeClassifier(cascade_path)
        faces = face_cascade.detectMultiScale(
            gray,
            scaleFactor=1.1,
            minNeighbors=5,
            minSize=(30, 30)
        )
        
        if len(faces) == 0:
            return False, "未检测到人脸"
        
        # 选择最大的人脸框
        largest_face = max(faces, key=lambda f: f[2] * f[3])
        x, y, w, h = largest_face
        
        # 裁剪人脸区域
        face_roi = gray[y:y+h, x:x+w]
        
        # Resize到112×112
        face_resized = cv2.resize(face_roi, (112, 112))
        
        # 保存
        cv2.imwrite(output_path, face_resized)
        return True, "成功"
        
    except Exception as e:
        return False, str(e)

if __name__ == "__main__":
    input_dir = sys.argv[1]
    output_dir = sys.argv[2]
    cascade_path = sys.argv[3]
    
    # 处理所有jpg文件
    files = sorted([f for f in os.listdir(input_dir) if f.endswith('.jpg')])
    total = len(files)
    success = 0
    failed = 0
    
    for idx, filename in enumerate(files, 1):
        input_path = os.path.join(input_dir, filename)
        # 输出文件名：img_0101.jpg -> face_0101.jpg
        output_filename = filename.replace('img_', 'face_')
        output_path = os.path.join(output_dir, output_filename)
        
        ok, msg = preprocess_face(input_path, output_path, cascade_path)
        
        if ok:
            print(f"[{idx}/{total}] {filename} -> {output_filename} ✓")
            success += 1
        else:
            print(f"[{idx}/{total}] {filename} -> 失败: {msg}")
            failed += 1
    
    print(f"\n=== 预处理完成 ===")
    print(f"成功: {success}张")
    print(f"失败: {failed}张")
    if total > 0:
        print(f"有效率: {success*100//total}%")
PY

# 执行预处理
python3 /tmp/preprocess_faces.py "$INPUT_DIR" "$OUTPUT_DIR" "$CASCADE"

# 清理临时文件
rm -f /tmp/preprocess_faces.py

say "预处理脚本执行完成"
