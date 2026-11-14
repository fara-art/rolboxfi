# Cartoon icon set: thick dark outline, glossy gradient fill, sparkles.
# Original art (no third-party images). Run: python3 tools/make_icons.py
import math, pathlib
from PIL import Image, ImageDraw, ImageFilter, ImageChops

S = 1024
OUT = 256
root = pathlib.Path(__file__).resolve().parent.parent / "assets" / "icons"
root.mkdir(parents=True, exist_ok=True)
INK = (26, 28, 48)


def blank(mode="RGBA"):
    return Image.new(mode, (S, S), 0 if mode == "L" else (0, 0, 0, 0))


def gradient(top, bottom, box):
    x0, y0, x1, y1 = box
    g = Image.new("RGBA", (S, S))
    d = ImageDraw.Draw(g)
    h = max(1, y1 - y0)
    for y in range(S):
        t = min(1, max(0, (y - y0) / h))
        c = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3)) + (255,)
        d.line([(0, y), (S, y)], fill=c)
    return g


def dilate(mask, px):
    return mask.filter(ImageFilter.GaussianBlur(px / 2)).point(lambda v: 255 if v > 6 else 0)


def shape(img, draw_fn, top, bottom, outline=28, gloss=True, shadow=True, ink=INK):
    """draw_fn(draw) paints the silhouette in white on an L mask."""
    mask = blank("L")
    draw_fn(ImageDraw.Draw(mask))
    box = mask.getbbox()
    if not box:
        return img
    ring = dilate(mask, outline)
    if shadow:
        sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        sh.paste((10, 20, 40, 90), (0, 0), ring)
        img = Image.alpha_composite(img, ImageChops.offset(sh, 10, 16))
    edge = Image.new("RGBA", (S, S), ink + (255,))
    edge.putalpha(ring)
    img = Image.alpha_composite(img, edge)
    fill = gradient(top, bottom, box)
    fill.putalpha(mask)
    img = Image.alpha_composite(img, fill)
    if gloss:
        x0, y0, x1, y1 = box
        w, h = x1 - x0, y1 - y0
        g = blank("L")
        ImageDraw.Draw(g).ellipse((x0 + w * 0.14, y0 + h * 0.08, x0 + w * 0.62, y0 + h * 0.42), fill=120)
        g = ImageChops.multiply(g.filter(ImageFilter.GaussianBlur(10)), mask)
        shine = Image.new("RGBA", (S, S), (255, 255, 255, 255))
        shine.putalpha(g)
        img = Image.alpha_composite(img, shine)
    return img


def star_points(cx, cy, outer, inner, n=5, rot=-math.pi / 2):
    pts = []
    for i in range(n * 2):
        a = rot + i * math.pi / n
        r = outer if i % 2 == 0 else inner
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def sparkle(img, cx, cy, r):
    return shape(img, lambda d: d.polygon(star_points(cx, cy, r, r * 0.3, 4), fill=255),
                 (255, 255, 255), (220, 240, 255), outline=max(8, r * 0.18), gloss=False, shadow=False)


def save(img, name):
    img.resize((OUT, OUT), Image.LANCZOS).save(root / f"{name}.png")
    return img


C = S / 2
icons = {}

# ---------------- stars
img = blank()
for (x, y, r) in [(380, 600, 170), (650, 420, 150), (640, 720, 110)]:
    img = shape(img, lambda d, x=x, y=y, r=r: d.polygon(star_points(x, y, r, r * 0.5), fill=255), (235, 230, 255), (170, 160, 230), outline=26)
icons["dust"] = save(sparkle(img, 300, 300, 60), "dust")

img = shape(blank(), lambda d: d.polygon(star_points(C, C, 420, 110, 4), fill=255), (255, 252, 220), (255, 214, 90), outline=30)
icons["spark"] = save(sparkle(img, 760, 250, 70), "spark")

img = shape(blank(), lambda d: d.ellipse((190, 190, 834, 834), fill=255), (255, 140, 110), (200, 40, 50), outline=30)
icons["dwarf"] = save(sparkle(img, 780, 240, 60), "dwarf")

img = shape(blank(), lambda d: d.polygon(star_points(C, C, 470, 330, 12, 0), fill=255), (255, 200, 80), (255, 140, 30), outline=28)
img = shape(img, lambda d: d.ellipse((250, 250, 774, 774), fill=255), (255, 248, 170), (255, 190, 40), outline=24)
icons["sun"] = save(img, "sun")

img = shape(blank(), lambda d: d.ellipse((120, 120, 904, 904), fill=255), (150, 220, 255), (40, 100, 230), outline=32)
icons["giant"] = save(sparkle(img, 800, 200, 70), "giant")

