#!/usr/bin/env python3
"""Renders docs/ui/mockup.png, a picture of the retro UI for review.

It reads the pixel font, icons and palette straight from the Swift sources and
the sprites from docs/art/contact-sheet.png, so it stays in step with the code
without needing Swift. It is a design aid: the app itself is the SwiftUI code.

Usage: scripts/ui-mockup.py   (needs Pillow)
"""
import os, re
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RETRO = os.path.join(ROOT, "Sources", "PocketPetCore", "Retro")
OUT = os.path.join(ROOT, "docs", "ui", "mockup.png")


def parse_font():
    src = open(os.path.join(RETRO, "PixelFont.swift")).read()
    glyphs = {}
    for ch, body in re.findall(r'^\s*"(.|\\")": \[(.*?)\],$', src, re.M):
        glyphs[ch] = re.findall(r'"([.#]+)"', body)
    return glyphs


def parse_icons():
    src = open(os.path.join(RETRO, "PixelIcons.swift")).read()
    icons = {}
    for name, body in re.findall(r"case \.(\w+): \[(.*?)\]", src, re.S):
        icons[name] = re.findall(r'"([.#]+)"', body)
    return icons


def parse_palette(name):
    src = open(os.path.join(RETRO, "RetroPalette.swift")).read()
    block = re.search(rf"static let {name} = RetroPalette\((.*?)\n    \)", src, re.S).group(1)
    return {k: tuple(int(v[i:i + 2], 16) for i in (0, 2, 4)) for k, v in re.findall(r"(\w+): hex\(0x([0-9A-F]{6})\)", block)}


FONT, ICONS = parse_font(), parse_icons()
STAGES = ["newborn", "young", "grown", "elder"]
POSES = ["asleep", "hungry", "grubby", "sleepy", "glum", "content", "joyful", "feed", "clean", "play", "stage"]


def sprite(stage, pose):
    sheet = Image.open(os.path.join(ROOT, "docs", "art", "contact-sheet.png")).convert("RGB")
    ox, oy = POSES.index(pose) * 136 + 8, STAGES.index(stage) * 150 + 8
    bg = sheet.getpixel((2, 2))
    out = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    for y in range(24):
        for x in range(24):
            px = sheet.getpixel((ox + x * 5 + 2, oy + y * 5 + 2))
            if px != bg:
                out.putpixel((x, y), px + (255,))
    return out


