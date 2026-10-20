"""Generates Utopia's sound effects and music loops from scratch.

Run from the repo root:  python3 tool/synth_audio.py
Writes assets/sfx/*.wav and assets/music/*.wav. Pure Python (no numpy), so
it runs anywhere; everything is synthesized, so there are no licensing
questions about the audio.
"""
import array
import math
import os
import random
import wave

SR = 44100
MUSIC_SR = 22050
OUT_SFX = "assets/sfx"
OUT_MUSIC = "assets/music"

random.seed(7)


# ── primitives ─────────────────────────────────────────────────────────────


def buf(seconds, sr=SR):
    return array.array("d", bytes(8 * int(seconds * sr)))


def add(dst, src, at=0.0, gain=1.0, sr=SR):
    start = int(at * sr)
    n = min(len(src), len(dst) - start)
    for i in range(max(0, n)):
        dst[start + i] += src[i] * gain


def env_exp(n, decay, sr=SR, attack=0.002):
    a = max(1, int(attack * sr))
    out = array.array("d", bytes(8 * n))
    for i in range(n):
        t = i / sr
        out[i] = (i / a if i < a else 1.0) * math.exp(-t / decay)
    return out


def tone(freq_fn, seconds, decay, shape="sine", sr=SR, attack=0.002, harmonics=None):
    """A tone whose frequency follows freq_fn(t). harmonics: [(mult, gain)]."""
    n = int(seconds * sr)
    out = array.array("d", bytes(8 * n))
    env = env_exp(n, decay, sr, attack)
    phase = 0.0
    parts = harmonics or [(1, 1.0)]
    for i in range(n):
        t = i / sr
        phase += 2 * math.pi * freq_fn(t) / sr
        v = 0.0
        for mult, g in parts:
            p = phase * mult
            if shape == "sine":
                v += g * math.sin(p)
            elif shape == "tri":
                v += g * (2 / math.pi) * math.asin(math.sin(p))
            elif shape == "saw":
                v += g * (((p / (2 * math.pi)) % 1.0) * 2 - 1)
            elif shape == "square":
                v += g * (1 if math.sin(p) >= 0 else -1)
        out[i] = v * env[i]
    return out


def noise(seconds, decay, sr=SR, attack=0.001):
    n = int(seconds * sr)
    env = env_exp(n, decay, sr, attack)
    return array.array("d", ((random.random() * 2 - 1) * env[i] for i in range(n)))


def biquad(x, kind, freq, q=0.7, sr=SR):
    """RBJ biquad. freq may be a float or a function of time."""
    out = array.array("d", bytes(8 * len(x)))
    x1 = x2 = y1 = y2 = 0.0
    dynamic = callable(freq)
    b0 = b1 = b2 = a1 = a2 = 0.0

    def coeffs(f):
        w0 = 2 * math.pi * min(f, sr * 0.45) / sr
        alpha = math.sin(w0) / (2 * q)
        c = math.cos(w0)
        if kind == "lp":
            nb0, nb1, nb2 = (1 - c) / 2, 1 - c, (1 - c) / 2
        elif kind == "hp":
            nb0, nb1, nb2 = (1 + c) / 2, -(1 + c), (1 + c) / 2
        else:  # band-pass, constant peak gain
            nb0, nb1, nb2 = alpha, 0.0, -alpha
        a0 = 1 + alpha
        return nb0 / a0, nb1 / a0, nb2 / a0, -2 * c / a0, (1 - alpha) / a0

    if not dynamic:
        b0, b1, b2, a1, a2 = coeffs(freq)
    for i, xi in enumerate(x):
        if dynamic and i % 32 == 0:
            b0, b1, b2, a1, a2 = coeffs(freq(i / sr))
        y = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1 = x1, xi
        y2, y1 = y1, y
        out[i] = y
    return out


