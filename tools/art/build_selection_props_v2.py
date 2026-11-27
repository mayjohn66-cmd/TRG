"""Blender 5.2: editable selection props, GLB exports and transparent previews.

Run: blender -b --python tools/art/build_selection_props_v1.py -- REPO OUTPUT
The approved fortune-cookie input is imported read-only. No source is overwritten.
"""
import bpy
import math
import json
import random
import hashlib
import sys
from pathlib import Path
from mathutils import Vector

REPO, PREVIEW = map(Path, sys.argv[sys.argv.index("--")+1:])
OUT = REPO / "assets/models/selection_props/v2"
SOURCE = REPO / "art_source/selection_props"
for folder in (OUT, SOURCE, PREVIEW): folder.mkdir(parents=True, exist_ok=True)
COOKIE = REPO / "assets/models/fortune_cookie/fortune-cookie-whole.glb"
source_hash = hashlib.sha256(COOKIE.read_bytes()).hexdigest()
bpy.ops.wm.read_factory_settings(use_empty=True)
random.seed(9131)

def rgba(h, a=1):
    values=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in values)+(a,)

def mat(name, color, rough=.5, metal=0, alpha=1):
    m=bpy.data.materials.new(name); m.use_nodes=True
    m.diffuse_color=rgba(color,alpha)
    p=m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value=m.diffuse_color
    p.inputs["Roughness"].default_value=rough
    p.inputs["Metallic"].default_value=metal
    p.inputs["Specular IOR Level"].default_value=.32
    p.inputs["Alpha"].default_value=alpha
    if alpha<1: m.surface_render_method='DITHERED'
    return m

M={k:mat(k,*args) for k,args in {
    "Mint enamel":("8fc7af",.42,.1),"Deep mint seam":("477d66",.52,.05),
    "Brushed warm brass":("deb877",.34,.55),"Inner biscuit cream":("f2e5c9",.64,0),
    "Icebox blue":("82b4d5",.48,.03),"Icebox seam":("426e88",.55,0),
    "Ivory rim":("fff3d7",.48,0),"Mint hardware":("89c9b0",.44,0),
    "Steel hinge":("bec8c3",.3,.7),"Ice translucent":("b5e7f2",.2,.02,.52),
    "Ice facet":("e5f7fc",.24,0,.72),"Wood stick":("dfba83",.7,0),
    "Stick grain":("b78f5f",.74,0),"Strawberry cream":("ee9ea6",.65,0),
    "Cocoa cream":("a36d4e",.66,0),"Mint cream":("98d6ba",.62,0),
    "Chocolate coating":("653a2c",.4,0),"Dark chips":("4d3026",.55,0),
    "Pink wrapper":("ee9bac",.48,0),"Pink seal":("c65e7c",.5,0),
    "Cocoa wrapper":("af7b59",.48,0),"Cocoa seal":("704936",.5,0),
    "Mint wrapper":("86c6b3",.48,0),"Mint seal":("3f8d78",.5,0),
    "Milk white":("fff0d3",.56,0),"Leaf green":("56895c",.62,0),
}.items()}

def root(name):
    o=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(o); return o

def finish(o,name,material,parent,smooth=False):
    o.name=name; o.parent=parent
    if material: o.data.materials.append(material)
    if o.type=='MESH':
        for p in o.data.polygons: p.use_smooth=smooth
    return o

def bevel(o,width=.04,segments=3):
    b=o.modifiers.new("Molded edge bevel","BEVEL"); b.width=width; b.segments=segments
    b.affect='EDGES'
    bpy.context.view_layer.objects.active=o
    bpy.ops.object.modifier_apply(modifier=b.name)
    for poly in o.data.polygons: poly.use_smooth=True
    n=o.modifiers.new("Weighted face normals","WEIGHTED_NORMAL"); n.keep_sharp=True
    bpy.ops.object.modifier_apply(modifier=n.name)
    return o

def box(name,loc,size,material,parent,r=.04):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    o=bpy.context.object; o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    finish(o,name,material,parent)
    if r: bevel(o,r)
    return o

