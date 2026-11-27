## A still life of an existing game model, rendered once and then frozen.
## The selection preview contains no result, prize, fortune or random calls.
class_name ToolPickProp
extends TextureRect

const MODELS := {
	&"DICE_COOKIE": preload("res://assets/models/optimized/v4/fortune_cookie/fortune-cookie-whole.scn"),
	&"DICE_CAPSULE": preload("res://assets/models/optimized/v4/capsule_gacha/capsule.scn"),
}
var _view: SubViewport
var _warmup := 4

func setup(id: StringName, extent: Vector2, index: int) -> void:
	size = extent
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_view = SubViewport.new()
	_view.size = Vector2i(320,320)
	_view.transparent_bg = true
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_2X
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	texture = _view.get_texture()
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0,0,0,0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff5e6")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	_view.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42,-35,0)
	key.light_energy = 1.3
	_view.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25,135,0)
	fill.light_color = Color("c3e9e1")
	fill.light_energy = 0.6
	_view.add_child(fill)
	var model := (MODELS[id] as PackedScene).instantiate() as Node3D
	model.rotation_degrees.y = -18.0+float(index)*12.0 if id==&"DICE_COOKIE" else -14.0
	_view.add_child(model)
	if id==&"DICE_CAPSULE":
		# Cosmetic candidate colors, independent of the as-yet unrolled prize.
		var tint: Color = [Color("e78e98"),Color("76a9dc"),Color("81c4a3"),Color("b09bd2")][index%4]
		for part: String in ["CupShell","CupLip"]:
			var mesh := model.find_child(part,true,false) as MeshInstance3D
			var material := mesh.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
			material.albedo_color = tint.darkened(0.15) if part=="CupLip" else tint
			material.metallic = 0.0
			mesh.set_surface_override_material(0,material)
	# Frame the real mesh bounds, independent of each asset's authoring scale.
	var bounds: AABB
	var first := true
	for child: Node in model.find_children("*","MeshInstance3D",true,false):
		var mesh := child as MeshInstance3D
		var pose := mesh.transform
		var ancestor := mesh.get_parent()
		while ancestor is Node3D:
			pose = (ancestor as Node3D).transform*pose
			ancestor = ancestor.get_parent()
		var box: AABB = pose*mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var center := bounds.get_center()
	var diameter := maxf(bounds.size.length(),0.1)
	camera.size = diameter*1.03
	_view.add_child(camera)
	var eye := center+Vector3(0.25,0.65,1.0).normalized()*diameter*2.0
	camera.transform = Transform3D(Basis.looking_at(center-eye),eye)
	var projected: AABB = camera.transform.affine_inverse()*bounds
	camera.size = maxf(projected.size.x,projected.size.y)*1.12
	camera.current = true

func _process(_delta: float) -> void:
	_warmup-=1
	if _warmup>0: return
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	set_process(false)
