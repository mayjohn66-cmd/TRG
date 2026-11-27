"""Export an optional transparent ice image from the same physical ice geometry."""
import bpy,sys
from pathlib import Path
from mathutils import Vector
repo,out=map(Path,sys.argv[sys.argv.index('--')+1:])
bpy.ops.wm.open_mainfile(filepath=str(repo/'art_source/selection_props/selection_props_v2.blend'))
ice=bpy.data.objects['IceChunks']
visible=set([ice,*ice.children_recursive])
for o in bpy.data.objects:
    if o.type in ['MESH','CURVE']:
        o.hide_set(False); o.hide_render=o not in visible
scene=bpy.context.scene; camera=scene.camera
target=Vector((0,0,1.1)); camera.location=target+Vector((4,-7,5)).normalized()*10
camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.ortho_scale=4.5
scene.render.resolution_x=1024; scene.render.resolution_y=640
scene.render.filepath=str(out)
bpy.ops.render.render(write_still=True)
print('ICE_LAYER_RENDER_OK')
