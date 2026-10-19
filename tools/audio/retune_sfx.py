"""Retune curated effects without the unreachable original packs: python retune_sfx.py <kenney folder> <ffmpeg>.

<kenney folder> holds the unzipped Kenney packs as kenney_<pack-name>/ (e.g. kenney_sci-fi-sounds/Audio/...).
1) Events in REPLACE are rebuilt from the Kenney CC0 sources below (old files and manifest rows are removed).
2) Every curated clip is then brought to its loudness class (RMS target) so similar moments sound equally loud;
   clips already within LOUDNESS_TOLERANCE_DB are left untouched to avoid re-encoding.
3) Clips longer than MAX_SECONDS[event] are shortened with a fade.
manifest.json and catalog.gd are updated in place. Source downloads stay outside the repository.
"""
from pathlib import Path
import hashlib, json, subprocess, sys
import numpy as np

SOURCE = Path(sys.argv[1]).resolve()
FFMPEG = sys.argv[2]
OUT = Path(__file__).resolve().parents[2] / 'assets/sfx/curated'
RATE = 44100
PACKS = {
    'kenney_sci-fi-sounds': 'https://kenney.nl/assets/sci-fi-sounds',
    'kenney_digital-audio': 'https://kenney.nl/assets/digital-audio',
    'kenney_interface-sounds': 'https://kenney.nl/assets/interface-sounds',
    'kenney_impact-sounds': 'https://kenney.nl/assets/impact-sounds',
    'kenney_rpg-audio': 'https://kenney.nl/assets/rpg-audio',
}
# event, source, start seconds (skip slow fade-ins), max seconds, speed.
# Chosen by measured features (duration, attack, brightness trend, tonal vs noise) to fit what happens on screen:
# flights rise in pitch, the rocket is a short thruster burst, the shot is a toy "pew", warps fall inward,
# a hidden trap is a quiet latch, a capture is a body punch instead of a soft tap.
RECIPES = [
    ('launch', 'kenney_digital-audio/Audio/phaseJump2.ogg', 0.0, .32, 1),          # 장외 홈런·점프 코너: 위로 솟는 만화풍 효과
    ('rocket', 'kenney_sci-fi-sounds/Audio/thrusterFire_002.ogg', 1.0, .42, 1),     # 🔥 리벤지 로켓 출격: 분사 화염
    ('dash', 'kenney_digital-audio/Audio/phaserUp7.ogg', 0.0, .30, 1),             # ⚡ 부스터 발판·처치 컷인 돌진
    ('shot', 'kenney_sci-fi-sounds/Audio/laserRetro_000.ogg', 0.0, .24, 1),        # 뱅! 장난감 총 발사
    ('charge', 'kenney_digital-audio/Audio/powerUp5.ogg', 0.0, .26, 1),            # 차 돌진 차징
    ('good', 'kenney_interface-sounds/Audio/confirmation_003.ogg', 0.0, .32, 1),   # 좋은 일 (증강 선택 딩과 구분)
    ('warp', 'kenney_digital-audio/Audio/phaserDown1.ogg', 0.0, .36, 1),           # 옷장 포탈: 빨려 들어가는 하강음
    ('trap_set', 'kenney_rpg-audio/Audio/metalLatch.ogg', 0.0, .16, 1),            # 함정 설치: 조용한 걸쇠
    ('slam', 'kenney_impact-sounds/Audio/impactPunch_heavy_000.ogg', 0.0, .36, 1), # 잡기·결투 타격
]
REPLACE = {event for event, *_ in RECIPES}
# Loudness classes (RMS dBFS). Frequent small sounds stay quiet, punctuation is louder, big moments loudest.
CLASSES = {
    -36.0: ['ui_hover'],
    -30.0: ['ui_click', 'roulette_tick', 'hop', 'card_pick', 'card_get', 'card_throw', 'card_impact', 'dice_roll', 'roll_other',
            'mahjong_tap', 'yut_clack', 'yut_toss', 'slot_spin', 'slot_stop', 'roulette_stop', 'toy_click', 'law_drop', 'augment_show', 'augment_pick', 'trap_set'],
    -25.0: ['good', 'bad', 'charge', 'dash', 'launch', 'rocket', 'shot', 'warp', 'promote', 'law', 'toy_party_pop'],
    -21.0: ['slam', 'thud', 'trap', 'game_start', 'win'],
}
TARGET = {event: level for level, events in CLASSES.items() for event in events}
LOUDNESS_TOLERANCE_DB = 4.0
PEAK_LIMIT = 0.9
MAX_SECONDS = {'promote': 0.95}  # 1.75초 차임은 승급마다 너무 길다


