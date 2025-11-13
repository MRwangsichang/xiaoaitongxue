#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/MRwang/smart_assistant"
FACES_DIR="${ROOT}/data/faces"
MODEL_FILE="${FACES_DIR}/model.yml"
REPORT_FILE="${FACES_DIR}/test_report.txt"

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

say "=== LBPH模型训练 ==="

python3 - <<'PYEOF'
import cv2
import numpy as np
from pathlib import Path
from datetime import datetime
import random

ROOT = Path("/home/MRwang/smart_assistant")
FACES_DIR = ROOT / "data" / "faces"

def log(msg):
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}")

# 加载训练数据
log("加载训练数据: wangzong")
processed_dir = FACES_DIR / "wangzong" / "processed"
face_files = sorted(list(processed_dir.glob("face_*.jpg")))

if len(face_files) < 10:
    log(f"[✗] 训练数据不足: 仅{len(face_files)}张，需要至少10张")
    exit(1)

log(f"找到{len(face_files)}张人脸照片")

# 读取所有人脸图像
faces = []
labels = []
for img_path in face_files:
    img = cv2.imread(str(img_path), cv2.IMREAD_GRAYSCALE)
    if img is not None:
        faces.append(img)
        labels.append(0)  # 王总的label是0

# 划分训练集和测试集 (80% / 20%)
indices = list(range(len(faces)))
random.seed(42)
random.shuffle(indices)

split_idx = int(len(faces) * 0.8)
train_indices = indices[:split_idx]
test_indices = indices[split_idx:]

train_faces = [faces[i] for i in train_indices]
train_labels = [labels[i] for i in train_indices]
test_faces = [faces[i] for i in test_indices]
test_labels = [labels[i] for i in test_indices]

log(f"训练集: {len(train_faces)}张 | 测试集: {len(test_faces)}张")

# 训练LBPH模型
log("开始训练LBPH模型...")
recognizer = cv2.face.LBPHFaceRecognizer_create(
    radius=1,
    neighbors=8,
    grid_x=8,
    grid_y=8
)

recognizer.train(train_faces, np.array(train_labels))
log("[✓] 模型训练完成")

# 保存模型
model_path = FACES_DIR / "model.yml"
recognizer.save(str(model_path))
log(f"[✓] 模型已保存: {model_path.relative_to(ROOT)}")

# 测试模型
log("")
log("=== 模型测试 ===")
correct = 0
total = len(test_faces)
confidences = []

for i, (face, true_label) in enumerate(zip(test_faces, test_labels)):
    pred_label, confidence = recognizer.predict(face)
    confidences.append(confidence)
    if pred_label == true_label:
        correct += 1

accuracy = (correct / total) * 100
avg_confidence = np.mean(confidences)

log("测试集识别结果:")
log(f"  准确率: {accuracy:.1f}% ({correct}/{total})")
log(f"  平均置信度: {avg_confidence:.1f}")

# 生成报告
report_path = FACES_DIR / "test_report.txt"
with open(report_path, "w", encoding="utf-8") as f:
    f.write("=" * 50 + "\n")
    f.write("LBPH人脸识别模型测试报告\n")
    f.write("=" * 50 + "\n")
    f.write(f"训练时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    f.write(f"训练人员: 王总 (wangzong)\n")
    f.write(f"训练样本: {len(train_faces)}张\n")
    f.write(f"测试样本: {len(test_faces)}张\n")
    f.write(f"\n")
    f.write(f"测试结果:\n")
    f.write(f"  准确率: {accuracy:.1f}% ({correct}/{total})\n")
    f.write(f"  平均置信度: {avg_confidence:.1f}\n")
    f.write(f"  置信度范围: {min(confidences):.1f} ~ {max(confidences):.1f}\n")
    f.write(f"\n")
    f.write(f"模型参数:\n")
    f.write(f"  算法: LBPH (Local Binary Patterns Histograms)\n")
    f.write(f"  Radius: 1\n")
    f.write(f"  Neighbors: 8\n")
    f.write(f"  Grid: 8x8\n")
    f.write(f"\n")
    if accuracy >= 85:
        f.write("✓ 测试通过 - 模型质量良好\n")
    else:
        f.write("✗ 测试未通过 - 建议增加训练样本或调整参数\n")

log(f"[✓] 测试报告: {report_path.relative_to(ROOT)}")

if accuracy >= 85:
    log("")
    log("✓ 模型训练成功！可以进入下一步：封装识别模块")
    exit(0)
else:
    log("")
    log(f"[!] 准确率偏低({accuracy:.1f}%)，建议重新采集更多样本")
    exit(1)
PYEOF

