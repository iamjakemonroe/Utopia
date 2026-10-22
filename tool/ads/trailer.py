"""Utopia's trailer: about 76 seconds, vertical, and you're in it. A film
made in the game's own art (tool/perf/cinema.dart, filmed frame by frame
by tool/ads/film.mjs into build/ads/raw/cinema): you wake on an island at
night, Chip finds you, and you go through the gateway, the worlds and the
games, into the dark where something is watching, and back to the gate.
Over it: titles, an original score (tool/ads/score.py), the worlds' own
sounds, and, in one version, a narrator talking to you (tool/ads/voice.py).

  python tool/ads/trailer.py   # -> ~/Desktop/Utopia Ads: narrated, and music only
"""
import os
import subprocess
import sys
from multiprocessing import Pool

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compose import FF, FPS, GOLD, H, SFX, W, Shot, font  # noqa: E402
from voice import LINES  # noqa: E402

OUT = os.path.expanduser('~/Desktop/Utopia Ads')
WORK = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
                    'build', 'ads', 'trailer')
LENGTH = 76.0
END = 68.3

# ── the cut ────────────────────────────────────────────────────────────────

# A bar (2 s) each from 19.5, as cinema.dart flies through them.
WORLDS = [
    ('UTOPIA DOODLE', 'Everything drawn in ink, and still alive.', 'drawer.wav', True),
    ('UTOPIA WINTER', 'Listen for sleigh bells.', 'wn_sleigh.wav', False),
    ('UTOPIA MUSIC', 'Lasers up. Bass down.', 'six.wav', False),
    ('UTOPIA HEAVEN', 'Pearly gates above the clouds.', 'holo_on.wav', True),
    ('UTOPIA HELL', 'A sea of fire under a blood moon.', 'hw_rumble_1.wav', False),
    ('UTOPIA DOJO', 'A dragon circling the sky.', 'hw_dread.wav', False),
    ('UTOPIA DEEP', 'Down under the waves.', 'wn_gust_1.wav', False),
    ('UTOPIA ALIEN', 'Two moons. Something in the sky.', 'holo_blip_3.wav', False),
    ('UTOPIA TECH', 'A neon city that never sleeps.', 'holo_blip_1.wav', False),
    ('UTOPIA ZOMBIE', 'The dead never stay down.', 'hw_moan_left.wav', False),
    ('UTOPIA HALLOWEEN', "Don't look at the tower window.", 'hw_cackle.wav', False),
]

# Each game as it flies past you (cinema.dart's _things).
GAMES = [
    (43.8, 45.0, 'LUDO', 44.15, 'dice_land.wav'),
    (45.0, 46.3, 'CHESS', 45.3, 'chess_move.wav'),
    (46.3, 47.4, 'CHECKERS', 46.55, 'chess_capture.wav'),
    (47.4, 48.4, 'CRAZY EIGHTS', 47.7, 'card_play.wav'),
    (48.4, 49.5, 'GUESS MY DOODLE', 48.35, 'drawer.wav'),
]


def timeline():
    """Titles (start, end, text, style, ink) and sounds (time, file, volume)."""
    texts = [
        # Waking: the narrator's words, quietly, under the picture.
        *[(at, at + 2.0, text.replace('...', '\u2026'), 'open', False)
          for at, text, *_ in LINES if at < 11],
        (12.2, 16.3, 'UTOPIA', 'title', False),
        (13.0, 16.3, 'A world of worlds.', 'tag', False),
        (16.7, 19.4, 'Meet Chip.', 'big', False),
        (17.6, 19.4, "He'll show you everything.", 'sub', False),
    ]
    sfx = [(9.7, 'teleport.wav', 0.55), (11.4, 'teleport.wav', 0.9), (16.6, 'reaction.wav', 0.5)]
    t = 19.5
    for name, line, sound, ink in WORLDS:
        texts += [(t + 0.15, t + 1.95, name, 'world', ink), (t + 0.45, t + 1.95, line, 'sub', ink)]
        sfx += [(t, 'teleport.wav', 0.22), (t + 0.1, sound, 0.5)]
        t += 2.0
    sfx += [(39.6, 'hw_thunder_1.wav', 0.5)]
    texts += [(41.7, 43.4, 'Every world hides a game.', 'big', False)]
    for a, b, name, at, sound in GAMES:
        texts.append((a, b, name, 'game', False))
        sfx.append((at, sound, 0.75))
    texts += [
        (49.6, 51.0, 'Win.', 'big', False),
        (51.1, 52.5, 'Lose.', 'big', False),
        (52.6, 55.3, 'Feel everything.', 'big', False),
        (55.7, 57.5, 'But careful.', 'big', False),
        (57.8, 59.9, 'Someone is always', 'big', False),
        (58.5, 59.9, 'watching.', 'big2', False),
        (60.05, 61.4, 'RUN.', 'title', False),
        (64.4, 68.1, 'Your world', 'big', False),
        (64.9, 68.1, 'is waiting.', 'big2', False),
    ]
    sfx += [(49.6, 'win.wav', 0.45), (51.1, 'react_sad.wav', 0.6), (55.5, 'hw_dread.wav', 0.6),
            (58.15, 'hw_thunder_2.wav', 0.7), (58.9, 'hw_cackle.wav', 0.55),
            (59.6, 'hw_whisper_left.wav', 0.5), (60.0, 'hw_thunder_3.wav', 0.6),
            (64.0, 'reaction.wav', 0.45), (68.6, 'holo_on.wav', 0.4)]
    return texts, sfx


