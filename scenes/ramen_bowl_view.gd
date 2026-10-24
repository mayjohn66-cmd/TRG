## One transparent, isolated 3D viewport for the difficulty bowl.
## Static settled bowls render once; hidden menus stop rendering altogether.
extends Control

const Model = preload("res://scenes/ramen_bowl_model.gd")
const COLORS: Dictionary = {1: Color("f8dc93"), 2: Color("f5a078"), 3: Color("e95d32"), 4: Color("aa382b"), 5: Color("d92329")}

var level: int = 1
var sauce: Color = COLORS[1]
var pour: float = 0.0
var _time: float = 0.0
var _reaction: float = 1.0
var _shown_sauce: Color = COLORS[1]
var _previous_sauce: Color = COLORS[1]
var render_view: SubViewport
var model_root: Node3D
var source_node: MeshInstance3D
var camera: Camera3D
var _food_material: StandardMaterial3D
var _mound_material: StandardMaterial3D
var _source_material: StandardMaterial3D
var _drops: Array[MeshInstance3D] = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	render_view = SubViewport.new()
	render_view.name = "Ramen3DViewport"
	render_view.size = Vector2i(1080, 308)
	render_view.own_world_3d = true
	render_view.transparent_bg = true
	render_view.gui_disable_input = true
	render_view.msaa_3d = Viewport.MSAA_2X
	render_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(render_view)
	var world := Node3D.new()
	render_view.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("f3eddf")
	environment.environment.ambient_light_energy = 0.65
	world.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -30, 0)
	key.light_energy = 1.0
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 10.0
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 135, 0)
	fill.light_energy = 0.25
	world.add_child(fill)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.4
	camera.position = Vector3(0, 5.12, 8)
	world.add_child(camera)
	camera.look_at(Vector3(0, 1.12, 0), Vector3.UP)
	camera.current = true
	model_root = Model.make_model()
	world.add_child(model_root)
	_food_material = model_root.get_node("Noodles").material_override
	_mound_material = model_root.get_node("NoodleMound").material_override
	_source_material = Model.material(sauce, 0.3)
	var stream := CylinderMesh.new()
	stream.top_radius = 1.0
	stream.bottom_radius = 1.0
	stream.height = 1.0
	stream.radial_segments = 12
	source_node = Model.part(model_root, "SauceStream", stream, _source_material)
	source_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var drop := SphereMesh.new()
	drop.radius = 0.025
	drop.height = 0.07
	drop.radial_segments = 8
	drop.rings = 4
	for index: int in 4:
		var item: MeshInstance3D = Model.part(model_root, "SauceDrop%d" % index, drop, _source_material)
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_drops.append(item)
	_sync_model()
	_sync_visibility()

func set_level(value: int, animate: bool) -> void:
	level = clampi(value, 1, 5)
	sauce = COLORS[level]
	_previous_sauce = _shown_sauce
	_reaction = 0.0 if animate else 1.0
	if not animate:
		_shown_sauce = sauce
	var span: Vector2 = pour_span()
	pour = span.y - span.x
	_sync_model()
	queue_redraw()

func pour_span() -> Vector2:
	var front: float = clampf(_reaction / 0.22, 0.0, 1.0)
	var tail: float = 0.0 if level == 5 else clampf((_reaction - 0.52) / 0.22, 0.0, 1.0)
	return Vector2(tail, front)

func shake_offset() -> Vector2:
	return Vector2(sin(_time * 17.0) * 0.75, sin(_time * 13.0) * 0.4) if level == 5 else Vector2.ZERO

func _process(delta: float) -> void:
	_time += delta
	var was_changing: bool = _reaction < 1.0
	_reaction = minf(1.0, _reaction + delta)
	var span: Vector2 = pour_span()
	pour = span.y - span.x
	_shown_sauce = _previous_sauce.lerp(sauce, smoothstep(0.22, 0.72, _reaction))
	if was_changing or level == 5:
		_sync_model()
	queue_redraw()

func _sync_model() -> void:
	if model_root == null:
		return
	_food_material.albedo_color = _shown_sauce
	_mound_material.albedo_color = _shown_sauce.darkened(0.25)
	_source_material.albedo_color = sauce
	var span: Vector2 = pour_span()
	var start: float = 3.2
	var hit: float = Model.FOOD_Y + 0.05
	var top: float = lerpf(start, hit, span.x)
	var bottom: float = lerpf(start, hit, span.y)
	source_node.visible = top - bottom > 0.001
	if source_node.visible:
		var radius: float = 0.046 if level == 5 else 0.032
		source_node.position = Vector3(0.27, (top + bottom) * 0.5, 0.12)
		source_node.scale = Vector3(radius, top - bottom, radius)
	for index: int in _drops.size():
		var drop: MeshInstance3D = _drops[index]
		var y: float = start - fmod(_time * 2.3 + index * 0.47, start - hit)
		drop.position = Vector3(0.27 + sin(_time * 7.0 + index) * 0.018, y, 0.12)
		drop.visible = source_node.visible and y <= top and y >= bottom
	var shake: Vector2 = shake_offset()
	model_root.position.x = shake.x * 0.008
	model_root.rotation.z = shake.y * 0.005
	if is_visible_in_tree():
		render_view.render_target_update_mode = SubViewport.UPDATE_ONCE

func _sync_visibility() -> void:
	var active: bool = is_visible_in_tree()
	set_process(active)
	if render_view != null:
		render_view.render_target_update_mode = SubViewport.UPDATE_ONCE if active else SubViewport.UPDATE_DISABLED
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_sync_visibility()

func _draw() -> void:
	if render_view == null or camera == null:
		return
	var scale_factor: float = minf(size.x / 540.0, size.y / 154.0)
	var extent := Vector2(540, 154) * scale_factor
	var origin := Vector2((size.x - extent.x) * 0.5, 0)
	# A quiet contact shadow; the bowl, its cavity and food are real depth-tested meshes.
	var ground: Vector2 = camera.unproject_position(Vector3(0, 0.02, 0)) * 0.5 * scale_factor + origin
	var shadow := PackedVector2Array()
	for index: int in 48:
		var angle: float = TAU * float(index) / 48.0
		shadow.append(ground + Vector2(cos(angle) * 68, sin(angle) * 4) * scale_factor)
	draw_colored_polygon(shadow, Color(0.2, 0.15, 0.12, 0.12))
	draw_texture_rect(render_view.get_texture(), Rect2(origin, extent), false)
	for index: int in 3:
		var phase: float = fmod(_time * (0.32 + level * 0.04) + index * 0.34, 1.0)
		var base: Vector2 = camera.unproject_position(Vector3((index - 1) * 0.52, 1.30, 0.0)) * 0.5
		var line := PackedVector2Array()
		for step: int in 13:
			var t: float = float(step) / 12.0
			line.append(origin + (base + Vector2(sin(t * TAU + _time * 1.5 + index) * 2.5, -phase * 10.0 - t * (12.0 + level * 2.0))) * scale_factor)
		draw_polyline(line, Color(0.65, 0.53, 0.43, sin(phase * PI) * 0.25), 2.0 * scale_factor, true)
