#!/usr/bin/env bash
# apply-ly-config.sh —— 幂等地把本桌面需要的几项写进 /etc/ly/config.ini
#
#   sudo ./system/apply-ly-config.sh --user chen              # 只改会话/用户
#   sudo ./system/apply-ly-config.sh --user chen --autologin  # 顺带免密自动登录
#   sudo ./system/apply-ly-config.sh --user chen --no-autologin
#
# 为什么不用整份 config.ini 覆盖：ly 的配置项会随版本增删，整份盖会把新版本缺项
# 带回来。这里只 sed 我们关心的几个键（行不存在就追加），其余保持包默认值。
set -euo pipefail

CONF=/etc/ly/config.ini
PAM_SRC="$(cd "$(dirname "$0")" && pwd)/pam.d/ly-autologin"
PAM_DST=/etc/pam.d/ly-autologin
USER_NAME=""
AUTOLOGIN=""
SESSION=hyprland-uwsm

while [ $# -gt 0 ]; do
  case "$1" in
    --user)         USER_NAME="$2"; shift 2 ;;
    --autologin)    AUTOLOGIN=yes; shift ;;
    --no-autologin) AUTOLOGIN=no; shift ;;
    --session)      SESSION="$2"; shift 2 ;;
    --conf)         CONF="$2"; shift 2 ;;   # 仅用于自测：对一份副本跑
    -h|--help)      sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数: $1" >&2; exit 2 ;;
  esac
done

[ "$(id -u)" = 0 ] || { echo "要 root: sudo $0 --user <你的用户名>" >&2; exit 1; }
[ -n "$USER_NAME" ] || { echo "必须给 --user <用户名>" >&2; exit 2; }
id "$USER_NAME" >/dev/null 2>&1 || { echo "用户不存在: $USER_NAME" >&2; exit 1; }
[ -f "/usr/share/wayland-sessions/${SESSION}.desktop" ] || {
  echo "警告: /usr/share/wayland-sessions/${SESSION}.desktop 不存在（uwsm 没装？）" >&2
}

[ -f "$CONF" ] || { echo "没有 $CONF —— 先装 ly 包" >&2; exit 1; }
BAK="${CONF}.bak.$(date +%Y%m%d-%H%M%S)"
cp -a "$CONF" "$BAK"
echo "备份: $BAK"

set_key() {   # set_key <键> <值> —— 改第一条（可能被注释的）该键，没有就追加
  local k="$1" v="$2"
  python3 - "$CONF" "$k" "$v" <<'PY'
import re, sys
path, key, val = sys.argv[1], sys.argv[2], sys.argv[3]
lines = open(path, encoding='utf-8').read().splitlines()
pat = re.compile(r'^\s*#?\s*' + re.escape(key) + r'\s*=')
for i, line in enumerate(lines):
    if pat.match(line):
        lines[i] = f'{key} = {val}'
        break
else:
    lines.append(f'{key} = {val}')
open(path, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
PY
  printf '  %-22s = %s\n' "$k" "$v"
}

echo "写入 $CONF:"
set_key auto_login_user    "$USER_NAME"
set_key auto_login_service "ly-autologin"
if [ -f "/usr/share/wayland-sessions/${SESSION}.desktop" ]; then
  set_key auto_login_session "$SESSION"
else
  set_key auto_login_session "hyprland"   # 没装 uwsm 时退化成非托管会话（状态栏不会自动起）
  echo "  ⚠ 退化成 hyprland（非 uwsm）：waybar/fcitx5/hypridle 不会自动启动！" >&2
fi

case "$AUTOLOGIN" in
  yes)
    set_key allow_empty_password true
    if [ -f "$PAM_SRC" ]; then
      cp -a "$PAM_DST" "${PAM_DST}.bak.$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
      install -m 644 "$PAM_SRC" "$PAM_DST"
      echo "  PAM 免密服务已装: $PAM_DST"
    fi
    ;;
  no)
    echo "  （保持 PAM 现状；要彻底关自动登录就把 auto_login_session 设为 null）"
    ;;
esac

echo
echo "生效时机：ly 只在启动时读配置 → **下次开机**。别在桌面里 systemctl restart ly（会踢掉当前会话）。"
echo "核对: grep -nE '^[[:space:]]*(auto_login_user|auto_login_service|auto_login_session|allow_empty_password)' $CONF"
