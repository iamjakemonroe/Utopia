"""Generates the worlds' own sounds: Halloween's thunder, wind, witch,
ghosts, bats, owl and creaking window (played in step with the scene by
lib/core/audio/world_soundscape.dart).

Run from the repo root:  python3 tool/synth_world_audio.py
Writes assets/sfx/hw_*.wav. Like synth_audio.py it's pure Python and
everything is synthesized, so there are no licensing questions; swapping
in recorded sounds later only means replacing these files.
"""
import array
import math
import os
import random
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

SR = 22050  # natural sounds don't need more, and it halves the files
OUT = "assets/sfx"

random.seed(31)


def white(seconds):
    n = int(seconds * SR)
    return array.array("d", (random.random() * 2 - 1 for _ in range(n)))


def shape(x, env):
    """Multiplies [x] by env(t)."""
    return array.array("d", (v * env(i / SR) for i, v in enumerate(x)))


def mix(*parts):
    n = max(len(p) for p in parts)
    out = buf(n / SR, SR)
    for p in parts:
        add(out, p, sr=SR)
    return out


def reverb(x, size=1.0, feedback=0.4):
    taps = tuple((d * size, g) for d, g in (
        (0.067, 0.42), (0.113, 0.35), (0.171, 0.28), (0.239, 0.22), (0.331, 0.15),
    ))
    tail = array.array("d", x) + buf(size * 1.2, SR)
    return delay_reverb(tail, sr=SR, taps=taps, feedback=feedback)


def save(name, x, peak=0.85, fade_out=0.08):
    write(f"{OUT}/{name}.wav", fade_edges(normalize(x, peak), sr=SR, fade_out=fade_out), sr=SR)


# ── thunder ────────────────────────────────────────────────────────────────


def thunder(near):
    secs = 5.5
    # The roll: deep noise swelling in a few bumps as the sound arrives from
    # different parts of the bolt.
    bumps = [(0.05 if near else 0.25, 1.0)] + [
        (0.3 + random.random() * 2.2, 0.35 + random.random() * 0.5) for _ in range(5)
    ]

    def roll_env(t):
        v = 0.0
        for at, g in bumps:
            if t >= at:
                d = t - at
                v += g * (1 - math.exp(-d / 0.05)) * math.exp(-d / (0.9 if near else 1.3))
        return v

    deep = biquad(biquad(white(secs), "lp", 110 if near else 80, sr=SR), "lp", 160, sr=SR)
    mid = biquad(white(secs), "bp", 380 if near else 260, q=0.8, sr=SR)
    roll = mix(shape(deep, roll_env), shape(mid, lambda t: 0.25 * roll_env(t)))
    parts = [array.array("d", (v * 3.0 for v in roll))]
    if near:
        # The crack: a bright, splintering burst right at the start.
        crack = biquad(white(0.35), "hp", 1400, sr=SR)
        crack = shape(crack, lambda t: math.exp(-t / 0.05) * (1 + 0.6 * math.sin(t * 900)))
        parts.append(array.array("d", (v * 0.9 for v in crack)))
    out = reverb(mix(*parts), size=1.6, feedback=0.45)
    # Far away, only the deep part of it reaches you.
    return out if near else biquad(out, "lp", 700, sr=SR)


# ── wind ───────────────────────────────────────────────────────────────────