def decode(path, start=0.0):
    args = [FFMPEG, '-v', 'error']
    if start > 0:
        args += ['-ss', str(start)]
    args += ['-i', str(path), '-af', 'highpass=f=65,lowpass=f=10500', '-ac', '1', '-ar', str(RATE), '-f', 'f32le', '-']
    return np.frombuffer(subprocess.check_output(args), dtype='<f4').copy()


def encode(x, path):
    subprocess.run([FFMPEG, '-v', 'error', '-y', '-f', 'f32le', '-ar', str(RATE), '-ac', '1', '-i', '-', '-c:a', 'libvorbis', '-q:a', '5', str(path)],
                   input=x.astype('<f4').tobytes(), check=True)


def rms_db(x):
    return 20 * np.log10(float(np.sqrt(np.mean(x ** 2))) + 1e-9)


def to_level(x, level):
    x = x * (10 ** ((level - rms_db(x)) / 20))
    peak = float(abs(x).max())
    return x * (PEAK_LIMIT / peak) if peak > PEAK_LIMIT else x


def shape(x, cap):
    active = np.flatnonzero(abs(x) > abs(x).max() * .012)
    if len(active):
        x = x[max(0, int(active[0]) - 88):min(len(x), int(active[-1]) + 441)]
    x = x[:int(cap * RATE)].copy()
    fade = min(int(.04 * RATE), len(x) // 4)
    x[:22] *= np.linspace(0, 1, 22)
    x[-fade:] *= np.linspace(1, 0, fade)
    return x


records = json.loads((OUT / 'manifest.json').read_text(encoding='utf-8'))
order = []
for record in records:
    if record['event'] not in order:
        order.append(record['event'])
for record in [r for r in records if r['event'] in REPLACE]:
    (OUT / record['file']).unlink(missing_ok=True)
    (OUT / (record['file'] + '.import')).unlink(missing_ok=True)
records = [r for r in records if r['event'] not in REPLACE]

for event, name, start, cap, speed in RECIPES:
    source = SOURCE / name
    x = decode(source, start)
    if speed != 1:
        x = np.interp(np.arange(0, len(x), speed), np.arange(len(x)), x).astype('f4')
    x = to_level(shape(x, cap), TARGET[event])
    variant = 1 + sum(1 for r in records if r['event'] == event)
    output = OUT / f'{event}_{variant:02}.ogg'
    encode(x, output)
    pack = name.split('/')[0]
    records.append(dict(event=event, file=output.name, source=name, author='Kenney', url=PACKS[pack], license='CC0-1.0',
                        source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(), sha256=hashlib.sha256(output.read_bytes()).hexdigest(),
                        seconds=round(len(x) / RATE, 4), target_rms_db=TARGET[event], speed=speed, trim_start=start, fade_out_ms=40))
    if event not in order:
        order.append(event)

for record in records:
    path = OUT / record['file']
    x = decode(path)
    changed = False
    cap = MAX_SECONDS.get(record['event'])
    if cap and len(x) > cap * RATE:
        x = shape(x, cap)
        changed = True
    level = TARGET.get(record['event'])
    if level is not None and (changed or abs(rms_db(x) - level) > LOUDNESS_TOLERANCE_DB):
        x = to_level(x, level)
        changed = True
    if changed:
        encode(x, path)
        record.update(sha256=hashlib.sha256(path.read_bytes()).hexdigest(), seconds=round(len(x) / RATE, 4), target_rms_db=level)

records.sort(key=lambda r: (order.index(r['event']), r['file']))
(OUT / 'manifest.json').write_text(json.dumps(records, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
catalog = 'extends RefCounted\n## Generated by tools/audio/curate_sfx.py and retuned by tools/audio/retune_sfx.py; sources in manifest.json.\nconst FILES: Dictionary = {\n'
for event in order:
    paths = ['res://assets/sfx/curated/' + r['file'] for r in records if r['event'] == event]
    catalog += '\t&' + json.dumps(event) + ': ' + json.dumps(paths) + ',\n'
(OUT / 'catalog.gd').write_text(catalog + '}\n', encoding='utf-8')
print(f'Retuned {len(records)} clips for {len(order)} events')