def with_halo(spr, colour):
    """Adds the one-pixel glowing edge the app draws on the dark backlight LCD."""
    out = spr.copy()
    for y in range(spr.height):
        for x in range(spr.width):
            if spr.getpixel((x, y))[3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < spr.width and 0 <= ny < spr.height and spr.getpixel((nx, ny))[3]:
                    out.putpixel((x, y), colour + (140,))
                    break
    return out


def bits(rows, img, x, y, s, colour):
    d = ImageDraw.Draw(img)
    for r, row in enumerate(rows):
        for c, ch in enumerate(row):
            if ch == "#":
                d.rectangle([x + c * s, y + r * s, x + c * s + s - 1, y + r * s + s - 1], fill=colour)


def text(img, s, x, y, scale, colour, centre_width=None):
    s = s.upper()
    width = len(s) * 6 * scale - scale
    if centre_width:
        x += (centre_width - width) // 2
    for i, ch in enumerate(s):
        if ch != " ":
            bits(FONT.get(ch, FONT["?"]), img, x + i * 6 * scale, y, scale, colour)
    return width


def body_text(img, s, x, y, colour, size=15):
    # Stand-in for the system monospaced font used for sentences.
    from PIL import ImageFont
    try:
        f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", size)
    except OSError:
        f = ImageFont.load_default()
    ImageDraw.Draw(img).text((x, y), s, font=f, fill=colour)


def gradient(img, box, top, bottom):
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        t = (y - y0) / max(1, y1 - y0 - 1)
        d.line([(x0, y), (x1, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)))


def stepped(img, box, fill, step=4):
    """A rectangle with stepped pixel corners."""
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = box
    d.rectangle([x0 + step, y0, x1 - step, y1], fill=fill)
    d.rectangle([x0, y0 + step, x1, y1 - step], fill=fill)
    d.rectangle([x0 + step // 2, y0 + step // 2, x1 - step // 2, y1 - step // 2], fill=fill)


def lcd(img, box, p):
    x0, y0, x1, y1 = box
    stepped(img, (x0 - 8, y0 - 8, x1 + 8, y1 + 8), p["bezel"])
    ImageDraw.Draw(img).rectangle([x0 - 8 + 4, y0 - 8 + 2, x1 + 8 - 4, y0 - 8 + 3], fill=p["bezelHighlight"])
    stepped(img, box, p["lcd"], step=2)
    d = ImageDraw.Draw(img)
    for y in range(y0 + 3, y1 - 2, 4):
        for x in range(x0 + 3, x1 - 2, 4):
            d.rectangle([x, y, x + 2, y + 2], fill=p["lcdGhost"])


def keycap(img, box, label, icon, p, pressed=False):
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    stepped(img, (x0, y0, x1, y1), p["keycapShadow"])
    face = (x0, y0, x1 - 4, y1 - 4) if not pressed else (x0 + 2, y0 + 2, x1 - 2, y1 - 2)
    stepped(img, face, p["keycap"])
    d.rectangle([face[0] + 4, face[1] + 2, face[2] - 4, face[1] + 3], fill=p["keycapHighlight"])
    w = 9 * 3 + 8 + (len(label) * 6 - 1) * 2
    cx = face[0] + (face[2] - face[0] - w) // 2
    cy = face[1] + (face[3] - face[1]) // 2
    bits(ICONS[icon], img, cx, cy - 13, 3, p["keycapInk"])
    text(img, label, cx + 35, cy - 7, 2, p["keycapInk"])


def meter(img, x, y, icon, label, value, p):
    bits(ICONS[icon], img, x, y, 2, p["ink"])
    text(img, label, x + 26, y + 2, 2, p["ink"])
    lit = max(1, round(value * 8)) if value > 0 else 0
    for i in range(8):
        sx = x + 150 + i * 18
        ImageDraw.Draw(img).rectangle([sx, y, sx + 13, y + 16], fill=p["ink"] if i < lit else p["lcdGhost"])


def phone(p, scene, dark):
    W, H = 390, 844

    def pet(stage, pose, scale):
        spr = sprite(stage, pose)
        if dark:
            spr = with_halo(spr, p["inkSoft"])
        return spr.resize((24 * scale, 24 * scale), Image.NEAREST)
    img = Image.new("RGB", (W, H))
    gradient(img, (0, 0, W, H), p["backdropTop"], p["backdropBottom"])
    if scene == "home":
        # Status strip
        text(img, "BIP", 20, 64, 3, p["backdropInk"])
        text(img, "YOUNG  DAY 3", 120, 70, 2, p["backdropInk"])
        bits(ICONS["attention"], img, 340, 64, 3, p["backdropInk"])
        lcd(img, (28, 112, 362, 400), p)
        spr = pet("young", "hungry", 9)
        img.paste(spr, (87, 128), spr)
        bits(ICONS["attention"], img, 272, 134, 4, p["alert"])
        text(img, "BIP IS HUNGRY", 28, 368, 2, p["ink"], centre_width=334)
        lcd(img, (28, 432, 362, 584), p)
        for i, (icon, label, v) in enumerate([("bowl", "FULL", 0.1), ("smile", "HAPPY", 0.6), ("bolt", "ENERGY", 0.8), ("bubbles", "CLEAN", 1.0)]):
            meter(img, 44, 446 + i * 34, icon, label, v, p)
        keys = [("FEED", "bowl"), ("CLEAN", "bubbles"), ("PLAY", "ball"), ("BEDTIME", "moon")]
        for i, (label, icon) in enumerate(keys):
            col, row = i % 2, i // 2
            keycap(img, (20 + col * 180, 612 + row * 92, 190 + col * 180, 692 + row * 92), label, icon, p, pressed=(i == 0))
    elif scene == "glance":
        lcd(img, (24, 150, 366, 690), p)
        spr = pet("young", "asleep", 10)
        img.paste(spr, (75, 210), spr)
        text(img, "BIP", 24, 500, 5, p["ink"], centre_width=342)
        text(img, "YOUNG", 24, 560, 2, p["inkSoft"], centre_width=342)
        bits(ICONS["moon"], img, 120, 604, 2, p["ink"])
        text(img, "FAST ASLEEP", 146, 606, 2, p["ink"])
    elif scene == "stage":
        lcd(img, (24, 70, 366, 400), p)
        d = ImageDraw.Draw(img)
        for side in (0, 1):  # pleated curtains
            for x in range(0, 36, 6):
                cx = 24 + x if side == 0 else 366 - x - 3
                d.rectangle([cx, 70, cx + 2, 400], fill=p["bezelHighlight"])
        for y in range(70, 360, 4):
            half = 20 + (y - 70) * 0.45
            for x in range(int(195 - half), int(195 + half), 4):
                if (x // 4 + y // 4) % 2 == 0:
                    d.rectangle([x, y, x + 1, y + 1], fill=p["lcdGhost"])
        spr = pet("young", "stage", 8)
        img.paste(spr, (99, 150), spr)
        text(img, "BIP IS DANCING", 24, 366, 2, p["ink"], centre_width=342)
        d.rectangle([0, 430, W, 436], fill=p["bezel"])  # the fold
        keycap(img, (95, 520, 295, 610), "CHEER", "burst", p)
        body_text(img, "Bip loved that.", 120, 630, p["backdropInk"])
        bits(ICONS["pair"], img, 40, 700, 2, p["backdropInk"])
        text(img, "MEET NEARBY PETS", 70, 702, 2, p["backdropInk"])
    return img


def main():
    shots = [("home", "daylight"), ("home", "backlight"), ("glance", "backlight"), ("stage", "daylight")]
    pad = 24
    sheet = Image.new("RGB", (len(shots) * (390 + pad) + pad, 844 + 2 * pad), (240, 236, 228))
    for i, (scene, pal) in enumerate(shots):
        sheet.paste(phone(parse_palette(pal), scene, pal == "backlight"), (pad + i * (390 + pad), pad))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sheet.save(OUT)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
