## A real six-face toy die rendered into the 2D roll panel. Presentation only:
## the engine supplies the face, and the continuous pose ends on that face.
class_name DiceRoll3D
extends TextureRect

const ROLL_TIME: float = 1.0
const HOLD_TIME: float = 0.35
const VIEW_SIZE: Vector2 = Vector2(280, 232)
const RENDER_SIZE: Vector2i = Vector2i(560, 464)
const BOWL_VIEW_SIZE: Vector2 = Vector2(440, 340)
const BOWL_RENDER_SIZE: Vector2i = Vector2i(880, 680)
const BOWL_MODEL = preload("res://scenes/chinchiro_bowl_model.gd")
const BOWL_SCENE: PackedScene = preload("res://assets/models/optimized/v4/chinchiro/rice_bowl_v01.scn")
const BOWL_CONTACTS: Array[float] = [0.42, 0.70]
const HALF_SIZE: float = 1.0
const ROUND_RADIUS: float = 0.22
const PIP_RADIUS: float = 0.125
const PIP_GAP: float = 0.38
const BODY_SHADER: Shader = preload("res://assets/ui/trickcal/dice/toy_die.gdshader")
const OUTLINE_SHADER: Shader = preload("res://assets/ui/trickcal/dice/toy_outline.gdshader")
const SHADOW_SHADER: Shader = preload("res://assets/ui/trickcal/dice/contact_shadow.gdshader")
const D6_VALUES: Array[int] = [1, 2, 3, 4, 5, 6]
## Physical face axes. Only the normal D6 has opposite values adding to seven.
const FACE_NORMALS: Array[Vector3] = [Vector3.UP, Vector3.BACK, Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.DOWN]
const FACE_U: Array[Vector3] = [Vector3.RIGHT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]
const FACE_V: Array[Vector3] = [Vector3.FORWARD, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.BACK]

static var _body_mesh: ArrayMesh
static var _pip_meshes: Dictionary = {}

var render_view: SubViewport
var die: Node3D
var shadow: MeshInstance3D
var result_face: int = 1
var result_value: int = 1
var settled: bool = false
var _power: float = 0.5
var _tool_id: StringName = &"D6"
var _pips: MeshInstance3D
var _camera: Camera3D
var bowl: Node3D
var _bowl_shadow: MeshInstance3D
var _bowl_entry: Vector2 = Vector2(0.8, 0.6)
## 친치로 (1.3.1 리워크): 사기 주사위 3개. die가 첫째, _extra가 둘째·셋째. 결과 눈·그릇 밖으로 나가는 주사위는 엔진이 정한다.
const CHINCHIRO_DICE: int = 3
## 주사위마다 그릇에 들어오는 시차 (초).
const DIE_STAGGER: float = 0.035
## 주사위 3개가 멈추는 자리 (그릇 바닥 좌표, 서로 겹치지 않게).
const BOWL_RESTS: Array[Vector2] = [Vector2(-1.05, 0.25), Vector2(0.15, -0.55), Vector2(1.05, 0.5)]
## 쇼벤 주사위가 떨어지는 그릇 밖 바닥 (화면 쪽으로 튀어 나와 보이게).
const OUT_REST: Vector2 = Vector2(3.5, 2.2)
var dice_values: Array[int] = []
var out_index: int = -1
var _extra: Array[Node3D] = []
var _extra_shadows: Array[MeshInstance3D] = []
var _dice_faces: Array[int] = []


