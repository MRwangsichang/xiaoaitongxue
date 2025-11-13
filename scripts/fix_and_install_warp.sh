#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

say "=== 清理并重新安装 Cloudflare WARP ==="

# 1. 清理旧配置
say "清理旧配置..."
sudo rm -f /etc/apt/sources.list.d/cloudflare-client.list
sudo rm -f /usr/share/keyrings/cloudflare-warp*.gpg

# 2. 添加仓库（使用正确路径）
say "添加Cloudflare仓库..."
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp.gpg

echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp.gpg] https://pkg.cloudflareclient.com/ bookworm main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list

# 3. 更新软件源
say "更新软件源..."
sudo apt update

# 4. 安装WARP
say "安装cloudflare-warp..."
sudo apt install -y cloudflare-warp

# 5. 注册（匿名，无需账号）
say "注册WARP（匿名，无需输入任何信息）..."
warp-cli register

# 6. 连接
say "连接WARP..."
warp-cli connect

# 7. 等待连接
sleep 5

# 8. 验证状态
say "验证连接状态..."
warp-cli status

say ""
say "✅ WARP安装完成！"
say ""
say "测试Grok连接："
echo "  curl -v https://api.x.ai/v1 2>&1 | head -10"
