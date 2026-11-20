#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""热插拔存储设备自动挂载（用户级，无需 root）。

原理：监听 udisks2 的 D-Bus 信号（InterfacesAdded / PropertiesChanged），
对可移动设备（U 盘、移动硬盘、读卡器、手机存储模式…）调用 udisks2 的
Filesystem.Mount()，挂载到 udisks2 决定的挂载点（/run/media/$USER/<标签>），
并弹 mako 通知。文件系统不干净（Windows 快速启动/休眠）时自动退化为只读。

用法：
    udisks-automount.py [--extra-bus loop] [--dry-run] [--force-mount /dev/sdb1] [-v]
    udisks-automount.py --once            # 只扫描一次已有设备

配置（可选）：~/.config/udisks-automount/config.json
    {
      "buses": ["usb", "mmc", "ieee1394", "firewire"],
      "mount_options": {"ntfs": ["windows_names"]},
      "notify": true
    }

日志：~/.local/state/udisks-automount/udisks-automount.log（同时进 journal）
"""
import argparse
import json
import logging
import logging.handlers
import os
import shutil
import subprocess
import sys
import threading
import time
from pathlib import Path

try:
    import gi
    gi.require_version("Gio", "2.0")
    from gi.repository import Gio, GLib
except Exception as exc:  # pragma: no cover
    sys.exit(f"需要 python-gobject (Gio)：{exc}")

BUS_NAME = "org.freedesktop.UDisks2"
OBJ_ROOT = "/org/freedesktop/UDisks2"
IF_BLOCK = BUS_NAME + ".Block"
IF_FS = BUS_NAME + ".Filesystem"
IF_DRIVE = BUS_NAME + ".Drive"
IF_PART = BUS_NAME + ".Partition"
LOG = logging.getLogger("udisks-automount")

DEFAULT_CONFIG = {
    "buses": ["usb", "mmc", "ieee1394", "firewire"],
    "mount_options": {},
    "notify": True,
}
RESCAN_SECONDS = 120
TRANSIENT_HINTS = ("unclean", "hibernat", "not clean", "dirty", "wrong fs type",
                   "read-only", "no such device", "busy")


# ---------------------------------------------------------------- 工具函数
def bstr(value):
    """D-Bus 的 'ay' 字符串 -> str。"""
    if value is None:
        return None
    if isinstance(value, (bytes, bytearray)):
        return bytes(value).rstrip(b"\x00").decode("utf-8", "replace")
    if isinstance(value, list):
        return bytes(value).rstrip(b"\x00").decode("utf-8", "replace")
    return str(value)


def list_bstr(value):
    return [bstr(v) for v in (value or [])]


def load_config(path):
    cfg = dict(DEFAULT_CONFIG)
    cfg["mount_options"] = dict(DEFAULT_CONFIG["mount_options"])
    try:
        if path.is_file():
            data = json.loads(path.read_text("utf-8")) or {}
            cfg.update(data)
            LOG.info("已读取配置 %s", path)
    except Exception as exc:
        LOG.warning("配置 %s 读取失败，使用默认值：%s", path, exc)
    return cfg


def setup_logging(verbose):
    level = logging.DEBUG if verbose else logging.INFO
    fmt = logging.Formatter("%(asctime)s %(levelname)s %(message)s", "%Y-%m-%d %H:%M:%S")
    LOG.setLevel(level)
    stream = logging.StreamHandler(sys.stdout)
    stream.setFormatter(fmt)
    LOG.addHandler(stream)
    try:                                  # 落盘一份，方便事后排查
        state = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
        logdir = state / "udisks-automount"
        logdir.mkdir(parents=True, exist_ok=True)
        fh = logging.handlers.RotatingFileHandler(
            logdir / "udisks-automount.log", maxBytes=1_000_000, backupCount=2, encoding="utf-8")
        fh.setFormatter(fmt)
        LOG.addHandler(fh)
    except Exception as exc:
        LOG.warning("日志文件不可用：%s", exc)


def notify(title, body, urgency="normal", icon="drive-removable-media"):
    if not shutil.which("notify-send"):
        return
    try:
        subprocess.run(
            ["notify-send", "-a", "udisks-automount", "-i", icon,
             "-u", urgency, "-t", "6000", title, body],
            check=False, timeout=10,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception as exc:
        LOG.debug("notify-send 失败：%s", exc)


def friendly_error(msg):
    low = msg.lower()
    if "notauthorized" in low.replace(" ", "") or "not authorized" in low:
        return "权限不足（polkit 不允许无交互挂载该设备）"
    if "device is already" in low or "already mounted" in low:
        return "该设备已经挂载"
    if "unclean" in low or "hibernat" in low:
        return "文件系统不干净（Windows 未正常关机 / 快速启动导致）"
    if "read-only" in low:
        return "设备或文件系统只读"
    return msg


# ---------------------------------------------------------------- 主逻辑
class Automounter:
    def __init__(self, bus, cfg, dry_run=False):
        self.bus = bus
        self.cfg = cfg
        self.dry_run = dry_run
        self.lock = threading.Lock()
        self.pending = set()
        self.self_mounted = set()

    # ---- D-Bus 小封装
    def get_all(self, path, iface):
        try:
            res = self.bus.call_sync(
                BUS_NAME, path, "org.freedesktop.DBus.Properties", "GetAll",
                GLib.Variant("(s)", (iface,)), GLib.VariantType("(a{sv})"),
                Gio.DBusCallFlags.NONE, 15000, None)
            return res.unpack()[0]
        except GLib.Error as exc:
            LOG.debug("GetAll %s %s 失败: %s", path, iface, exc.message)
            return {}

    def managed_objects(self):
        res = self.bus.call_sync(
            BUS_NAME, OBJ_ROOT, "org.freedesktop.DBus.ObjectManager",
            "GetManagedObjects", None, GLib.VariantType("(a{oa{sa{sv}}})"),
            Gio.DBusCallFlags.NONE, 20000, None)
        return res.unpack()[0]

    # ---- 判定：这台设备该不该自动挂载
    def qualify(self, path, objs=None):
        """返回 (是否自动挂载, 原因, 设备节点, 标签, 文件系统类型)"""
        props = objs.get(path) if objs else None
        if props is None:
            blk = self.get_all(path, IF_BLOCK)
            fs = self.get_all(path, IF_FS)
            drv = self.get_all(bstr(blk.get("Drive")), IF_DRIVE) if blk.get("Drive") else {}
            props = {IF_BLOCK: blk, IF_FS: fs, IF_DRIVE: drv}
        blk = props.get(IF_BLOCK, {})
        fs = props.get(IF_FS, {})
        dev = bstr(blk.get("Device")) or path
        label = (bstr(blk.get("IdLabel")) or bstr(blk.get("IdLabelEnc"))
                 or os.path.basename(dev))
        fstype = bstr(blk.get("IdType"))

        if fs is None or (not fs and IF_FS not in props):
            return False, "没有文件系统接口", dev, label, fstype
        if bstr(blk.get("IdUsage")) != "filesystem":
            return False, f"不是文件系统 (IdUsage={bstr(blk.get('IdUsage'))})", dev, label, fstype
        if fs.get("MountPoints"):
            return False, "已经挂载", dev, label, fstype
        if blk.get("HintIgnore"):
            return False, "udisks 标记为忽略 (HintIgnore)", dev, label, fstype
        if (fstype or "") in ("swap", "LVM2_member", "crypto_LUKS", "linux_raid_member",
                              "zfs_member", "BitLocker", "unknown"):
            return False, f"不支持的容器类型 {fstype}", dev, label, fstype
        if blk.get("HintAuto"):
            return True, "udisks 标记可自动挂载 (HintAuto)", dev, label, fstype
        drv = props.get(IF_DRIVE) or {}
        bus = bstr(drv.get("ConnectionBus")) or ""
        if bus and bus in self.cfg["buses"]:
            return True, f"{bus} 总线上的可移动设备", dev, label, fstype
        if bus in getattr(self, "extra_buses", ()):
            return True, f"{bus} 总线（测试白名单）", dev, label, fstype
        return False, (f"内部/系统设备 (HintAuto={bool(blk.get('HintAuto'))} "
                       f"HintSystem={bool(blk.get('HintSystem'))} 总线={bus or '未知'})"), dev, label, fstype

    # ---- 挂载
    def do_mount(self, path, dev, label, fstype):
        base = {"auth.no_user_interaction": GLib.Variant("b", True)}
        extra = self.cfg["mount_options"].get(fstype) or []
        for attempt in (1, 2, 3):
            options = dict(base)
            if extra:
                options["options"] = GLib.Variant("as", list(extra))
            LOG.info("挂载 %s (%s, %s) 第 %d 次尝试", dev, label, fstype, attempt)
            try:
                mountpoint = self.mount_call(path, options)
                self.self_mounted.add(path)
                LOG.info("挂载成功 %s -> %s", dev, mountpoint)
                if self.cfg["notify"]:
                    notify(f"已挂载 {label}", f"{dev} ({fstype})\n{mountpoint}")
                return mountpoint
            except GLib.Error as exc:
                msg = exc.message
                low = msg.lower()
                LOG.warning("挂载 %s 失败：%s", dev, msg)
                if any(k in low for k in TRANSIENT_HINTS):
                    ro = dict(base)
                    ro["ro"] = GLib.Variant("b", True)
                    try:
                        LOG.info("尝试只读挂载 %s", dev)
                        mountpoint = self.mount_call(path, ro)
                        self.self_mounted.add(path)
                        LOG.info("只读挂载成功 %s -> %s", dev, mountpoint)
                        if self.cfg["notify"]:
                            notify(f"已只读挂载 {label}",
                                   f"{dev} ({fstype})\n{friendly_error(msg)}\n{mountpoint}",
                                   icon="dialog-warning")
                        return mountpoint
                    except GLib.Error as exc2:
                        LOG.error("只读挂载 %s 也失败：%s", dev, exc2.message)
                        msg = exc2.message
                if "notauthorized" in low.replace(" ", "") or "not authorized" in low:
                    break                     # 授权问题重试没意义
                if attempt < 3:
                    time.sleep(2)
                    continue
                break
        if self.cfg["notify"]:
            hint = ""
            if "权限不足" in friendly_error(msg):
                hint = f"\n可手动挂载：udisksctl mount -b {dev}"
            notify(f"挂载失败 {label}", f"{dev}\n{friendly_error(msg)}{hint}",
                   urgency="critical", icon="dialog-error")
        return None

    def mount_call(self, path, options):
        if self.dry_run:
            LOG.info("[dry-run] 不实际挂载 %s", path)
            return "(dry-run)"
        res = self.bus.call_sync(
            BUS_NAME, path, IF_FS, "Mount", GLib.Variant("(a{sv})", (options,)),
            GLib.VariantType("(s)"), Gio.DBusCallFlags.NONE, 120000, None)
        return res.unpack()[0]

    def handle_device(self, path, reason="", quiet=False):
        ok, why, dev, label, fstype = self.qualify(path)
        if not ok:
            LOG.log(logging.DEBUG if quiet else logging.INFO, "跳过 %s：%s", dev, why)
            return
        LOG.info("自动挂载 %s（%s%s）", dev, why, f"；{reason}" if reason else "")
        self.do_mount(path, dev, label, fstype)

    # ---- 信号回调
    def on_interfaces_added(self, _conn, _sender, _obj, _iface, _sig, params, _data):
        added_path, ifaces = params.unpack()
        if IF_FS in ifaces or IF_BLOCK in ifaces:
            self.spawn(added_path)

    def on_properties_changed(self, _conn, _sender, obj_path, iface, _sig, params, _data):
        iface_name, changed, _invalidated = params.unpack()
        if iface_name != IF_FS or "MountPoints" not in changed:
            return
        mps = list_bstr(changed["MountPoints"])
        blk = self.get_all(obj_path, IF_BLOCK)
        dev = bstr(blk.get("Device")) or obj_path.rsplit("/", 1)[-1]
        label = bstr(blk.get("IdLabel")) or dev
        if mps:
            if obj_path in self.self_mounted:       # 自己刚挂的，别重复通知
                self.self_mounted.discard(obj_path)
                return
            LOG.info("设备已挂载 %s -> %s", dev, ", ".join(mps))
            if self.cfg["notify"]:
                notify(f"已挂载 {label}", f"{dev}\n{', '.join(mps)}")
        else:
            LOG.info("设备已卸载 %s", dev)
            if self.cfg["notify"]:
                notify(f"已卸载 {label}", dev)

    def on_interfaces_removed(self, _conn, _sender, obj_path, _iface, _sig, params, _data):
        removed_path, ifaces = params.unpack()
        if IF_FS in ifaces:
            name = removed_path.rsplit("/", 1)[-1]
            LOG.info("设备已拔出 %s", name)
            if self.cfg["notify"]:
                notify("设备已拔出", name)

    def spawn(self, path):
        with self.lock:
            if path in self.pending:
                return
            self.pending.add(path)

        def worker():
            time.sleep(1.0)            # 等 udisks 把属性补齐
            try:
                self.handle_device(path, "热插拔")
            except Exception as exc:
                LOG.exception("处理 %s 出错：%s", path, exc)
            finally:
                with self.lock:
                    self.pending.discard(path)

        threading.Thread(target=worker, daemon=True).start()

    # ---- 启动 / 周期扫描
    def subscribe(self):
        flags = Gio.DBusSignalFlags.NONE
        self.bus.signal_subscribe(BUS_NAME, "org.freedesktop.DBus.ObjectManager",
                                  "InterfacesAdded", OBJ_ROOT, None, flags,
                                  self.on_interfaces_added, None)
        self.bus.signal_subscribe(BUS_NAME, "org.freedesktop.DBus.ObjectManager",
                                  "InterfacesRemoved", OBJ_ROOT, None, flags,
                                  self.on_interfaces_removed, None)
        self.bus.signal_subscribe(BUS_NAME, "org.freedesktop.DBus.Properties",
                                  "PropertiesChanged", None, None, flags,
                                  self.on_properties_changed, None)

    def scan_existing(self, quiet=False, only_devices=()):
        try:
            objs = self.managed_objects()
        except GLib.Error as exc:
            LOG.warning("枚举 udisks 对象失败：%s", exc.message)
            return
        for path, ifaces in sorted(objs.items()):
            if IF_BLOCK not in ifaces:
                continue
            dev = bstr(ifaces[IF_BLOCK].get("Device"))
            if only_devices and dev not in only_devices:
                continue
            if only_devices:
                LOG.info("强制挂载 %s（忽略判定）", dev)
                self.do_mount(path, dev, bstr(ifaces[IF_BLOCK].get("IdLabel")) or dev,
                              bstr(ifaces[IF_BLOCK].get("IdType")))
                continue
            if IF_FS in ifaces:
                try:
                    self.handle_device(path, "启动扫描" if not quiet else "周期扫描", quiet=quiet)
                except Exception as exc:
                    LOG.warning("扫描 %s 出错：%s", path, exc)


def main():
    ap = argparse.ArgumentParser(description="热插拔设备自动挂载（udisks2，用户级）")
    ap.add_argument("--extra-bus", action="append", default=[],
                    help="额外允许自动挂载的总线（可重复，调试用，如 loop）")
    ap.add_argument("--dry-run", action="store_true", help="只打印判定，不真的挂载")
    ap.add_argument("--once", action="store_true", help="扫描一次已有设备然后退出")
    ap.add_argument("--force-mount", action="append", default=[],
                    help="忽略判定，直接挂载指定设备节点（调试，如 /dev/sdb1）")
    ap.add_argument("-v", "--verbose", action="store_true")
    args = ap.parse_args()

    setup_logging(args.verbose)
    cfg = load_config(Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
                      / "udisks-automount" / "config.json")

    bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
    bot = Automounter(bus, cfg, dry_run=args.dry_run)
    bot.extra_buses = tuple(args.extra_bus)          # 仅调试白名单，常规配置走 drives 总线
    LOG.info("自动挂载服务启动；白名单总线=%s；dry_run=%s", cfg["buses"], args.dry_run)

    if args.force_mount:
        bot.scan_existing(only_devices=tuple(args.force_mount))
        return 0

    bot.scan_existing()
    if args.once:
        return 0
    bot.subscribe()
    GLib.timeout_add_seconds(RESCAN_SECONDS, lambda: (bot.scan_existing(quiet=True), True)[1])
    LOG.info("已订阅 udisks2 信号，等待热插拔事件…（每 %d 秒兜底扫描一次）", RESCAN_SECONDS)
    GLib.MainLoop().run()
    return 0


if __name__ == "__main__":
    sys.exit(main())
