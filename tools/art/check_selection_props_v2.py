"""Read saved Blender source back, inspect GLB exports, render three-flavor lineup."""
import bpy, sys, math, json, hashlib
from pathlib import Path
from mathutils import Vector

REPO, PREVIEW=map(Path,sys.argv[sys.argv.index('--')+1:])
source=REPO/'art_source/selection_props/selection_props_v2.blend'
fingerprint=hashlib.sha256(source.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(source))
assert bpy.app.version[:2]==(5,2)
required=['CookieTin_Open','CookieTin_Filled','CookieLidPivot','Icebox_Open','Icebox_Stocked','IceboxLidPivot','IceChunks']
for name in required: assert name in bpy.data.objects,name
assert len([o for o in bpy.data.objects if o.name.startswith('PickCookie_')])==5
assert len([o for o in bpy.data.objects if o.name.startswith('PickWrapped_')])==12
assert len([o for o in bpy.data.objects if o.name.startswith('Ice_')])==40
issues=[]; mesh_count=0
for o in bpy.data.objects:
    if o.type!='MESH': continue
    mesh_count+=1
    if not o.data.materials: issues.append(o.name+': missing material')
    for v in o.data.vertices:
        if not all(math.isfinite(c) for c in v.co): issues.append(o.name+': non-finite vertex')
    if not o.data.uv_layers: issues.append(o.name+': missing UV')
assert not issues,issues

scene=bpy.context.scene
camera=scene.camera
flavors=['strawberry_chocolate','chocolate','mint_chocolate']
for kind,label in [('IceCream_','icecream-three-flavors'),('Wrapped_','wrapped-three-flavors')]:
    roots=[bpy.data.objects[kind+flavor] for flavor in flavors]
    visible=set()
    for index,root in enumerate(roots):
        root.location.x=(index-1)*1.1
        visible.update([root,*root.children_recursive])
    for o in bpy.data.objects:
        if o.type in ['MESH','CURVE']:
            o.hide_set(False)
            o.hide_render=o not in visible
    target=Vector((0,0,1.0))
    camera.location=Vector((2,-9,3.3))
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.ortho_scale=4.0
    scene.render.resolution_x=1500; scene.render.resolution_y=900
    scene.render.filepath=str(PREVIEW/(label+'.png'))
    bpy.ops.render.render(write_still=True)
    for root in roots: root.location.x=0

assert hashlib.sha256(source.read_bytes()).hexdigest()==fingerprint
exports=[]
paths=list((REPO/'assets/models/selection_props/v2').glob('*.glb'))
paths+=list((REPO/'art_source/selection_props/archive_tin_v2').glob('*.glb'))
for path in sorted(paths):
    # Independently parse the GLB JSON chunk instead of trusting exporter logs.
    data=path.read_bytes(); assert data[:4]==b'glTF'
    length=int.from_bytes(data[12:16],'little')
    doc=json.loads(data[20:20+length])
    assert doc.get('meshes'),path.name
    exports.append({'file':path.name,'bytes':len(data),'nodes':len(doc['nodes']),'meshes':len(doc['meshes'])})
assert len(exports)==10
report={'saved_readback':True,'source_preserved':True,'blender':bpy.app.version_string,
        'source_sha256':fingerprint,'mesh_objects':mesh_count,'finite_geometry':True,
        'materials_and_uvs':True,'cookie_count':5,'wrapped_count':12,'ice_count':40,'exports':exports}
(PREVIEW/'validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('SELECTION_PROPS_READBACK_OK',len(exports))
