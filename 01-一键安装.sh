#!/usr/bin/env bash
# 01-一键安装.sh —— 在新机上把「桌面 + 代理」装起来（root）
#
#   sudo bash 01-一键安装.sh --user <用户名>                       # 装桌面 + 代理（TUN 照参考机）
#   sudo bash 01-一键安装.sh --user <用户名> --tun off --lan-cidr 192.168.1.0/24
#   sudo bash 01-一键安装.sh --user <用户名> --skip-bootstrap      # 只铺 dotfiles（包自己装）
#   sudo bash 01-一键安装.sh --list                                # 看这个目录里有什么
#   sudo bash 01-一键安装.sh --self-test                           # 不碰系统的自检（可非 root）
#
# 它做的事（按顺序，任一步失败就停）：
#   1. 补回可执行权限（exfat/U 盘不保留权限位，所以必须用 bash 调本脚本）
#   2. 把 dotfiles/ 拷到 <用户家目录>/dotfiles（已有则先改名备份）
#   3. bootstrap.sh：装 57 个桌面包 + 启动服务 + 写 ly 的 hyprland-uwsm 会话
#   4. proxy/install-mihomo.sh：装 mihomo + 铺配置 + 起服务（用本目录的 bundle）
#   5. 以该用户身份跑 install.sh（软链 dotfiles 进 ~）
# 之后你重新登录，再跑一次 ./install.sh --enable-units 即可。
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
USER_NAME="${SUDO_USER:-}"
TUN="keep"
LAN_CIDR=""
AUTOLOGIN=""
SKIP_BOOTSTRAP=0
SKIP_USER_INSTALL=0
DRY=0
DEST=""

while [ $# -gt 0 ]; do
  case "$1" in
    --user)           USER_NAME="$2"; shift 2 ;;
    --tun)            TUN="$2"; shift 2 ;;
    --lan-cidr)       LAN_CIDR="$2"; shift 2 ;;
    --autologin)      AUTOLOGIN=--autologin; shift ;;
    --skip-bootstrap) SKIP_BOOTSTRAP=1; shift ;;
    --skip-user-install) SKIP_USER_INSTALL=1; shift ;;
    --dest)           DEST="$2"; shift 2 ;;
    --dry-run)        DRY=1; shift ;;
    --list)
      echo "目录: $HERE"
      ls -1 "$HERE" | sed 's/^/  /'
      echo
      echo "dotfiles 仓库: $(find "$HERE/dotfiles/home" -type f 2>/dev/null | wc -l) 个文件"
      echo "代理 bundle  : $(ls "$HERE"/mihomo-bundle-*.tar.gz 2>/dev/null || echo '（没有）')"
      echo "手册         : $(ls "$HERE"/手册/*.pdf 2>/dev/null || echo '（没有）')"
      exit 0 ;;
    --self-test)
      echo "══ 自检：脚本能否找到所有部件（不碰系统） ══"
      ok=1
      for f in dotfiles/bootstrap.sh dotfiles/install.sh dotfiles/proxy/install-mihomo.sh \
               dotfiles/proxy/export-from-live.sh dotfiles/system/apply-ly-config.sh; do
        if [ -f "$HERE/$f" ]; then printf '  ✓ %s\n' "$f"; else printf '  ✗ 缺 %s\n' "$f"; ok=0; fi
      done
      b="$(ls "$HERE"/mihomo-bundle-*.tar.gz 2>/dev/null | tail -1 || true)"
      if [ -n "$b" ]; then printf '  ✓ %s (%s)\n' "$(basename "$b")" "$(du -h "$b" | cut -f1)"
      else printf '  ✗ 缺 mihomo bundle\n'; ok=0; fi
      echo "  -- 语法检查 --"
      for s in 01-一键安装.sh dotfiles/bootstrap.sh dotfiles/install.sh dotfiles/proxy/install-mihomo.sh; do
        bash -n "$HERE/$s" && printf '  ✓ %s\n' "$s" || { printf '  ✗ %s\n' "$s"; ok=0; }
      done
      if [ "$ok" = 1 ]; then echo "  自检通过"; else echo "  自检失败"; exit 1; fi
      exit 0 ;;
    -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数: $1（--help 看用法）" >&2; exit 2 ;;
  esac
done

run() { if [ "$DRY" = 1 ]; then printf '  [dry] %s\n' "$*"; else "$@"; fi; }

