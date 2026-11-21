"""Add the short Halli bell from a local Kenney Impact Sounds pack (CC0).

Usage: python add_halli_bell.py <impact pack folder containing Audio/> <ffmpeg>
Only the halli_bell derivative and its catalog/manifest entry are written.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

import numpy as np

source = Path(sys.argv[1]) / 'Audio/impactBell_heavy_000.ogg'
ffmpeg = sys.argv[2]
out = Path(__file__).resolve().parents[2] / 'assets/sfx/curated'
rate = 44100
speed = 1.6
raw = subprocess.check_output([ffmpeg, '-v', 'error', '-i', str(source),
                               '-ac', '1', '-ar', str(rate), '-f', 'f32le', '-'])
x = np.frombuffer(raw, dtype='<f4').copy()
active = np.flatnonzero(abs(x) > abs(x).max() * .012)
if len(active):
    x = x[max(0, int(active[0]) - 88):]
x = np.interp(np.arange(0, len(x), speed), np.arange(len(x)), x).astype('f4')
x = x[:int(.72 * rate)]
fade = min(int(.06 * rate), len(x) // 4)
x[:44] *= np.linspace(0, 1, 44)
x[-fade:] *= np.linspace(1, 0, fade)
x *= 10 ** ((-25 - 20 * np.log10(float(np.sqrt(np.mean(x ** 2))) + 1e-9)) / 20)
if abs(x).max() > .8:
    x *= .8 / abs(x).max()
target = out / 'halli_bell_01.ogg'
subprocess.run([ffmpeg, '-v', 'error', '-y', '-f', 'f32le', '-ar', str(rate),
                '-ac', '1', '-i', '-', '-c:a', 'libvorbis', '-q:a', '5', str(target)],
               input=x.astype('<f4').tobytes(), check=True)
manifest = out / 'manifest.json'
rows = [r for r in json.loads(manifest.read_text(encoding='utf-8')) if r['event'] != 'halli_bell']
rows.append(dict(event='halli_bell', file=target.name, source='kenney_impact/Audio/' + source.name,
                 author='Kenney', url='https://kenney.nl/assets/impact-sounds', license='CC0-1.0',
                 source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                 sha256=hashlib.sha256(target.read_bytes()).hexdigest(), seconds=round(len(x) / rate, 4),
                 target_rms_db=-25, speed=speed, max_seconds=.72, fade_out_ms=60, fade_in_ms=1))
manifest.write_text(json.dumps(rows, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
catalog = out / 'catalog.gd'
text = catalog.read_text(encoding='utf-8')
if '&"halli_bell"' not in text:
    text = text.replace('\n}', '\n\t&"halli_bell": ["res://assets/sfx/curated/halli_bell_01.ogg"],\n}')
catalog.write_text(text, encoding='utf-8')
print(f'Halli bell: {len(x) / rate:.3f}s, {target.stat().st_size} bytes')