def cylinder(name,loc,radius,depth,material,parent):
    bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=radius,depth=depth,location=loc)
    o=finish(bpy.context.object,name,material,parent)
    bevel(o,min(.025,depth*.22),3)
    return o

def torus(name,loc,major,minor,material,parent):
    bpy.ops.mesh.primitive_torus_add(major_segments=80,minor_segments=10,location=loc,major_radius=major,minor_radius=minor)
    return finish(bpy.context.object,name,material,parent,True)

def mesh(name,verts,faces,material,parent,smooth=False):
    data=bpy.data.meshes.new(name); data.from_pydata(verts,[],faces); data.update()
    if data.validate(): raise RuntimeError("Invalid mesh: "+name)
    o=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(o)
    finish(o,name,material,parent,smooth)
    # Explicit UVs also make the saved source ready for subsequent texture baking.
    uv=data.uv_layers.new(name="UVMap")
    for poly in data.polygons:
        for li in poly.loop_indices:
            v=data.vertices[data.loops[li].vertex_index].co
            uv.data[li].uv=(v.x*.25+.5,v.z*.25+.5)
    return o

def lathe(name,profile,material,parent):
    n=96; verts=[]
    for radius,z in profile:
        verts.extend((radius*math.cos(j*2*math.pi/n),radius*math.sin(j*2*math.pi/n),z) for j in range(n))
    faces=[]
    for i in range(len(profile)):
        q=(i+1)%len(profile)
        for j in range(n): faces.append((i*n+j,i*n+(j+1)%n,q*n+(j+1)%n,q*n+j))
    return mesh(name,verts,faces,material,parent,True)

def line(name,points,material,parent,radius=.018):
    curve=bpy.data.curves.new(name,'CURVE'); curve.dimensions='3D'; curve.resolution_u=8
    curve.bevel_depth=radius; curve.bevel_resolution=3
    s=curve.splines.new('POLY'); s.points.add(len(points)-1)
    for p,co in zip(s.points,points): p.co=(*co,1)
    o=bpy.data.objects.new(name,curve); bpy.context.collection.objects.link(o)
    o.parent=parent; curve.materials.append(material)
    return o

def sphere(name,loc,scale,material,parent):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,location=loc)
    o=finish(bpy.context.object,name,material,parent,True); o.scale=scale
    return o

def rectangle(w,d,r,n=8):
    points=[]
    for cx,cy,start in [(w/2-r,d/2-r,0),(-w/2+r,d/2-r,90),(-w/2+r,-d/2+r,180),(w/2-r,-d/2+r,270)]:
        for i in range(n+1):
            a=math.radians(start+i*90/n)
            points.append((cx+r*math.cos(a),cy+r*math.sin(a)))
    return points

def rounded_ring(name,w,d,r,z0,z1,thickness,material,parent):
    loops=[(rectangle(w,d,r),z0),(rectangle(w,d,r),z1),
           (rectangle(w-2*thickness,d-2*thickness,max(.05,r-thickness)),z1),
           (rectangle(w-2*thickness,d-2*thickness,max(.05,r-thickness)),z0)]
    verts=[(x,y,z) for pts,z in loops for x,y in pts]; n=len(loops[0][0]); faces=[]
    for k in range(4):
        for j in range(n): faces.append((k*n+j,k*n+(j+1)%n,((k+1)%4)*n+(j+1)%n,((k+1)%4)*n+j))
    return bevel(mesh(name,verts,faces,material,parent),.022,2)

def duplicate_tree(source,name,parent=None):
    new=source.copy(); new.name=name; bpy.context.collection.objects.link(new); new.parent=parent
    for child in source.children: duplicate_tree(child,child.name,new)
    return new

def descendants(o): return [o,*o.children_recursive]

def world_bounds(objects):
    bpy.context.view_layer.update()
    pts=[o.matrix_world@Vector(corner) for o in objects if o.type=='MESH' for corner in o.bound_box]
    return Vector(tuple(min(p[i] for p in pts) for i in range(3))),Vector(tuple(max(p[i] for p in pts) for i in range(3)))

