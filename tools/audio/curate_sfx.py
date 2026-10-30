"""Rebuild CC0 effects: python curate_sfx.py <downloaded source folder> <ffmpeg>.

Source downloads stay outside the repository. Every derivative records its source,
processing and hashes in assets/sfx/curated/manifest.json.
"""
from pathlib import Path
import hashlib, json, subprocess, sys
import numpy as np

SOURCE=Path(sys.argv[1]).resolve()
FFMPEG=sys.argv[2]
OUT=Path(__file__).resolve().parents[2]/'assets/sfx/curated'
OUT.mkdir(parents=True,exist_ok=True)
SOURCES={
 'kenney_ui':('Kenney','https://kenney.nl/assets/ui-audio'),
 'kenney_casino':('Kenney','https://kenney.nl/assets/casino-audio'),
 'kenney_impact':('Kenney','https://kenney.nl/assets/impact-sounds'),
 'kenney_jingles':('Kenney','https://kenney.nl/assets/music-jingles'),
 'robin_ui':('Robin Lamb','https://opengameart.org/content/ui-sound-effects-button-clicks-user-feedback-notifications'),
 'rubberduck_materials':('rubberduck','https://opengameart.org/content/100-cc0-metal-and-wood-sfx'),
 'bicycle-horn-1.wav':('AntumDeluge','https://opengameart.org/content/bicycle-horn'),
}
# event, source, peak target (linear), max duration, speed multiplier.
# Mahjong uses a short casino chip strike, not an alleged mahjong field recording.
RECIPES=[
 ('ui_click','kenney_ui/Audio/click5.ogg',.23,.07,1),
 ('ui_hover','kenney_ui/Audio/rollover1.ogg',.09,.11,1.12),
 ('hop','kenney_casino/Audio/chip-lay-1.ogg',.32,.13,.85),
 ('hop','kenney_casino/Audio/chip-lay-2.ogg',.32,.13,.85),
 ('slam','kenney_impact/Audio/impactSoft_medium_000.ogg',.60,.22,.85),
 ('thud','kenney_impact/Audio/impactWood_medium_000.ogg',.38,.20,.78),
 ('dice_roll','kenney_casino/Audio/dice-throw-1.ogg',.46,.60,1),
 ('dice_roll','kenney_casino/Audio/dice-throw-2.ogg',.46,.60,1),
 ('roll_other','kenney_casino/Audio/card-fan-1.ogg',.32,.60,1.15),
 ('card_pick','kenney_casino/Audio/card-slide-1.ogg',.28,.21,1),
 ('card_throw','kenney_casino/Audio/card-shove-1.ogg',.35,.28,1),
 ('card_get','kenney_casino/Audio/card-place-1.ogg',.30,.25,1),
 ('card_impact','kenney_casino/Audio/card-place-4.ogg',.45,.25,.85),
 ('mahjong_tap','kenney_casino/Audio/chips-collide-2.ogg',.58,.12,.78),
 ('mahjong_tap','kenney_casino/Audio/chips-collide-4.ogg',.58,.12,.78),
 ('yut_clack','rubberduck_materials/wood_hit_01.ogg',.48,.18,1),
 ('yut_clack','rubberduck_materials/wood_hit_02.ogg',.48,.18,1),
 ('yut_clack','rubberduck_materials/wood_hit_03.ogg',.48,.18,1),
 ('yut_toss','kenney_casino/Audio/card-fan-1.ogg',.24,.30,.80),
 ('toy_click','kenney_ui/Audio/switch2.ogg',.40,.13,.87),
 ('toy_party_pop','bicycle-horn-1.wav',.56,.90,1.08),
 ('slot_spin','rubberduck_materials/metal_spring_01.ogg',.45,.14,.80),
 ('slot_stop','kenney_ui/Audio/switch1.ogg',.46,.14,.78),
 ('roulette_tick','kenney_ui/Audio/click4.ogg',.28,.025,1),
 ('roulette_stop','kenney_ui/Audio/switch3.ogg',.40,.15,.80),
 ('augment_show','kenney_casino/Audio/card-fan-2.ogg',.36,.65,1),
 ('augment_pick','robin_ui/ui_wav/Ding.wav',.42,.55,1.15),
 ('law','rubberduck_materials/wood_hit_03.ogg',.56,.27,.72),
 ('law_drop','kenney_casino/Audio/card-slide-3.ogg',.32,.30,.80),
 ('promote','robin_ui/ui_wav/chimes.wav',.45,1.75,1),
 ('charge','rubberduck_materials/metal_spring_01.ogg',.24,.38,.90),
 ('dash','kenney_casino/Audio/card-shove-2.ogg',.36,.23,1.2),
 ('launch','kenney_casino/Audio/card-slide-4.ogg',.34,.30,.85),
 ('shot','rubberduck_materials/metal_spring_01.ogg',.42,.24,1.25),
 ('good','robin_ui/ui_wav/Ding.wav',.42,.65,1),
 ('bad','robin_ui/ui_wav/negative_sound.wav',.42,1.05,1),
 ('game_start','kenney_jingles/Audio/Pizzicato jingles/jingles_PIZZI00.ogg',.46,.60,1),
 ('win','kenney_jingles/Audio/Pizzicato jingles/jingles_PIZZI01.ogg',.52,1.20,1),
 ('trap','robin_ui/ui_wav/alarm.wav',.38,.46,.88),
]
records=[]; files={}; preview=[]
for event,name,peak,cap,speed in RECIPES:
 source=SOURCE/name
 filters=f'highpass=f=65,lowpass=f={6500 if event in ["ui_click","ui_hover","hop","roulette_tick"] else 10500}'
 raw=subprocess.check_output([FFMPEG,'-v','error','-i',str(source),'-af',filters,'-ac','1','-ar','44100','-f','f32le','-'])
 x=np.frombuffer(raw,dtype='<f4').copy()
 # Preserve the attack while removing empty lead-in / long recording tails.
 active=np.flatnonzero(abs(x)>abs(x).max()*.012)
 start=max(0,int(active[0])-88); end=min(len(x),int(active[-1])+441)
 x=x[start:end]
 if speed!=1:x=np.interp(np.arange(0,len(x),speed),np.arange(len(x)),x).astype('f4')
 x=x[:int(cap*44100)]
 x*=peak/max(float(abs(x).max()),1e-6)
 fade=min(220,len(x)//4); x[:22]*=np.linspace(0,1,22); x[-fade:]*=np.linspace(1,0,fade)
 variant=len(files.setdefault(event,[]))+1
 output=OUT/f'{event}_{variant:02}.ogg'
 subprocess.run([FFMPEG,'-v','error','-y','-f','f32le','-ar','44100','-ac','1','-i','-','-c:a','libvorbis','-q:a','5',str(output)],input=x.astype('<f4').tobytes(),check=True)
 files[event].append('res://assets/sfx/curated/'+output.name)
 pack=name.split('/')[0];author,url=SOURCES[pack]
 records.append(dict(event=event,file=output.name,source=name,author=author,url=url,license='CC0-1.0',source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),sha256=hashlib.sha256(output.read_bytes()).hexdigest(),seconds=round(len(x)/44100,4),target_peak=peak,speed=speed,filters=filters,trim_start=round(start/44100,4),fade_out_ms=5))
 preview.extend([x,np.zeros(11025,dtype='f4')])
(OUT/'manifest.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
catalog='extends RefCounted\n## Generated by tools/audio/curate_sfx.py; sources in manifest.json.\nconst FILES: Dictionary = {\n'
for event,paths in files.items():catalog+='\t&'+json.dumps(event)+': '+json.dumps(paths)+',\n'
(OUT/'catalog.gd').write_text(catalog+'}\n',encoding='utf-8')
# Audition montage follows manifest order; intentionally outside runtime assets.
preview_path=OUT.parents[2]/'build/sfx_refresh_preview.ogg'
preview_path.parent.mkdir(exist_ok=True)
subprocess.run([FFMPEG,'-v','error','-y','-f','f32le','-ar','44100','-ac','1','-i','-','-c:a','libvorbis','-q:a','5',str(preview_path)],input=np.concatenate(preview).astype('<f4').tobytes(),check=True)
print(f'Curated {len(records)} clips for {len(files)} events; {sum(p.stat().st_size for p in OUT.glob("*.ogg"))} bytes')
