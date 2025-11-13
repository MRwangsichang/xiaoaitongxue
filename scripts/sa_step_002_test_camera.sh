#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/MRwang/smart_assistant"
CAPTURE_DIR="${ROOT}/captures"
TEST_PHOTO="${CAPTURE_DIR}/test_弱光.jpg"

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

say "=== 摄像头测试 - 拍摄单张照片 ==="

mkdir -p "$CAPTURE_DIR"

say "停止可能占用相机的服务..."
sudo systemctl stop cam.service greet.service 2>/dev/null || true
systemctl --user stop pipewire.service pipewire.socket pipewire-pulse.service wireplumber.service 2>/dev/null || true
say "[✓] 服务已停止"

say "准备拍摄，请站在摄像头前..."
say "3秒后拍摄..."
sleep 3

rpicam-still --immediate --nopreview --mode 1640:1232:10:P \
  --shutter 80000 --gain 8 \
  -o "$TEST_PHOTO" 2>/dev/null

if [ -f "$TEST_PHOTO" ] && [ -s "$TEST_PHOTO" ]; then
    say "[✓] 照片已保存: $TEST_PHOTO"
else
    say "[✗] 拍摄失败"
    exit 1
fi

say ""
say "=== 人脸检测验证 ==="

python3 - <<'PYEOF'
import cv2
import sys

CASCADE_PATH = "/usr/share/opencv4/haarcascades/haarcascade_frontalface_default.xml"
TEST_PHOTO = "/home/MRwang/smart_assistant/captures/test_弱光.jpg"

img = cv2.imread(TEST_PHOTO)
if img is None:
    print("[✗] 无法读取照片")
    sys.exit(1)

face_cascade = cv2.CascadeClassifier(CASCADE_PATH)
gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
faces = face_cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5, minSize=(80, 80))

if len(faces) > 0:
    print(f"[✓] 检测到 {len(faces)} 张人脸")
    for i, (x, y, w, h) in enumerate(faces):
        print(f"人脸{i+1}位置: (x={x}, y={y}, w={w}, h={h})")
    
    variance = cv2.Laplacian(gray, cv2.CV_64F).var()
    print(f"清晰度得分: {variance:.1f} ({'合格' if variance > 100 else '模糊'})")
    
    if variance > 100:
        print("\n✓ 测试通过！请用WinSCP下载照片查看效果")
        sys.exit(0)
    else:
        print("\n[!] 照片过于模糊，建议增加光照或调整快门")
        sys.exit(1)
else:
    print("[✗] 未检测到人脸")
    print("可能原因：")
    print("  1. 距离摄像头太远或太近")
    print("  2. 光线太暗")
    print("  3. 摄像头角度不对")
    sys.exit(1)
PYEOF

RESULT=$?
if [ $RESULT -eq 0 ]; then
    say ""
    say "文件路径: $TEST_PHOTO"
    say "请用WinSCP下载查看，确认角度/光线合适后继续批量采集"
else
    say ""
    say "[!] 测试未通过，请调整后重试"
fi

exit $RESULT
