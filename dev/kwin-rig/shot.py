"""Screenshot of a *nested* KWin over its own session bus: python3 -I shot.py out.png"""
import os, sys, subprocess, threading
import gi
gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

out = sys.argv[1]
bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
r, w = os.pipe()
fds = Gio.UnixFDList.new()
idx = fds.append(w)
os.close(w)
chunks = []
def reader():
    with os.fdopen(r, "rb") as f:
        while True:
            b = f.read(1 << 20)
            if not b:
                break
            chunks.append(b)
t = threading.Thread(target=reader); t.start()
res, _ = bus.call_with_unix_fd_list_sync(
    "org.kde.KWin", "/org/kde/KWin/ScreenShot2", "org.kde.KWin.ScreenShot2",
    "CaptureWorkspace", GLib.Variant("(a{sv}h)", ({}, idx)),
    GLib.VariantType("(a{sv})"), Gio.DBusCallFlags.NONE, 10000, fds, None)
meta = res.unpack()[0]
fds = None
t.join(timeout=10)
data = b"".join(chunks)
wd, ht, stride = meta["width"], meta["height"], meta["stride"]
raw = b"".join(data[y*stride:y*stride + wd*4] for y in range(ht))
order = "RGBA" if meta.get("format") in (16, 17, 18) else "BGRA"
subprocess.run(["magick", "-size", f"{wd}x{ht}", "-depth", "8", f"{order}:-", out], input=raw, check=True)
print(out, meta)