def wind(loop=20.0):
    """A seamless loop: gusts rise and fall on cycles that divide the loop,
    and the last two seconds are crossfaded into the first two."""
    over = 2.0
    secs = loop + over
    two_pi = 2 * math.pi

    def gust(t):
        p = t / loop
        return 0.55 + 0.28 * math.sin(two_pi * p * 2 + 0.4) + 0.17 * math.sin(two_pi * p * 5 + 1.3)

    def center(t):
        p = t / loop
        return 420 + 260 * math.sin(two_pi * p * 3) + 140 * math.sin(two_pi * p * 7 + 2)

    body = biquad(white(secs), "bp", center, q=0.6, sr=SR)
    low = biquad(white(secs), "lp", 180, sr=SR)
    whistle = biquad(white(secs), "bp", lambda t: 1100 + 300 * math.sin(two_pi * t / loop * 4), q=9, sr=SR)
    x = mix(
        shape(body, lambda t: gust(t) * 1.4),
        shape(low, lambda t: 0.6 * gust(t)),
        shape(whistle, lambda t: 0.5 * max(0.0, gust(t) - 0.6)),
    )
    n = int(loop * SR)
    m = int(over * SR)
    out = array.array("d", x[:n])
    for i in range(m):
        k = i / m
        out[i] = out[i] * k + x[n + i] * (1 - k)
    return out


# ── the witch ──────────────────────────────────────────────────────────────


def voice(f0_fn, seconds, formants, breath=0.15):
    """A buzzy voice: a sawtooth at f0_fn(t) through formant resonances."""
    n = int(seconds * SR)
    src = array.array("d", bytes(8 * n))
    phase = 0.0
    for i in range(n):
        t = i / SR
        phase += f0_fn(t) / SR
        src[i] = (phase % 1.0) * 2 - 1
    out = buf(seconds, SR)
    for f, q, g in formants:
        add(out, array.array("d", (v * g for v in biquad(src, "bp", f, q=q, sr=SR))), sr=SR)
    add(out, array.array("d", (v * breath for v in biquad(white(seconds), "bp", 2400, q=1.2, sr=SR))), sr=SR)
    return out


def witch():
    secs = 2.8
    # Her broom sweeping past, the swoosh rising as she nears and falling
    # away.
    swoosh = biquad(
        white(secs),
        "bp",
        lambda t: 300 + 1600 * math.exp(-((t - 1.0) / 0.45) ** 2),
        q=1.4,
        sr=SR,
    )
    swoosh = shape(swoosh, lambda t: math.exp(-((t - 1.0) / 0.5) ** 2) * 0.7)
    # The cackle: "heh-heh-heh-ha-ha-haaa", high, jittery and falling.
    cackle = buf(secs, SR)
    at = 0.45
    syllables = [(0.09, 980), (0.09, 960), (0.1, 930), (0.12, 880), (0.12, 840), (0.42, 800)]
    for k, (length, pitch) in enumerate(syllables):
        last = k == len(syllables) - 1

        def f0(t, p=pitch, last=last, length=length):
            glide = -260 * (t / length) if last else -40 * (t / length)
            return p + glide + 22 * math.sin(t * 2 * math.pi * 7) + random.uniform(-15, 15)

        v = voice(f0, length, [(950, 4, 1.0), (1700, 6, 0.6), (2900, 8, 0.3)])
        v = shape(v, lambda t, length=length: min(1.0, t / 0.008) * math.exp(-t / (length * 0.55)))
        add(cackle, v, at=at, sr=SR)
        at += length + (0.05 if not last else 0)
    return reverb(mix(swoosh, array.array("d", (v * 3.2 for v in cackle))), size=1.0, feedback=0.3)


# ── ghosts ─────────────────────────────────────────────────────────────────


def ghost(base):
    """A hollow "wooOOOooo": a breathy, wavering voice rising and falling."""
    secs = 3.0

    def f0(t):
        rise = math.sin(math.pi * min(1.0, t / 2.6))
        return base * (1 + 0.45 * rise) + 7 * math.sin(t * 2 * math.pi * 5.2)

    v = voice(f0, secs, [(380, 3, 1.0), (760, 5, 0.35)], breath=0.3)
    v = biquad(v, "lp", 900, sr=SR)
    v = shape(v, lambda t: min(1.0, t / 0.45) * min(1.0, max(0.0, (secs - t) / 0.9)))
    return reverb(v, size=1.8, feedback=0.5)


# ── bats ───────────────────────────────────────────────────────────────────


