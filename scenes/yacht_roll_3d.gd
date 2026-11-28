## Five shared-mesh dice in one transparent viewport. Outcomes come only from
## ToolYacht; the toss ends with each result face square to the camera.
## 1.3.1 주사위 케이스: 아래 펠트 줄(굴린 주사위)과 위 고정 칸 줄(고정한 주사위) 두 줄. 굴린 주사위는 오른쪽 컵에서 쏟아져 나온다.
class_name YachtRoll3D
extends TextureRect

const ROLL_TIME: float = 1.05
const STAGGER: float = 0.035
## 1.3.1 (기획서 PRESENTATION 2.3 · HANDOFF-008): 컵이 주사위를 품고 흔들린 뒤(CUP_SHAKE) 펠트 쪽으로 기울어(CUP_LEAD까지)
## 입구에서 주사위를 쏟아 낸다. 주사위 움직임(pose_at)은 CUP_LEAD 뒤에 시작하고, 쏟고 나면 컵은 다시 바로 선다.
const CUP_SHAKE: float = 0.34
const CUP_LEAD: float = 0.46
const CUP_TILT: float = deg_to_rad(72.0)
const CUP_HOLD_END: float = CUP_LEAD + 0.30
const CUP_UPRIGHT_END: float = CUP_LEAD + 0.62
const TOTAL_TIME: float = CUP_LEAD + ROLL_TIME + STAGGER * 4.0
const VIEW_SIZE := Vector2(768.0, 300.0)
const RENDER_SIZE := Vector2i(960, 375)
const DICE_CENTER := Vector2(288,150)
const PIXELS_PER_UNIT := 42.0
const GAP: float = 55.0 / 21.0
## 줄 높이 (월드 단위, 1단위 = 화면 42px). 펠트 줄은 가운데보다 아래, 고정 칸 줄은 위.
const FELT_Y: float = -1.2
const KEEP_Y: float = 2.0
## 케이스 화면(800×352, 카메라 x=0)과 이 화면(카메라가 DICE_CENTER에 맞춤)의 월드 좌표 차이: 같은 자리에 그리려고 더한다.
const CASE_TO_DICE: Vector3 = Vector3(80.0 / 42.0, -2.0 / 42.0, 0.0)
## 고정·해제 때 줄을 옮겨 가는 시간.
const MOVE_TIME: float = 0.16
static var _yacht_body_mesh: ArrayMesh

var render_view: SubViewport
var dice_nodes: Array[Node3D] = []
var values: Array[int] = [0, 0, 0, 0, 0]
var rolled_indices: Array[int] = []
var settled: bool = true
## 고정 칸에 올라가 있는가 (주사위마다). 굴리는 동안에도 고정한 주사위는 고정 칸에 가만히 있다.
var kept: Array[bool] = [false, false, false, false, false]
var _lift: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var _time: float = TOTAL_TIME
## 주사위 컵 (케이스에서 떼어 낸 가동 소품): 바닥 가운데가 원점이다.
var cup: MeshInstance3D
static var cup_home: Vector3 = Vector3((724.0 - 320.0) / 42.0, 0.0, -2.0)
static var cup_height: float = 2.9


func _init() -> void:
	size = VIEW_SIZE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func _ready() -> void:
	render_view = SubViewport.new()
	render_view.name = "YachtDiceViewport"
	render_view.size = RENDER_SIZE
	render_view.own_world_3d = true
	render_view.transparent_bg = true
	render_view.gui_disable_input = true
	render_view.msaa_3d = Viewport.MSAA_2X
	render_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(render_view)
	texture = render_view.get_texture()
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = VIEW_SIZE.y/PIXELS_PER_UNIT
	camera.position = Vector3((VIEW_SIZE.x*.5-DICE_CENTER.x)/PIXELS_PER_UNIT,0,16)
	render_view.add_child(camera)
	camera.current = true
	# Same dimensions, radius and painted faces; fewer curve samples at 92px.
	if _yacht_body_mesh == null:
		_yacht_body_mesh=_make_yacht_body()
	var body_material := ShaderMaterial.new()
	body_material.shader = DiceRoll3D.BODY_SHADER
	var ink := ShaderMaterial.new()
	ink.shader = DiceRoll3D.OUTLINE_SHADER
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.vertex_color_use_as_albedo = true
	for index: int in 5:
		var die := Node3D.new()
		die.name = "YachtDie%d" % (index + 1)
		render_view.add_child(die)
		for material: Material in [ink, body_material, paint]:
			var part := MeshInstance3D.new()
			part.mesh = DiceRoll3D._pip_mesh_for(&"D6") if material == paint else _yacht_body_mesh
			part.material_override = material
			die.add_child(part)
		dice_nodes.append(die)
	_build_cup()
	show_values(values)


