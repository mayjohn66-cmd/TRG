## A real six-face toy die rendered into the 2D roll panel. Presentation only:
## the engine supplies the face, and the continuous pose ends on that face.
class_name DiceRoll3D
extends TextureRect

const ROLL_TIME: float = 1.0
const HOLD_TIME: float = 0.35
const VIEW_SIZE: Vector2 = Vector2(280, 232)
const RENDER_SIZE: Vector2i = Vector2i(560, 464)
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
	die = Node3D.new()
	die.name = "ToyDie"
	render_view.add_child(die)
	if _body_mesh == null:
		_body_mesh = _make_body_mesh()
	var outline := MeshInstance3D.new()
	outline.mesh = _body_mesh
	var ink := ShaderMaterial.new()
	ink.shader = OUTLINE_SHADER
	outline.material_override = ink
	die.add_child(outline)
	var body := MeshInstance3D.new()
	body.mesh = _body_mesh
	var cream := ShaderMaterial.new()
	cream.shader = BODY_SHADER
	body.material_override = cream
	die.add_child(body)
	_pips = MeshInstance3D.new()
	_pips.mesh = _pip_mesh_for(&"D6")
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.vertex_color_use_as_albedo = true
	_pips.material_override = paint
	die.add_child(_pips)


func begin(value: int, power: float, tool_id: StringName = &"D6") -> void:
	_tool_id = tool_id
	result_value = value
	result_face = physical_face_for(value, tool_id)
	_pips.mesh = _pip_mesh_for(tool_id)
	_power = clampf(power, 0.0, 1.0)
	settled = false
	render_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	apply_time(0.0)


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
	die.transform = pose_at(seconds, result_face, _power)
	settled = seconds >= ROLL_TIME
	var lift: float = die.position.y - support_height(die.quaternion)
	shadow.position.x = die.position.x
	shadow.position.z = die.position.z
	shadow.scale = Vector3.ONE * (1.0 + lift * 0.18)
	(shadow.material_override as ShaderMaterial).set_shader_parameter("opacity", 0.25 / (1.0 + lift))


## Board presenter owns flight and travel in screen space. Keep the 3D die's
## rotation, but do not add a second jump or a fixed left-to-right translation.
func apply_board_time(seconds: float, screen_lift: float) -> void:
	die.transform = pose_at(seconds, result_face, _power)
	var support: float = support_height(die.quaternion)
	var clearance: float = (HALF_SIZE - ROUND_RADIUS) * sqrt(3.0) + ROUND_RADIUS
	die.position = Vector3(0.0, lerpf(support, clearance, smoothstep(0.0, 30.0, screen_lift)), 0.0)
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
	const SEGMENTS: int = 16
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
	return mesh


static func _make_pip_mesh(tool_id: StringName = &"D6") -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	const SIDES: int = 20
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
	return mesh
