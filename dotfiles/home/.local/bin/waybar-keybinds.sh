#!/usr/bin/env bash
#
# waybar-keybinds.sh — 显示 Hyprland 快捷键中文速查(wofi)
#
KEYBINDS="\
 SUPER + Q            打开终端 (kitty)
 SUPER + C            关闭当前窗口
 SUPER + E            yazi 文件管理器 (kitty 内)
 SUPER + R            启动器 (hyprlauncher)
 SUPER + F            Firefox 浏览器
 SUPER + G            Google Chrome 浏览器
 SUPER + ESC          关屏 (亮度归零) / SHIFT+ESC 恢复
 SUPER + F11          切换全屏
 SUPER + V            切换窗口浮动
 SUPER + P            伪平铺 (pseudo)
 SUPER + J            切换分割方向
 SUPER + M            退出 Hyprland
─────────────────────────────
 SUPER + ← ↑ ↓ →       切换焦点窗口(方向)
 SUPER + 0~9           工作区 1~10
 SUPER + SHIFT + 0~9   移动窗口到工作区
 SUPER + 滚轮            上/下一个工作区
─────────────────────────────
 SUPER + S            特殊工作区 (magic)
 SUPER + SHIFT + S    移动窗口到特殊工作区
 SUPER + 左键拖动       移动窗口
 SUPER + 右键拖动       缩放窗口
─────────────────────────────
 SUPER + Escape       关屏 (黑屏)
 SUPER + SHIFT + Esc  恢复屏幕亮度
 SUPER + L           锁屏 (hyprlock)
 SUPER + SHIFT + E    文件管理器 (thunar)
 SUPER + SHIFT + S    窗口移到特殊工作区
─────────────────────────────
 CTRL + ALT + 0       旋转 内屏(LVDS) 0° (正常)
 CTRL + ALT + 1       旋转 内屏(LVDS) 90°
 CTRL + ALT + 2       旋转 内屏(LVDS) 180°
 CTRL + ALT + 3       旋转 内屏(LVDS) 270°
─────────────────────────────
 CTRL + ALT + SHIFT + 0  旋转 外接(DP-1) 0° (正常)
 CTRL + ALT + SHIFT + 1  旋转 外接(DP-1) 90°
 CTRL + ALT + SHIFT + 2  旋转 外接(DP-1) 180°
 CTRL + ALT + SHIFT + 3  旋转 外接(DP-1) 270°
─────────────────────────────
 CTRL + SUPER + 0     旋转 外接(VGA-1) 0° (正常)
 CTRL + SUPER + 1     旋转 外接(VGA-1) 90°
 CTRL + SUPER + 2     旋转 外接(VGA-1) 180°
 CTRL + SUPER + 3     旋转 外接(VGA-1) 270°
─────────────────────────────
 SUPER + H      Hermes AI 桌面
 SUPER + Shift + H      DeepSeek Harness AI 桌面
─────────────────────────────
 音量 +/-             音量调节
 亮度 +/-             屏幕亮度
 播放/暂停/上下曲      多媒体控制"

# 只读展示; 选中某行不执行动作(纯查阅)
echo "$KEYBINDS" | wofi --dmenu --prompt "⌨ 快捷键速查" --width 560 --height 680 --cache-file /dev/null --timeout 3 >/dev/null 2>&1