echo "══ 0. 检查 ══"
[ -n "$USER_NAME" ] || { echo "必须给 --user <用户名>" >&2; exit 2; }
id "$USER_NAME" >/dev/null 2>&1 || { echo "用户不存在: $USER_NAME（先 useradd -m -G wheel,video,audio,seat,input,render $USER_NAME）" >&2; exit 1; }
U_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
TEST_MODE=0
if [ -n "$DEST" ] && [ "$DEST" != "$U_HOME/dotfiles" ]; then
  TEST_MODE=1          # 显式 --dest 到别处 = 演练，不要求 root（也不动系统服务）
fi
if [ "$DRY" = 0 ] && [ "$TEST_MODE" = 0 ] && [ "$(id -u)" != 0 ]; then
  echo "要 root：sudo bash $0 --user <用户名>（演练可加 --dest /tmp/xxx）" >&2; exit 1
fi
[ -n "$DEST" ] || DEST="$U_HOME/dotfiles"
BUNDLE="$(ls "$HERE"/mihomo-bundle-*.tar.gz 2>/dev/null | tail -1 || true)"

echo "  安装目录 : $DEST"
echo "  代理     : ${BUNDLE:-（没找到 bundle，跳过代理）}"
echo "  TUN      : $TUN$([ -n "$LAN_CIDR" ] && echo "  局域网 $LAN_CIDR")"
echo "  自检指北 : 完整流程见 00-安装说明.txt"

echo "══ 1. 补可执行权限（U 盘 exfat 丢权限） ══"
if [ "$DRY" = 0 ]; then
  find "$HERE" -name '*.sh' -exec chmod +x {} + 2>/dev/null || true
  find "$HERE/dotfiles/home/.local/bin" -type f -exec chmod +x {} + 2>/dev/null || true
fi
echo "  ok"

echo "══ 2. 拷 dotfiles → $DEST ══"
if [ -e "$DEST" ]; then
  BAK="$DEST.bak.$(date +%Y%m%d-%H%M%S)"
  echo "  已存在，先改名备份: $BAK"
  run mv "$DEST" "$BAK"
fi
run mkdir -p "$(dirname "$DEST")"
run cp -a "$HERE/dotfiles" "$DEST"
if [ "$DRY" = 0 ]; then
  chown -R "$USER_NAME":"$(id -gn "$USER_NAME")" "$DEST" 2>/dev/null \
    || echo "  ⚠ chown 失败（演练模式/非 root 属正常），真装时是 root 不会遇到"
fi
echo "  文件数: $(find "$HERE/dotfiles/home" -type f | wc -l)"

if [ "$SKIP_BOOTSTRAP" = 0 ]; then
  echo "══ 3-4. 装包 / 服务 / 会话 / 代理 ══"
  BOOT_ARGS=(--user "$USER_NAME" --tun "$TUN" $AUTOLOGIN)
  [ -n "$LAN_CIDR" ] && BOOT_ARGS+=(--lan-cidr "$LAN_CIDR")
  [ -n "$BUNDLE" ] && BOOT_ARGS+=(--with-proxy "$BUNDLE")
  [ "$DRY" = 1 ] && BOOT_ARGS+=(--dry-run)
  run bash "$DEST/bootstrap.sh" "${BOOT_ARGS[@]}"
else
  echo "══ 3-4. 跳过（--skip-bootstrap） ══"
fi

echo "══ 5. 以 $USER_NAME 身份铺 dotfiles（软链进 ~） ══"
if [ "$SKIP_USER_INSTALL" = 1 ]; then
  echo "  跳过（--skip-user-install）。手工执行：su - $USER_NAME -c 'bash $DEST/install.sh'"
elif [ "$DRY" = 1 ]; then
  echo "  [dry] sudo -u $USER_NAME -H bash $DEST/install.sh"
else
  if command -v sudo >/dev/null; then
    sudo -u "$USER_NAME" -H bash "$DEST/install.sh" || {
      echo "  ⚠ 以用户身份安装失败（常见原因：sudoers 还没配好）。手工执行：" >&2
      echo "     su - $USER_NAME -c 'bash $DEST/install.sh'" >&2
    }
  else
    echo "  ⚠ 没有 sudo，手工执行: su - $USER_NAME -c 'bash $DEST/install.sh'" >&2
  fi
fi

cat <<EOF

══ 完成 ══
  1) 重启（或 loginctl terminate-user $USER_NAME）—— ly 只在启动时读会话配置
  2) 登录后第一件事（启用 waybar / hypridle / 自动挂载 / polkit 认证）：
       cd $DEST && ./install.sh --enable-units
  3) 验收清单：$DEST/docs/新机安装手册.md 的「阶段 5：验收清单」（U 盘上还有 PDF 版手册）
  4) 代理：终端 proxyon / proxyoff；浏览器用 ~/.local/bin/chrome-optimized.sh
     改了 mihomo 配置后 systemctl reload mihomo
EOF
