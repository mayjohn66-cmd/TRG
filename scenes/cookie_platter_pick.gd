## The existing sixteen cookies share one mesh; only the chosen cookie moves.
class_name CookiePlatterPick
extends Control

signal selected(index: int)
const HEAP: PackedScene = preload("res://assets/models/optimized/v4/fortune_cookie/platter_v1/cookie_platter_heaped.scn")
const EXTENT := Vector2(560, 350)
var cookies: Array[Node3D] = []
var _view: SubViewport
var _camera: Camera3D
var _warmup := 5
var _chosen := -1
var _opening: Node3D
var _left: Node3D
var _right: Node3D
var _left_rest: Vector3
var _right_rest: Vector3
var _paper: Node3D
var _print_view: SubViewport
var _plate: Node3D
var _display: TextureRect

func prepare_message(sentence: String) -> void:
	_print_view = SubViewport.new()
	_print_view.size = Vector2i(1024,164)
	_print_view.disable_3d = true
	add_child(_print_view)
	var background := ColorRect.new()
	background.size = Vector2(_print_view.size)
	background.color = Color("fcf3df")
	_print_view.add_child(background)
	var label := Label.new()
	label.size = background.size
	label.text = L10n.t(sentence)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FortuneCookieView.FONT)
	var width := FortuneCookieView.FONT.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,55).x
	label.add_theme_font_size_override("font_size",mini(55,floori(55*900/maxf(width,1))))
	label.add_theme_color_override("font_color",Color("523321"))
	_print_view.add_child(label)
	_print_view.render_target_update_mode = SubViewport.UPDATE_ONCE

## Open the chosen instance at its pickup pose, with the paper held by both halves.
func open_at(seconds: float) -> void:
	if _chosen < 0 or seconds < 0.55: return
	if _opening == null:
		_opening = Node3D.new()
		cookies[_chosen].get_parent().add_child(_opening)
		_opening.transform = cookies[_chosen].transform
		cookies[_chosen].hide()
		var broken := FortuneCookieView.BROKEN.instantiate() as Node3D
		_opening.add_child(broken)
		_left = broken.find_child("LeftHalf",true,false)
		_right = broken.find_child("RightHalf",true,false)
		_left_rest = _left.position
		_right_rest = _right.position
		_paper = FortuneCookieView.SLIP.instantiate()
		_opening.add_child(_paper)
		var mesh := _paper.find_child("FoldedPaper",true,false) as MeshInstance3D
		var ink := mesh.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
		ink.albedo_texture = _print_view.get_texture()
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.set_surface_override_material(0,ink)
		Sfx.play(&"icecream_snap",-5)
	var spread := smoothstep(0.55,1.65,seconds)
	_opening.scale=Vector3.ONE*lerpf(.68,1.08,spread)
	var left_mouth := FortuneCookieView.CLOSED_SEAM.lerp(FortuneCookieView.LEFT_OPENING,spread)
	var right_mouth := FortuneCookieView.CLOSED_SEAM.lerp(FortuneCookieView.RIGHT_OPENING,spread)
	_left.rotation_degrees = Vector3(6,-34,63)*spread
	_right.rotation_degrees = Vector3(-3,35,-62)*spread
	_left.position = left_mouth-_left.basis*(FortuneCookieView.CLOSED_SEAM-_left_rest)
	_right.position = right_mouth-_right.basis*(FortuneCookieView.CLOSED_SEAM-_right_rest)
	_paper.position = (left_mouth+right_mouth)*.5+Vector3(0,-.12,-.19)
	_paper.rotation_degrees = Vector3(64,0,3*spread)
	_paper.scale = Vector3(lerpf(.04,.99,spread),1,lerpf(.7,1.12,spread))
	var focus:=Vector3(0,.45,0).lerp(_paper.global_position,spread)
	_camera.position=focus+Vector3(4,5.55,6)
	_camera.look_at(focus)

func _ready() -> void:
	custom_minimum_size = EXTENT
	size = EXTENT
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_view = SubViewport.new()
	_view.size = Vector2i(840, 525)
	_view.transparent_bg = true
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_2X
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	var display := TextureRect.new()
	display.texture = _view.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.size = EXTENT
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)
	_display=display
	resized.connect(func() -> void:
		if _chosen<0: _display.position=(size-EXTENT)*.5)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("fff5e5")
	world.environment.ambient_light_energy = 0.35
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_view.add_child(world)
	for entry: Array in [[Vector3(-4,7,5),0.8],[Vector3(5,5,2),0.35],[Vector3(0,7,-5),0.5]]:
		var light := DirectionalLight3D.new()
		_view.add_child(light)
		light.position = entry[0]
		light.look_at(Vector3(0,0.4,0))
		light.light_energy = entry[1]
	var heap := HEAP.instantiate() as Node3D
	_view.add_child(heap)
	_plate=heap.get_node("Plate")
	for child: Node in heap.get_children():
		if str(child.name).begins_with("PickCookie_"):
			cookies.append(child as Node3D)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 5.4
	_view.add_child(_camera)
	_camera.position = Vector3(4,6,6)
	_camera.look_at(Vector3(0,0.45,0))
	_camera.current = true

func _process(_delta: float) -> void:
	if _chosen >= 0:
		return
	_warmup -= 1
	if _warmup <= 0 and _view != null:
		_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		set_process(false)

## Match the pointer to the frontmost cookie's mesh bounds in the 3D camera.
func index_at(at: Vector2) -> int:
	if _camera == null:
		return -1
	var uv := (at-_display.position) / EXTENT * Vector2(_view.size)
	var origin := _camera.project_ray_origin(uv)
	var direction := _camera.project_ray_normal(uv)
	var nearest := INF
	var index := -1
	for i: int in cookies.size():
		for child: Node in cookies[i].find_children("*", "MeshInstance3D", true, false):
			var mesh := child as MeshInstance3D
			var inverse := mesh.global_transform.affine_inverse()
			var hit: Variant = mesh.get_aabb().intersects_ray(inverse * origin, inverse.basis * direction)
			if hit is Vector3:
				var distance := origin.distance_to(mesh.global_transform * (hit as Vector3))
				if distance < nearest:
					nearest = distance
					index = i
	return index

func screen_position(index: int) -> Vector2:
	return _camera.unproject_position(cookies[index].global_position) / Vector2(_view.size) * EXTENT+_display.position

func take(index: int, focus: Vector2 = Vector2.INF) -> void:
	if _chosen >= 0 or index < 0 or index >= cookies.size():
		return
	_chosen = index
	for i: int in cookies.size():
		if i!=index: cookies[i].hide()
	_plate.hide()
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cookie := cookies[index]
	var tween := create_tween().set_parallel(true)
	var target:=focus-global_position-EXTENT*.5 if focus.is_finite() else (size-EXTENT)*.5
	tween.tween_property(_display,"position",target,.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(cookie, "position", Vector3.ZERO, 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(cookie, "rotation", Vector3(0,atan2(4.0,6.0),0), 0.48)
	tween.tween_property(cookie, "scale", Vector3.ONE * 0.68, 0.48)

func _gui_input(event: InputEvent) -> void:
	var at := Vector2.ZERO
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		at = event.position
	elif event is InputEventScreenTouch and event.pressed:
		at = event.position
	else:
		return
	var index := index_at(at)
	if index >= 0:
		accept_event()
		selected.emit(index)
