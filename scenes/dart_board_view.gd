## Timing and result views share the same baked 3D models; no RNG lives here.
class_name DartBoardView
extends TextureRect

const SIZE := Vector2(360, 340)
const SPIN_PERIOD := 2.4
const AIM_PERIOD := 1.3
const FLIGHT_TIME := 0.45
const TOTAL_TIME := 1.5
const FACE_Z := 0.075
const TIP_Z := -0.14
const SCORE_RADIUS := 2.0
const BOARD_MODEL: PackedScene = preload("res://assets/models/darts/v02/dartboard_v02.tscn")
const DART_MODEL: PackedScene = preload("res://assets/models/darts/v02/dart_v02.tscn")

var aiming := false
var settled := false
var _spin := 0.0
var _aim_radius := 0.0
var _clock := 0.0
var _hit_radius := -1.0
var _hit_angle := 0.0
var _bull := false
var _t := 0.0
var _viewport: SubViewport
var _board: Node3D
var _dart: Node3D
var _camera: Camera3D
var _reticle: Node3D


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func _ready() -> void:
	_build_scene()
	visibility_changed.connect(_sync_rendering)
	_present()
	_sync_rendering()


func set_aiming(on: bool) -> void:
	aiming = on
	_hit_radius = -1.0
	settled = false
	if is_node_ready():
		_present()
		_sync_rendering()


## Fixed twelve-o'clock cursor against a clockwise spinning board.
func current_aim() -> Array:
	return [_aim_radius, fposmod(-_spin, 1.0)]


func _process(delta: float) -> void:
	_clock += delta
	_spin = fposmod(_clock / SPIN_PERIOD, 1.0)
	_aim_radius = 0.5 - 0.5 * cos(_clock / AIM_PERIOD * TAU)
	_present()


func begin(details: Dictionary) -> void:
	aiming = false
	_spin = 0.0
	_hit_radius = float(details.get("radius", 0.5))
	_hit_angle = float(details.get("angle", 0.0))
	_bull = bool(details.get("bull", false))
	settled = false
	_t = 0.0
	if is_node_ready():
		_present()
		_sync_rendering()


func apply_time(t: float) -> void:
	_t = maxf(t, 0.0)
	settled = _t >= FLIGHT_TIME
	if is_node_ready():
		_present()
		_request_frame()


static func caption(details: Dictionary, steps: int) -> String:
	return ToolDarts.hit_text(details, steps)


static func hit_point(radius: float, angle: float, z: float = TIP_Z) -> Vector3:
	return Vector3(sin(angle * TAU) * radius * SCORE_RADIUS, cos(angle * TAU) * radius * SCORE_RADIUS, z)


func _build_scene() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "DartsViewport"
	_viewport.size = Vector2i(SIZE * 2.0)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	texture = _viewport.get_texture()
	_board = BOARD_MODEL.instantiate()
	_board.name = "DartboardModel"
	_viewport.add_child(_board)
	_dart = DART_MODEL.instantiate()
	_dart.name = "EmbeddedDart"
	_viewport.add_child(_dart)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 5.65
	_camera.current = true
	_viewport.add_child(_camera)
	_reticle = Node3D.new()
	_reticle.name = "AimCursor"
	_viewport.add_child(_reticle)
	var ink := _cursor_material(Color("101426"))
	var cream := _cursor_material(Color("fff4d3"))
	for axis: int in 2:
		_cursor_bar(Vector2(0.32, 0.045) if axis == 0 else Vector2(0.045, 0.32), ink, 0.0)
		_cursor_bar(Vector2(0.27, 0.018) if axis == 0 else Vector2(0.018, 0.27), cream, 0.005)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.084
	torus.outer_radius = 0.106
	torus.rings = 24
	torus.ring_segments = 8
	ring.mesh = torus
	ring.rotation.x = PI / 2.0
	ring.material_override = cream
	_reticle.add_child(ring)


func _cursor_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material


func _cursor_bar(dimensions: Vector2, material: Material, z: float) -> void:
	var bar := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = dimensions
	bar.mesh = quad
	bar.material_override = material
	bar.position.z = z
	_reticle.add_child(bar)


func _present() -> void:
	_board.rotation.z = -_spin * TAU if aiming else 0.0
	_reticle.visible = aiming
	_reticle.position = Vector3(0.0, _aim_radius * SCORE_RADIUS, 0.22)
	_dart.visible = not aiming and _hit_radius >= 0.0
	var reveal := smoothstep(0.0, 0.75, _t) if not aiming else 0.0
	_camera.position = Vector3(5.0 * reveal, 1.6 * reveal, 8.5)
	_camera.look_at(Vector3.ZERO, Vector3.UP)
	if _dart.visible:
		var flight := clampf(_t / FLIGHT_TIME, 0.0, 1.0)
		_dart.position = hit_point(_hit_radius, _hit_angle) + Vector3(1.1, 1.3, 5.0) * (1.0 - pow(flight, 3.0))
		var age := maxf(_t - FLIGHT_TIME, 0.0)
		var wobble := sin(age * 42.0) * exp(-age * 12.0) * 0.045 if settled else 0.0
		# Wobble pivots about the tip; the authoritative contact point stays fixed.
		_dart.rotation = Vector3(deg_to_rad(-8.0) + wobble, deg_to_rad(8.0) + wobble, 0.0)


func _sync_rendering() -> void:
	var running := aiming and is_visible_in_tree()
	set_process(running)
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if running else SubViewport.UPDATE_DISABLED
		if is_visible_in_tree() and not running:
			_request_frame()


func _request_frame() -> void:
	if is_visible_in_tree() and not aiming:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _exit_tree() -> void:
	set_process(false)
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	# Detach the canvas consumer before its child render target is destroyed.
	texture = null
