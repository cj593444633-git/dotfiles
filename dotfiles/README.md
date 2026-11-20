# dotfiles — Arch + Hyprland 桌面（参考机：chen@X220）

这台机器（Arch / Hyprland 0.56.2 / Wayland / ly + uwsm 会话）的**可复现桌面配置**，
目标：新电脑装完 Arch 后两条命令把桌面拉起来，不用凭记忆重配一遍。

```
sudo ./bootstrap.sh --user <新用户名>      # ① 装包、启服务、写 ly 会话（root）
#    想把代理也一起复刻：加 --with-proxy <bundle.tar.gz> [--proxy-tun keep|on|off] [--lan-cidr CIDR]
./install.sh --enable-units                # ② 把 dotfiles 软链进 ~ 并启用用户单元（普通用户）
# 重新登录（不是 hyprctl reload）
```

## 里面有什么

```
home/            装进 ~ 的文件（软链或复制），路径 $HOME 化
  .config/hypr/       hyprland.lua（lua API）+ hypridle.conf
  .config/waybar/     config.jsonc + style.css
  .config/kitty/ .config/mako/ .config/fcitx5/ .config/environment.d/
  .config/systemd/user/   waybar/hypridle/automount 需要的 target drop-in 与单元
  .config/autostart/  nm-tray 的 Hidden=true 覆盖（托盘交给 waybar 原生模块）
  .config/yazi/yazi-window.bash   SUPER+E 用
  .local/bin/         键位和状态栏点进去的脚本（下载、旋转、wifi、电源、sudo 窗口…）
  .bashrc .bash_profile .profile
packages/        桌面必需包（全官方仓库）/ AUR（可选）/ 参考机全量清单
system/          /etc 侧：ly 配置写入脚本、PAM ly-autologin、参考机 config.ini 快照
proxy/           mihomo 代理：export-from-live.sh（打包）/ install-mihomo.sh（新机安装）
                 / resolved.conf.d/10-dns.conf（TUN 模式的 DNS drop-in）
tools/           sync-from-live.sh —— 从现役机器重新导出
docs/            新机安装手册 / 快捷键速查 / 踩坑记录
install.sh       用户级安装器（软链默认 / --copy / --dry-run / --list / --enable-units）
bootstrap.sh     root 级：包 + 服务 + 会话
```

## 与现役机器的差异（导出时故意改的四处）

| 项 | 现役机器 | 仓库版 | 原因 |
|---|---|---|---|
| `SUPER + V` | 同时绑「切换浮动」和「剪贴板历史」，只有一个生效 | 剪贴板改 `SUPER + SHIFT + V` | 同键重复绑定不报错，纯 bug |
| gocryptfs 加密盘挂载（hyprland.start 钩子）| 开着 | 注释掉 | 依赖 `/etc/gocryptfs.key` 和已存在的 cipher 目录 |
| chrome-optimized.sh | 死等 mihomo、无条件加 `--proxy-server`、写死 uBlock 解包路径 | 没有 mihomo/代理不可用就**跳过等待且不传 --proxy-server**（直连），uBlock 目录不存在也不加参数 | 新机器不一定有代理：把浏览器指到死端口等于让 Chrome 彻底断网 |
| 路径 | `/home/chen/...` | `$HOME/...` | Hyprland `exec_cmd` 与 waybar `on-click` 都过 `sh -c`，已实测会展开 |

其余保持与现役一致：包的版本取向（官方 `waybar` 0.15.0 = 现役 `waybar-git` 同版本）、
模糊/阴影关闭（X220 核显优化）、`LIBVA_DRIVER_NAME=i965`、`epic-mouse-v1` 灵敏度、
LVDS-1/HDMI-A-1/VGA-1 旋转键位与钉屏规则 —— 这些文件里都用 `[本机]` 标注了，新机器按需删改。

## 同步 / 更新流程

参考机上改了现役配置之后：

```bash
./tools/sync-from-live.sh     # 把 27 个文件重新导出到 home/（$HOME 化）
git diff                      # 审阅：本机特有段落有没有被导出覆盖掉（导出是"照抄现役"）
git commit -am "sync: 说明改了什么"
```

注意 sync 会**覆盖**仓库里那四处"故意改过"的地方 —— 要么平时直接改仓库再 `./install.sh` 装回现役机器，
要么导出后手动补回。

## 不在这个仓库里的

浏览器 profile、SSH/GPG 密钥、nginx/aria2 的服务端配置、Android SDK、Kodi、DSH/Hermes、
以及 `~/security-hardening` 那套加固脚本 —— 它们跟"桌面能不能起来"无关，且含机器/账户相关的状态。
代理（mihomo）的配置同样不进 git（含订阅/节点），但 `proxy/` 下有一套"现场导出 bundle →
新机一条命令安装"的流程，见手册阶段 4b。
清单与理由见 `docs/新机安装手册.md` 最后一节。

细节手册：`docs/新机安装手册.md`｜快捷键：`docs/keybinds.md`｜坑：`docs/踩坑记录.md`

## 交付物（离线/手机看）

`~/Downloads/hyprland-dotfiles/` 里有从本仓库派生的三份文件（2026-11-20 导出）：

- `Hyprland-Dotfiles-手册.pdf` —— A4、13 页，中文已嵌入字体
- `Hyprland-Dotfiles-手册.md` —— 合并版源文件（README + 手册 + 踩坑 + 快捷键）
- `Hyprland-Dotfiles-手册.txt` —— 纯文本，手机 grep/贴聊天用

重新生成：改完 `README.md` / `docs/*.md` 后按 `doc-export` skill 的步骤（pandoc → HTML → Chrome headless → pdf）。
