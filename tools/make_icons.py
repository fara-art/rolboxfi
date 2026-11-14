# Draws the star icons (original art, no licensing issues). Run: python3 tools/make_icons.py
import math, pathlib
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

S = 1024  # draw big, downscale for smooth edges
OUT = 256
root = pathlib.Path(__file__).resolve().parent.parent / "assets" / "icons"
root.mkdir(parents=True, exist_ok=True)
yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
C = S / 2

def layer():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))

def glow(img, color, radius, strength=1.0, cx=C, cy=C):
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / radius
    a = np.clip(np.exp(-d * d * 2.2) * 255 * strength, 0, 255).astype(np.uint8)
    g = np.zeros((S, S, 4), np.uint8)
    g[..., 0], g[..., 1], g[..., 2], g[..., 3] = color[0], color[1], color[2], a
    return Image.alpha_composite(img, Image.fromarray(g, "RGBA"))

def sphere(img, cx, cy, r, dark, light, rim=None):
    # shaded ball: light from top-left
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    inside = d <= r
    hx, hy = cx - r * 0.35, cy - r * 0.4
    t = np.clip(np.sqrt((xx - hx) ** 2 + (yy - hy) ** 2) / (r * 1.5), 0, 1)
    out = np.zeros((S, S, 4), np.float32)
    for i in range(3):
        out[..., i] = light[i] * (1 - t) + dark[i] * t
    edge = np.clip((r - d) / 3, 0, 1)
    out[..., 3] = edge * 255
    if rim:
        rr = np.clip(1 - np.abs(d - r * 0.97) / (r * 0.06), 0, 1) * inside
        for i in range(3):
            out[..., i] = out[..., i] * (1 - rr * 0.6) + rim[i] * rr * 0.6
    return Image.alpha_composite(img, Image.fromarray(out.astype(np.uint8), "RGBA"))

def poly(img, points, color, blur=0):
    l = layer()
    ImageDraw.Draw(l).polygon(points, fill=color)
    if blur:
        l = l.filter(ImageFilter.GaussianBlur(blur))
    return Image.alpha_composite(img, l)

def ellipse(img, box, color=None, outline=None, width=1, blur=0, angle=0):
    l = layer()
    ImageDraw.Draw(l).ellipse(box, fill=color, outline=outline, width=width)
    if angle:
        l = l.rotate(angle, resample=Image.BICUBIC, center=(C, C))
    if blur:
        l = l.filter(ImageFilter.GaussianBlur(blur))
    return Image.alpha_composite(img, l)

def spikes(img, n, inner, outer, color, rot=0, cx=C, cy=C, blur=0):
    pts = []
    for i in range(n * 2):
        a = rot + i * math.pi / n
        r = outer if i % 2 == 0 else inner
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return poly(img, pts, color, blur)

def save(img, name):
    img.resize((OUT, OUT), Image.LANCZOS).save(root / f"{name}.png")

# 1 Stardust: drifting cluster of soft motes
img = layer()
rng = np.random.default_rng(7)
img = glow(img, (200, 200, 255), 330, 0.35)
for _ in range(16):
    x, y = rng.normal(C, 150), rng.normal(C, 150)
    r = rng.uniform(14, 40)
    img = glow(img, (235, 235, 255), r * 2.2, 0.8, x, y)
    img = ellipse(img, (x - r / 2, y - r / 2, x + r / 2, y + r / 2), (255, 255, 255, 255))
save(img, "dust")

# 2 Spark: four-point twinkle
img = layer()
img = glow(img, (255, 236, 170), 300, 0.7)
img = spikes(img, 4, 60, 430, (255, 240, 190, 140), blur=18)
img = spikes(img, 4, 45, 400, (255, 252, 235, 255))
img = spikes(img, 4, 25, 200, (255, 255, 255, 255), rot=math.pi / 4)
img = glow(img, (255, 255, 255), 90, 1)
save(img, "spark")

# 3 Red Dwarf: small warm ember
img = layer()
img = glow(img, (255, 80, 50), 360, 0.75)
img = sphere(img, C, C, 230, (150, 20, 20), (255, 170, 110), rim=(255, 120, 80))
save(img, "dwarf")

# 4 Yellow Sun: rays + bright disc
img = layer()
img = glow(img, (255, 200, 60), 420, 0.8)
img = spikes(img, 14, 260, 470, (255, 196, 60, 255), rot=0.1)
img = spikes(img, 14, 260, 420, (255, 226, 110, 255), rot=0.1 + math.pi / 14)
img = sphere(img, C, C, 270, (240, 140, 20), (255, 248, 190))
save(img, "sun")

# 5 Blue Giant: big glowing sphere
img = layer()
img = glow(img, (80, 160, 255), 470, 0.9)
img = sphere(img, C, C, 380, (20, 70, 200), (190, 235, 255), rim=(160, 220, 255))
save(img, "giant")

# 6 Pulsar: beams + core
img = layer()
img = glow(img, (170, 90, 255), 380, 0.6)
for flip in (1, -1):
    img = poly(img, [(C - 30, C), (C + 30, C), (C + 120, C - flip * 500), (C - 120, C - flip * 500)], (210, 160, 255, 150), blur=25)
    img = poly(img, [(C - 12, C), (C + 12, C), (C + 45, C - flip * 500), (C - 45, C - flip * 500)], (250, 235, 255, 255), blur=4)
img = sphere(img, C, C, 150, (110, 40, 220), (240, 220, 255))
save(img, "pulsar")

# 7 Neutron Star: tiny blazing core with field rings
img = layer()
img = glow(img, (90, 255, 220), 400, 0.55)
for k, ang in enumerate((25, -25, 90)):
    img = ellipse(img, (C - 430, C - 140, C + 430, C + 140), outline=(140, 255, 230, 220), width=16, blur=3, angle=ang)
img = glow(img, (220, 255, 250), 180, 1)
img = sphere(img, C, C, 95, (60, 220, 200), (255, 255, 255))
save(img, "neutron")

# 8 Quasar: accretion disk + jets
img = layer()
img = glow(img, (255, 80, 200), 420, 0.6)
for flip in (1, -1):
    img = poly(img, [(C - 18, C), (C + 18, C), (C + 70, C - flip * 510), (C - 70, C - flip * 510)], (255, 200, 245, 200), blur=12)
img = ellipse(img, (C - 470, C - 120, C + 470, C + 120), (255, 90, 190, 210), blur=10, angle=-18)
img = ellipse(img, (C - 360, C - 80, C + 360, C + 80), (255, 190, 120, 230), blur=8, angle=-18)
img = ellipse(img, (C - 200, C - 45, C + 200, C + 45), (255, 245, 220, 255), blur=5, angle=-18)
img = glow(img, (255, 255, 255), 120, 1)
save(img, "quasar")

# 9 Supernova: layered burst
img = layer()
img = glow(img, (255, 210, 120), 480, 0.9)
img = spikes(img, 16, 200, 500, (255, 120, 80, 200), rot=0.2, blur=6)
img = spikes(img, 12, 180, 450, (255, 200, 90, 255), rot=0.5)
img = spikes(img, 8, 150, 380, (255, 250, 220, 255), rot=0.1)
img = glow(img, (255, 255, 255), 220, 1)
img = ellipse(img, (C - 110, C - 110, C + 110, C + 110), (255, 255, 255, 255))
save(img, "supernova")
print("icons ->", root)
