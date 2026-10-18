## Reusable party toy: a plastic click, or a spring flag and paper confetti.
## Only public outcome/accumulation data enters this scene; no loaded-slot data.
class_name ToyFlagGun3D
extends TextureRect

signal outcome_reached(fired: bool)

const VIEW_SIZE: Vector2 = Vector2(500,300)
const RENDER_SIZE: Vector2i = Vector2i(1000,600)
const CAMERA_HOME: Vector3 = Vector3(0,1.6,12)
const CAMERA_TARGET: Vector3 = Vector3(-0.15,0.10,0)
const CAMERA_SIZE: float = 4.0
const CLICK_TIME: float = 0.32
const SAFE_RESULT_TIME: float = 0.48
const SAFE_TOTAL_TIME: float = 0.85
const FLAG_RESULT_TIME: float = 0.92
const FLAG_TOTAL_TIME: float = 1.65
const FLAG_EXTEND: float = 0.26
const CONFETTI_COUNT: int = 18
const MUZZLE: Vector3 = Vector3(-1.38,0.55,0)
const HOME: Vector3 = Vector3(0.85,0.10,0)
const CONFETTI_COLORS: Array[String] = ["efa3c2","a5db76","f6cd63","8dcfe4","fff0bf"]
const BODY_SHADER: Shader = preload("res://assets/ui/trickcal/dice/toy_die.gdshader")
const FLAG_SHADER: Shader = preload("res://assets/ui/trickcal/revolver/party_flag.gdshader")
var render_view: SubViewport
var settled: bool = false
var fired_result: bool = false
var safe_count: int = 0
var chambers: Array[bool] = [false,false,false,false,false,false]
var flag_root: Node3D
var confetti: Array[MeshInstance3D] = []
var _assembly: Node3D
var _cylinder: Node3D
var _trigger: Node3D
var _pole: MeshInstance3D
var _tip: MeshInstance3D
var _cloth: MeshInstance3D
var _cloth_material: ShaderMaterial
var _pips: Array[ShaderMaterial] = []
var _before_count: int = 0
var _outcome_emitted: bool = false
var _dirty: bool = true
var _time: float = 0.0
static var _cloth_mesh: ArrayMesh
static var _paper_mesh: ArrayMesh
static var _boxes: Dictionary = {}


func _init() -> void:
	custom_minimum_size = VIEW_SIZE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	render_view = SubViewport.new()
	render_view.name = "PartyToyViewport"
	render_view.size = RENDER_SIZE
	render_view.own_world_3d = true
	render_view.transparent_bg = true
	render_view.gui_disable_input = true
	render_view.msaa_3d = Viewport.MSAA_2X
	render_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(render_view)
	texture = render_view.get_texture()
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CAMERA_SIZE
	camera.position = CAMERA_HOME
	render_view.add_child(camera)
	camera.look_at(CAMERA_TARGET)
	camera.current = true
	_assembly = Node3D.new()
	_assembly.position = HOME
	render_view.add_child(_assembly)
	_build_toy()
	_build_flag()
	if _paper_mesh == null:
		_paper_mesh = MahjongSlam3D.rounded_box(Vector3(0.035,0.065,0.007),0.006)
	for index: int in CONFETTI_COUNT:
		var paper := MeshInstance3D.new()
		paper.mesh = _paper_mesh
		paper.material_override = paint(Color(CONFETTI_COLORS[index%CONFETTI_COLORS.size()]))
		paper.visible = false
		render_view.add_child(paper)
		confetti.append(paper)
	reset_state()


