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

# ---------------- deep-space stars (1 in 5M .. 1 in 1T)
# magnetar: blue core with two lightning bolts
def bolt(cx, cy, k, rot):
    base = [(-0.15, -1), (0.45, -1), (0.12, -0.15), (0.5, -0.15), (-0.35, 1), (-0.05, 0.12), (-0.45, 0.12)]
    ca, sa = math.cos(rot), math.sin(rot)
    return [(cx + (x * ca - y * sa) * k, cy + (x * sa + y * ca) * k) for (x, y) in base]
img = blank()
img = shape(img, lambda d: d.polygon(bolt(760, 270, 230, 0.5), fill=255), (255, 250, 170), (255, 200, 60), outline=24)
img = shape(img, lambda d: d.polygon(bolt(270, 760, 230, 0.5), fill=255), (255, 250, 170), (255, 200, 60), outline=24)
img = shape(img, lambda d: d.ellipse((250, 250, 774, 774), fill=255), (180, 235, 255), (40, 120, 230), outline=30)
icons["magnetar"] = save(img, "magnetar")

# nebula heart: pink cloud with a star
img = shape(blank(), lambda d: [d.ellipse(b, fill=255) for b in [(120, 380, 500, 760), (330, 230, 760, 660), (520, 400, 900, 780), (300, 500, 700, 860)]], (255, 190, 240), (190, 90, 220), outline=30)
img = shape(img, lambda d: d.polygon(star_points(C, 540, 180, 80), fill=255), (255, 255, 230), (255, 200, 120), outline=22, shadow=False)
icons["nebula"] = save(sparkle(img, 800, 200, 70), "nebula")

# white hole: bright sphere with an icy ring
ring = blank("L")
ImageDraw.Draw(ring).ellipse((60, 400, 964, 624), outline=255, width=60)
ring = ring.rotate(-15, resample=Image.BICUBIC, center=(C, C))
img = shape(blank(), lambda d: d.polygon(star_points(C, C, 470, 300, 16, 0), fill=255), (240, 250, 255), (180, 220, 255), outline=24, gloss=False)
img = shape(img, lambda d: d.ellipse((250, 250, 774, 774), fill=255), (255, 255, 255), (200, 225, 255), outline=28)
img = shape(img, lambda d: d.bitmap((0, 0), ring, fill=255), (220, 245, 255), (140, 200, 255), outline=20, gloss=False, shadow=False)
icons["whitehole"] = save(img, "whitehole")

# galaxy core: two spiral arms around a golden core
def spiral(d, phase):
    pts = []
    for i in range(60):
        t = i / 59
        a = phase + t * 3.6
        r = 70 + t * 360
        pts.append((C + math.cos(a) * r, C + math.sin(a) * r * 0.75))
    d.line(pts, fill=255, width=int(70), joint="curve")
img = blank()
for ph in (0, math.pi):
    img = shape(img, lambda d, ph=ph: spiral(d, ph), (255, 200, 240), (170, 110, 240), outline=22, gloss=False)
img = shape(img, lambda d: d.ellipse((380, 410, 644, 614), fill=255), (255, 245, 190), (255, 180, 60), outline=24)
icons["galaxy"] = save(sparkle(img, 820, 220, 60), "galaxy")

# cosmic string: glowing wave
pts = [(120 + i * 13, C + math.sin(i / 8) * 220) for i in range(61)]
img = shape(blank(), lambda d: d.line(pts, fill=255, width=90, joint="curve"), (200, 255, 230), (60, 210, 160), outline=30)
for (x, y) in [(pts[10][0], pts[10][1]), (pts[35][0], pts[35][1]), (pts[55][0], pts[55][1])]:
    img = sparkle(img, x, y, 70)
icons["cosmic"] = save(img, "cosmic")

