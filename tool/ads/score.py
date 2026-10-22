"""The trailer's score, synthesized: a dark drone and a heartbeat, an
impact, a theme that lifts (A minor, F, C, G at 120 bpm, a bar every two
seconds so the cuts land on bar lines), drums for the worlds and the games,
a ticking drop with stuttering hits, a second impact, and a hopeful C major
finale that rings out. Times match tool/ads/trailer.py.

  python tool/ads/score.py out.wav
"""
import sys
import wave

import numpy as np

SR = 48000
LENGTH = 76.0
N = int(SR * LENGTH)
rng = np.random.default_rng(7)

IMPACT_1 = 11.5
WORLDS = 19.5
GAMES = 43.5
TENSION = 55.5
FLASHES = 60.0
IMPACT_2 = 63.5
BEAT = 0.5


def t_of(n):
    return np.arange(n) / SR


def note(name):
    names = {'C': -9, 'D': -7, 'E': -5, 'F': -4, 'G': -2, 'A': 0, 'B': 2}
    semis = names[name[0]]
    rest = name[1:]
    if rest.startswith('#'):
        semis += 1
        rest = rest[1:]
    elif rest.startswith('b'):
        semis -= 1
        rest = rest[1:]
    octave = int(rest)
    return 440.0 * 2 ** ((semis + (octave - 4) * 12) / 12)


def place(buf, sig, at, gain=1.0):
    """Adds [sig] (mono or stereo) into stereo [buf] at [at] seconds."""
    i = int(at * SR)
    if i >= len(buf):
        return
    if sig.ndim == 1:
        sig = np.stack([sig, sig], axis=1)
    j = min(len(buf), i + len(sig))
    buf[i:j] += sig[: j - i] * gain


def lowpass(sig, cutoff):
    spec = np.fft.rfft(sig, axis=0)
    f = np.fft.rfftfreq(len(sig), 1 / SR)
    curve = 1 / np.sqrt(1 + (f / cutoff) ** 4)
    if sig.ndim == 2:
        curve = curve[:, None]
    return np.fft.irfft(spec * curve, n=len(sig), axis=0)


def highpass(sig, cutoff):
    return sig - lowpass(sig, cutoff)


def env(n, attack, release, sustain=1.0):
    e = np.full(n, sustain)
    a = int(attack * SR)
    r = int(release * SR)
    if a:
        e[:a] = np.linspace(0, sustain, a)
    if r:
        e[-r:] *= np.linspace(1, 0, r)
    return e


def saw_pad(freq, dur, voices=5, detune=0.012, harmonics=10):
    n = int(dur * SR)
    t = t_of(n)
    left = np.zeros(n)
    right = np.zeros(n)
    for v in range(voices):
        d = 1 + detune * (v - (voices - 1) / 2) / ((voices - 1) / 2 or 1)
        phase = rng.random() * 2 * np.pi
        wave_ = sum(np.sin(2 * np.pi * freq * d * h * t + phase * h) / h
                    for h in range(1, harmonics + 1))
        pan = v / max(1, voices - 1)
        left += wave_ * (1 - pan * 0.6)
        right += wave_ * (0.4 + pan * 0.6)
    return np.stack([left, right], axis=1) / voices


def pluck(freq, dur=0.6, bright=0.35):
    n = int(dur * SR)
    t = t_of(n)
    e = np.exp(-t * 7)
    sig = (np.sin(2 * np.pi * freq * t) + bright * np.sin(4 * np.pi * freq * t)
           + 0.15 * np.sin(6 * np.pi * freq * t)) * e
    sig[: int(0.004 * SR)] *= np.linspace(0, 1, int(0.004 * SR))
    return sig


def bell(freq, dur=2.5):
    n = int(dur * SR)
    t = t_of(n)
    sig = sum(a * np.sin(2 * np.pi * freq * r * t) * np.exp(-t * d)
              for r, a, d in [(1, 1, 1.6), (2.76, 0.4, 3), (5.4, 0.2, 5), (2, 0.3, 2.2)])
    return sig


def kick(gain=1.0):
    n = int(0.45 * SR)
    t = t_of(n)
    f = 45 + 95 * np.exp(-t * 28)
    phase = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(phase) * np.exp(-t * 7) * gain


def snare():
    n = int(0.3 * SR)
    t = t_of(n)
    noise = highpass(rng.standard_normal(n), 1200) * np.exp(-t * 16)
    tone = np.sin(2 * np.pi * 185 * t) * np.exp(-t * 22)
    return noise * 0.5 + tone * 0.5


def hat():
    n = int(0.08 * SR)
    t = t_of(n)
    return highpass(rng.standard_normal(n), 7000) * np.exp(-t * 60) * 0.35


