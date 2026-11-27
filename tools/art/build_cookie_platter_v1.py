"""A lightweight plate and a settled cookie heap sharing the approved cookie asset.

Only the plate is exported to GLB. The runtime pile is a small Godot scene
instancing the existing cookie PackedScene, so no cookie mesh/texture is copied.
"""
import bpy, math, random, sys, json, hashlib
from pathlib import Path
from mathutils import Vector, Matrix

REPO, OUT=map(Path,sys.argv[sys.argv.index('--')+1:])
ASSETS=REPO/'assets/models/fortune_cookie/platter_v1'
SOURCE=REPO/'art_source/selection_props'
COOKIE=REPO/'assets/models/fortune_cookie/fortune-cookie-whole.glb'
for directory in (ASSETS,SOURCE,OUT): directory.mkdir(parents=True,exist_ok=True)
original_hash=hashlib.sha256(COOKIE.read_bytes()).hexdigest()
bpy.ops.wm.read_factory_settings(use_empty=True)
random.seed(17421)

def linear(h):
    cs=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in cs)+(1,)
def material(name,color,rough=.4,metal=0):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=linear(color)
    p=m.node_tree.nodes['Principled BSDF']
    p.inputs['Base Color'].default_value=m.diffuse_color
    p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    return m

ivory=material('Ivory glazed ceramic','f6f0dc',.31)
rim=material('Quiet warm rim','d9bd86',.4,.18)
# A single closed revolved dish, including its shallow bowl and foot.
profile=[(0,.105),(.85,.105),(1.30,.115),(1.58,.15),(1.80,.22),
         (2.00,.30),(2.12,.315),(2.18,.28),(2.17,.225),(1.98,.205),
         (1.76,.145),(1.48,.075),(1.12,.045),(1.08,.015),(.98,.015),(.94,.045),(0,.055)]
n=64;verts=[];rings=[];faces=[];slots=[]
for r,z in profile:
    if r==0:
        rings.append([len(verts)]);verts.append((0,0,z))
    else:
        rings.append(list(range(len(verts),len(verts)+n)))
        verts.extend((r*math.cos(i*math.tau/n),r*math.sin(i*math.tau/n),z) for i in range(n))
for k in range(len(rings)-1):
    a,b=rings[k:k+2]
    for i in range(n):
        j=(i+1)%n
        if len(a)==1: face=(a[0],b[i],b[j])
        elif len(b)==1: face=(a[i],b[0],a[j])
        else: face=(a[i],b[i],b[j],a[j])
        faces.append(face);slots.append(1 if k in [5,6] else 0)
# Join the two center vertices, closing the central axis without degenerate faces.
data=bpy.data.meshes.new('Shallow ceramic plate mesh');data.from_pydata(verts,[],faces);data.update()
assert not data.validate()
plate=bpy.data.objects.new('CeramicPlate',data);bpy.context.collection.objects.link(plate)
data.materials.append(ivory);data.materials.append(rim)
uv=data.uv_layers.new(name='UVMap')
for p,slot in zip(data.polygons,slots):
    p.use_smooth=True;p.material_index=slot
    for li in p.loop_indices:
        v=data.vertices[data.loops[li].vertex_index].co
        uv.data[li].uv=(v.x/4.4+.5,v.y/4.4+.5)

def rigid(obj,kind,shape):
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    bpy.ops.rigidbody.object_add()
    obj.rigid_body.type=kind;obj.rigid_body.collision_shape=shape
    obj.rigid_body.use_margin=True;obj.rigid_body.collision_margin=.004
    obj.rigid_body.friction=.85;obj.rigid_body.restitution=.02

rigid(plate,'PASSIVE','MESH')
# Temporary open-sided pouring guide keeps the simulated cookies on the dish.
# It is removed before saving/exporting and never becomes part of the asset.
guide_verts=[]
for r,z in [(1.98,.2),(1.98,3.5),(1.94,3.5),(1.94,.2)]:
    guide_verts.extend((r*math.cos(i*math.tau/n),r*math.sin(i*math.tau/n),z) for i in range(n))