# big bang: huge multi-layer burst
img = shape(blank(), lambda d: d.polygon(star_points(C, C, 500, 250, 14, 0.1), fill=255), (255, 110, 80), (200, 40, 60), outline=28)
img = shape(img, lambda d: d.polygon(star_points(C, C, 400, 220, 12, 0.4), fill=255), (255, 190, 80), (255, 120, 40), outline=24, shadow=False)
img = shape(img, lambda d: d.polygon(star_points(C, C, 300, 170, 10, 0.2), fill=255), (255, 250, 170), (255, 200, 80), outline=20, shadow=False)
img = shape(img, lambda d: d.ellipse((400, 400, 624, 624), fill=255), (255, 255, 255), (255, 240, 210), outline=18, shadow=False)
icons["bigbang"] = save(img, "bigbang")

# infinity star: lemniscate with a star at the center
lem = []
for i in range(121):
    t = i / 120 * 2 * math.pi
    den = 1 + math.sin(t) ** 2
    lem.append((C + 400 * math.cos(t) / den, C + 400 * math.sin(t) * math.cos(t) / den))
img = shape(blank(), lambda d: d.line(lem, fill=255, width=95, joint="curve"), (225, 200, 255), (130, 80, 230), outline=30)
img = shape(img, lambda d: d.polygon(star_points(C, C, 170, 75), fill=255), (255, 245, 180), (255, 190, 50), outline=22, shadow=False)
icons["infinity"] = save(sparkle(img, 830, 230, 70), "infinity")

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

# settings: gear
img = shape(blank(), lambda d: d.polygon(star_points(C, C, 430, 330, 8, 0), fill=255) or d.ellipse((182, 182, 842, 842), fill=255), (215, 225, 240), (140, 155, 185), outline=30)
img = shape(img, lambda d: d.ellipse((372, 372, 652, 652), fill=255), (90, 110, 150), (50, 60, 90), outline=20, gloss=False, shadow=False)
icons["ui_settings"] = save(img, "ui_settings")

# coins: a pile of gold coins
from PIL import ImageFont
DOLLAR = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 300)
img = blank()
for (x, y) in [(330, 760), (560, 780), (440, 650), (680, 660), (330, 560), (560, 540)]:
    img = shape(img, lambda d, x=x, y=y: d.ellipse((x - 170, y - 70, x + 170, y + 70), fill=255), (255, 222, 100), (225, 150, 20), outline=24, gloss=False)
img = shape(img, lambda d: d.ellipse((470, 160, 850, 540), fill=255), (255, 228, 110), (230, 150, 20), outline=28)
img = shape(img, lambda d: d.ellipse((550, 240, 770, 460), fill=255), (255, 205, 70), (245, 175, 30), outline=14, gloss=False, shadow=False)
img = shape(img, lambda d: d.polygon(star_points(660, 352, 90, 40), fill=255), (255, 250, 210), (255, 215, 90), outline=12, shadow=False, gloss=False)
icons["ui_coins"] = save(sparkle(img, 300, 260, 70), "ui_coins")

# income: a stack of dollar bills
img = blank()
for i, (dx, dy) in enumerate([(60, 120), (30, 60), (0, 0)]):
    box = (150 + dx, 300 + dy, 870 + dx, 700 + dy)
    img = shape(img, lambda d, box=box: d.rounded_rectangle(box, 40, fill=255), (130, 225, 120), (50, 160, 70), outline=26, gloss=(i == 2))
img = shape(img, lambda d: d.ellipse((380, 370, 640, 630), fill=255), (210, 250, 200), (120, 210, 120), outline=16, gloss=False, shadow=False)
img = shape(img, lambda d: d.text((512, 500), "$", font=DOLLAR, anchor="mm", fill=255), (40, 130, 60), (30, 100, 45), outline=10, gloss=False, shadow=False)
img = shape(img, lambda d: (d.ellipse((200, 350, 280, 430), fill=255), d.ellipse((740, 570, 820, 650), fill=255)), (210, 250, 200), (150, 220, 140), outline=10, gloss=False, shadow=False)
icons["ui_income"] = save(sparkle(img, 820, 230, 70), "ui_income")