def boom(dur=4.0):
    """An impact: a falling sub, a crash of noise, and a braam."""
    n = int(dur * SR)
    t = t_of(n)
    f = 28 + 50 * np.exp(-t * 6)
    sub = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 1.1)
    crash = lowpass(rng.standard_normal(n), 3500) * np.exp(-t * 2.2) * 0.5
    braam = saw_pad(note('A1'), dur, voices=7, detune=0.02, harmonics=18)
    braam = lowpass(braam, 900) * (np.exp(-t * 0.7) * (1 - np.exp(-t * 30)))[:, None] * 1.2
    out = braam + np.stack([sub, sub], axis=1) * 1.4 + np.stack([crash, crash * 0.9], axis=1)
    return out


def ostinato_note(freq, dur, cutoff=900):
    """One 16th of the pulsing bass: a saw, plucked shut by its filter."""
    n = int(dur * SR)
    t = t_of(n)
    wave_ = sum(np.sin(2 * np.pi * freq * h * t) / h for h in range(1, 14))
    wave_ += sum(np.sin(2 * np.pi * freq * 1.005 * h * t) / h for h in range(1, 14))
    wave_ = lowpass(wave_, cutoff) * np.exp(-t * 9)
    wave_[: int(0.003 * SR)] *= np.linspace(0, 1, int(0.003 * SR))
    return wave_ * 0.5


def braam(dur=4.0, root='A1'):
    """The trailer horn: detuned saws an octave and a fifth apart, driven
    hard, the filter opening then closing."""
    n = int(dur * SR)
    t = t_of(n)
    stack = saw_pad(note(root), dur, voices=7, detune=0.025, harmonics=24)
    stack += saw_pad(note(root) * 2, dur, voices=5, detune=0.02, harmonics=16) * 0.6
    stack += saw_pad(note(root) * 3, dur, voices=4, detune=0.02, harmonics=12) * 0.35
    stack = np.tanh(stack * 2.2)
    shape = (1 - np.exp(-t * 12)) * np.exp(-t * 0.55)
    return lowpass(stack, 1100) * shape[:, None]


def swell(dur=1.2):
    """A reverse swell: a hit's tail played backwards, sucking in."""
    n = int(dur * SR)
    t = t_of(n)
    tail = lowpass(rng.standard_normal(n), 2500) * np.exp(-t * 3.5)
    tone = saw_pad(note('A2'), dur, voices=3, harmonics=8)[:, 0] * np.exp(-t * 2.5) * 0.4
    return (tail * 0.7 + tone)[::-1]


def tom(freq=95, gain=1.0):
    n = int(0.7 * SR)
    t = t_of(n)
    f = freq * (0.65 + 0.35 * np.exp(-t * 18))
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 5)
    skin = lowpass(rng.standard_normal(n), 900) * np.exp(-t * 30) * 0.4
    return (body + skin) * gain


def lead(freq, dur):
    """A bright lead: odd harmonics, a little vibrato coming in."""
    n = int(dur * SR)
    t = t_of(n)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t / 0.4, 0, 1)
    phase = 2 * np.pi * np.cumsum(freq * vib) / SR
    wave_ = sum(np.sin(h * phase) / h for h in (1, 3, 5, 7, 9))
    return lowpass(wave_, 4200) * env(n, 0.04, min(0.4, dur * 0.4))


def riser(dur, start=200, end=2600):
    n = int(dur * SR)
    t = t_of(n)
    k = t / dur
    noise = rng.standard_normal(n)
    dark = lowpass(noise, start)
    bright = lowpass(noise, end)
    sig = dark * (1 - k) + bright * k
    sweep = np.sin(2 * np.pi * np.cumsum(110 * 2 ** (k * 3)) / SR) * 0.3
    return (sig * 0.6 + sweep) * k ** 2


def heartbeat():
    n = int(0.5 * SR)
    t = t_of(n)
    one = np.sin(2 * np.pi * 50 * t) * np.exp(-t * 18)
    two = np.zeros(n)
    k = int(0.22 * SR)
    two[k:] = np.sin(2 * np.pi * 46 * t[: n - k]) * np.exp(-t[: n - k] * 20) * 0.75
    return one + two


def tick():
    n = int(0.05 * SR)
    t = t_of(n)
    return highpass(rng.standard_normal(n), 3000) * np.exp(-t * 120) * 0.5 + \
        np.sin(2 * np.pi * 2400 * t) * np.exp(-t * 90) * 0.3


