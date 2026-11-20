# 快捷键速查（来源：`~/.config/hypr/hyprland.lua`，Hyprland 0.56.2 实测）

主修饰键 `SUPER`（Win 键）。想核对运行时的真实绑定：

```bash
hyprctl binds -j | python3 -c "
import json,sys
for b in json.load(sys.stdin):
    print(b['modmask'], b['key'], b.get('description') or '')"
# modmask: SHIFT=1 CAPS=2 CTRL=4 ALT=8 SUPER=64  → SUPER+ALT = 72
```

## 窗口与启动

| 键 | 动作 | 备注 |
|---|---|---|
| `SUPER + Q` | kitty 终端 | |
| `SUPER + E` | yazi 文件管理器 | 在 kitty 里跑，退出时 shell 会跟到 yazi 的目录 |
| `SUPER + SHIFT + E` | thunar | |
| `SUPER + R` | hyprlauncher | 启动器 |
| `SUPER + F` | firefox | 启动即全屏（窗口规则 firefox-fullscreen）|
| `SUPER + G` | chrome-optimized.sh | 带 Wayland/输入法/代理参数 |
| `SUPER + B` | blueman-manager | |
| `SUPER + H` | Hermes Desktop | 本机 AI 客户端，别的机器上删掉这条 |
| `SUPER + SHIFT + H` | DSH 控制面板 | 同上 |
| `SUPER + C` | 关闭焦点窗口 | |
| `SUPER + F11` | 全屏切换 | |
| `SUPER + M` | 退出 Hyprland | 有 hyprshutdown 就用它（带确认）|
| `SUPER + L` | hyprlock 锁屏 | |
| `SUPER + ESC` | 关屏（亮度归零）| 不是 DMPS 休眠，只是背光 |
| `SUPER + SHIFT + ESC` | 恢复亮度 | |

## 布局

| 键 | 动作 |
|---|---|
| `SUPER + V` | 切换焦点窗口浮动（toggle）|
| `SUPER + SHIFT + V` | 剪贴板历史（wofi dmenu + cliphist）**← 仓库版改动** |
| `SUPER + P` | 伪平铺 pseudo |
| `SUPER + J` | 切换分割方向（仅 dwindle）|
| `SUPER + 方向键` | 焦点移动 |
| `SUPER + 左键拖动` | 拖动窗口 |
| `SUPER + 右键拖动` | 缩放窗口 |
| `鼠标侧键(274)` | 关闭窗口 |

## 工作区

| 键 | 动作 |
|---|---|
| `SUPER + 1..9 / 0` | 切换工作区 1~10（0 = 10）|
| `SUPER + SHIFT + 1..0` | 把窗口移到对应工作区 |
| `SUPER + 滚轮上/下` | 上一个 / 下一个工作区 |
| `SUPER + S` | 切到特殊工作区 `magic` |
| `SUPER + SHIFT + S` | 把窗口移到 `special:magic` |
| 三指横滑 | 切工作区（gesture workspace）|

## 屏幕旋转（**本机专有**：LVDS-1 内屏 / HDMI-A-1 外屏 / VGA-1 投影）

| 键 | 动作 |
|---|---|
| `CTRL + ALT + 0/1/2/3` | 内屏 0°/90°/180°/270° |
| `CTRL + ALT + SHIFT + 0/1/2/3` | HDMI-A-1 旋转 |
| `CTRL + SUPER + 0/1/2/3` | VGA-1 旋转 |

旋转脚本会 disable→enable 输出强制重分配 buffer，并对 XWayland 浏览器 toggle 两次全屏，
否则竖屏后浏览器缓存的屏幕尺寸失效、全屏铺不满（`rotate-hyprland.sh` 头注释里有完整缘由）。

## 硬件功能键（`locked = true`，锁屏状态也生效）

| 键 | 动作 |
|---|---|
| `XF86AudioRaiseVolume / LowerVolume` | wpctl ±5%（上限 100%）|
| `XF86AudioMute` | 静音 sink |
| `XF86AudioMicMute` | 静音 source（**登录时默认静音麦克风**）|
| `XF86MonBrightnessUp / Down` | brightnessctl ±5% |
| `XF86AudioPlay / Pause / Next / Prev` | playerctl |

## 状态栏点击（waybar）

| 位置 | 左键 | 右键 | 中键 |
|---|---|---|---|
| 应用图标 | wofi drun | 快捷键速查 `waybar-keybinds.sh` | — |
| 模拟器图标 | 启动 QtDemo34 | 关闭 | — |
| Chrome / Firefox / thunar | 启动对应程序 | — | — |
| wifi | `wifi-menu.sh`（wofi + nmcli）| `kitty -e nmtui` | 关/开 WiFi |
| 有线 | `kitty -e nmtui` | — | — |
| 蓝牙 | blueman-manager | `bluetoothctl power off` | — |
| 电源图标 | `waybar-power.sh`（关机/重启）| — | — |

## 已知冲突（现役机器）

`SUPER + V` 在现役 `hyprland.lua` 里绑了两次（「切换浮动」和「剪贴板历史」），
`hyprctl binds` 两条都在，运行时只有一个生效。仓库版把剪贴板改到 `SUPER + SHIFT + V`。
