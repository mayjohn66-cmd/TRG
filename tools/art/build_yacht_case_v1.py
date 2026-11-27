"""Blender CLI: new low-poly case source, GLB and dimensional validation report."""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/models/yacht_case/v1'
SRC = ROOT / 'art_source/models/yacht_case/v1'
OUT.mkdir(parents=True, exist_ok=True)
SRC.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def material(name, color, roughness=.65, metallic=0):
    color=tuple(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in color)
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bs = mat.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Roughness'].default_value = roughness
    bs.inputs['Metallic'].default_value = metallic
    return mat

shell = material('Charcoal molded case', (.13, .15, .16), .55)
edge = material('Soft leather edge', (.19, .22, .23), .78)
felt = material('Green felt', (.08, .30, .16), .95)
well = material('Recess lining', (.04, .055, .045), 1)
metal = material('Brushed brass fittings', (.70, .60, .35), .4, .6)
cupmat = material('Cup leather', (.25, .12, .075), .8)
red = material('Cup burgundy lining', (.42, .12, .10), 1)

def xy(px, py, z=0): return ((px-390)/42, (176-py)/42, z)
def box(name, px, py, width, height, depth, z, mat, bevel=.07):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xy(px, py, z))
    ob = bpy.context.object
    ob.name = name
    ob.dimensions = (width/42, height/42, depth)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.data.materials.append(mat)
    mod = ob.modifiers.new('Rounded manufacture edge', 'BEVEL')
    mod.width = bevel
    mod.segments = 2
    bpy.ops.object.modifier_apply(modifier=mod.name)
    ob.modifiers.new('Weighted corner normals', 'WEIGHTED_NORMAL')
    return ob

box('Case underside',320,168,640,336,.62,-.58,shell,.18)
box('Felt playing surface',320,234,596,180,.10,-.20,felt,.10)
for x in (10,630): box('Side padded rail',x,168,20,336,.5,-.04,edge,.12)
for y in (10,326): box('End padded rail',320,y,620,20,.5,-.04,edge,.12)
box('Five well shelf',320,64,600,100,.20,-.35,shell,.08)
box('Recess divider rail',320,140,608,12,.36,-.01,edge,.08)
for i in range(5):
    x = 100+i*110
    box(f'Well {i+1} floor',x,90,78,78,.10,-.25,well,.10)
    for dx in (-44,44): box(f'Well {i+1} wall',x+dx,90,10,94,.32,-.04,edge,.07)
    for dy in (-44,44): box(f'Well {i+1} lip',x,90+dy,80,10,.32,-.04,edge,.07)
for x in (62,578):
    box('Brass hinge',x,7,44,12,.15,.21,metal,.04)
    box('Latch',x,328,24,15,.17,.22,metal,.04)

# Hollow tapered cup: actual inner/outer surfaces and thick rolled lip.
center = Vector(xy(668,232,.50))
orientation = Vector((.24,-.22,.946)).normalized().to_track_quat('Z','Y')
verts=[]
faces=[]
rings=[(1.13,-2.3),(1.62,0),(1.43,.04),(.97,-2.08)]
N=24
for radius,z in rings:
    for i in range(N):
        t=i*math.tau/N
        verts.append(center+orientation@Vector((radius*math.cos(t),radius*math.sin(t),z)))
for ring in range(3):
    for i in range(N):
        j=(i+1)%N
        faces.append((ring*N+i,ring*N+j,(ring+1)*N+j,(ring+1)*N+i))
faces.append(tuple(reversed(range(N))))
faces.append(tuple(range(3*N,4*N)))
mesh=bpy.data.meshes.new('Hollow tapered cup geometry')
mesh.from_pydata(verts,[],faces)
mesh.update()
cup=bpy.data.objects.new('Hollow dice cup',mesh)
bpy.context.collection.objects.link(cup)
for mat in (cupmat,metal,red): mesh.materials.append(mat)
for poly in mesh.polygons:
    poly.material_index=0 if poly.index<N else (1 if poly.index<2*N else 2)
    poly.use_smooth=poly.index<3*N

objects=[ob for ob in bpy.context.scene.objects if ob.type=='MESH']
for ob in objects:
    bpy.context.view_layer.objects.active=ob
    for mod in list(ob.modifiers): bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.ops.object.select_all(action='DESELECT')
for ob in objects: ob.select_set(True)
bpy.context.view_layer.objects.active=objects[0]
bpy.ops.object.join()
asset=bpy.context.object
asset.name='YachtCaseWithHollowCup'
asset.data.calc_loop_triangles()
report={'blender':bpy.app.version_string,'triangles':len(asset.data.loop_triangles),
        'vertices':len(asset.data.vertices),'materials':len(asset.data.materials),
        'case_pixels':[640,336],'viewport_pixels':[780,352],
        'well_centers':[[100+110*i,90] for i in range(5)],'cup_center':[668,232]}
assert report['triangles'] < 6000
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'yacht-case-v1.blend'),compress=True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'yacht-case-v1.glb'),use_selection=True,
                         export_format='GLB',export_yup=True,export_animations=False)
report['glb_bytes']=(OUT/'yacht-case-v1.glb').stat().st_size
assert report['glb_bytes'] < 250_000
report['glb_sha256']=hashlib.sha256((OUT/'yacht-case-v1.glb').read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(SRC/'yacht-case-v1.blend'))
readback=bpy.data.objects['YachtCaseWithHollowCup']
readback.data.calc_loop_triangles()
assert len(readback.data.loop_triangles)==report['triangles']
assert len(readback.data.vertices)==report['vertices']
report['saved_readback']=True
(SRC/'report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('YACHT_CASE_VALIDATED',json.dumps(report))
