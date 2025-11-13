#!/usr/bin/env bash
set -euo pipefail

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }
die() { say "❌ $*"; exit 1; }

ROOT="/home/MRwang/smart_assistant"

say "=== 安装V2Ray客户端 ==="

# 1. 检查是否已安装
if command -v v2ray &>/dev/null; then
    say "V2Ray已安装，跳过安装步骤"
else
    say "开始安装V2Ray（需要sudo权限）..."
    
    # 下载安装脚本到临时文件
    INSTALL_SCRIPT="/tmp/v2ray_install_$(date +%s).sh"
    say "下载安装脚本..."
    curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh -o "${INSTALL_SCRIPT}" || die "下载安装脚本失败"
    
    # 执行安装脚本
    say "执行安装脚本（需要输入sudo密码）..."
    sudo bash "${INSTALL_SCRIPT}" || die "V2Ray安装失败"
    
    # 清理临时文件
    rm -f "${INSTALL_SCRIPT}"
    
    say "✓ V2Ray安装完成"
fi

# 2. 验证安装
v2ray version || die "V2Ray安装验证失败"

# 3. 备份旧配置（如果存在）
if [ -f /usr/local/etc/v2ray/config.json ]; then
    say "备份旧配置..."
    sudo cp /usr/local/etc/v2ray/config.json "/usr/local/etc/v2ray/config.json.backup.$(date +%s)"
fi

# 4. 创建配置文件
say "创建V2Ray配置文件..."
sudo tee /usr/local/etc/v2ray/config.json > /dev/null <<'V2RAY_CONFIG'
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/v2ray/access.log",
    "error": "/var/log/v2ray/error.log"
  },
  "inbounds": [
    {
      "port": 1080,
      "listen": "127.0.0.1",
      "protocol": "socks",
      "settings": {
        "auth": "noauth",
        "udp": true
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "vmess",
      "settings": {
        "vnext": [
          {
            "address": "172.86.126.55",
            "port": 31535,
            "users": [
              {
                "id": "c3d35ce3-c754-4b4a-a1f1-4e4df8f0c506",
                "alterId": 0,
                "security": "auto"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "kcp",
        "kcpSettings": {
          "mtu": 1350,
          "tti": 50,
          "uplinkCapacity": 12,
          "downlinkCapacity": 100,
          "congestion": false,
          "readBufferSize": 2,
          "writeBufferSize": 2,
          "header": {
            "type": "dtls"
          }
        }
      }
    }
  ]
}
V2RAY_CONFIG

say "✓ 配置文件创建完成"

# 5. 确保日志目录存在且权限正确
say "创建日志目录..."
sudo mkdir -p /var/log/v2ray
sudo chown nobody:nogroup /var/log/v2ray

# 6. 启用并启动服务
say "启动V2Ray服务..."
sudo systemctl enable v2ray
sudo systemctl restart v2ray

# 7. 等待服务启动
sleep 3

# 8. 验证服务状态
if sudo systemctl is-active --quiet v2ray; then
    say "✓ V2Ray服务运行正常"
else
    say "❌ V2Ray服务启动失败，查看日志："
    sudo journalctl -u v2ray -n 30 --no-pager
    die "V2Ray服务启动失败"
fi

# 9. 验证SOCKS5端口
say "验证SOCKS5端口..."
sleep 2
if ss -tuln | grep -q "127.0.0.1:1080"; then
    say "✓ SOCKS5端口监听正常"
else
    say "❌ SOCKS5端口未监听，查看V2Ray日志："
    sudo journalctl -u v2ray -n 30 --no-pager
    die "SOCKS5端口未监听"
fi

# 10. 测试代理连通性
say "测试代理连通性（最多等待15秒）..."
if timeout 15 curl -x socks5h://127.0.0.1:1080 -s https://www.google.com > /dev/null 2>&1; then
    say "✓ 代理连通性测试通过"
else
    say "⚠️  代理连通性测试失败（但V2Ray已启动，可能是网络问题）"
fi

say ""
say "✅ V2Ray客户端安装和配置完成！"
say ""
say "查看服务状态："
echo "  sudo systemctl status v2ray"
say ""
say "查看日志："
echo "  sudo journalctl -u v2ray -f"
say ""
say "下一步："
echo "  bash ${ROOT}/scripts/install_python_proxy_support.sh"