func _build_toy() -> void:
	box(_assembly,Vector3(0.69,0.40,0.24),Vector3(0.28,0.37,0),Color("8ecb6a"),0.18)
	box(_assembly,Vector3(0.64,0.19,0.18),Vector3(-0.65,0.55,0),Color("fff0c9"),0.15)
	box(_assembly,Vector3(0.49,0.06,0.20),Vector3(-0.58,0.69,0),Color("a7da79"),0.05)
	var grip: MeshInstance3D = box(_assembly,Vector3(0.23,0.58,0.19),Vector3(0.60,-0.46,0),Color("eea0bd"),0.16)
	grip.rotation.z = -0.25
	for y: float in [-0.24,-0.44,-0.64]:
		box(_assembly,Vector3(0.13,0.022,0.018),Vector3(0.61-y*0.15,y,0.206),Color("fff0c9"),0.015)
	var muzzle := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.13
	ring.outer_radius = 0.25
	ring.rings = 16
	ring.ring_segments = 12
	muzzle.mesh = ring
	muzzle.rotation.z = PI/2.0
	muzzle.position = MUZZLE
	muzzle.material_override = paint(Color("f6bb61"))
	_assembly.add_child(muzzle)
	var inside: MeshInstance3D = cylinder(0.135,0.015,Color("799b5d"))
	inside.position = MUZZLE+Vector3(0.018,0,0)
	inside.rotation.z = PI/2.0
	_assembly.add_child(inside)
	_cylinder = Node3D.new()
	_cylinder.position = Vector3(0.12,0.37,0.30)
	_assembly.add_child(_cylinder)
	var drum: MeshInstance3D = cylinder(0.35,0.13,Color("fff0c9"))
	drum.rotation.x = PI/2.0
	_cylinder.add_child(drum)
	for i: int in 6:
		var dot: MeshInstance3D = cylinder(0.063,0.02,Color("88ae68"))
		var a: float = i*TAU/6.0
		dot.position = Vector3(cos(a)*0.235,sin(a)*0.235,0.081)
		dot.rotation.x = PI/2.0
		_cylinder.add_child(dot)
		_pips.append(dot.material_override as ShaderMaterial)
	var hub: MeshInstance3D = cylinder(0.09,0.026,Color("dfbd6b"))
	hub.position.z = 0.09
	hub.rotation.x = PI/2.0
	_cylinder.add_child(hub)
	var guard := MeshInstance3D.new()
	var donut := TorusMesh.new()
	donut.inner_radius = 0.16
	donut.outer_radius = 0.22
	donut.rings = 20
	donut.ring_segments = 8
	guard.mesh = donut
	guard.position = Vector3(0.13,-0.14,0.05)
	guard.rotation.x = PI/2.0
	guard.material_override = paint(Color("d6bc7b"))
	_assembly.add_child(guard)
	_trigger = Node3D.new()
	_trigger.position = Vector3(0.10,-0.03,0.22)
	_assembly.add_child(_trigger)
	box(_trigger,Vector3(0.055,0.10,0.045),Vector3(0,-0.09,0),Color("f6bb61"),0.04)


func _build_flag() -> void:
	flag_root = Node3D.new()
	flag_root.position = MUZZLE
	_assembly.add_child(flag_root)
	_pole = cylinder(0.026,1.0,Color("d1b66d"))
	_pole.rotation.z = PI/2.0
	flag_root.add_child(_pole)
	_tip = cylinder(0.045,0.055,Color("f6cd63"))
	_tip.rotation.z = PI/2.0
	flag_root.add_child(_tip)
	if _cloth_mesh == null:
		_cloth_mesh = make_flag_mesh()
	_cloth = MeshInstance3D.new()
	_cloth.mesh = _cloth_mesh
	_cloth_material = ShaderMaterial.new()
	_cloth_material.shader = FLAG_SHADER
	_cloth.material_override = _cloth_material
	flag_root.add_child(_cloth)
	flag_root.visible = false


