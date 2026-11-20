#!/usr/bin/env bash
#
# waybar-power.sh — 电源菜单（左键点出选择）
#   选项: 关机 / 重启
#   无右键功能，无 tooltip
#

choice=$(printf "⏻ 关机\n↻ 重启" | wofi --dmenu --prompt "电源操作" \
  --width 320 --height 180 --cache-file /dev/null 2>/dev/null)

case "$choice" in
  *关机*) systemctl poweroff ;;
  *重启*) systemctl reboot ;;
esac