## 케이스에서 떼어 낸 컵을 이 화면에 세운다. 컵 재질은 빛을 받으므로 케이스 화면과 같은 조명을 둔다 (주사위는 빛을 받지 않는 셰이더라 그대로).
func _build_cup() -> void:
	var split: Dictionary = YachtCase3D.split_model()
	cup_home = (split["pivot"] as Vector3) + CASE_TO_DICE
	cup_height = float(split["height"])
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("e4eadb")
	environment.environment.ambient_light_energy = .65
	render_view.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, -30, 0)
	light.light_energy = 1.1
	render_view.add_child(light)
	cup = MeshInstance3D.new()
	cup.name = "DiceCup"
	cup.mesh = split["cup"]
	render_view.add_child(cup)
	cup.transform = cup_pose_at(TOTAL_TIME)


## 컵 자세: 흔들기(작게 좌우·앞뒤로 기울며 들썩) → 펠트 쪽(왼쪽)으로 기울여 쏟기 → 잠깐 그대로 → 다시 바로 서기.
static func cup_pose_at(seconds: float) -> Transform3D:
	var basis := Basis()
	var offset := Vector3.ZERO
	if seconds < CUP_SHAKE:
		var u: float = seconds / CUP_SHAKE
		var wobble: float = sin(u * TAU * 3.0) * (1.0 - u * 0.4)
		basis = Basis(Vector3.UP, wobble * 0.16) * Basis(Vector3.RIGHT, cos(u * TAU * 3.0) * 0.10)
		offset = Vector3(wobble * 0.14, absf(sin(u * TAU * 3.0)) * 0.18, 0.0)
	else:
		var tilt: float
		if seconds < CUP_LEAD:
			tilt = CUP_TILT * (1.0 - pow(1.0 - (seconds - CUP_SHAKE) / (CUP_LEAD - CUP_SHAKE), 2.0))
		elif seconds < CUP_HOLD_END:
			tilt = CUP_TILT
		else:
			tilt = CUP_TILT * (1.0 - smoothstep(CUP_HOLD_END, CUP_UPRIGHT_END, seconds))
		basis = Basis(Vector3.UP, -tilt)  # 입구(+z)가 왼쪽(-x, 펠트 쪽)으로 돈다
		offset = Vector3(0.0, 0.0, sin(tilt) * 0.35)  # 기울이며 살짝 들어 올린다
	return Transform3D(basis, cup_home + offset)


## 컵 입구 가운데 (쏟을 때 주사위가 나오는 자리, 이 화면 월드 좌표).
static func cup_mouth() -> Vector3:
	var pose: Transform3D = cup_pose_at(CUP_LEAD)
	return pose * Vector3(0.0, 0.0, cup_height * 0.92)


func show_values(faces: Array) -> void:
	values.assign(faces)
	_time = TOTAL_TIME
	for index: int in 5:
		dice_nodes[index].visible = values[index] > 0
		dice_nodes[index].transform = _pose(index)
	settled = true
	# Draw once after a change; idle/hidden panels do not render continuously.
	render_view.render_target_update_mode = SubViewport.UPDATE_ONCE


func begin(faces: Array, rolled: Array) -> void:
	values.assign(faces)
	rolled_indices.assign(rolled)
	settled = false
	for die: Node3D in dice_nodes:
		die.visible = true
	render_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	apply_time(0.0)


func apply_time(seconds: float) -> void:
	_time = seconds
	if cup != null:
		cup.transform = cup_pose_at(seconds)
	for index: int in 5:
		dice_nodes[index].transform = _pose(index)
		# 굴리는 주사위는 컵 안에 있다가 입구에서 나온다 (흔드는 동안은 컵 속이라 안 보인다)
		if rolled_indices.has(index) and not kept[index]:
			dice_nodes[index].visible = values[index] > 0 and seconds - CUP_LEAD - STAGGER * index > 0.0
	settled = seconds >= TOTAL_TIME


## 고정 표시를 바꾼다: 고정한 주사위는 위 고정 칸으로, 푼 주사위는 펠트로 MOVE_TIME 동안 옮겨 간다.
func set_kept(mask: Array) -> void:
	for index: int in 5:
		kept[index] = index < mask.size() and bool(mask[index])
	if render_view != null and is_inside_tree():
		render_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		set_process(true)