def pluck(freq, seconds, sr=SR, brightness=0.5):
    """Karplus-Strong plucked string: harps and music boxes."""
    period = max(2, int(sr / freq))
    ring = [random.random() * 2 - 1 for _ in range(period)]
    # Pre-filter the excitation for a softer pluck.
    for _ in range(int((1 - brightness) * 4)):
        ring = [(ring[i] + ring[i - 1]) * 0.5 for i in range(period)]
    n = int(seconds * sr)
    out = array.array("d", bytes(8 * n))
    idx = 0
    for i in range(n):
        a = ring[idx]
        b = ring[(idx + 1) % period]
        ring[idx] = (a + b) * 0.4985
        out[i] = a
        idx = (idx + 1) % period
    return out


def bell(freq, seconds, decay=0.6, sr=SR):
    return tone(
        lambda t: freq,
        seconds,
        decay,
        sr=sr,
        harmonics=[(1, 1.0), (2.0, 0.35), (3.01, 0.18), (4.2, 0.08)],
    )


def delay_reverb(x, sr=SR, taps=((0.083, 0.32), (0.127, 0.26), (0.191, 0.2), (0.263, 0.14)), feedback=0.35):
    out = array.array("d", x)
    for d, g in taps:
        k = int(d * sr)
        for i in range(k, len(out)):
            out[i] += out[i - k] * g * feedback * 2.2
    return out


def normalize(x, peak=0.89):
    m = max(1e-9, max(abs(v) for v in x))
    g = peak / m
    return array.array("d", (math.tanh(v * g * 1.15) / math.tanh(1.15) for v in x))


def fade_edges(x, sr=SR, fade_in=0.002, fade_out=0.02):
    a = int(fade_in * sr)
    b = int(fade_out * sr)
    for i in range(min(a, len(x))):
        x[i] *= i / a
    for i in range(min(b, len(x))):
        x[len(x) - 1 - i] *= i / b
    return x


def write(path, x, sr=SR):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = array.array("h", (int(max(-1.0, min(1.0, v)) * 32767) for v in x))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())
    print(f"wrote {path} ({len(x) / sr:.2f}s)")


def sfx(name, x, peak=0.85):
    write(f"{OUT_SFX}/{name}.wav", fade_edges(normalize(x, peak)))


def note(name):
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    letter, rest = name[0], name[1:]
    shift = 0
    if rest.startswith("#"):
        shift, rest = 1, rest[1:]
    elif rest.startswith("b"):
        shift, rest = -1, rest[1:]
    octave = int(rest)
    return 440.0 * 2 ** ((names[letter] + shift + (octave - 4) * 12) / 12)


# ── sound effects ──────────────────────────────────────────────────────────


def bubble(f0, seconds=0.14, rise=1.9, decay=0.05):
    """The classic bubble 'bloop': a sine whose pitch rises as it decays."""
    return tone(lambda t: f0 * (1 + (rise - 1) * min(1, t / (seconds * 0.6))), seconds, decay, attack=0.004)


