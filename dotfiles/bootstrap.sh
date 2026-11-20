#!/usr/bin/env bash
# bootstrap.sh —— 新 Arch 机器上把「包 + 服务 + 登录会话」一次配好（root）
#
#   sudo ./bootstrap.sh --user chen                    # 装包、启服务、写 ly 会话
#   sudo ./bootstrap.sh --user chen --autologin        # 顺带免密自动登录（PAM ly-autologin）
#   sudo ./bootstrap.sh --user chen --dry-run          # 只打印要做什么
#   sudo ./bootstrap.sh --user chen --skip-packages    # 包已自己装好了，只配服务/会话
#
# 前提：已装好 base 系统、能联网、用户已存在（useradd -m -G wheel,video,audio,seat chen）。
# 本脚本不动分区/引导，安装介质那部分见 docs/新机安装手册.md。
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
USER_NAME="${SUDO_USER:-}"
AUTOLOGIN=""
DRY=0
SKIP_PKGS=0
PROXY_BUNDLE=""
PROXY_TUN=keep
LAN_CIDR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --user)          USER_NAME="$2"; shift 2 ;;
    --autologin)     AUTOLOGIN=--autologin; shift ;;
    --skip-packages) SKIP_PKGS=1; shift ;;
    --dry-run)       DRY=1; shift ;;
    --with-proxy)    PROXY_BUNDLE="$2"; shift 2 ;;
    --proxy-tun)     PROXY_TUN="$2"; shift 2 ;;
    --lan-cidr)      LAN_CIDR="$2"; shift 2 ;;
    -h|--help)       sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数: $1" >&2; exit 2 ;;
  esac
done

run() {
  if [ "$DRY" = 1 ]; then printf '  [dry] %s\n' "$*"; else printf '  + %s\n' "$*"; "$@"; fi
}

[ "$(id -u)" = 0 ] || { echo "要 root: sudo $0 --user <用户名>" >&2; exit 1; }
[ -n "$USER_NAME" ] || { echo "必须给 --user <用户名>（或确保通过 sudo 运行）" >&2; exit 2; }
id "$USER_NAME" >/dev/null 2>&1 || { echo "用户不存在: $USER_NAME —— 先 useradd -m -G wheel,video,audio $USER_NAME" >&2; exit 1; }

echo "══ 0. 环境检查 ══"
[ -f /etc/arch-release ] || echo "  ⚠ 这不是 Arch（/etc/arch-release 不存在），脚本按 Arch 写，继续但可能失败"
command -v pacman >/dev/null || { echo "没有 pacman" >&2; exit 1; }
ping -c1 -W2 archlinux.org >/dev/null 2>&1 && echo "  ✓ 网络通" || echo "  ⚠ 连不上 archlinux.org（若用代理，先配好 pacman/curl）"

if [ "$SKIP_PKGS" = 0 ]; then
  echo "══ 1. 装桌面包（packages/desktop.txt） ══"
  # 行尾 # 注释先去掉，一行里写了多个包也要全部取到（早期版本只取 $1，漏了 20 多个包）
  PKGS="$(awk '{ sub(/#.*/, ""); for (i = 1; i <= NF; i++) print $i }' "$HERE/packages/desktop.txt" | tr '\n' ' ')"
  echo "  共 $(echo "$PKGS" | wc -w) 个包"
  run pacman -S --needed --noconfirm $PKGS
else
  echo "══ 1. 跳过装包（--skip-packages） ══"
fi

echo "══ 2. 服务 ══"
# 网络：NetworkManager 与 systemd-networkd 二选一，同时开会抢接口
if systemctl is-enabled --quiet systemd-networkd.service 2>/dev/null; then
  echo "  检测到 systemd-networkd 在跑 —— 与 NetworkManager 冲突"
  run systemctl disable --now systemd-networkd.service
  run systemctl disable --now systemd-networkd.socket 2>/dev/null || true
fi
run systemctl enable --now NetworkManager.service
run systemctl enable --now bluetooth.service

# 显示管理器：ly 用模板单元，跑在 tty1（与 getty@tty1 有 Conflicts=，不用手动关）
run systemctl enable ly@tty1.service
if [ "$DRY" = 0 ]; then
  systemctl is-enabled ly@tty1.service >/dev/null 2>&1 && echo "  ✓ ly@tty1 已 enable（下次开机生效）"
fi

# 蓝牙/声音相关组（用户得在这几个组里才不报权限错）
echo "══ 3. 用户组 ══"
for g in video audio seat input render; do
  if getent group "$g" >/dev/null 2>&1; then
    run usermod -aG "$g" "$USER_NAME"
  fi
done

echo "══ 4. ly 会话与自动登录 ══"
run bash "$HERE/system/apply-ly-config.sh" --user "$USER_NAME" $AUTOLOGIN

if [ -n "$PROXY_BUNDLE" ]; then
  echo "══ 5. 代理（mihomo）—— 来自 bundle ══"
  PROXY_ARGS=(--bundle "$PROXY_BUNDLE" --tun "$PROXY_TUN")
  [ -n "$LAN_CIDR" ] && PROXY_ARGS+=(--lan-cidr "$LAN_CIDR")
  run bash "$HERE/proxy/install-mihomo.sh" "${PROXY_ARGS[@]}"
else
  echo "══ 5. 代理（mihomo）—— 跳过 ══"
  echo "  没有 --with-proxy，所以不装代理。要装：参考机上跑 proxy/export-from-live.sh，"
  echo "  把 bundle 拷过来后 sudo $0 --user $USER_NAME --with-proxy <bundle.tar.gz> [--proxy-tun off]"
fi

echo
echo "══ 完成，剩下的是用户级操作 ══"
cat <<EOF
  1) 退出 root shell，用 $USER_NAME 登录后：
       cd $HERE && ./install.sh            # 软链 dotfiles 进 ~
       ./install.sh --enable-units         # 启用 ~/.config/systemd/user 里的单元
  2) 重新登录（不是 hyprctl reload —— hyprland.start 钩子只在真正启动时跑）
  3) 验收清单：docs/新机安装手册.md 「验收」一节（waybar/fcitx5/锁屏/剪贴板/下载脚本逐项过）
EOF
