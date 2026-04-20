#!/usr/bin/env python3
"""
ExpiryVault 1024x1024 app icon.
Flat trust-blue vault/shield with a subtle calendar glyph. No transparency,
no text, no Apple device imagery, square (iOS rounds the corners). Passes
App Store Connect 1024x1024 rules and is legible at 60x60.
"""
from PIL import Image, ImageDraw
from pathlib import Path

SIZE = 1024
OUT = Path(__file__).resolve().parent.parent / "ExpiryVault" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"
OUT.mkdir(parents=True, exist_ok=True)


def background():
    # Deep trust blue radial → soft top-left highlight.
    img = Image.new("RGB", (SIZE, SIZE), (22, 49, 110))
    px = img.load()
    cx, cy = SIZE * 0.36, SIZE * 0.30
    max_r = ((SIZE * 0.9) ** 2 + (SIZE * 0.9) ** 2) ** 0.5
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = x - cx, y - cy
            r = (dx * dx + dy * dy) ** 0.5 / max_r
            t = max(0.0, 1.0 - r)
            r8 = int(22 + (87 - 22) * (t ** 1.4))
            g8 = int(49 + (135 - 49) * (t ** 1.4))
            b8 = int(110 + (215 - 110) * (t ** 1.2))
            px[x, y] = (r8, g8, b8)
    return img


def draw_shield(img):
    d = ImageDraw.Draw(img)
    cx, cy = SIZE // 2, SIZE // 2 + 40
    # Shield outline — tall rounded pentagon
    width = 520
    top = cy - 340
    bottom = cy + 340
    half = width // 2
    # Approximate shield with polygon + wide bottom curve
    pts = [
        (cx - half, top + 30),
        (cx + half, top + 30),
        (cx + half, cy + 20),
        (cx, bottom),
        (cx - half, cy + 20),
    ]
    d.polygon(pts, fill=(255, 255, 255))
    # Inner fill
    inset = 28
    inner = [
        (cx - half + inset, top + 30 + inset),
        (cx + half - inset, top + 30 + inset),
        (cx + half - inset, cy + 20 - 4),
        (cx, bottom - inset * 1.2),
        (cx - half + inset, cy + 20 - 4),
    ]
    d.polygon(inner, fill=(23, 82, 165))


def draw_calendar(img):
    d = ImageDraw.Draw(img)
    cx, cy = SIZE // 2, SIZE // 2 + 30
    # Calendar block, white, centered, with two header pegs and a grid of 9 cells.
    w, h = 340, 320
    x0, y0 = cx - w // 2, cy - h // 2
    x1, y1 = x0 + w, y0 + h
    d.rounded_rectangle([x0, y0, x1, y1], radius=32, fill=(255, 255, 255))
    # Header band
    header_h = 78
    d.rounded_rectangle([x0, y0, x1, y0 + header_h], radius=32, fill=(255, 124, 46))
    # Square out the bottom of the header (paint over the bottom half of the rounded part)
    d.rectangle([x0, y0 + header_h - 32, x1, y0 + header_h], fill=(255, 124, 46))
    # Header pegs
    peg_w, peg_h = 22, 42
    peg_y = y0 - 16
    d.rounded_rectangle([x0 + 64, peg_y, x0 + 64 + peg_w, peg_y + peg_h], radius=11, fill=(255, 255, 255))
    d.rounded_rectangle([x1 - 64 - peg_w, peg_y, x1 - 64, peg_y + peg_h], radius=11, fill=(255, 255, 255))

    # Grid of day dots — 3×3, highlight one
    grid_x0 = x0 + 44
    grid_y0 = y0 + header_h + 30
    cell_w = (w - 88) // 3
    cell_h = (h - header_h - 60) // 3
    highlight = (1, 2)  # row 1, col 2 (the "upcoming" day)
    for row in range(3):
        for col in range(3):
            cx2 = grid_x0 + col * cell_w + cell_w // 2
            cy2 = grid_y0 + row * cell_h + cell_h // 2
            r = 18
            if (row, col) == highlight:
                d.ellipse([cx2 - r - 4, cy2 - r - 4, cx2 + r + 4, cy2 + r + 4], fill=(255, 124, 46))
            else:
                d.ellipse([cx2 - r, cy2 - r, cx2 + r, cy2 + r], fill=(210, 220, 235))


def main():
    img = background()
    draw_shield(img)
    draw_calendar(img)
    icon = OUT / "icon-1024.png"
    img.save(icon, "PNG")
    (OUT / "Contents.json").write_text(
        '{\n  "images": [\n    { "size": "1024x1024", "idiom": "universal", '
        '"filename": "icon-1024.png", "platform": "ios" }\n  ],\n  '
        '"info": { "version": 1, "author": "xcode" }\n}\n'
    )
    print(f"wrote {icon}")


if __name__ == "__main__":
    main()