def make_sfx():
    # UI tap: a soft pop.
    x = bubble(520, 0.09, 1.6, 0.03)
    add(x, noise(0.01, 0.003), gain=0.15)
    sfx("tap", x, 0.7)

    sfx("toggle_on", _two_tone(660, 990))
    sfx("toggle_off", _two_tone(880, 560))

    # Dice rattle: clacks with a woody resonance, accelerating then settling.
    x = buf(0.55)
    t = 0.0
    k = 0
    while t < 0.5:
        click = biquad(noise(0.03, 0.006), "bp", 2200 + random.random() * 1800, 3)
        add(x, click, t, 0.9)
        add(x, tone(lambda _: 1700 + random.random() * 600, 0.04, 0.01), t, 0.15)
        t += 0.035 + random.random() * 0.03
        k += 1
    sfx("dice_shake", x, 0.75)

    # Dice landing: a thunk and two little bounces.
    x = buf(0.35)
    for at, g in ((0.0, 1.0), (0.09, 0.45), (0.15, 0.22)):
        add(x, tone(lambda t: 160 - 60 * t, 0.12, 0.04, attack=0.001), at, g)
        add(x, biquad(noise(0.02, 0.005), "bp", 2600, 2), at, g * 0.5)
    sfx("dice_land", x, 0.8)

    # Token steps: bubbly hops climbing a pentatonic scale.
    for i, n in enumerate(["C5", "D5", "E5", "G5", "A5", "C6"], start=1):
        x = bubble(note(n) * 0.5, 0.13, 1.85, 0.045)
        add(x, bubble(note(n), 0.08, 1.4, 0.02), 0.0, 0.25)
        sfx(f"step_{i}", x, 0.7)

    # Token lands: a lower, squishier plop.
    x = tone(lambda t: 240 * (1 + 0.8 * min(1, t / 0.06)), 0.22, 0.07, attack=0.003)
    add(x, biquad(noise(0.06, 0.02), "lp", 900), 0.0, 0.3)
    sfx("drop", x, 0.75)

    # Capture: a bonk, then the victim whooshing back home.
    x = buf(0.6)
    add(x, tone(lambda t: 330 * math.exp(-t * 6), 0.18, 0.06, harmonics=[(1, 1), (2.7, 0.3)]), 0.0, 1.0)
    whoosh = biquad(noise(0.5, 0.3, attack=0.08), "bp", lambda t: 400 + 3400 * t / 0.5, 1.2)
    add(x, whoosh, 0.08, 0.8)
    sfx("capture", x)

    # War reaction: a villain stinger and a growly "mwa-ha-ha".
    x = buf(1.5)
    for f in (note("A2"), note("C3"), note("D#3")):
        add(x, biquad(tone(lambda t, f=f: f * (1 + 0.01 * math.sin(t * 30)), 1.2, 0.5, "saw", attack=0.01), "lp", 900), 0.0, 0.35)
    for i, (f, at) in enumerate(((190, 0.35), (175, 0.55), (160, 0.75), (150, 0.98))):
        buzz = tone(lambda t, f=f: f * (1 - 0.15 * t / 0.18), 0.18 if i < 3 else 0.32, 0.12, "saw", attack=0.01)
        voice = biquad(buzz, "bp", 750, 2.5)
        add(voice, biquad(buzz, "bp", 1250, 3), 0, 0.6)
        add(x, voice, at, 1.2)
    sfx("capture_war", x)

    # Peace reaction: a harp glissando and a soft chime.
    x = buf(1.6)
    for i, n in enumerate(["C5", "D5", "E5", "G5", "A5", "C6", "D6", "E6"]):
        add(x, pluck(note(n), 1.0, brightness=0.7), i * 0.05, 0.6)
    add(x, bell(note("G6"), 1.2, 0.5), 0.45, 0.25)
    sfx("capture_peace", delay_reverb(x))

    # Token reaches home: a sparkly bell arpeggio.
    x = buf(1.2)
    for i, n in enumerate(["C6", "E6", "G6", "C7"]):
        add(x, bell(note(n), 0.8, 0.35), i * 0.07, 0.5)
    for i in range(10):
        add(x, tone(lambda _, f=random.uniform(3000, 6000): f, 0.06, 0.02), 0.3 + i * 0.05, 0.08)
    sfx("home", delay_reverb(x))

    # Win: a bright plucked fanfare into a held chord.
    x = buf(2.2)
    for i, n in enumerate(["C5", "E5", "G5", "C6"]):
        add(x, pluck(note(n), 0.6, brightness=0.8), i * 0.11, 0.6)
    for n in ("C4", "E4", "G4", "C5"):
        add(x, biquad(tone(lambda t, f=note(n): f, 1.6, 0.8, "saw", attack=0.03), "lp", 2400), 0.5, 0.18)
    add(x, bell(note("C7"), 1.2, 0.5), 0.5, 0.2)
    sfx("win", delay_reverb(x))

    # Lose: a deflating "wah-wah-wah-waaah".
    x = buf(2.0)
    for i, n in enumerate(["G4", "F#4", "F4", "E4"]):
        dur = 0.32 if i < 3 else 0.9
        wah = tone(
            lambda t, f=note(n), last=(i == 3): f * (1 + (0.02 * math.sin(t * 34) if last else 0)),
            dur,
            0.25 if i < 3 else 0.6,
            "saw",
            attack=0.02,
        )
        add(x, biquad(wah, "lp", lambda t: 500 + 1300 * math.sin(min(1, t / 0.25) * math.pi / 2), 2), i * 0.34, 0.8)
    sfx("lose", x)

    # Your turn: a two-note bell.
    x = buf(0.9)
    add(x, bell(note("E6"), 0.6, 0.25), 0.0, 0.6)
    add(x, bell(note("A6"), 0.8, 0.35), 0.12, 0.6)
    sfx("your_turn", delay_reverb(x), 0.6)

    # Chat message: a quick double blip.
    x = buf(0.2)
    add(x, bubble(900, 0.07, 1.5, 0.02), 0.0)
    add(x, bubble(1200, 0.07, 1.5, 0.02), 0.06, 0.8)
    sfx("chat", x, 0.55)

    # Reaction picked: a soft pop with a shimmer.
    x = bubble(600, 0.16, 2.2, 0.05)
    add(x, bell(note("E7"), 0.3, 0.1), 0.03, 0.15)
    sfx("reaction", x, 0.7)

    # The old menu whoosh, retired for make_sfx_drawer's softer bubbles.
    # Still computed so the random sounds after it come out the same.
    biquad(noise(0.3, 0.12, attack=0.06), "bp", lambda t: 600 + 2400 * t / 0.3, 1.0)

    # Purchase: coins cascading.
    x = buf(1.2)
    for i in range(9):
        f = random.uniform(2200, 3600)
        add(x, tone(lambda _, f=f: f, 0.4, 0.12, harmonics=[(1, 1), (2.76, 0.4), (5.4, 0.2)]), i * 0.06 + random.random() * 0.02, 0.35)
    add(x, bell(note("C7"), 0.8, 0.35), 0.55, 0.3)
    sfx("purchase", delay_reverb(x), 0.75)

    # Teleport: the portal opens, everything gets sucked in, a boom, then the
    # new world sparkles into place.
    x = buf(3.0)
    rush = biquad(noise(1.5, 1.2, attack=0.6), "bp", lambda t: 200 + 4800 * (t / 1.5) ** 2, 1.5)
    add(x, rush, 0.0, 1.0)
    add(x, tone(lambda t: 120 * 2 ** (t * 3.2), 1.4, 0.9, "tri", attack=0.4), 0.0, 0.35)
    add(x, tone(lambda t: 70 * math.exp(-t * 2), 1.0, 0.35, attack=0.002), 1.45, 1.1)
    add(x, biquad(noise(0.4, 0.15), "lp", 500), 1.45, 0.6)
    for i, n in enumerate(["C6", "G6", "E6", "C7", "G7", "E7"]):
        add(x, bell(note(n), 0.9, 0.3), 1.6 + i * 0.08, 0.22)
    sfx("teleport", delay_reverb(x), 0.85)