def reverb(sig, seconds=2.6, mix=0.35):
    n = int(seconds * SR)
    t = t_of(n)
    ir_l = rng.standard_normal(n) * np.exp(-t * 3.2 / seconds * 3)
    ir_r = rng.standard_normal(n) * np.exp(-t * 3.2 / seconds * 3)
    ir_l[0] = ir_r[0] = 0
    size = 1 << int(np.ceil(np.log2(len(sig) + n)))
    out = np.zeros_like(sig)
    for ch, ir in ((0, ir_l), (1, ir_r)):
        wet = np.fft.irfft(np.fft.rfft(sig[:, ch], size) * np.fft.rfft(ir, size), size)[: len(sig)]
        wet /= np.sqrt(np.sum(ir ** 2)) * 6
        out[:, ch] = sig[:, ch] * (1 - mix) + wet * mix * 3
    return out


CHORDS = [  # a bar each (two seconds), round and round
    ('A2', ['A3', 'C4', 'E4'], ['A4', 'C5', 'E5', 'A5']),
    ('F2', ['F3', 'A3', 'C4'], ['F4', 'A4', 'C5', 'F5']),
    ('C3', ['C4', 'E4', 'G4'], ['C5', 'E5', 'G5', 'C6']),
    ('G2', ['G3', 'B3', 'D4'], ['G4', 'B4', 'D5', 'G5']),
]


