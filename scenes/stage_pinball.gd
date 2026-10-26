## Imported 3D base and polished ball. The authoritative ToolPinball result
## selects the pocket; this local timeline only presents that fixed outcome.
class_name PinballStage
extends Control

signal finished

const STAGE_SIZE := Vector2(360.0, 430.0)
const MOTION = preload("res://scenes/pinball_motion.gd")
const BASE: PackedScene = preload("res://assets/models/pinball/pinball_base_v01.tscn")
const BALL: PackedScene = preload("res://assets/models/pinball/steel_ball_v01.tscn")
const STUDIO: Environment = preload("res://assets/models/pinball/steel_ball_preview_environment_v01.tres")
const WIND_TIME: float = 0.16
const ARCH_SECONDS: float = 0.52
const HOLD_SECONDS: float = 0.45

var pull: float = 0.0
var active: bool = false
var instant: bool = false
var last_hole: int = -1
var render_view: SubViewport
var ball: Node3D
var base: Node3D
var _caption: Label
var _coil: MeshInstance3D
var _moving_plunger: Array[Node3D] = []
var _plunger_home: Array[Vector3] = []
var _floors: Array[MeshInstance3D] = []
var _floor_colors: Array[Color] = []
var _trajectory: Dictionary = {}
var _fall_seconds: float = 0.0
var _hole: int = -1
var _elapsed: float = 0.0
var _rise_seconds: float = 0.6
var _arrival: float = 0.0
var _total: float = 0.0
var _last_bounce: int = -1
var _result_played: bool = false


func _init() -> void:
	custom_minimum_size = STAGE_SIZE
	size = STAGE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	render_view = SubViewport.new()
	render_view.name = "PinballViewport"
	render_view.size = Vector2i(720, 800)
	render_view.own_world_3d = true
	render_view.transparent_bg = true
	render_view.gui_disable_input = true
	render_view.msaa_3d = Viewport.MSAA_2X
	render_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(render_view)
	var view := TextureRect.new()
	view.texture = render_view.get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	view.size = Vector2(360, 400)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 9.8
	camera.position = Vector3(0, 17, 11)
	render_view.add_child(camera)
	camera.look_at(Vector3(0, 0.1, -0.05))
	camera.current = true
	var world := WorldEnvironment.new()
	world.environment = STUDIO.duplicate()
	world.environment.ambient_light_energy = 0.25
	render_view.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_energy = 0.45
	light.shadow_enabled = true
	render_view.add_child(light)
	base = BASE.instantiate() as Node3D
	render_view.add_child(base)
	ball = BALL.instantiate() as Node3D
	render_view.add_child(ball)
	var plunger: Node3D = base.get_node("StaticSpringPlunger")
	_coil = plunger.get_node("SevenTurnSteelSpring")
	for node_name: String in ["PlungerRod", "BallPusher", "CoralPullKnob", "RoundedKnobEnd"]:
		var part: Node3D = plunger.get_node(node_name)
		_moving_plunger.append(part)
		_plunger_home.append(part.position)
	var pockets: Node3D = base.get_node("SevenRecessedPockets")
	for index: int in 7:
		var floor: MeshInstance3D = pockets.get_node("Pocket_%d_Value_%d/RecessFloor" % [index, ToolPinball.HOLES[index]])
		floor.material_override = floor.material_override.duplicate()
		_floors.append(floor)
		_floor_colors.append((floor.material_override as StandardMaterial3D).albedo_color)
	_batch_static_base()
	var panel := Panel.new()
	panel.position = Vector2(20, 400)
	panel.size = Vector2(320, 28)
	panel.add_theme_stylebox_override("panel", UiSkin.panel("panel", 2.0))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_caption = Label.new()
	_caption.size = panel.size
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 17)
	_caption.add_theme_color_override("font_color", UiSkin.INK)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_caption)
	visibility_changed.connect(_visibility_changed)
	reset()


func _batch_static_base() -> void:
	# Combine fixed pieces once, retaining the animated plunger and pocket
	# floors separately instead of issuing 175 individual mesh draws.
	var keep: Array[Node] = [_coil]
	keep.append_array(_moving_plunger)
	keep.append_array(_floors)
	var groups: Dictionary = {}
	var sources: Array[MeshInstance3D] = []
	for node: Node in base.find_children("*", "MeshInstance3D", true, false):
		if keep.has(node):
			continue
		var mesh := node as MeshInstance3D
		for surface: int in mesh.mesh.get_surface_count():
			var material: Material = mesh.material_override if mesh.material_override != null else mesh.mesh.surface_get_material(surface)
			if not groups.has(material):
				var builder := SurfaceTool.new()
				builder.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[material] = builder
			# Primitive meshes have indices; the authored rails/slabs do not.
			# Normalize both before appending so indexed primitives cannot hide
			# the earlier unindexed triangles in the same material batch.
			var source := SurfaceTool.new()
			source.create_from(mesh.mesh, surface)
			source.deindex()
			(groups[material] as SurfaceTool).append_from(source.commit(), 0, base.global_transform.affine_inverse() * mesh.global_transform)
		sources.append(mesh)
	for material: Material in groups:
		var merged := MeshInstance3D.new()
		merged.name = "StaticBatch"
		(groups[material] as SurfaceTool).index()
		merged.mesh = (groups[material] as SurfaceTool).commit()
		merged.material_override = material
		base.add_child(merged)
	for mesh: MeshInstance3D in sources:
		mesh.get_parent().remove_child(mesh)
		mesh.queue_free()


