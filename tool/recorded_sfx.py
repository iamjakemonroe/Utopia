"""Builds the Halloween sounds made from real recordings (tool/sfx_sources,
all public domain): the witch's laugh as she crosses the moon, and the
scream as the wraith rushes out.

Run from the repo root:  python3 tool/recorded_sfx.py
Writes assets/sfx/hw_cackle.wav (her evil laugh, echoing off the hills and
sweeping left to right as she flies) and hw_scream.wav (a high, falling
horror shriek over the scare's boom and string stab, from
synth_world_audio.scare_hit). afconvert, built into macOS, decodes the
sources.
"""
import array
import math
import os
import struct
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(__file__))
from synth_audio import add, biquad, buf, delay_reverb  # noqa: E402
from synth_world_audio import SR, save, save_stereo, scale, scare_hit  # noqa: E402

SOURCES = os.path.join(os.path.dirname(__file__), "sfx_sources")

# The laugh: where it starts in its recording, and its longest.
LAUGH_AT = 0.08
LONGEST = 3.2

# The scream: the recording's second shriek (the higher one).
SCREAM_AT = 4.35


def decode(name):
    """A source as mono samples at SR."""
    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, "x.wav")
        subprocess.run(
            ["afconvert", "-f", "WAVE", "-d", f"LEI16@{SR}", "-c", "1",
             os.path.join(SOURCES, name), out],
            check=True,
        )
        data = open(out, "rb").read()
    i = data.index(b"data")
    n = struct.unpack("<I", data[i + 4:i + 8])[0]
    pcm = array.array("h")
    pcm.frombytes(data[i + 8:i + 8 + n])
    return array.array("d", (v / 32768 for v in pcm))


def take(x, start):
    """One take, cut at the quietest moment between 2.6 s and LONGEST in
    (a breath between laughs), with soft ends."""
    a = int(start * SR)
    hop = int(0.01 * SR)
    best, cut = None, a + int(LONGEST * SR)
    for k in range(a + int(2.6 * SR), a + int(LONGEST * SR), hop):
        e = sum(v * v for v in x[k:k + hop])
        if best is None or e < best:
            best, cut = e, k + hop // 2
    seg = array.array("d", x[a:cut])
    n = len(seg)
    for i in range(n):
        seg[i] *= min(1.0, i / (0.02 * SR), (n - 1 - i) / (0.15 * SR))
    return seg


def cackle(seg):
    """Her laugh up in the sky: the low end thinned, an echo off the hills,
    and left to right across the take as she flies."""
    seg = biquad(seg, "hp", 170, sr=SR)
    seg = delay_reverb(
        seg + buf(1.0, SR),
        sr=SR,
        taps=((0.19, 0.3), (0.37, 0.18), (0.56, 0.1)),
        feedback=0.22,
    )
    n = len(seg)
    left = array.array("d", bytes(8 * n))
    right = array.array("d", bytes(8 * n))
    for i, v in enumerate(seg):
        pan = 0.2 + 0.45 * i / n
        left[i] = v * math.cos(pan * math.pi / 2)
        right[i] = v * math.sin(pan * math.pi / 2)
    return left, right


def scream(x):
    """The shriek from its first breath, about 2.8 s of it trailing off,
    over the boom and the strings."""
    a = int(SCREAM_AT * SR)
    n = int(2.8 * SR)
    voice = array.array("d", x[a:a + n])
    for i in range(n):
        voice[i] *= min(1.0, i / (0.01 * SR), (n - 1 - i) / (0.7 * SR))
    out = scare_hit()
    add(out, scale(voice, 1.4), at=0.03, sr=SR)
    return delay_reverb(out, sr=SR, taps=((0.07, 0.2), (0.13, 0.12)), feedback=0.15)


def main():
    laugh = take(decode("witch_laugh_mvvoiceacting_223851.mp3"), LAUGH_AT)
    left, right = cackle(laugh)
    save_stereo("hw_cackle", left, right, peak=0.85, fade_out=0.6)
    shriek = decode("horror_shrieks_aderumoro_320740.mp3")
    save("hw_scream", scream(shriek), peak=0.97, fade_out=0.6)


if __name__ == "__main__":
    main()
