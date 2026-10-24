"""Add user-supplied effect clips (mp3) as curated events.

Usage: python add_event_sfx.py <folder with <event>[_N].mp3> <ffmpeg>
Each clip is converted to mono Vorbis, trimmed to the role's maximum length,
faded and level-matched to the curated set. Writes assets/sfx/curated/<event>_NN.ogg and the
catalog/manifest entries. Clips listed in SKIP are left out on purpose.
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys

import numpy as np

# event -> (max seconds, fade-out ms, target mean level dBFS). Levels match the curated set:
# small UI sounds sit near -30, effects near -25, banners and jingles near -20 (game_start -18, win -17).
SPEC = {
    'turn_start': (1.5, 400, -25), 'round_start': (2.0, 400, -21), 'review_open': (1.0, 80, -30),
    'review_confirm': (1.0, 80, -29), 'attack_alert': (1.0, 80, -22), 'trap_hidden': (1.2, 120, -26),
    'build_hotel': (2.2, 250, -25), 'build_mine': (1.6, 200, -26), 'revenge_ignite': (2.4, 700, -25),
    'tempo_warning': (1.0, 80, -22), 'emote_pop': (0.8, 60, -29), 'timer_tick': (0.4, 80, -31),
    'timeout': (1.6, 150, -25), 'graduate': (4.0, 400, -22), 'podium': (5.5, 500, -22),
}
PEAK_LIMIT_DB = -2.0  # never louder than this peak, even if the mean target asks for more
SKIP = {'build_mine_2.mp3'}  # 0.14 s blip: reads as a click, not a variant of the mine sound

folder = Path(sys.argv[1])
ffmpeg = sys.argv[2]
out = Path(__file__).resolve().parents[2] / 'assets/sfx/curated'
rate = 44100
manifest = out / 'manifest.json'
rows = json.loads(manifest.read_text(encoding='utf-8'))
catalog_lines = {}
for src in sorted(folder.glob('*.mp3')):
    if src.name in SKIP:
        continue
    event = re.sub(r'_\d+$', '', src.stem)
    if event not in SPEC:
        print('skip (unknown event):', src.name)
        continue
    max_s, fade_ms, mean_db = SPEC[event]
    raw = subprocess.check_output([ffmpeg, '-v', 'error', '-i', str(src), '-ac', '1', '-ar', str(rate), '-f', 'f32le', '-'])
    x = np.frombuffer(raw, dtype='<f4').copy()
    active = np.flatnonzero(abs(x) > abs(x).max() * .01)
    if len(active):
        x = x[max(0, int(active[0]) - 88):]
    x = x[:int(max_s * rate)]
    fade = min(int(fade_ms / 1000 * rate), len(x) // 2)
    x[:44] *= np.linspace(0, 1, 44)
    x[-fade:] *= np.linspace(1, 0, fade)
    rms_db = 20 * np.log10(float(np.sqrt(np.mean(x ** 2))) + 1e-9)
    x *= 10 ** ((mean_db - rms_db) / 20)
    peak_db = 20 * np.log10(float(abs(x).max()) + 1e-9)
    if peak_db > PEAK_LIMIT_DB:
        x *= 10 ** ((PEAK_LIMIT_DB - peak_db) / 20)
    n = len(catalog_lines.setdefault(event, [])) + 1
    target = out / f'{event}_{n:02d}.ogg'
    subprocess.run([ffmpeg, '-v', 'error', '-y', '-f', 'f32le', '-ar', str(rate), '-ac', '1', '-i', '-',
                    '-c:a', 'libvorbis', '-q:a', '5', str(target)], input=x.astype('<f4').tobytes(), check=True)
    catalog_lines[event].append(f'res://assets/sfx/curated/{target.name}')
    rows = [r for r in rows if r.get('file') != target.name]
    rows.append(dict(event=event, file=target.name, source='user-supplied/' + src.name, author='project supplied',
                     license='user-supplied (verify before public release)',
                     source_sha256=hashlib.sha256(src.read_bytes()).hexdigest(),
                     sha256=hashlib.sha256(target.read_bytes()).hexdigest(), seconds=round(len(x) / rate, 4),
                     target_mean_db=mean_db, peak_limit_db=PEAK_LIMIT_DB, max_seconds=max_s, fade_out_ms=fade_ms))
    print(f'{target.name}: {len(x) / rate:.2f}s {target.stat().st_size} bytes')
manifest.write_text(json.dumps(rows, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
catalog = out / 'catalog.gd'
text = catalog.read_text(encoding='utf-8')
for event, files in catalog_lines.items():
    entry = '\t&"%s": [%s],\n' % (event, ', '.join('"%s"' % f for f in files))
    text = re.sub(r'\t&"%s": \[[^\n]*\],\n' % event, '', text)
    text = text.replace('\n}', '\n' + entry.rstrip('\n') + '\n}', 1) if text.rstrip().endswith('}') else text
catalog.write_text(text, encoding='utf-8')