def bats():
    secs = 1.1
    out = buf(secs, SR)
    # Squeaks: tiny falling chirps.
    for k in range(5):
        at = 0.05 + k * 0.17 + random.uniform(-0.03, 0.03)
        length = random.uniform(0.025, 0.045)
        top = random.uniform(6500, 8200)
        n = int(length * SR)
        chirp = array.array("d", bytes(8 * n))
        phase = 0.0
        for i in range(n):
            t = i / SR
            phase += (top - (top - 3800) * (t / length)) / SR
            chirp[i] = math.sin(2 * math.pi * phase) * math.sin(math.pi * t / length)
        add(out, array.array("d", (v * 0.6 for v in chirp)), at=at, sr=SR)
    # Leathery wings fluttering past.
    flap = biquad(white(secs), "bp", 700, q=1.0, sr=SR)
    flap = shape(flap, lambda t: (0.5 + 0.5 * math.sin(t * 2 * math.pi * 17)) ** 3 * math.sin(math.pi * t / secs))
    add(out, array.array("d", (v * 0.9 for v in flap)), sr=SR)
    return reverb(out, size=0.8, feedback=0.3)


# ── owl ────────────────────────────────────────────────────────────────────


def owl():
    out = buf(2.2, SR)
    for at, length, pitch in [(0.0, 0.32, 395), (0.55, 0.16, 400), (0.78, 0.55, 385)]:
        n = int(length * SR)
        hoot = array.array("d", bytes(8 * n))
        phase = 0.0
        for i in range(n):
            t = i / SR
            phase += (pitch - 35 * (t / length) ** 2) / SR
            env = min(1.0, t / 0.04) * min(1.0, (length - t) / 0.08)
            hoot[i] = (math.sin(2 * math.pi * phase) + 0.12 * math.sin(4 * math.pi * phase)) * env
        breath = shape(biquad(white(length), "lp", 900, sr=SR), lambda t, length=length: 0.08 * math.sin(math.pi * t / length))
        add(out, hoot, at=at, sr=SR)
        add(out, breath, at=at, sr=SR)
    # A soft, short space round it, not an echo that repeats the hoots.
    return reverb(out, size=0.9, feedback=0.18)


# ── a creak ────────────────────────────────────────────────────────────────


def creak():
    """Old wood or hinges: a stick-slip train of clicks ringing in the
    wood's resonances, its rate wandering."""
    secs = 1.3
    n = int(secs * SR)
    clicks = array.array("d", bytes(8 * n))
    t = 0.05
    while t < secs - 0.05:
        i = int(t * SR)
        clicks[i] = random.uniform(0.6, 1.0)
        rate = 28 + 30 * math.sin(math.pi * t / secs) + random.uniform(-4, 4)
        t += 1 / rate
    rung = mix(*[
        array.array("d", (v * g for v in biquad(clicks, "bp", f, q=12, sr=SR)))
        for f, g in [(620, 1.0), (1150, 0.7), (2350, 0.35)]
    ])
    rung = shape(rung, lambda t: math.sin(math.pi * min(1.0, t / secs)))
    return reverb(rung, size=0.7, feedback=0.3)


def main():
    save("hw_thunder_near", thunder(near=True), peak=0.9, fade_out=0.6)
    save("hw_thunder_far", thunder(near=False), peak=0.8, fade_out=0.6)
    write(f"{OUT}/hw_wind.wav", normalize(wind(), 0.7), sr=SR)
    save("hw_witch", witch())
    save("hw_ghost_1", ghost(200), peak=0.8, fade_out=0.5)
    save("hw_ghost_2", ghost(150), peak=0.8, fade_out=0.5)
    save("hw_bats", bats(), peak=0.7)
    save("hw_owl", owl(), peak=0.75, fade_out=0.4)
    save("hw_creak", creak(), peak=0.75)


if __name__ == "__main__":
    main()
