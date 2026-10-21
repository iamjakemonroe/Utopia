"""Cuts filmed Utopia shots into a vertical ad: shots with a slow push-in,
captions that rise in, flashes on the beats, an end card, and the game's
own music and sounds under it."""
import json
import math
import os
import subprocess

import imageio_ffmpeg
from PIL import Image, ImageDraw, ImageFilter, ImageFont

FF = imageio_ffmpeg.get_ffmpeg_exe()
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RAW = os.path.join(REPO, 'build', 'ads', 'raw')
FONTS = os.path.join(REPO, 'assets', 'google_fonts')
SFX = os.path.join(REPO, 'assets', 'sfx')
MUSIC = os.path.join(REPO, 'assets', 'music')
W, H, FPS = 1080, 1920, 30
GOLD = (255, 201, 61)
WHITE = (255, 255, 255)


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


class Shot:
    """A filmed scene: its frames and when each was painted."""

    _cache = {}

    def __init__(self, name):
        self.dir = os.path.join(RAW, name)
        times = json.load(open(os.path.join(self.dir, 'times.json')))
        self.t = [x - times[0] for x in times]

    @classmethod
    def get(cls, name):
        if name not in cls._cache:
            cls._cache[name] = Shot(name)
        return cls._cache[name]

    def frame_at(self, sec):
        # The last frame painted at or before [sec].
        lo, hi = 0, len(self.t) - 1
        while lo < hi:
            mid = (lo + hi + 1) // 2
            if self.t[mid] <= sec:
                lo = mid
            else:
                hi = mid - 1
        return os.path.join(self.dir, f'f{lo:05d}.jpg')

    @property
    def length(self):
        return self.t[-1]


def caption_layer(lines, size=96, sub=None, y=330, band=True):
    """Big centered lines (*word* in gold), an optional smaller line under
    them, on a transparent layer with a soft shadow (and a dark band
    fading down from the top, so they read over anything)."""
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    if band:
        bottom = y + len(lines) * size * 1.12 + (90 if sub else 0) + 170
        grad = Image.new('L', (1, int(bottom)))
        for yy in range(int(bottom)):
            k = yy / bottom
            grad.putpixel((0, yy), int(205 * (1 - k ** 1.6)))
        shade = Image.new('RGBA', (W, int(bottom)), (8, 3, 28, 255))
        shade.putalpha(grad.resize((W, int(bottom))))
        layer.alpha_composite(shade)
    big = font('SpaceGrotesk-Bold.ttf', size)
    small = font('Inter-Bold.ttf', int(size * 0.46))
    draw = ImageDraw.Draw(layer)
    rows = []
    cy = y
    for line in lines:
        words = []
        for i, part in enumerate(line.split('*')):
            if part:
                words.append((part, GOLD if i % 2 else WHITE))
        width = sum(draw.textlength(t, font=big) for t, _ in words)
        rows.append((words, width, cy))
        cy += int(size * 1.12)
    if sub:
        sw = draw.textlength(sub, font=small)
        rows.append(([(sub, (235, 228, 255))], sw, cy + 10, small))
    shadow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    for row in rows:
        words, width, ry = row[:3]
        f = row[3] if len(row) > 3 else big
        x = (W - width) / 2
        for text, color in words:
            sd.text((x + 3, ry + 6), text, font=f, fill=(10, 4, 30, 230))
            x += draw.textlength(text, font=f)
    shadow = shadow.filter(ImageFilter.GaussianBlur(9))
    layer.alpha_composite(shadow)
    draw = ImageDraw.Draw(layer)
    for row in rows:
        words, width, ry = row[:3]
        f = row[3] if len(row) > 3 else big
        x = (W - width) / 2
        for text, color in words:
            draw.text((x, ry), text, font=f, fill=color + (255,),
                      stroke_width=2, stroke_fill=(20, 10, 45, 180))
            x += draw.textlength(text, font=f)
    return layer


def end_card(tagline='Free games with friends', url='utopia.kaivon.app'):
    """The closing card: the gateway, the name, how to play."""
    base = Image.new('RGB', (W, H), (14, 8, 38))
    glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for r, a in ((760, 40), (560, 60), (380, 80)):
        gd.ellipse((W / 2 - r, 720 - r, W / 2 + r, 720 + r), fill=(140, 90, 255, a))
    glow = glow.filter(ImageFilter.GaussianBlur(120))
    card = base.convert('RGBA')
    card.alpha_composite(glow)
    mark = Image.open(os.path.join(REPO, 'assets', 'branding', 'logo_mark.png')).convert('RGBA')
    mark = mark.resize((760, 760), Image.LANCZOS)
    card.alpha_composite(mark, (int((W - 760) / 2), 330))
    d = ImageDraw.Draw(card)
    title = font('SpaceGrotesk-Bold.ttf', 150)
    tw = d.textlength('UTOPIA', font=title)
    d.text(((W - tw) / 2, 1110), 'UTOPIA', font=title, fill=WHITE)
    tag = font('Inter-Bold.ttf', 50)
    gw = d.textlength(tagline, font=tag)
    d.text(((W - gw) / 2, 1290), tagline, font=tag, fill=(225, 215, 255))
    # The button.
    btn = font('Inter-ExtraBold.ttf', 52)
    label = 'Play free in your browser'
    bw = d.textlength(label, font=btn) + 120
    bx, by = (W - bw) / 2, 1440
    d.rounded_rectangle((bx, by, bx + bw, by + 118), radius=59, fill=GOLD)
    d.text((bx + 60, by + 28), label, font=btn, fill=(40, 20, 60))
    u = font('SpaceGrotesk-Bold.ttf', 58)
    uw = d.textlength(url, font=u)
    d.text(((W - uw) / 2, 1610), url, font=u, fill=WHITE)
    small = font('Inter-SemiBold.ttf', 36)
    note = 'No download. Phones, tablets, computers.'
    nw = d.textlength(note, font=small)
    d.text(((W - nw) / 2, 1700), note, font=small, fill=(190, 180, 225))
    return card


