"""Utopia's ads: the main one ("there's more to Utopia than you think") and
short ones, each on one part of the game, cut from the game itself filmed
in Chrome (tool/ads/shoot.sh). Written to ~/Desktop/Utopia Ads.

  python3 -m venv .venv && .venv/bin/pip install imageio-ffmpeg pillow
  tool/ads/shoot.sh                  # films every shot into build/ads/raw
  .venv/bin/python tool/ads/ads.py [main|worlds|chip|ludo|doodle|cards ...]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compose import render  # noqa: E402

OUT = os.path.expanduser('~/Desktop/Utopia Ads')

WORLDS = ['utopia_halloween', 'utopia_winter', 'utopia_music', 'utopia_heaven', 'utopia_hell',
          'utopia_dojo', 'utopia_deep', 'utopia_alien', 'utopia_birthday', 'utopia_zombie']

# Chip's moods in the chipshow films (seconds in): what each shows.
MOODS = {'evil': 0.4, 'peaceful': 1.6, 'sad': 3.4, 'vibing': 5.2, 'hot': 7.0,
         'happy': 8.8, 'excited': 10.6, 'thinking': 12.4}


class Cut:
    """Builds a timeline and the sounds that go with it, in order."""

    def __init__(self):
        self.clips = []
        self.sfx = []
        self.t = 0.0

    def add(self, shot, at, dur, sound=None, sound_at=0.0, vol=0.8, **opts):
        self.clips.append(dict(shot=shot, at=at, dur=dur, **opts))
        if sound:
            self.sfx.append((self.t + sound_at, sound, vol))
        self.t += dur
        return self

    def sound(self, name, at=0.0, vol=0.8):
        self.sfx.append((self.t + at, name, vol))
        return self

    def worlds(self, names, each, caption, sub=None):
        for i, w in enumerate(names):
            last = i == len(names) - 1
            self.add(f'cards_{w}', 0.6, each, caption=caption, sub=sub,
                     rise=i == 0, fade_out=last, zoom=0.04,
                     sound='tap.wav' if i else 'teleport.wav', vol=0.35 if i else 0.7)
        return self

    def go(self, name, end=3.6, music='menu.wav'):
        os.makedirs(OUT, exist_ok=True)
        out = os.path.join(OUT, name + '.mp4')
        self.sfx.append((self.t + 0.25, 'win.wav', 0.7))
        render(self.clips, out, music=music, sfx=self.sfx, end=end)
        print('made', out, f'{self.t + end:.1f}s')


def main_ad():
    c = Cut()
    c.add('ludomid', 3.0, 2.7, caption=["You think it's", '*just Ludo?*'],
          sound='dice_shake.wav', sound_at=0.15, vol=0.7)
    c.sound('dice_land.wav', at=-1.6, vol=0.7)
    c.add('cards_utopia_doodle', 0.4, 1.2, caption=['*Step inside.*'], flash=True,
          sound='teleport.wav', vol=0.8)
    c.worlds(WORLDS[:8], 0.62, ['*17 worlds*', 'to play in'])
    # Chip, through his moods.
    c.add('chip_halloween', MOODS['excited'], 1.0, caption=['Meet *Chip.*'], fade_out=False,
          sound='reaction.wav', vol=0.6)
    c.add('chip_doodle', MOODS['evil'], 0.8, caption=['Meet *Chip.*'], rise=False,
          fade_out=False, sound='capture_war.wav', vol=0.5)
    c.add('chip_halloween', MOODS['sad'], 0.8, caption=['He reacts to', '*everything.*'],
          fade_out=False, sound='react_sad.wav', vol=0.6)
    c.add('chip_doodle', MOODS['vibing'], 1.0, caption=['He reacts to', '*everything.*'],
          rise=False)
    c.add('chipdraws', 0.3, 3.4, speed=1.9, caption=['He *draws.*', 'You *guess.*'],
          sound='drawer.wav', vol=0.6)
    c.add('ludomid', 24.4, 2.4, caption=['Send them *home...*'], sound='capture.wav',
          sound_at=0.85, vol=0.8, zoom_from=0.08, zoom=0.32, focus=(0.38, 0.55))
    c.add('ludomid', 43.4, 2.4, caption=['...and they', '*react.*'], sound='react_again.wav',
          sound_at=0.7, vol=0.8, zoom_from=0.12, zoom=0.4, focus=(0.3, 0.64))
    c.add('eights', 8.0, 2.6, caption=['*Cards.* Chess.', 'Checkers. *Ludo.*'],
          sound='card_play.wav', sound_at=1.3, vol=0.7)
    c.add('home_winter', 1.0, 2.4, caption=['Your friends,', 'or *the whole world.*'],
          sound='home.wav', vol=0.5)
    c.go('Utopia - There is more inside (main, 9x16)')


def worlds_ad():
    c = Cut()
    c.add('cards_utopia', 0.5, 1.6, caption=['One game.'], sound='tap.wav', vol=0.4)
    c.worlds(['utopia_doodle'] + WORLDS, 0.7, ['*17 worlds.*'], sub='Which one is yours?')
    c.go('Utopia - Worlds (short, 9x16)', music='winter.m4a')


def chip_ad():
    c = Cut()
    c.add('chip_doodle', 1.7, 1.4, caption=['This is *Chip.*'],
          sound='reaction.wav', vol=0.6)
    for shot, mood, sound in [('chip_halloween', 'evil', 'hw_cackle.wav'),
                              ('chip_doodle', 'sad', 'react_sad.wav'),
                              ('chip_halloween', 'vibing', 'tap.wav'),
                              ('chip_doodle', 'hot', 'reaction.wav'),
                              ('chip_halloween', 'excited', 'teleport.wav'),
                              ('chip_doodle', 'peaceful', 'chat.wav')]:
        c.add(shot, MOODS[mood], 0.95, caption=['He feels', '*everything.*'],
              rise=mood == 'evil', fade_out=mood == 'peaceful', sound=sound, vol=0.55)
    c.add('chipdraws', 0.3, 3.4, speed=1.9, caption=['He even *draws.*', 'Can you *guess?*'],
          sound='drawer.wav', vol=0.6)
    c.go('Utopia - Meet Chip (short, 9x16)', music='game.wav')


def ludo_ad():
    c = Cut()
    c.add('ludomid', 2.0, 3.0, caption=['Ludo,', '*but alive.*'], sound='dice_shake.wav',
          sound_at=0.4, vol=0.7)
    c.add('ludomid', 24.4, 3.6, caption=['Get sent *home?*'], sound='capture.wav',
          sound_at=0.85, vol=0.8, zoom_from=0.08, zoom=0.4, focus=(0.36, 0.58))
    c.sound('react_sad.wav', at=-1.0, vol=0.7)
    c.add('ludomid', 43.4, 3.0, caption=['Say it with your', '*piece.*'],
          sound='react_again.wav', sound_at=0.7, vol=0.8, zoom_from=0.12, zoom=0.45,
          focus=(0.3, 0.64))
    c.add('home_utopia', 1.0, 2.2, caption=['Free, with', '*friends.*'], sound='home.wav',
          vol=0.5)
    c.go('Utopia - Ludo (short, 9x16)')


def doodle_ad():
    c = Cut()
    c.add('cards_utopia_doodle', 0.4, 1.8, caption=['Welcome to the', '*Doodle world.*'],
          sound='teleport.wav', vol=0.7)
    c.add('chipdraws', 0.0, 4.4, speed=1.7, caption=['Chip draws.', '*Guess it first.*'],
          sound='drawer.wav', vol=0.6)
    c.add('chip_doodle', MOODS['excited'], 1.4, caption=['Draw for your', '*friends too.*'],
          sound='reaction.wav', vol=0.6)
    c.go('Utopia - Guess My Doodle (short, 9x16)', music='game.wav')


def cards_ad():
    c = Cut()
    c.add('eights', 6.5, 4.6, caption=['*Crazy Eights*', 'with friends'], sound='card_play.wav',
          sound_at=3.3, vol=0.7)
    c.sound('card_wild.wav', at=-1.0, vol=0.6)
    c.add('eights', 19.0, 2.4, caption=['*Last card!*'], sound='last_card.wav', sound_at=0.8,
          vol=0.7)
    c.add('cards_utopia_music', 0.5, 1.6, caption=['And so much', '*more.*'], sound='teleport.wav',
          vol=0.6)
    c.go('Utopia - Crazy Eights (short, 9x16)')


ADS = {'main': main_ad, 'worlds': worlds_ad, 'chip': chip_ad, 'ludo': ludo_ad,
       'doodle': doodle_ad, 'cards': cards_ad}

if __name__ == '__main__':
    for name in sys.argv[1:] or ADS:
        ADS[name]()
