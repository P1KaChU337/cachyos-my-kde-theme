#!/usr/bin/env python3
"""Аудио-визуализатор на CAVA поверх обоев (layer-shell, под окнами, клики насквозь, с размытием)."""
import ctypes
import math
import os
import sys
import tempfile

os.environ.setdefault("QT_QPA_PLATFORM", "wayland")
os.environ["QT_WAYLAND_SHELL_INTEGRATION"] = "layer-shell"

import shiboken6
from PySide6.QtCore import QObject, QProcess, Signal, Property, QUrl, QRect, QTimer
from PySide6.QtGui import QGuiApplication, QRegion
from PySide6.QtQml import QQmlApplicationEngine

# ---------- настройки ----------
BARS = 36
SIDE_FRACTION = 0.34      # доля ширины экрана под каждую волну
MAX_HEIGHT = 240          # px
EDGE_MIN = 0.22           # высота у центра относительно краёв
SENSITIVITY = 140         # чувствительность cava, % (100 = стандарт)
BOOST = 0.75              # <1 поднимает тихие звуки, громкие упираются в тот же максимум
BLUR = False
BLUR_COLUMN = 4           # ширина столбиков региона размытия, px
BLUR_INSET = 4            # насколько зона размытия ниже кромки волны, px
# --------------------------------

HERE = os.path.dirname(os.path.abspath(__file__))

CAVA_CONF = f"""
[general]
framerate = 60
bars = {BARS}
autosens = 1
sensitivity = {SENSITIVITY}
lower_cutoff_freq = 40
higher_cutoff_freq = 12000

[input]
method = pipewire
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 1000
bar_delimiter = 59
frame_delimiter = 10
channels = mono
mono_option = average

[smoothing]
monstercat = 1
noise_reduction = 82
"""

try:
    _kws = ctypes.CDLL("libKF6WindowSystem.so.6")
    _blur = _kws._ZN14KWindowEffects16enableBlurBehindEP7QWindowbRK7QRegion
    _blur.argtypes = [ctypes.c_void_p, ctypes.c_bool, ctypes.c_void_p]
    _blur.restype = None
except (OSError, AttributeError):
    _blur = None


def catmull(pts, steps=6):
    """Сглаженная кривая через точки (Catmull-Rom), возвращает плотный список (x, y)."""
    out = []
    n = len(pts)
    for i in range(n - 1):
        p0, p1, p2, p3 = pts[max(i - 1, 0)], pts[i], pts[i + 1], pts[min(i + 2, n - 1)]
        for s in range(steps):
            t = s / steps
            t2, t3 = t * t, t * t * t
            out.append(tuple(
                0.5 * (2 * p1[k] + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2
                       + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3)
                for k in (0, 1)))
    out.append(pts[-1])
    return out


