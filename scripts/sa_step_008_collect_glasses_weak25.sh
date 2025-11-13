#!/usr/bin/env bash
set -euo pipefail
DRY_RUN="${DRY_RUN:-1}"

say(){ printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
OUTPUT_DIR="$ROOT/data/faces/wangzong_glasses/raw"

if [ "$DRY_RUN" = "1" ]; then
  say "DRY-RUN: 仅打印将执行的操作"
  say "[DRY] 将创建目录: $OUTPUT_DIR"
  say "[DRY] 将拍摄25张弱光照片（戴眼镜，间隔2秒）"
  say "[✓] 预演完成"
  exit 0
fi

say "=== 采集弱光照片（戴眼镜）==="
say "⚠️  请确认："
say "  1. 戴着眼镜"
say "  2. 站在镜头前（距离1-2米）"
say "  3. 保持在当前家居环境"
say ""
say "5秒后开始拍摄..."
sleep 5

mkdir -p "$OUTPUT_DIR"

# 停止相机服务
say "停止相机服务..."
sudo systemctl stop cam.service greet.service 2>/dev/null || true
systemctl --user stop pipewire.service pipewire.socket pipewire-pulse.service wireplumber.service 2>/dev/null || true
sleep 1

say "开始拍摄25张（弱光模式，间隔2秒）..."

for i in $(seq 101 125); do
  OUTPUT="$OUTPUT_DIR/img_$(printf '%04d' $i).jpg"
  
  # 弱光模式参数
  rpicam-still --immediate --nopreview \
    --mode 1640:1232:10:P \
    --awb auto \
    --shutter 80000 \
    --gain 8 \
    -o "$OUTPUT" 2>/dev/null
  
  if [ -f "$OUTPUT" ]; then
    COUNT=$((i - 100))
    say "[✓] $COUNT/25: img_$(printf '%04d' $i).jpg"
  else
    say "[✗] $COUNT/25: 拍照失败"
  fi
  
  # 最后一张不等待
  if [ "$i" != "125" ]; then
    sleep 2
  fi
done

say "[✓] 弱光采集完成（25张）"
say "文件保存在: $OUTPUT_DIR/"
