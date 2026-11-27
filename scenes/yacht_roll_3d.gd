## Five shared-mesh dice in one transparent viewport. Outcomes come only from
## ToolYacht; the toss ends with each result face square to the camera.
## 1.3.1 주사위 케이스: 아래 펠트 줄(굴린 주사위)과 위 고정 칸 줄(고정한 주사위) 두 줄. 굴린 주사위는 오른쪽 컵에서 쏟아져 나온다.
class_name YachtRoll3D
extends TextureRect

const ROLL_TIME: float = 1.05
const STAGGER: float = 0.035
const TOTAL_TIME: float = ROLL_TIME + STAGGER * 4.0
const VIEW_SIZE := Vector2(768.0, 300.0)
const RENDER_SIZE := Vector2i(960, 375)
const DICE_CENTER := Vector2(288,150)
const PIXELS_PER_UNIT := 42.0
const GAP: float = 55.0 / 21.0
## 줄 높이 (월드 단위, 1단위 = 화면 42px). 펠트 줄은 가운데보다 아래, 고정 칸 줄은 위.
const FELT_Y: float = -1.2
const KEEP_Y: float = 2.0
## 컵 자리 (굴린 주사위가 여기서 쏟아져 나온다).
const CUP: Vector3 = Vector3((724.0-320.0)/42.0, 0.0, 0.0)
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
	show_values(values)


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
	for index: int in 5:
		dice_nodes[index].transform = _pose(index)
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
	var time: float = _time if rolled_indices.has(index) and not kept[index] else TOTAL_TIME
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
	# 오른쪽 컵에서 쏟아져 나와 펠트 위 제자리로 굴러간다 (멀리 있는 주사위일수록 오래 굴러간다)
	var home := Vector3((index - 2) * GAP, FELT_Y, 0.0)
	var position: Vector3 = home.lerp(CUP, remaining) + Vector3(0.0, bounce, -1.2 * remaining)
	var scale: float = 1.0 - 0.18 * remaining
	return Transform3D(Basis(rotation).scaled(Vector3.ONE * scale), position)