func _process(delta: float) -> void:
	if not active:
		return
	_elapsed += delta
	apply_time(_elapsed)
	var fall_start: float = WIND_TIME + _rise_seconds + ARCH_SECONDS
	var impacts: PackedFloat32Array = _trajectory.get("impacts", PackedFloat32Array())
	var bounced: bool = false
	while _last_bounce + 1 < impacts.size() and _elapsed - fall_start >= impacts[_last_bounce + 1]:
		_last_bounce += 1
		bounced = true
	if bounced and _elapsed < _arrival:
		Sfx.play(&"pinball_hit", -10.0, 0.0, 1.0 + 0.04 * (_last_bounce % 4))
	if _elapsed >= _arrival and not _result_played:
		_result_played = true
		Sfx.play(&"good", -6.0, 0.0)
	if _elapsed >= _total:
		active = false
		set_process(false)
		request_frame()
		finished.emit()


func set_pull(value: float) -> void:
	pull = clampf(value, 0.0, 1.0)
	if _coil == null:
		return
	var shift: float = pull * 0.22
	_coil.scale.z = 1.0 - shift / 0.88
	_coil.position.z = 4.31 * (1.0 - _coil.scale.z)
	for index: int in _moving_plunger.size():
		_moving_plunger[index].position = _plunger_home[index] + Vector3(0, 0, shift)
	if not active:
		ball.position = MOTION.PARK + Vector3(0, 0, shift)
	request_frame()


func reset() -> void:
	cancel()
	last_hole = -1
	_hole = -1
	if ball == null:
		return
	set_pull(0.0)
	ball.position = MOTION.PARK
	ball.quaternion = Quaternion.IDENTITY
	_highlight(-1)
	_caption.text = "클래식 구슬 핀볼 · 발사 버튼을 누르세요"
	request_frame()


func play(result: Dictionary, power: float = 0.5) -> void:
	cancel()
	var details: Dictionary = result["details"]
	_hole = clampi(int(details["hole"]), 0, 6)
	last_hole = -1
	_rise_seconds = lerpf(0.70, 0.45, clampf(power, 0.0, 1.0))
	_trajectory = {}
	_fall_seconds = 0.0
	if not instant and is_inside_tree():
		_trajectory = MOTION.trajectory(_hole, details.get("bounces", []))
		_fall_seconds = float(_trajectory["duration"])
	_arrival = WIND_TIME + _rise_seconds + ARCH_SECONDS + _fall_seconds
	_total = _arrival + HOLD_SECONDS
	if instant or not is_inside_tree():
		last_hole = _hole
		if ball != null:
			apply_time(_total)
			request_frame()
		return
	_highlight(-1)
	_caption.text = "스프링을 당겼다가… 발사!"
	_elapsed = 0.0
	_last_bounce = -1
	_result_played = false
	active = true
	render_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	set_process(true)
	apply_time(0.0)
	await finished


func apply_time(seconds: float) -> void:
	var t: float = maxf(seconds, 0.0)
	var arch_start: float = WIND_TIME + _rise_seconds
	var fall_start: float = arch_start + ARCH_SECONDS
	var position: Vector3
	if t < WIND_TIME:
		set_pull(sin(t / WIND_TIME * PI * 0.5))
		position = MOTION.PARK + Vector3(0, 0, pull * 0.22)
	elif t < arch_start:
		set_pull(0.0)
		var u: float = (t - WIND_TIME) / _rise_seconds
		position = (MOTION.PARK + Vector3(0, 0, 0.22)).lerp(MOTION.arch_position(0.0), (1.35 * u - 0.35 * u * u))
	elif t < fall_start:
		position = MOTION.arch_position((t - arch_start) / ARCH_SECONDS)
	elif t < _arrival and not _trajectory.is_empty():
		position = MOTION.sample(_trajectory["positions"], t - fall_start)
		_caption.text = "핀에 튕기며 굴러가는 중…"
	else:
		set_pull(0.0)
		position = (_trajectory["positions"] as PackedVector3Array)[-1] if not _trajectory.is_empty() else MOTION.hole_position(_hole)
		last_hole = _hole
		_highlight(_hole)
		_caption.text = "%s 포켓 골인 · %d칸 전진" % ["★10" if ToolPinball.HOLES[_hole] == 10 else str(ToolPinball.HOLES[_hole]), ToolPinball.HOLES[_hole]]
	# Roll about the travel direction without adding random position jitter.
	var movement: Vector3 = position - ball.position
	var axis := Vector3(movement.z, 0.0, -movement.x)
	if axis.length_squared() > 0.0000001:
		ball.quaternion = Quaternion(axis.normalized(), movement.length() / MOTION.RADIUS) * ball.quaternion
	ball.position = position


func _highlight(index: int) -> void:
	for slot: int in _floors.size():
		var material := _floors[slot].material_override as StandardMaterial3D
		material.albedo_color = Color("ffe095") if slot == index else _floor_colors[slot]
		material.emission_enabled = slot == index
		material.emission = Color("a06e12")
		material.emission_energy_multiplier = 0.35


func request_frame() -> void:
	if render_view != null and not active:
		render_view.render_target_update_mode = SubViewport.UPDATE_ONCE if is_visible_in_tree() else SubViewport.UPDATE_DISABLED


func stop_rendering() -> void:
	if render_view != null:
		render_view.render_target_update_mode = SubViewport.UPDATE_DISABLED


func cancel() -> void:
	set_process(false)
	stop_rendering()
	if active:
		active = false
		finished.emit()


func _visibility_changed() -> void:
	if not is_visible_in_tree():
		cancel()
	else:
		request_frame()


func _exit_tree() -> void:
	cancel()
