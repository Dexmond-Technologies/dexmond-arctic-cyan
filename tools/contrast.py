#!/usr/bin/env python3
"""WCAG 2.x contrast ratios for the Dexmond Arctic Cyan colour pairs.
Translucent colours are first composited over the background they sit on.
Run: python3 tools/contrast.py   (prints a Markdown table)"""

def rgb(h):
    h = h.lstrip('#'); return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

def over(fg, alpha, bg):
    return '#%02x%02x%02x' % tuple(round(alpha * f + (1 - alpha) * b) for f, b in zip(rgb(fg), rgb(bg)))

def lum(h):
    def ch(c):
        c /= 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (ch(c) for c in rgb(h))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b

def ratio(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)

PAIRS = [
    # (what, text, background, minimum)  minimum 4.5 = body text, 3.0 = large/bold text or UI parts, 0 = exempt
    ("Body text on window", "#d8f5ff", "#070912", 4.5),
    ("Text in lists and views", "#d0efff", "#05070d", 4.5),
    ("Text in sidebars", "#d8f5ff", "#080d19", 4.5),
    ("Text on cards, menus, popovers", "#d8f5ff", "#0c1424", 4.5),
    ("Button text", "#d8f5ff", "#0e1a2b", 4.5),
    ("Button text, hover", "#ffffff", "#13263a", 4.5),
    ("Checked button text", "#00f5ff", "#0b3644", 4.5),
    ("Secondary / backdrop text on window", "#8fb0c6", "#070912", 4.5),
    ("Secondary text on cards", "#8fb0c6", "#0c1424", 4.5),
    ("Header bar title (cyan)", "#00f5ff", "#0a1b2a", 4.5),
    ("Header bar title, window in backdrop", "#7fa6bd", "#07121c", 4.5),
    ("Selected row text (focused)", "#03121a", "#00c8d4", 4.5),
    ("Selected row text (window in backdrop)", "#cfefff", "#0b3644", 4.5),
    ("Text selection (cyan 35% over view)", "#ffffff", over("#00f5ff", 0.35, "#05070d"), 4.5),
    ("Suggested button text", "#03121a", "#00f5ff", 4.5),
    ("Suggested button text (gradient end)", "#03121a", "#00b3d6", 4.5),
    ("Destructive button text", "#ffffff", "#a8155f", 4.5),
    ("Links", "#5ce1ff", "#05070d", 4.5),
    ("Visited links", "#b48cff", "#05070d", 4.5),
    ("Error text", "#ff5ca8", "#05070d", 4.5),
    ("Warning text", "#ffd24d", "#05070d", 4.5),
    ("Success text", "#3ef0a0", "#05070d", 4.5),
    ("Tooltip text", "#d8f5ff", over("#03060c", 0.96, "#070912"), 4.5),
    ("Column header text", "#8fb0c6", "#080f1a", 4.5),
    ("Libadwaita accent text (accent_color)", "#00f5ff", "#070912", 4.5),
    ("Libadwaita accent button text", "#03121a", "#00c8d4", 4.5),
    ("Terminal text", "#e6f1ff", "#070812", 4.5),
    ("Editor comments", "#7f9db3", "#05070d", 4.5),
    ("Editor line numbers", "#5d7689", "#070912", 3.0),
    ("Disabled text (exempt under WCAG 1.4.3)", "#5d7689", "#070912", 0),
]

if __name__ == "__main__":
    print("| Pair | Text | Background | Ratio | Needs | Result |")
    print("|---|---|---|---|---|---|")
    bad = 0
    for what, fg, bg, need in PAIRS:
        r = ratio(fg, bg)
        ok = r >= need
        bad += not ok
        print(f"| {what} | `{fg}` | `{bg}` | {r:.2f}:1 | {need if need else 'exempt'} | {'pass' if ok else 'FAIL'} |")
    raise SystemExit(1 if bad else 0)
