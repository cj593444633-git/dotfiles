# Hyprland Dotfiles 手册（Arch Linux，参考机 X220）

> 源仓库：`~/dotfiles`　｜　导出时间：2026-11-20
> 
> 本文件由 `dotfiles/README.md` 与 `docs/` 下三份文档合并派生；改内容请改 md 源再重新导出。

## 第 1 部分　仓库说明（README）

这台机器（Arch / Hyprland 0.56.2 / Wayland / ly + uwsm 会话）的**可复现桌面配置**，
目标：新电脑装完 Arch 后两条命令把桌面拉起来，不用凭记忆重配一遍。

```
sudo ./bootstrap.sh --user <新用户名>      # ① 装包、启服务、写 ly 会话（root）
#    想把代理也一起复刻：加 --with-proxy <bundle.tar.gz> [--proxy-tun keep|on|off] [--lan-cidr CIDR]
./install.sh --enable-units                # ② 把 dotfiles 软链进 ~ 并启用用户单元（普通用户）
# 重新登录（不是 hyprctl reload）
```

### 里面有什么

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

### 与现役机器的差异（导出时故意改的四处）

| 项 | 现役机器 | 仓库版 | 原因 |
|---|---|---|---|
| `SUPER + V` | 同时绑「切换浮动」和「剪贴板历史」，只有一个生效 | 剪贴板改 `SUPER + SHIFT + V` | 同键重复绑定不报错，纯 bug |
| gocryptfs 加密盘挂载（hyprland.start 钩子）| 开着 | 注释掉 | 依赖 `/etc/gocryptfs.key` 和已存在的 cipher 目录 |
| chrome-optimized.sh | 死等 mihomo、无条件加 `--proxy-server`、写死 uBlock 解包路径 | 没有 mihomo/代理不可用就**跳过等待且不传 --proxy-server**（直连），uBlock 目录不存在也不加参数 | 新机器不一定有代理：把浏览器指到死端口等于让 Chrome 彻底断网 |
| 路径 | `/home/chen/...` | `$HOME/...` | Hyprland `exec_cmd` 与 waybar `on-click` 都过 `sh -c`，已实测会展开 |

其余保持与现役一致：包的版本取向（官方 `waybar` 0.15.0 = 现役 `waybar-git` 同版本）、
模糊/阴影关闭（X220 核显优化）、`LIBVA_DRIVER_NAME=i965`、`epic-mouse-v1` 灵敏度、
LVDS-1/HDMI-A-1/VGA-1 旋转键位与钉屏规则 —— 这些文件里都用 `[本机]` 标注了，新机器按需删改。

### 同步 / 更新流程

参考机上改了现役配置之后：

```bash
./tools/sync-from-live.sh     # 把 27 个文件重新导出到 home/（$HOME 化）
git diff                      # 审阅：本机特有段落有没有被导出覆盖掉（导出是"照抄现役"）
git commit -am "sync: 说明改了什么"
```

注意 sync 会**覆盖**仓库里那四处"故意改过"的地方 —— 要么平时直接改仓库再 `./install.sh` 装回现役机器，
要么导出后手动补回。

### 不在这个仓库里的

浏览器 profile、SSH/GPG 密钥、nginx/aria2 的服务端配置、Android SDK、Kodi、DSH/Hermes、
以及 `~/security-hardening` 那套加固脚本 —— 它们跟"桌面能不能起来"无关，且含机器/账户相关的状态。
代理（mihomo）的配置同样不进 git（含订阅/节点），但 `proxy/` 下有一套"现场导出 bundle →
新机一条命令安装"的流程，见手册阶段 4b。
清单与理由见 `docs/新机安装手册.md` 最后一节。

细节手册：`docs/新机安装手册.md`｜快捷键：`docs/keybinds.md`｜坑：`docs/踩坑记录.md`

### 交付物（离线/手机看）

`~/Downloads/hyprland-dotfiles/` 里有从本仓库派生的三份文件（2026-11-20 导出）：

- `Hyprland-Dotfiles-手册.pdf` —— A4、13 页，中文已嵌入字体
- `Hyprland-Dotfiles-手册.md` —— 合并版源文件（README + 手册 + 踩坑 + 快捷键）
- `Hyprland-Dotfiles-手册.txt` —— 纯文本，手机 grep/贴聊天用

重新生成：改完 `README.md` / `docs/*.md` 后按 `doc-export` skill 的步骤（pandoc → HTML → Chrome headless → pdf）。

## 第 2 部分　新机安装手册

参考机：Intel i7-2640M / HD 3000 / X220，Arch Linux，Hyprland **0.56.2**（lua 配置 API），
Wayland 会话由 **ly + uwsm** 托管，状态栏 waybar 0.15.0，输入法 fcitx5。