# rebirth: circular arrow
def rebirth_arrow(d):
    r, w = 300, 120
    d.arc((C - r, C - r, C + r, C + r), 70, 330, fill=255, width=w)
    th = math.radians(330)
    rm = r - w / 2  # arc centerline radius
    px, py = C + rm * math.cos(th), C + rm * math.sin(th)
    tx, ty = -math.sin(th), math.cos(th)  # direction of travel (clockwise on screen)
    nx, ny = math.cos(th), math.sin(th)
    tip = (px - tx * 40 + tx * 200, py - ty * 40 + ty * 200)
    base1 = (px - tx * 40 + nx * 170, py - ty * 40 + ny * 170)
    base2 = (px - tx * 40 - nx * 170, py - ty * 40 - ny * 170)
    d.polygon([tip, base1, base2], fill=255)
img = shape(blank(), rebirth_arrow, (210, 160, 255), (120, 60, 220), outline=30)
icons["ui_rebirth"] = save(sparkle(img, 512, 512, 90), "ui_rebirth")

# build: hammer
handle = blank("L")
ImageDraw.Draw(handle).rounded_rectangle((462, 330, 562, 940), 40, fill=255)
handle = handle.rotate(-35, resample=Image.BICUBIC, center=(C, C))
headm = blank("L")
ImageDraw.Draw(headm).rounded_rectangle((250, 170, 780, 400), 60, fill=255)
headm = headm.rotate(-35, resample=Image.BICUBIC, center=(C, C))
img = shape(blank(), lambda d: d.bitmap((0, 0), handle, fill=255), (215, 150, 90), (150, 90, 50), outline=28)
img = shape(img, lambda d: d.bitmap((0, 0), headm, fill=255), (215, 225, 240), (120, 135, 165), outline=30)
icons["ui_build"] = save(sparkle(img, 230, 760, 70), "ui_build")

# codes: little blue bird
img = shape(blank(), lambda d: d.ellipse((190, 330, 760, 820), fill=255), (120, 200, 255), (40, 120, 230), outline=30)
img = shape(img, lambda d: d.ellipse((520, 210, 830, 520), fill=255), (130, 210, 255), (50, 130, 235), outline=28, shadow=False)
img = shape(img, lambda d: d.polygon([(810, 340), (960, 380), (810, 420)], fill=255), (255, 200, 80), (240, 150, 30), outline=20, shadow=False, gloss=False)
img = shape(img, lambda d: d.ellipse((250, 470, 560, 690), fill=255), (90, 170, 245), (30, 100, 210), outline=22, shadow=False)
img = shape(img, lambda d: d.polygon([(200, 560), (60, 470), (110, 640)], fill=255), (90, 170, 245), (30, 100, 210), outline=20, shadow=False, gloss=False)
img = shape(img, lambda d: d.ellipse((650, 300, 730, 380), fill=255), (255, 255, 255), (230, 235, 245), outline=12, shadow=False, gloss=False)
img = shape(img, lambda d: d.ellipse((675, 320, 715, 360), fill=255), (30, 30, 50), (20, 20, 40), outline=4, shadow=False, gloss=False)
icons["ui_codes"] = save(img, "ui_codes")

# ---- shop icons
def hexagon(cx, cy, r, rot=math.pi / 6):
    return [(cx + math.cos(rot + k * math.pi / 3) * r, cy + math.sin(rot + k * math.pi / 3) * r) for k in range(6)]
