#!/usr/bin/env bash
# install.sh —— 把 home/ 下的 dotfiles 装进当前用户的 $HOME（默认软链，便于改一份两边生效）
#
#   ./install.sh                 软链进 $HOME（已存在且内容不同的文件先备份）
#   ./install.sh --copy          复制而不是软链（想把 dotfiles 当模板、之后各机器独立改时用）
#   ./install.sh --dry-run       只打印会做什么，不动文件
#   ./install.sh --list          列出清单里每个文件的目标路径与状态
#   ./install.sh --no-backup     万一被 shell 的备份机制覆盖也不留副本（默认留）
#
# 不会做的事：不装包、不改 /etc、不启服务 —— 那些在 bootstrap.sh / system/README.md。
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
SRC="$REPO/home"
MODE=link
DRY=0
LIST_ONLY=0
BACKUP=1
ENABLE_UNITS=0
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/.dotfiles-backup-$STAMP"

for a in "$@"; do
  case "$a" in
    --copy)      MODE=copy ;;
    --dry-run)   DRY=1 ;;
    --list)      LIST_ONLY=1 ;;
    --no-backup) BACKUP=0 ;;
    --enable-units) ENABLE_UNITS=1 ;;
    -h|--help)   sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数: $a（看 --help）" >&2; exit 2 ;;
  esac
done

[ -d "$SRC" ] || { echo "找不到 $SRC —— 请在仓库根目录跑。" >&2; exit 1; }

say()  { printf '%s\n' "$*"; }
act()  { if [ "$DRY" = 1 ]; then say "  [dry] $*"; else eval "$@"; fi }

# 目标路径太长时 hyprland/waybar 的 exec 里看着乱，但软链是标准做法（stow 同款）
count_ok=0 count_new=0 count_bak=0 count_same=0

mapfile -t FILES < <(cd "$SRC" && find . -type f ! -name '.gitkeep' | sed 's|^\./||' | sort)
[ "${#FILES[@]}" -gt 0 ] || { echo "$SRC 是空的 —— 先跑 tools/sync-from-live.sh" >&2; exit 1; }

say "仓库: $REPO"
say "目标: $HOME"
say "模式: $([ "$MODE" = copy ] && echo 复制 || echo 软链)$([ "$DRY" = 1 ] && echo ' (dry-run)')"
say "共 $(( ${#FILES[@]} )) 个文件"
say ""

for rel in "${FILES[@]}"; do
  target="$HOME/$rel"
  src="$SRC/$rel"

  if [ "$LIST_ONLY" = 1 ]; then
    if [ -L "$target" ]; then
      st="软链 → $(readlink -f "$target" 2>/dev/null || echo 坏链)"
    elif [ -e "$target" ]; then
      if cmp -s "$src" "$target"; then st="已存在(内容相同)"; else st="已存在(内容不同，会被备份)"; fi
    else
      st="不存在(将新增)"
    fi
    printf '  %-58s %s\n' "$rel" "$st"
    continue
  fi

  mkdir_parent="$(dirname "$target")"
  act "mkdir -p '$mkdir_parent'"

  if [ "$MODE" = copy ]; then
    if [ -e "$target" ] && ! cmp -s "$src" "$target"; then
      act "mkdir -p '$BACKUP_DIR/$(dirname "$rel")'"
      act "cp -a '$target' '$BACKUP_DIR/$rel'"
      count_bak=$((count_bak + 1))
      say "  备份 $rel → $BACKUP_DIR/"
      act "cp -a '$src' '$target'"
      count_new=$((count_new + 1))
    elif [ ! -e "$target" ]; then
      act "cp -a '$src' '$target'"
      count_new=$((count_new + 1))
      say "  新增 $rel"
    else
      count_same=$((count_same + 1))
      say "  跳过 $rel（内容相同）"
    fi
  else
    # 软链模式：目标是同一个软链就跳过；否则先备份再链
    if [ -L "$target" ] && [ "$(readlink -f "$target")" = "$(readlink -f "$src")" ]; then
      count_same=$((count_same + 1))
      continue
    fi
    if [ -e "$target" ] || [ -L "$target" ]; then
      # 之前有人装在别处的软链：删链不删源
      if [ -L "$target" ]; then
        act "rm -f '$target'"
      else
        act "mkdir -p '$BACKUP_DIR/$(dirname "$rel")'"
        act "cp -a '$target' '$BACKUP_DIR/$rel'"
        act "rm -f '$target'"
        count_bak=$((count_bak + 1))
        say "  备份 $rel → $BACKUP_DIR/"
      fi
    fi
    act "ln -sfn '$src' '$target'"
    count_new=$((count_new + 1))
    say "  链接 $rel"
  fi

  # 可执行位：~/.local/bin 下的脚本必须有
  case "$rel" in
    .local/bin/*) act "chmod +x '$target'" ;;
  esac
done

if [ "$LIST_ONLY" = 1 ]; then
  exit 0
fi

say ""
say "完成：新增/更新 $count_new，跳过 $count_same，备份 $count_bak$([ "$count_bak" -gt 0 ] && echo "（$BACKUP_DIR）")"

if [ "$ENABLE_UNITS" = 1 ]; then
  say ""
  say "启用 systemd 用户单元（waybar / hypridle / 自动挂载 / polkit 认证）"
  act "systemctl --user daemon-reload"
  for u in waybar.service hypridle.service udisks-automount.service hyprpolkitagent.service; do
    # hyprpolkitagent/polkit 单元名各发行版可能不同，存在才 enable
    if systemctl --user list-unit-files "$u" 2>/dev/null | grep -q "^$u"; then
      act "systemctl --user enable '$u'"
    fi
  done
  say "  提示：waybar.service 有 Requisite=graphical-session.target —— 只有 uwsm 会话"
  say "        或 hyprland.start 钩子里的 session-targets-up.sh 拉起会话 target 后才会启动。"
fi

cat <<EOF

接下来（新机器上第一次安装时）：
  1. 装包：sudo ./bootstrap.sh --user \$USER        （或直接看 packages/desktop.txt）
  2. 会话：sudo ./bootstrap.sh 会写好 ly 的 hyprland-uwsm 会话 + PAM 自动登录
  3. 重新登录（注销再进，不是 hyprctl reload —— 钩子只在登录时跑一次）
  4. 验收：见 docs/新机安装手册.md 的「验收清单」一节
EOF
