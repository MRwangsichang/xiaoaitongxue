#!/usr/bin/env bash
set -euo pipefail
DRY_RUN="${DRY_RUN:-1}"

say(){ printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
DATA_DIR1="$ROOT/data/faces/wangzong/processed"
DATA_DIR2="$ROOT/data/faces/wangzong_glasses/processed"
MODEL_OUTPUT="$ROOT/data/faces/model_v2.yml"
REPORT_OUTPUT="$ROOT/data/faces/test_report_v2.txt"
CASCADE="/usr/share/opencv4/haarcascades/haarcascade_frontalface_default.xml"

if [ "$DRY_RUN" = "1" ]; then
  say "DRY-RUN: 仅打印将执行的操作"
  say "[DRY] 将合并两批数据："
  say "[DRY]   - wangzong/processed/ (95张)"
  say "[DRY]   - wangzong_glasses/processed/ (47张)"
  say "[DRY] 将训练LBPH模型 -> model_v2.yml"
  say "[✓] 预演完成"
  exit 0
fi

say "=== 重新训练LBPH模型（142张） ==="

# 创建训练脚本
cat > /tmp/train_model_v2.py <<'PY'
#!/usr/bin/env python3
import cv2
import os
import sys
import random
from datetime import datetime

def load_faces_from_dir(directory, label):
    """从目录加载所有face_*.jpg"""
    faces = []
    files = sorted([f for f in os.listdir(directory) if f.startswith('face_') and f.endswith('.jpg')])
    
    for filename in files:
        path = os.path.join(directory, filename)
        img = cv2.imread(path, cv2.IMREAD_GRAYSCALE)
        if img is not None:
            faces.append((img, label))
    
    return faces

def train_and_test(data_dir1, data_dir2, model_output, report_output):
    """训练并测试模型"""
    print(f"[{datetime.now().strftime('%H:%M:%S')}] 加载数据...")
    
    # 加载两批数据（都是label=0，王总）
    batch1 = load_faces_from_dir(data_dir1, label=0)
    batch2 = load_faces_from_dir(data_dir2, label=0)
    
    print(f"[{datetime.now().strftime('%H:%M:%S')}] 原数据: {len(batch1)}张（wangzong/processed/）")
    print(f"[{datetime.now().strftime('%H:%M:%S')}] 新数据: {len(batch2)}张（wangzong_glasses/processed/）")
    
    # 合并
    all_data = batch1 + batch2
    random.shuffle(all_data)
    
    total = len(all_data)
    print(f"[{datetime.now().strftime('%H:%M:%S')}] 总计: {total}张")
    
    # 80%训练，20%测试
    split_idx = int(total * 0.8)
    train_data = all_data[:split_idx]
    test_data = all_data[split_idx:]
    
    print(f"[{datetime.now().strftime('%H:%M:%S')}] 训练集: {len(train_data)}张")
    print(f"[{datetime.now().strftime('%H:%M:%S')}] 测试集: {len(test_data)}张")
    
    # 准备训练数据
    train_faces = [img for img, label in train_data]
    train_labels = [label for img, label in train_data]
    
    # 训练LBPH模型
    print(f"[{datetime.now().strftime('%H:%M:%S')}] 开始训练LBPH模型...")
    recognizer = cv2.face.LBPHFaceRecognizer_create(radius=1, neighbors=8, grid_x=8, grid_y=8)
    recognizer.train(train_faces, np.array(train_labels))
    
    print(f"[{datetime.now().strftime('%H:%M:%S')}] 训练完成")
    
    # 测试模型
    correct = 0
    confidences = []
    
    for img, true_label in test_data:
        pred_label, confidence = recognizer.predict(img)
        confidences.append(confidence)
        if pred_label == true_label:
            correct += 1
    
    accuracy = correct / len(test_data) * 100 if test_data else 0
    avg_confidence = sum(confidences) / len(confidences) if confidences else 0
    min_confidence = min(confidences) if confidences else 0
    max_confidence = max(confidences) if confidences else 0
    
    print(f"[{datetime.now().strftime('%H:%M:%S')}] 测试准确率: {accuracy:.1f}% ({correct}/{len(test_data)})")
    print(f"[{datetime.now().strftime('%H:%M:%S')}] 平均置信度: {avg_confidence:.1f}")
    
    # 保存模型
    recognizer.write(model_output)
    print(f"[{datetime.now().strftime('%H:%M:%S')}] 模型已保存: {model_output}")
    
    # 生成报告
    with open(report_output, 'w', encoding='utf-8') as f:
        f.write("=== LBPH模型训练报告 v2 ===\n")
        f.write(f"训练时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
        f.write(f"数据来源:\n")
        f.write(f"  - wangzong/processed/: {len(batch1)}张\n")
        f.write(f"  - wangzong_glasses/processed/: {len(batch2)}张\n")
        f.write(f"  - 总计: {total}张\n\n")
        f.write(f"训练样本: {len(train_data)}张\n")
        f.write(f"测试样本: {len(test_data)}张\n\n")
        f.write(f"测试结果:\n")
        f.write(f"  - 准确率: {accuracy:.1f}% ({correct}/{len(test_data)})\n")
        f.write(f"  - 平均置信度: {avg_confidence:.1f}\n")
        f.write(f"  - 置信度范围: {min_confidence:.1f} ~ {max_confidence:.1f}\n\n")
        f.write(f"模型参数:\n")
        f.write(f"  - 算法: LBPH\n")
        f.write(f"  - Radius: 1, Neighbors: 8, Grid: 8×8\n")
    
    print(f"[{datetime.now().strftime('%H:%M:%S')}] 报告已保存: {report_output}")

if __name__ == "__main__":
    import numpy as np
    
    data_dir1 = sys.argv[1]
    data_dir2 = sys.argv[2]
    model_output = sys.argv[3]
    report_output = sys.argv[4]
    
    train_and_test(data_dir1, data_dir2, model_output, report_output)
PY

# 执行训练
python3 /tmp/train_model_v2.py "$DATA_DIR1" "$DATA_DIR2" "$MODEL_OUTPUT" "$REPORT_OUTPUT"

# 清理临时文件
rm -f /tmp/train_model_v2.py

say "=== 重训练完成 ==="