class Wave(QObject):
    changed = Signal()

    def __init__(self, width, height):
        super().__init__()
        self.W, self.H = width, height
        self.levels = [0.0] * BARS
        self._left, self._right = [], []
        self._active = False
        self.window = None
        self._region_dirty = False
        self._last_region = None
        self._hist = []

        fd, self.conf = tempfile.mkstemp(prefix="kava-", suffix=".conf")
        with os.fdopen(fd, "w") as f:
            f.write(CAVA_CONF)
        self.buf = b""
        self.proc = QProcess(self)
        self.proc.readyReadStandardOutput.connect(self.read)
        self.proc.start("cava", ["-p", self.conf])

        self.blurTimer = QTimer(self)
        self.blurTimer.setInterval(33)  # ~30 к/с для региона размытия
        self.blurTimer.timeout.connect(self.update_blur)
        self.blurTimer.start()  # подчищает регион, когда звук пропал

    # ---- данные для QML ----
    def _get_left(self):
        return self._left

    def _get_right(self):
        return self._right

    def _get_active(self):
        return self._active

    left = Property(list, _get_left, notify=changed)
    right = Property(list, _get_right, notify=changed)
    active = Property(bool, _get_active, notify=changed)

    def read(self):
        self.buf += bytes(self.proc.readAllStandardOutput())
        lines = self.buf.split(b"\n")
        self.buf = lines[-1]
        if len(lines) < 2:
            return
        raw = lines[-2].strip(b";").split(b";")
        try:
            vals = [(min(int(v), 1000) / 1000.0) ** BOOST for v in raw if v]
        except ValueError:
            return
        if len(vals) != BARS:
            return
        any_ = False
        for i, t in enumerate(vals):
            l = self.levels[i]
            l += (t - l) * (0.55 if t > l else 0.18)
            self.levels[i] = l
            any_ = any_ or l > 0.004
        self._active = any_
        self.build()

    def side_points(self, x0, w, mirrored):
        n = BARS
        pts = []
        for i in range(n):
            u = 1 - i / (n - 1) if mirrored else i / (n - 1)   # 0 = край экрана
            idx = round(u * (n - 1))                            # басы у краёв
            env = EDGE_MIN + (1 - EDGE_MIN) * (1 - u) ** 1.2
            inner = math.sin(math.pi / 2 * min(1.0, (1 - u) / 0.3))
            pts.append((x0 + i / (n - 1) * w, self.H - self.levels[idx] * MAX_HEIGHT * env * inner))
        return catmull(pts)

    def build(self):
        w = self.W * SIDE_FRACTION
        L = self.side_points(0, w, False)
        R = self.side_points(self.W - w, w, True)
        self._curves = (L, R)
        self._left = [v for p in L for v in p]
        self._right = [v for p in R for v in p]
        self._region_dirty = True
        self.changed.emit()
        self.update_blur()

    def update_blur(self):
        if not (BLUR and _blur and self.window and self._region_dirty):
            return
        self._region_dirty = False
        reg = QRegion()
        if self._active:
            cols = []
            for curve in self._curves:
                j = 0
                x = curve[0][0]
                xend = curve[-1][0]
                while x < xend:
                    # самая низкая точка кривой в столбике
                    while j < len(curve) - 1 and curve[j + 1][0] < x:
                        j += 1
                    k = j
                    while k < len(curve) and curve[k][0] <= x + BLUR_COLUMN:
                        k += 1
                    ys = [p[1] for p in curve[j:k + 1]]
                    cols.append((int(x), self.H - (max(ys) if ys else self.H)))
                    x += BLUR_COLUMN
            # берём минимум за последние кадры + отступ, чтобы размытие никогда не торчало над волной
            self._hist.append([h for _, h in cols])
            self._hist = self._hist[-3:]
            for i, (x, _) in enumerate(cols):
                h = int(min(hh[i] for hh in self._hist if len(hh) > i)) - BLUR_INSET
                if h > 1:
                    reg += QRegion(QRect(x, self.H - h, BLUR_COLUMN, h))
        else:
            self._hist = []
        if reg == self._last_region:
            return
        self._last_region = reg
        win_ptr = shiboken6.getCppPointer(self.window)[0]
        reg_ptr = shiboken6.getCppPointer(reg)[0]
        _blur(win_ptr, not reg.isEmpty(), reg_ptr)

    def stop(self):
        self.proc.kill()
        self.proc.waitForFinished(1000)
        try:
            os.unlink(self.conf)
        except OSError:
            pass


def single_instance():
    import fcntl
    path = os.path.join(os.environ.get("XDG_RUNTIME_DIR", tempfile.gettempdir()), "kava-overlay.lock")
    f = open(path, "w")
    try:
        fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        sys.exit(0)  # уже запущена
    return f


def main():
    _lock = single_instance()
    app = QGuiApplication(sys.argv)
    app.setDesktopFileName("kava-overlay")
    scr = app.primaryScreen().geometry()
    height = MAX_HEIGHT + 10
    wave = Wave(scr.width(), height)
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("wave", wave)
    engine.rootContext().setContextProperty("waveHeight", height)
    engine.load(QUrl.fromLocalFile(os.path.join(HERE, "main.qml")))
    if not engine.rootObjects():
        sys.exit(1)
    wave.window = engine.rootObjects()[0]
    app.aboutToQuit.connect(wave.stop)
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