def make_tin():
    tin=root("CookieTin_Open")
    lathe("Enamel shell",[(1.73,.07),(1.77,.12),(1.77,.62),(1.74,.68),(1.65,.68),(1.63,.61),(1.63,.14),(1.73,.14)],M["Mint enamel"],tin)
    cylinder("Solid biscuit floor",(0,0,.12),1.65,.1,M["Inner biscuit cream"],tin)
    lathe("Cream inner liner",[(1.633,.17),(1.633,.61),(1.65,.65),(1.66,.64),(1.65,.16)],M["Inner biscuit cream"],tin)
    for z,r,minor in [(.67,1.70,.045),(.12,1.76,.027),(.25,1.779,.014),(.55,1.779,.014)]:
        torus("Rolled brass rim",(0,0,z),r,minor,M["Brushed warm brass"],tin)
    lid=root("CookieLidPivot"); lid.parent=tin; lid.location=(0,1.65,.67); lid.rotation_euler.x=math.radians(-112)
    cylinder("Mint lid shell",(0,-1.7,0),1.76,.105,M["Mint enamel"],lid)
    cylinder("Cream lid inner",(0,-1.7,-.064),1.63,.025,M["Inner biscuit cream"],lid)
    torus("Lid brass roll",(0,-1.7,-.055),1.70,.043,M["Brushed warm brass"],lid)
    line("Wheat stem",[(-.3,-2.22,-.09),(-.1,-1.8,-.09),(.28,-1.18,-.09)],M["Brushed warm brass"],lid,.023)
    for i in range(5):
        side=-1 if i%2 else 1
        leaf=sphere("Embossed wheat leaf",(-.18+i*.1+side*.14,-2.05+i*.17,-.095),(.12,.23,.035),M["Brushed warm brass"],lid)
        leaf.rotation_euler.z=side*.48
    for x in [-.63,.63]:
        hinge=cylinder("Lid hinge",(x,1.63,.66),.095,.34,M["Brushed warm brass"],tin)
        hinge.rotation_euler.y=math.pi/2
    return tin

tin=make_tin()
filled=duplicate_tree(tin,"CookieTin_Filled")
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(COOKIE))
imported=[o for o in bpy.data.objects if o not in before]
meshes=[o for o in imported if o.type=='MESH']
bpy.ops.object.select_all(action='DESELECT')
for o in meshes: o.select_set(True)
bpy.context.view_layer.objects.active=meshes[0]; bpy.ops.object.join()
cookie=bpy.context.object; cookie.name="Approved cookie reference"
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
lo,hi=world_bounds([cookie]); c=(lo+hi)/2
# Bake imported coordinate transform and normalize to the actual tin's scale.
for v in cookie.data.vertices: v.co=cookie.matrix_world@v.co
cookie.matrix_world.identity()
lo,hi=world_bounds([cookie]); factor=.95/max(hi.x-lo.x,hi.y-lo.y)
for v in cookie.data.vertices:
    v.co=(v.co-Vector(((hi.x+lo.x)/2,(hi.y+lo.y)/2,lo.z)))*factor
cookie.data.update()
for i,(x,y,a) in enumerate([(-.78,-.45,-.2),(.25,-.65,.35),(.85,.1,.7),(-.55,.55,-.4),(.3,.6,.2)]):
    o=cookie.copy(); o.name=f"PickCookie_{i+1:02d}"; bpy.context.collection.objects.link(o)
    o.parent=filled; o.location=(x,y,.2); o.rotation_euler.z=a
for o in list(bpy.data.objects):
    if o not in before and not o.name.startswith("PickCookie_"):
	    bpy.data.objects.remove(o,do_unlink=True)