def push(img, k, amount, start=0.0, focus=(0.5, 0.5)):
    """Zooms into [img] by [start] plus [amount] (0.05 = 5%) at progress
    [k], toward [focus] (0-1 across and down)."""
    s = 1 + start + amount * k
    if s <= 1.0001:
        return img
    w, h = int(W / s), int(H / s)
    x = min(max(int(focus[0] * W - w / 2), 0), W - w)
    y = min(max(int(focus[1] * H - h / 2), 0), H - h)
    return img.crop((x, y, x + w, y + h)).resize((W, H), Image.BICUBIC)


def render(timeline, out, music='menu.wav', music_volume=0.7, sfx=(), end=None):
    """[timeline]: dicts with shot, at (seconds into the shot), dur, and
    optionally caption (list of lines), sub, zoom, flash (flash in), y.
    [end]: seconds of end card. [sfx]: (time, file, volume)."""
    total = sum(c['dur'] for c in timeline) + (end or 0)
    frames = int(round(total * FPS))
    proc = subprocess.Popen(
        [FF, '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24',
         '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-', '-c:v', 'libx264', '-crf', '18',
         '-preset', 'medium', '-pix_fmt', 'yuv420p', out + '.video.mp4'],
        stdin=subprocess.PIPE)
    layers = {}
    card = end_card() if end else None
    t0 = 0.0
    spans = []
    for c in timeline:
        spans.append((t0, t0 + c['dur'], c))
        t0 += c['dur']
    for n in range(frames):
        t = n / FPS
        span = next((s for s in spans if s[0] <= t < s[1]), None)
        if span is None:
            # The end card, eased in from black over its first moments.
            k = (t - t0) / end
            img = card.copy().convert('RGB')
            img = push(img, k, 0.035)
            if k < 0.08:
                img = Image.blend(Image.new('RGB', (W, H), (0, 0, 0)), img, k / 0.08)
        else:
            a, b, c = span
            local = t - a
            k = local / (b - a)
            shot = Shot.get(c['shot'])
            img = Image.open(shot.frame_at(
                min(shot.length, c['at'] + local * c.get('speed', 1)))).convert('RGB')
            img = push(img, k, c.get('zoom', 0.05), c.get('zoom_from', 0.0),
                       c.get('focus', (0.5, 0.5)))
            if c.get('flash') and local < 0.18:
                img = Image.blend(img, Image.new('RGB', (W, H), WHITE), 1 - local / 0.18)
            cap = c.get('caption')
            if cap:
                key = (tuple(cap), c.get('sub'), c.get('y', 330), c.get('band', True))
                if key not in layers:
                    layers[key] = caption_layer(cap, sub=c.get('sub'), y=c.get('y', 330),
                                                size=c.get('size', 96), band=c.get('band', True))
                layer = layers[key]
                rise = min(1, local / 0.28) if c.get('rise', True) else 1
                ease = 1 - (1 - rise) ** 3
                fade_out = min(1, (b - a - local) / 0.15) if c.get('fade_out', True) else 1
                alpha = ease * fade_out
                if alpha > 0:
                    moved = Image.new('RGBA', (W, H), (0, 0, 0, 0))
                    moved.alpha_composite(layer, (0, int(40 * (1 - ease))))
                    if alpha < 1:
                        r, g, bb, al = moved.split()
                        al = al.point(lambda v: int(v * alpha))
                        moved = Image.merge('RGBA', (r, g, bb, al))
                    base = img.convert('RGBA')
                    base.alpha_composite(moved)
                    img = base.convert('RGB')
        proc.stdin.write(img.tobytes())
    proc.stdin.close()
    proc.wait()
    mix_audio(out, total, music, music_volume, sfx)
    os.remove(out + '.video.mp4')


def mix_audio(out, total, music, music_volume, sfx):
    inputs = ['-i', out + '.video.mp4', '-stream_loop', '-1', '-i', os.path.join(MUSIC, music)]
    parts = [f'[1:a]atrim=0:{total:.3f},volume={music_volume},'
             f'afade=t=in:d=0.4,afade=t=out:st={max(0, total - 1.8):.3f}:d=1.8[m]']
    labels = ['[m]']
    for i, (at, name, vol) in enumerate(sfx):
        inputs += ['-i', os.path.join(SFX, name)]
        idx = i + 2
        ms = int(at * 1000)
        parts.append(f'[{idx}:a]volume={vol},adelay={ms}|{ms}[s{i}]')
        labels.append(f'[s{i}]')
    parts.append(f'{"".join(labels)}amix=inputs={len(labels)}:normalize=0,'
                 f'alimiter=limit=0.95[a]')
    subprocess.run([FF, '-y', '-loglevel', 'error', *inputs, '-filter_complex', ';'.join(parts),
                    '-map', '0:v', '-map', '[a]', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k',
                    '-ar', '48000', '-ac', '2', '-shortest', '-movflags', '+faststart', out], check=True)
