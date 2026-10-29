"""Check the deployable wallpaper and binding without running the game suite."""
from pathlib import Path
import hashlib,json,struct,zlib

root=Path(__file__).resolve().parents[1]
picture=root/'web/letterbox-pattern.png'
metadata=root/'web/letterbox-pattern.source.json'
data=picture.read_bytes()
assert data[:8]==b'\x89PNG\r\n\x1a\n','letterbox pattern must be a PNG'
width,height,depth,kind=struct.unpack('>IIBB',data[16:26])
assert (width,height,depth,kind)==(1536,1536,8,6),'expected 2x RGBA wallpaper'
assert 1024<len(data)<512*1024,'unexpected wallpaper size'
source=json.loads(metadata.read_text(encoding='utf8'))
assert hashlib.sha256(data).hexdigest()==source['sha256'],'wallpaper differs from manifest'
assert source['css_size']==[768,768] and source['ink']=='#174d39'
keys={'skull','paw','flame','sun','star','crescent','butterfly','wing'}
assert {item['key'] for item in source['motifs']}==keys
assert len(source['placements'])==36
assert all(sum(x['key']==key for x in source['placements'])>=4 for key in keys)
offset=8;packed=bytearray()
while offset<len(data):
    length=struct.unpack('>I',data[offset:offset+4])[0]
    if data[offset+4:offset+8]==b'IDAT':packed.extend(data[offset+8:offset+8+length])
    offset+=length+12
assert len(zlib.decompress(packed))==height*(1+width*4),'truncated image data'
shell=(root/'web/shell.html').read_text(encoding='utf8')
assert "pattern.src = 'letterbox-pattern.png?v=__TRG_BUILD_ID__'" in shell
assert 'background-size: 768px 768px' in shell
workflow=(root/'.github/workflows/deploy-web.yml').read_text(encoding='utf8')
assert 'cp web/letterbox-pattern.png build/web/letterbox-pattern.png' in workflow
assert 'if [ -f web/letterbox-pattern.png ]' not in workflow,'export must fail if the wallpaper is missing'
print('LETTERBOX_PATTERN_OK 8 motifs / 36 placements / deploy asset bound')