func _init() -> void:
	custom_minimum_size = VIEW_SIZE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	render_view = SubViewport.new()
	render_view.name = "DiceViewport"
	render_view.size = RENDER_SIZE
	render_view.own_world_3d = true
	render_view.transparent_bg = true
	render_view.gui_disable_input = true
	render_view.msaa_3d = Viewport.MSAA_2X
	render_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(render_view)
	texture = render_view.get_texture()
	var camera := Camera3D.new()
	_camera = camera
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.4
	camera.position = Vector3(6.0, 7.25, 6.0)
	render_view.add_child(camera)
	camera.look_at(Vector3(0.0, 1.25, 0.0))
	camera.current = true
	shadow = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(3.5, 3.5)
	shadow.mesh = plane
	var shadow_material := ShaderMaterial.new()
	shadow_material.shader = SHADOW_SHADER
	shadow.material_override = shadow_material
	shadow.position.y = 0.005
	render_view.add_child(shadow)
	die = _make_die("ToyDie")
	render_view.add_child(die)
	_pips = die.get_node("Pips")
	# 친치로의 둘째·셋째 주사위 (같은 메시를 함께 쓴다, 평소에는 숨김)
	for index: int in CHINCHIRO_DICE - 1:
		var extra: Node3D = _make_die("ToyDie%d" % (index + 2))
		extra.visible = false
		render_view.add_child(extra)
		_extra.append(extra)
		var extra_shadow := MeshInstance3D.new()
		extra_shadow.mesh = shadow.mesh
		var extra_material := ShaderMaterial.new()
		extra_material.shader = SHADOW_SHADER
		extra_shadow.material_override = extra_material
		extra_shadow.visible = false
		render_view.add_child(extra_shadow)
		_extra_shadows.append(extra_shadow)


