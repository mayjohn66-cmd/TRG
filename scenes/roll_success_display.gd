## Success-only trophies: lit 3D props, printed ink stamps, or one current revolver score.
class_name RollSuccessDisplay
extends Control

const TOOLS: Array[StringName] = [&"REVOLVER",&"LIFE_ROULETTE",&"DICE_MAHJONG",&"DICE_TAROT",&"DICE_YACHT",&"DICE_BLACKJACK"]
const STACK_TOOLS: Array[StringName] = [&"DICE_MAHJONG",&"DICE_BLACKJACK"]
const STAMPS := {&"LIFE_ROULETTE":"star",&"DICE_TAROT":"moon",&"DICE_YACHT":"thumb"}
const MAX_SHOWN := 6
var tool_id: StringName = &""
var count: int = 0
var _vp: SubViewport
var _view: TextureRect
var _pile: Node3D
var _props: Array[Node3D] = []
var _stamps: Array[TextureRect] = []
var _age: float = 1.0
var _latest: int = -1
var _rest: Vector3
var _rotation: Vector3
var _stamp_rest: Vector2
var _score: Label
var _amount: int = -1

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(180,102)
	resized.connect(_layout)
	set_process(false)

static func supports(tool: StringName) -> bool:
	return tool in TOOLS

func clear() -> void:
	count = 0
	_latest = -1
	_age = 1.0
	_props.clear()
	_stamps.clear()
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_vp = null
	_view = null
	_pile = null
	_score = null
	_amount = -1
	set_process(false)
	hide()

func configure(tool: StringName) -> void:
	if tool_id == tool: return
	clear()
	tool_id = tool

func set_count(total: int, animate: bool = false) -> void:
	total = maxi(0,total)
	if total == count: return
	var previous := count
	count = total
	if tool_id == &"REVOLVER":
		set_revolver_amount(total*3,animate)
		return
	if tool_id in STACK_TOOLS:
		if _vp == null: _build_world()
		for prop: Node3D in _props:
			_pile.remove_child(prop)
			prop.queue_free()
		_props.clear()
		for i: int in mini(count,MAX_SHOWN):
			var prop := _make_prop()
			_pile.add_child(prop)
			prop.position = _target(i)
			prop.rotation = _target_rotation(i)
			_props.append(prop)
		_latest = _props.size()-1
		if _latest >= 0:
			_rest = _props[_latest].position
			_rotation = _props[_latest].rotation
	else:
		for mark: TextureRect in _stamps:
			remove_child(mark)
			mark.queue_free()
		_stamps.clear()
		var tex: Texture2D = load("res://assets/ui/trickcal/roll_success_v01/%s.webp" % STAMPS.get(tool_id,"star"))
		for i: int in mini(count,MAX_SHOWN):
			var mark := TextureRect.new()
			mark.texture = tex
			mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(mark)
			_stamps.append(mark)
		_latest = _stamps.size()-1
	_layout()
	_age = 0.0 if animate and total > previous else 1.0
	show()
	_pose()
	set_process(_age < 0.56)
	_update_viewport()

func set_revolver_amount(value: int, animate: bool = false) -> void:
	value = maxi(0,value)
	if _score != null and _amount == value: return
	if _score == null:
		_score = Label.new()
		_score.name = "CurrentBonus"
		_score.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_score.add_theme_font_size_override("font_size",64)
		_score.add_theme_color_override("font_outline_color",Color("fff8df"))
		_score.add_theme_constant_override("outline_size",4)
		add_child(_score)
	_amount = value
	_score.text = "+%d" % value
	_score.add_theme_color_override("font_color",Color("ad3445") if value==0 else Color("337354"))
	_age = 0.0 if animate else 1.0
	_layout()
	_pose()
	set_process(animate)

func _layout() -> void:
	if _score != null:
		_score.size = size
		_score.pivot_offset = size*0.5
	if _view != null: _view.size = size
	for i: int in _stamps.size():
		var mark := _stamps[i]
		mark.size = Vector2(51,51)
		mark.pivot_offset = mark.size*0.5
		mark.position = Vector2((size.x-165.0)*0.5+(i%3)*57, (i/3)*47.0)
		mark.rotation = deg_to_rad(-8.0 if i%2==0 else 6.0)
	if _latest >= 0 and _latest < _stamps.size():
		_stamp_rest = _stamps[_latest].position

