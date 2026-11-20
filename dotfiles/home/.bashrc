#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '



# ── mihomo 终端代理开关 (127.0.0.1:7890) ──
# 用法: proxyon / proxyoff
proxyon() {
    export http_proxy=http://127.0.0.1:7890
    export https_proxy=http://127.0.0.1:7890
    export all_proxy=socks5://127.0.0.1:7890
    export HTTP_PROXY=http://127.0.0.1:7890
    export HTTPS_PROXY=http://127.0.0.1:7890
    export ALL_PROXY=socks5://127.0.0.1:7890
    export NO_PROXY=localhost,127.0.0.1,::1,192.168.2.0/24,.local
    export no_proxy="$NO_PROXY"
    echo '终端代理已开启 (http/socks5://127.0.0.1:7890)'
}

proxyoff() {
    unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY no_proxy
    echo '终端代理已关闭'
}

# Fcitx5 输入法配置

#export GTK_IM_MODULE=fcitx

export QT_IM_MODULE=fcitx

export XMODIFIERS=@im=fcitx

# Created by `pipx` on 2026-07-16 09:43:36
export PATH="$PATH:$HOME/.local/bin:$HOME/plain/security-hardening"
export QT_QPA_PLATFORM=wayland
#export HTTP_PROXY=http://127.0.0.1:7890
#export HTTPS_PROXY=http://127.0.0.1:7890
#export http_proxy=http://127.0.0.1:7890
#export https_proxy=http://127.0.0.1:7890
#export NO_PROXY=localhost,127.0.0.1,::1,192.168.2.0/24,.local
export PATH="$HOME/.lmstudio/bin:$PATH"

# Added by LM Studio CLI (lms)
export PATH="$PATH:$HOME/.lmstudio/bin"
# End of LM Studio CLI section


# D-Bus 会话总线补全 (SSH/非登录 shell 缺少时按需设置)
if [ -z "$XDG_RUNTIME_DIR" ] && [ -d "/run/user/$(id -u)" ]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ] && [ -S "${XDG_RUNTIME_DIR}/bus" ]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
fi

# codewhale / codewhale-tui shell 补全
if [ -f "$HOME/.local/share/bash-completion/completions/codewhale" ]; then
    . "$HOME/.local/share/bash-completion/completions/codewhale"
fi
if [ -f "$HOME/.local/share/bash-completion/completions/codewhale-tui" ]; then
    . "$HOME/.local/share/bash-completion/completions/codewhale-tui"
fi

# vnote-bin 仅捆绑 xcb 平台插件（无 wayland 插件），强制用 xcb 经 Xwayland 运行
vnote() {
    QT_QPA_PLATFORM=xcb command vnote "$@"
}
export PATH=~/.npm-global/bin:$PATH

export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end

# ---- Yazi: 退出时把工作目录带回 shell(用法: y [目录]) ----
function y() {
	local tmp cwd
	tmp="$(mktemp -t yazi-cwd.XXXXXX)" || return 1
	command yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd" || builtin true
	command rm -f -- "$tmp"
}

# ---- zoxide(智能 cd,配合 yazi 使用) ----
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"

# 默认编辑器(本机无 vim, 用 neovim; vim/vi 已做垫片)
export EDITOR=nvim
export VISUAL=nvim

# ---- Android / Qt for Android 开发环境(见 ~/.config/environment.d/android.conf) ----
# Android SDK(cmdline-tools + platform-tools + build-tools;34.0.0 + platforms;android-34)
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
# NDK r26b —— Qt 6.7.x 官方要求的版本
export ANDROID_NDK_ROOT="$ANDROID_HOME/ndk/26.1.10909125"
export ANDROID_NDK_HOME="$ANDROID_NDK_ROOT"
# Qt for Android(GUI 会话里由 environment.d 提供, 这里给 CLI 构建用)
export QT_ANDROID="$HOME/Qt/6.7.3/android_arm64_v8a"
export QT_HOST_PATH="$HOME/Qt/6.7.3/gcc_64"
# AGP 7.4.1 的 lint 在 JDK 17 上会崩(JvmWideVariable),本机默认 java 26 更不行,所以固定到 21
export JAVA_HOME="/usr/lib/jvm/java-21-openjdk"
for _p in "$ANDROID_HOME/platform-tools" "$ANDROID_HOME/cmdline-tools/latest/bin" "$JAVA_HOME/bin"; do
	case ":$PATH:" in *":$_p:"*) ;; *) export PATH="$_p:$PATH" ;; esac
done
unset _p

# ── Gemini API 密钥 (Gemini CLI / google-genai SDK / 本机脚本) ──
# 密钥文件 600,内容形如 GEMINI_API_KEY=...;由 ~/security-hardening/gemini-cli-setup.sh 写入
if [ -f "$HOME/.config/gemini.env" ]; then
	set -a
	. "$HOME/.config/gemini.env"
	set +a
fi

# GUI 会话里由 ~/.config/hypr/hyprland.lua 的 hl.env 设置;这里只管终端启动的程序
export LIBVA_DRIVER_NAME=i965
