# 供 Hyprland 的 mod+E 键位使用：在 kitty 窗口里打开 yazi
# 关键是「先有一个真正的交互式 bash，再由它启动 yazi」：
#   * yazi 不是会话首进程 → <C-z> 的 suspend 会真的暂停它
#   * yazi 由提示符前的 PROMPT_COMMAND 启动 → 它在自己的进程组里，
#     暂停时只有 yazi 停，bash 会照常打出提示符，可以 fg 回来
# （如果直接 kitty -e yazi，yazi 就是会话首进程，<C-z> 会被 yazi 自己忽略 → 看起来"坏了"）
source ~/.bashrc
# 用用户 .bashrc 里的 y() 包装器启动：退出 yazi 时 shell 的 cwd 会跟着切到 yazi 的目录
PROMPT_COMMAND='y; unset -v PROMPT_COMMAND'
