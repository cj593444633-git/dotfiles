#!/usr/bin/env bash
# install-mihomo.sh —— 在新机上装出"和参考机一样的代理"（root）
#
#   sudo ./proxy/install-mihomo.sh --bundle ~/Downloads/mihomo-bundle-20261120.tar.gz
#   sudo ./proxy/install-mihomo.sh --bundle … --tun off      # 不开 TUN（只留 7890 混合端口）
#   sudo ./proxy/install-mihomo.sh --bundle … --dry-run      # 只打印要做什么
#   sudo ./proxy/install-mihomo.sh --bundle … --no-start     # 装好但不 enable/start
#
# 做的事：装包（缺 mihomo 时）→ 备份并铺 /etc/mihomo → 装 systemd 单元 → 配置自检 → 起服务 → 验端口与出网
#
# 自测（不需要 root，也不会碰 /etc）：把 bundle 铺到临时根目录并跑 mihomo -t
#   ./proxy/install-mihomo.sh --bundle x.tgz --root-dir /tmp/fakeroot
set -euo pipefail

BUNDLE=""
TUN=keep
DRY=0
START=1
ROOT_DIR=/
LAN_CIDR=""
HERE="$(cd "$(dirname "$0")" && pwd)"

while [ $# -gt 0 ]; do
  case "$1" in
    --bundle)   BUNDLE="$2"; shift 2 ;;
    --tun)      TUN="$2"; shift 2 ;;
    --lan-cidr) LAN_CIDR="$2"; shift 2 ;;
    --dry-run)  DRY=1; shift ;;
    --no-start) START=0; shift ;;
    --root-dir) ROOT_DIR="${2%/}"; [ -n "$ROOT_DIR" ] || ROOT_DIR=/; shift 2 ;;
    -h|--help)  sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数: $1" >&2; exit 2 ;;
  esac
done

SIMULATE=0
[ "$ROOT_DIR" != "/" ] && SIMULATE=1

[ -n "$BUNDLE" ] || { echo "必须给 --bundle <tar.gz>（参考机上用 proxy/export-from-live.sh 生成）" >&2; exit 2; }
[ -f "$BUNDLE" ] || { echo "找不到 bundle: $BUNDLE" >&2; exit 1; }
case "$TUN" in keep|on|off) ;; *) echo "--tun 只能是 keep/on/off" >&2; exit 2 ;; esac
if [ "$SIMULATE" = 0 ] && [ "$(id -u)" != 0 ]; then
  echo "要 root: sudo $0 --bundle <tar.gz>（自测加 --root-dir /tmp/xxx 可免 root）" >&2; exit 1
fi

run() { if [ "$DRY" = 1 ]; then printf '  [dry] %s\n' "$*"; else "$@"; fi; }
DEST="$ROOT_DIR"
CONF_DIR="$DEST/etc/mihomo"
UNIT_DIR="$DEST/etc/systemd/system"
STAMP="$(date +%Y%m%d-%H%M%S)"

echo "══ 0. 检查 ══"
echo "  bundle : $BUNDLE"
echo "  目标根 : $DEST$([ "$SIMULATE" = 1 ] && echo '  (模拟模式：不启服务、不验端口)')"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
tar -C "$TMP" -xzf "$BUNDLE"
B="$TMP/bundle"
[ -f "$B/etc-mihomo/config.yaml" ] || { echo "bundle 结构不对：缺 etc-mihomo/config.yaml" >&2; exit 1; }
sed -n '1,10p' "$B/MANIFEST.txt" 2>/dev/null | sed 's/^/  | /'

echo "══ 1. mihomo 二进制 ══"
if command -v mihomo >/dev/null; then
  echo "  已有: $(command -v mihomo)  $(mihomo -v 2>&1 | head -1)"
elif [ "$SIMULATE" = 1 ]; then
  echo "  ⚠ 模拟模式下没有 mihomo，跳过二进制检查（真装时会先装包）"
else
  echo "  未安装，尝试装包（AUR: mihomo-bin）"
  if command -v yay >/dev/null; then
    run yay -S --needed --noconfirm mihomo-bin
  elif command -v paru >/dev/null; then
    run paru -S --needed --noconfirm mihomo-bin
  else
    cat >&2 <<'EOF'
  没有 yay/paru。两种办法：
    a) 装 AUR helper 后重跑本脚本：sudo pacman -S --needed base-devel git && git clone https://aur.archlinux.org/yay-bin.git /tmp/yay && (cd /tmp/yay && makepkg -si)
    b) 直接拷参考机的 /usr/bin/mihomo 过来：chmod 755 /usr/bin/mihomo
EOF
    exit 1
  fi
fi

echo "══ 2. 备份并铺配置 ══"
if [ -d "$CONF_DIR" ]; then
  run cp -a "$CONF_DIR" "$CONF_DIR.bak.$STAMP"
  echo "  旧目录已备份: $CONF_DIR.bak.$STAMP"
