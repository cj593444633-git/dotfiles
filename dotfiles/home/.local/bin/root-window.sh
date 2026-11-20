#!/usr/bin/env bash
# root-window.sh — 本机唯一的提权通道:在 kitty 窗口里用 sudo 跑需要 root 的脚本。
# 原因: pkexec / 图形 polkit 代理在本机走不通;agent 不能替你输密码,只能开窗你自己输。
# 用法:  root-window.sh <需root的脚本> [更多脚本...]   # 多个脚本共用一次 sudo 密码
# 特点:  开窗前先关掉 fcitx5 输入法(避免密码被中文输入法吃掉),
#        脚本按顺序跑,任一出错继续跑下一个,窗口保持打开(--hold)供你回看。
set -u
[[ $# -ge 1 ]] || { echo "用法: root-window.sh <需root的脚本> [更多脚本...]" >&2; exit 2; }

RUNNER=$HOME/.local/bin/root-run-last.sh
title="root: $(basename "$1")"
[[ $# -gt 1 ]] && title="$title 等 $# 个"

{
  echo '#!/usr/bin/env bash'
  echo 'set -u'
  for s in "$@"; do
    printf 'echo; echo "════ %s ════"\n' "$(basename "$s")"
    printf 'bash %q; echo "[退出码 $?] %s"\n' "$s" "$(basename "$s")"
  done
  echo 'echo; echo "──── 全部脚本执行完毕,可关窗 ────"'
} > "$RUNNER"
chmod +x "$RUNNER"

exec kitty --title "$title" --hold -e bash -lc '
  fcitx5-remote -c 2>/dev/null || true
  echo "提示: 密码 = 登录桌面时输的那个;若窗口里输入法是中文,先按 Ctrl+空格 切成英文"
  echo
  exec sudo -p "sudo 密码: " bash $HOME/.local/bin/root-run-last.sh'
