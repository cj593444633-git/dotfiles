#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc

# Created by `pipx` on 2026-07-16 09:43:36
export PATH="$PATH:$HOME/.local/bin:$HOME/security-hardening"

# Added by LM Studio CLI (lms)
export PATH="$PATH:$HOME/.lmstudio/bin"
# End of LM Studio CLI section


# 默认编辑器(本机无 vim, 用 neovim; vim/vi 已做垫片)
export EDITOR=nvim
export VISUAL=nvim