def make_sfx_extra():
    """Sounds added after the first set. Seeded separately so the original
    sounds and music above render exactly as before."""
    random.seed(11)

    # Turn timer tick: a soft woodblock for the last seconds of a turn.
    x = buf(0.12)
    add(x, biquad(noise(0.02, 0.004), "bp", 2400, 4), 0.0, 0.6)
    add(x, tone(lambda t: 1250 - 300 * t, 0.08, 0.018, attack=0.001), 0.0, 0.5)
    sfx("tick", x, 0.55)

    # Chess move: a wooden piece set down on the board.
    x = buf(0.25)
    add(x, tone(lambda t: 420 - 120 * t, 0.12, 0.025, attack=0.001, harmonics=[(1, 1), (2.3, 0.25)]), 0.0, 0.9)
    add(x, biquad(noise(0.03, 0.008), "bp", 1500, 2.5), 0.0, 0.5)
    add(x, tone(lambda _: 140, 0.1, 0.03, attack=0.001), 0.0, 0.35)
    sfx("chess_move", x, 0.75)

    # Chess capture: the piece knocks the other off with a little clack.
    x = buf(0.42)
    add(x, tone(lambda t: 360 - 100 * t, 0.12, 0.03, attack=0.001, harmonics=[(1, 1), (2.3, 0.3)]), 0.0, 1.0)
    add(x, biquad(noise(0.03, 0.008), "bp", 2600, 3), 0.0, 0.6)
    add(x, tone(lambda t: 520 - 160 * t, 0.1, 0.02, attack=0.001), 0.11, 0.55)
    add(x, biquad(noise(0.25, 0.12, attack=0.03), "bp", lambda t: 900 + 2200 * t / 0.25, 1.2), 0.12, 0.35)
    sfx("chess_capture", x, 0.8)

    # Check: two quick, slightly tense bells.
    x = buf(0.7)
    add(x, bell(note("B5"), 0.5, 0.18), 0.0, 0.55)
    add(x, bell(note("F6"), 0.6, 0.25), 0.1, 0.5)
    sfx("chess_check", delay_reverb(x), 0.65)


