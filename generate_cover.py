import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont


W, H = 2560, 1280
CORNER_RADIUS = 80
HERE = os.path.dirname(os.path.abspath(__file__))


def ellipse_layer(size, color, cx, cy, rx, ry, blur):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=color)
    return layer.filter(ImageFilter.GaussianBlur(radius=blur))


def load_font(path, size, index=0):
    try:
        return ImageFont.truetype(path, size, index=index)
    except Exception:
        return ImageFont.truetype("/System/Library/Fonts/Supplemental/Courier New Bold.ttf", size)


def centered_text_position(draw, text, font, y):
    bbox = draw.textbbox((0, 0), text, font=font)
    return (W - (bbox[2] - bbox[0])) // 2 - bbox[0], y - bbox[1]


def text_layer(text, x, y, font, color):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(layer).text((x, y), text, font=font, fill=color)
    return layer


canvas = Image.new("RGBA", (W, H), (8, 12, 18, 255))

for spec in [
    ((25, 118, 148, 190), 620, 600, 760, 500, 120),
    ((79, 156, 211, 145), 1920, 220, 620, 410, 105),
    ((16, 44, 64, 185), 1280, 1150, 920, 360, 95),
    ((115, 91, 176, 120), 1520, 650, 530, 360, 85),
    ((218, 152, 83, 72), 280, 1050, 620, 410, 100),
]:
    canvas = Image.alpha_composite(canvas, ellipse_layer((W, H), *spec))

canvas = canvas.filter(ImageFilter.GaussianBlur(radius=8))

rng = np.random.default_rng(42)
noise = rng.integers(0, 255, (H, W), dtype=np.uint8)
alpha = (noise * 0.20).astype(np.uint8)
grain = Image.fromarray(np.stack([noise, noise, noise, alpha], axis=-1).astype(np.uint8), "RGBA")
canvas = Image.alpha_composite(canvas, grain)

menlo = "/System/Library/Fonts/Menlo.ttc"
font_title = load_font(menlo, 192, index=1)
font_subtitle = load_font(menlo, 52)
font_prompt = load_font(menlo, 42)

draw = ImageDraw.Draw(canvas)
title = "pretty-claude-hud"
subtitle = "Readable statusline for Claude Code. Context and rate limits stay visible."
prompt = "O4.8 | ctx ███▄░░ 58%/1000k | 5h [██░░░]42% | 1w [███░░]63% | git main ✓"

title_x, title_y = centered_text_position(draw, title, font_title, 426)
subtitle_x, subtitle_y = centered_text_position(draw, subtitle, font_subtitle, 674)

for color, blur in [
    ((88, 214, 255, 55), 18),
    ((122, 232, 255, 82), 9),
    ((190, 246, 255, 120), 4),
]:
    glow = text_layer(title, title_x, title_y, font_title, color).filter(ImageFilter.GaussianBlur(radius=blur))
    canvas = Image.alpha_composite(canvas, glow)

canvas = Image.alpha_composite(canvas, text_layer(title, title_x, title_y, font_title, (255, 255, 255, 245)))
canvas = Image.alpha_composite(canvas, text_layer(subtitle, subtitle_x, subtitle_y, font_subtitle, (180, 214, 224, 216)))

terminal = Image.new("RGBA", (W, H), (0, 0, 0, 0))
td = ImageDraw.Draw(terminal)
box = (310, 820, 2250, 1010)
td.rounded_rectangle(box, radius=38, fill=(6, 10, 16, 190), outline=(150, 215, 230, 82), width=2)
td.text((365, 879), prompt, font=font_prompt, fill=(116, 220, 248, 235))
canvas = Image.alpha_composite(canvas, terminal)

mask = Image.new("L", (W, H), 0)
ImageDraw.Draw(mask).rounded_rectangle([(0, 0), (W - 1, H - 1)], radius=CORNER_RADIUS, fill=255)
canvas.putalpha(mask)
canvas = canvas.filter(ImageFilter.GaussianBlur(radius=1))

out_path = os.path.join(HERE, "cover.png")
canvas.save(out_path, "PNG", dpi=(400, 400))
print(f"Saved: {out_path}")
print(f"Size: {canvas.size}")