def build():
    music = np.zeros((N, 2))
    fx = np.zeros((N, 2))  # impacts and risers, kept out of the reverb

    # ── the cold open: drone, heartbeat, a riser into the gate ─────────────
    drone = saw_pad(note('A1'), IMPACT_1 + 0.3, voices=4, harmonics=6) * 0.5
    drone += saw_pad(note('E2'), IMPACT_1 + 0.3, voices=3, harmonics=5) * 0.25
    drone = lowpass(drone, 420) * env(len(drone), 3.0, 0.4)[:, None]
    place(music, drone, 0)
    for k in np.arange(0.8, IMPACT_1 - 1.0, 1.15):
        place(fx, heartbeat(), k, 0.9)
    place(music, bell(note('E5'), 3.5) * 0.12, 4.2)
    place(music, bell(note('C5'), 3.5) * 0.10, 6.6)
    place(fx, riser(3.0), IMPACT_1 - 3.0, 0.7)
    place(fx, swell(1.2), IMPACT_1 - 1.2, 0.8)
    place(fx, boom(5.0), IMPACT_1, 1.0)
    place(fx, braam(5.0), IMPACT_1, 0.7)

    # ── the theme: pads, bass, arpeggio; drums from the worlds on ──────────
    end_theme = TENSION
    bar = 0
    t = IMPACT_1
    while t < end_theme - 0.01:
        root, triad, arp = CHORDS[bar % 4]
        pad = saw_pad(note(triad[0]), 2.2, harmonics=8) + saw_pad(note(triad[1]), 2.2, harmonics=8) \
            + saw_pad(note(triad[2]), 2.2, harmonics=8)
        pad = lowpass(pad, 1400 if t < GAMES else 2200) * env(int(2.2 * SR), 0.25, 0.4)[:, None]
        if t >= WORLDS - 0.01:
            # Pumping: ducked on each beat, breathing back in.
            tt = t_of(len(pad))
            pump = 1 - 0.55 * np.exp(-((tt % BEAT) * 9))
            pad = pad * pump[:, None]
        place(music, pad, t, 0.16)
        # The pulse: 16ths on the root, brighter as it goes.
        cutoff = 700 if t < WORLDS else (1100 if t < GAMES else 1600)
        for s16 in range(16):
            octave = 2 if s16 % 4 == 2 else 1
            place(music, ostinato_note(note(root) * octave, BEAT / 4 * 0.95, cutoff), t + s16 * BEAT / 4,
                  0.22 if t >= WORLDS else 0.14)
        if t >= GAMES:
            for k, f in ((0, 95), (0.75, 80), (1.5, 95), (1.75, 70)):
                place(music, tom(f, 0.5), t + k)
        for b in range(4):
            place(music, pluck(note(root), 0.55, 0.2), t + b * BEAT, 0.32 if b % 2 == 0 else 0.18)
        if t >= WORLDS - 0.01:
            pattern = [0, 1, 2, 3, 2, 1, 3, 2] if (bar % 2) else [0, 2, 1, 3, 0, 2, 3, 1]
            for e8 in range(8):
                f = note(arp[pattern[e8]])
                place(music, pluck(f, 0.5, 0.45), t + e8 * BEAT / 2,
                      0.10 if t < GAMES else 0.13)
            for b in range(4):
                place(music, kick(1.0 if t >= GAMES else 0.7), t + b * BEAT)
                if t >= GAMES and b in (1, 3):
                    place(music, snare(), t + b * BEAT, 0.5)
            for e8 in range(8):
                place(music, hat(), t + e8 * BEAT / 2, 0.8 if e8 % 2 else 0.4)
        else:
            # Before the worlds: the arpeggio, sparser and softer.
            for e8 in range(0, 8, 2):
                place(music, pluck(note(arp[(e8 // 2) % 4]), 0.6, 0.3), t + e8 * BEAT / 2, 0.08)
        t += 2.0
        bar += 1

    # A lift into the games.
    place(fx, riser(2.0, 400, 5000), GAMES - 2.0, 0.35)
    place(fx, boom(2.5), GAMES, 0.45)

    # ── the drop: drone and a clock, then hits under the flashes ──────────
    drop = saw_pad(note('A1'), IMPACT_2 - TENSION + 0.2, voices=4, harmonics=6) * 0.6
    drop = lowpass(drop, 300) * env(len(drop), 0.3, 0.2)[:, None]
    place(music, drop, TENSION)
    for k in np.arange(TENSION, IMPACT_2 - 0.05, BEAT):
        place(fx, tick(), k, 0.7)
    for k in np.arange(TENSION, FLASHES, BEAT / 4):
        place(music, ostinato_note(note('A1'), BEAT / 4 * 0.9, 420), k, 0.2)
    for i, k in enumerate(np.arange(TENSION + 2.0, FLASHES, BEAT)):
        place(fx, tom(85, 0.35 + 0.05 * i), k)
    for k in np.arange(TENSION + 0.5, FLASHES, 1.0):
        place(fx, heartbeat(), k, 0.8)
    place(fx, riser(IMPACT_2 - FLASHES, 300, 7000), FLASHES, 0.8)
    for i, k in enumerate(np.arange(FLASHES, IMPACT_2 - 0.1, 0.25)):
        place(fx, kick(0.6 + 0.4 * i / 14), k)
    place(fx, swell(1.0), IMPACT_2 - 1.0, 0.9)
    place(fx, boom(6.0), IMPACT_2, 1.1)
    place(fx, braam(6.0, 'C2'), IMPACT_2, 0.8)

    # ── the finale: C major, a melody on bells, rung out ───────────────────
    fin = IMPACT_2 + 0.3
    for start, triad, root, dur in [(fin, ['C4', 'E4', 'G4', 'B4'], 'C3', 2.0),
                                    (fin + 2.0, ['F3', 'A3', 'C4', 'E4'], 'F2', 2.0),
                                    (fin + 4.0, ['C4', 'E4', 'G4', 'C5'], 'C3', LENGTH - fin - 4.0)]:
        pad = sum(saw_pad(note(n_), dur + 0.3, harmonics=9) for n_ in triad)
        pad = lowpass(pad, 2600) * env(int((dur + 0.3) * SR), 0.6, min(1.5, dur * 0.5))[:, None]
        place(music, pad, start, 0.14)
        bass = saw_pad(note(root), dur + 0.3, voices=2, harmonics=4)
        bass = lowpass(bass, 300) * env(len(bass), 0.2, 0.6)[:, None]
        place(music, bass, start, 0.35)
    melody = [('E5', 0, 0.5), ('G5', 0.5, 0.5), ('A5', 1.0, 0.5), ('G5', 1.5, 0.75), ('E5', 2.25, 0.5),
              ('D5', 2.75, 0.75), ('C5', 3.5, 0.75), ('G5', 4.25, 0.75), ('C6', 5.0, 3.0)]
    for n_, k, d in melody:
        place(music, bell(note(n_), 3.0), fin + k, 0.12)
        place(music, lead(note(n_), d), fin + k, 0.09)
    for e8 in range(int((LENGTH - fin - 3) / (BEAT / 2))):
        n_ = ['C5', 'E5', 'G5', 'C6', 'G5', 'E5'][e8 % 6]
        place(music, pluck(note(n_), 0.5, 0.5), fin + e8 * BEAT / 2, 0.05)

    # The worlds sit up in the mix.
    lift = np.ones(N)
    a, b = int(WORLDS * SR), int(GAMES * SR)
    lift[a:b] = 1.4
    music *= lift[:, None]
    out = reverb(music, 2.8, 0.3) + reverb(fx, 1.8, 0.15)
    # Fades: in from silence, out at the very end.
    fade = np.ones(N)
    fade[-int(2.5 * SR):] = np.linspace(1, 0, int(2.5 * SR))
    out *= fade[:, None]
    out /= np.max(np.abs(out)) / 0.89
    return out


def write(path, sig):
    data = (np.clip(sig, -1, 1) * 32767).astype('<i2')
    with wave.open(path, 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


if __name__ == '__main__':
    write(sys.argv[1] if len(sys.argv) > 1 else 'score.wav', build())
