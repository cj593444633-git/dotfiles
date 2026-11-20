#!/bin/bash
# rotate-hyprland.sh — Hyprland 旋转屏幕 (disable/re-enable 强制 buffer 重分配)
# Usage: rotate-hyprland.sh <output> <transform>
#   transform: 0|90|180|270
#
# Hyprland 0.56+ | 旋转后自动修复 XWayland 浏览器全屏
# Edge/Chrome 走 --ozone-platform=x11, disable/re-enable 时 XWayland
# RandR 断连/重连事件可能使浏览器缓存的屏幕尺寸失效，导致竖屏不能全屏。

OUTPUT="${1:-LVDS-1}"
TRANSFORM="${2:-0}"

case "$TRANSFORM" in
    0|normal) T=0 ;;
    90)  T=1 ;;
    180) T=2 ;;
    270) T=3 ;;
    *)   echo "Invalid transform: $TRANSFORM" >&2; exit 1 ;;
esac

# ── 1. 旋转 ──────────────────────────────────────────────────
hyprctl eval "hl.monitor({output=\"$OUTPUT\", disabled=true})"
sleep 0.2
hyprctl eval "hl.monitor({output=\"$OUTPUT\", disabled=false, transform=$T})"
sleep 0.6  # 等 compositor + XWayland RandR 稳定

# ── 2. 获取旋转后分辨率 ──────────────────────────────────────
read -r MON_W MON_H < <(hyprctl monitors -j 2>/dev/null | python3 -c "
import json, sys
for m in json.load(sys.stdin):
    if m['name'] == '$OUTPUT':
        print(m['width'], m['height'])
        break
" 2>/dev/null)

# ── 3. 修复 XWayland 浏览器全屏 ─────────────────────────────
# toggle 两次 (进入全屏 → 退出全屏), 强制浏览器重新查询 X screen 尺寸
# 无论窗口当前是否全屏, 最终状态与旋转前一致
hyprctl clients -j 2>/dev/null | python3 -c "
import json, sys, subprocess, time

clients = json.load(sys.stdin)
xwayland_browsers = ('microsoft-edge', 'google-chrome', 'chromium')

for c in clients:
    cls = c.get('class', '').lower()
    if not any(b in cls for b in xwayland_browsers):
        continue

    addr = c['address']
    size = c.get('size', [0, 0])
    print(f'[rotate] {cls} {addr}: refresh screen dims ({size[0]}x{size[1]})', file=sys.stderr)
    
    # toggle fullscreen (地址指定, 不影响其他窗口)
    subprocess.run(['hyprctl', 'eval',
        f'hl.dsp.window.fullscreen({{address=\"{addr}\"}})'],
        capture_output=True)
    time.sleep(0.2)
    subprocess.run(['hyprctl', 'eval',
        f'hl.dsp.window.fullscreen({{address=\"{addr}\"}})'],
        capture_output=True)
" 2>/dev/null

echo "✓ $OUTPUT 旋转 $TRANSFORM° ($MON_W×$MON_H)"