img = shape(blank(), lambda d: (d.polygon([(470, 512), (554, 512), (640, 40), (384, 40)], fill=255), d.polygon([(470, 512), (554, 512), (640, 984), (384, 984)], fill=255)),
            (240, 225, 255), (190, 150, 255), outline=24, gloss=False)
img = shape(img, lambda d: d.ellipse((290, 290, 734, 734), fill=255), (200, 150, 255), (110, 50, 210), outline=28)
icons["pulsar"] = save(img, "pulsar")

img = blank()
for ang in (30, -30):
    ring = blank("L")
    ImageDraw.Draw(ring).ellipse((80, 340, 944, 684), outline=255, width=46)
    ring = ring.rotate(ang, resample=Image.BICUBIC, center=(C, C))
    img = shape(img, lambda d, ring=ring: d.bitmap((0, 0), ring, fill=255), (170, 255, 235), (60, 200, 190), outline=20, gloss=False, shadow=False)
img = shape(img, lambda d: d.ellipse((330, 330, 694, 694), fill=255), (220, 255, 250), (50, 200, 180), outline=26)
icons["neutron"] = save(sparkle(img, 780, 230, 60), "neutron")

disk = blank("L")
ImageDraw.Draw(disk).ellipse((60, 380, 964, 644), fill=255)
disk = disk.rotate(18, resample=Image.BICUBIC, center=(C, C))
img = shape(blank(), lambda d: (d.polygon([(490, 512), (534, 512), (590, 40), (434, 40)], fill=255), d.polygon([(490, 512), (534, 512), (590, 984), (434, 984)], fill=255)),
            (255, 230, 250), (255, 150, 230), outline=22, gloss=False)
img = shape(img, lambda d: d.bitmap((0, 0), disk, fill=255), (255, 170, 230), (220, 60, 170), outline=26)
img = shape(img, lambda d: d.ellipse((392, 392, 632, 632), fill=255), (255, 255, 240), (255, 200, 120), outline=22)
icons["quasar"] = save(img, "quasar")

img = shape(blank(), lambda d: d.polygon(star_points(C, C, 480, 230, 10, 0.2), fill=255), (255, 150, 90), (230, 70, 50), outline=28)
img = shape(img, lambda d: d.polygon(star_points(C, C, 360, 190, 8, 0.6), fill=255), (255, 240, 150), (255, 180, 60), outline=24)
img = shape(img, lambda d: d.ellipse((380, 380, 644, 644), fill=255), (255, 255, 255), (255, 240, 200), outline=20)
icons["supernova"] = save(img, "supernova")

# ---------------- UI icons
# catalogue: treasure chest
img = shape(blank(), lambda d: d.rounded_rectangle((150, 420, 874, 860), 50, fill=255), (215, 140, 70), (150, 80, 40), outline=30)
img = shape(img, lambda d: d.rounded_rectangle((130, 250, 894, 470), 90, fill=255), (235, 165, 90), (175, 100, 50), outline=30)
img = shape(img, lambda d: (d.rectangle((440, 250, 584, 860), fill=255)), (255, 225, 110), (230, 165, 40), outline=22, gloss=False, shadow=False)
img = shape(img, lambda d: d.rounded_rectangle((430, 410, 594, 560), 30, fill=255), (255, 240, 160), (240, 180, 50), outline=22, shadow=False)
icons["ui_catalogue"] = save(sparkle(img, 820, 220, 70), "ui_catalogue")

# my sky: island on a cloud
img = shape(blank(), lambda d: [d.ellipse(b, fill=255) for b in [(100, 560, 480, 880), (330, 480, 730, 880), (580, 570, 930, 880)]], (255, 255, 255), (210, 225, 245), outline=26)
img = shape(img, lambda d: d.polygon([(220, 520), (804, 520), (680, 700), (344, 700)], fill=255), (240, 230, 210), (190, 170, 150), outline=24)
img = shape(img, lambda d: d.rounded_rectangle((190, 440, 834, 560), 60, fill=255), (150, 235, 120), (70, 180, 70), outline=24)
img = shape(img, lambda d: d.polygon(star_points(512, 250, 190, 85), fill=255), (255, 240, 130), (255, 180, 40), outline=24)
icons["ui_sky"] = save(img, "ui_sky")

# upgrades: big up arrow
img = shape(blank(), lambda d: d.polygon([(512, 90), (900, 500), (680, 500), (680, 920), (344, 920), (344, 500), (124, 500)], fill=255), (140, 255, 160), (30, 175, 80), outline=32)
icons["ui_upgrades"] = save(sparkle(img, 820, 220, 60), "ui_upgrades")

