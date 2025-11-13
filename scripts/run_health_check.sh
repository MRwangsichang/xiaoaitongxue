#!/usr/bin/env bash
set -euo pipefail

say(){ printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
cd "$ROOT"

FAIL_COUNT=0

say "=== 智能助手系统健康检查 ==="

# 1. 检查模型文件
if [ -f "data/faces/model.yml" ]; then
  SIZE=$(du -h data/faces/model.yml | cut -f1)
  say "[✓] 模型文件存在: model.yml ($SIZE)"
else
  say "[✗] 模型文件缺失: data/faces/model.yml"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# 2. 检查日志系统
if python3 -c "from core.logger import get_logger; logger = get_logger('health_check'); logger.info('健康检查')" 2>/dev/null; then
  say "[✓] 日志系统正常"
else
  say "[✗] 日志系统异常"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# 3. 检查识别模块
if python3 -c "from modules.vision.recognizer.face_recognizer import FaceRecognizer" 2>/dev/null; then
  say "[✓] 识别模块可导入"
else
  say "[✗] 识别模块导入失败"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# 4. 检查相机（拍一张测试照片）
TEST_PHOTO="/tmp/health_check_camera_test.jpg"
rm -f "$TEST_PHOTO"

# 停止占用服务
sudo systemctl stop cam.service greet.service 2>/dev/null || true
systemctl --user stop pipewire.service pipewire.socket pipewire-pulse.service wireplumber.service 2>/dev/null || true
sleep 0.5

if rpicam-still --immediate --nopreview --mode 1640:1232:10:P --awb auto -o "$TEST_PHOTO" 2>/dev/null; then
  if [ -f "$TEST_PHOTO" ]; then
    say "[✓] 相机可用（测试拍照成功）"
    rm -f "$TEST_PHOTO"
  else
    say "[✗] 相机拍照失败（文件未生成）"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
else
  say "[✗] 相机不可用"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# 5. 检查关键目录
DIRS=("core" "modules/vision/recognizer" "data/faces" "logs" "scripts")
ALL_DIRS_OK=true

for dir in "${DIRS[@]}"; do
  if [ ! -d "$dir" ]; then
    say "[✗] 目录缺失: $dir"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    ALL_DIRS_OK=false
  fi
done

if [ "$ALL_DIRS_OK" = true ]; then
  say "[✓] 关键目录完整"
fi

# 6. 检查Haar检测器
CASCADE="/usr/share/opencv4/haarcascades/haarcascade_frontalface_default.xml"
if [ -f "$CASCADE" ]; then
  say "[✓] Haar检测器存在"
else
  say "[✗] Haar检测器缺失: $CASCADE"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# 总结
say ""
if [ "$FAIL_COUNT" -eq 0 ]; then
  say "=== HEALTH PASS ==="
  say "所有组件正常"
  exit 0
else
  say "=== HEALTH FAIL ==="
  say "发现${FAIL_COUNT}个问题"
  exit 1
fi
