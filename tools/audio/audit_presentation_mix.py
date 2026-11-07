"""Measure the new cues at their actual scene gains, against existing SFX.

python audit_presentation_mix.py <ffmpeg> <output directory>
Requires NumPy. Reads assets; writes reports only. No loudness normalization of
unrelated SFX. M400 is maximum K-weighted 400 ms momentary loudness: padding
permits meaningful measurement of short one-shots without a music-style gate.
"""
import json
from pathlib import Path
import re
import subprocess
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
FFMPEG = str(Path(sys.argv[1]).resolve())
OUT = Path(sys.argv[2]).resolve()
OUT.mkdir(parents=True, exist_ok=True)
RATE = 48000
SCENES = {
    'runaway_train_stage': ['rail_lay', 'train_chug', 'train_whistle'],
    'bond_stage': ['chain_pull', 'chain_lock'],
    'bakery_stage': ['bakery_door', 'bakery_rummage'],
    'raid_stage': ['cutin_slash'], 'stage_pinball': ['pinball_hit'],
}
gains = {}
for scene, events in SCENES.items():
    source = (ROOT / 'scenes' / (scene + '.gd')).read_text(encoding='utf-8')
    for event in events:
        match = re.search(r'Sfx\.play\(&"' + event + r'"\s*,\s*(-?[\d.]+)', source)
        if not match:
            raise ValueError('Cannot locate scene gain for ' + event)
        gains[event] = float(match[1])

references = {'ui_click': 0., 'hop': 0., 'yut_clack': 0., 'mahjong_tap': 0.,
              'slam': 0., 'thud': 0., 'card_impact': -4., 'charge': -9.,
              'dash': -7., 'good': -6., 'rocket': -7., 'promote': -9.}

def db(value):
    return round(20 * np.log10(max(float(value), 1e-10)), 2)

def measure(samples):
    power = samples * samples
    count = min(len(samples), RATE // 10)
    total = np.cumsum(np.r_[0., power])
    raw = samples.astype('<f4').tobytes()
    result = subprocess.run([FFMPEG, '-hide_banner', '-f', 'f32le', '-ar', str(RATE),
        '-ac', '1', '-i', '-', '-af', 'apad=pad_dur=0.5,ebur128=peak=true',
        '-f', 'null', '-'], input=raw, capture_output=True, check=True)
    moments = re.findall(r'\bM:\s*([-\d.]+)', result.stderr.decode('utf-8', errors='replace'))
    return {'rms_dbfs': db(np.sqrt(np.mean(power))),
            'rms100_dbfs': db(np.sqrt(np.max(total[count:] - total[:-count]) / count)),
            'peak_dbfs': db(np.max(np.abs(samples))),
            'm400_lufs': max(map(float, moments))}

clips = {}
rows = []
manifest = json.loads((ROOT / 'assets/sfx/curated/manifest.json').read_text(encoding='utf-8'))
for row in manifest:
    event = row['event']
    if event not in gains and event not in references:
        continue
    raw = subprocess.check_output([FFMPEG, '-v', 'error', '-i',
        str(ROOT / 'assets/sfx/curated' / row['file']), '-ac', '1', '-ar', str(RATE), '-f', 'f32le', '-'])
    samples = np.frombuffer(raw, dtype='<f4').astype('float64')
    clips.setdefault(event, []).append(samples)
    gain = gains.get(event, references.get(event))
    measured = measure(samples * 10**(gain / 20))
    rows.append({'event': event, 'file': row['file'], 'scene_gain_db': gain, **measured})

def mix(cues):
    # cues: time, event, variant, pitch. Use real waveforms, never generated tones.
    result = np.zeros(round((max(c[0] for c in cues) + 4) * RATE))
    for at, event, variant, pitch in cues:
        raw = clips[event][variant % len(clips[event])]
        samples = np.interp(np.arange(0, len(raw), pitch), np.arange(len(raw)), raw)
        samples *= 10**(gains.get(event, references.get(event)) / 20)
        start = round(at * RATE)
        result[start:start+len(samples)] += samples
    return measure(result)

mixtures = {}
for pace in [.35/3., .5, 1., 2.]:
    # Twelve rails cover even a full normalized board edge plus approach slack.
    mixtures[f'rails_{pace}'] = mix([(i*.065*pace, 'rail_lay', i, 1+i*.012) for i in range(12)])
    beats = [(0., 'train_whistle', 0, 1.)]
    elapsed = 0.
    while elapsed < 1.85:
        elapsed += .16 + (.065-.16) * elapsed/1.85
        beats.append((elapsed*pace, 'train_chug', 0, .95 + elapsed/1.85*.2))
    mixtures[f'train_{pace}'] = mix(beats)
    mixtures[f'bakery_{pace}'] = mix([(0., 'bakery_door', 0, 1.)] +
        [((.36+t)*pace, 'bakery_rummage', i, 1.) for i,t in enumerate([.10,.34,.65,.97])])
    mixtures[f'chain_{pace}'] = mix([(0., 'charge', 0, 1.), (.22*pace, 'chain_pull', 0, 1.), (.82*pace, 'chain_lock', 0, 1.)])
mixtures['raid_impact'] = mix([(0., 'card_impact', 0, 1.), (0., 'cutin_slash', 0, 1.)])
mixtures['rapid_pinball'] = mix([(i*.04, 'pinball_hit', 0, 1+.04*(i%4)) for i in range(8)])
mixtures['rapid_pinball_3x'] = mix([(i*.04/3, 'pinball_hit', 0, 1+.04*(i%4)) for i in range(8)])

checks = {}
for event in ['rail_lay', 'chain_pull', 'bakery_rummage']:
    levels = [r['m400_lufs'] for r in rows if r['event'] == event]
    checks[event + '_variant_spread_db'] = round(max(levels)-min(levels), 2)
report = {'gains': gains, 'clips': rows, 'overlap': mixtures, 'checks': checks}
(OUT / 'mix-audit.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
(OUT / 'native-gains.json').write_text(json.dumps(gains)+'\n', encoding='utf-8')
for row in rows:
    print('%-25s gain=%5.1f M400=%5.1f peak=%6.2f' % (row['file'], row['scene_gain_db'], row['m400_lufs'], row['peak_dbfs']))
print('OVERLAP', json.dumps(mixtures))
print('VARIANTS', json.dumps(checks))
if any(value > 2. for value in checks.values()) or any(row['peak_dbfs'] > -3. for row in mixtures.values()):
    raise SystemExit('Review variant loudness or overlap headroom')
print('PRESENTATION_MIX_OK: variants within 2 dB; rapid overlaps keep at least 3 dB headroom')
