#!/usr/bin/env python3
"""Regenerates docs/art/contact-sheet.png from the sprite code.

Usage: scripts/contact-sheet.py   (needs Swift and Pillow: pip install pillow)
"""
import os, subprocess, sys, tempfile
from PIL import Image, ImageDraw

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
dump = os.path.join(tempfile.mkdtemp(), "art.txt")
subprocess.run(["swift", "test", "--filter", "contactSheetSourceCoversEveryPose"],
               cwd=root, check=True, env={**os.environ, "PET_ART_DUMP": dump})
blocks = open(dump).read().strip().split("\n\n")
palette = {line[0]: int(line[2:], 16) for line in blocks[0].split("\n")[1:]}
poses = blocks[1:]

S, cols, label = 5, 11, 14
cell = 24 * S + 16
rows = (len(poses) + cols - 1) // cols
img = Image.new("RGB", (cols * cell, rows * (cell + label)), (246, 242, 232))
draw = ImageDraw.Draw(img)
for i, block in enumerate(poses):
    name, *grid = block.split("\n")
    ox, oy = (i % cols) * cell + 8, (i // cols) * (cell + label) + 8
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            if ch in palette:
                h = palette[ch]
                draw.rectangle([ox + x * S, oy + y * S, ox + x * S + S - 1, oy + y * S + S - 1],
                               fill=((h >> 16) & 255, (h >> 8) & 255, h & 255))
    draw.text((ox, oy + 24 * S + 2), name, fill=(40, 40, 40))
out = os.path.join(root, "docs", "art", "contact-sheet.png")
img.save(out)
print(f"wrote {out} ({len(poses)} poses)")
