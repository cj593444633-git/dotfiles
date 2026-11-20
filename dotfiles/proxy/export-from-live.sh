#!/usr/bin/env bash
# export-from-live.sh —— 把本机的 mihomo（代理）配置打包成可搬走的 bundle（root）
#
#   sudo ./proxy/export-from-live.sh                       # → ~/Downloads/mihomo-bundle-<日期>.tar.gz
#   sudo ./proxy/export-from-live.sh --out /tmp/x.tgz
#
# 打进去的东西（都是新机复现"一模一样的代理"所必需的）：
#   etc-mihomo/          config.yaml、api-secret、Country.mmdb、geoip.metadb、GeoSite.dat …
#                        （不含 cache.db 与 *.bak*）
#   systemd/             mihomo.service 的 drop-in、mihomo-healthcheck / boot-fix 的 service+timer
#   dns-info.txt         /etc/resolv.conf 与 systemd-resolved 的 drop-in（TUN/fake-ip 时 DNS 走这里）
#   nftables-mihomo.txt  `nft list table inet mihomo`（防火墙放行规则参考，TUN 需要）
#   pkg.txt / config-test.txt / MANIFEST.txt
#
# bundle 里**有订阅地址和节点密码**：文件权限 600、只给调用 sudo 的那个用户，
# 不要提交进 git（仓库 .gitignore 已挡 mihomo-bundle*）。
set -euo pipefail

OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数: $1" >&2; exit 2 ;;
  esac
done

[ "$(id -u)" = 0 ] || { echo "要 root: sudo $0" >&2; exit 1; }
OWNER="${SUDO_USER:-root}"
OWNER_HOME="$(getent passwd "$OWNER" | cut -d: -f6)"
: "${OWNER_HOME:=/root}"
[ -n "$OUT" ] || OUT="$OWNER_HOME/Downloads/mihomo-bundle-$(date +%Y%m%d).tar.gz"

[ -f /etc/mihomo/config.yaml ] || { echo "没有 /etc/mihomo/config.yaml —— 本机没装 mihomo？" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
B="$TMP/bundle"
mkdir -p "$B/etc-mihomo" "$B/systemd"

echo "══ 1. 配置目录 /etc/mihomo ══"
# cache.db 是运行期缓存；*.bak* 是历史备份 —— 都不带走
tar -C /etc/mihomo -cf - \
    --exclude='cache.db' --exclude='*.bak*' --exclude='*.log' . \
  | tar -C "$B/etc-mihomo" -xf -
du -sh "$B/etc-mihomo" | sed 's/^/  /'
ls "$B/etc-mihomo" | sed 's/^/  · /'

echo "══ 2. systemd 单元与 drop-in ══"
for f in /etc/systemd/system/mihomo*.service /etc/systemd/system/mihomo*.timer; do
  [ -e "$f" ] && cp -a "$f" "$B/systemd/" && echo "  · $(basename "$f")"
done
if [ -d /etc/systemd/system/mihomo.service.d ]; then
  mkdir -p "$B/systemd/mihomo.service.d"
  cp -a /etc/systemd/system/mihomo.service.d/. "$B/systemd/mihomo.service.d/"
  echo "  · mihomo.service.d/ $(ls /etc/systemd/system/mihomo.service.d | tr '\n' ' ')"
fi

# TUN 模式下 DNS 交给 mihomo（198.18.0.2），drop-in 一起带走
if [ -d /etc/systemd/resolved.conf.d ]; then
  mkdir -p "$B/resolved.conf.d"
  cp -a /etc/systemd/resolved.conf.d/. "$B/resolved.conf.d/" 2>/dev/null || true
  echo "  · resolved.conf.d/ $(ls /etc/systemd/resolved.conf.d 2>/dev/null | tr '\n' ' ')"
fi

echo "══ 3. DNS 现状（TUN/fake-ip 时靠它） ══"
{
  echo "### ls -l /etc/resolv.conf"
  ls -l /etc/resolv.conf 2>&1
  echo
  echo "### cat /etc/resolv.conf"
  cat /etc/resolv.conf 2>&1
  echo
  echo "### systemd-resolved drop-in"
  for f in /etc/systemd/resolved.conf.d/*.conf /etc/systemd/resolved.conf; do
    [ -f "$f" ] || continue
    echo "--- $f"
    cat "$f"
    echo
  done
  echo "### resolvectl status（摘要）"
  resolvectl status 2>&1 | sed -n '1,25p'
} > "$B/dns-info.txt"
echo "  → dns-info.txt ($(wc -l < "$B/dns-info.txt") 行)"

echo "══ 4. 防火墙（TUN 需要放行 iifname meta） ══"
if command -v nft >/dev/null; then
  nft list table inet mihomo > "$B/nftables-mihomo.txt" 2>/dev/null \
    || echo "（没有 inet mihomo 表 —— 本机防火墙可能不拦 TUN 流量）" > "$B/nftables-mihomo.txt"
  grep -c 'meta' "$B/nftables-mihomo.txt" 2>/dev/null | sed 's/^/  表里提到 meta 的行数: /' || true
fi

echo "══ 5. 包版本与配置自检 ══"
pacman -Q mihomo-bin > "$B/pkg.txt" 2>/dev/null || echo "mihomo-bin 不在 pacman 数据库里" > "$B/pkg.txt"
cat "$B/pkg.txt" | sed 's/^/  /'
if mihomo -t -d /etc/mihomo > "$B/config-test.txt" 2>&1; then
  echo "  ✓ 配置自检通过（mihomo -t）"
else
  echo "  ⚠ 配置自检失败 —— 详见 bundle 内 config-test.txt（照样打包，新机上先修）"
fi

{
  echo "# mihomo bundle"
  echo "date      : $(date '+%F %T %Z')"
  echo "host      : $(hostname)"
  echo "mihomo    : $(mihomo -v 2>&1 | head -1)"
  echo "pkg       : $(cat "$B/pkg.txt")"
  echo "bundle    : 含订阅与节点凭据，勿入 git"
  echo "源机 TUN  : $(grep -A3 '^tun:' /etc/mihomo/config.yaml 2>/dev/null | head -5 | tr '\n' ' ')"
  echo "源机端口  : $(ss -tlnp 2>/dev/null | awk '/mihomo|mihomo/{print $4}' | sort -u | tr '\n' ' ')"
} > "$B/MANIFEST.txt"

echo "══ 6. 打包 ══"
mkdir -p "$(dirname "$OUT")"
tar -C "$TMP" -czf "$OUT" bundle
chown "$OWNER":"$(id -gn "$OWNER")" "$OUT" 2>/dev/null || true
chmod 600 "$OUT"
echo "  ✓ $OUT ($(du -h "$OUT" | cut -f1))  属主 $OWNER 权限 600"
echo
echo "新机上：sudo ./proxy/install-mihomo.sh --bundle $OUT"