def make_sfx_drawer():
    """A drawer or panel opening: three soft, low bubbles rising one after
    another, rounded off and with a little air, so it reads as calm rather
    than the old noisy whoosh."""
    random.seed(23)
    x = buf(0.62)
    add(x, bubble(300, 0.2, 1.45, 0.09), 0.0, 1.0)
    add(x, bubble(400, 0.18, 1.4, 0.08), 0.075, 0.7)
    add(x, bubble(535, 0.16, 1.35, 0.07), 0.15, 0.45)
    add(x, biquad(noise(0.22, 0.09, attack=0.05), "lp", 700), 0.0, 0.05)
    x = biquad(x, "lp", 1900, 0.6)
    sfx("drawer", delay_reverb(x, feedback=0.22), 0.42)


def make_sfx_coins_out():
    """Coins going out (a gift sent): a handful counted off, each clink a
    little lower than the last, swept away with a soft whoosh and a low
    drop as they go. Darker than the purchase cascade (coins coming in),
    so giving never sounds like getting."""
    random.seed(41)
    x = buf(1.0)
    for i in range(7):
        f = 3300 - i * 230 + random.uniform(-80, 80)
        add(x, tone(lambda _, f=f: f, 0.28, 0.07, harmonics=[(1, 1), (2.76, 0.35), (5.4, 0.15)]),
            i * 0.055 + random.random() * 0.012, 0.32 * (1 - i * 0.06))
    add(x, biquad(noise(0.45, 0.25, attack=0.05), "bp", lambda t: 2600 - 1800 * t / 0.45, 1.1), 0.12, 0.22)
    add(x, tone(lambda t: 520 - 260 * t, 0.25, 0.08, harmonics=[(1, 1), (2, 0.3)]), 0.42, 0.3)
    sfx("coins_out", delay_reverb(x, feedback=0.25), 0.7)


def _two_tone(a, b):
    x = buf(0.16)
    add(x, bubble(a, 0.07, 1.2, 0.025), 0.0)
    add(x, bubble(b, 0.08, 1.2, 0.03), 0.06)
    return x


def make_sfx_hologram():
    """The rank hologram reading out a player's stats: a soft power-up as it
    projects, a data blip as each readout comes up (four pitches, climbing
    through them as the readouts appear) and a tiny counter tick while the
    rating counts up. The app plays them as the stats animate, so the sound
    stops when the animation does."""
    random.seed(31)

    # Power-up: a hum swelling and rising, a shimmer of air, a chirp on top.
    x = buf(0.6)
    add(x, tone(lambda t: 180 + 520 * (t / 0.42) ** 1.6, 0.42, 0.5, shape="tri",
                attack=0.12, harmonics=[(1, 1), (2, 0.3)]), 0.0, 0.5)
    add(x, biquad(noise(0.4, 0.3, attack=0.15), "bp", lambda t: 1200 + 4000 * t / 0.4, 2.5), 0.0, 0.12)
    add(x, tone(lambda t: 1760 + 900 * t / 0.06, 0.07, 0.025, attack=0.002), 0.4, 0.35)
    add(x, tone(lambda _: 2637, 0.09, 0.03, attack=0.002), 0.46, 0.25)
    x = biquad(x, "lp", 5200, 0.6)
    sfx("holo_on", delay_reverb(x, feedback=0.18), 0.5)

    # Data blips: two quick bleeps, the second a fifth up, with a click.
    for i, name in enumerate(("A5", "C6", "D6", "E6")):
        f = note(name)
        x = buf(0.16)
        add(x, tone(lambda _: f, 0.05, 0.022, shape="tri", attack=0.001), 0.0, 0.55)
        add(x, tone(lambda _: f * 1.5, 0.05, 0.02, shape="tri", attack=0.001), 0.038, 0.45)
        add(x, biquad(noise(0.012, 0.003), "bp", 5200, 3), 0.0, 0.25)
        x = biquad(x, "lp", 6500, 0.6)
        sfx(f"holo_blip_{i + 1}", delay_reverb(x, taps=((0.05, 0.18), (0.09, 0.1)), feedback=0.1), 0.42)

    # Counter tick: a tiny high bleep, very short.
    x = buf(0.05)
    add(x, tone(lambda _: 3135, 0.028, 0.009, attack=0.0008), 0.0, 0.6)
    add(x, biquad(noise(0.006, 0.0015), "hp", 4000), 0.0, 0.2)
    sfx("holo_tick", x, 0.3)


