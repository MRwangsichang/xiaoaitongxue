#!/usr/bin/env bash
set -e
SVC=("greet.service" "cam.service" "camfix.service" "smart_speaker.service")
for s in "${SVC[@]}"; do
  FRAG=$(systemctl show -p FragmentPath --value "$s" 2>/dev/null || true)
  # 取消掩码
  sudo systemctl unmask "$s" 2>/dev/null || true
  # 若有备份则恢复
  BAK=$(ls -1 /etc/systemd/system.disabled/${s}.bak.* 2>/dev/null | tail -n1 || true)
  if [ -n "$BAK" ]; then
    sudo mv "$BAK" "/etc/systemd/system/$s"
  else
    echo "[warn] 无备份：$s（保持未启用状态）"
  fi
done
sudo systemctl daemon-reload
echo "Rollback done.（未自动enable/启动，请手动决定）"
