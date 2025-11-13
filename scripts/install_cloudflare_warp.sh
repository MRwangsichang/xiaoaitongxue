#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

say "=== 安装 Cloudflare WARP VPN ==="

# 1. 添加Cloudflare仓库
say "添加Cloudflare仓库..."
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list

# 2. 更新并安装
say "更新软件源..."
sudo apt update

say "安装cloudflare-warp..."
sudo apt install -y cloudflare-warp

# 3. 注册并连接
say "注册WARP账号..."
warp-cli register

say "连接WARP..."
warp-cli connect

# 4. 等待连接成功
sleep 3

# 5. 验证连接
say "验证连接状态..."
warp-cli status

say ""
say "✅ Cloudflare WARP 安装完成！"
say ""
say "测试连接："
echo "  curl https://api.x.ai/v1"