def make_sfx_hologram_ambience():
    """Each tier's aura as a far-off sound, looping under the hologram
    while it's open: Bronze dust swirling, Silver's liquid trickling, Gold's
    fire crackling, Diamond's crystals chiming, Legend's electricity
    crackling. Muffled (low-passed hard), mostly echo and quiet, so it
    sounds far away in the world but still there. Each wraps round on itself, so
    it loops without a seam. 22 kHz, like the music, to stay small."""
    sr = MUSIC_SR
    seconds = 5.0
    n = int(seconds * sr)

    def wrap(dst, src, at, gain=1.0):
        start = int(at * sr)
        for i in range(len(src)):
            dst[(start + i) % n] += src[i] * gain

    def circ(x, kind, freq, q):
        """Filtered as a loop: run over two copies, keep the second, so the
        end flows into the start without a click."""
        twice = array.array("d", x)
        twice.extend(x)
        return biquad(twice, kind, freq, q, sr)[n:]

    def loop_out(name, x, cutoff, peak):
        # Far off: muffled (the highs don't carry), mostly the room's echo
        # rather than the sound itself, and quiet.
        x = circ(x, "lp", cutoff * 0.55, 0.6)
        y = array.array("d", (v * 0.55 for v in x))
        # Reverb that also wraps, so the tail carries over the seam.
        for d, g in ((0.13, 0.42), (0.23, 0.36), (0.37, 0.3), (0.53, 0.22), (0.71, 0.15)):
            k = int(d * sr)
            for i in range(n):
                y[(i + k) % n] += x[i] * g
        write(f"{OUT_SFX}/{name}.wav", normalize(y, peak * 0.6), sr)

    random.seed(41)

    # Bronze: dust swirling, a soft whoosh coming and going, grains ticking.
    x = buf(seconds, sr)
    for i in range(n):
        x[i] = random.uniform(-1, 1)
    swirl = array.array("d", bytes(8 * n))
    for i in range(n):
        t = i / sr
        swirl[i] = 0.5 + 0.5 * math.sin(2 * math.pi * t / seconds * 2 + 1.1 * math.sin(2 * math.pi * t / seconds))
    x = circ(x, "bp", lambda t: 500 + 900 * (0.5 + 0.5 * math.sin(2 * math.pi * t / seconds * 2)), 1.3)
    for i in range(n):
        x[i] *= 0.25 + 0.75 * swirl[i]
    for _ in range(55):
        wrap(x, biquad(noise(0.01, 0.003, sr=sr), "bp", random.uniform(2500, 5000), 3, sr), random.uniform(0, seconds), random.uniform(0.05, 0.15))
    loop_out("holo_amb_bronze", x, 2600, 0.45)

    # Silver: liquid trickling, droplets falling into it.
    x = buf(seconds, sr)
    trickle = circ(array.array("d", [random.uniform(-1, 1) for _ in range(n)]), "bp", 1400, 2.5)
    for i in range(n):
        t = i / sr
        x[i] = trickle[i] * (0.35 + 0.25 * math.sin(2 * math.pi * 7 * t) * math.sin(2 * math.pi * 0.4 * t))
    for _ in range(26):
        f = random.uniform(700, 1500)
        drop = tone(lambda t, f=f: f * (1 + 1.8 * math.exp(-t / 0.012)), 0.09, 0.03, sr=sr, attack=0.001)
        wrap(x, drop, random.uniform(0, seconds), random.uniform(0.25, 0.55))
    loop_out("holo_amb_silver", x, 3200, 0.45)

    # Gold: a fire, a warm low roar with crackles popping through it.
    x = buf(seconds, sr)
    roar = circ(array.array("d", [random.uniform(-1, 1) for _ in range(n)]), "lp", 260, 0.7)
    for i in range(n):
        t = i / sr
        x[i] = roar[i] * (0.8 + 0.2 * math.sin(2 * math.pi * t / seconds * 3))
    for _ in range(70):
        pop = biquad(noise(random.uniform(0.004, 0.012), 0.004, sr=sr), "bp", random.uniform(1200, 3600), 2, sr)
        wrap(x, pop, random.uniform(0, seconds), random.uniform(0.15, 0.5))
    loop_out("holo_amb_gold", x, 3000, 0.35)

    # Diamond: crystals chiming far off, over a faint glassy air.
    x = buf(seconds, sr)
    air = circ(array.array("d", [random.uniform(-1, 1) for _ in range(n)]), "bp", 5200, 1.5)
    for i in range(n):
        x[i] = air[i] * 0.06
    for _ in range(14):
        f = random.choice([note(m) for m in ("E6", "G6", "B6", "D7", "F#7")])
        chime = tone(lambda _, f=f: f, 1.2, 0.35, sr=sr, attack=0.002,
                     harmonics=[(1, 1), (2.76, 0.4), (5.4, 0.18)])
        wrap(x, chime, random.uniform(0, seconds), random.uniform(0.12, 0.3))
    loop_out("holo_amb_diamond", x, 7000, 0.4)

    # Legend: electricity, a buzzing hum flickering, arcs crackling.
    x = buf(seconds, sr)
    phase = 0.0
    for i in range(n):
        t = i / sr
        phase += 2 * math.pi * 60 / sr
        hum = sum(math.sin(phase * h) / h for h in (1, 2, 3, 5, 7))
        flicker = 0.55 + 0.45 * math.sin(2 * math.pi * t * 11) * math.sin(2 * math.pi * t / seconds * 4)
        x[i] = hum * 0.18 * flicker
    for _ in range(40):
        length = random.uniform(0.02, 0.12)
        arc = biquad(noise(length, length / 2, sr=sr), "hp", 1800, 0.7, sr)
        # Arcs come in bursts of snaps.
        at = random.uniform(0, seconds)
        for k in range(random.randint(1, 4)):
            wrap(x, arc, at + k * random.uniform(0.02, 0.06), random.uniform(0.3, 0.8))
    loop_out("holo_amb_legend", x, 4200, 0.29)


