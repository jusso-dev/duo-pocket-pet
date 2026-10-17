#!/usr/bin/env python3
"""Renders the 15 second demo animatic, marketing/demo/hingeling-demo-animatic.mp4.

The sprites are cropped from docs/art/contact-sheet.png, so this needs no Swift.
Needs Pillow and ffmpeg. Captions are burned in, there is no audio track.

Usage: scripts/demo-animatic.py [path/to/font.ttf]
"""
import os, subprocess, sys, tempfile
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHEET = os.path.join(ROOT, "docs", "art", "contact-sheet.png")
OUT = os.path.join(ROOT, "marketing", "demo", "hingeling-demo-animatic.mp4")
FONT = sys.argv[1] if len(sys.argv) > 1 else "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

W, H, FPS, SECONDS = 1080, 1920, 30, 15
STAGES = ["newborn", "young", "grown", "elder"]
POSES = ["asleep", "hungry", "grubby", "sleepy", "glum", "content", "joyful", "feed", "clean", "play", "stage"]
SHEET_SCALE, CELL, ROW = 5, 24 * 5 + 16, 24 * 5 + 16 + 14

# Dusk palette, from the art's own colours (docs/art.md).
DUSK_TOP, DUSK_BOTTOM = (46, 38, 74), (122, 84, 112)
SCREEN, SCREEN_EDGE, SHELL = (246, 242, 232), (34, 40, 32), (28, 30, 36)
STAGE_DARK, SPOT = (24, 22, 30), (255, 226, 140)
CAPTION_BG, CAPTION_FG = (20, 18, 28), (250, 246, 236)


def sprite(stage, pose):
    """The first frame of a pose as a 24x24 RGBA image, background made clear."""
    sheet = Image.open(SHEET).convert("RGB")
    col, row = POSES.index(pose), STAGES.index(stage)
    ox, oy = col * CELL + 8, row * ROW + 8
    bg = sheet.getpixel((2, 2))
    out = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    for y in range(24):
        for x in range(24):
            px = sheet.getpixel((ox + x * SHEET_SCALE + 2, oy + y * SHEET_SCALE + 2))
            if px != bg:
                out.putpixel((x, y), px + (255,))
    return out


def big(img, scale):
    return img.resize((img.width * scale, img.height * scale), Image.NEAREST)