static func paint(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = BODY_SHADER
	material.set_shader_parameter("cream",color)
	return material


static func cylinder(radius: float, height: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	node.mesh = mesh
	node.material_override = paint(color)
	return node


static func box(parent: Node, half: Vector3, at: Vector3, color: Color, radius: float) -> MeshInstance3D:
	radius = minf(radius,minf(half.x,minf(half.y,half.z)))
	var key: String = "%s/%s" % [half,radius]
	if not _boxes.has(key):
		_boxes[key] = MahjongSlam3D.rounded_box(half,radius)
	var mesh := MeshInstance3D.new()
	mesh.mesh = _boxes[key]
	mesh.position = at
	mesh.material_override = paint(color)
	parent.add_child(mesh)
	return mesh


func begin(fired: bool, accumulated: int, lost: int = 0) -> void:
	fired_result = fired
	safe_count = clampi((lost if fired else accumulated)/ToolRussianRoulette.STEPS_PER_EMPTY,0,5)
	_before_count = safe_count if fired else maxi(safe_count-1,0)
	settled = false
	_outcome_emitted = false
	_dirty = true
	_time = 0.0
	render_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	apply_time(0.0)


func reset_state() -> void:
	if not _dirty: return
	fired_result = false
	safe_count = 0
	_before_count = 0
	settled = false
	_outcome_emitted = false
	_time = 0.0
	_assembly.transform = Transform3D(Basis.IDENTITY,HOME)
	_cylinder.rotation.z = 0
	_trigger.rotation.z = 0
	flag_root.hide()
	for paper: MeshInstance3D in confetti: paper.hide()
	for i: int in 6:
		chambers[i] = false
		_pips[i].set_shader_parameter("cream",Color("88ae68"))
	_dirty = false
	render_view.render_target_update_mode = SubViewport.UPDATE_ONCE


func stop_rendering() -> void:
	if render_view != null:
		render_view.render_target_update_mode = SubViewport.UPDATE_DISABLED


func apply_time(seconds: float) -> void:
	_time = maxf(seconds,0.0)
	_assembly.transform = gun_pose_at(_time,fired_result)
	var turn: float = smoothstep(0.06,0.24,_time)
	_cylinder.rotation.z = -(_before_count+turn)*TAU/6.0
	var press: float = smoothstep(0.16,CLICK_TIME,_time)*(1.0-smoothstep(CLICK_TIME,CLICK_TIME+0.16,_time))
	_trigger.rotation.z = -0.35*press
	for i: int in 6:
		chambers[i] = i<(_before_count if _time<CLICK_TIME else safe_count)
		_pips[i].set_shader_parameter("cream",Color("fff7de") if chambers[i] else Color("88ae68"))
	flag_root.visible = fired_result and _time>=CLICK_TIME
	if flag_root.visible:
		var extent: float = 1.8*spring_extension(_time)
		_pole.position.x = -extent/2.0
		_pole.scale.y = maxf(extent,0.001)
		_tip.position.x = -extent
		_cloth.position = Vector3(-extent+0.03,-0.02,0.08)
		var unfurl: float = smoothstep(CLICK_TIME+0.11,CLICK_TIME+0.37,_time)
		_cloth.visible = unfurl>0.001
		_cloth.scale.x = maxf(unfurl,0.001)
		_cloth_material.set_shader_parameter("phase",maxf(_time-CLICK_TIME,0))
	for i: int in CONFETTI_COUNT:
		var age: float = _time-CLICK_TIME
		confetti[i].visible = fired_result and age>=0 and age<1.02
		if confetti[i].visible:
			confetti[i].transform = confetti_pose_at(age,i)
	settled = _time>=result_time(fired_result)
	if _time>=CLICK_TIME and not _outcome_emitted:
		_outcome_emitted = true
		outcome_reached.emit(fired_result)
		if _time-CLICK_TIME<0.07:
			Sfx.play(&"toy_party_pop" if fired_result else &"toy_click",-4.0,0.0)


static func result_time(fired: bool) -> float:
	return FLAG_RESULT_TIME if fired else SAFE_RESULT_TIME


static func total_time(fired: bool) -> float:
	return FLAG_TOTAL_TIME if fired else SAFE_TOTAL_TIME


static func result_caption(fired: bool, accumulated: int, lost: int, can_continue: bool = true) -> String:
	if fired:
		return "뿅! 누적 %d칸 사라짐 · 턴 종료" % lost
	return "찰칵! 누적 %d칸" % accumulated if can_continue else "%d칸 이동 확정" % accumulated


static func spring_extension(seconds: float) -> float:
	var u: float = clampf((seconds-CLICK_TIME)/FLAG_EXTEND,0,1)
	return 1.0-pow(1.0-u,3)


static func gun_pose_at(seconds: float, fired: bool) -> Transform3D:
	var u: float = clampf((seconds-CLICK_TIME)/0.30,0,1)
	var recoil: float = sin(u*PI)*pow(1.0-u,2) if fired else 0.0
	return Transform3D(Basis(Vector3.BACK,-0.22*recoil),HOME+Vector3(0.16*recoil,0.03*recoil,0))


static func confetti_pose_at(age: float, index: int) -> Transform3D:
	var spread: float = lerpf(-0.35,0.95,float(index%9)/8.0)
	var speed: float = 1.1+(index%5)*0.22
	var velocity := Vector3(-speed*cos(spread),speed*sin(spread)+0.45,((index%3)-1)*0.32)
	var origin: Vector3 = HOME+MUZZLE+velocity*age+Vector3(0,-1.1*age*age,0.10)
	var spin := Vector3(index*0.4+age*(3+index%4),index*0.7+age*2.0,age*(4+index%5))
	var shrink: float = 1.0-smoothstep(0.72,1.02,age)
	return Transform3D(Basis.from_euler(spin).scaled(Vector3.ONE*maxf(shrink,0.001)),origin)


static func make_flag_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for row: int in 9:
		for column: int in 21:
			vertices.append(Vector3(column*1.45/20.0,-row*0.78/8.0,0))
			normals.append(Vector3.BACK)
			uv.append(Vector2(column/20.0,row/8.0))
	for row: int in 8:
		for column: int in 20:
			var a: int = row*21+column
			indices.append_array(PackedInt32Array([a,a+1,a+22,a,a+22,a+21]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