本手册分五阶段：从装介质到"桌面能用"，每一步都给可复制的命令和**期望输出**。
不想看细节就直接跳到 [阶段 3](#阶段-3两条命令装桌面)；装到一半出问题看
[docs/踩坑记录.md](踩坑记录.md)。

---

### 阶段 0：装 base 系统（如果已经装好 Arch，跳到阶段 1）

参考机是 LVM + btrfs（`/` = subvol `@`，`/home` 独立 subvol，`/boot` = ESP）。
新机不必照抄，但**下面几处配置和桌面直接相关**：

```bash
# 1) 起网络（有线最省事）
ip link                      # 找到网卡名
systemctl start systemd-networkd systemd-resolved   # 或 iwctl 连 WiFi
ping -c1 archlinux.org

# 2) 分区时至少留
#    · ESP 1G（vfat，挂 /boot）
#    · swap（LVM 时留 swap LV，或 zram 也可以）
#    · /（btrfs/xfs/ext4 都行；btrfs 记得子卷，参考机：@ 挂 /、@home 挂 /home）

# 3) 挂载 + pacstrap
mount /dev/<root> /mnt
mount /dev/<esp> /mnt/boot
pacstrap -K /mnt base base-devel linux linux-firmware \
  btrfs-progs lvm2 networkmanager vim sudo zsh bash-completion man-db

# 4) 生成 fstab、chroot
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt

# 5) 基础配置
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && hwclock --systohc
sed -i 's/^#\(zh_CN.UTF-8\|en_US.UTF-8\)/\1/' /etc/locale.gen && locale-gen
echo 'LANG=zh_CN.UTF-8' > /etc/locale.conf
echo '<主机名>' > /etc/hostname
passwd                                       # root 密码

# 6) 建用户（组很关键：video/audio/seat/input/render 决定能不能调亮度、用音频、读设备）
useradd -m -G wheel,video,audio,seat,input,render -s /bin/bash <用户名>
passwd <用户名>
EDITOR=vim visudo                            # 取消 %wheel ALL=(ALL:ALL) ALL 的注释

# 7) 装引导（UEFI：bootctl；BIOS：grub 或 syslinux）
bootctl --path=/boot install
# 内核参数（UEFI 用 systemd-boot 时写 /boot/loader/entries/*.conf）：
#   root=/dev/mapper/<vg>-root rootflags=subvol=@  rw nowatchdog
# 参考机 /boot 是 ESP 且挂载参数 dmask=0077 —— 非 root 用户 ls /boot 显示为空是正常的

# 8) 首次启动
exit && umount -R /mnt && reboot
```

---

### 阶段 1：把仓库拿到新机

三种拿法，任选其一：

| 方式 | 怎么做 |
|---|---|
| **U 盘交付包（已做好，推荐）** | 插 U 盘 → `cd /run/media/$USER/Ventoy/arch-hyprland-newmachine` → `bash 01-一键安装.sh --self-test` → `sudo bash 01-一键安装.sh --user <用户名>`。该目录里同时带了 `dotfiles/`、mihomo bundle、手册，说明见其中的 `00-安装说明.txt`；校验用 `sha256sum -c SHA256SUMS`（51 个文件）|
| git clone | `git clone <仓库地址> ~/dotfiles` |
| scp / rsync | `scp -r 旧机:/home/chen/dotfiles ~/` 或 `rsync -a 旧机:dotfiles/ ~/dotfiles/` |

> **exfat/U 盘不保留执行位**（`-rwxr-xr-x` 会变成 `-rw-r--r--`），所以从 U 盘跑脚本一律：
> `bash 01-一键安装.sh …`。一键脚本第一步就会给所有 `*.sh` 和 `~/.local/bin/*` 补回 `+x`。

```bash
cd ~/dotfiles   # 或 U 盘目录
ls packages/desktop.txt system/apply-ly-config.sh install.sh bootstrap.sh proxy/install-mihomo.sh
```

---

### 阶段 2：装包 + 服务 + 登录会话（root）

```bash
sudo ./bootstrap.sh --user <用户名> --dry-run    # 先看一眼要做什么
sudo ./bootstrap.sh --user <用户名>              # 真装
# 想免密自动登录（参考机就是）：加 --autologin
```

它做的事，逐条都能对上：

| 步骤 | 实际命令 | 期望 |
|---|---|---|
| 装桌面包 | `pacman -S --needed $(awk '{sub(/#.*/,""); for(i=1;i<=NF;i++) print $i}' packages/desktop.txt)` | 57 个包、无 error；`pacman -Q hyprland waybar kitty` 有输出 |
| 关掉 networkd | `systemctl disable --now systemd-networkd`（只在它 enabled 时）| 避免与 NetworkManager 抢接口 |
| 网络 | `systemctl enable --now NetworkManager` | `nmcli general status` → `connected` |
| 蓝牙 | `systemctl enable --now bluetooth` | 有硬件时 `bluetoothctl show` 有 Controller |
| 显示管理器 | `systemctl enable ly@tty1` | `systemctl is-enabled ly@tty1` → enabled |
| ly 会话 | `system/apply-ly-config.sh` → `auto_login_session = hyprland-uwsm` | `grep auto_login_session /etc/ly/config.ini` |
| 用户组 | `usermod -aG video,audio,seat,input,render` | `id` 里有这些组 |

**为什么必须是 `hyprland-uwsm`**：waybar / hypridle / hyprpolkitagent / udisks-automount 都挂在
`graphical-session.target` 上，fcitx5 / blueman-applet 走 `xdg-desktop-autostart.target`，
这两个 target 被 systemd 设成 `RefuseManualStart=yes`，只有 uwsm 的
`wayland-session@hyprland.desktop.target` 能以依赖方式拉起它们。
写成 `hyprland`（= `/usr/bin/start-hyprland`）就会出现"没状态栏、没输入法、不锁屏"。
详见 [踩坑记录 第 1 条](踩坑记录.md#1-状态栏--输入法--托盘整片不启动--会话没被-uwsm-托管)。

---

### 阶段 3：两条命令装桌面（普通用户）

```bash
cd ~/dotfiles
./install.sh --list              # 先看清单：27 个文件、目标路径、哪些会被备份
./install.sh --enable-units      # 软链进 ~ + 启用 waybar/hypridle/automount/polkit 单元
```

- 默认**软链**：`~/.config/waybar/config.jsonc → ~/dotfiles/home/.config/waybar/config.jsonc`。
  改配置就是改仓库文件（`git status` 能看到）；不想这样用 `./install.sh --copy`。
- 已存在的**普通文件**会先备份到 `~/.dotfiles-backup-<时间戳>/`，再被软链替换；
  已存在的**软链**只换链不备份（源文件不动）。
- 幂等：重复跑只会打印"跳过 N"。
- `--dry-run` 完全不落盘。

装完之后**必须重新登录**（`loginctl terminate-user $USER` 或直接 reboot）。
`hyprctl reload` 只会重读配置，不会重跑 `hyprland.start` 钩子 —— 而 waybar 兜底、mako、麦克风静音
都在钩子里。

---

### 阶段 4：首次登录后的硬件适配（**新机必看**）

参考机的配置里有几处绑定具体硬件的段落，仓库里用 `[本机]` 标注了：

```bash
# 1) 显示器名（旋转键位、模拟器/Kodi 钉屏规则用到）
hyprctl monitors -j | python3 -c "import json,sys;[print(m['name'], m['width'], m['height']) for m in json.load(sys.stdin)]"
#   参考机是 LVDS-1（内屏）/ HDMI-A-1（外接 42 寸）/ VGA-1。
#   新机名字不同就把 hyprland.lua 里对应键位、以及 emulator-screen / kodi-screen 规则改掉，
#   或者直接删掉那几组键位。

# 2) 鼠标（epic-mouse-v1 + sensitivity -0.5）
hyprctl devices -j | python3 -c "import json,sys;[print(d['name']) for d in json.load(sys.stdin)['mice']]"
#   改 hl.device({ name = "..." }) 的名字，或者整段删掉。

# 3) 核显 VA-API 驱动
#   参考机（Sandy Bridge）: hl.env("LIBVA_DRIVER_NAME","i965") + 包 libva-intel-driver
#   新机（Gen8+ Intel）:    改成 iHD + 包 intel-media-driver；AMD/NVIDIA 删掉这一行

# 4) 加密盘挂载（钩子里已注释）
#   要用就装 gocryptfs、准备 /etc/gocryptfs.key(600) 和 cipher 目录，再把那行注释打开

# 5) 参考机专属的启动项，新机没有就删掉这些键位：
#   SUPER+H（Hermes Desktop）、SUPER+SHIFT+H（DSH）、waybar 的 custom/emulator（QtDemo34 模拟器）
```

字体是硬依赖：`pacman -Q ttf-jetbrains-mono-nerd` 必须在。缺了状态栏图标全是空白
（不是配置错，`fc-list | grep -i jetbrainsmono` 能确认）。

---

### 阶段 4b：代理（mihomo）—— 可一键复刻，但要带一份 bundle

**默认不装**：`bootstrap.sh` 只装桌面包，`packages/aur.txt` 里 `mihomo-bin` 是注释状态 ——
`/etc/mihomo` 里是订阅地址、节点、`api-secret`，属于机器相关+敏感，按仓库策略不进 git。
但从 2026-11-20 起它**可以一条命令复刻**，靠的是现场导出的 bundle（不走 git）。

#### 两条命令

```bash
# 参考机上（打包，需要你在弹出的窗口里输一次 sudo 密码）
sudo ~/dotfiles/proxy/export-from-live.sh
#   → ~/Downloads/mihomo-bundle-<日期>.tar.gz （实测 7.2 MB，属主本人、600）

# 新机上（装包 → 铺配置 → 装单元 → 配置自检 → 起服务 → 验端口/出网）
sudo ~/dotfiles/bootstrap.sh --user <用户名> --with-proxy ~/mihomo-bundle-<日期>.tar.gz
#   或单独跑：sudo ~/dotfiles/proxy/install-mihomo.sh --bundle <tar.gz>
```

`install-mihomo.sh` 的可选参数：

| 参数 | 作用 |
|---|---|
| `--tun keep\|on\|off` | 默认 `keep`（照 bundle）。`off` = 只留 `127.0.0.1:7890` 混合端口，不接管全系统流量 |
| `--lan-cidr 192.168.1.0/24` | 改 TUN 的 `route-exclude-address`。**新机网段和参考机不同时必须给**，否则局域网设备/NAS 会被 TUN 抢走 |
| `--no-start` | 铺好不启服务 |
| `--dry-run` | 只打印 |
| `--root-dir /tmp/fake` | 自测用：铺到临时根目录、不碰 `/etc`、不启服务（可以非 root 跑）|

#### bundle 里有什么（都是新机能复现"一模一样的代理"所必需）

```
etc-mihomo/        config.yaml、api-secret、Country.mmdb、geoip.metadb、GeoSite.dat
                   （排除 cache.db 与 *.bak*）
systemd/           mihomo.service 的两个 drop-in（10-harden / network-online）
                   + mihomo-healthcheck.{service,timer} + mihomo-boot-fix.{service,timer}
resolved.conf.d/   TUN 模式下指向 198.18.0.2 的 DNS drop-in
dns-info.txt / nftables-mihomo.txt / pkg.txt / config-test.txt / MANIFEST.txt
```

参考机的配置实况（从 bundle 里读出来的，不是猜的）：`mixed-port: 7890`、
`external-controller: 127.0.0.1:9090`（带 32 字节 secret）、`tun: enable=true stack=system device=meta`、
`auto-route` + `dns-hijack: any:53`、`dns.enhanced-mode: fake-ip`（`198.18.0.1/16`）、
`mode: rule`、`ipv6: false`。

#### 装完怎么验（install-mihomo.sh 已经自动跑前两条）

```bash
ss -tlnp | grep 127.0.0.1:7890                                  # LISTEN
curl -s -o /dev/null -w '%{http_code}\n' -x http://127.0.0.1:7890 https://www.youtube.com   # 200
resolvectl status | grep -m1 'Current DNS Server'              # TUN 开时是 198.18.0.2
resolvectl query www.baidu.com                                 # 国内域名能解析
ip -br link show meta                                          # TUN 开时有 meta 网卡
```

#### 本机实测的四个坑（脚本已处理其中三个）

- **无条件传 `--proxy-server` 会让新机浏览器断网**：`chrome-optimized.sh` 现在先探测再决定，
  没有代理就直连。自测：`chrome-optimized.sh --print-cmd`（可加 `PROXY_URL=… MAX_WAIT=2`）。
- **TUN 会把全系统流量接管**，需要防火墙放行 `iifname meta`（参考规则在 bundle 的
  `nftables-mihomo.txt`（`inet mihomo` 表）里）并且 `/dev/net/tun` 存在。
  不想动全局网络就 `--tun off`，只保留端口 + 应用层显式代理。
- **`DNS=198.18.0.2` 只在 TUN 活着时有人应答**：脚本按最终 `tun.enable` 决定装不装那份
  `resolved.conf.d/10-dns.conf`；`--tun off` 时还会把以前装过的改成 `.disabled`（否则等于断 DNS）。
- 纯 HTTP 站点经本机代理返回 **502**（HTTPS 正常），探活别用 `http://` 判断"代理坏了"。

#### 自测方式（不用第二台机器）

```bash
# 用真 bundle 铺到临时根目录，mihomo -t 会真的解析 44KB 配置（订阅/节点/规则全在）
./proxy/install-mihomo.sh --bundle ~/Downloads/mihomo-bundle-20261120.tar.gz --root-dir /tmp/fake1
#   → configuration file /tmp/fake1/etc/mihomo/config.yaml test is successful

./proxy/install-mihomo.sh --bundle … --root-dir /tmp/fake2 --tun off --lan-cidr 192.168.1.0/24
#   → tun.enable → false；route-exclude-address = 192.168.1.0/24 + 127.0.0.0/8；不装 DNS drop-in
```

配置改了之后要重新 `export-from-live.sh` 再拷新 bundle —— bundle 是快照，不是活链接。

---

### 阶段 5：验收清单

逐条跑，右侧是这台机器上的**实测期望值**。

#### 会话与服务

```bash
systemctl --user is-active wayland-session@hyprland.desktop.target   # active  （uwsm 托管成功）
systemctl --user is-active graphical-session.target waybar.service hypridle.service
                                                                     # active active active
pgrep -x waybar fcitx5 hypridle mako                                 # 四个 PID 都有
systemctl --user is-active udisks-automount.service                  # active
```

#### 状态栏

```bash
grim /tmp/bar.png && echo ok        # 截图后看一眼：左上应用/模拟器/thunar/chrome/firefox 图标、
                                    # 工作区、时钟；右上 wifi、有线、蓝牙、音量、托盘、电源
hyprctl clients -j | python3 -c 'import json,sys;print([c["class"] for c in json.load(sys.stdin)])'
```

图标**缺一半**或蓝牙整块空白 → 字体/状态键问题，见踩坑记录第 4 条。

#### 输入法与快捷键

```bash
fcitx5-remote -o && echo 输入法已开        # 或 Ctrl+空格 切中英
hyprctl binds -j | python3 -c "import json,sys;print(len(json.load(sys.stdin)),'条绑定')"
                                           # 参考机 72 条（含循环生成的 10 个工作区键位）；明显偏少 = lua 文件没被读到
```
按 `SUPER+R` 应弹 hyprlauncher；`SUPER+Q` 弹 kitty；`SUPER+SHIFT+V` 弹剪贴板历史。

#### 锁屏 / 息屏

```bash
hypridle                                    # 前台跑一下：应打印 "Registered timeout rule for 300s"
systemctl --user status hypridle            # active (running)，不是 failed/start-limit-hit
SUPER+L                                     # 立刻锁屏（hyprlock 用内置默认外观）
```

#### 通知 / 剪贴板 / 自动挂载

```bash
notify-send 测试 "mako 收到了吗"             # 顶部居中、下移 36px 避开状态栏
printf 'abc' | wl-copy && cliphist list | head -2      # 有记录
ls /run/media/$USER/                        # 插 U 盘后出现挂载点（udisks-automount）
```

#### 一键下载 / 自定义协议（参考机的那套，新机按需）

```bash
# 这两个 handler 不在本仓库里（属于"下载工具链"），装好后这样验：
xdg-mime query default x-scheme-handler/ytdlp     # ytdlp-url-handler.desktop
xdg-open 'ytdlp:"https://download.samplelib.com/mp4/sample-5s.mp4"'   # 弹 kitty 下载完自动关
tail -5 ~/.cache/ytdlp-url-handler/handler.log
```

#### 登录会话本身（最容易漏）

```bash
cat /var/log/ly.log 2>/dev/null | tail -20
# 每次登录写会话名与 Exec 命令行；应能看到 hyprland-uwsm
```

---

### 排障索引

| 症状 | 看这里 |
|---|---|
| 没状态栏 / 没输入法 / 不锁屏 / 托盘空 | 踩坑记录 1、2 |
| 状态栏图标残缺或蓝牙空白 | 踩坑记录 4 |
| `hyprctl dispatch` 没反应 | 踩坑记录 5 |
| 改了钩子里的东西没生效 | 踩坑记录 3（要重新登录）|
| `[glfw error 65544]` | 踩坑记录 8（portal 后端缺失）|
| 快捷键按了没反应 | 踩坑记录 6（同键冲突）+ `hyprctl binds -j` |

---

### 回滚 / 卸载

```bash
# 只卸 dotfiles（保留系统包）
cd ~/dotfiles && ./install.sh --list | awk '{print $1}'      # 看清单
rm -rf ~/.dotfiles-backup-*                                  # 想彻底清掉备份
# 逐个删软链（只删链，不删仓库）：
find ~/.config/hypr ~/.config/waybar -maxdepth 1 -type l -delete   # 按需精确到文件更安全

# 连系统一起退回去
sudo systemctl disable ly@tty1
sudo pacman -Rns hyprland waybar kitty mako fcitx5 fcitx5-chinese-addons
# 别删 NetworkManager/bluetooth，除非你确认还能联网
```

---

### 不在本仓库里的（以及为什么）

| 东西 | 位置 | 为什么不带 |
|---|---|---|
| 浏览器 profile / 扩展状态 | `~/.config/google-chrome`、`~/.mozilla` | 几十 GB、含登录态与 cookie |
| 密钥 | `.gnupg`、`.ssh`、`/etc/gocryptfs.key`、`~/.config/gemini.env` | 敏感 |
| 代理（mihomo）| `/etc/mihomo`（600）、`mihomo.service` | 机器/订阅相关，且改全局网络行为 |
| nginx + WebDAV + aria2 | `/etc/nginx`、`~/.config/aria2` | 与本机磁盘/NFS 布局绑定 |
| Android SDK / Qt for Android | `~/Android`、`~/Qt` | 几十 GB，跟桌面无关 |
| Kodi / IPTV / DSH / Hermes | `~/kodi-iptv`、`~/code`、`~/.hermes` | 应用层，独立维护 |
| 加固/优化脚本 | `~/security-hardening`（副本 `plain/security-hardening`）| 改 `/etc` 与内核模块，风险面大，单独一套 |
| 下载协议 handler | `~/.local/bin/{ytdlp,m3u8dl}-url-handler` + 两个 .desktop | 属于下载工具链，另有安装脚本 |

这些如果要一起搬，单独打 tar 或用 rsync 带上，别塞进 dotfiles —— 它们不是"桌面配置"，
而是"这台机器的数据与服务状态"，混进来会让新机安装变成一个不可控的大动作。

## 第 3 部分　踩坑记录

按"先看这条能不能解释你的症状"排序。

### 1. 状态栏 / 输入法 / 托盘整片不启动 → 会话没被 uwsm 托管

症状：登录后没 waybar、fcitx5 不起、blueman 托盘没了、hypridle 不锁屏、U 盘不自动挂。

```bash
systemctl --user is-active wayland-session@hyprland.desktop.target   # inactive = 非 uwsm 会话
systemctl --user is-active graphical-session.target                 # inactive
systemctl --user show graphical-session.target -p RefuseManualStart  # yes (systemd 261)
```

机制：`waybar / hypridle / hyprpolkitagent / udisks-automount` 全部 `WantedBy=graphical-session.target`，
`fcitx5 / blueman-applet / xapp-sn-watcher` 走 `xdg-desktop-autostart.target`。这两个 target 被 systemd
设了 `RefuseManualStart=yes`，**只准会话管理器以依赖方式拉起**。能拉它们的是 uwsm 的
`wayland-session@hyprland.desktop.target`；ly 里对应的会话项是
`auto_login_session = hyprland-uwsm`（`Exec=uwsm start -e -D Hyprland hyprland.desktop`）。
写成 `hyprland` 就是 `/usr/bin/start-hyprland`，谁都拉不起来 → 整片服务消失。

两条修法，A 为主 B 兜底，本仓库 **两条都带**：
- A：ly 用 uwsm 会话（`sudo ./system/apply-ly-config.sh --user <你>`）
- B：两个 drop-in 放开手动启动（`home/.config/systemd/user/*.target.d/10-allow-manual-start.conf`）
  + `hyprland.start` 钩子里调 `session-targets-up.sh`（uwsm 会话里它自动跳过）

坑：
- **uwsm 会话里绝不能 stop/restart `graphical-session.target`** —— 它 `BindsTo` 着合成器单元，
  一停就是秒登出。`session-targets-up.sh` 先判 uwsm，就是为了这个。
- 非 uwsm 会话里要先 `stop` 再 `start`：本机 `loginctl enable-linger`（`Linger=yes`），用户管理器跨注销
  常驻，直接 start 会拿到上次登录遗留的 target 和一堆指着死 Wayland 连接的单元。
- 拉起后 `xdg-desktop-autostart.target` 显示 `inactive` 不代表失败（`StopWhenUnneeded=yes`），
  看 `systemctl --user list-units 'app-*'` 里 blueman/fcitx5 是否 running。
- 源头常是"自己的加固/优化脚本"：`/etc/ly/config.ini` 被改回 `Hyprland` 就复发。改 /etc 时把脚本一起改。

### 2. hypridle 起来就死：缺 hypridle.conf

```bash
hypridle                                     # → [CRITICAL] ConfigManager: No hypridle.conf file found
systemctl --user status hypridle             # → Active: failed (Result: start-limit-hit)
```

hypridle **不自带默认配置**，没有 `~/.config/hypr/hypridle.conf` 就 46ms 退出，systemd 重试到上限。
此时自动锁屏/息屏全程没生效，而手动 `SUPER+L` 仍然正常 —— 很容易误以为没事。
修：写好 conf（本仓库 `home/.config/hypr/hypridle.conf`，300s 锁屏）→
`systemctl --user reset-failed hypridle.service && systemctl --user restart hypridle.service`。

### 3. `hyprctl reload` 不会重跑 `hyprland.start` 钩子

钩子只在合成器真正启动（登录）时执行一次。改了钩子里的东西（mako、session-targets-up.sh、
gocryptfs 挂载）**必须重新登录**才生效。想当场验证钩子有没有跑：
看只有钩子才会做的事在不在（`pgrep mako`、`~/.local/state/session-targets-up.log`）。

### 4. 状态栏图标"缺一半" / 蓝牙图标空白

- **图标被裁**：Nerd Font 图标的墨迹比字宽(advance)宽。14px 时 advance≈8.4px 而墨迹 12~16px，
  模块没有水平 padding 时溢出部分被自己的裁剪区切掉。修：图标模块 `padding: 0 6px`（本仓库 style.css 已做）。
- **蓝牙空白**：waybar 0.15.0 运行时的状态键是 `on` / `off`（不是文档里的
  `disabled/disconnected/connected/pairing`）。`format-icons` 里缺 `on` 就整块渲染成空。
  诊断手法：把候选键分别设成 `N`/`U`/`?` 跑临时实例，截图念出来命中的是哪个。
- **命名模块的 CSS 选择器**是 `#network.wifi`，不是 `#network-wifi`（`"network#wifi"` → `#network.wifi`）。
- 改图标码点**别用 sed**：PUA 字符 UTF-8 长度不同，按字节替换会变成别的字符（实测 U+F17B → U+F032）。
  用 Python `s.replace(chr(old), chr(new))`，再用 PIL `ImageFont.getbbox(chr(cp))` 确认字形真的存在。

### 5. `hyprctl dispatch` 现在是 lua 语法，旧写法静默失败

```bash
hyprctl dispatch focuswindow address:0x...            # ✗ 报 'dispatch in lua is a shorthand…'，什么都不做
hyprctl dispatch 'hl.dsp.focus({ window = "class:Emulator" })'   # ✓
hyprctl dispatch 'hl.dsp.exec_cmd("$HOME/.local/bin/xxx.sh")'    # ✓
hyprctl dispatch 'hl.dsp.focus({ workspace = 2 })'
```

- 窗口级操作都作用在**当前焦点窗口**：先 `hl.dsp.focus({...})` 再 `hl.dsp.window.resize/move/center`。
- `focus` 的 `title:` 选择器要给**完整标题**，片段/正则一律 `window not found`（而且警告容易看漏，
  后续操作会静默作用在旧焦点窗口上）。
- `hl.dsp.window.float()` 是 **toggle**，先 `hyprctl clients -j` 看 `floating` 再决定叫不叫。
- 发完必须自己确认目标真的发生了（`hyprctl clients -j` / 截图），别信回显 ok。
- **`hl.dsp.exec_cmd` 里 `$HOME` 会展开**（Hyprland 走 `sh -c`，本仓库 2026-11-20 实测：
  `hl.dsp.exec_cmd("echo $HOME > /tmp/x")` 写出 `/home/chen`），所以 dotfiles 里可以只写 `$HOME/...`。

### 6. 同一个键位绑两次不报错，只有一个生效

现役 `hyprland.lua` 里 `SUPER + V` 同时绑了「切换浮动」和「剪贴板历史」，`hyprctl binds -j` 两条都在。
Hyprland 不警告。加键位前先查占用：

```bash
grep -n 'ALT + H' ~/.config/hypr/hyprland.lua
hyprctl binds -j | python3 -c "import json,sys;[print(b['modmask'],b['key'],b.get('description')) for b in json.load(sys.stdin)]"
```

仓库版已经把剪贴板挪到 `SUPER + SHIFT + V`。

### 7. 改完配置怎么验证（不看日志等于没改）

```bash
luajit -bl ~/.config/hypr/hyprland.lua >/dev/null && echo lua-ok   # lua 语法自检
hyprctl reload                                                     # 返回 ok 才说明字段被接受
systemctl --user restart waybar.service                            # 新增模块用 restart，SIGUSR2 不一定重建
grim /tmp/bar.png                                                  # 截图 + 视觉确认（本机无 journald 持久化）
```

- 本机 `journalctl --user` 用不了（无 `/var/log/journal`，journald 易失），诊断靠
  `systemctl --user status <unit>` 的内嵌日志和 `/var/log/ly.log`。
- 只测窗口规则不用开真程序：`hl.dsp.exec_cmd("kitty --class Emulator -T test")` 然后看
  `hyprctl clients -j` 里的 class/monitor/size。

### 8. kitty 启动时那条 `[glfw error 65544]`

```
[glfw error 65544]: process_desktop_settings: failed with error:
org.freedesktop.DBus.Error.UnknownMethod: 在路径 org.freedesktop.portal.Settings 的对象上没有"…"接口
```

**是警告不是致命错误**（窗口照开），但它等价于一个硬事实：聚合对象上 `org.freedesktop.portal.Settings`
整个不存在 → `xdg-desktop-portal-gtk` 的 `gtk.portal` 被改名成 `gtk.portal.disabled`（后端被静默忽略）。
后果不止一条报错：Settings/FileChooser/Notification 等接口全缺，portal 版文件选择器也是坏的。
查：`ls -la /usr/share/xdg-desktop-portal/portals/` + `pacman -Qkk xdg-desktop-portal-gtk`。

### 9. dotfiles 是软链时，改"配置"就是在改仓库

`install.sh` 默认软链。用编辑器改 `~/.config/kitty/kitty.conf` 会直接写进 `~/dotfiles/home/...`，
`git status` 里能看到。这是设计（一份配置两处生效），但要注意：
- 别用 `echo > ~/.config/xxx` 这类重定向去"测试"，会穿透软链改掉仓库文件（本仓库制作时就踩过一次）。
- 想让机器各自独立：`./install.sh --copy`。

## 第 4 部分　快捷键速查

主修饰键 `SUPER`（Win 键）。想核对运行时的真实绑定：

```bash
hyprctl binds -j | python3 -c "
import json,sys
for b in json.load(sys.stdin):
    print(b['modmask'], b['key'], b.get('description') or '')"
# modmask: SHIFT=1 CAPS=2 CTRL=4 ALT=8 SUPER=64  → SUPER+ALT = 72
```

### 窗口与启动

| 键 | 动作 | 备注 |
|---|---|---|
| `SUPER + Q` | kitty 终端 | |
| `SUPER + E` | yazi 文件管理器 | 在 kitty 里跑，退出时 shell 会跟到 yazi 的目录 |
| `SUPER + SHIFT + E` | thunar | |
| `SUPER + R` | hyprlauncher | 启动器 |
| `SUPER + F` | firefox | 启动即全屏（窗口规则 firefox-fullscreen）|
| `SUPER + G` | chrome-optimized.sh | 带 Wayland/输入法/代理参数 |
| `SUPER + B` | blueman-manager | |
| `SUPER + H` | Hermes Desktop | 本机 AI 客户端，别的机器上删掉这条 |
| `SUPER + SHIFT + H` | DSH 控制面板 | 同上 |
| `SUPER + C` | 关闭焦点窗口 | |
| `SUPER + F11` | 全屏切换 | |
| `SUPER + M` | 退出 Hyprland | 有 hyprshutdown 就用它（带确认）|
| `SUPER + L` | hyprlock 锁屏 | |
| `SUPER + ESC` | 关屏（亮度归零）| 不是 DMPS 休眠，只是背光 |
| `SUPER + SHIFT + ESC` | 恢复亮度 | |

### 布局

| 键 | 动作 |
|---|---|
| `SUPER + V` | 切换焦点窗口浮动（toggle）|
| `SUPER + SHIFT + V` | 剪贴板历史（wofi dmenu + cliphist）**← 仓库版改动** |
| `SUPER + P` | 伪平铺 pseudo |
| `SUPER + J` | 切换分割方向（仅 dwindle）|
| `SUPER + 方向键` | 焦点移动 |
| `SUPER + 左键拖动` | 拖动窗口 |
| `SUPER + 右键拖动` | 缩放窗口 |
| `鼠标侧键(274)` | 关闭窗口 |

### 工作区

| 键 | 动作 |
|---|---|
| `SUPER + 1..9 / 0` | 切换工作区 1~10（0 = 10）|
| `SUPER + SHIFT + 1..0` | 把窗口移到对应工作区 |
| `SUPER + 滚轮上/下` | 上一个 / 下一个工作区 |
| `SUPER + S` | 切到特殊工作区 `magic` |
| `SUPER + SHIFT + S` | 把窗口移到 `special:magic` |
| 三指横滑 | 切工作区（gesture workspace）|

### 屏幕旋转（**本机专有**：LVDS-1 内屏 / HDMI-A-1 外屏 / VGA-1 投影）

| 键 | 动作 |
|---|---|
| `CTRL + ALT + 0/1/2/3` | 内屏 0°/90°/180°/270° |
| `CTRL + ALT + SHIFT + 0/1/2/3` | HDMI-A-1 旋转 |
| `CTRL + SUPER + 0/1/2/3` | VGA-1 旋转 |

旋转脚本会 disable→enable 输出强制重分配 buffer，并对 XWayland 浏览器 toggle 两次全屏，
否则竖屏后浏览器缓存的屏幕尺寸失效、全屏铺不满（`rotate-hyprland.sh` 头注释里有完整缘由）。

### 硬件功能键（`locked = true`，锁屏状态也生效）

| 键 | 动作 |
|---|---|
| `XF86AudioRaiseVolume / LowerVolume` | wpctl ±5%（上限 100%）|
| `XF86AudioMute` | 静音 sink |
| `XF86AudioMicMute` | 静音 source（**登录时默认静音麦克风**）|
| `XF86MonBrightnessUp / Down` | brightnessctl ±5% |
| `XF86AudioPlay / Pause / Next / Prev` | playerctl |

### 状态栏点击（waybar）

| 位置 | 左键 | 右键 | 中键 |
|---|---|---|---|
| 应用图标 | wofi drun | 快捷键速查 `waybar-keybinds.sh` | — |
| 模拟器图标 | 启动 QtDemo34 | 关闭 | — |
| Chrome / Firefox / thunar | 启动对应程序 | — | — |
| wifi | `wifi-menu.sh`（wofi + nmcli）| `kitty -e nmtui` | 关/开 WiFi |
| 有线 | `kitty -e nmtui` | — | — |
| 蓝牙 | blueman-manager | `bluetoothctl power off` | — |
| 电源图标 | `waybar-power.sh`（关机/重启）| — | — |

### 已知冲突（现役机器）

`SUPER + V` 在现役 `hyprland.lua` 里绑了两次（「切换浮动」和「剪贴板历史」），
`hyprctl binds` 两条都在，运行时只有一个生效。仓库版把剪贴板改到 `SUPER + SHIFT + V`。