def icebox():
    body=root("Icebox_Open")
    rounded_ring("Blue insulated shell",4.2,2.5,.3,.08,1.34,.17,M["Icebox blue"],body)
    box("Insulated base",(0,0,.14),(4.05,2.35,.22),M["Icebox blue"],body,.16)
    rounded_ring("Cream inner walls",3.87,2.17,.18,.24,1.32,.065,M["Ivory rim"],body)
    box("Cream inner floor",(0,0,.26),(3.73,2.03,.1),M["Ivory rim"],body,.12)
    rounded_ring("Thick cream rim",4.22,2.52,.31,1.27,1.43,.21,M["Ivory rim"],body)
    rounded_ring("Base seam",4.16,2.46,.28,.19,.24,.06,M["Icebox seam"],body)
    lid=root("IceboxLidPivot"); lid.parent=body; lid.location=(0,1.25,1.4); lid.rotation_euler.x=math.radians(-108)
    box("Rounded blue lid",(0,-1.25,0),(4.24,2.52,.20),M["Icebox blue"],lid,.14)
    box("Insulating lid liner",(0,-1.25,-.12),(3.91,2.19,.08),M["Ivory rim"],lid,.13)
    box("Recessed lid center",(0,-1.25,-.17),(3.62,1.90,.025),M["Inner biscuit cream"],lid,.12)
    for x in [-1.35,1.35]:
        hinge=cylinder("Cooler hinge",(x,1.25,1.37),.11,.4,M["Mint hardware"],body); hinge.rotation_euler.y=math.pi/2
    for x in [-2.12,2.12]:
        box("Handle bracket",(x,0,.94),(.09,.74,.4),M["Steel hinge"],body,.04)
        box("Carrying grip",(x*1.035,0,.95),(.14,.9,.18),M["Mint hardware"],body,.06)
    box("Front latch",(0,-1.3,1.28),(.34,.12,.37),M["Mint hardware"],body,.055)
    # Raised snowflake; graphic is actual geometry, not a baked drawing.
    for i in range(3):
        a=i*math.pi/3
        dx,dz=math.cos(a)*.31,math.sin(a)*.31
        line("Snowflake ray",[(-dx,-1.279,.73-dz),(dx,-1.279,.73+dz)],M["Ivory rim"],body,.025)
        for sign in [-1,1]:
            v=Vector((dx*sign,dz*sign)); tail=v*.62
            for turn in [-1,1]:
                wing=tail+Vector((-v.y,v.x))*turn*.20
                line("Snowflake branch",[(v.x,-1.279,.73+v.y),(wing.x,-1.279,.73+wing.y)],M["Ivory rim"],body,.019)
    return body

empty_box=icebox()

FLAVORS=[("strawberry_chocolate","Strawberry cream","Pink wrapper","Pink seal"),
         ("chocolate","Cocoa cream","Cocoa wrapper","Cocoa seal"),
         ("mint_chocolate","Mint cream","Mint wrapper","Mint seal")]

def wrapper(flavor,base,seal):
    pack=root("Wrapped_"+flavor)
    box("Sealed plastic pack",(0,0,.85),(.64,.24,1.54),M[base],pack,.09)
    for z in [.10,1.61]:
        box("Crimped end",(0,0,z),(.69,.11,.11),M[seal],pack,.013)
        for i in range(9):
            box("Heat seal ridge",(-.28+i*.07,-.061,z),(.014,.012,.075),M[base],pack,.004)
    box("Cream flavor label",(0,-.127,.90),(.46,.02,.54),M["Milk white"],pack,.06)
    for z in [.45,1.31]: box("Package band",(0,-.128,z),(.59,.015,.055),M[seal],pack,.008)
    if flavor=="strawberry_chocolate":
        fruit=sphere("Strawberry motif",(0,-.16,.89),(.13,.035,.16),M["Pink seal"],pack)
        for x in [-.06,.06]:
            leaf=sphere("Strawberry leaf",(x,-.17,1.04),(.08,.02,.04),M["Leaf green"],pack); leaf.rotation_euler.y=x*3
        for x,z in [(-.04,.9),(.05,.93),(0,.82)]: sphere("Seed",(x,-.197,z),(.009,.004,.017),M["Milk white"],pack)
    elif flavor=="chocolate":
        for x in [-.09,.09]:
            for z in [.81,1.0]: box("Cocoa square",(x,-.16,z),(.14,.04,.14),M["Chocolate coating"],pack,.015)
    else:
        for side in [-1,1]:
            leaf=sphere("Mint leaf",(side*.07,-.16,.92),(.1,.03,.17),M["Leaf green"],pack); leaf.rotation_euler.y=side*.5
        line("Mint vein",[(0,-.20,.77),(0,-.20,1.06)],M["Mint cream"],pack,.008)
    return pack

