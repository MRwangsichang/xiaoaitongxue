#!/usr/bin/env bash
set -euo pipefail
DRY_RUN="${DRY_RUN:-1}"

say(){ printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
OUTPUT_DIR="$ROOT/data/faces/wangzong_glasses/raw"

if [ "$DRY_RUN" = "1" ]; then
  say "DRY-RUN: 仅打印将执行的操作"
  say "[DRY] 将拍摄25张正常光照（戴眼镜，间隔2秒）"
  say "[✓] 预演完成"
  exit 0
fi

say "=== 采集正常光照（戴眼镜）==="
say "5秒后开始拍摄..."
sleep 5

# 停止相机服务
say "停止相机服务..."
sudo systemctl stop cam.service greet.service 2>/dev/null || true
systemctl --user stop pipewire.service pipewire.socket pipewire-pulse.service wireplumber.service 2>/dev/null || true
sleep 1

say "开始拍摄25张（正常光照，间隔2秒）..."

for i in $(seq 126 150); do
  OUTPUT="$OUTPUT_DIR/img_$(printf '%04d' $i).jpg"
  
  # 正常光照（无特殊参数）
  rpicam-still --immediate --nopreview \
    --mode 1640:1232:10:P \
    --awb auto \
    -o "$OUTPUT" 2>/dev/null
  
  if [ -f "$OUTPUT" ]; then
    COUNT=$((i - 125))
    say "[✓] $COUNT/25: img_$(printf '%04d' $i).jpg"
  else
    say "[✗] $COUNT/25: 拍照失败"
  fi
  
  if [ "$i" != "150" ]; then
    sleep 2
  fi
done

say "[✓] 正常光照采集完成（25张）"
say "文件保存在: $OUTPUT_DIR/"