## 이 주사위가 화면에서 놓인 자리 (이 노드 좌표, 입력 영역을 맞출 때 쓴다).
func die_center(index: int, on_keep_row: bool) -> Vector2:
	var px: float = PIXELS_PER_UNIT
	var world := Vector2((index - 2) * GAP, KEEP_Y if on_keep_row else FELT_Y)
	return DICE_CENTER + Vector2(world.x, -world.y) * px


func _process(delta: float) -> void:
	var moving: bool = false
	for index: int in 5:
		var target: float = 1.0 if kept[index] else 0.0
		if not is_equal_approx(_lift[index], target):
			_lift[index] = move_toward(_lift[index], target, delta / MOVE_TIME)
			moving = true
	if not moving and settled:
		set_process(false)
		if render_view != null:
			render_view.render_target_update_mode = SubViewport.UPDATE_ONCE
		return
	for index: int in 5:
		dice_nodes[index].transform = _pose(index)


func _pose(index: int) -> Transform3D:
	var time: float = _time - CUP_LEAD if rolled_indices.has(index) and not kept[index] else TOTAL_TIME
	var pose: Transform3D = pose_at(time, values[index], index)
	pose.origin.y += (KEEP_Y - FELT_Y) * smoothstep(0.0, 1.0, _lift[index])
	return pose


func stop_rendering() -> void:
	if render_view != null:
		render_view.render_target_update_mode = SubViewport.UPDATE_DISABLED


## Concentrate the smaller grid on the bevel boundaries, leaving the painted
## face truly flat instead of spreading interpolated corner shading over it.
static func _make_yacht_body() -> ArrayMesh:
	var vertices:=PackedVector3Array()
	var normals:=PackedVector3Array()
	var indices:=PackedInt32Array()
	var inner:=DiceRoll3D.HALF_SIZE-DiceRoll3D.ROUND_RADIUS
	var samples: Array[float]=[-1.0,-inner,0.0,inner,1.0]
	for face:int in 6:
		var start:=vertices.size()
		for row:int in 5:
			for column:int in 5:
				var point:=DiceRoll3D.FACE_NORMALS[face]+DiceRoll3D.FACE_U[face]*samples[column]+DiceRoll3D.FACE_V[face]*samples[row]
				var core:=point.clamp(-Vector3.ONE*inner,Vector3.ONE*inner)
				var normal:=(point-core).normalized()
				vertices.append(core+normal*DiceRoll3D.ROUND_RADIUS)
				normals.append(normal)
		for row:int in 4:
			for column:int in 4:
				var a:=start+row*5+column
				indices.append_array(PackedInt32Array([a,a+5,a+6,a,a+6,a+1]))
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh


static func front_orientation(face: int) -> Quaternion:
	return Quaternion(DiceRoll3D.FACE_NORMALS[clampi(face, 1, 6) - 1], Vector3.BACK)


static func pose_at(seconds: float, face: int, index: int) -> Transform3D:
	var u: float = clampf((seconds - STAGGER * index) / ROLL_TIME, 0.0, 1.0)
	var remaining: float = (1.0 - u) * (1.0 - u)
	var rotation: Quaternion = front_orientation(face)
	rotation = rotation * Quaternion(Vector3.RIGHT, TAU * (1.4 + 0.11 * index) * remaining)
	rotation = rotation * Quaternion(Vector3.UP, TAU * (0.7 + 0.09 * index) * remaining)
	rotation = rotation * Quaternion(Vector3.BACK, sin(PI * u) * (0.28 if index % 2 == 0 else -0.28))
	# Throw into the screen, then make two small contacts. The final 20% is
	# a gentle turn into a front-facing row, never a late value substitution.
	var bounce: float = 0.0
	if u < 0.62:
		bounce = sin(PI * u / 0.62) * 0.22
	elif u < 0.84:
		bounce = sin(PI * (u - 0.62) / 0.22) * 0.09
	else:
		bounce = sin(PI * (u - 0.84) / 0.16) * 0.025
	# 기울인 컵의 입구에서 쏟아져 나와 펠트 위 제자리로 굴러간다 (멀리 있는 주사위일수록 오래 굴러간다)
	var home := Vector3((index - 2) * GAP, FELT_Y, 0.0)
	var position: Vector3 = home.lerp(cup_mouth(), remaining) + Vector3(0.0, bounce, 0.0)
	var scale: float = 1.0 - 0.18 * remaining
	return Transform3D(Basis(rotation).scaled(Vector3.ONE * scale), position)