def gradient():
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / (H - 1)
        d.line([(0, y), (W, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(DUSK_TOP, DUSK_BOTTOM)))
    return img


def caption(img, text, font):
    d = ImageDraw.Draw(img)
    lines = text.split("\n")
    sizes = [d.textbbox((0, 0), line, font=font) for line in lines]
    line_h = max(b[3] - b[1] for b in sizes) + 18
    box_h = line_h * len(lines) + 60
    top = H - 360
    d.rounded_rectangle([60, top, W - 60, top + box_h], radius=36, fill=CAPTION_BG)
    for i, (line, b) in enumerate(zip(lines, sizes)):
        d.text(((W - (b[2] - b[0])) / 2, top + 30 + i * line_h), line, font=font, fill=CAPTION_FG)


def paste_center(img, spr, cx, cy):
    img.paste(spr, (int(cx - spr.width / 2), int(cy - spr.height / 2)), spr)


def zzz(img, x, y, t, font):
    d = ImageDraw.Draw(img)
    for i in range(3):
        phase = (t * 0.6 + i / 3) % 1
        d.text((x + i * 34, y - phase * 120), "z", font=font, fill=(200, 190, 240))


def frame(t, sprites, fonts):
    img = gradient()
    d = ImageDraw.Draw(img)
    bob = 0 if int(t * 2) % 2 == 0 else 10

    if t < 3:
        # Closed: one compact screen.
        d.rounded_rectangle([250, 420, 830, 1260], radius=70, fill=SHELL)
        d.rounded_rectangle([280, 450, 800, 1230], radius=50, fill=SCREEN)
        paste_center(img, big(sprites["young asleep"], 14), 540, 800 + bob)
        zzz(img, 690, 640, t, fonts["z"])
        d.text((540, 1120), "Bip", font=fonts["label"], fill=SCREEN_EDGE, anchor="mm")
        caption(img, "Closed, Bip naps\non the outer screen", fonts["caption"])
    elif t < 7:
        # Open: a wide inner screen with a faint fold down the middle.
        d.rounded_rectangle([80, 380, 1000, 1300], radius=60, fill=SHELL)
        d.rounded_rectangle([110, 410, 970, 1270], radius=42, fill=SCREEN)
        d.line([(540, 430), (540, 1250)], fill=(220, 214, 200), width=4)
        pose = "young feed" if t >= 4.5 else "young content"
        paste_center(img, big(sprites[pose], 14), 325, 760 + bob)
        for i, (label, level) in enumerate([("Fullness", 0.45 if t >= 4.5 else 0.15), ("Happiness", 0.7), ("Energy", 0.8)]):
            y = 560 + i * 110
            d.text((600, y), label, font=fonts["small"], fill=SCREEN_EDGE)
            d.rounded_rectangle([600, y + 46, 930, y + 70], radius=12, fill=(220, 214, 200))
            d.rounded_rectangle([600, y + 46, 600 + int(330 * level), y + 70], radius=12, fill=(84, 130, 92))
        pressed = 4.2 <= t < 4.7
        d.rounded_rectangle([600, 960, 930, 1060], radius=28, fill=(60, 96, 70) if pressed else (84, 130, 92))
        d.text((765, 1010), "Feed", font=fonts["label"], fill=SCREEN, anchor="mm")
        caption(img, "Open it up to feed,\nclean and play", fonts["caption"])
    elif t < 11:
        # Half fold: the top half is the stage, the bottom half the audience.
        d.rounded_rectangle([140, 300, 940, 860], radius=50, fill=SHELL)
        d.rounded_rectangle([170, 330, 910, 830], radius=34, fill=STAGE_DARK)
        sway = ((t - 7) * 25) % 50 - 25
        cone = [(540 - 20, 330), (540 + 20, 330), (540 + 200 + sway * 4, 830), (540 - 200 + sway * 4, 830)]
        overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(overlay).polygon(cone, fill=SPOT + (70,))
        img.paste(overlay, (0, 0), overlay)
        paste_center(img, big(sprites["young stage"], 12), 540 + (bob - 5) * 2, 640)
        # The lower half, tilted towards the viewer.
        d.polygon([(140, 900), (940, 900), (1010, 1290), (70, 1290)], fill=SHELL)
        d.polygon([(175, 925), (905, 925), (965, 1265), (115, 1265)], fill=SCREEN)
        d.rounded_rectangle([390, 1040, 690, 1140], radius=28, fill=(150, 96, 140))
        d.text((540, 1090), "Cheer", font=fonts["label"], fill=SCREEN, anchor="mm")
        caption(img, "Half fold it and\nBip puts on a show", fonts["caption"])
    elif t < 13.5:
        d.rounded_rectangle([250, 420, 830, 1260], radius=70, fill=SHELL)
        d.rounded_rectangle([280, 450, 800, 1230], radius=50, fill=SCREEN)
        paste_center(img, big(sprites["young asleep"], 14), 540, 800 + bob)
        zzz(img, 690, 640, t, fonts["z"])
        caption(img, "Close it, and Bip\ncurls up again", fonts["caption"])
    else:
        paste_center(img, big(sprites["young joyful"], 16), 540, 760 + bob)
        d.text((540, 1120), "Hingeling", font=fonts["title"], fill=CAPTION_FG, anchor="mm")
        d.text((540, 1230), "A pocket pet that lives in the fold", font=fonts["small"], fill=CAPTION_FG, anchor="mm")
    return img


def main():
    sprites = {f"young {p}": sprite("young", p) for p in ["asleep", "content", "feed", "stage", "joyful"]}
    fonts = {
        "caption": ImageFont.truetype(FONT, 64),
        "label": ImageFont.truetype(FONT, 48),
        "small": ImageFont.truetype(FONT, 40),
        "title": ImageFont.truetype(FONT, 120),
        "z": ImageFont.truetype(FONT, 56),
    }
    tmp = tempfile.mkdtemp()
    for i in range(FPS * SECONDS):
        frame(i / FPS, sprites, fonts).save(os.path.join(tmp, f"f{i:04d}.png"))
    subprocess.run([
        "ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", os.path.join(tmp, "f%04d.png"),
        "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "20", "-movflags", "+faststart", "-an", OUT,
    ], check=True)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
