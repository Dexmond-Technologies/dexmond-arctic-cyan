#!/usr/bin/env python3
"""Procedural wallpapers for the Dexmond Arctic Cyan theme.

Everything is drawn from code (pycairo + numpy + Pillow); the only input is the Dexmond mark mask (tools/mark_mask.png).
Palette: background #070812, cyan #00f5ff dominant, accents purple #8b5cf6 and green #00ff9c. No red or orange.

    python3 tools/make_wallpapers.py --variant circuit --size 1920x1080 --out preview.png
    python3 tools/make_wallpapers.py --all           # every variant at every release size
"""
import argparse, math, os, random
import cairo
import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
BG = (0x07, 0x08, 0x12)
CYAN = (0x00 / 255, 0xF5 / 255, 0xFF / 255)
DEEP = (0x00 / 255, 0x8C / 255, 0xC8 / 255)
PURPLE = (0x8B / 255, 0x5C / 255, 0xF6 / 255)
GREEN = (0x00 / 255, 0xFF / 255, 0x9C / 255)
SIZES = {"3840x2160": (3840, 2160), "2560x1440": (2560, 1440), "1920x1080": (1920, 1080), "phone-1080x1920": (1080, 1920)}
VARIANTS = ("circuit", "neural", "horizon")
TAU = 2 * math.pi


# ---------------------------------------------------------------- helpers
def surface(w, h):
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, w, h)
    c = cairo.Context(s)
    c.set_line_cap(cairo.LINE_CAP_ROUND)
    c.set_line_join(cairo.LINE_JOIN_ROUND)
    return s, c


