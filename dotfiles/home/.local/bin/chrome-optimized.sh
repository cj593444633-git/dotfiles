#!/usr/bin/env bash
#
# chrome-optimized.sh — 用优化参数启动 Google Chrome（Wayland + 全屏 + 中文输入法）
# 来源：i7-2640M / Intel HD3000 / Arch / Hyprland。新机器上硬件相关参数可自行精简。
#
# 可移植性处理（导出时加的，和本机现役版本的差异就在这里）：
#   · 没有 mihomo 服务的机器 → 整段代理等待跳过
#   · uBlock 解包目录不存在 → 不加 --load-extension（Chrome 155+ 该参数已失效）
#   · EXT_PATH 用 $HOME，别写死用户名
#
export XMODIFIERS=@im=fcitx
export QT_IM_MODULE=fcitx
export SDL_IM_MODULE=fcitx

# ── 可选：本机代理(mihomo)就绪等待 ──────────────────────────────
# 新机器上没有 mihomo/7890 代理时整段跳过，直接启动 Chrome。
# 原意：笔记本有 systemd-networkd-wait-online + mihomo-healthcheck.timer 兜底，
#       代理死了 youtube/github 就打不开。没有代理的机器不需要这层。
PROXY_URL="${PROXY_URL:-http://127.0.0.1:7890}"
MAX_WAIT="${MAX_WAIT:-40}"
WAITED=0
RESTARTED=false

log() { echo "[chrome-optimized] $*"; }

proxy_ok() {
    local code
    code=$(curl -s --proxy "$PROXY_URL" --connect-timeout 3 --max-time 5 \
        -o /dev/null -w "%{http_code}" "https://www.youtube.com" 2>/dev/null) || code="000"
    [[ "$code" == "200" ]]
}

restart_mihomo() {
    log "重启 mihomo..."
    if sudo -n systemctl restart mihomo 2>/dev/null; then
        log "  mihomo 已重启, 等待就绪..."
        sleep 5
        return 0
    else
        log "  ⚠ sudo 免密未配置, 跳过重启"
        return 1
    fi
}

if systemctl list-unit-files mihomo.service >/dev/null 2>&1 \
   && systemctl list-unit-files mihomo.service 2>/dev/null | grep -q '^mihomo\.service'; then
    log "等待 mihomo 代理就绪 (最多 ${MAX_WAIT}s)..."
    while [[ $WAITED -lt $MAX_WAIT ]]; do
        if ss -tulpn 2>/dev/null | grep -q "127.0.0.1:7890"; then
            if proxy_ok; then
                log "✓ 代理已就绪 (${WAITED}s)"
                break
            elif [[ "$RESTARTED" == false && $WAITED -ge 10 ]]; then
                if restart_mihomo; then
                    RESTARTED=true
                    WAITED=$((WAITED + 5))
                    continue
                fi
            fi
        fi
        sleep 2
        WAITED=$((WAITED + 2))
    done
    if [[ $WAITED -ge $MAX_WAIT ]]; then
        log "⚠ 代理超时未就绪, 强制启动 Chrome (youtube/github 可能不可用)"
    fi
else
    log "没有 mihomo 服务，跳过代理等待"
fi

# ── 启动 Chrome ────────────────────────────────────────────────
# 代理参数**只在代理真的可用时**才加：新机器上没有 mihomo 时若仍传 --proxy-server，
# Chrome 会指向一个没人监听的 127.0.0.1:7890 → 整个浏览器断网（这个坑 2026-11-20 修掉）。
PROXY_ARGS=()
if proxy_ok; then
    PROXY_ARGS=(--proxy-server="$PROXY_URL")
    log "Chrome 走代理 $PROXY_URL"
else
    log "代理不可用（$PROXY_URL），Chrome 直连"
fi

# [本机] EXT_PATH 是本机解包的 uBlock（Chrome 155 起 --load-extension 已被禁用，
#        只有个别版本还能用）。目录不存在就不加这个参数，别让 Chrome 起不来。
EXT_PATH="$HOME/.local/share/chrome-extensions/uBlock-1.72.3rc4"
EXT_ARGS=()
[ -d "$EXT_PATH" ] && EXT_ARGS=(--load-extension="$EXT_PATH")

ARGS=(
  "${PROXY_ARGS[@]}"
  --ozone-platform=wayland
  --enable-wayland-ime
  "${EXT_ARGS[@]}"
  --start-fullscreen
  --process-per-site
  --enable-low-end-device-mode
  --renderer-process-limit=4
  --enable-features=CanvasOopRasterization,ParallelDownloading
  --disable-features=TouchpadOverscrollHistoryNavigation,UseChromeOSDirectVideoDecoder
  --disable-breakpad
  --disable-domain-reliability
  --disable-gcm
  --no-default-browser-check
  --no-pings
)

# 自测用：不真启动浏览器，只把最终命令行打出来
if [ "${1:-}" = "--print-cmd" ]; then
    printf '/usr/bin/google-chrome-stable'; printf ' %q' "${ARGS[@]}"; printf '\n'
    exit 0
fi

/usr/bin/google-chrome-stable "${ARGS[@]}" "$@" 2>/dev/null
