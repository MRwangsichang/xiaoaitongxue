#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/MRwang/smart_assistant"
RAW_DIR="${ROOT}/data/faces/王总/raw"
PROCESSED_DIR="${ROOT}/data/faces/王总/processed"
CASCADE="/usr/share/opencv4/haarcascades/haarcascade_frontalface_default.xml"

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

say "=== 批量采集100张人脸照片 ==="

mkdir -p "$RAW_DIR" "$PROCESSED_DIR"

say "停止占用服务..."
sudo systemctl stop cam.service greet.service 2>/dev/null || true
systemctl --user stop pipewire.service pipewire.socket pipewire-pulse.service wireplumber.service 2>/dev/null || true

TASKS=("正脸" "正脸" "正脸" "左侧45度" "右侧45度" "正脸" "正脸" "微笑" "表情1" "表情2")

say "准备开始，请站在镜头前固定位置"
sleep 3

TOTAL=0
for BATCH in {1..10}; do
    TASK="${TASKS[$((BATCH-1))]}"
    say ""
    say ">>> 第${BATCH}组/共10组 - 任务: ${TASK}"
    
    for i in {1..10}; do
        TOTAL=$((TOTAL + 1))
        IMG_NUM=$(printf "%04d" $TOTAL)
        RAW_FILE="${RAW_DIR}/img_${IMG_NUM}.jpg"
        
        if [ $BATCH -le 5 ]; then
            rpicam-still --immediate --nopreview --mode 1640:1232:10:P --awb auto \
                --shutter 80000 --gain 8 -o "$RAW_FILE" 2>/dev/null
        else
            rpicam-still --immediate --nopreview --mode 1640:1232:10:P --awb auto \
                -o "$RAW_FILE" 2>/dev/null
        fi
        
        python3 - <<PYEOF
import cv2
import sys

raw = "$RAW_FILE"
processed = "${PROCESSED_DIR}/face_${IMG_NUM}.jpg"

img = cv2.imread(raw)
gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
cascade = cv2.CascadeClassifier("$CASCADE")
faces = cascade.detectMultiScale(gray, 1.1, 5, minSize=(80,80))

if len(faces) == 0:
    print("NOFACE")
    sys.exit(1)

# 取最大人脸框
areas = [w*h for (x,y,w,h) in faces]
largest = faces[areas.index(max(areas))]
x, y, w, h = largest

# 裁剪并resize到112x112
face_crop = gray[y:y+h, x:x+w]
face_resized = cv2.resize(face_crop, (112, 112))
cv2.imwrite(processed, face_resized)
print(f"OK:{len(faces)}:{w}x{h}")
PYEOF
        
        RESULT=$(cat)
        if [[ "$RESULT" == OK:* ]]; then
            say "  [${i}/10] ✓ img_${IMG_NUM}.jpg"
        else
            say "  [${i}/10] ✗ 未检测到人脸，跳过"
        fi
        
        sleep 0.8
    done
    
    if [ $BATCH -lt 10 ]; then
        say ">>> 停顿5秒，请调整姿势 - 下一组任务: ${TASKS[$BATCH]}"
        for s in {5..1}; do
            printf "\r    倒计时: %d秒..." $s
            sleep 1
        done
        echo ""
    fi
done

say ""
say "=== 采集完成！==="
say "原始照片: ${RAW_DIR}/ ($(ls ${RAW_DIR} | wc -l)张)"
say "处理照片: ${PROCESSED_DIR}/ ($(ls ${PROCESSED_DIR} | wc -l)张)"