def to_np(s):
    """cairo premultiplied BGRA -> float RGB light layer (0..1, additive)."""
    s.flush()
    a = np.ndarray((s.get_height(), s.get_stride() // 4, 4), np.uint8, s.get_data())[:, : s.get_width()]
    return a[..., [2, 1, 0]].astype(np.float32) / 255.0


def blur(rgb, r):
    if r < 0.4:
        return rgb
    out = np.empty_like(rgb)
    for i in range(rgb.shape[2]):
        ch = rgb[..., i]
        m = float(ch.max()) or 1.0
        im = Image.fromarray(np.clip(ch / m * 255, 0, 255).astype(np.uint8), "L")
        out[..., i] = np.asarray(im.filter(ImageFilter.GaussianBlur(r)), np.float32) / 255.0 * m
    return out


def glow(layer, u, strength=1.0):
    """Light layer plus a tight bloom and a wide atmospheric halo."""
    return layer + strength * (0.8 * blur(layer, 2.5 * u) + 0.5 * blur(layer, 12 * u) + 0.25 * blur(layer, 40 * u))


def dof(layer, u, focus, w, h, max_r):
    """Depth-of-field falloff: sharp near the focus point, softer toward the edges."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.clip(np.hypot((x - focus[0] * w) / w, (y - focus[1] * h) / h) / 0.75, 0, 1)[..., None] ** 1.5
    return layer * (1 - d) + blur(layer, max_r * u) * d


def base(w, h, cx, cy, tint=(0.02, 0.06, 0.12), k=0.45):
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.hypot((x - cx * w) / max(w, h), (y - cy * h) / max(w, h))
    img = np.zeros((h, w, 3), np.float32) + np.array(BG, np.float32) / 255.0
    img += np.exp(-(d / 0.45) ** 2)[..., None] * np.array(tint, np.float32) * k
    return img * (1 - 0.65 * np.clip(d / 0.75, 0, 1) ** 2)[..., None]


def mark(img, w, h, phone):
    m = Image.open(os.path.join(HERE, "mark_mask.png"))
    mh = int(h * (0.03 if phone else 0.048))
    m = m.resize((max(1, int(m.width * mh / m.height)), mh), Image.LANCZOS)
    a = np.asarray(m, np.float32) / 255.0
    x0, y0 = ((w - m.width) // 2, int(h * 0.91)) if phone else (w - m.width - int(h * 0.05), h - mh - int(h * 0.05))
    full = np.zeros((h, w), np.float32)
    full[y0:y0 + mh, x0:x0 + m.width] = a
    lay = full[..., None] * np.array(CYAN, np.float32) * 0.9
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    clear = np.exp(-(((xx - x0 - m.width / 2) / (mh * 1.3)) ** 2 + ((yy - y0 - mh / 2) / (mh * 1.3)) ** 2))[..., None]
    img = img * (1 - 0.7 * clear)  # quiet zone so nothing crosses the mark
    return img * (1 - 0.9 * full[..., None]) + lay + blur(lay, mh * 0.12) * 0.5


def tone(bg, light):
    return bg * (1 - np.clip(light, 0, 1) * 0.5) + (1 - np.exp(-light * 1.5))  # soft tone curve on the light only


def dither(img, rng):
    img = img + (rng.random(img.shape[:2], np.float32)[..., None] - 0.5) / 255.0 * 1.5
    return Image.fromarray(np.clip(img * 255 + 0.5, 0, 255).astype(np.uint8), "RGB")


def offset_poly(pts, d):
    """Offset an open polyline sideways by d (mitred joins) so parallel bus traces stay parallel through bends."""
    out = []
    n = len(pts)
    for i in range(n):
        if i in (0, n - 1):
            j0, j1 = (0, 1) if i == 0 else (n - 2, n - 1)
            dx, dy = pts[j1][0] - pts[j0][0], pts[j1][1] - pts[j0][1]
            L = math.hypot(dx, dy) or 1
            out.append((pts[i][0] - dy / L * d, pts[i][1] + dx / L * d))
            continue
        ax, ay = pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]
        bx, by = pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1]
        La, Lb = math.hypot(ax, ay) or 1, math.hypot(bx, by) or 1
        n1, n2 = (-ay / La, ax / La), (-by / Lb, bx / Lb)
        mx, my = n1[0] + n2[0], n1[1] + n2[1]
        Lm = math.hypot(mx, my) or 1
        mx, my = mx / Lm, my / Lm
        cosh = max(0.35, mx * n1[0] + my * n1[1])
        out.append((pts[i][0] + mx * d / cosh, pts[i][1] + my * d / cosh))
    return out


def poly(c, pts):
    c.move_to(*pts[0])
    for p in pts[1:]:
        c.line_to(*p)


# ---------------------------------------------------------------- Circuit
DIRS = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]


def route(rng, x, y, cell, steps, d=None):
    d = rng.randrange(8) if d is None else d
    pts = [(x, y)]
    for _ in range(steps):
        n = rng.randint(2, 8)
        dx, dy = DIRS[d]
        x, y = x + dx * cell * n, y + dy * cell * n
        pts.append((x, y))
        if rng.random() < 0.75:
            d = (d + rng.choice((-1, 1))) % 8
    return pts


def pad(c, x, y, r, kind, col, a):
    c.set_source_rgba(*col, a)
    if kind == 0:  # round solder pad
        c.arc(x, y, r, 0, TAU)
        c.fill()
    elif kind == 1:  # via: ring around a dark drill hole
        c.set_line_width(r * 0.55)
        c.arc(x, y, r * 0.8, 0, TAU)
        c.stroke()
    else:  # square SMD pad
        c.rectangle(x - r, y - r * 0.7, 2 * r, 1.4 * r)
        c.fill()


def chip(c, x, y, cw, ch, pitch, col, a, u):
    """IC footprint: rounded outline, pin-1 dot, die outline and pin rows; returns the pin ends."""
    r = 3 * u
    c.new_sub_path()
    c.arc(x + cw - r, y + r, r, -TAU / 4, 0)
    c.arc(x + cw - r, y + ch - r, r, 0, TAU / 4)
    c.arc(x + r, y + ch - r, r, TAU / 4, TAU / 2)
    c.arc(x + r, y + r, r, TAU / 2, 3 * TAU / 4)
    c.close_path()
    c.set_source_rgba(*col, a * 0.07)
    c.fill_preserve()
    c.set_source_rgba(*col, a * 0.8)
    c.set_line_width(1.2 * u)
    c.stroke()
    c.arc(x + 7 * u, y + 7 * u, 2.2 * u, 0, TAU)
    c.set_source_rgba(*col, a * 0.7)
    c.fill()
    c.rectangle(x + cw * 0.28, y + ch * 0.28, cw * 0.44, ch * 0.44)
    c.set_source_rgba(*col, a * 0.25)
    c.set_line_width(0.8 * u)
    c.stroke()
    pins = []
    nx, ny = max(2, int((cw - 10 * u) / pitch)), max(2, int((ch - 10 * u) / pitch))
    L = 6 * u
    for side in range(4):
        cnt = nx if side in (0, 2) else ny
        for k in range(cnt):
            t = (k + 0.5) / cnt
            px, py, ox, oy = [(x + t * cw, y, 0, -1), (x + cw, y + t * ch, 1, 0), (x + t * cw, y + ch, 0, 1), (x, y + t * ch, -1, 0)][side]
            if ox == 0:
                c.rectangle(px - 1.1 * u, min(py, py + oy * L), 2.2 * u, L)
            else:
                c.rectangle(min(px, px + ox * L), py - 1.1 * u, L, 2.2 * u)
            c.set_source_rgba(*col, a * 0.85)
            c.fill()
            pins.append((px + ox * L, py + oy * L, side))
    return pins


def circuit(w, h, seed, phone=False):
    rng = random.Random(seed)
    u = min(w, h) / 1080
    area = w * h / (1920 * 1080 * u * u)  # same picture at every resolution: sizes already scale with u
    focus = (0.66, 0.46) if not phone else (0.5, 0.42)
    bg = base(w, h, *focus)
    light = np.zeros_like(bg)

    def dens(x):  # denser toward the right; the centre-left stays calmer for windows and icons
        return 0.75 if phone else 0.3 + 0.7 * min(1.0, max(0.0, x / w)) ** 1.3

    # depth layers, far to near: (micro traces, buses, single traces, chips, line width, alpha, cell, blur, colour)
    layers = [
        (900, 10, 60, 0, 0.6, 0.10, 8, 3.2, DEEP),
        (700, 14, 70, 2, 0.8, 0.18, 10, 1.8, DEEP),
        (380, 12, 45, 3, 1.0, 0.32, 13, 0.9, CYAN),
        (120, 8, 24, 3, 1.5, 0.55, 18, 0.3, CYAN),
        (0, 4, 9, 1, 2.4, 0.95, 26, 0.0, CYAN),
    ]
    for li, (micro, buses, singles, chips, lw, alpha, cell, bl, col0) in enumerate(layers):
        s, c = surface(w, h)
        cl = cell * u
        for _ in range(int(micro * area)):  # fine micro-traces filling the empty space
            x, y = rng.uniform(0, w), rng.uniform(0, h)
            if rng.random() > dens(x):
                continue
            pts = route(rng, x, y, cl * 0.45, rng.randint(1, 3))
            poly(c, pts)
            c.set_source_rgba(*col0, alpha * 0.55)
            c.set_line_width(lw * 0.6 * u)
            c.stroke()
            pad(c, *pts[-1], 1.4 * u, rng.randrange(3), col0, alpha * 0.6)
        for _ in range(int(chips * area + rng.random())):  # chips with traces leaving their pins
            cw, ch = rng.uniform(70, 150) * u * (0.6 + 0.2 * li), rng.uniform(50, 120) * u * (0.6 + 0.2 * li)
            x = rng.uniform(0.35, 0.95) * w if not phone else rng.uniform(0.05, 0.8) * w
            y = rng.uniform(0.05, 0.85) * h
            for px, py, side in chip(c, x, y, cw, ch, 9 * u * (0.7 + 0.15 * li), col0, alpha, u):
                if rng.random() < 0.55:
                    d0 = {0: 6, 1: 0, 2: 2, 3: 4}[side]
                    pts = [(px, py)] + route(rng, px, py, cl * 0.6, rng.randint(1, 3), d0)[1:]
                    poly(c, pts)
                    c.set_source_rgba(*col0, alpha * 0.7)
                    c.set_line_width(lw * 0.7 * u)
                    c.stroke()
                    pad(c, *pts[-1], 2.0 * u, rng.randrange(3), col0, alpha * 0.8)
        for _ in range(int(buses * area)):  # parallel buses
            x, y = rng.uniform(-0.05, 1.05) * w, rng.uniform(-0.05, 1.05) * h
            if rng.random() > dens(x):
                continue
            centre = route(rng, x, y, cl, rng.randint(2, 5))
            n = rng.randint(3, 7)
            pitch = (4 + li) * u
            col = PURPLE if rng.random() < 0.1 else col0
            for k in range(n):
                p = offset_poly(centre, (k - (n - 1) / 2) * pitch)
                poly(c, p)
                c.set_source_rgba(*col, alpha * 0.8)
                c.set_line_width(lw * 0.75 * u)
                c.stroke()
                pad(c, *p[0], 1.6 * u * (1 + 0.2 * li), 1, col, alpha)
                pad(c, *p[-1], 1.6 * u * (1 + 0.2 * li), 0, col, alpha)
        for _ in range(int(singles * area)):  # single long traces with pads and vias
            x, y = rng.uniform(-0.05, 1.05) * w, rng.uniform(-0.05, 1.05) * h
            if rng.random() > dens(x):
                continue
            r_ = rng.random()
            col = PURPLE if r_ < 0.07 else (GREEN if r_ < 0.1 else col0)
            pts = route(rng, x, y, cl, rng.randint(2, 6))
            poly(c, pts)
            c.set_source_rgba(*col, alpha)
            c.set_line_width(lw * u)
            c.stroke()
            for (px, py) in pts[1:-1]:
                if rng.random() < 0.25:
                    pad(c, px, py, (2.2 + 0.5 * li) * u, 1, col, alpha)
            pad(c, *pts[0], (2.4 + 0.6 * li) * u, rng.randrange(3), col, alpha)
            pad(c, *pts[-1], (2.4 + 0.6 * li) * u, rng.randrange(3), col, alpha)
        light += glow(blur(to_np(s), bl * u), u, 0.35 + 0.18 * li)
    return bg, dof(light, u, focus, w, h, 2.2)


# ---------------------------------------------------------------- Neural
def neighbours(P, k, maxd):
    """Up to k nearest neighbours under maxd for every point (grid buckets + numpy)."""
    out = []
    keys = np.floor(P / maxd).astype(int)
    buckets = {}
    for i, kk in enumerate(map(tuple, keys)):
        buckets.setdefault(kk, []).append(i)
    for i, (kx, ky) in enumerate(keys):
        cand = [j for dx in (-1, 0, 1) for dy in (-1, 0, 1) for j in buckets.get((kx + dx, ky + dy), ()) if j != i]
        if not cand:
            continue
        cand = np.array(cand)
        d = np.hypot(*(P[cand] - P[i]).T)
        for o in np.argsort(d)[:k]:
            if d[o] < maxd and cand[o] > i:
                out.append((i, int(cand[o]), float(d[o])))
    return out


def dendrite(c, rng, x, y, ang, length, width, depth, col, a, u):
    if depth == 0 or length < 3 * u:
        return
    x2, y2 = x + math.cos(ang) * length, y + math.sin(ang) * length
    bend = rng.uniform(-0.5, 0.5)
    cx, cy = (x + x2) / 2 - math.sin(ang) * length * bend * 0.4, (y + y2) / 2 + math.cos(ang) * length * bend * 0.4
    c.move_to(x, y)
    c.curve_to(cx, cy, cx, cy, x2, y2)
    c.set_source_rgba(*col, a)
    c.set_line_width(width)
    c.stroke()
    for _ in range(rng.choice((1, 2, 2))):
        dendrite(c, rng, x2, y2, ang + rng.uniform(-0.7, 0.7), length * rng.uniform(0.55, 0.75), width * 0.7, depth - 1, col, a * 0.8, u)


def spark(c, x, y, r, col, a):
    for ang in (0, TAU / 4):
        c.move_to(x - math.cos(ang) * r, y - math.sin(ang) * r)
        c.line_to(x + math.cos(ang) * r, y + math.sin(ang) * r)
    c.set_source_rgba(*col, a)
    c.set_line_width(r * 0.18)
    c.stroke()
    c.arc(x, y, r * 0.22, 0, TAU)
    c.fill()


def neural(w, h, seed, phone=False):
    rng = random.Random(seed)
    u = min(w, h) / 1080
    area = w * h / (1920 * 1080 * u * u)  # same picture at every resolution: sizes already scale with u
    focus = (0.34, 0.5) if not phone else (0.5, 0.45)
    bg = base(w, h, focus[0], focus[1], (0.03, 0.04, 0.12))
    light = np.zeros_like(bg)

    def sample(n):
        pts = []
        while len(pts) < n:
            x, y = rng.uniform(-0.03, 1.03) * w, rng.uniform(-0.03, 1.03) * h
            d = math.hypot((x / w - focus[0]) * 1.2, y / h - focus[1])
            if rng.random() < 0.18 + 0.82 * math.exp(-(d / 0.45) ** 2):
                pts.append((x, y))
        return np.array(pts)

    s, c = surface(w, h)  # soft volumetric glow clusters
    for _ in range(int(14 * area) + 6):
        x, y = sample(1)[0]
        col = PURPLE if rng.random() < 0.35 else (GREEN if rng.random() < 0.08 else CYAN)
        g = cairo.RadialGradient(x, y, 0, x, y, rng.uniform(120, 320) * u)
        g.add_color_stop_rgba(0, *col, rng.uniform(0.05, 0.11))
        g.add_color_stop_rgba(1, *col, 0)
        c.set_source(g)
        c.paint()
    light += to_np(s)

    # far to near: (nodes, node radius, alpha, link distance, links per node, blur, dendrites); last = foreground bokeh
    layers = [(1400, 1.0, 0.16, 70, 3, 3.0, 0), (800, 1.4, 0.28, 95, 3, 1.6, 0), (420, 2.0, 0.5, 130, 3, 0.6, 2),
              (150, 3.0, 0.9, 170, 4, 0.0, 3), (9, 9.0, 0.16, 0, 0, 8.0, 0)]
    for li, (n, rad, alpha, link, kk, bl, dend) in enumerate(layers):
        P = sample(int(n * area))
        s, c = surface(w, h)
        if link:
            for i, j, d in neighbours(P, kk, link * u):
                (x, y), (a_, b_) = P[i], P[j]
                bend = rng.uniform(-0.25, 0.25)
                mx, my = (x + a_) / 2 - (b_ - y) * bend, (y + b_) / 2 + (a_ - x) * bend
                hot = rng.random() < 0.05 and li >= 2
                aa = alpha * (0.35 + 0.65 * (1 - d / (link * u))) * (1.8 if hot else 1)
                g = cairo.LinearGradient(x, y, a_, b_)
                g.add_color_stop_rgba(0, *CYAN, aa)
                g.add_color_stop_rgba(0.5, *(PURPLE if hot and rng.random() < 0.4 else CYAN), aa * (1.3 if hot else 0.6))
                g.add_color_stop_rgba(1, *CYAN, aa)
                c.set_source(g)
                c.move_to(x, y)
                c.curve_to(mx, my, mx, my, a_, b_)
                c.set_line_width((0.5 + 0.35 * li) * u * (1.6 if hot else 1))
                c.stroke()
                if li >= 2 and rng.random() < 0.08:  # synapse spark on the link
                    t = rng.uniform(0.2, 0.8)
                    sx = (1 - t) ** 2 * x + 2 * (1 - t) * t * mx + t * t * a_
                    sy = (1 - t) ** 2 * y + 2 * (1 - t) * t * my + t * t * b_
                    spark(c, sx, sy, rng.uniform(3, 7) * u, GREEN if rng.random() < 0.2 else CYAN, 0.8)
        for x, y in P:
            r_ = rng.random()
            col = GREEN if r_ < 0.04 else (PURPLE if r_ < 0.11 else CYAN)
            rr = rad * u * rng.uniform(0.7, 1.5)
            if li == 4:  # out-of-focus foreground bokeh
                c.arc(x, y, rr * 3, 0, TAU)
                c.set_source_rgba(*col, alpha * rng.uniform(0.3, 1))
                c.fill()
                continue
            c.arc(x, y, rr, 0, TAU)
            c.set_source_rgba(*col, alpha)
            c.fill()
            if li >= 3:  # soma ring
                c.arc(x, y, rr * 2.1, 0, TAU)
                c.set_source_rgba(*col, alpha * 0.35)
                c.set_line_width(0.8 * u)
                c.stroke()
            for _ in range(dend if rng.random() < 0.6 else 0):
                dendrite(c, rng, x, y, rng.uniform(0, TAU), rng.uniform(14, 34) * u * (li - 1), (0.5 + 0.25 * li) * u, 3, col, alpha * 0.55, u)
        light += glow(blur(to_np(s), bl * u), u, 0.15 if li == 4 else 0.4 + 0.2 * li)
    s, c = surface(w, h)  # faint dust
    for _ in range(int(900 * area)):
        c.arc(rng.uniform(0, w), rng.uniform(0, h), rng.uniform(0.4, 1.2) * u, 0, TAU)
        c.set_source_rgba(*CYAN, rng.uniform(0.05, 0.25))
        c.fill()
    light += blur(to_np(s), 0.6 * u)
    return bg, dof(light, u, focus, w, h, 2.0)


# ---------------------------------------------------------------- Horizon
def horizon(w, h, seed, phone=False):
    rng = random.Random(seed)
    u = min(w, h) / 1080
    hy = h * (0.6 if not phone else 0.64)
    vx = w / 2
    bg = base(w, h, 0.5, hy / h, (0.03, 0.05, 0.13), 0.6)
    light = np.zeros_like(bg)
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    below = (y >= hy)[..., None]

    haze = np.exp(-((y - hy) / (h * 0.05)) ** 2)[..., None]  # haze band and purple tint above the horizon
    sky = np.exp(-np.clip(hy - y, 0, None) / (h * 0.22))[..., None] * (y < hy)[..., None]
    light += haze * (0.10 * np.array(CYAN, np.float32) + 0.07 * np.array(PURPLE, np.float32))
    light += sky * 0.05 * np.array(PURPLE, np.float32)

    # distant data towers in two rows (the far row is hazier)
    for row, (scale, alpha, bl) in enumerate([(0.55, 0.22, 1.6), (1.0, 0.5, 0.4)]):
        s, c = surface(w, h)
        ms, mc = surface(w, h)  # silhouette mask: towers hide the haze behind them
        xpos = rng.uniform(0, 20) * u
        while xpos < w:
            bw = rng.uniform(10, 46) * u * scale
            bh = rng.uniform(20, 150) * u * scale * (1.4 if rng.random() < 0.12 else 1)
            if row == 1 and abs(xpos - vx) < w * 0.06:  # keep the vanishing point open
                xpos += bw * 2
                continue
            top = hy - bh
            mc.rectangle(xpos, top, bw, bh)
            mc.set_source_rgba(1, 1, 1, 0.55 + 0.4 * row)
            mc.fill()
            c.move_to(xpos, hy)
            c.line_to(xpos, top)
            c.line_to(xpos + bw, top)
            c.line_to(xpos + bw, hy)
            c.set_source_rgba(*CYAN, alpha * 0.6)
            c.set_line_width(0.8 * u)
            c.stroke()
            step_y, step_x = 6 * u * scale + 2 * u, 5 * u * scale + 2 * u
            for wy in np.arange(top + 5 * u, hy - 3 * u, step_y):
                for wx in np.arange(xpos + 3 * u, xpos + bw - 3 * u, step_x):
                    if rng.random() < 0.18:
                        sz = 1.6 * u * (0.6 + 0.4 * row)
                        c.rectangle(wx, wy, sz, sz)
                        c.set_source_rgba(*(PURPLE if rng.random() < 0.2 else CYAN), min(1, alpha * rng.uniform(0.6, 1.2)))
                        c.fill()
            if rng.random() < 0.15:  # antenna with a beacon
                ax, ah = xpos + bw / 2, rng.uniform(10, 40) * u * scale
                c.move_to(ax, top)
                c.line_to(ax, top - ah)
                c.set_source_rgba(*CYAN, alpha * 0.7)
                c.set_line_width(0.7 * u)
                c.stroke()
                c.arc(ax, top - ah, 1.6 * u, 0, TAU)
                c.set_source_rgba(*(GREEN if rng.random() < 0.3 else CYAN), 0.9)
                c.fill()
            xpos += bw + rng.uniform(0, 30) * u * scale
        sil = blur(to_np(ms), bl * u)[..., :1]
        light *= 1 - sil * 0.9
        bg = bg * (1 - sil * 0.35)
        light += glow(blur(to_np(s), bl * u), u, 0.5)

    s, c = surface(w, h)  # finer floor grid with distance haze
    spread = w * 0.03
    for i in range(-int(w / spread * 5), int(w / spread * 5) + 1):
        bx = i * spread
        c.move_to(vx, hy)
        c.line_to(vx + bx, h * 1.05)
        c.set_source_rgba(*CYAN, 0.38 / (1 + (abs(bx) / w) ** 2 * 3))
        c.set_line_width(0.9 * u)
        c.stroke()
    for k in range(1, 60):
        t = (k / 59) ** 2.4
        yy = hy + (h - hy) * t * 1.05
        c.move_to(0, yy)
        c.line_to(w, yy)
        c.set_source_rgba(*CYAN, 0.1 + 0.45 * t)
        c.set_line_width((0.5 + 1.4 * t) * u)
        c.stroke()
    fade = np.clip((y - hy) / (h - hy), 0, 1)[..., None]
    light += glow(to_np(s) * (0.05 + 0.95 * fade) * below, u, 0.8)
    light += below * np.exp(-((y - hy) / (h * 0.025)) ** 2)[..., None] * 0.18 * np.array(CYAN, np.float32)

    s, c = surface(w, h)  # glowing horizon band: thin hot core, wider bloom
    c.move_to(0, hy)
    c.line_to(w, hy)
    c.set_source_rgba(*CYAN, 1.0)
    c.set_line_width(1.6 * u)
    c.stroke()
    band = to_np(s)
    light += band * 0.9 + blur(band, 6 * u) * 1.4 + blur(band, 30 * u) * 0.9

    # falling streaks with motion trails, at three depths
    for depth, (n, wid, al, bl) in enumerate([(160, 0.6, 0.25, 1.4), (70, 1.0, 0.5, 0.5), (18, 1.8, 0.9, 0.0)]):
        s, c = surface(w, h)
        for _ in range(int(n * w / (1920 * u))):
            x0 = rng.uniform(0, w)
            yend = rng.uniform(0.02, 0.95) * hy
            L = rng.uniform(0.06, 0.35) * hy * (0.6 + 0.3 * depth)
            r_ = rng.random()
            col = PURPLE if r_ < 0.16 else (GREEN if r_ < 0.2 else CYAN)
            g = cairo.LinearGradient(x0, yend - L, x0, yend)
            g.add_color_stop_rgba(0, *col, 0)
            g.add_color_stop_rgba(0.7, *col, al * 0.35)
            g.add_color_stop_rgba(1, *col, al)
            c.set_source(g)
            c.set_line_width(wid * u)
            c.move_to(x0, yend - L)
            c.line_to(x0, yend)
            c.stroke()
            for gk in range(rng.randint(0, 3)):  # motion ghosts above the trail
                gy = yend - L - (gk + 1) * rng.uniform(8, 20) * u
                c.move_to(x0, gy)
                c.line_to(x0, gy - rng.uniform(4, 14) * u)
                c.set_source_rgba(*col, al * 0.25 / (gk + 1))
                c.stroke()
            c.arc(x0, yend, wid * 1.6 * u, 0, TAU)  # bright head
            c.set_source_rgba(0.8, 1, 1, al * 0.8)
            c.fill()
            if depth > 0 and rng.random() < 0.3:
                c.move_to(x0, yend)
                c.line_to(x0 + rng.choice((-1, 1)) * 14 * u, yend + 14 * u)
                c.set_source_rgba(*col, al * 0.8)
                c.set_line_width(wid * u)
                c.stroke()
        light += glow(blur(to_np(s), bl * u), u, 0.5 + 0.2 * depth)

    s, c = surface(w, h)  # particle dust
    for _ in range(int(1400 * w * h / (1920 * 1080 * u * u))):
        px, py = rng.uniform(0, w), rng.uniform(0, h)
        c.arc(px, py, rng.uniform(0.4, 1.3) * u, 0, TAU)
        c.set_source_rgba(*(PURPLE if rng.random() < 0.2 else CYAN), rng.uniform(0.05, 0.3) * (0.6 if py > hy else 1))
        c.fill()
    light += blur(to_np(s), 0.5 * u)
    return bg, light


def render(variant, w, h, seed=7):
    phone = h > w
    bg, light = {"circuit": circuit, "neural": neural, "horizon": horizon}[variant](w, h, seed, phone)
    img = mark(tone(bg, light), w, h, phone)
    return dither(img, np.random.default_rng(seed))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--variant", choices=VARIANTS)
    ap.add_argument("--size", default="1920x1080")
    ap.add_argument("--out")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--variants", default=",".join(VARIANTS))
    ap.add_argument("--outdir", default=os.path.join(HERE, "..", "wallpapers"))
    a = ap.parse_args()
    if a.all:
        for v in a.variants.split(","):
            for name, (w, h) in SIZES.items():
                p = os.path.join(a.outdir, f"dexmond-{v}-{name}.png")
                render(v, w, h).save(p, optimize=True)
                print(p)
    else:
        w, h = map(int, a.size.split("x"))
        render(a.variant, w, h).save(a.out, optimize=True)
        print(a.out)
