"""The trailer's narrator, talking to you (you're the one in Utopia): the
Mac's Daniel voice, slowed a touch and pitched down for weight, with a
little room. Lines and times match tool/ads/trailer.py.

  python tool/ads/voice.py out.wav
"""
import os
import subprocess
import sys
import tempfile

from compose import FF

LINES = [
    (0.9, 'Shh... breathe.', 118),
    (3.4, 'Open your eyes.', 124),
    (6.4, "You're not dreaming."),
    (9.0, 'Follow him.'),
    (12.5, 'Welcome... to Utopia.'),
    (16.7, 'Meet Chip.'),
    (17.6, "He'll show you everything."),
    (41.7, 'Every world hides a game.'),
    (49.6, 'Win.'),
    (51.1, 'Lose.'),
    (52.6, 'Feel... everything.'),
    (55.7, 'But careful.'),
    (57.8, 'Someone... is always watching.'),
    (60.1, 'Run.', 170),
    (64.4, 'Your world is waiting.'),
    (69.7, 'Step inside.'),
]

VOICE = 'Daniel'
RATE = 138
SEMITONES = -2.0


def build(out, length=76.0):
    work = tempfile.mkdtemp()
    inputs = []
    parts = []
    k = 2 ** (SEMITONES / 12)
    for i, (at, text, *rate) in enumerate(LINES):
        raw = os.path.join(work, f'l{i}.aiff')
        subprocess.run(['say', '-v', VOICE, '-r', str(rate[0] if rate else RATE), '-o', raw, text],
                       check=True)
        inputs += ['-i', raw]
        ms = int(at * 1000)
        parts.append(
            f'[{i}:a]aresample=48000,asetrate={int(48000 * k)},aresample=48000,'
            f'atempo={1 / k:.4f},highpass=f=70,equalizer=f=180:t=q:w=1:g=4,'
            f'equalizer=f=3200:t=q:w=1.2:g=2.5,acompressor=threshold=-20dB:ratio=3:attack=5:release=120,'
            f'adelay={ms}|{ms}[v{i}]')
    labels = ''.join(f'[v{i}]' for i in range(len(LINES)))
    parts.append(f'{labels}amix=inputs={len(LINES)}:normalize=0,'
                 f'aecho=0.8:0.6:60|110:0.18|0.10,apad=whole_dur={length},'
                 f'pan=stereo|c0=c0|c1=c0,volume=5.5,alimiter=limit=0.89:level=false[out]')
    subprocess.run([FF, '-y', '-loglevel', 'error', *inputs, '-filter_complex', ';'.join(parts),
                    '-map', '[out]', '-ar', '48000', '-t', str(length), out], check=True)


if __name__ == '__main__':
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    build(sys.argv[1] if len(sys.argv) > 1 else 'voice.wav')
