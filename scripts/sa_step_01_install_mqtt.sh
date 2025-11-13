#!/usr/bin/env bash
set -euo pipefail
DRY_RUN="${DRY_RUN:-1}"

say(){ printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }
ok(){ printf "✓ %s\n" "$*"; }
fail(){ printf "✗ %s\n" "$*"; exit 1; }

echo "=== MQTT BROKER INSTALLATION ==="

# 检查是否已安装
if command -v mosquitto &>/dev/null; then
  say "mosquitto already installed, checking status..."
  ALREADY_INSTALLED=1
else
  ALREADY_INSTALLED=0
fi

if [ "$DRY_RUN" = "1" ]; then
  say "DRY-RUN: Would install mosquitto mosquitto-clients"
  say "DRY-RUN: Would enable/start mosquitto.service"
  exit 0
fi

# 实际安装
if [ "$ALREADY_INSTALLED" = "0" ]; then
  say "Installing mosquitto..."
  sudo apt update -qq
  sudo apt install -y mosquitto mosquitto-clients
  ok "mosquitto installed successfully"
else
  ok "mosquitto already installed, skipping package installation"
fi

# 启动并设置开机自启
say "Starting mosquitto service..."
sudo systemctl enable mosquitto
sudo systemctl start mosquitto

# 验证服务状态
sleep 2
if sudo systemctl is-active --quiet mosquitto; then
  ok "mosquitto.service is active and running"
else
  fail "mosquitto.service failed to start"
fi

# 验证端口监听
if ss -tuln | grep -q ':1883 '; then
  ok "Port 1883 is listening"
else
  fail "Port 1883 NOT listening"
fi

# 简单连接测试
if mosquitto_sub -h localhost -t 'test' -C 1 -W 1 &>/dev/null & 
   sleep 0.5
   mosquitto_pub -h localhost -t 'test' -m 'ping' &>/dev/null
then
  ok "MQTT pub/sub test passed"
else
  say "⚠ MQTT pub/sub test failed (service running but connection issue)"
fi

echo ""
echo "=== MQTT BROKER READY ==="
