## Timing and result views share the same baked 3D models; no RNG lives here.
class_name DartBoardView
extends TextureRect

const SIZE := Vector2(360, 340)
const SPIN_PERIOD := 2.4
const AIM_PERIOD := 1.3
const FLIGHT_TIME := 0.45
## 1.3.1 뜸 들이기: 다트가 꽂힌 뒤 정면 그대로 잠시 멈췄다가(SUSPENSE) 판이 옆으로 기울며(TILT_TIME) 결과를 보여 준다.
const SUSPENSE := 0.6
const TILT_TIME := 0.55
const REVEAL_AT := FLIGHT_TIME + SUSPENSE + TILT_TIME * 0.6
const TOTAL_TIME := FLIGHT_TIME + SUSPENSE + TILT_TIME + 0.45
const FACE_Z := 0.075
const TIP_Z := -0.14
const SCORE_RADIUS := 2.0
## 1.3.1: 과녁 판(점수 칸·철사·숫자)만 돌고 테두리·나사·받침은 그대로다. 꽂힌 뒤에는 다트를 꽂은 채 STOP_TIME 동안 서서히 멈춘다.
const FACE_PARTS: Array[String] = ["TwelveSolidScoringSectors", "RaisedDividerWires", "ExtrudedNumbers"]
const STOP_TIME := 0.5
const BOARD_MODEL: PackedScene = preload("res://assets/models/optimized/v4/darts/v02/dartboard_v02.scn")
const DART_MODEL: PackedScene = preload("res://assets/models/optimized/v4/darts/v02/dart_v02.scn")

var aiming := false
## 던지기 전 대기 표시: 조준점 없이 과녁만 천천히 돈다 (조준은 없앴지만 던질 곳이 보이게).
var idle := false
## 결과 글을 보여도 되는가 (꽂히고 뜸 들인 뒤 판이 기울 때). 꽂힌 순간은 stuck.
var settled := false
var stuck := false
var _spin := 0.0
var _aim_radius := 0.0
var _clock := 0.0
var _hit_radius := -1.0
var _hit_angle := 0.0
var _bull := false
var _t := 0.0
var _viewport: SubViewport
var _board: Node3D
var _face: Node3D
var _face_turn := 0.0
var _start_turn := 0.0
var _dart_frame: Node3D
var _dart: Node3D
var _camera: Camera3D
var _reticle: Node3D
## 던질 준비 (1.3.1): 내 차례 대기 과녁 앞에 다트를 들고 있다가, 위로 끌어 던진다 (MainBoard). pull은 끈 거리(px).
var ready_dart: bool = false
var _pull: Vector2 = Vector2.ZERO
const READY_POINT: Vector3 = Vector3(0.95, -0.4, 5.2)
const READY_TILT: Vector3 = Vector3(118.0, 18.0, 156.0)
const READY_SCALE: float = 2.2


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


func set_idle(on: bool) -> void:
	idle = on
	if on:
		aiming = false
		_hit_radius = -1.0
		_t = 0.0
		settled = false
	if is_node_ready():
		_present()
		_sync_rendering()


## 끈 거리를 알려 준다 (대기 과녁의 다트가 따라 움직인다).
func set_pull(pull: Vector2) -> void:
	_pull = pull
	if is_node_ready():
		_present()


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
	if idle:
		_face_turn = _spin
	_aim_radius = 0.5 - 0.5 * cos(_clock / AIM_PERIOD * TAU)
	_present()


## 지금 돌아가 있는 과녁 판의 각도 (바퀴). 던지는 순간 결과 연출이 이 각도에서 이어 돈다.
func face_turn() -> float:
	return _face_turn


## 결과 연출의 과녁 판 각도: 던진 뒤에도 같은 속도로 돌다가, 꽂히면 다트를 꽂은 채 서서히 멈춘다.
static func face_turn_at(start: float, t: float) -> float:
	var speed := 1.0 / SPIN_PERIOD
	if t < FLIGHT_TIME:
		return start + speed * maxf(t, 0.0)
	var u := clampf((t - FLIGHT_TIME) / STOP_TIME, 0.0, 1.0)
	return start + speed * FLIGHT_TIME + speed * STOP_TIME * (2.0 * u - u * u) * 0.5


