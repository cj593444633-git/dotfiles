#!/bin/bash
# WiFi / 网络菜单（wofi + nmcli）—— waybar network 模块的左键入口
# 用法:
#   wifi-menu.sh            打开 wofi 菜单（默认）
#   wifi-menu.sh --list     只打印菜单项（不自测 GUI，供排查）
#   wifi-menu.sh --status   打印当前网络状态
set -uo pipefail

WOFI="/usr/sbin/wofi"
NOTIFY="notify-send -a wifi-menu -i network-wireless"

need() { command -v "$1" >/dev/null || { echo "缺少 $1" >&2; exit 1; }; }
need nmcli

menu_items() {
    echo "操作: 打开 nmtui（完整管理）"
    echo "操作: 开关 WiFi"
    echo "操作: 断开当前 WiFi"
    echo "操作: 刷新并重扫网络"
    echo "----"
    local cur
    cur=$(nmcli -t -f NAME,TYPE,DEVICE connection show --active | awk -F: '$2=="802-11-wireless"{print $1}')
    while IFS= read -r name; do
        [ -z "$name" ] && continue
        if [ "$name" = "$cur" ]; then echo "已保存: $name  (当前)"; else echo "已保存: $name"; fi
    done < <(nmcli -t -f NAME,TYPE connection show | awk -F: '$2=="802-11-wireless"{print $1}')
    echo "----"
    while IFS=: read -r ssid sig sec inuse; do
        [ -z "${ssid:-}" ] && continue
        case "$inuse" in \**) continue ;; esac
        printf '可见: %s  %s%%%s\n' "$ssid" "$sig" "${sec:+ [$sec]}"
    done < <(nmcli -t -f SSID,SIGNAL,SECURITY,IN-USE dev wifi list --rescan yes 2>/dev/null)
}

ask_password() {
    "$WOFI" --dmenu --password --prompt "WiFi 密码 ($1): " --lines 1 2>/dev/null
}

connect_new() {
    local ssid="$1" pass="$2"
    local tmp rc=1
    if [ -n "$pass" ]; then
        tmp=$(mktemp /tmp/wifi-pass.XXXXXX)
        chmod 600 "$tmp"; printf '802-11-wireless-security.psk:%s\n' "$pass" > "$tmp"
        nmcli dev wifi connect "$ssid" passwd-file "$tmp" >/dev/null 2>&1 && rc=0
        rm -f "$tmp"
    else
        nmcli dev wifi connect "$ssid" >/dev/null 2>&1 && rc=0
        if [ $rc -ne 0 ]; then            # 可能是加密网络，问密码再来一次
            pass=$(ask_password "$ssid")
            if [ -n "$pass" ]; then
                tmp=$(mktemp /tmp/wifi-pass.XXXXXX)
                chmod 600 "$tmp"; printf '802-11-wireless-security.psk:%s\n' "$pass" > "$tmp"
                nmcli dev wifi connect "$ssid" passwd-file "$tmp" >/dev/null 2>&1 && rc=0
                rm -f "$tmp"
            fi
        fi
    fi
    if [ $rc -eq 0 ]; then
        $NOTIFY "已连接 $ssid"
    else
        $NOTIFY -u critical "连接 $ssid 失败" "可以试试点右键用 nmtui"
    fi
}

case "${1:-}" in
--status)
    nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev status | grep -v '^lo:'
    nmcli -t -f active,ssid,signal dev wifi | grep '^yes' || true
    exit 0
    ;;
--list)
    menu_items
    exit 0
    ;;
esac

ITEM=$(menu_items | "$WOFI" --dmenu --prompt "网络: " --width 420 2>/dev/null) || exit 0
case "$ITEM" in
    "操作: 打开 nmtui（完整管理）") exec /usr/bin/kitty --title "nmtui" -e nmtui ;;
    "操作: 开关 WiFi")   nmcli radio wifi "$(nmcli -t -f WIFI radio | grep -q enabled && echo off || echo on)" \
                            && $NOTIFY "WiFi 已切换为 $(nmcli -t -f WIFI radio)" ;;
    "操作: 断开当前 WiFi") nmcli dev disconnect wlp3s0 >/dev/null 2>&1 && $NOTIFY "已断开 WiFi" ;;
    "操作: 刷新并重扫网络") exec "$0" ;;
    "已保存: "*)
        name="${ITEM#已保存: }"; name="${name%%  (*}"
        if nmcli con up "$name" >/dev/null 2>&1; then $NOTIFY "已连接 $name"; else $NOTIFY -u critical "连接 $name 失败"; fi ;;
    "可见: "*)
        rest="${ITEM#可见: }"; ssid="${rest%%  *}"
        connect_new "$ssid" "" ;;
    *) exit 0 ;;
esac
