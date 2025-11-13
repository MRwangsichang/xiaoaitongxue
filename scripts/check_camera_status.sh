#!/usr/bin/env bash
say(){ printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

say "=== 相机占用检查 ==="

say "检查系统服务..."
systemctl is-active cam.service 2>/dev/null || echo "cam.service: not found or inactive"
systemctl is-active greet.service 2>/dev/null || echo "greet.service: not found or inactive"

say "检查用户服务..."
systemctl --user is-active pipewire.service 2>/dev/null || echo "pipewire: inactive"
systemctl --user is-active wireplumber.service 2>/dev/null || echo "wireplumber: inactive"

say "检查相机相关进程..."
if pgrep -f "rpicam|libcamera" >/dev/null; then
  say "发现相机进程："
  pgrep -af "rpicam|libcamera"
else
  say "无相机相关进程"
fi

say "=== 检查完成 ==="