# ── music ──────────────────────────────────────────────────────────────────


def render_loop(bars, bpm, sr, voices):
    """Renders two passes and keeps the second, so reverb tails and long
    pad releases wrap around into the loop start: seamless looping."""
    beat = 60.0 / bpm
    length = bars * 4 * beat
    x = buf(length * 2, sr)
    for at, sound, gain in voices(beat):
        for pass_start in (0.0, length):
            add(x, sound, pass_start + at, gain, sr)
    x = delay_reverb(x, sr, taps=((0.21, 0.3), (0.34, 0.24), (0.55, 0.16), (0.89, 0.1)), feedback=0.4)
    loop = array.array("d", x[int(length * sr): int(length * sr) + int(length * sr)])
    return normalize(loop, 0.7)


def pad_chord(freqs, seconds, sr):
    out = buf(seconds, sr)
    n = len(out)
    for f in freqs:
        for detune in (0.997, 1.003):
            ph = random.random() * 6.28
            for i in range(n):
                t = i / sr
                a = min(1, t / 0.9) * min(1, (seconds - t) / 0.9)
                out[i] += math.sin(ph + 2 * math.pi * f * detune * t) * a * 0.5
                out[i] += (2 / math.pi) * math.asin(math.sin(ph + 2 * math.pi * f * 2 * detune * t)) * a * 0.08
    return out


