#!/usr/bin/env bash
# waybar-ws-switch.sh — 切换到指定 Hyprland 工作区
# 用法: waybar-ws-switch.sh <workspace_id>
# 适配 Hyprland 0.55+ 的 Lua dispatch API (hl.dsp.focus)
ws="${1:?需要工作区 ID}"
exec hyprctl dispatch "hl.dsp.focus({ workspace = ${ws} })"