func _make_die(node_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	if _body_mesh == null:
		_body_mesh = _make_body_mesh()
	var outline := MeshInstance3D.new()
	outline.mesh = _body_mesh
	var ink := ShaderMaterial.new()
	ink.shader = OUTLINE_SHADER
	outline.material_override = ink
	node.add_child(outline)
	var body := MeshInstance3D.new()
	body.mesh = _body_mesh
	var cream := ShaderMaterial.new()
	cream.shader = BODY_SHADER
	body.material_override = cream
	node.add_child(body)
	var pips := MeshInstance3D.new()
	pips.name = "Pips"
	pips.mesh = _pip_mesh_for(&"D6")
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.vertex_color_use_as_albedo = true
	pips.material_override = paint
	node.add_child(pips)
	return node


## 이어서 굴리기 (1.3.1 제자리 점프): 보드에 놓여 있던 주사위 자세에서 시작해 START_BLEND 동안 평소 굴림 자세로 섞여 들어간다.
const START_BLEND: float = 0.24
var _start_pose: Variant = null


func start_from(pose: Transform3D) -> void:
	_start_pose = pose
	apply_time(0.0)


## 지금 주사위 자세 (보드 위 소품이 넘겨준다).
func die_pose() -> Transform3D:
	return die.transform


func _blend_start(pose: Transform3D, seconds: float) -> Transform3D:
	if not (_start_pose is Transform3D) or seconds >= START_BLEND:
		return pose
	var weight: float = smoothstep(0.0, START_BLEND, seconds)
	return (_start_pose as Transform3D).interpolate_with(pose, weight)


func begin(value: int, power: float, tool_id: StringName = &"D6") -> void:
	if tool_id == &"CHINCHIRO":
		begin_chinchiro([4, 5, 6] as Array[int], -1, power)  # 엔진 결과 없이 쓸 때(대기 소품): 4·5·6이 놓인 그릇
		return
	_tool_id = tool_id
	for extra: Node3D in _extra:
		extra.visible = false
	for extra_shadow: MeshInstance3D in _extra_shadows:
		extra_shadow.visible = false
	_start_pose = null
	result_value = value
	result_face = physical_face_for(value, tool_id)
	_pips.mesh = _pip_mesh_for(tool_id)
	_power = clampf(power, 0.0, 1.0)
	settled = false
	_configure_bowl(tool_id == &"CHINCHIRO")
	render_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	apply_time(0.0)


## 친치로: 엔진이 정한 주사위 3개의 눈과 그릇 밖으로 나가는 주사위(쇼벤, 없으면 -1)로 굴린다.
func begin_chinchiro(values: Array[int], out_die: int, power: float) -> void:
	_tool_id = &"CHINCHIRO"
	_start_pose = null
	dice_values = values.duplicate()
	while dice_values.size() < CHINCHIRO_DICE:
		dice_values.append(4)
	out_index = out_die
	_dice_faces.clear()
	for index: int in CHINCHIRO_DICE:
		_dice_faces.append(physical_face_for_die(dice_values[index], index))
	result_value = dice_values[0]
	result_face = _dice_faces[0]
	var mesh: ArrayMesh = _pip_mesh_for(&"CHINCHIRO")
	_pips.mesh = mesh
	for extra: Node3D in _extra:
		(extra.get_node("Pips") as MeshInstance3D).mesh = mesh
		extra.visible = true
	for extra_shadow: MeshInstance3D in _extra_shadows:
		extra_shadow.visible = true
	_power = clampf(power, 0.0, 1.0)
	settled = false
	_configure_bowl(true)
	render_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	apply_time(0.0)


## 같은 눈이 두 면에 있는 사기 주사위: 주사위마다 다른 면을 써서 세 개가 똑같아 보이지 않게 한다.
static func physical_face_for_die(value: int, index: int) -> int:
	var sides: Array[int] = []
	var faces: Array[int] = face_values(&"CHINCHIRO")
	for side: int in faces.size():
		if faces[side] == value:
			sides.append(side + 1)
	return sides[index % sides.size()] if not sides.is_empty() else 1


## 주사위 3개의 지금 윗면 눈 (친치로).
func displayed_values() -> Array[int]:
	var values: Array[int] = []
	var faces: Array[int] = face_values(_tool_id)
	for node: Node3D in _all_dice():
		values.append(faces[top_face(node.quaternion) - 1])
	return values


func _all_dice() -> Array[Node3D]:
	var nodes: Array[Node3D] = [die]
	nodes.append_array(_extra)
	return nodes


static func face_values(tool_id: StringName) -> Array[int]:
	return ToolChinchiro.FACES if tool_id == &"CHINCHIRO" else D6_VALUES


## The outcome is a value, not a physical side number. In particular -6 must
## reach its dedicated marked side instead of being clamped to D6's side 1.
static func physical_face_for(value: int, tool_id: StringName) -> int:
	return maxi(face_values(tool_id).find(value), 0) + 1


func displayed_value() -> int:
	return face_values(_tool_id)[top_face(die.quaternion) - 1]


static func _pip_mesh_for(tool_id: StringName) -> ArrayMesh:
	if not _pip_meshes.has(tool_id):
		_pip_meshes[tool_id] = _make_pip_mesh(tool_id)
	return _pip_meshes[tool_id]


func stop_rendering() -> void:
	if render_view != null:
		render_view.render_target_update_mode = SubViewport.UPDATE_DISABLED


func apply_time(seconds: float) -> void:
	if _tool_id == &"CHINCHIRO":
		_apply_bowl_time(seconds)
		return
	die.transform = _blend_start(pose_at(seconds, result_face, _power), seconds)
	settled = seconds >= ROLL_TIME
	var lift: float = die.position.y - support_height(die.quaternion)
	shadow.position.x = die.position.x
	shadow.position.z = die.position.z
	shadow.scale = Vector3.ONE * (1.0 + lift * 0.18)
	(shadow.material_override as ShaderMaterial).set_shader_parameter("opacity", 0.25 / (1.0 + lift))


func _configure_bowl(enabled: bool) -> void:
	if enabled and bowl == null:
		bowl = BOWL_SCENE.instantiate() as Node3D
		render_view.add_child(bowl)
		_bowl_shadow = MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(7.4, 7.4)
		_bowl_shadow.mesh = plane
		_bowl_shadow.position.y = 0.01
		var shade := ShaderMaterial.new()
		shade.shader = SHADOW_SHADER
		shade.set_shader_parameter("opacity", 0.22)
		_bowl_shadow.material_override = shade
		render_view.add_child(_bowl_shadow)
	if bowl != null:
		bowl.visible = enabled
		_bowl_shadow.visible = enabled
	custom_minimum_size = BOWL_VIEW_SIZE if enabled else VIEW_SIZE
	size = custom_minimum_size
	render_view.size = BOWL_RENDER_SIZE if enabled else RENDER_SIZE
	_camera.size = 6.9 if enabled else 5.4
	_camera.position = Vector3(0, 8.2, 12.0) if enabled else Vector3(6.0, 7.25, 6.0)
	_camera.look_at(Vector3(0, 1.05, 0) if enabled else Vector3(0, 1.25, 0))
	die.scale = Vector3.ONE
	shadow.visible = true
	shadow.scale = Vector3.ONE
	shadow.position = Vector3(0, BOWL_MODEL.FLOOR_Y + 0.012 if enabled else 0.005, 0)
	_bowl_entry = Vector2(0.8, 0.6)


func set_bowl_entry(screen_direction: Vector2) -> void:
	_bowl_entry = Vector2(screen_direction.x, screen_direction.y * 0.65).normalized()
	if _bowl_entry.is_zero_approx():
		_bowl_entry = Vector2(0.8, 0.6)
	if _tool_id == &"CHINCHIRO":
		_apply_bowl_time(0.0)


## Throw into the fixed bowl, glance off the curved side, rebound across the
## floor, and settle on the engine's physical face. No random outcome is drawn.
static func bowl_pose_at(seconds: float, face: int, power: float, entry: Vector2, rest: Vector2 = Vector2(0.08, 0.02), thrown_out: bool = false) -> Transform3D:
	var u: float = clampf(seconds / ROLL_TIME, 0, 1)
	if thrown_out and u >= BOWL_CONTACTS[0]:
		return _out_pose_at(u, seconds, face, power, entry)
	var source: Vector2 = entry.normalized()
	var turn: Quaternion = pose_at(seconds, face, power).basis.get_rotation_quaternion()
	var floor_point: Vector2
	var lift: float
	var flight_progress: float = -1.0
	if u < BOWL_CONTACTS[0]:
		var p: float = u / BOWL_CONTACTS[0]
		flight_progress = p
		floor_point = source * lerpf(3.7, 1.45, smoothstep(0, 1, p))
		lift = 0.0  # Entry height is handled above the rim, below.
	elif u < BOWL_CONTACTS[1]:
		var p: float = (u - BOWL_CONTACTS[0]) / (BOWL_CONTACTS[1]-BOWL_CONTACTS[0])
		floor_point = source * lerpf(1.45, -0.85, p) + source.orthogonal() * sin(PI*p) * 0.22
		lift = sin(PI*p) * lerpf(0.32, 0.50, power)
	else:
		var p: float = (u-BOWL_CONTACTS[1]) / (1.0-BOWL_CONTACTS[1])
		floor_point = (-source*0.85).lerp(rest,1.0-pow(1.0-p,2.0))
		lift = sin(PI*p) * 0.14 * (1.0-p)
	var support: float = BOWL_MODEL.support_y(turn, floor_point)
	var y: float = support + maxf(lift, 0.0)
	if flight_progress >= 0.0:
		# Above/outside the rim there is no ceramic floor to extrapolate upward.
		var rim_clearance: float = minf(support, 3.6)
		y = lerpf(4.5, rim_clearance, flight_progress) + sin(PI*flight_progress)*0.45
	return Transform3D(Basis(turn).scaled(Vector3.ONE * BOWL_MODEL.DIE_SCALE), Vector3(floor_point.x, y, floor_point.y))


## 쇼벤: 첫 벽 충돌 뒤 그릇 테두리를 넘어 바깥 바닥(OUT_REST 쪽)으로 튕겨 나가 한두 번 튀고 멈춘다.
static func _out_pose_at(u: float, seconds: float, face: int, power: float, entry: Vector2) -> Transform3D:
	var source: Vector2 = entry.normalized()
	var turn: Quaternion = pose_at(seconds, face, power).basis.get_rotation_quaternion()
	var outside: Vector2 = Vector2(OUT_REST.x * (-1.0 if source.x > 0.0 else 1.0), OUT_REST.y)  # 들어온 반대쪽으로
	var ground: float = support_height(turn) * BOWL_MODEL.DIE_SCALE
	var start: Vector2 = source * 1.45
	var hop_end: float = 0.82
	var point: Vector2
	var y: float
	if u < hop_end:
		var p: float = (u - BOWL_CONTACTS[0]) / (hop_end - BOWL_CONTACTS[0])
		point = start.lerp(outside, smoothstep(0.0, 1.0, p))
		var start_y: float = BOWL_MODEL.support_y(turn, start)
		y = lerpf(start_y, ground, p) + sin(PI * p) * lerpf(2.6, 3.2, power)  # 테두리(약 1.9)를 넘는 높이
	else:
		var p: float = (u - hop_end) / (1.0 - hop_end)
		point = outside + (outside - start).normalized() * 0.25 * (1.0 - pow(1.0 - p, 2.0))
		y = ground + sin(PI * p) * 0.22 * (1.0 - p)
	return Transform3D(Basis(turn).scaled(Vector3.ONE * BOWL_MODEL.DIE_SCALE), Vector3(point.x, y, point.y))


func _apply_bowl_time(seconds: float) -> void:
	var nodes: Array[Node3D] = _all_dice()
	var shadows: Array[MeshInstance3D] = [shadow]
	shadows.append_array(_extra_shadows)
	var span: float = ROLL_TIME / (ROLL_TIME + DIE_STAGGER * (CHINCHIRO_DICE - 1))  # 마지막 주사위도 ROLL_TIME에 멈춘다
	for index: int in nodes.size():
		var node: Node3D = nodes[index]
		if index > 0 and not node.visible:
			continue
		var local: float = clampf((seconds - DIE_STAGGER * index) / span, 0.0, ROLL_TIME)
		var face: int = _dice_faces[index] if index < _dice_faces.size() else result_face
		var entry: Vector2 = _bowl_entry.rotated((index - 1) * 0.35)
		var rest: Vector2 = BOWL_RESTS[index]
		var pose: Transform3D = bowl_pose_at(local, face, _power, entry, rest, index == out_index)
		node.transform = _blend_start(pose, seconds) if index == 0 else pose
		var outside: bool = index == out_index and node.position.distance_to(Vector3(0, node.position.y, 0)) > 3.2
		var floor_y: float = 0.012 if outside else BOWL_MODEL.FLOOR_Y + 0.012
		var lift: float = maxf(node.position.y - floor_y - BOWL_MODEL.DIE_SCALE, 0.0)
		var shade: MeshInstance3D = shadows[index]
		shade.position = Vector3(node.position.x, floor_y, node.position.z)
		shade.scale = Vector3.ONE * (0.72 + lift * 0.10)
		(shade.material_override as ShaderMaterial).set_shader_parameter("opacity", 0.30/(1.0+lift*1.5))
	settled = seconds >= ROLL_TIME


## Board presenter owns flight and travel in screen space. Keep the 3D die's
## rotation, but do not add a second jump or a fixed left-to-right translation.
func apply_board_time(seconds: float, screen_lift: float) -> void:
	die.transform = pose_at(seconds, result_face, _power)
	var support: float = support_height(die.quaternion)
	var clearance: float = (HALF_SIZE - ROUND_RADIUS) * sqrt(3.0) + ROUND_RADIUS
	die.position = Vector3(0.0, lerpf(support, clearance, smoothstep(0.0, 30.0, screen_lift)), 0.0)
	die.transform = _blend_start(die.transform, seconds)
	settled = seconds >= ROLL_TIME


static func final_orientation(face: int) -> Quaternion:
	var normal: Vector3 = FACE_NORMALS[clampi(face, 1, 6) - 1]
	return Quaternion(Vector3.UP, deg_to_rad(12.0)) * Quaternion(normal, Vector3.UP)


## The rounded cube is a smaller cube plus a radius. Its exact support keeps
## every rotating corner above the table, even at the bounce contacts.
static func support_height(rotation: Quaternion) -> float:
	var basis := Basis(rotation)
	return (HALF_SIZE - ROUND_RADIUS) * (absf(basis.x.y) + absf(basis.y.y) + absf(basis.z.y)) + ROUND_RADIUS


static func pose_at(seconds: float, face: int, power: float) -> Transform3D:
	var u: float = clampf(seconds / ROLL_TIME, 0.0, 1.0)
	var strength: float = clampf(power, 0.0, 1.0)
	var remaining: float = (1.0 - u) * (1.0 - u)
	var rotation: Quaternion = final_orientation(face)
	rotation = rotation * Quaternion(Vector3.RIGHT, TAU * (1.7 + strength * 0.8) * remaining)
	rotation = rotation * Quaternion(Vector3.FORWARD, TAU * (0.8 + strength * 0.3) * remaining)
	rotation = rotation * Quaternion(Vector3.UP, sin(PI * u) * 0.45)
	var lift: float
	if u < 0.48:
		lift = sin(PI * u / 0.48) * lerpf(0.45, 0.85, strength)
	elif u < 0.78:
		lift = sin(PI * (u - 0.48) / 0.30) * lerpf(0.12, 0.25, strength)
	else:
		lift = sin(PI * (u - 0.78) / 0.22) * 0.055
	# In flight the centre follows a smooth arc rather than bobbing once per
	# rotating corner. Near contact blend back to the exact table support.
	var support: float = support_height(rotation)
	var flight_clearance: float = (HALF_SIZE - ROUND_RADIUS) * sqrt(3.0) + ROUND_RADIUS
	var height: float = lerpf(support, flight_clearance, smoothstep(0.0, 0.18, lift)) + maxf(lift, 0.0)
	var position := Vector3(-1.15 * pow(1.0 - u, 3.0), height, 0.0)
	return Transform3D(Basis(rotation), position)


static func top_face(rotation: Quaternion) -> int:
	var best: float = -INF
	var face: int = 1
	for index: int in 6:
		var height: float = (rotation * FACE_NORMALS[index]).dot(Vector3.UP)
		if height > best:
			best = height
			face = index + 1
	return face


static func pip_positions(face: int) -> Array[Vector2]:
	var d: float = PIP_GAP
	match face:
		1: return [Vector2.ZERO]
		2: return [Vector2(-d, -d), Vector2(d, d)]
		3: return [Vector2(-d, -d), Vector2.ZERO, Vector2(d, d)]
		4: return [Vector2(-d, -d), Vector2(d, -d), Vector2(-d, d), Vector2(d, d)]
		5: return [Vector2(-d, -d), Vector2(d, -d), Vector2.ZERO, Vector2(-d, d), Vector2(d, d)]
		6: return [Vector2(-d, -d), Vector2(-d, 0), Vector2(-d, d), Vector2(d, -d), Vector2(d, 0), Vector2(d, d)]
	return []


static func _make_body_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	const SEGMENTS: int = 8
	var inner: float = HALF_SIZE - ROUND_RADIUS
	for face: int in 6:
		var start: int = vertices.size()
		for row: int in SEGMENTS + 1:
			for column: int in SEGMENTS + 1:
				var point: Vector3 = FACE_NORMALS[face] * HALF_SIZE + FACE_U[face] * lerpf(-HALF_SIZE, HALF_SIZE, float(column) / SEGMENTS) + FACE_V[face] * lerpf(-HALF_SIZE, HALF_SIZE, float(row) / SEGMENTS)
				var core: Vector3 = point.clamp(Vector3.ONE * -inner, Vector3.ONE * inner)
				var normal: Vector3 = (point - core).normalized()
				vertices.append(core + normal * ROUND_RADIUS)
				normals.append(normal)
		for row: int in SEGMENTS:
			for column: int in SEGMENTS:
				var a: int = start + row * (SEGMENTS + 1) + column
				var b: int = a + 1
				var d: int = a + SEGMENTS + 1
				indices.append_array(PackedInt32Array([a, d, d + 1, a, d + 1, b]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return preload("res://scenes/web_3d_budget.gd").indexed(mesh)


static func _make_pip_mesh(tool_id: StringName = &"D6") -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	const SIDES: int = 12
	for face: int in 6:
		var value: int = face_values(tool_id)[face]
		var color: Color = (Color("e77970") if value == 1 or value < 0 else Color("36543c")).srgb_to_linear()
		for pip: Vector2 in pip_positions(absi(value)):
			var center: Vector3 = FACE_NORMALS[face] * 1.006 + FACE_U[face] * pip.x + FACE_V[face] * pip.y
			for segment: int in SIDES:
				var angle: float = TAU * segment / SIDES
				var next: float = TAU * (segment + 1) / SIDES
				for point: Vector3 in [center, center + (FACE_U[face] * cos(next) + FACE_V[face] * sin(next)) * PIP_RADIUS, center + (FACE_U[face] * cos(angle) + FACE_V[face] * sin(angle)) * PIP_RADIUS]:
					vertices.append(point)
					normals.append(FACE_NORMALS[face])
					colors.append(color)
		if value < 0:
			# A broad minus above six coral pips. It is face paint, not a seventh pip.
			var corners: Array[Vector2] = [Vector2(-0.18, 0.605), Vector2(-0.18, 0.675), Vector2(0.18, 0.675), Vector2(-0.18, 0.605), Vector2(0.18, 0.675), Vector2(0.18, 0.605)]
			for point: Vector2 in corners:
				vertices.append(FACE_NORMALS[face] * 1.006 + FACE_U[face] * point.x + FACE_V[face] * point.y)
				normals.append(FACE_NORMALS[face])
				colors.append(color)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return preload("res://scenes/web_3d_budget.gd").indexed(mesh)