def music_box(f, sr, seconds=1.4):
    return tone(lambda _: f, seconds, 0.45, sr=sr, harmonics=[(1, 1.0), (2, 0.25), (3, 0.08), (4.1, 0.04)])


def make_music():
    # Menu: dreamy, slow, music box over pads.
    chords = [
        ("F3", ["F3", "A3", "C4", "E4"]),
        ("E3", ["E3", "G3", "B3", "D4"]),
        ("D3", ["D3", "F3", "A3", "C4"]),
        ("C3", ["C3", "E3", "G3", "B3"]),
    ]
    pattern = [0, 2, 3, 1, 2, 3, 2, 1]

    def menu(beat):
        out = []
        for c, (root, tones) in enumerate(chords):
            start = c * 8 * beat
            freqs = [note(n) for n in tones]
            out.append((start, pad_chord(freqs, 8 * beat + 0.8, MUSIC_SR), 0.22))
            for bar in range(2):
                out.append((start + bar * 4 * beat, tone(lambda _, f=note(root) / 2: f, 3.6 * beat, 1.2, sr=MUSIC_SR, attack=0.02), 0.5))
                for k, p in enumerate(pattern):
                    up = freqs[p] * (4 if (bar + k) % 3 else 2)
                    out.append((start + bar * 4 * beat + k * beat / 2, music_box(up, MUSIC_SR), 0.16))
        return out

    write(f"{OUT_MUSIC}/menu.wav", render_loop(8, 84, MUSIC_SR, menu), MUSIC_SR)

    # Game: brighter, plucky sixteenths with a soft beat.
    chords = [
        ("A2", ["A3", "C4", "E4"]),
        ("F2", ["F3", "A3", "C4"]),
        ("C3", ["C4", "E4", "G4"]),
        ("G2", ["G3", "B3", "D4"]),
    ]

    def game(beat):
        out = []
        kick = tone(lambda t: 110 * math.exp(-t * 18) + 45, 0.3, 0.09, sr=MUSIC_SR, attack=0.001)
        snap = biquad(noise(0.12, 0.04, MUSIC_SR), "bp", 2200, 1.2, MUSIC_SR)
        for c, (root, tones) in enumerate(chords * 2):
            start = c * 4 * beat
            freqs = [note(n) for n in tones]
            out.append((start, pad_chord(freqs, 4 * beat + 0.4, MUSIC_SR), 0.12))
            out.append((start, tone(lambda _, f=note(root): f, 1.8 * beat, 0.5, "tri", MUSIC_SR, 0.01), 0.35))
            out.append((start + 2 * beat, tone(lambda _, f=note(root): f, 1.8 * beat, 0.5, "tri", MUSIC_SR, 0.01), 0.3))
            for b in range(4):
                out.append((start + b * beat, kick if b % 2 == 0 else snap, 0.35 if b % 2 == 0 else 0.12))
            for k in range(16):
                f = freqs[(k * 2 + (k // 4)) % 3] * (2 if k % 4 else 4)
                out.append((start + k * beat / 4, pluck(f, 0.5, MUSIC_SR, 0.6), 0.1))
        return out

    write(f"{OUT_MUSIC}/game.wav", render_loop(8, 100, MUSIC_SR, game), MUSIC_SR)


if __name__ == "__main__":
    import sys

    if sys.argv[1:] == ["coins_out"]:
        # Only the gift-sent sound, leaving the rest as they are.
        make_sfx_coins_out()
        sys.exit(0)
    if sys.argv[1:] == ["hologram"]:
        # Only the hologram's sounds, leaving the rest as they are.
        make_sfx_hologram()
        make_sfx_hologram_ambience()
        sys.exit(0)
    make_sfx()
    make_music()
    make_sfx_extra()
    make_sfx_drawer()
    make_sfx_hologram()
    make_sfx_hologram_ambience()
    make_sfx_coins_out()
