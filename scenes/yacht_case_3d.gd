## Static low-poly case behind the existing dice/input layer; no extra idle rendering.
class_name YachtCase3D
extends TextureRect

const MODEL_PATH: String="res://assets/models/optimized/v5/yacht_case/case.scn"
const VIEW_SIZE:=Vector2(800,352)
var render_view: SubViewport

func _init() -> void:
	size=VIEW_SIZE
	expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode=TextureRect.STRETCH_SCALE
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	if DisplayServer.get_name()=="headless": return # Static artwork has no simulation to run.
	render_view=SubViewport.new()
	render_view.name="YachtCaseViewport"
	render_view.size=Vector2i(800,352)
	render_view.own_world_3d=true
	render_view.transparent_bg=true
	render_view.gui_disable_input=true
	render_view.msaa_3d=Viewport.MSAA_2X
	render_view.render_target_update_mode=SubViewport.UPDATE_ONCE
	add_child(render_view)
	texture=render_view.get_texture()
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=VIEW_SIZE.y/42.0
	camera.position=Vector3(0,0,16)
	render_view.add_child(camera)
	camera.current=true
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("e4eadb")
	environment.environment.ambient_light_energy=.65
	render_view.add_child(environment)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-30,-30,0)
	light.light_energy=1.1
	render_view.add_child(light)
	var model: Node3D=(load(MODEL_PATH) as PackedScene).instantiate() as Node3D
	model.rotation.x=PI*.5 # Blender XY tray faces the same camera as the dice.
	for node: Node in model.find_children("*","MeshInstance3D",true,false):
		var mesh:=node as MeshInstance3D
		for surface: int in mesh.mesh.get_surface_count():
			var source:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source!=null and source.resource_name.begins_with("Green felt"):
				var felt:=source.duplicate() as StandardMaterial3D
				felt.albedo_texture=CardMat.FABRIC
				felt.albedo_color*=Color(1.9,1.9,1.9,1)
				felt.uv1_scale=Vector3(3,2,1)
				mesh.set_surface_override_material(surface,felt)
	render_view.add_child(model)

func set_active(enabled: bool) -> void:
	if render_view==null: return
	if enabled:
		preload("res://scenes/web_3d_budget.gd").restore(self)
		render_view.render_target_update_mode=SubViewport.UPDATE_ONCE
	else:
		preload("res://scenes/web_3d_budget.gd").park(self)