def bar(flavor,cream):
    o=root("IceCream_"+flavor)
    box("Thin wooden stick",(0,0,.42),(.16,.065,.83),M["Wood stick"],o,.06)
    line("Wood grain",[(-.025,-.034,.12),(-.027,-.034,.55)],M["Stick grain"],o,.004)
    box("Frozen cream body",(0,0,1.23),(.72,.27,1.35),M[cream],o,.22)
    if flavor!="mint_chocolate":
        # One continuous coating with soft drips, not separate rectangular tabs.
        rings=[]
        for w,d,z in [(.748,.304,0),(.748,.304,1.73),(.70,.29,1.84),(.58,.22,1.92),(.46,.12,1.95)]:
            points=rectangle(w,d,min(.105,d*.48),12)
            ring=[]
            for x,y in points:
                dip=sum(depth*math.exp(-((x-at)/span)**2) for at,depth,span in [(-.23,.10,.07),(-.035,.19,.065),(.23,.13,.075)])
                ring.append((x,y,1.65-dip if z==0 else z))
            rings.append(ring)
        n=len(rings[0]); faces=[]
        for k in range(len(rings)-1):
            for j in range(n): faces.append((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j))
        faces.extend([tuple(reversed(range(n))),tuple((len(rings)-1)*n+j for j in range(n))])
        mesh("Continuous dipped chocolate",[p for ring in rings for p in ring],faces,M["Chocolate coating"],o,True)
    if flavor=="strawberry_chocolate":
        for i in range(14):
            x=random.uniform(-.26,.26); z=random.uniform(.75,1.43)
            sphere("Strawberry fleck",(x,-.137,z),(.008,.0015,.014),M["Pink seal"],o)
    elif flavor=="chocolate":
        for z in [.92,1.13,1.34]:
            line("Milk chocolate drizzle",[(-.27,-.149,z+.08),(-.1,-.156,z),(.10,-.156,z-.07),(.27,-.149,z-.12)],M["Cocoa cream"],o,.018)
    else:
        for i in range(24):
            x=random.uniform(-.27,.27); z=random.uniform(.71,1.76)
            chip=box("Chocolate chip",(x,-.143,z),(.045,.014,.065),M["Dark chips"],o,.008)
            chip.rotation_euler.y=random.uniform(-.7,.7)
    return o

packs=[]; bars=[]
for flavor,cream,base,seal in FLAVORS:
    packs.append(wrapper(flavor,base,seal)); bars.append(bar(flavor,cream))

stocked=duplicate_tree(empty_box,"Icebox_Stocked")
ice_group=root("IceChunks"); ice_group.parent=stocked
for i in range(40):
    loc=(random.uniform(-1.70,1.70),random.uniform(-.90,.90),random.uniform(.98,1.16))
    side=random.uniform(.25,.40)
    cube=box(f"Ice_{i+1:02d}",loc,(side,side*.9,side*.85),M["Ice facet" if i%5==0 else "Ice translucent"],ice_group,.055)
    cube.rotation_euler=(random.uniform(-.4,.4),random.uniform(-.4,.4),random.uniform(0,math.pi))
for row,y in enumerate([-.64,.03,.64]):
    for col,x in enumerate([-1.42,-.47,.47,1.42]):
        i=row*4+col
        pack=duplicate_tree(packs[(col+row)%3],f"PickWrapped_{i+1:02d}",stocked)
        pack.location=(x,y,.51+random.uniform(-.05,.08))
        pack.rotation_euler=(random.uniform(-.07,.11),random.uniform(-.13,.13),random.uniform(-.14,.14))