func begin(details: Dictionary, start_turn: float = 0.0) -> void:
	_start_turn = start_turn
	_face_turn = start_turn
	aiming = false
	idle = false
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
	_face_turn = face_turn_at(_start_turn, _t)
	stuck = _t >= FLIGHT_TIME
	settled = _t >= REVEAL_AT
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
	_viewport.size = Vector2i(SIZE * 1.5)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	texture = _viewport.get_texture()
	_board = BOARD_MODEL.instantiate()
	_board.name = "DartboardModel"
	_viewport.add_child(_board)
	_face = Node3D.new()
	_face.name = "SpinningFace"
	_board.add_child(_face)
	for part: String in FACE_PARTS:
		var mesh: Node3D = _board.get_node_or_null(part)
		if mesh != null:
			mesh.reparent(_face, false)
	_dart_frame = Node3D.new()  # 꽂힌 다트는 과녁 판과 함께 돈다 (다트 위치는 판 기준 좌표)
	_dart_frame.name = "DartFrame"
	_viewport.add_child(_dart_frame)
	_dart = DART_MODEL.instantiate()
	_dart.name = "EmbeddedDart"
	_dart_frame.add_child(_dart)
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
	torus.rings = 16
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
	# 조준 모드(테스트용)는 판 전체가, 그 밖에는 과녁 판만 돈다 (테두리·받침은 그대로). 던지는 순간의 각도에서 결과 연출이 이어 돈다.
	_board.rotation.z = -_spin * TAU if aiming else 0.0
	_face.rotation.z = 0.0 if aiming else -_face_turn * TAU
	_dart_frame.rotation.z = 0.0
	_reticle.visible = aiming
	_reticle.position = Vector3(0.0, _aim_radius * SCORE_RADIUS, 0.22)
	_dart.visible = not aiming and (_hit_radius >= 0.0 or (idle and ready_dart))
	var reveal := smoothstep(FLIGHT_TIME + SUSPENSE, FLIGHT_TIME + SUSPENSE + TILT_TIME, _t) if not aiming else 0.0  # 꽂히고 뜸 들인 뒤에 기운다
	_camera.position = Vector3(5.0 * reveal, 1.6 * reveal, 8.5)
	_camera.look_at(Vector3.ZERO, Vector3.UP)
	if idle and ready_dart and _hit_radius < 0.0:
		# 손가락을 따라 살짝 당겨진다 (아래로 당길수록 몸쪽으로, 좌우는 조금)
		var pull: Vector2 = _pull.limit_length(120.0) / 120.0
		_dart.position = READY_POINT + Vector3(pull.x * 0.55, -pull.y * 0.35, pull.y * 0.6)
		_dart.rotation = Vector3(deg_to_rad(READY_TILT.x - pull.y * 12.0), deg_to_rad(READY_TILT.y + pull.x * 8.0), deg_to_rad(READY_TILT.z))
		_dart.scale = Vector3.ONE * READY_SCALE
		return
	_dart.scale = Vector3.ONE
	if _dart.visible:
		var flight := clampf(_t / FLIGHT_TIME, 0.0, 1.0)
		# 날아가는 동안은 꽂힐 순간의 판 각도를 겨냥하고, 꽂힌 뒤에는 판과 함께 돈다. 날아오는 방향(오른쪽 위 앞)은 화면 기준.
		_dart_frame.rotation.z = -face_turn_at(_start_turn, maxf(_t, FLIGHT_TIME)) * TAU
		_dart.position = hit_point(_hit_radius, _hit_angle) + _dart_frame.basis.inverse() * (Vector3(1.1, 1.3, 5.0) * (1.0 - pow(flight, 3.0)))
		var age := maxf(_t - FLIGHT_TIME, 0.0)
		var wobble := sin(age * 42.0) * exp(-age * 12.0) * 0.045 if stuck else 0.0
		# Wobble pivots about the tip; the authoritative contact point stays fixed.
		_dart.rotation = Vector3(deg_to_rad(-8.0) + wobble, deg_to_rad(8.0) + wobble, 0.0)


func _sync_rendering() -> void:
	var running := (aiming or idle) and is_visible_in_tree()
	set_process(running)
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if running else SubViewport.UPDATE_DISABLED
		if is_visible_in_tree() and not running:
			_request_frame()


func _request_frame() -> void:
	if is_visible_in_tree() and not aiming and not idle:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _exit_tree() -> void:
	set_process(false)
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	# Detach the canvas consumer before its child render target is destroyed.
	texture = null