# robux-style coin: rounded hexagon with a square hole
img = shape(blank(), lambda d: d.polygon(hexagon(C, C, 420), fill=255), (130, 255, 150), (20, 170, 70), outline=32)
img = shape(img, lambda d: d.polygon(hexagon(C, C, 300), fill=255), (40, 150, 70), (20, 110, 50), outline=14, gloss=False, shadow=False)
img = shape(img, lambda d: d.rounded_rectangle((C - 110, C - 110, C + 110, C + 110), 30, fill=255), (240, 255, 240), (190, 240, 200), outline=14, shadow=False)
icons["ui_robux"] = save(img, "ui_robux")
# crate: purple crystal chest
img = shape(blank(), lambda d: d.rounded_rectangle((150, 400, 874, 880), 50, fill=255), (190, 120, 255), (100, 40, 200), outline=32)
img = shape(img, lambda d: d.rounded_rectangle((120, 290, 904, 450), 60, fill=255), (210, 150, 255), (120, 60, 220), outline=30)
img = shape(img, lambda d: d.rectangle((450, 290, 574, 880), fill=255), (255, 230, 120), (235, 170, 40), outline=20, gloss=False, shadow=False)
for (x, y, r) in [(330, 210, 120), (520, 150, 150), (700, 220, 110)]:
    img = shape(img, lambda d, x=x, y=y, r=r: d.polygon([(x, y - r), (x + r * 0.5, y + r * 0.6), (x - r * 0.5, y + r * 0.6)], fill=255), (190, 250, 255), (90, 170, 255), outline=20, shadow=False)
icons["ui_crate"] = save(sparkle(img, 860, 180, 70), "ui_crate")
# shop: shopping bag with a star
img = shape(blank(), lambda d: d.rounded_rectangle((180, 330, 844, 900), 60, fill=255), (120, 230, 130), (40, 160, 70), outline=32)
handle = blank("L")
ImageDraw.Draw(handle).arc((340, 120, 684, 470), 180, 360, fill=255, width=60)
img = shape(img, lambda d: d.bitmap((0, 0), handle, fill=255), (255, 230, 120), (235, 170, 40), outline=20, gloss=False, shadow=False)
img = shape(img, lambda d: d.polygon(star_points(C, 610, 170, 75), fill=255), (255, 245, 170), (255, 190, 50), outline=22, shadow=False)
icons["ui_shop"] = save(img, "ui_shop")
# crown (VIP)
img = shape(blank(), lambda d: d.polygon([(150, 780), (150, 330), (340, 520), (512, 230), (684, 520), (874, 330), (874, 780)], fill=255), (255, 235, 120), (240, 160, 20), outline=32)
for (x, y) in [(150, 330), (512, 230), (874, 330)]:
    img = shape(img, lambda d, x=x, y=y: d.ellipse((x - 60, y - 60, x + 60, y + 60), fill=255), (255, 120, 140), (210, 40, 80), outline=16, shadow=False)
img = shape(img, lambda d: d.rounded_rectangle((150, 700, 874, 820), 30, fill=255), (255, 215, 90), (220, 140, 20), outline=20, shadow=False)
icons["ui_crown"] = save(sparkle(img, 820, 160, 70), "ui_crown")
# bolt (fast rolls)
img = shape(blank(), lambda d: d.polygon([(600, 80), (250, 560), (480, 560), (400, 950), (790, 420), (550, 420), (680, 80)], fill=255), (255, 240, 120), (255, 150, 30), outline=34)
icons["ui_bolt"] = save(sparkle(img, 240, 220, 70), "ui_bolt")
# two dice (extra roll)
for name_, offs in [("ui_dice2", [(-170, 60, -12), (170, -60, 14)])]:
    img = blank()
    for (dx, dy, ang) in offs:
        die = blank("L")
        ImageDraw.Draw(die).rounded_rectangle((C - 230 + dx, C - 230 + dy, C + 230 + dx, C + 230 + dy), 70, fill=255)
        die = die.rotate(ang, resample=Image.BICUBIC, center=(C + dx, C + dy))
        img = shape(img, lambda d, die=die: d.bitmap((0, 0), die, fill=255), (255, 255, 255), (205, 215, 235), outline=30)
        for (px, py) in [(-110, -110), (110, 110), (0, 0)]:
            img = shape(img, lambda d, px=px, py=py, dx=dx, dy=dy: d.ellipse((C + dx + px - 45, C + dy + py - 45, C + dx + px + 45, C + dy + py + 45), fill=255), (60, 70, 120), (30, 30, 70), outline=6, gloss=False, shadow=False)
    icons[name_] = save(img, name_)
