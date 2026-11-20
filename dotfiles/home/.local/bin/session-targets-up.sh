#!/bin/sh
# session-targets-up.sh — 非 uwsm 会话里把"会话级" systemd target 拉起来
#
# 背景(2026-09-23 实测):
#   ly 的 session 是 /usr/bin/start-hyprland(非 uwsm), 没有任何东西以"依赖"方式
#   拉起 graphical-session.target / xdg-desktop-autostart.target, 于是:
#     waybar / hypridle / hyprpolkitagent / udisks-automount  (WantedBy=graphical-session.target)
#     fcitx5 / blueman-applet / xapp-sn-watcher                (XDG autostart 生成单元)
#   全都不启动 —— 表现就是"状态栏没了、输入法没了、蓝牙托盘没了"。
#   systemd 261 对这两个 target 设了 RefuseManualStart=yes(只准会话管理器以依赖方式拉),
#   本机已在下面两个 drop-in 里放开手动启动:
#     ~/.config/systemd/user/graphical-session.target.d/10-allow-manual-start.conf
#     ~/.config/systemd/user/xdg-desktop-autostart.target.d/10-allow-manual-start.conf
#
# 由 ~/.config/hypr/hyprland.lua 的 hyprland.start 钩子调用(每次登录一次)。
# uwsm 会话里直接退出 —— 那边由 wayland-session@hyprland.desktop.target 正常
# 拉起并随会话停止, 绝不能在这里停/重启那些 target(会连带把合成器停掉=秒登出)。
set -u

LOG="$HOME/.local/state/session-targets-up.log"
log() {
    printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG" 2>/dev/null || true
}

UWSM_SESSION='wayland-session@hyprland.desktop.target'
case "$(systemctl --user is-active "$UWSM_SESSION" 2>/dev/null)" in
    active|activating|reloading)
        log "uwsm 会话已托管 ($UWSM_SESSION), 不需要兜底"
        exit 0
        ;;
esac

# 等 systemd 用户管理器把环境导入完(hypridle 有 ConditionEnvironment=WAYLAND_DISPLAY)
i=0
while [ "$i" -lt 20 ]; do
    if systemctl --user show-environment 2>/dev/null | grep -q '^WAYLAND_DISPLAY='; then
        break
    fi
    sleep 0.25
    i=$((i + 1))
done

# 探活: 正常会话里这两个 target 是"新的", 但因为 linger=yes(用户管理器跨注销常驻),
# 上一次登录遗留的 target 会一直是 active, 里面的单元(waybar/hypridle…)指着已经死掉的
# Wayland 连接。所以非 uwsm 会话里先停再起 —— 非 uwsm 会话下没人 BindsTo 这俩 target,
# 停它们是安全的(PartOf= 会把 waybar/hypridle/polkit/automount 一起停掉再重新拉起)。
if systemctl --user is-active --quiet graphical-session.target 2>/dev/null; then
    log "检测到上次登录遗留的会话 target, 先停再起(清理指向死连接的单元)"
    systemctl --user stop graphical-session.target xdg-desktop-autostart.target 2>/dev/null || true
fi

log "拉起会话级 target (graphical-session.target + xdg-desktop-autostart.target)"
exec systemctl --user --no-block start graphical-session.target xdg-desktop-autostart.target
