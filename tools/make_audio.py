# Synthesizes the game's original audio (no third-party samples).
#   assets/audio/music_calm.ogg  - calm looping ambient track
#   assets/audio/rebirth.ogg     - epic rebirth sting
# Run: python3 tools/make_audio.py   (needs numpy + ffmpeg)
import pathlib, subprocess, wave
import numpy as np

SR = 44100
root = pathlib.Path(__file__).resolve().parent.parent / "assets" / "audio"
root.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(42)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def env(n, attack, release, total):
    """attack/sustain/release envelope over n samples (seconds)."""
    t = np.arange(n) / SR
    e = np.minimum(1, t / max(attack, 1e-3))
    rel_start = total - release
    e *= np.clip(1 - (t - rel_start) / max(release, 1e-3), 0, 1)
    return e


def pad_note(freq, dur, amp):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for detune in (-0.0025, 0.0025):
        f = freq * (1 + detune)
        for k in range(1, 7):
            out += np.sin(2 * np.pi * f * k * t + rng.uniform(0, 6)) / k ** 1.7
    tremolo = 1 + 0.08 * np.sin(2 * np.pi * 0.3 * t + rng.uniform(0, 6))
    return out * tremolo * env(n, 1.4, 1.8, dur) * amp


def bell(freq, dur, amp, decay=2.4):
    n = int(dur * SR)
    t = np.arange(n) / SR
    d = np.exp(-t * decay)
    out = np.sin(2 * np.pi * freq * t) + 0.45 * np.sin(2 * np.pi * freq * 2.01 * t) * np.exp(-t * decay * 1.8) \
        + 0.18 * np.sin(2 * np.pi * freq * 3.0 * t) * np.exp(-t * decay * 2.6)
    attack = np.minimum(1, t / 0.006)
    return out * d * attack * amp


def bass(freq, dur, amp):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(2 * np.pi * freq * 2 * t)
    return out * env(n, 0.5, 1.2, dur) * amp


def add(buf, sig, start):
    i = int(start * SR)
    end = min(len(buf), i + len(sig))
    buf[i:end] += sig[: end - i]


def reverb(mono, seconds=2.6, wet=0.35, seed=1):
    """stereo convolution reverb with decaying noise impulse responses"""
    n_ir = int(seconds * SR)
    t = np.arange(n_ir) / SR
    out = []
    for ch in range(2):
        r = np.random.default_rng(seed + ch)
        ir = r.standard_normal(n_ir) * np.exp(-t * 3.2 / seconds)
        ir[: int(0.012 * SR)] = 0  # pre-delay
        # darker tail: simple smoothing
        ir = np.convolve(ir, np.ones(6) / 6, mode="same")
        ir /= np.sqrt(np.sum(ir ** 2))
        size = 1 << int(np.ceil(np.log2(len(mono) + n_ir)))
        wet_sig = np.fft.irfft(np.fft.rfft(mono, size) * np.fft.rfft(ir, size), size)[: len(mono) + n_ir]
        dry = np.concatenate([mono, np.zeros(n_ir)])
        out.append(dry * (1 - wet) + wet_sig * wet * 2.2)
    return np.stack(out, axis=1)