fi
run mkdir -p "$CONF_DIR"
# 配置文件 600（含订阅与节点）；geo 库 644
for f in "$B"/etc-mihomo/*; do
  base="$(basename "$f")"
  case "$base" in
    *.mmdb|*.dat|*.metadb|*.meta) mode=644 ;;
    *) mode=600 ;;
  esac
  if [ "$DRY" = 1 ]; then
    printf '  [dry] install -m %s %s %s\n' "$mode" "$base" "$CONF_DIR/$base"
  else
    install -m "$mode" "$f" "$CONF_DIR/$base"
  fi
done
echo "  铺入 $(ls -1 "$B"/etc-mihomo | wc -l) 个文件 → $CONF_DIR"

echo "══ 3. TUN 开关（--tun $TUN） ══"
if [ "$TUN" != keep ] && [ "$DRY" = 0 ]; then
  python3 - "$CONF_DIR/config.yaml" "$TUN" <<'PY'
import re, sys
path, want = sys.argv[1], ('true' if sys.argv[2] == 'on' else 'false')
lines = open(path, encoding='utf-8').read().splitlines()
in_tun, hit = False, False
for i, ln in enumerate(lines):
    if re.match(r'^tun\s*:', ln):
        in_tun = True
        continue
    if in_tun:
        if re.match(r'^\S', ln):      # 回到顶层键 → tun 段结束
            break
        m = re.match(r'^(\s+)enable\s*:.*$', ln)
        if m:
            lines[i] = f'{m.group(1)}enable: {want}'
            hit = True
            break
open(path, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
print(f'  tun.enable → {want}' + ('' if hit else '（没有找到 tun.enable，检查配置是否有 tun 段）'))
PY
elif [ "$DRY" = 1 ] && [ "$TUN" != keep ]; then
  echo "  [dry] 会改 tun.enable → $([ "$TUN" = on ] && echo true || echo false)"
else
  echo "  保持 bundle 内的取值（参考机是开的）"
fi

echo "══ 4. 本机网段（TUN 的 route-exclude-address） ══"
# 参考机排除的是 192.168.2.0/24（它自己的局域网）。新机网段不同就必须改，
# 否则 NAS/打印机/路由器管理页会被 TUN 抢走 → 局域网设备访问不了。
if [ -n "$LAN_CIDR" ] && [ "$DRY" = 0 ]; then
  python3 - "$CONF_DIR/config.yaml" "$LAN_CIDR" <<'PY'
import re, sys
path, cidr = sys.argv[1], sys.argv[2]
lines = open(path, encoding='utf-8').read().splitlines()
in_tun, in_list, done, out = False, False, False, []
for ln in lines:
    if re.match(r'^tun\s*:', ln):
        in_tun, in_list = True, False
        out.append(ln); continue
    if in_tun:
        if re.match(r'^\S', ln):           # 离开 tun 段
            in_tun = False
        elif re.match(r'^\s+route-exclude-address\s*:', ln):
            in_list = True
            out.append(ln)
            out.append(f'        - {cidr}')
            done = True
            continue
        elif in_list:
            if re.match(r'^\s+-\s', ln):
                if '127.0.0.0/8' in ln:
                    out.append(ln)          # 回环永远保留
                continue                    # 其余旧网段丢弃，换成新值
            in_list = False
    out.append(ln)
if not done:                                # 原来没有这项就补在 tun 段末尾不好定位，直接提示
    print('  ⚠ 配置里没有 route-exclude-address，未修改（TUN 开时局域网访问可能异常）')
else:
    print(f'  route-exclude-address 加入 {cidr}（旧的局域网条目已替换，127.0.0.0/8 保留）')
open(path, 'w', encoding='utf-8').write('\n'.join(out) + '\n')
PY
  # 127.0.0.0/8 被误删的话补回来（上面逻辑只丢旧网段，不丢 127）
  grep -q '127.0.0.0/8' "$CONF_DIR/config.yaml" || echo "  ⚠ 127.0.0.0/8 不在排除列表里，请手动加回"
else
  echo "  保持 bundle 内的取值（参考机 192.168.2.0/24）—— 新机网段不同就加 --lan-cidr <你的网段>"
fi

echo "══ 5. 配置自检（mihomo -t） ══"
if command -v mihomo >/dev/null; then
  if run mihomo -t -d "$CONF_DIR" 2>&1 | tail -3; then
    echo "  ✓ 配置测试通过"
  else
    echo "  ✗ 配置测试失败 —— 先修配置再起服务（上面的日志）" >&2
    [ "$SIMULATE" = 0 ] && exit 3
  fi
else
  echo "  跳过（没有 mihomo 二进制）"
fi

echo "══ 6. systemd 单元 ══"
if [ -d "$B/systemd" ]; then
  run mkdir -p "$UNIT_DIR"
  for f in "$B"/systemd/*.service "$B"/systemd/*.timer; do
    [ -e "$f" ] || continue
    run install -m 600 "$f" "$UNIT_DIR/$(basename "$f")"
    echo "  · $(basename "$f")"
  done
  if [ -d "$B/systemd/mihomo.service.d" ]; then
    run mkdir -p "$UNIT_DIR/mihomo.service.d"
    for f in "$B"/systemd/mihomo.service.d/*.conf; do
      [ -e "$f" ] || continue
      run install -m 600 "$f" "$UNIT_DIR/mihomo.service.d/$(basename "$f")"
    done
    echo "  · mihomo.service.d/ $(ls "$B/systemd/mihomo.service.d" | tr '\n' ' ')"
  fi
else
  echo "  bundle 里没有单元（沿用包自带 mihomo.service）"
fi

echo "══ 7. DNS（TUN 时把 systemd-resolved 指向 mihomo） ══"
TUN_STATE="$(python3 - "$CONF_DIR/config.yaml" <<'PY'
import re, sys
try:
    lines = open(sys.argv[1], encoding='utf-8').read().splitlines()
except OSError:
    print('off'); raise SystemExit
in_tun, val = False, 'off'
for ln in lines:
    if re.match(r'^tun\s*:', ln):
        in_tun = True; continue
    if in_tun:
        if re.match(r'^\S', ln):
            break
        m = re.match(r'^\s+enable\s*:\s*(\S+)', ln)
        if m:
            val = 'on' if m.group(1).lower() == 'true' else 'off'
            break
print(val)
PY
)"
DNS_DIR="$DEST/etc/systemd/resolved.conf.d"
DNS_SRC=""
[ -d "$B/resolved.conf.d" ] && DNS_SRC="$B/resolved.conf.d"
[ -z "$DNS_SRC" ] && [ -d "$HERE/resolved.conf.d" ] && DNS_SRC="$HERE/resolved.conf.d"

if [ "$TUN_STATE" = on ]; then
  echo "  TUN 开着 → 装 resolved drop-in（DNS=198.18.0.2，fake-ip 由代理远端解析）"
  if [ -n "$DNS_SRC" ]; then
    run mkdir -p "$DNS_DIR"
    for f in "$DNS_SRC"/*.conf; do
      [ -e "$f" ] || continue
      run install -m 644 "$f" "$DNS_DIR/$(basename "$f")"
      echo "  · $(basename "$f")"
    done
    if [ "$START" = 1 ] && [ "$SIMULATE" = 0 ]; then
      run systemctl restart systemd-resolved
      run resolvectl flush-caches
      resolvectl status 2>/dev/null | grep -m2 -E 'Current DNS Server|DNS Servers' | sed 's/^/  /'
    fi
  else
    echo "  ⚠ bundle 和仓库里都没有 resolved drop-in，DNS 请手动指到 198.18.0.2"
  fi
else
  echo "  TUN 关着 → 不装（装了会把 DNS 指到没人应答的 198.18.0.2，等于断 DNS）"
  if [ -f "$DNS_DIR/10-dns.conf" ]; then
    run mv "$DNS_DIR/10-dns.conf" "$DNS_DIR/10-dns.conf.disabled"
    echo "  已把之前装过的 10-dns.conf 停用（.disabled）"
  fi
fi

echo "══ 8. 起服务并验收 ══"
if [ "$START" = 1 ] && [ "$SIMULATE" = 0 ]; then
  run systemctl daemon-reload
  run systemctl enable --now mihomo.service
  for t in mihomo-healthcheck.timer mihomo-boot-fix.timer; do
    [ -f "$UNIT_DIR/$t" ] && run systemctl enable --now "$t"
  done
  sleep 2
  echo "  -- 监听端口 --"
  ss -tlnp 2>/dev/null | grep -E '127\.0\.0\.1:7890' || echo "  ⚠ 7890 没在监听：systemctl status mihomo / journalctl -u mihomo -n 50"
  echo "  -- 出网测试（经代理访问 https） --"
  code=$(curl -s -o /dev/null -w '%{http_code}' --proxy http://127.0.0.1:7890 --max-time 10 https://www.youtube.com 2>/dev/null || echo 000)
  [ "$code" = "200" ] && echo "  ✓ https 200（代理可用）" || echo "  ⚠ 返回 $code（注意：纯 http 站点经本机代理返回 502 属正常）"
  echo "  -- TUN 网卡 --"
  ip -br link show meta 2>/dev/null | sed 's/^/  /' || echo "  没有 meta 网卡（tun 关着，或用的是别的名字）"
elif [ "$SIMULATE" = 1 ]; then
  echo "  模拟模式：跳过 daemon-reload / enable / start / 端口与出网验证"
else
  echo "  --no-start：容器已就位，自己 systemctl enable --now mihomo 即可"
fi

cat <<EOF

══ 完成 ══
  · 配置目录 : $CONF_DIR   （config.yaml/api-secret 600，geo 库 644）
  · 备份     : $CONF_DIR.bak.$STAMP （若之前存在）
  · 端口约定 : 127.0.0.1:7890（mixed，HTTP+SOCKS）
  · TUN      : 开 TUN 时全系统流量被接管；防火墙要放行 iifname meta（参考 bundle 内 nftables-mihomo.txt），
               并确认 /dev/net/tun 存在。只想让个别程序走代理就 --tun off。
  · 用法     : 终端里 proxyon / proxyoff（.bashrc）；浏览器用 ~/.local/bin/chrome-optimized.sh
  · 改了配置 : systemctl reload mihomo（ExecReload=kill -HUP）
EOF
