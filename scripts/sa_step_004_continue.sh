#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/MRwang/smart_assistant"
RAW_DIR="${ROOT}/data/faces/王总/raw"
PROCESSED_DIR="${ROOT}/data/faces/王总/processed"
CASCADE="/usr/share/opencv4/haarcascades/haarcascade_frontalface_default.xml"

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

say "=== 继续采集剩余26张 ==="

TASKS=("微笑" "表情1" "表情2")

say "从第75张继续，请站在镜头前"
sleep 3

BATCH_MAP=(8 8 8 8 8 8 9 9 9 9 9 9 9 9 9 9 10 10 10 10 10 10 10 10 10 10)
TASK_MAP=(0 0 0 0 0 0 1 1 1 1 1 1 1 1 1 1 2 2 2 2 2 2 2 2 2 2)

for idx in {0..25}; do
    TOTAL=$((75 + idx))
    BATCH=$((BATCH_MAP[idx]))
    TASK_IDX=$((TASK_MAP[idx]))
    TASK="${TASKS[$TASK_IDX]}"
    
    IMG_NUM=$(printf "%04d" $TOTAL)
    RAW_FILE="${RAW_DIR}/img_${IMG_NUM}.jpg"
    
    if [ $((idx % 10)) -eq 0 ]; then
        say ""
        say ">>> 第${BATCH}组 - 任务: ${TASK}"
    fi
    
    rpicam-still --immediate --nopreview --mode 1640:1232:10:P --awb auto \
        -o "$RAW_FILE" 2>/dev/null
    
    python3 - <<PYEOF 2>/dev/null || echo "SKIP"
import cv2
import sys

raw = "$RAW_FILE"
processed = "${PROCESSED_DIR}/face_${IMG_NUM}.jpg"

img = cv2.imread(raw)
if img is None:
    sys.exit(0)

gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
cascade = cv2.CascadeClassifier("$CASCADE")
faces = cascade.detectMultiScale(gray, 1.1, 5, minSize=(80,80))

if len(faces) == 0:
    sys.exit(0)

areas = [w*h for (x,y,w,h) in faces]
largest = faces[areas.index(max(areas))]
x, y, w, h = largest

face_crop = gray[y:y+h, x:x+w]
face_resized = cv2.resize(face_crop, (112, 112))
cv2.imwrite(processed, face_resized)
print("OK")
PYEOF
    
    say "  ✓ img_${IMG_NUM}.jpg"
    
    sleep 0.8
    
    if [ $((idx + 1)) -eq 6 ] || [ $((idx + 1)) -eq 16 ]; then
        say ">>> 停顿5秒，请调整姿势"
        sleep 5
    fi
done

say ""
say "=== 全部100张采集完成！==="
say "原始照片: $(ls ${RAW_DIR} | wc -l)张"
say "处理照片: $(ls ${PROCESSED_DIR} | wc -l)张"