func _process(delta: float) -> void:
	_age += delta
	_pose()
	if _age >= (0.20 if tool_id==&"REVOLVER" else 0.56): set_process(false)
	_update_viewport()

func _pose() -> void:
	if _score != null:
		var progress := clampf(_age/0.18,0.0,1.0)
		_score.scale = Vector2.ONE*lerpf(1.18,1.0,1.0-pow(1.0-progress,3.0))
		return
	if _latest < 0: return
	if tool_id in STACK_TOOLS and _latest < _props.size():
		var p := clampf(_age/0.42,0.0,1.0)
		var lift := 1.55*pow(1.0-p/0.72,2.0) if p<0.72 else sin((p-0.72)/0.28*PI)*0.12
		_props[_latest].position = _rest+Vector3(0,lift,0)
		_props[_latest].rotation = _rotation+Vector3(0,0,(1.0-p)*0.28)
	elif _latest < _stamps.size():
		var mark := _stamps[_latest]
		var p := clampf(_age/0.14,0.0,1.0)
		var settle := clampf((_age-0.14)/0.15,0.0,1.0)
		var zoom := lerpf(1.8,0.9,p*p) if _age<0.14 else lerpf(0.9,1.0,1.0-pow(1.0-settle,2.0))
		mark.scale = Vector2.ONE*zoom
		mark.modulate.a = clampf(_age/0.06,0.0,1.0)
		var shock := sin(settle*PI*3.0)*(1.0-settle)*2.0 if _age>=0.14 else 0.0
		mark.position = _stamp_rest+Vector2(shock,0)

func _update_viewport() -> void:
	if _vp != null:
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_processing() else SubViewport.UPDATE_ONCE

func _build_world() -> void:
	_vp = SubViewport.new()
	_vp.name = "Trophy3D"
	_vp.size = Vector2i(540,306)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_vp)
	_view = TextureRect.new()
	_view.texture = _vp.get_texture()
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	var world := Node3D.new()
	_vp.add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0,0,0,0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff3dc")
	env.ambient_light_energy = 0.50
	environment.environment = env
	world.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40,-35,0)
	key.light_energy = 1.15
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25,140,0)
	fill.light_energy = 0.50
	world.add_child(fill)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.70
	camera.position = Vector3(3.8,4.0,6.0)
	world.add_child(camera)
	camera.look_at(Vector3(0,0.35,0))
	_pile = Node3D.new()
	world.add_child(_pile)

func _target(i: int) -> Vector3:
	if tool_id == &"DICE_BLACKJACK": return Vector3(0,i*0.145,0)
	if tool_id == &"DICE_MAHJONG": return Vector3((i%2)*0.10-0.05,i*0.13,0)
	return Vector3.ZERO

func _target_rotation(i: int) -> Vector3:
	if tool_id == &"DICE_MAHJONG": return Vector3(0,deg_to_rad(-9 if i%2==0 else 10),0)
	return Vector3(0,deg_to_rad(i*17),0)

func _material(hex: String, metal: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.metallic = metal
	mat.roughness = 0.3 if metal>0.0 else 0.62
	return mat

func _cylinder(parent: Node3D, radius: float, height: float, at: Vector3, material: Material, open_top: bool = false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 40
	mesh.cap_top = not open_top
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance

func _box(parent: Node3D, dimensions: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance

func _make_prop() -> Node3D:
	var prop := Node3D.new()
	if tool_id == &"DICE_MAHJONG":
		_box(prop,Vector3(1.65,0.11,0.20),Vector3.ZERO,_material("d5ccaf"))
		_cylinder(prop,0.065,0.008,Vector3(0,0.06,0),_material("c72d36"))
	else:
		var blue := _material("238790")
		var cream := _material("fff0d0")
		_cylinder(prop,0.46,0.125,Vector3.ZERO,blue)
		for i: int in 10:
			var theta := i*TAU/10.0
			var edge := _box(prop,Vector3(0.12,0.129,0.09),Vector3(sin(theta)*0.404,0,cos(theta)*0.404),cream)
			edge.rotation.y = theta
		_cylinder(prop,0.31,0.006,Vector3(0,0.066,0),cream)
		_cylinder(prop,0.245,0.008,Vector3(0,0.071,0),blue)
	return prop
