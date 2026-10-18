"""Generates the worlds' own music: Halloween's calm, spooky soundscape (it
replaces the menu music there; lib/core/audio/world_soundscape.dart plays
it in step with the scene).

Run from the repo root:  python3 tool/synth_world_audio.py
Writes assets/music/halloween.m4a (a slow, dark pad that drifts over a
minute and loops seamlessly) and assets/sfx/hw_*.wav: music-box notes for
a lullaby that's never the same twice, a distant rumble for the lightning,
a ghost's breathy "ooo", a shimmer of magic for the witch, a far-off bell
and an owl. Everything soft and distant: no wind, no cracks, no shrieks.

Pure Python like synth_audio.py (afconvert, built into macOS, compresses
the pad); everything is synthesized, so there are no licensing questions.
"""
import array
import math
import os
import random
import subprocess
import sys

sys.path.insert(0, os.path.dirname(__file__))
from synth_audio import (  # noqa: E402
    add,
    biquad,
    buf,
    delay_reverb,
    fade_edges,
    normalize,
    write,
)

SR = 22050
OUT_SFX = "assets/sfx"
OUT_MUSIC = "assets/music"

random.seed(13)


def white(seconds):
    n = int(seconds * SR)
    return array.array("d", (random.random() * 2 - 1 for _ in range(n)))


def shape(x, env):
    return array.array("d", (v * env(i / SR) for i, v in enumerate(x)))


def scale(x, g):
    return array.array("d", (v * g for v in x))


def reverb(x, size=1.0, feedback=0.3):
    taps = tuple((d * size, g) for d, g in (
        (0.071, 0.40), (0.109, 0.33), (0.163, 0.27), (0.233, 0.21), (0.317, 0.14),
    ))
    # Ease the dry sound out first: a sudden end would click, and the echoes
    # would repeat the click.
    x = array.array("d", x)
    k = min(len(x), int(0.35 * SR))
    for i in range(k):
        x[len(x) - 1 - i] *= 0.5 - 0.5 * math.cos(math.pi * i / k)
    tail = x + buf(size * 1.5, SR)
    return delay_reverb(tail, sr=SR, taps=taps, feedback=feedback)


def save(name, x, peak=0.8, fade_out=0.3):
    x = normalize(x, peak)
    # Cut the reverb's tail where it's faded below hearing.
    end = len(x)
    while end > SR and abs(x[end - 1]) < 0.004:
        end -= 1
    x = array.array("d", x[: min(len(x), end + int(0.05 * SR))])
    write(f"{OUT_SFX}/{name}.wav", fade_edges(x, sr=SR, fade_out=fade_out), sr=SR)


def partials(freq, seconds, parts, attack=0.003):
    """Sum of decaying sine partials: (ratio, gain, decay seconds)."""
    n = int(seconds * SR)
    out = array.array("d", bytes(8 * n))
    a = max(1, int(attack * SR))
    for ratio, gain, decay in parts:
        w = 2 * math.pi * freq * ratio / SR
        for i in range(n):
            env = (i / a if i < a else 1.0) * math.exp(-(i / SR) / decay)
            out[i] += gain * env * math.sin(w * i)
    return out


# ── the bed ────────────────────────────────────────────────────────────────


def bed(loop=64.0):
    """A dark D-minor pad over a low drone. Every frequency and every swell
    makes whole cycles in [loop], so it joins up seamlessly; its voices swell
    on different cycles, so it keeps shifting, and it's quietest at the loop
    point, where a player might otherwise notice the join."""
    n = int(loop * SR)
    out = array.array("d", bytes(8 * n))
    q = 1 / loop  # every frequency is a whole number of these

    def snap(f):
        return round(f / q) * q

    two_pi = 2 * math.pi
    # (frequency, gain, swell cycles per loop, swell phase)
    voices = [
        (73.42, 0.20, 2, 0.0),   # D2 drone
        (110.0, 0.10, 3, 1.3),   # A2
        (146.83, 0.07, 1, 0.4),  # D3
        (174.61, 0.06, 5, 2.1),  # F3
        (220.0, 0.05, 3, 4.0),   # A3
        (261.63, 0.04, 4, 0.9),  # C4
        (329.63, 0.03, 7, 3.3),  # E4, the ninth: a little unease
        (880.0, 0.008, 1, 3.1),  # A5, a faint glassy shimmer above
    ]
    for v, (f, gain, cycles, phase) in enumerate(voices):
        # Two copies a hair apart beat slowly, like a breath; each voice at
        # its own rate, so they never all fall quiet together.
        for detune, level in ((0.0, 1.0), ((3, 5, 7, 11, 13, 17, 19, 23)[v] * q, 0.35)):
            w = two_pi * snap(f + detune)
            for i in range(n):
                t = i / SR
                swell = 0.5 + 0.5 * math.sin(two_pi * cycles * t / loop + phase)
                p = w * t
                # Soft, dark tone: the fundamental and a whisper of the third.
                out[i] += gain * 0.6 * level * swell * (math.sin(p) + 0.12 * math.sin(3 * p))
    for i in range(n):
        t = i / SR
        out[i] *= 0.65 - 0.35 * math.cos(two_pi * t / loop)
    return out


# ── the lullaby's notes ────────────────────────────────────────────────────


def music_box(freq):
    tone = partials(freq, 3.2, [(1.0, 1.0, 1.4), (2.0, 0.22, 0.6), (3.0, 0.06, 0.35), (4.16, 0.08, 0.25)])
    return reverb(biquad(tone, "lp", 3200, sr=SR), size=1.4, feedback=0.32)


# ── a distant rumble ───────────────────────────────────────────────────────


