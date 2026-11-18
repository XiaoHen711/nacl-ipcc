"""Generate the NaCl IPCC app icon (1024x1024) from the reference logo."""
from PIL import Image, ImageDraw, ImageFont
import sys

OUT = sys.argv[1]
S = 1024
BG = (10, 15, 12)
CENTER = (30, 74, 50)
EDGE = (12, 28, 20)
RING = (62, 148, 102)
MINT = (93, 230, 158)
MINT_DIM = (74, 200, 138)

img = Image.new("RGB", (S, S), BG)
d = ImageDraw.Draw(img)

R = 462
cx = cy = S // 2

# soft outer glow
glow = Image.new("RGB", (S, S), (0, 0, 0))
gd = ImageDraw.Draw(glow)
for w in range(26, 0, -1):
    a = int(70 * (1 - w / 26.0))
    gd.ellipse([cx - R - w, cy - R - w, cx + R + w, cy + R + w], outline=(a // 2, a, int(a * 0.7)))
img = Image.blend(img, glow, 0.55)
d = ImageDraw.Draw(img)

for r in range(R, 0, -1):
    t = r / R
    col = tuple(int(CENTER[i] + (EDGE[i] - CENTER[i]) * t) for i in range(3))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)

d.ellipse([cx - R, cy - R, cx + R, cy + R], outline=RING, width=7)

f_big = ImageFont.truetype(r"C:\Windows\Fonts\ariblk.ttf", 224)
f_small = ImageFont.truetype(r"C:\Windows\Fonts\arialbd.ttf", 100)


def center_text(ctx, text, font, y, fill, tracking=0):
    if tracking == 0:
        w = ctx.textlength(text, font=font)
        ctx.text((cx - w / 2, y), text, font=font, fill=fill)
        return
    widths = [ctx.textlength(ch, font=font) for ch in text]
    total = sum(widths) + tracking * (len(text) - 1)
    x = cx - total / 2
    for ch, w in zip(text, widths):
        ctx.text((x, y), ch, font=font, fill=fill)
        x += w + tracking


glow = Image.new("RGB", (S, S), (0, 0, 0))
gd = ImageDraw.Draw(glow)
center_text(gd, "NaCl", f_big, 330, MINT)
center_text(gd, "IPCC", f_small, 620, MINT_DIM, tracking=22)
glow = glow.filter(__import__("PIL.ImageFilter", fromlist=["ImageFilter"]).GaussianBlur(22))
img = Image.blend(img, glow, 0.40)

d = ImageDraw.Draw(img)
center_text(d, "NaCl", f_big, 330, MINT)
center_text(d, "IPCC", f_small, 620, MINT_DIM, tracking=22)

img.save(OUT, "PNG")
print("wrote", OUT, img.size)
