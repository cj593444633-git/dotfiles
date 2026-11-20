#!/usr/bin/env bash
# sync-from-live.sh —— 把本机现役配置导进 ./home（路径 $HOME 化）
#
# 用途：这台 X220 是"参考机"。改完现役配置后跑一次，让 dotfiles 跟上。
# 会覆盖 ./home 下的同名文件 —— 先 git status 看清楚，导完用 git diff 审阅。
#
# 不导出：浏览器 profile、缓存、密钥、mihomo/nginx/aria2/kodi/Android SDK 这些
# 与桌面无关或含敏感信息的部分（清单见 docs/新机安装手册.md「不在本仓库里的」）。
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$REPO/home"
SRC="$HOME"

FILES=(
  .bashrc
  .bash_profile
  .profile
  .config/hypr/hyprland.lua
  .config/hypr/hypridle.conf
  .config/waybar/config.jsonc
  .config/waybar/style.css
  .config/kitty/kitty.conf
  .config/mako/config
  .config/fcitx5/config
  .config/fcitx5/profile
  .config/environment.d/im.conf
  .config/environment.d/90-libva.conf
  .config/autostart/nm-tray-autostart.desktop
  .config/systemd/user/udisks-automount.service
  .config/systemd/user/graphical-session.target.d/10-allow-manual-start.conf
  .config/systemd/user/xdg-desktop-autostart.target.d/10-allow-manual-start.conf
  .config/yazi/yazi-window.bash
  .local/bin/session-targets-up.sh
  .local/bin/wifi-menu.sh
  .local/bin/waybar-power.sh
  .local/bin/waybar-keybinds.sh
  .local/bin/waybar-ws-switch.sh
  .local/bin/rotate-hyprland.sh
  .local/bin/chrome-optimized.sh
  .local/bin/root-window.sh
  .local/bin/udisks-automount.py
)

missing=0
for f in "${FILES[@]}"; do
  src="$SRC/$f"
  if [ ! -f "$src" ]; then
    printf '  跳过（本机没有）: %s\n' "$f" >&2
    missing=$((missing + 1))
    continue
  fi
  dst="$DEST/$f"
  mkdir -p "$(dirname "$dst")"
  # /home/chen → $HOME（已实证：Hyprland 的 exec_cmd、waybar 的 on-click 都过 sh -c）
  sed -e "s|/home/chen|\$HOME|g" "$src" > "$dst"
  printf '  ✓ %s\n' "$f"
done

printf '\n导出完成: %s 个文件（跳过 %d）\n' "$(( ${#FILES[@]} - missing ))" "$missing"
cat <<'EOF'

下一步：
  1) git -C <repo> status && git -C <repo> diff     # 审阅差异
  2) 检查本机特有的段落是否被"通用化"过头：
     · hyprland.lua 的 gocryptfs 挂载、epic-mouse-v1 设备项、HDMI-A-1/LVDS-1 屏幕规则
     · chrome-optimized.sh 的 mihomo 等待/EXT_PATH
EOF
