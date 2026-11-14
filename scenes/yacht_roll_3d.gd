## Five shared-mesh dice in one transparent viewport. Outcomes come only from
## ToolYacht; the toss ends with each result face square to the camera.
class_name YachtRoll3D
extends TextureRect

const ROLL_TIME: float = 1.05
const STAGGER: float = 0.035
const TOTAL_TIME: float = ROLL_TIME + STAGGER * 4.0
const VIEW_SIZE := Vector2(576.0, 140.0)
const GAP: float = 55.0 / 21.0

var render_view: SubViewport
var dice_nodes: Array[Node3D] = []
var values: Array[int] = [0, 0, 0, 0, 0]
var rolled_indices: Array[int] = []
var settled: bool = true


func _init() -> void:
	size = VIEW_SIZE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	render_view = SubViewport.new()
	render_view.name = "YachtDiceViewport"
	render_view.size = Vector2i(1152, 280)
	render_view.own_world_3d = true
	render_view.transparent_bg = true
	render_view.gui_disable_input = true
	render_view.msaa_3d = Viewport.MSAA_2X
	render_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(render_view)
	texture = render_view.get_texture()
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.0 / 3.0
	camera.position = Vector3(0.0, 0.0, 16.0)
	render_view.add_child(camera)
	camera.current = true
	# Reuse the exact rounded toy body and six painted sides from the D6.
	if DiceRoll3D._body_mesh == null:
		DiceRoll3D._body_mesh = DiceRoll3D._make_body_mesh()
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
			part.mesh = DiceRoll3D._pip_mesh_for(&"D6") if material == paint else DiceRoll3D._body_mesh
			part.material_override = material
			die.add_child(part)
		dice_nodes.append(die)
	show_values(values)


func show_values(faces: Array) -> void:
	values.assign(faces)
	for index: int in 5:
		dice_nodes[index].visible = values[index] > 0
		dice_nodes[index].transform = pose_at(TOTAL_TIME, values[index], index)
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
	for index: int in 5:
		var time: float = seconds if rolled_indices.has(index) else TOTAL_TIME
		dice_nodes[index].transform = pose_at(time, values[index], index)
	settled = seconds >= TOTAL_TIME


func stop_rendering() -> void:
	if render_view != null:
		render_view.render_target_update_mode = SubViewport.UPDATE_DISABLED


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
	var home := Vector3((index - 2) * GAP, 0.0, 0.0)
	var position: Vector3 = home + Vector3((2 - index) * 0.12 * remaining, bounce - 0.13 * remaining, -3.0 * remaining)
	var scale: float = 1.0 - 0.25 * remaining
	return Transform3D(Basis(rotation).scaled(Vector3.ONE * scale), position)
