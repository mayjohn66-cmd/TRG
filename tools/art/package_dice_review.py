"""Add a complete catalog manifest, chapters and individual-clip archive to a capture."""
import csv
import html
import json
from pathlib import Path
import subprocess
import sys
import zipfile

folder, ffmpeg = Path(sys.argv[1]).resolve(), str(Path(sys.argv[2]).resolve())
repo = Path(__file__).resolve().parents[2]
with (repo / 'content_trickcal/data/dice_table.csv').open(encoding='utf-8-sig', newline='') as file:
    catalog = {r['id']: r['name'] for r in csv.DictReader(file) if r['enabled'].upper() == 'TRUE'}
clips = json.loads((folder / 'clips.json').read_text(encoding='utf-8'))
seen = {c['tool_id'] for c in clips}
assert seen == set(catalog), f'Catalog mismatch: missing={set(catalog)-seen}, extra={seen-set(catalog)}'
assert all(c['resolved_rolls'] > 0 for c in clips), 'A clip did not resolve a real gameplay roll'
assert all(c['end_frame'] > c['start_frame'] for c in clips)
titles = []
time_ms = 0
metadata = [';FFMETADATA1']
lines = ['# 1.3.1 전체 판정 도구 연출 검토', '', '현재 경량화 적용본 · 활성 도구 21종 · 아이스크림 3종 포함 23개 클립.',
         '실제 MainBoard에서 입력하고 엔진 결과를 공개한 녹화입니다. 효과음만 포함하며 배경음악과 보이스는 껐습니다.',
         '각 클립은 대표 결과를 보여 줍니다. 모든 무작위 결과와 당첨 조합을 전부 나열한 영상은 아닙니다.', '', '| 시작 | 종류 | 개별 영상 |', '|---|---|---|']
for clip in clips:
    title = catalog[clip['tool_id']]
    for flavor in ['strawberry', 'chocolate', 'mint']:
        if flavor in clip['name']: title += ' — ' + {'strawberry':'딸기','chocolate':'초코','mint':'민트'}[flavor]
    duration = round((clip['end_frame'] - clip['start_frame']) * 1000 / 30)
    stamp = f'{time_ms//60000:02}:{(time_ms//1000)%60:02}'
    lines.append(f'| {stamp} | {title} | [{clip["name"]}.mp4](videos/{clip["name"]}.mp4) |')
    metadata.extend(['[CHAPTER]', 'TIMEBASE=1/1000', f'START={time_ms}', f'END={time_ms+duration}', f'title={title}'])
    titles.append({'name':clip['name'], 'title':title, 'timestamp':stamp, 'start_ms':time_ms, 'duration_ms':duration})
    time_ms += duration
(folder/'README.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
(folder/'chapters.txt').write_text('\n'.join(metadata)+'\n',encoding='utf-8')
(folder/'review-index.json').write_text(json.dumps(titles,ensure_ascii=False,indent=2),encoding='utf-8')
subprocess.run([ffmpeg,'-hide_banner','-loglevel','error','-y','-i',str(folder/'videos/all-direct-tools.mp4'),'-i',str(folder/'chapters.txt'),'-map_metadata','1','-map_chapters','1','-c','copy','-movflags','+faststart',str(folder/'all-dice-review.mp4')],check=True)
options = ''.join(f'<option value="videos/{x["name"]}.mp4">{html.escape(x["title"])}</option>' for x in titles)
(folder/'review.html').write_text('''<!doctype html><html lang="ko"><meta charset="utf-8"><title>1.3.1 판정 도구 검토</title>
<style>body{margin:24px;background:#152b24;color:#fff;font:18px sans-serif}video{display:block;width:min(100%,1366px);margin-top:18px}select{padding:12px;font-size:18px;min-width:340px}a{color:#bfe890}</style>
<h1>1.3.1 판정 도구 연출 21종</h1><p>종류를 선택하면 해당 영상으로 바뀝니다. 효과음 포함.</p>
<select id="choice">'''+options+'''</select><video id="player" controls preload="metadata" src="videos/'''+titles[0]['name']+'''.mp4"></video>
<script>choice.onchange=()=>{player.src=choice.value;player.play()};</script><p><a href="all-dice-review.mp4">전체 모아보기</a> · <a href="README.md">순서와 타임코드</a></p></html>''',encoding='utf-8')
with zipfile.ZipFile(folder/'all-dice-individual-clips.zip','w',zipfile.ZIP_STORED) as archive:
    for clip in clips:
        path=folder/'videos'/(clip['name']+'.mp4');archive.write(path,'videos/'+path.name)
    for name in ['README.md','review.html','review-index.json']: archive.write(folder/name,name)
print(f'REVIEW_PACKAGE_OK {len(catalog)} tools; {len(clips)} clips; {time_ms/1000:.2f}s')