guide_faces=[]
for k in range(4):
    for i in range(n):guide_faces.append((k*n+i,k*n+(i+1)%n,((k+1)%4)*n+(i+1)%n,((k+1)%4)*n+i))
gm=bpy.data.meshes.new('Temporary pour guide');gm.from_pydata(guide_verts,[],guide_faces);gm.update()
guide=bpy.data.objects.new('Temporary pour guide',gm);bpy.context.collection.objects.link(guide)
guide.hide_render=True;rigid(guide,'PASSIVE','MESH')
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(COOKIE))
imported=[o for o in bpy.data.objects if o not in before]
meshes=[o for o in imported if o.type=='MESH']
bpy.ops.object.select_all(action='DESELECT')
for o in meshes:o.select_set(True)
bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join()
cookie=bpy.context.object
bpy.context.view_layer.update()
for v in cookie.data.vertices:v.co=cookie.matrix_world@v.co
cookie.matrix_world=Matrix.Identity(4)
lo=Vector(tuple(min(v.co[i] for v in cookie.data.vertices) for i in range(3)))
hi=Vector(tuple(max(v.co[i] for v in cookie.data.vertices) for i in range(3)))
normalizer=Matrix.Scale(1.05/max(hi.x-lo.x,hi.y-lo.y),4)@Matrix.Translation(Vector((-(lo.x+hi.x)/2,-(lo.y+hi.y)/2,-lo.z)))
for v in cookie.data.vertices:v.co=normalizer@v.co
cookie.data.update()
cookie.name='PickCookie_01'
for obj in list(bpy.data.objects):
    if obj not in before and obj!=cookie: bpy.data.objects.remove(obj,do_unlink=True)

cookies=[cookie]
for i in range(1,16):
    o=cookie.copy();o.data=cookie.data;o.name=f'PickCookie_{i+1:02d}'
    bpy.context.collection.objects.link(o);cookies.append(o)
for i,o in enumerate(cookies):
    angle=random.uniform(0,math.tau);radius=random.uniform(.15,1.10)
    o.location=(radius*math.cos(angle),radius*math.sin(angle),.9+i*.76)
    o.rotation_euler=(random.uniform(-.9,.9),random.uniform(-.65,.65),random.uniform(0,math.tau))
    rigid(o,'ACTIVE','CONVEX_HULL')
    o.rigid_body.mass=.04;o.rigid_body.linear_damping=.45;o.rigid_body.angular_damping=.55
scene=bpy.context.scene
scene.render.fps=60;scene.frame_start=1;scene.frame_end=420
scene.rigidbody_world.substeps_per_frame=8;scene.rigidbody_world.solver_iterations=24
scene.rigidbody_world.point_cache.frame_end=420
for frame in range(1,421): scene.frame_set(frame)
dg=bpy.context.evaluated_depsgraph_get()
poses=[o.evaluated_get(dg).matrix_world.copy() for o in cookies]
for o,pose in zip(cookies,poses):
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
    bpy.ops.rigidbody.object_remove()
    o.matrix_world=pose
bpy.ops.object.select_all(action='DESELECT');plate.select_set(True);bpy.context.view_layer.objects.active=plate;bpy.ops.rigidbody.object_remove()
bpy.data.objects.remove(guide,do_unlink=True)
scene.frame_set(1)
for o,pose in zip(cookies,poses):o.matrix_world=pose
bpy.context.view_layer.update()
assert all(o.matrix_world.translation.xy.length<2.1 for o in cookies),'Cookie spilled outside plate: '+str([tuple(o.location) for o in cookies])
assert len({o.data.as_pointer() for o in cookies})==1

