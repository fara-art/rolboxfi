# Photo-style star icons, rendered from scratch (no third-party images).
# Each icon is a round "window into space": dark sky, faint starfield, the object, a thin rim.
# Run: python3 tools/make_star_art.py  -> assets/stars/<id>.png (256x256)
import math, pathlib
import numpy as np
from PIL import Image

S = 640  # render size, downscaled to 256 for clean edges
OUT = 256
root = pathlib.Path(__file__).resolve().parent.parent / "assets" / "stars"
root.mkdir(parents=True, exist_ok=True)

yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
X = (xx - S / 2) / (S / 2)  # -1..1
Y = (yy - S / 2) / (S / 2)
R = np.sqrt(X * X + Y * Y)
ANG = np.arctan2(Y, X)


def fbm(seed, octaves=6, base=4, persistence=0.55):
    rng = np.random.default_rng(seed)
    out = np.zeros((S, S), np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        n = base * 2 ** o
        grid = rng.random((n + 1, n + 1)).astype(np.float32)
        layer = np.asarray(Image.fromarray(grid).resize((S, S), Image.BICUBIC), np.float32)
        out += layer * amp
        total += amp
        amp *= persistence
    out /= total
    return (out - out.min()) / (out.max() - out.min() + 1e-6)


def warp(field, seed, strength=0.08):
    """domain-warp a field for wispy, gas-like structure"""
    wx = (fbm(seed, 4, 3) - 0.5) * strength * S
    wy = (fbm(seed + 1, 4, 3) - 0.5) * strength * S
    ix = np.clip((xx + wx).astype(np.int32), 0, S - 1)
    iy = np.clip((yy + wy).astype(np.int32), 0, S - 1)
    return field[iy, ix]


def col(*c):
    return np.array(c, np.float32) / 255.0


class Canvas:
    def __init__(self, seed):
        self.L = np.zeros((S, S, 3), np.float32)  # linear light
        self.seed = seed
        rng = np.random.default_rng(seed)
        # deep sky gradient + faint starfield
        sky = col(6, 8, 20) * (1 - R[..., None] * 0.3) + col(18, 12, 40) * (R[..., None] * 0.4)
        self.L += sky
        for _ in range(140):
            x, y = rng.uniform(-1, 1, 2)
            b = rng.uniform(0.15, 0.9) ** 3
            tint = rng.choice([0, 1, 2])
            c = [col(200, 210, 255), col(255, 240, 220), col(255, 255, 255)][tint]
            self.add_glow(x, y, rng.uniform(0.004, 0.009), c, b * 2.5)

    def add(self, intensity, color):
        self.L += intensity[..., None] * color

    def add_glow(self, cx, cy, r, color, strength=1.0):
        d2 = ((X - cx) ** 2 + (Y - cy) ** 2) / (r * r)
        self.add(np.exp(-d2) * strength, color)

    def add_halo(self, cx, cy, r, color, strength=1.0):
        d2 = ((X - cx) ** 2 + (Y - cy) ** 2) / (r * r)
        self.add(strength / (1 + d2 * 6), color)

    def spikes(self, cx, cy, length, color, strength=1.0, n=4, width=0.006, rot=math.pi / 4):
        for k in range(n):
            a = rot + k * math.pi / n * 2 / 2 * (2 if n == 4 else 1)
            a = rot + k * (math.pi / (n / 2)) if n > 2 else rot
            dx, dy = math.cos(a), math.sin(a)
            along = (X - cx) * dx + (Y - cy) * dy
            perp = -(X - cx) * dy + (Y - cy) * dx
            inten = np.exp(-(perp / width) ** 2) * np.exp(-np.abs(along) / length)
            self.add(inten * strength, color)

    def sphere(self, cx, cy, r, inner, outer, texture=None, tex_strength=0.35, limb=0.65, alpha=1.0):
        d = np.sqrt((X - cx) ** 2 + (Y - cy) ** 2) / r
        inside = d < 1
        mu = np.sqrt(np.clip(1 - d * d, 0, 1))
        shade = 1 - limb * (1 - mu)  # limb darkening
        t = np.clip(d, 0, 1)[..., None]
        color = inner * (1 - t) + outer * t
        if texture is not None:
            color = color * (1 - tex_strength + tex_strength * 2 * texture[..., None])
        color = color * shade[..., None]
        a = np.clip((1 - d) * r * S / 2 / 1.5, 0, 1) * inside * alpha  # anti-aliased edge
        self.L = self.L * (1 - a[..., None]) + color * a[..., None]
        return inside

    def disk(self, cx, cy, rx, ry, angle, color, strength, inner=0.0, softness=0.08):
        ca, sa = math.cos(angle), math.sin(angle)
        u = ((X - cx) * ca + (Y - cy) * sa) / rx
        v = (-(X - cx) * sa + (Y - cy) * ca) / ry
        d = np.sqrt(u * u + v * v)
        ring = np.clip((1 - d) / softness, 0, 1) * np.clip((d - inner) / softness, 0, 1)
        self.add(ring * strength, color)
        return d

    def save(self, name, exposure=1.6):
        img = 1 - np.exp(-self.L * exposure)  # filmic-ish tone map
        img = np.clip(img, 0, 1) ** (1 / 1.1)
        mask = np.clip((0.965 - R) * S / 3, 0, 1)
        rim = np.clip(1 - np.abs(R - 0.975) * S / 6, 0, 1)
        rgb = img * mask[..., None] + col(150, 170, 230) * rim[..., None] * 0.9
        alpha = np.clip(mask + rim, 0, 1)
        out = np.dstack([rgb, alpha])
        Image.fromarray((out * 255).astype(np.uint8), "RGBA").resize((OUT, OUT), Image.LANCZOS).save(root / f"{name}.png")


def surface(seed, scale=5, octaves=6):
    return fbm(seed, octaves, scale)


# ------------------------------------------------------------------ the 27 objects
def dust():
    c = Canvas(1)
    cloud = warp(fbm(11, 6, 3), 12, 0.12)
    shape = np.exp(-((X / 0.75) ** 2 + (Y / 0.55) ** 2))
    c.add(np.clip(cloud - 0.35, 0, 1) * shape * 1.4, col(150, 140, 210))
    rng = np.random.default_rng(5)
    for _ in range(45):
        x, y = rng.normal(0, 0.32, 2)
        c.add_glow(x, y, rng.uniform(0.008, 0.02), col(230, 230, 255), rng.uniform(0.6, 2.5))
    c.save("dust")


def spark():
    c = Canvas(2)
    c.add_halo(0, 0, 0.35, col(255, 230, 170), 0.6)
    c.spikes(0, 0, 0.45, col(255, 245, 220), 1.6, width=0.012)
    c.spikes(0, 0, 0.2, col(255, 240, 210), 0.8, width=0.008, rot=0)
    c.add_glow(0, 0, 0.06, col(255, 255, 240), 6)
    c.save("spark")


def browndwarf():
    c = Canvas(3)
    bands = np.sin(Y * 22 + (fbm(31, 5, 4) - 0.5) * 6) * 0.5 + 0.5
    tex = bands * 0.6 + fbm(32, 6, 6) * 0.4
    c.add_halo(0, 0, 0.55, col(120, 50, 30), 0.25)
    c.sphere(0, 0, 0.5, col(170, 100, 70), col(90, 45, 35), texture=tex, tex_strength=0.45, limb=0.75)
    c.save("browndwarf", exposure=1.9)


def red_dwarf():
    c = Canvas(4)
    c.add_halo(0, 0, 0.5, col(255, 80, 40), 0.7)
    c.sphere(0, 0, 0.38, col(255, 150, 90), col(200, 40, 20), texture=surface(41, 8), tex_strength=0.3)
    c.add_glow(-0.12, -0.12, 0.2, col(255, 200, 150), 0.25)
    c.save("dwarf")


def whitedwarf():
    c = Canvas(5)
    c.add_halo(0, 0, 0.5, col(170, 200, 255), 0.6)
    c.spikes(0, 0, 0.5, col(220, 235, 255), 1.4, width=0.01)
    c.sphere(0, 0, 0.11, col(255, 255, 255), col(200, 225, 255), limb=0.3)
    c.add_glow(0, 0, 0.16, col(230, 240, 255), 2.5)
    c.save("whitedwarf")


def sun():
    c = Canvas(6)
    c.add_halo(0, 0, 0.75, col(255, 170, 60), 0.6)
    gran = surface(61, 14, 5)
    c.sphere(0, 0, 0.58, col(255, 240, 170), col(240, 120, 20), texture=gran, tex_strength=0.25, limb=0.6)
    rng = np.random.default_rng(62)
    for _ in range(5):  # prominences on the limb
        a = rng.uniform(0, 2 * math.pi)
        c.add_glow(math.cos(a) * 0.6, math.sin(a) * 0.6, 0.05, col(255, 110, 40), 1.2)
    for _ in range(4):  # sunspots
        a, rr = rng.uniform(0, 2 * math.pi), rng.uniform(0, 0.35)
        d2 = ((X - math.cos(a) * rr) ** 2 + (Y - math.sin(a) * rr) ** 2) / 0.03 ** 2
        c.L *= (1 - 0.6 * np.exp(-d2))[..., None]
    c.save("sun")


def redgiant():
    c = Canvas(7)
    c.add_halo(0, 0, 0.9, col(255, 90, 40), 0.55)
    cells = surface(71, 3, 6)
    c.sphere(0, 0, 0.74, col(255, 160, 80), col(170, 40, 15), texture=cells, tex_strength=0.45, limb=0.7)
    c.save("redgiant")


def bluegiant():
    c = Canvas(8)
    c.add_halo(0, 0, 0.95, col(90, 160, 255), 0.8)
    c.sphere(0, 0, 0.66, col(230, 245, 255), col(60, 120, 240), texture=surface(81, 10, 5), tex_strength=0.18, limb=0.5)
    c.spikes(0, 0, 0.6, col(190, 220, 255), 0.4, width=0.01)
    c.save("giant")


def binary():
    c = Canvas(9)
    swirl = warp(fbm(91, 5, 3), 92, 0.15) * np.exp(-((X / 0.8) ** 2 + (Y / 0.4) ** 2))
    c.add(swirl * 0.5, col(255, 180, 120))
    c.add_halo(-0.28, 0.05, 0.4, col(255, 200, 110), 0.6)
    c.add_halo(0.3, -0.05, 0.35, col(120, 170, 255), 0.6)
    c.sphere(-0.28, 0.05, 0.25, col(255, 240, 180), col(240, 140, 40), texture=surface(93, 10, 5), tex_strength=0.2)
    c.sphere(0.3, -0.05, 0.18, col(235, 245, 255), col(90, 140, 240), limb=0.5)
    c.save("binary")


def pulsar():
    c = Canvas(10)
    haze = warp(fbm(101, 6, 3), 102, 0.12) * np.exp(-(R / 0.8) ** 2)
    c.add(haze * 0.45, col(140, 90, 230))
    a = math.radians(70)
    dx, dy = math.cos(a), math.sin(a)
    along = X * dx + Y * dy
    perp = -X * dy + Y * dx
    beam = np.exp(-(perp / (0.02 + np.abs(along) * 0.12)) ** 2) * np.exp(-np.abs(along) * 0.8)
    c.add(beam * 1.6, col(190, 200, 255))
    c.add_halo(0, 0, 0.25, col(200, 160, 255), 1.0)
    c.add_glow(0, 0, 0.07, col(255, 255, 255), 6)
    c.save("pulsar")


def wolfrayet():
    c = Canvas(11)
    shell = warp(fbm(111, 6, 5), 112, 0.1)
    ring = np.exp(-((R - 0.48) / 0.18) ** 2)
    c.add(np.clip(shell - 0.3, 0, 1) * ring * 2.2, col(255, 120, 160))
    c.add(np.clip(shell - 0.55, 0, 1) * ring * 2.0, col(255, 200, 120))
    c.spikes(0, 0, 0.5, col(255, 235, 245), 1.3, n=6, width=0.008, rot=math.pi / 2)
    c.add_glow(0, 0, 0.08, col(255, 250, 255), 6)
    c.save("wolfrayet")


def neutron():
    c = Canvas(12)
    for k in range(5):  # magnetic field loops
        a = k * math.pi / 5
        field = np.exp(-((np.abs(np.sin(ANG - a)) * R - 0.0) / 0.02) ** 2) * np.exp(-((R - 0.42) / 0.3) ** 2)
        c.add(field * 0.18, col(90, 255, 220))
    c.add_halo(0, 0, 0.3, col(90, 255, 220), 0.9)
    c.spikes(0, 0, 0.4, col(200, 255, 245), 1.2, width=0.008)
    c.add_glow(0, 0, 0.06, col(255, 255, 255), 7)
    c.save("neutron")


def hypergiant():
    c = Canvas(13)
    outflow = warp(fbm(131, 6, 4), 132, 0.2) * np.exp(-((R - 0.68) / 0.2) ** 2)
    c.add(np.clip(outflow - 0.35, 0, 1) * 2.2, col(255, 110, 50))
    c.add_halo(0, 0, 0.75, col(255, 120, 50), 0.45)
    c.sphere(0, 0, 0.58, col(255, 190, 110), col(180, 50, 15), texture=surface(133, 2, 6), tex_strength=0.5, limb=0.75)
    c.save("hypergiant")


def quasar():
    c = Canvas(14)
    d = c.disk(0, 0, 0.8, 0.22, -0.3, col(255, 120, 210), 0.0)
    swirl = fbm(141, 5, 6)
    disk_light = np.clip(1 - d, 0, 1) ** 1.5 * (0.6 + 0.6 * swirl)
    c.add(disk_light * 1.6, col(255, 120, 200))
    c.add(np.clip(1 - d * 1.8, 0, 1) * 2.2, col(255, 210, 160))
    a = -0.3 + math.pi / 2
    dx, dy = math.cos(a), math.sin(a)
    along = X * dx + Y * dy
    perp = -X * dy + Y * dx
    jet = np.exp(-(perp / (0.015 + np.abs(along) * 0.05)) ** 2) * np.exp(-np.abs(along) * 1.2)
    c.add(jet * 1.8, col(200, 210, 255))
    c.add_glow(0, 0, 0.07, col(255, 255, 255), 8)
    c.save("quasar")


def kilonova():
    c = Canvas(15)
    blast = warp(fbm(151, 6, 4), 152, 0.15) * np.exp(-(R / 0.6) ** 2)
    c.add(blast * 1.6, col(255, 150, 60))
    c.add(np.exp(-(R / 0.3) ** 2) * 1.2, col(255, 210, 120))
    c.add_glow(-0.05, 0, 0.04, col(255, 255, 255), 6)
    c.add_glow(0.05, 0, 0.04, col(255, 255, 255), 6)
    c.spikes(0, 0, 0.4, col(255, 230, 190), 0.9, width=0.01)
    c.save("kilonova")


def supernova():
    c = Canvas(16)
    fil = warp(fbm(161, 7, 6), 162, 0.08)
    shell = np.exp(-((R - 0.55) / 0.13) ** 2)
    c.add(np.clip(fil - 0.4, 0, 1) * shell * 3.5, col(255, 120, 80))
    c.add(np.clip(fil - 0.6, 0, 1) * shell * 3.5, col(120, 200, 255))
    c.add(np.clip(fil - 0.5, 0, 1) * np.exp(-(R / 0.45) ** 2) * 1.5, col(140, 255, 160))
    c.add_glow(0, 0, 0.05, col(255, 255, 255), 6)
    c.save("supernova")


def magnetar():
    c = Canvas(17)
    for k in range(6):
        a = k * math.pi / 3
        loop = np.exp(-((R - 0.25 - 0.18 * np.abs(np.cos(ANG - a))) / 0.015) ** 2) * (np.cos(ANG - a) > 0)
        c.add(loop * 0.9, col(120, 200, 255))
    c.add_halo(0, 0, 0.35, col(120, 200, 255), 1.0)
    flare = np.exp(-((X - 0.35) ** 2 / 0.02 + (Y + 0.25) ** 2 / 0.004))
    c.add(flare * 1.5, col(255, 245, 190))
    c.add_glow(0, 0, 0.08, col(255, 255, 255), 7)
    c.save("magnetar")


def nebula():
    c = Canvas(18)
    gas = warp(fbm(181, 7, 3), 182, 0.18)
    # heart-shaped envelope
    hx, hy = X * 1.2, -Y * 1.2 + 0.15
    heart = (hx ** 2 + hy ** 2 - 0.5) ** 3 - hx ** 2 * hy ** 3
    env = np.clip(-heart * 6, 0, 1)
    env = np.asarray(Image.fromarray((env * 255).astype(np.uint8)).resize((S, S)).filter(__import__("PIL.ImageFilter", fromlist=["GaussianBlur"]).GaussianBlur(18)), np.float32) / 255
    c.add(np.clip(gas - 0.1, 0, 1) * env * 3.6, col(255, 90, 190))
    c.add(np.clip(gas - 0.4, 0, 1) * env * 3.2, col(120, 150, 255))
    c.add(np.clip(warp(fbm(183, 6, 4), 184, 0.1) - 0.6, 0, 1) * env * 2, col(255, 220, 150))
    c.add_glow(0, 0.05, 0.05, col(255, 255, 255), 4)
    c.save("nebula")


def whitehole():
    c = Canvas(19)
    for k, rr in enumerate([0.35, 0.5, 0.65, 0.8]):
        c.add(np.exp(-((R - rr) / 0.02) ** 2) * (1.2 - k * 0.2), col(200, 230, 255))
    c.add_halo(0, 0, 0.5, col(220, 240, 255), 1.4)
    c.sphere(0, 0, 0.22, col(255, 255, 255), col(220, 235, 255), limb=0.1)
    c.spikes(0, 0, 0.7, col(255, 255, 255), 1.0, width=0.01)
    c.save("whitehole")


def eventhorizon():
    c = Canvas(20)
    # Doppler-bright photon ring (brighter at the bottom like the famous images)
    ringf = np.exp(-((R - 0.42) / 0.07) ** 2)
    doppler = 0.55 + 0.45 * np.clip(Y / 0.5 + 0.2, -1, 1)
    c.add(ringf * doppler * 2.6, col(255, 140, 50))
    c.add(np.exp(-((R - 0.42) / 0.025) ** 2) * doppler * 1.5, col(255, 220, 150))
    shadow = np.clip((0.3 - R) / 0.02, 0, 1)
    c.L *= (1 - shadow)[..., None]
    c.save("eventhorizon")


def galaxy():
    c = Canvas(21)
    tilt = 0.55
    u = X * math.cos(0.4) + Y * math.sin(0.4)
    v = (-X * math.sin(0.4) + Y * math.cos(0.4)) / tilt
    rr = np.sqrt(u * u + v * v)
    th = np.arctan2(v, u)
    arms = 0.5 + 0.5 * np.cos(2 * (th - np.log(rr + 1e-3) * 2.4))
    clumps = fbm(211, 6, 8)
    disk_env = np.exp(-(rr / 0.62) ** 2)
    c.add(arms ** 2 * disk_env * (0.5 + clumps) * 1.3, col(150, 180, 255))
    c.add(np.exp(-(rr / 0.2) ** 2) * 2.2, col(255, 210, 140))
    dust_lane = arms ** 6 * disk_env * (fbm(212, 5, 10))
    c.L *= (1 - np.clip(dust_lane * 0.5, 0, 0.6))[..., None]
    c.add_glow(0, 0, 0.05, col(255, 240, 210), 3)
    c.save("galaxy")


def darkmatter():
    c = Canvas(22)
    haze = warp(fbm(221, 6, 3), 222, 0.2) * np.exp(-(R / 0.85) ** 2)
    c.add(haze * 0.6, col(110, 60, 190))
    for k in range(3):  # lensing arcs
        a = k * 2.1 + 0.4
        arc = np.exp(-((R - 0.5 - k * 0.08) / 0.015) ** 2) * np.clip(np.cos(ANG - a) - 0.6, 0, 1) * 2.5
        c.add(arc, col(210, 190, 255))
    c.L *= (1 - 0.7 * np.exp(-(R / 0.28) ** 2))[..., None]
    c.add(np.exp(-((R - 0.3) / 0.03) ** 2) * 0.8, col(170, 120, 255))
    c.save("darkmatter")


def cosmic():
    c = Canvas(23)
    curve = Y - 0.25 * np.sin(X * 4.2)
    line = np.exp(-(curve / 0.012) ** 2) * np.exp(-(X / 0.95) ** 8)
    glow = np.exp(-(curve / 0.08) ** 2) * np.exp(-(X / 0.95) ** 8)
    c.add(line * 3, col(200, 255, 230))
    c.add(glow * 0.8, col(80, 230, 170))
    for x in (-0.55, 0.1, 0.6):  # lensed double images
        y = 0.25 * math.sin(x * 4.2)
        c.add_glow(x, y - 0.12, 0.02, col(255, 255, 255), 3)
        c.add_glow(x, y + 0.12, 0.02, col(255, 255, 255), 3)
    c.save("cosmic")


def multiverse():
    c = Canvas(24)
    rng = np.random.default_rng(241)
    bubbles = [(-0.35, -0.2, 0.3), (0.32, -0.25, 0.24), (0.05, 0.35, 0.33), (-0.5, 0.42, 0.14), (0.55, 0.35, 0.16)]
    tints = [col(120, 220, 255), col(255, 140, 220), col(160, 255, 170), col(255, 220, 120), col(200, 160, 255)]
    for i, (x, y, r) in enumerate(bubbles):
        inner = warp(fbm(242 + i, 5, 4), 250 + i, 0.15)
        d = np.sqrt((X - x) ** 2 + (Y - y) ** 2) / r
        c.add(np.clip(1 - d, 0, 1) * inner * 1.4, tints[i])
        c.add(np.exp(-((d - 1) / 0.06) ** 2) * 1.6, tints[i] * 0.6 + col(255, 255, 255) * 0.4)
    c.save("multiverse")


def bigbang():
    c = Canvas(25)
    plasma = warp(fbm(251, 7, 4), 252, 0.2)
    fire = np.exp(-(R / 0.65) ** 2)
    c.add(plasma * fire * 2.4, col(255, 110, 50))
    c.add(np.clip(plasma - 0.45, 0, 1) * fire * 3, col(255, 220, 120))
    rays = (0.5 + 0.5 * np.cos(ANG * 18 + fbm(253, 3, 2) * 4)) ** 8 * np.exp(-R * 1.2)
    c.add(rays * 1.2, col(255, 200, 150))
    c.add(np.exp(-(R / 0.18) ** 2) * 4, col(255, 255, 240))
    c.save("bigbang")


def cosmicweb():
    c = Canvas(26)
    rng = np.random.default_rng(261)
    pts = rng.uniform(-0.8, 0.8, (22, 2))
    pts = pts[np.hypot(pts[:, 0], pts[:, 1]) < 0.85]
    for i in range(len(pts)):
        for j in range(i + 1, len(pts)):
            a, b = pts[i], pts[j]
            dist = np.hypot(*(a - b))
            if dist < 0.42:
                ab = b - a
                t = np.clip(((X - a[0]) * ab[0] + (Y - a[1]) * ab[1]) / (ab @ ab), 0, 1)
                px, py = a[0] + ab[0] * t, a[1] + ab[1] * t
                dd = np.hypot(X - px, Y - py)
                c.add(np.exp(-(dd / 0.012) ** 2) * 0.9 + np.exp(-(dd / 0.05) ** 2) * 0.25, col(150, 170, 255))
    for (x, y) in pts:
        c.add_glow(x, y, 0.03, col(230, 235, 255), 3)
        c.add_halo(x, y, 0.08, col(150, 170, 255), 0.4)
    c.save("cosmicweb")


def infinity():
    c = Canvas(27)
    t = np.linspace(0, 2 * math.pi, 400)
    den = 1 + np.sin(t) ** 2
    lx, ly = 0.72 * np.cos(t) / den, 0.72 * np.sin(t) * np.cos(t) / den
    for i in range(0, 400, 2):
        c.add_glow(lx[i], ly[i], 0.022, col(210, 170, 255), 0.35)
    for i in range(0, 400, 25):
        c.add_glow(lx[i], ly[i], 0.012, col(255, 240, 200), 2.2)
    c.add_halo(0, 0, 0.4, col(200, 160, 255), 0.6)
    c.spikes(0, 0, 0.5, col(255, 235, 190), 1.2, width=0.01)
    c.add_glow(0, 0, 0.06, col(255, 255, 255), 6)
    c.save("infinity")


# ------------------------------------------------------------------ named stars: drawn by kind + color
import sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from star_catalog import NAMED


def tint(c, k):
    return np.clip(np.array(c, np.float32) / 255.0 * k, 0, 2)


def hue_shift(c, amount):
    r, g, b = c
    return (int(g * (1 - amount) + r * amount), int(b * (1 - amount) + g * amount), int(r * (1 - amount) + b * amount))


def kind_sphere(name, c, seed):
    cv = Canvas(seed)
    cv.add_halo(0, 0, 0.6, tint(c, 0.9), 0.6)
    cv.sphere(0, 0, 0.44, tint(c, 1.15) * 0.5 + col(255, 255, 255) * 0.5, tint(c, 0.75), texture=surface(seed, 10, 5), tex_strength=0.28)
    cv.save(name)


def kind_point(name, c, seed):
    cv = Canvas(seed)
    cv.add_halo(0, 0, 0.45, tint(c, 0.8), 0.6)
    rot = (seed % 7) * 0.12
    cv.spikes(0, 0, 0.55, tint(c, 1.1), 1.4, width=0.009, rot=math.pi / 4 + rot)
    cv.spikes(0, 0, 0.25, tint(c, 0.9), 0.6, width=0.006, rot=rot)
    cv.add_glow(0, 0, 0.09, col(255, 255, 255), 6)
    cv.save(name)


def kind_giant(name, c, seed):
    cv = Canvas(seed)
    outflow = warp(fbm(seed, 6, 4), seed + 1, 0.2) * np.exp(-((R - 0.7) / 0.18) ** 2)
    cv.add(np.clip(outflow - 0.4, 0, 1) * 1.8, tint(c, 1))
    cv.add_halo(0, 0, 0.85, tint(c, 0.8), 0.45)
    cv.sphere(0, 0, 0.62, tint(c, 1.2) * 0.6 + col(255, 230, 180) * 0.4, tint(c, 0.55), texture=surface(seed + 2, 3, 6), tex_strength=0.45, limb=0.72)
    cv.save(name)


def kind_binary(name, c, seed):
    cv = Canvas(seed)
    c2 = hue_shift(c, 0.6)
    swirl = warp(fbm(seed, 5, 3), seed + 1, 0.15) * np.exp(-((X / 0.8) ** 2 + (Y / 0.4) ** 2))
    cv.add(swirl * 0.45, tint(c, 0.9))
    cv.add_halo(-0.27, 0.04, 0.38, tint(c, 0.9), 0.6)
    cv.add_halo(0.3, -0.05, 0.33, tint(c2, 0.9), 0.6)
    cv.sphere(-0.27, 0.04, 0.24, tint(c, 1.1) * 0.6 + col(255, 255, 255) * 0.4, tint(c, 0.7), texture=surface(seed + 3, 10, 5), tex_strength=0.2)
    cv.sphere(0.3, -0.05, 0.17, tint(c2, 1.1) * 0.6 + col(255, 255, 255) * 0.4, tint(c2, 0.7), limb=0.5)
    cv.save(name)


def kind_pulsar(name, c, seed):
    cv = Canvas(seed)
    haze = warp(fbm(seed, 6, 3), seed + 1, 0.12) * np.exp(-(R / 0.8) ** 2)
    cv.add(haze * 0.45, tint(c, 0.8))
    a = math.radians(50 + (seed % 5) * 15)
    dx, dy = math.cos(a), math.sin(a)
    along = X * dx + Y * dy
    perp = -X * dy + Y * dx
    beam = np.exp(-(perp / (0.02 + np.abs(along) * 0.12)) ** 2) * np.exp(-np.abs(along) * 0.8)
    cv.add(beam * 1.6, tint(c, 1.1) * 0.5 + col(255, 255, 255) * 0.5)
    cv.add_halo(0, 0, 0.25, tint(c, 1), 1.0)
    cv.add_glow(0, 0, 0.07, col(255, 255, 255), 6)
    cv.save(name)


def kind_blackhole(name, c, seed):
    cv = Canvas(seed)
    size = 0.36 + (seed % 3) * 0.04
    ringf = np.exp(-((R - size) / 0.07) ** 2)
    doppler = 0.55 + 0.45 * np.clip(Y / 0.5 + 0.2, -1, 1)
    cv.add(ringf * doppler * 2.6, tint(c, 1))
    cv.add(np.exp(-((R - size) / 0.025) ** 2) * doppler * 1.5, tint(c, 0.6) + col(255, 255, 255) * 0.4)
    swirl = fbm(seed + 1, 5, 6)
    disk = np.exp(-((Y * 3.2) ** 2)) * np.exp(-((R - size * 1.7) / 0.35) ** 2) * (0.6 + swirl * 0.8)
    cv.add(disk * 0.9, tint(c, 0.9))
    shadow = np.clip((size * 0.72 - R) / 0.02, 0, 1)
    cv.L *= (1 - shadow)[..., None]
    cv.save(name)


def kind_magnetar(name, c, seed):
    cv = Canvas(seed)
    for k in range(6):
        a = k * math.pi / 3 + seed * 0.1
        loop = np.exp(-((R - 0.25 - 0.18 * np.abs(np.cos(ANG - a))) / 0.015) ** 2) * (np.cos(ANG - a) > 0)
        cv.add(loop * 0.9, tint(c, 1))
    cv.add_halo(0, 0, 0.35, tint(c, 1), 1.0)
    cv.add_glow(0, 0, 0.08, col(255, 255, 255), 7)
    cv.save(name)


def kind_nebula(name, c, seed):
    cv = Canvas(seed)
    c2 = hue_shift(c, 0.5)
    gas = warp(fbm(seed, 7, 3), seed + 1, 0.2)
    gx, gy = np.random.default_rng(seed).uniform(-0.2, 0.2, 2)
    env = np.exp(-(((X - gx) / 0.75) ** 2 + ((Y - gy) / 0.6) ** 2))
    cv.add(np.clip(gas - 0.25, 0, 1) * env * 3.2, tint(c, 1))
    cv.add(np.clip(gas - 0.5, 0, 1) * env * 3.0, tint(c2, 1))
    dust = warp(fbm(seed + 2, 6, 5), seed + 3, 0.1)
    cv.L *= (1 - np.clip(dust - 0.6, 0, 1) * 1.6 * env)[..., None]
    rng = np.random.default_rng(seed + 4)
    for _ in range(5):
        x, y = rng.normal(0, 0.25, 2)
        cv.add_glow(x, y, 0.02, col(255, 255, 255), 2.5)
    cv.save(name)


def kind_remnant(name, c, seed):
    cv = Canvas(seed)
    c2 = hue_shift(c, 0.55)
    fil = warp(fbm(seed, 7, 6), seed + 1, 0.08)
    radius = 0.45 + (seed % 3) * 0.06
    shell = np.exp(-((R - radius) / 0.12) ** 2)
    cv.add(np.clip(fil - 0.4, 0, 1) * shell * 3.4, tint(c, 1))
    cv.add(np.clip(fil - 0.6, 0, 1) * shell * 3.4, tint(c2, 1))
    cv.add(np.clip(fil - 0.55, 0, 1) * np.exp(-(R / (radius * 0.8)) ** 2) * 1.2, tint(c, 0.7))
    cv.add_glow(0, 0, 0.045, col(255, 255, 255), 5)
    cv.save(name)


def kind_galaxy(name, c, seed):
    cv = Canvas(seed)
    tilt = 0.35 + (seed % 4) * 0.15
    rot = seed * 0.37
    u = X * math.cos(rot) + Y * math.sin(rot)
    v = (-X * math.sin(rot) + Y * math.cos(rot)) / tilt
    rr = np.sqrt(u * u + v * v)
    th = np.arctan2(v, u)
    arms = 0.5 + 0.5 * np.cos(2 * (th - np.log(rr + 1e-3) * (2 + (seed % 3) * 0.5)))
    disk_env = np.exp(-(rr / 0.62) ** 2)
    cv.add(arms ** 2 * disk_env * (0.5 + fbm(seed, 6, 8)) * 1.3, tint(c, 0.9))
    cv.add(np.exp(-(rr / 0.2) ** 2) * 2.2, col(255, 215, 150))
    lane = arms ** 6 * disk_env * fbm(seed + 1, 5, 10)
    cv.L *= (1 - np.clip(lane * 0.5, 0, 0.6))[..., None]
    cv.add_glow(0, 0, 0.05, col(255, 240, 210), 3)
    cv.save(name)


def kind_lens(name, c, seed):
    cv = Canvas(seed)
    ringr = 0.42 + (seed % 3) * 0.05
    cv.add(np.exp(-((R - ringr) / 0.035) ** 2) * (0.7 + 0.3 * fbm(seed, 4, 6)) * 2.2, tint(c, 1))
    cv.add(np.exp(-((R - ringr) / 0.12) ** 2) * 0.4, tint(c, 0.8))
    cv.add(np.exp(-(R / 0.16) ** 2) * 1.8, col(255, 225, 170))
    cv.save(name)


def kind_quasar(name, c, seed):
    cv = Canvas(seed)
    ang = -0.3 + (seed % 5) * 0.15
    d = cv.disk(0, 0, 0.8, 0.22, ang, tint(c, 1), 0.0)
    cv.add(np.clip(1 - d, 0, 1) ** 1.5 * (0.6 + 0.6 * fbm(seed, 5, 6)) * 1.6, tint(c, 1))
    cv.add(np.clip(1 - d * 1.8, 0, 1) * 2.2, col(255, 215, 170))
    a = ang + math.pi / 2
    dx, dy = math.cos(a), math.sin(a)
    along = X * dx + Y * dy
    perp = -X * dy + Y * dx
    cv.add(np.exp(-(perp / (0.015 + np.abs(along) * 0.05)) ** 2) * np.exp(-np.abs(along) * 1.2) * 1.8, col(200, 210, 255))
    cv.add_glow(0, 0, 0.07, col(255, 255, 255), 8)
    cv.save(name)


KINDS = {
    "sphere": kind_sphere, "point": kind_point, "giant": kind_giant, "binary": kind_binary, "pulsar": kind_pulsar,
    "blackhole": kind_blackhole, "magnetar": kind_magnetar, "nebula": kind_nebula, "remnant": kind_remnant,
    "galaxy": kind_galaxy, "lens": kind_lens, "quasar": kind_quasar,
}
for i, (sid, _en, _ru, kind, color) in enumerate(NAMED):
    KINDS[kind](sid, color, 1000 + i * 7)

# seasonal stars (src/shared/Stars.luau -> Stars.Seasonal): same look, own colours
SEASONAL = [
    ("frostcomet", "point", (170, 230, 255)), ("icenova", "sphere", (140, 210, 255)), ("aurorastar", "giant", (120, 255, 200)),
    ("glacierpulsar", "pulsar", (200, 240, 255)), ("wintercrown", "galaxy", (230, 245, 255)),
    ("embercomet", "point", (255, 150, 80)), ("phoenixstar", "sphere", (255, 110, 50)), ("solarflare", "giant", (255, 200, 60)),
    ("magmapulsar", "pulsar", (255, 80, 40)), ("infernocrown", "galaxy", (255, 60, 90)),
    ("petalcomet", "point", (255, 170, 220)), ("bloomnova", "sphere", (255, 130, 200)), ("springstar", "giant", (170, 255, 140)),
    ("emeraldpulsar", "pulsar", (60, 230, 130)), ("verdantcrown", "galaxy", (120, 255, 170)),
]
for i, (sid, kind, color) in enumerate(SEASONAL):
    KINDS[kind](sid, color, 5000 + i * 11)

for fn in [dust, spark, browndwarf, red_dwarf, whitedwarf, sun, redgiant, bluegiant, binary, pulsar, wolfrayet,
           neutron, hypergiant, quasar, kilonova, supernova, magnetar, nebula, whitehole, eventhorizon, galaxy,
           darkmatter, cosmic, multiverse, bigbang, cosmicweb, infinity]:
    fn()

import re
names = re.findall(r'id = "(\w+)"', (root.parent.parent / "src" / "shared" / "Stars.luau").read_text())
cols = 11
sheet = Image.new("RGBA", (OUT * cols, OUT * math.ceil(len(names) / cols)), (235, 242, 255, 255))
for i, n in enumerate(names):
    sheet.alpha_composite(Image.open(root / f"{n}.png"), ((i % cols) * OUT, (i // cols) * OUT))
sheet.save(root.parent / "stars_preview.png")
print(len(names), "star icons ->", root)