# target (lucky hunter)
img = blank()
for (r, top, bot) in [(420, (255, 120, 140), (210, 40, 80)), (300, (255, 255, 255), (225, 230, 240)), (180, (255, 120, 140), (210, 40, 80)), (70, (255, 230, 120), (235, 170, 40))]:
    img = shape(img, lambda d, r=r: d.ellipse((C - r, C - r, C + r, C + r), fill=255), top, bot, outline=22, shadow=(r == 420), gloss=(r == 420))
icons["ui_target"] = save(sparkle(img, 840, 180, 70), "ui_target")

# trash can (delete in build mode)
img = shape(blank(), lambda d: d.polygon([(250, 330), (774, 330), (720, 920), (304, 920)], fill=255), (210, 220, 235), (140, 150, 175), outline=32)
img = shape(img, lambda d: d.rounded_rectangle((190, 230, 834, 340), 30, fill=255), (225, 232, 245), (160, 170, 195), outline=28)
img = shape(img, lambda d: d.rounded_rectangle((420, 150, 604, 250), 30, fill=255), (225, 232, 245), (160, 170, 195), outline=22, shadow=False)
for x in (380, 512, 644):
    img = shape(img, lambda d, x=x: d.rounded_rectangle((x - 22, 420, x + 22, 830), 18, fill=255), (120, 130, 155), (90, 100, 125), outline=8, gloss=False, shadow=False)
icons["ui_trash"] = save(img, "ui_trash")

# backpack (inventory)
img = blank()
img = shape(img, lambda d: d.rounded_rectangle((330, 120, 694, 300), 90, fill=255), (150, 95, 50), (110, 65, 35), outline=26)
img = shape(img, lambda d: d.rounded_rectangle((220, 220, 804, 930), 150, fill=255), (196, 128, 66), (128, 76, 38), outline=30)
img = shape(img, lambda d: d.rounded_rectangle((300, 560, 724, 860), 70, fill=255), (176, 110, 54), (120, 72, 36), outline=22, shadow=False)
img = shape(img, lambda d: d.rounded_rectangle((300, 560, 724, 640), 30, fill=255), (140, 86, 42), (110, 66, 32), outline=16, gloss=False, shadow=False)
img = shape(img, lambda d: d.rounded_rectangle((470, 590, 554, 690), 20, fill=255), (255, 215, 90), (230, 160, 40), outline=14, gloss=False, shadow=False)
for x in (250, 774):
    img = shape(img, lambda d, x=x: d.rounded_rectangle((x - 40, 420, x + 40, 760), 30, fill=255), (150, 95, 50), (110, 65, 35), outline=16, gloss=False, shadow=False)
icons["ui_backpack"] = save(sparkle(img, 830, 200, 60), "ui_backpack")

# big white dice (ROLL)
img = blank()
img = shape(img, lambda d: d.rounded_rectangle((170, 170, 854, 854), 150, fill=255), (255, 255, 255), (214, 214, 236), outline=34)
for cx, cy in ((340, 340), (684, 340), (512, 512), (340, 684), (684, 684)):
    img = shape(img, lambda d, cx=cx, cy=cy: d.ellipse((cx - 62, cy - 62, cx + 62, cy + 62), fill=255), (235, 70, 110), (170, 30, 70), outline=10, gloss=False, shadow=False)
icons["ui_roll"] = save(sparkle(img, 850, 180, 80), "ui_roll")

# preview sheet
names = list(icons)
sheet = Image.new("RGBA", (OUT * 10, OUT * 2), (190, 225, 255, 255))
for i, n in enumerate(names):
    sheet.alpha_composite(Image.open(root / f"{n}.png"), ((i % 10) * OUT, (i // 10) * OUT))
sheet.save(root.parent / "icons_preview.png")
print(len(names), "icons ->", root)