def rumble(seed):
    random.seed(seed)
    secs = 4.5
    bumps = [(0.0, 1.0)] + [(0.4 + random.random() * 1.8, 0.3 + random.random() * 0.4) for _ in range(3)]

    def env(t):
        v = 0.0
        for at, g in bumps:
            if t >= at:
                d = t - at
                v += g * (1 - math.exp(-d / 0.45)) * math.exp(-d / 1.6)
        return v

    deep = biquad(biquad(white(secs), "lp", 95, sr=SR), "lp", 140, sr=SR)
    return reverb(scale(shape(deep, env), 3.0), size=1.8, feedback=0.3)


# ── a ghost's breath ───────────────────────────────────────────────────────


def ghost(base):
    """A soft, breathy "ooo" drifting up and away."""
    secs = 3.4
    n = int(secs * SR)
    src = array.array("d", bytes(8 * n))
    phase = 0.0
    for i in range(n):
        t = i / SR
        phase += base * (1 + 0.18 * math.sin(math.pi * min(1.0, t / 3.0))) / SR
        src[i] = math.sin(2 * math.pi * phase) + 0.3 * math.sin(4 * math.pi * phase)
    breath = biquad(white(secs), "bp", 520, q=1.6, sr=SR)
    mixed = buf(secs, SR)
    add(mixed, scale(biquad(src, "lp", 600, sr=SR), 0.45), sr=SR)
    add(mixed, scale(breath, 0.55), sr=SR)
    mixed = biquad(mixed, "lp", 1000, sr=SR)
    mixed = shape(mixed, lambda t: min(1.0, t / 0.8) * min(1.0, max(0.0, (secs - t) / 1.4)))
    return reverb(mixed, size=2.0, feedback=0.36)


# ── the witch's magic ──────────────────────────────────────────────────────


def magic():
    """A soft swish of her broom and a sprinkle of rising chimes."""
    secs = 3.0
    swish = biquad(
        white(secs),
        "bp",
        lambda t: 600 + 900 * math.exp(-((t - 0.7) / 0.5) ** 2),
        q=0.7,
        sr=SR,
    )
    swish = shape(swish, lambda t: 0.25 * math.exp(-((t - 0.7) / 0.45) ** 2))
    out = buf(secs, SR)
    add(out, swish, sr=SR)
    for k, f in enumerate([880.0, 1174.66, 1396.91, 1760.0]):
        chime = partials(f, 1.6, [(1.0, 1.0, 0.5), (2.0, 0.15, 0.25)])
        add(out, scale(chime, 0.32 - 0.04 * k), at=0.55 + k * 0.11, sr=SR)
    return reverb(biquad(out, "lp", 4000, sr=SR), size=1.5, feedback=0.32)


# ── a far-off bell ─────────────────────────────────────────────────────────


def bell(freq=196.0):
    """A church bell somewhere across the hollow: its hum, strike and tierce,
    softened by the distance."""
    tone = partials(freq, 6.0, [
        (0.5, 0.45, 4.5),   # hum
        (1.0, 0.8, 3.0),    # prime
        (1.19, 0.55, 2.4),  # tierce (the bell's minor third)
        (1.5, 0.3, 1.8),    # quint
        (2.0, 0.45, 1.5),   # nominal
        (2.52, 0.12, 0.9),
        (3.0, 0.08, 0.7),
    ], attack=0.004)
    return reverb(biquad(tone, "lp", 1400, sr=SR), size=2.2, feedback=0.34)


# ── an owl ─────────────────────────────────────────────────────────────────


def owl():
    out = buf(2.2, SR)
    for at, length, pitch in [(0.0, 0.34, 360), (0.6, 0.18, 365), (0.86, 0.6, 352)]:
        n = int(length * SR)
        hoot = array.array("d", bytes(8 * n))
        phase = 0.0
        for i in range(n):
            t = i / SR
            phase += (pitch - 30 * (t / length) ** 2) / SR
            env = min(1.0, t / 0.06) * min(1.0, (length - t) / 0.1)
            hoot[i] = math.sin(2 * math.pi * phase) * env
        add(out, hoot, at=at, sr=SR)
    return reverb(biquad(out, "lp", 700, sr=SR), size=1.4, feedback=0.22)


def main():
    for old in os.listdir(OUT_SFX):
        if old.startswith("hw_"):
            os.remove(os.path.join(OUT_SFX, old))

    wav = f"{OUT_MUSIC}/halloween.wav"
    write(wav, normalize(bed(), 0.6), sr=SR)
    subprocess.run(
        ["afconvert", "-f", "m4af", "-d", "aac", "-b", "64000", wav, f"{OUT_MUSIC}/halloween.m4a"],
        check=True,
    )
    os.remove(wav)
    print(f"wrote {OUT_MUSIC}/halloween.m4a")

    # D minor pentatonic, high and small, like a music box.
    for k, f in enumerate([587.33, 698.46, 783.99, 880.0, 1046.5, 1174.66], start=1):
        save(f"hw_note_{k}", music_box(f), peak=0.7, fade_out=0.6)
    save("hw_rumble_1", rumble(5), peak=0.75, fade_out=0.8)
    save("hw_rumble_2", rumble(9), peak=0.75, fade_out=0.8)
    save("hw_ghost_1", ghost(165), peak=0.7, fade_out=0.8)
    save("hw_ghost_2", ghost(130), peak=0.7, fade_out=0.8)
    save("hw_magic", magic(), peak=0.7, fade_out=0.6)
    save("hw_bell", bell(), peak=0.75, fade_out=1.0)
    save("hw_owl", owl(), peak=0.7, fade_out=0.6)


if __name__ == "__main__":
    main()
