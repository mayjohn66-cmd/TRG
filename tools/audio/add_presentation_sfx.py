"""Build only presentation SFX from downloaded CC0 originals.

Usage: python add_presentation_sfx.py <source directory> <ffmpeg> [event ...]
Download rpg.zip from https://opengameart.org/content/80-cc0-rpg-sfx,
clank1.wav/rattle1.wav/squeakyclick1.wav from
https://opengameart.org/content/mechanical-sounds and whistle.wav from
https://bigsoundbank.com/train-whistle-foley-6-s3320.html into that directory.
Existing curated recordings are left untouched. NumPy and FFmpeg required.
"""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import zipfile

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(sys.argv[1]).resolve()
FFMPEG = str(Path(sys.argv[2]).resolve())
DEST = ROOT / 'assets/sfx/curated'
RATE = 24000
RPG = ('rubberduck', 'https://opengameart.org/content/80-cc0-rpg-sfx')
MECH = ('Brian MacIntosh (BMacZero)', 'https://opengameart.org/content/mechanical-sounds')
TRAIN = ('Joseph Sardin / Axeline T.', 'https://bigsoundbank.com/train-whistle-foley-6-s3320.html')
# event, variant, original, start, seconds, playback speed, target RMS dBFS, credit
SPECS = [
    ('rail_lay', 1, 'clank1.wav', .018, .40, 1.15, -24, MECH),
    ('rail_lay', 2, 'metal_03.ogg', .005, .37, 1.1, -24, RPG),
    ('train_chug', 1, 'rattle1.wav', .020, .19, .92, -27, MECH),
    ('train_whistle', 1, 'whistle.wav', .025, 3.05, 1., -24, TRAIN),
    ('chain_pull', 1, 'chain_01.ogg', .003, .48, 1., -26, RPG),
    ('chain_pull', 2, 'chain_02.ogg', .001, .46, 1., -26, RPG),
    ('chain_lock', 1, 'lock_03.ogg', .002, .33, .95, -23, RPG),
    ('bakery_door', 1, 'squeakyclick1.wav', .020, .38, .92, -26, MECH),
    # The bright metal variant measures 4.4 dB louder than wood at equal RMS.
    ('bakery_rummage', 1, 'clank1.wav', .018, .46, .83, -29.4, MECH),
    ('bakery_rummage', 2, 'wood_03.ogg', 0., .43, .86, -25, RPG),
    ('cutin_slash', 1, 'blade_03.ogg', .002, .36, .9, -23, RPG),
    ('pinball_hit', 1, 'metal_01.ogg', .028, .31, 1.45, -27, RPG),
]

if len(sys.argv) > 3:
    requested = set(sys.argv[3:])
    if requested - {spec[0] for spec in SPECS}:
        raise SystemExit('Unknown presentation event')
    SPECS = [spec for spec in SPECS if spec[0] in requested]

with zipfile.ZipFile(SOURCE / 'rpg.zip') as archive:
    for name in {s[2] for s in SPECS if s[7] == RPG}:
        (SOURCE / name).write_bytes(archive.read(name))

manifest_path = DEST / 'manifest.json'
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
manifest_order = {row['file']: i for i, row in enumerate(manifest)}
events = {s[0] for s in SPECS}
manifest = [row for row in manifest if row['event'] not in events]
catalog_path = DEST / 'catalog.gd'
catalog = catalog_path.read_text(encoding='utf-8')
files = {}
report = []
for event, variant, original, start, seconds, speed, target, credit in SPECS:
    source = SOURCE / original
    filters = 'highpass=f=70,lowpass=f=9500'
    decoded = subprocess.check_output([FFMPEG, '-v', 'error', '-i', str(source),
        '-af', filters, '-ac', '1', '-ar', str(RATE), '-f', 'f32le', '-'])
    samples = np.frombuffer(decoded, dtype='<f4').copy()
    samples = samples[round(start*RATE):round((start+seconds)*RATE)]
    samples = np.interp(np.arange(0, len(samples), speed), np.arange(len(samples)), samples)
    # Preserve the first transient; soften only sample edges and the final decay.
    attack = min(round(.002*RATE), len(samples)//4)
    release = min(round((.18 if event == 'train_whistle' else .04)*RATE), len(samples)//4)
    samples[:attack] *= np.linspace(0, 1, attack)
    samples[-release:] *= np.linspace(1, 0, release)
    rms = float(np.sqrt(np.mean(samples*samples)))
    peak = float(np.max(np.abs(samples)))
    samples *= min(10**(target/20)/max(rms, 1e-8), .68/max(peak, 1e-8))
    output = DEST / f'{event}_{variant:02}.ogg'
    subprocess.run([FFMPEG, '-v', 'error', '-y', '-f', 'f32le', '-ar', str(RATE), '-ac', '1',
        '-i', '-', '-c:a', 'libvorbis', '-q:a', '1', str(output)],
        input=samples.astype('<f4').tobytes(), check=True)
    files.setdefault(event, []).append('res://assets/sfx/curated/' + output.name)
    row = {'event': event, 'file': output.name, 'source': original, 'author': credit[0],
        'url': credit[1], 'license': 'CC0-1.0', 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'sha256': hashlib.sha256(output.read_bytes()).hexdigest(), 'seconds': len(samples)/RATE,
        'sample_rate': RATE, 'channels': 1, 'quality': 1, 'filters': filters,
        'trim_start': start, 'speed': speed, 'target_rms_db': target, 'peak_ceiling': .68,
        'fade_in_ms': 2, 'fade_out_ms': round(release/RATE*1000)}
    manifest.append(row)
    report.append({'file': output.name, 'bytes': output.stat().st_size, 'seconds': round(row['seconds'], 3)})

for event, paths in files.items():
    entry = '\t&"%s": [%s],' % (event, ', '.join(json.dumps(p) for p in paths))
    lines = catalog.splitlines()
    index = next((i for i, line in enumerate(lines) if f'&"{event}"' in line), None)
    if index is None:
        lines.insert(len(lines)-1, entry)
    else:
        lines[index] = entry
    catalog = '\n'.join(lines)+'\n'
manifest.sort(key=lambda row: manifest_order.get(row['file'], len(manifest_order)))
catalog_path.write_text(catalog, encoding='utf-8', newline='\n')
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8', newline='\n')
print(json.dumps({'clips': report, 'total_bytes': sum(r['bytes'] for r in report)}, indent=2))