# Export only the new plate. Cookies in the game reference the approved GLB.
bpy.ops.object.select_all(action='DESELECT');plate.select_set(True);bpy.context.view_layer.objects.active=plate
plate_source=SOURCE/'cookie_platter_v1'
plate_source.mkdir(parents=True,exist_ok=True)
plate_path=plate_source/'ceramic_plate.glb'
bpy.ops.export_scene.gltf(filepath=str(plate_path),export_format='GLB',use_selection=True,export_apply=True,export_animations=False)
convert=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
lines=['[gd_scene load_steps=3 format=3]','',
    '[ext_resource type="PackedScene" path="res://assets/models/fortune_cookie/platter_v1/plate_runtime.scn" id="1_plate"]',
    '[ext_resource type="PackedScene" path="res://assets/models/fortune_cookie/fortune-cookie-whole.glb" id="2_cookie"]','',
    '[node name="FortuneCookiePlatter" type="Node3D"]','',
    '[node name="Plate" parent="." instance=ExtResource("1_plate")]']
transforms=[]
for i,pose in enumerate(poses):
    t=convert.inverted()@pose@normalizer@convert
    values=[t[row][col] for col in range(3) for row in range(3)]+[t[row][3] for row in range(3)]
    transforms.append(values)
    lines.extend(['',f'[node name="PickCookie_{i+1:02d}" parent="." instance=ExtResource("2_cookie")]',
                  'transform = Transform3D('+', '.join(f'{v:.8f}' for v in values)+')'])
scene_path=ASSETS/'cookie_platter_heaped.tscn';scene_path.write_text('\n'.join(lines)+'\n',encoding='utf-8')

# Transparent preview from the saved, physically settled asset.
scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=True
scene.render.resolution_x=1100;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=True
scene.view_settings.view_transform='AgX'
world=bpy.data.worlds.new('Warm soft studio');world.use_nodes=True
world.node_tree.nodes['Background'].inputs[1].default_value=.45;scene.world=world
for name,loc,energy,size in [('Key',(-4,-5,7),650,5),('Fill',(5,-2,5),400,4),('Rim',(0,5,7),550,4)]:
    lamp=bpy.data.lights.new(name,'AREA');lamp.energy=energy;lamp.shape='DISK';lamp.size=size
    obj=bpy.data.objects.new(name,lamp);bpy.context.collection.objects.link(obj);obj.location=loc
    obj.rotation_euler=(Vector((0,0,.5))-obj.location).to_track_quat('-Z','Y').to_euler()
camera_data=bpy.data.cameras.new('PlatterCamera');camera_data.type='ORTHO';camera_data.ortho_scale=6.0
camera=bpy.data.objects.new('PlatterCamera',camera_data);bpy.context.collection.objects.link(camera)
target=Vector((0,0,.55));camera.location=Vector((4,-6,6));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
scene.render.filepath=str(OUT/'cookie-platter-heaped.png');bpy.ops.render.render(write_still=True)
for o in cookies:o.hide_render=True
scene.render.filepath=str(OUT/'ceramic-plate-empty.png');bpy.ops.render.render(write_still=True)
for o in cookies:o.hide_render=False
bpy.ops.file.pack_all();bpy.context.preferences.filepaths.save_version=0
blend_path=SOURCE/'cookie_platter_v1.blend';bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
assert hashlib.sha256(COOKIE.read_bytes()).hexdigest()==original_hash
report={'blender':bpy.app.version_string,'source_preserved':True,'source_cookie_sha256':original_hash,
    'cookie_count':len(cookies),'unique_cookie_meshes':1,'settled_frames':420,
    'plate_triangles':sum(len(p.vertices)-2 for p in plate.data.polygons),
    'plate_bytes':plate_path.stat().st_size,'scene_bytes':scene_path.stat().st_size,
    'total_new_runtime_bytes':plate_path.stat().st_size+scene_path.stat().st_size,
    'cookie_transforms_godot':transforms,'source_blend':str(blend_path)}
(OUT/'model-report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('COOKIE_PLATTER_OK',report['total_new_runtime_bytes'])
