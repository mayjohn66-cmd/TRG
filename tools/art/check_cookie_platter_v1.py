import bpy,sys,json,hashlib,math
from pathlib import Path
repo,out=map(Path,sys.argv[sys.argv.index('--')+1:])
source=repo/'art_source/selection_props/cookie_platter_v1.blend'
digest=hashlib.sha256(source.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(source))
cookies=[o for o in bpy.data.objects if o.name.startswith('PickCookie_')]
assert len(cookies)==16
assert len({o.data.as_pointer() for o in cookies})==1
assert not any(o.name.startswith('Temporary pour guide') for o in bpy.data.objects)
assert bpy.data.objects['CeramicPlate'].type=='MESH'
for o in [*cookies,bpy.data.objects['CeramicPlate']]:
    assert o.data.uv_layers and o.data.materials
    assert all(math.isfinite(v) for row in o.matrix_world for v in row)
assert hashlib.sha256(source.read_bytes()).hexdigest()==digest
report=json.loads((out/'model-report.json').read_text(encoding='utf-8'))
report['saved_readback']=True;report['source_blend_sha256']=digest
(out/'model-report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('COOKIE_PLATTER_READBACK_OK: 16 instances, 1 shared mesh')