# ── drawing ────────────────────────────────────────────────────────────────

_cache = {}


def cached(key, make):
    if key not in _cache:
        _cache[key] = make()
    return _cache[key]


def vignette():
    def make():
        y, x = np.mgrid[0:H, 0:W]
        d = np.sqrt(((x - W / 2) / (W * 0.62)) ** 2 + ((y - H / 2) / (H * 0.62)) ** 2)
        return np.clip(1.08 - 0.42 * d ** 2, 0.45, 1.0).astype(np.float32)[:, :, None]
    return cached('vignette', make)


def grain(n):
    def make():
        rng = np.random.default_rng(3)
        tiles = []
        for _ in range(6):
            g = rng.normal(0, 1, (H // 2, W // 2)).astype(np.float32)
            img = Image.fromarray(np.uint8(np.clip(128 + g * 40, 0, 255))).resize((W, H), Image.BILINEAR)
            tiles.append((np.asarray(img, dtype=np.float32) - 128)[:, :, None] * 0.18)
        return tiles
    return cached('grain', make)[n % 6]


def finish(img, t):
    """Grade, vignette and grain over a finished frame."""
    a = np.asarray(img, dtype=np.float32)
    a = (a - 128) * 1.07 + 128 + np.array([4, 0, -3], dtype=np.float32)
    a = a * vignette() + grain(int(t * FPS))
    return Image.fromarray(np.uint8(np.clip(a, 0, 255)))


STYLES = {
    'title': ('SpaceGrotesk-Bold.ttf', 190, (255, 255, 255), True),
    'world': ('SpaceGrotesk-Bold.ttf', 92, (255, 255, 255), True),
    'game': ('SpaceGrotesk-Bold.ttf', 110, GOLD, True),
    'big': ('SpaceGrotesk-Bold.ttf', 84, (255, 255, 255), False),
    'big2': ('SpaceGrotesk-Bold.ttf', 84, GOLD, False),
    'sub': ('Inter-SemiBold.ttf', 46, (236, 230, 255), False),
    'open': ('Inter-SemiBold.ttf', 58, (240, 234, 255), False),
    'tag': ('Inter-SemiBold.ttf', 52, (236, 230, 255), False),
}
POSITIONS = {'title': 0.40, 'world': 0.13, 'game': 0.12, 'big': 0.16, 'big2': 0.215, 'sub': 0.215,
             'open': 0.74, 'tag': 0.52}
INK = (28, 22, 40)


def text_layer(text, style, k, life, ink=False):
    """[text] in [style] at [k] seconds into its [life]: tracking that
    eases open, a fade in and out, and a glow."""
    name, size, color, tracked = STYLES[style]
    if ink:
        # On a light world: dark ink, with a light glow.
        color = INK
    fade = min(1, k / 0.45, (life - k) / 0.35)
    if fade <= 0:
        return None
    ease = 1 - (1 - min(1, k / 1.6)) ** 3
    spacing = (size * (0.32 - 0.16 * ease)) if tracked else size * 0.01
    f = font(name, size)
    shown = text.upper() if tracked else text
    probe = ImageDraw.Draw(Image.new('L', (1, 1)))
    widths = [probe.textlength(ch, font=f) for ch in shown]
    total = sum(widths) + spacing * (len(shown) - 1)
    lines = [shown]
    if total > W - 120 and ' ' in shown:
        cut = shown.rfind(' ', 0, len(shown) // 2 + 6)
        lines = [shown[:cut], shown[cut + 1:]]
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    y = int(POSITIONS[style] * H) if style != 'title' else int(POSITIONS['title'] * H)
    if style == 'sub':
        y += 0 if len(lines) == 1 else -20
    rise = int(26 * (1 - min(1, k / 0.45)))
    for line in lines:
        ws = [probe.textlength(ch, font=f) for ch in line]
        width = sum(ws) + spacing * (len(line) - 1)
        x = (W - width) / 2
        for ch, w in zip(line, ws):
            d.text((x, y + rise), ch, font=f, fill=color + (255,))
            x += w + spacing
        y += int(size * 1.18)
    glow = layer.filter(ImageFilter.GaussianBlur(size * 0.22))
    tint = Image.new('RGBA', (W, H), (255, 255, 255, 0) if ink else (255, 200, 90, 0))
    tint.putalpha(glow.getchannel('A').point(lambda v: int(v * (0.55 if tracked else 0.3))))
    shadow = layer.filter(ImageFilter.GaussianBlur(10))
    sh = Image.new('RGBA', (W, H), (255, 255, 255, 0) if ink else (8, 2, 24, 0))
    sh.putalpha(shadow.getchannel('A').point(lambda v: int(v * 0.85)))
    out = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    out.alpha_composite(sh)
    out.alpha_composite(tint)
    out.alpha_composite(layer)
    if fade < 1:
        out.putalpha(out.getchannel('A').point(lambda v: int(v * fade)))
    return out


def film_frame(t):
    """The film, as cinema.dart drew it at [t]."""
    return Image.open(Shot.get('cinema').frame_at(t + 1e-6)).convert('RGB')


def _end_shade():
    """Dark at the top and the bottom of the end, for its words."""
    y = np.linspace(0, 1, H, dtype=np.float32)[:, None]
    top = np.clip((0.3 - y) / 0.3, 0, 1) * 0.6
    bottom = np.clip((y - 0.66) / 0.2, 0, 1) * 0.8
    alpha = np.repeat(np.maximum(top, bottom), W, axis=1)
    shade = Image.new('RGBA', (W, H), (6, 2, 18, 0))
    shade.putalpha(Image.fromarray(np.uint8(alpha * 255)))
    return shade


def end_frame(t):
    """The gate ahead of you, waiting: the name, and how to step inside."""
    local = t - END
    img = film_frame(t).convert('RGBA')
    shade = cached('endshade', _end_shade)
    k = min(1, local / 0.8)
    if k < 1:
        shade = shade.copy()
        shade.putalpha(shade.getchannel('A').point(lambda v: int(v * k)))
    img.alpha_composite(shade)
    for (a, text, style, y) in [(0.3, 'UTOPIA', 'title', 0.075), (1.2, 'Step inside.', 'big', 0.19)]:
        if local > a:
            POSITIONS[style] = y
            img.alpha_composite(text_layer(text, style, local - a, 99))
    POSITIONS.update({'title': 0.40, 'big': 0.16})
    if local > 2.0:
        f = min(1, (local - 2.0) / 0.5)
        layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        btn = font('Inter-ExtraBold.ttf', 52)
        label = 'Play free in your browser'
        bw = d.textlength(label, font=btn) + 120
        bx, by = (W - bw) / 2, 1480
        d.rounded_rectangle((bx, by, bx + bw, by + 118), radius=59, fill=GOLD + (255,))
        d.text((bx + 60, by + 28), label, font=btn, fill=(40, 20, 60))
        u = font('SpaceGrotesk-Bold.ttf', 60)
        url = 'utopia.kaivon.app'
        d.text(((W - d.textlength(url, font=u)) / 2, 1640), url, font=u, fill=(255, 255, 255))
        s = font('Inter-SemiBold.ttf', 36)
        note = 'Ludo \u00b7 Chess \u00b7 Checkers \u00b7 Cards \u00b7 Guess My Doodle'
        d.text(((W - d.textlength(note, font=s)) / 2, 1735), note, font=s, fill=(200, 190, 235))
        note2 = 'Free. No download. Phones, tablets, computers.'
        d.text(((W - d.textlength(note2, font=s)) / 2, 1785), note2, font=s, fill=(170, 160, 210))
        if f < 1:
            layer.putalpha(layer.getchannel('A').point(lambda v: int(v * f)))
        img.alpha_composite(layer)
    out = img.convert('RGB')
    fade_out = min(1, (LENGTH - t) / 1.2)
    if fade_out < 1:
        out = Image.blend(Image.new('RGB', (W, H), (0, 0, 0)), out, max(0, fade_out))
    return out


def frame(t, texts):
    if t >= END:
        return finish(end_frame(t), t)
    img = film_frame(t)
    live = [x for x in texts if x[0] <= t < x[1]]
    if live:
        base = img.convert('RGBA')
        for a, b, text, style, ink in live:
            layer = text_layer(text, style, t - a, b - a, ink)
            if layer is not None:
                base.alpha_composite(layer)
        img = base.convert('RGB')
    return finish(img, t)


def render_part(args):
    first, last, path = args
    texts, _ = timeline()
    proc = subprocess.Popen(
        [FF, '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}',
         '-r', str(FPS), '-i', '-', '-c:v', 'libx264', '-crf', '17', '-preset', 'medium',
         '-pix_fmt', 'yuv420p', path], stdin=subprocess.PIPE)
    for n in range(first, last):
        proc.stdin.write(frame(n / FPS, texts).tobytes())
    proc.stdin.close()
    proc.wait()
    return path


def main():
    """[--audio]: mix the sound again over the picture already made."""
    os.makedirs(WORK, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    video = os.path.join(WORK, 'video.mp4')
    if '--audio' not in sys.argv:
        frames = int(LENGTH * FPS)
        parts = 10
        edges = [frames * i // parts for i in range(parts + 1)]
        jobs = [(edges[i], edges[i + 1], os.path.join(WORK, f'part{i:02d}.mp4'))
                for i in range(parts)]
        with Pool(min(parts, os.cpu_count() or 4)) as pool:
            done = pool.map(render_part, jobs)
        listing = os.path.join(WORK, 'parts.txt')
        open(listing, 'w').write(''.join(f"file '{p}'\n" for p in done))
        master = os.path.join(WORK, 'master.mp4')
        subprocess.run([FF, '-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', listing,
                        '-c', 'copy', master], check=True)
        # For posting: the grain kept, the size an app will take (~110 MB).
        subprocess.run([FF, '-y', '-loglevel', 'error', '-i', master, '-c:v', 'libx264',
                        '-preset', 'slow', '-tune', 'grain', '-crf', '18', '-maxrate', '12M',
                        '-bufsize', '24M', '-pix_fmt', 'yuv420p', video], check=True)
    score = os.path.join(WORK, 'score.wav')
    subprocess.run([sys.executable, os.path.join(os.path.dirname(__file__), 'score.py'), score],
                   check=True)
    voice = os.path.join(WORK, 'voice.wav')
    subprocess.run([sys.executable, os.path.join(os.path.dirname(__file__), 'voice.py'), voice],
                   check=True)
    _, sfx = timeline()
    for name, narrated in (('Utopia - Trailer, narrated (9x16).mp4', True),
                           ('Utopia - Trailer, music only (9x16).mp4', False)):
        inputs = ['-i', video, '-i', score, '-i', voice]
        parts_a = ['[1:a]volume=0.9[m]']
        labels = ['[m]']
        for i, (at, sound, vol) in enumerate(sfx):
            inputs += ['-i', os.path.join(SFX, sound)]
            ms = int(at * 1000)
            parts_a.append(f'[{i + 3}:a]volume={vol},adelay={ms}|{ms}[s{i}]')
            labels.append(f'[s{i}]')
        parts_a.append(f'{"".join(labels)}amix=inputs={len(labels)}:normalize=0[bed]')
        if narrated:
            # The music steps back while the narrator speaks.
            parts_a.append('[2:a]asplit=2[vo1][vo2]')
            parts_a.append('[bed][vo1]sidechaincompress=threshold=0.03:ratio=4:attack=20:release=400[ducked]')
            parts_a.append('[ducked][vo2]amix=inputs=2:normalize=0,alimiter=limit=0.95[a]')
        else:
            parts_a.append('[bed]alimiter=limit=0.95[a]')
        out = os.path.join(OUT, name)
        subprocess.run([FF, '-y', '-loglevel', 'error', *inputs, '-filter_complex', ';'.join(parts_a),
                        '-map', '0:v', '-map', '[a]', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '256k',
                        '-ar', '48000', '-ac', '2', '-t', str(LENGTH), '-movflags', '+faststart', out],
                       check=True)
    print('made the trailer in', OUT)


if __name__ == '__main__':
    main()
