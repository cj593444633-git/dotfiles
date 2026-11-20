-- ============================================================================
--  Hyprland 配置（Lua API，0.56.2 实测）
--  来源：chen@X220 / Arch Linux / Intel HD3000。导出时 /home/chen 已替换为 $HOME
--        （Hyprland 的 exec_cmd 走 sh -c，$HOME 会展开 —— 已实证）。
--  [本机] 标记的段落绑定这台机器的硬件/服务，新机器上按需删改：
--        · gocryptfs 加密盘挂载（需要 /etc/gocryptfs.key）
--        · epic-mouse-v1 设备项（鼠标型号）
--        · LVDS-1 / HDMI-A-1 / VGA-1 旋转键位与窗口钉屏规则
--        · LIBVA_DRIVER_NAME=i965（Sandy Bridge 核显专用）
--        · 末端「性能优化」段（关模糊/阴影/图层动画）—— 新机器性能足够可删
-- ============================================================================
hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("mako")
    -- 2026-09-23: ly 用 start-hyprland(非 uwsm)启会话, 没有东西以"依赖"方式拉起
    -- graphical-session.target / xdg-desktop-autostart.target ⇒ waybar、hypridle、
    -- hyprpolkitagent、udisks-automount、fcitx5、blueman-applet 全都不启动。
    -- 该脚本把它们拉起来(uwsm 会话里自动跳过)。缘由/坑见脚本头注释。
    hl.exec_cmd("$HOME/.local/bin/session-targets-up.sh")
end)
local terminal    = "kitty"
local fileManager = "thunar"
local menu        = "hyprlauncher"
 hl.on("hyprland.start", function () 
-- hl.exec_cmd("hyprpaper")
-- hl.exec_cmd("$HOME/.local/bin/chrome-optimized.sh")
 -- [本机] gocryptfs 加密盘：需要 /etc/gocryptfs.key（600）和已挂载的 cipher 目录。
 -- 新机器上没有这套东西时**必须删掉/注释**，否则每次登录都会起一个失败的后台进程。
 -- hl.exec_cmd("sleep 2 && gocryptfs -allow_other -extpass 'cat /etc/gocryptfs.key' /srv/nfs/media/cipher $HOME/plain")
 hl.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 1")  -- 2026-09-23 审计: 内置麦克风默认静音(需用时 Fn+F4 或 wpctl 切换)
-- hl.exec_cmd("$HOME/code/dsh_manager/dsh_tray > /tmp/dsh_tray.log 2>&1")
-- hypridle 由 systemd user 服务托管(hypridle.service)
 end)
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_IM_MODULE", "fcitx")
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("SDL_IM_MODULE", "fcitx")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("GLFW_IM_MODULE", "ibus")
-- HD 3000(Sandy Bridge)不支持新的 iHD VA-API 驱动,不设这个的话每个 libva 应用
-- (kodi/marktext/mpv...)启动都会先加载 iHD_drv_video.so 失败刷一条 error 再回退 i965。
-- [本机] Sandy Bridge(HD 3000)专用；新机器是较新的 Intel 就删掉这行（或改成 iHD）
hl.env("LIBVA_DRIVER_NAME", "i965")
 hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
 hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
 hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })
hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })
 hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
 hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
 hl.window_rule({
     name  = "no-gaps-wtv1",
     match = { float = false, workspace = "w[tv1]" },
     border_size = 0,
     rounding    = 0,
 })
 hl.window_rule({
     name  = "no-gaps-f1",
     match = { float = false, workspace = "f[1]" },
     border_size = 0,
     rounding    = 0,
 })
hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})
-- [本机] 鼠标型号 + 灵敏度（新机器用 `hyprctl devices` 查自己的名字）
hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})
local mainMod = "SUPER" -- Sets "Windows" key as main modifier
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("blueman-manager"), { description = "蓝牙管理 (Bluetooth Manager)" })
hl.bind(mainMod .. " + F11", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd("$HOME/.local/bin/hermes desktop"), { description = "启动 Hermes Desktop" })
local closeWindowBind = hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("kitty -d ~ -e bash --rcfile $HOME/.config/yazi/yazi-window.bash"), { description = "Yazi 文件管理器 (kitty)" })
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd(fileManager), { description = "文件管理器 (thunar)" })
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))    -- dwindle only
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd("firefox"))
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("$HOME/.local/bin/chrome-optimized.sh"))
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.exec_cmd("$HOME/.local/bin/dsh_tray > /tmp/dsh_tray.log 2>&1"), { description = "呼出/收起 DSH 控制面板 (DSH manager)" })
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"), { description = "锁屏 (Lock screen)" })
-- 剪贴板历史。注意：现役版本这里写的是 "SUPER + V"，与上面「切换浮动」同一个键位
-- （Hyprland 不报错，两个绑定同时存在，实际只有一个生效 —— 踩坑记录里有截图级说明）。
-- 仓库版改成 SUPER+SHIFT+V，明确分开。
hl.bind("SUPER + SHIFT + V", hl.dsp.exec_cmd("cliphist list | wofi --dmenu -p 剪贴板 | cliphist decode | wl-copy"), { description = "打开剪贴板历史" })
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("brightnessctl -e4 set 0"), { description = "Turn screen off (backlight)" })
hl.bind(mainMod .. " + SHIFT + Escape", hl.dsp.exec_cmd("brightnessctl -e4 set 100%"), { description = "Turn screen on (backlight) " })
-- [本机] 屏幕旋转键位：LVDS-1=笔记本内屏, HDMI-A-1=外接42寸, VGA-1=老投影。
-- 新机器先用 `hyprctl monitors -j | grep name` 看自己的输出名，再改这三组。
hl.bind("CTRL + ALT + 0", hl.dsp.exec_cmd("$HOME/.local/bin/rotate-hyprland.sh LVDS-1 0"), { description = "旋转屏幕 0° (正常)" })
hl.bind("CTRL + ALT + 1", hl.dsp.exec_cmd("$HOME/.local/bin/rotate-hyprland.sh LVDS-1 90"), { description = "旋转屏幕 90°" })
hl.bind("CTRL + ALT + 2", hl.dsp.exec_cmd("$HOME/.local/bin/rotate-hyprland.sh LVDS-1 180"), { description = "旋转屏幕 180°" })
hl.bind("CTRL + ALT + 3", hl.dsp.exec_cmd("$HOME/.local/bin/rotate-hyprland.sh LVDS-1 270"), { description = "旋转屏幕 270°" })
hl.bind("CTRL + ALT + SHIFT + 0", hl.dsp.exec_cmd("$HOME/.local/bin/rotate-hyprland.sh  HDMI-A-1 0"), { description = "DP-1 旋转 0° (正常)" })
hl.bind("CTRL + ALT + SHIFT + 1", hl.dsp.exec_cmd("$HOME/.local/bin/rotate-hyprland.sh HDMI-A-1 90"), { description = "DP-1 旋转 90°" })
hl.bind("CTRL + ALT + SHIFT + 2", hl.dsp.exec_cmd("$HOME/.local/bin/rotate-hyprland.sh HDMI-A-1 180"), { description = "DP-1 旋转 180°" })
hl.bind("CTRL + ALT + SHIFT + 3", hl.dsp.exec_cmd("$HOME/.local/bin/rotate-hyprland.sh HDMI-A-1 270"), { description = "DP-1 旋转 270°" })
hl.bind("CTRL + SUPER + 0", hl.dsp.exec_cmd("$HOME/.local/bin/rotate-hyprland.sh VGA-1 0"), { description = "VGA-1 旋转 0° (正常)" })
hl.bind("CTRL + SUPER + 1", hl.dsp.exec_cmd("$HOME/.local/bin/rotate-hyprland.sh VGA-1 90"), { description = "VGA-1 旋转 90°" })
hl.bind("CTRL + SUPER + 2", hl.dsp.exec_cmd("$HOME/.local/bin/rotate-hyprland.sh VGA-1 180"), { description = "VGA-1 旋转 180°" })
hl.bind("CTRL + SUPER + 3", hl.dsp.exec_cmd("$HOME/.local/bin/rotate-hyprland.sh VGA-1 270"), { description = "VGA-1 旋转 270°" })
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind("mouse:274", hl.dsp.window.close(),  { mouse = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
local suppressMaximizeRule = hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move  = "20 monitor_h-120",
    float = true,
})
-- 注意: lua 窗口规则没有 fullscreen 字段, 必须用 fullscreen_state 表
-- (internal/client: 2=全屏, 3=全屏覆盖, 1=最大化, 0=无)
hl.window_rule({
    name  = "chrome-fullscreen",
    match = { class = "google-chrome" },
    fullscreen_state = "2 2",
})
-- 模拟器主窗口: 钉到外接屏(2026-09-27 三次调整后回到"tile 铺满")。
-- 踩坑记录:
--   * fullscreen_state = "2 2"(字符串) 从未生效 —— lua 里要写成表 { 2, 2 }, 且窗口一旦
--     被 windowrule 设了 float/size, fullscreen 会被规则反复抢回。
--   * 强行把窗口改窄(590x1048)会让模拟器只把画面画在左上角一小块, 还留白。
--   * 画面侧躺/正立取决于"客机 display 方向 vs 窗口方向"是否一致:
--     config.ini 基座 = portrait(720x1280) 时, 河马剧场这类 APP 反而按横屏布局渲染(1280x720),
--     与 16:9 的 42 寸屏一致 ⇒ tile 铺满时内容是正立铺满的。
--   * 模拟器自带的侧边工具栏是独立窗口(同 class Emulator, title 就叫 "Emulator"),
--     不要试图 kill 它 —— 那会退出整个模拟器 UI。
hl.window_rule({
    name  = "emulator-screen",
    match = { class = "Emulator" },
    monitor = "HDMI-A-1",
})
-- 浏览器(Firefox)启动即全屏
hl.window_rule({
    name  = "firefox-fullscreen",
    match = { class = "firefox" },
    fullscreen_state = "2 2",
})
-- Kodi: 钉到外接那块屏(42 寸)。Kodi 自己在 Wayland 下就是全屏窗口(xdg_toplevel fullscreen),
-- 不需要再给 fullscreen_state; 屏不在(只插内屏)时 Hyprland 会忽略 monitor 项, 就在当前屏开。
hl.window_rule({
    name  = "kodi-screen",
    match = { class = "Kodi" },
    monitor = "HDMI-A-1",
})

-- ===== 性能优化(2026-09-14):X220 / HD 3000 核显降低渲染开销 =====
-- 关闭模糊与阴影:显存与像素填充压力最大的两项
hl.config({
    decoration = {
        blur   = { enabled = false },
        shadow = { enabled = false },
    },
})

-- 精简次要动画:保留窗口开关/淡入淡出,关闭图层与工作区等动画
hl.animation({ leaf = "layers",        enabled = false, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = false, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = false, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = false, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = false, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = false, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = false, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = false, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "border",        enabled = false, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "zoomFactor",    enabled = false, speed = 7,    bezier = "quick" })
-- 如需恢复:把上面的 enabled 改回 true,并删掉 blur/shadow 段