# index: book
img = shape(blank(), lambda d: d.rounded_rectangle((170, 130, 860, 900), 60, fill=255), (110, 200, 255), (30, 110, 220), outline=32)
img = shape(img, lambda d: d.rounded_rectangle((250, 760, 850, 860), 30, fill=255), (255, 255, 255), (215, 225, 240), outline=20, gloss=False, shadow=False)
img = shape(img, lambda d: d.polygon(star_points(530, 430, 200, 90), fill=255), (255, 240, 130), (255, 180, 40), outline=22, shadow=False)
icons["ui_index"] = save(img, "ui_index")

# constellations: navy disc with connected stars
img = shape(blank(), lambda d: d.ellipse((110, 110, 914, 914), fill=255), (70, 90, 190), (30, 40, 110), outline=32)
pts = [(300, 640), (430, 420), (600, 520), (720, 300)]
img = shape(img, lambda d: d.line(pts, fill=255, width=26, joint="curve"), (255, 220, 120), (255, 190, 60), outline=14, gloss=False, shadow=False)
for (x, y) in pts:
    img = shape(img, lambda d, x=x, y=y: d.polygon(star_points(x, y, 80, 36), fill=255), (255, 250, 200), (255, 200, 60), outline=16, shadow=False, gloss=False)
icons["ui_constellations"] = save(img, "ui_constellations")

# odds: die
img = shape(blank(), lambda d: d.rounded_rectangle((170, 170, 854, 854), 120, fill=255), (255, 255, 255), (205, 215, 235), outline=32)
for (x, y) in [(320, 320), (512, 512), (704, 704), (704, 320), (320, 704)]:
    img = shape(img, lambda d, x=x, y=y: d.ellipse((x - 62, y - 62, x + 62, y + 62), fill=255), (90, 120, 240), (40, 60, 180), outline=10, gloss=False, shadow=False)
icons["ui_odds"] = save(img, "ui_odds")

# rewards: gift box
img = shape(blank(), lambda d: d.rounded_rectangle((180, 440, 844, 900), 40, fill=255), (255, 110, 120), (210, 40, 70), outline=30)
img = shape(img, lambda d: d.rounded_rectangle((140, 330, 884, 480), 40, fill=255), (255, 140, 150), (225, 60, 90), outline=30)
img = shape(img, lambda d: (d.rectangle((450, 330, 574, 900), fill=255)), (255, 230, 120), (235, 170, 40), outline=20, gloss=False, shadow=False)
img = shape(img, lambda d: (d.ellipse((260, 150, 520, 360), fill=255), d.ellipse((504, 150, 764, 360), fill=255)), (255, 230, 120), (235, 170, 40), outline=24, shadow=False)
icons["ui_rewards"] = save(img, "ui_rewards")

# cash: gold coin with a star
img = shape(blank(), lambda d: d.ellipse((130, 130, 894, 894), fill=255), (255, 225, 100), (230, 150, 20), outline=32)
img = shape(img, lambda d: d.ellipse((250, 250, 774, 774), fill=255), (255, 205, 70), (245, 175, 30), outline=16, gloss=False, shadow=False)
img = shape(img, lambda d: d.polygon(star_points(C, C + 10, 200, 90), fill=255), (255, 250, 210), (255, 215, 90), outline=16, shadow=False)
icons["ui_cash"] = save(img, "ui_cash")

# luck: four-leaf clover
img = blank()
for (x, y) in [(512, 300), (724, 512), (512, 724), (300, 512)]:
    img = shape(img, lambda d, x=x, y=y: d.ellipse((x - 190, y - 190, x + 190, y + 190), fill=255), (150, 245, 130), (40, 170, 70), outline=28)
img = shape(img, lambda d: d.ellipse((420, 420, 604, 604), fill=255), (120, 220, 110), (40, 150, 60), outline=18, gloss=False, shadow=False)
icons["ui_luck"] = save(img, "ui_luck")

# rolls: telescope
img = shape(blank(), lambda d: d.polygon([(250, 900), (512, 560), (774, 900)], fill=0) or d.line([(300, 900), (512, 600), (724, 900)], fill=255, width=50), (150, 110, 80), (100, 70, 50), outline=22, gloss=False)
tube = blank("L")
ImageDraw.Draw(tube).rounded_rectangle((180, 430, 900, 610), 60, fill=255)
tube = tube.rotate(30, resample=Image.BICUBIC, center=(C, C))
img = shape(img, lambda d: d.bitmap((0, 0), tube, fill=255), (130, 200, 255), (50, 110, 220), outline=30)
icons["ui_rolls"] = save(sparkle(img, 800, 200, 80), "ui_rolls")

# preview sheet
names = list(icons)
sheet = Image.new("RGBA", (OUT * 10, OUT * 2), (190, 225, 255, 255))
for i, n in enumerate(names):
    sheet.alpha_composite(Image.open(root / f"{n}.png"), ((i % 10) * OUT, (i // 10) * OUT))
sheet.save(root.parent / "icons_preview.png")
print(len(names), "icons ->", root)
