#!/usr/bin/env bash
set -euo pipefail
DRY_RUN="${DRY_RUN:-1}"

say(){ printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
DEBUG_DIR="$ROOT/data/faces/debug"

if [ "$DRY_RUN" = "1" ]; then
  say "DRY-RUN: 仅打印将执行的操作，不改系统"
  say "[DRY] 将创建目录: $DEBUG_DIR"
  say "[DRY] 将拍摄10张诊断照片（间隔1.5秒）"
  say "[✓] 所有操作预演完成"
  exit 0
fi

say "=== 诊断照片采集（慢速模式）==="

# 创建调试目录
mkdir -p "$DEBUG_DIR"

# 停止相机服务
say "停止相机服务..."
sudo systemctl stop cam.service greet.service 2>/dev/null || true
systemctl --user stop pipewire.service pipewire.socket pipewire-pulse.service wireplumber.service 2>/dev/null || true
sleep 1

say "开始拍摄10张诊断照片（间隔1.5秒）..."

for i in $(seq -w 1 10); do
  OUTPUT="$DEBUG_DIR/diag_frame_${i}.jpg"
  
  # 拍照前额外等待
  sleep 0.3
  
  rpicam-still --immediate --nopreview --mode 1640:1232:10:P --awb auto -o "$OUTPUT" 2>/dev/null
  
  if [ -f "$OUTPUT" ]; then
    say "[✓] 帧$i: $OUTPUT"
  else
    say "[✗] 帧$i: 拍照失败"
  fi
  
  # 拍照后等待相机恢复
  if [ "$i" != "10" ]; then
    sleep 1.5
  fi
done

say "=== 采集完成 ==="
say "照片已保存到: $DEBUG_DIR/"