def write(name, stereo, ogg_quality=5):
    stereo = stereo / (np.max(np.abs(stereo)) + 1e-9) * 0.89  # ~ -1 dBFS
    pcm = (stereo * 32767).astype(np.int16)
    wav_path = root / f"{name}.wav"
    with wave.open(str(wav_path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    ogg_path = root / f"{name}.ogg"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path), "-c:a", "libvorbis", "-q:a", str(ogg_quality), str(ogg_path)], check=True)
    wav_path.unlink()
    print(name, f"{len(pcm) / SR:.1f}s", ogg_path.stat().st_size // 1024, "KB")


# ---------------------------------------------------------------- calm music
CHORD = 4.0  # seconds per chord
progression = [
    # (bass root, pad notes)  Am7 - Fmaj7 - Cmaj7 - G6   then   Am7 - Fmaj7 - C - Em7
    (45, [57, 60, 64, 67]), (41, [57, 60, 64, 65]), (48, [55, 59, 60, 64]), (43, [55, 59, 62, 64]),
    (45, [57, 60, 64, 67]), (41, [57, 60, 65, 69]), (48, [55, 60, 64, 67]), (40, [55, 59, 62, 64]),
]
cycles = 3
length = CHORD * len(progression) * cycles  # 96 s
mono = np.zeros(int((length + 4) * SR))
pentatonic = [69, 72, 74, 76, 79, 81, 84]  # A minor pentatonic, upper octave

for c in range(cycles):
    for i, (root_note, notes) in enumerate(progression):
        start = (c * len(progression) + i) * CHORD
        add(mono, bass(midi(root_note), CHORD + 1.0, 0.33), start)
        for note in notes:
            add(mono, pad_note(midi(note), CHORD + 1.6, 0.075), start)
        # gentle melody: chord tones from the pentatonic, sparse, more notes in later cycles
        chord_pcs = {n % 12 for n in notes}
        candidates = [p for p in pentatonic if p % 12 in chord_pcs] or pentatonic
        hits = rng.choice([1, 2, 2, 3] if c > 0 else [1, 1, 2])
        beats = sorted(rng.choice([0, 1, 1.5, 2, 2.5, 3], size=hits, replace=False))
        for b in beats:
            add(mono, bell(midi(int(rng.choice(candidates))), 3.0, 0.16), start + b)
        if c == cycles - 1 and i % 2 == 1:  # sparkle in the last cycle
            add(mono, bell(midi(int(rng.choice(candidates)) + 12), 2.0, 0.05, decay=3.5), start + 3.5)

stereo = reverb(mono, seconds=3.0, wet=0.4)
total = int(length * SR)
looped = stereo[:total].copy()
tail = stereo[total:]
looped[: len(tail)] += tail  # wrap the tail to the start: seamless loop
write("music_calm", looped)

# ---------------------------------------------------------------- rebirth sting
dur = 6.0
mono = np.zeros(int(dur * SR))
t_r = np.arange(int(1.7 * SR)) / SR
# riser: sweeping tone + growing airy noise
sweep_f = 180 * (1600 / 180) ** (t_r / 1.7) ** 1.6
phase = 2 * np.pi * np.cumsum(sweep_f) / SR
riser = (np.sin(phase) + 0.4 * np.sin(2 * phase)) * (t_r / 1.7) ** 2 * 0.35
noise = np.diff(rng.standard_normal(len(t_r) + 1)) * (t_r / 1.7) ** 3 * 0.18
add(mono, riser + noise, 0)
hit = 1.7
# boom: falling sine + punch
t_b = np.arange(int(2.5 * SR)) / SR
boom_f = 40 + 90 * np.exp(-t_b * 7)
boom = np.sin(2 * np.pi * np.cumsum(boom_f) / SR) * np.exp(-t_b * 1.6) * 0.9
burst = rng.standard_normal(len(t_b)) * np.exp(-t_b * 18) * 0.35
add(mono, boom + burst, hit)
# big bright chord (C major across octaves), brassy harmonics, slow fade
t_c = np.arange(int(4.2 * SR)) / SR
chord = np.zeros(len(t_c))
for note in (36, 48, 55, 60, 64, 67, 72, 76):
    f = midi(note)
    for k in range(1, 10):
        chord += np.sin(2 * np.pi * f * k * t_c * (1 + 0.0015 * (k % 3))) / k ** 1.25
chord *= np.minimum(1, t_c / 0.04) * np.exp(-t_c * 0.75) * 0.06
add(mono, chord, hit)
# sparkling arpeggio upward
for i, note in enumerate((72, 76, 79, 84, 88, 91)):
    add(mono, bell(midi(note), 2.5, 0.22 - i * 0.02, decay=2.0), hit + 0.08 + i * 0.09)
write("rebirth", reverb(mono, seconds=3.5, wet=0.45, seed=7)[: int(dur * SR) + int(1.5 * SR)])