assets={"cookie_tin_open":tin,"cookie_tin_filled":filled,"icebox_open":empty_box,"icebox_stocked":stocked}
assets.update({"wrapped_"+f[0]:o for f,o in zip(FLAVORS,packs)})
assets.update({"icecream_"+f[0]:o for f,o in zip(FLAVORS,bars)})

def export_asset(name,group):
    bpy.ops.object.select_all(action='DESELECT')
    for o in descendants(group): o.select_set(True)
    bpy.context.view_layer.objects.active=group
    dest=OUT/(name+".glb")
    bpy.ops.export_scene.gltf(filepath=str(dest),export_format='GLB',use_selection=True,
        export_apply=True,export_animations=False,export_yup=True,export_materials='EXPORT')
    return dest

scene=bpy.context.scene
scene.render.engine='CYCLES'; scene.cycles.samples=48
scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=900; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.render.film_transparent=True
scene.view_settings.view_transform='AgX'
scene.world=bpy.data.worlds.new("Soft studio")
scene.world.use_nodes=True; scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.62,.69,.75,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.42
rig=root("PreviewRig")
for name,loc,power,size in [('Key',(-4,-5,8),650,5),('Fill',(5,-2,5),420,4),('Rim',(1,5,7),600,4)]:
    light=bpy.data.lights.new(name,'AREA'); light.energy=power; light.shape='DISK'; light.size=size
    o=bpy.data.objects.new(name,light); bpy.context.collection.objects.link(o); o.location=loc; o.parent=rig
    o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
camera_data=bpy.data.cameras.new("AssetCamera"); camera=bpy.data.objects.new("AssetCamera",camera_data)
bpy.context.collection.objects.link(camera); camera.parent=rig; scene.camera=camera
camera_data.type='ORTHO'

def render_asset(name,group):
    active=set(descendants(group))
    for o in bpy.data.objects:
        if o.type in ['MESH','CURVE']: o.hide_render=o not in active
    lo,hi=world_bounds(list(active)); center=(lo+hi)/2
    camera.location=center+Vector((4,-7,5)).normalized()*10
    camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
    inv=camera.matrix_world.inverted() if False else None
    bpy.context.view_layer.update()
    points=[camera.matrix_world.inverted()@(o.matrix_world@Vector(c)) for o in active if o.type=='MESH' for c in o.bound_box]
    width=max(p.x for p in points)-min(p.x for p in points); height=max(p.y for p in points)-min(p.y for p in points)
    camera_data.ortho_scale=max(width,height*scene.render.resolution_x/scene.render.resolution_y)*1.18
    scene.render.filepath=str(PREVIEW/(name+".png"))
    bpy.ops.render.render(write_still=True)

report={"blender":bpy.app.version_string,"cookie_source_sha256":source_hash,"assets":{}}
for name,group in assets.items():
    dest=export_asset(name,group)
    objects=descendants(group); meshes=[o for o in objects if o.type=='MESH']
    lo,hi=world_bounds(meshes)
    report['assets'][name]={"file":str(dest),"bytes":dest.stat().st_size,
        "mesh_count":len(meshes),"triangles":sum(len(p.vertices)-2 for o in meshes for p in o.data.polygons),
        "bounds":list(hi-lo),"materials":sorted({m.name for o in meshes for m in o.data.materials if m})}
    if name in ['cookie_tin_filled','cookie_tin_open','icebox_stocked'] or name.startswith('icecream_'):
        render_asset(name,group)
assert hashlib.sha256(COOKIE.read_bytes()).hexdigest()==source_hash
report['source_preserved']=True
for o in bpy.data.objects:
    if o.type in ['MESH','CURVE']:
        o.hide_render=o not in set(descendants(filled))
        o.hide_set(o.hide_render)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'selection_props_v2.blend'))
(PREVIEW/'model-report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('SELECTION_PROPS_MODELS_OK',len(assets))
