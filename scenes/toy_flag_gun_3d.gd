## Real 3D assembly: inspect the open cylinder, close it, spin and orbit to profile.
## Rendering receives only public outcomes, never the engine's loaded chamber/RNG.
class_name ToyFlagGun3D
extends TextureRect

signal outcome_reached(fired: bool)

const VIEW_SIZE: Vector2 = Vector2(500,300)
const RENDER_SIZE: Vector2i = Vector2i(1000,600)
const CAMERA_HOME: Vector3 = Vector3(0,0.10,12)
const CAMERA_TARGET: Vector3 = Vector3(-0.15,0.10,0)
const CAMERA_SIZE: float = 4.0
const PREP_TIME: float = 2.85
const MODEL: PackedScene = preload("res://assets/models/revolver/revolver_assembled_v01.scn")
const MODEL_SCALE: float = 0.245
const OPEN_OFFSET: Vector3 = Vector3(0,0,2.60)
const INSPECT_TARGET: Vector3 = Vector3(0.85,0.1735,0.637)
const CLICK_TIME: float = 0.32
const SAFE_RESULT_TIME: float = 0.48
const SAFE_TOTAL_TIME: float = 0.85
const FLAG_RESULT_TIME: float = 0.92
const FLAG_TOTAL_TIME: float = 1.65
const FLAG_EXTEND: float = 0.26
const CONFETTI_COUNT: int = 18
const MUZZLE: Vector3 = Vector3(-2.156,0.2401,0)
const HOME: Vector3 = Vector3(0.85,0.10,0)
const CONFETTI_COLORS: Array[String] = ["efa3c2","a5db76","f6cd63","8dcfe4","fff0bf"]
const BODY_SHADER: Shader = preload("res://assets/ui/trickcal/dice/toy_die.gdshader")
const FLAG_SHADER: Shader = preload("res://assets/ui/trickcal/revolver/party_flag.gdshader")
var render_view: SubViewport
## Paired-duel preparation shares one sound track while both models animate.
var sound_enabled := true
var settled: bool = false
var fired_result: bool = false
var safe_count: int = 0
var chambers: Array[bool] = [false,false,false,false,false,false]
var flag_root: Node3D
var confetti: Array[MeshInstance3D] = []
var _camera: Camera3D
var _assembly: Node3D
var _model: Node3D
var _mount: Marker3D
var _cylinder: Node3D
var _cartridge: Node3D
var _mount_home: Vector3
var _hammer: Node3D
var _trigger: Node3D
var _prep_click: bool = false
var _spin_tick: int = -1
var _pole: MeshInstance3D
var _tip: MeshInstance3D
var _cloth: MeshInstance3D
var _cloth_material: ShaderMaterial
var _before_count: int = 0
var _outcome_emitted: bool = false
var _dirty: bool = true
var _time: float = 0.0
static var _cloth_mesh: ArrayMesh
static var _paper_mesh: ArrayMesh


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
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	render_view.add_child(_camera)
	_camera.current = true
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("bdcbd9")
	env.ambient_light_energy = 0.65
	world.environment = env
	render_view.add_child(world)
	for data: Array in [[Vector3(-35,-30,0),1.7,Color("fff1db")],[Vector3(25,125,0),1.1,Color("a8c9ff")],[Vector3(-20,180,0),1.0,Color.WHITE]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = data[0]
		light.light_energy = data[1]
		light.light_color = data[2]
		render_view.add_child(light)
	_assembly = Node3D.new()
	_assembly.position = HOME
	render_view.add_child(_assembly)
	_model = MODEL.instantiate()
	_model.scale = Vector3.ONE*MODEL_SCALE
	_assembly.add_child(_model)
	_mount = _model.get_node("Body/CylinderMount")
	_mount_home = _mount.position
	_cylinder = _mount.get_node("Cylinder")
	_cartridge = _cylinder.get_node("SingleLoadedCartridge")
	# Move existing meshes about their own pivots, without changing their rest geometry.
	_hammer = moving_pivot("ExposedCurvedHammer",Vector3(2.24,0.74,0))
	_trigger = moving_pivot("CurvedTrigger",Vector3(0.64,-1.26,0))
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


func moving_pivot(part_name: String, point: Vector3) -> Node3D:
	var body: Node3D = _model.get_node("Body")
	var mesh: MeshInstance3D = body.get_node(part_name)
	var pivot := Node3D.new()
	pivot.name = part_name+"Pivot"
	pivot.position = point
	body.add_child(pivot)
	mesh.reparent(pivot,false)
	mesh.position -= point
	return pivot


func begin_preparation() -> void:
	reset_state()
	_dirty = true
	_prep_click = false
	_spin_tick = -1
	render_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	apply_preparation(0.0)


func apply_preparation(seconds: float) -> void:
	var t: float = clampf(seconds,0,PREP_TIME)
	var close: float = smoothstep(0.85,1.30,t)
	var orbit: float = smoothstep(0.85,PREP_TIME,t)
	var spin: float = smoothstep(1.30,2.35,t)
	_mount.position = _mount_home+OPEN_OFFSET*(1.0-close)
	_cylinder.rotation.z = -TAU*4.0*spin
	# One cosmetic cartridge is visible during inspection only. It encodes no outcome.
	_cartridge.visible = t<1.30
	var target: Vector3 = INSPECT_TARGET.lerp(CAMERA_TARGET,orbit)
	var yaw: float = lerpf(1.39,0.0,orbit)
	var pitch: float = lerpf(0.10,0.0,orbit)
	_camera.position = target+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*12.0
	_camera.size = lerpf(1.25,CAMERA_SIZE,smoothstep(0.85,1.75,t))
	_camera.look_at(target)
	if t>=1.30 and not _prep_click:
		_prep_click = true
		if t<1.37 and sound_enabled: Sfx.play(&"toy_click",-6.0,0.0)
	var tick: int = int(spin*18.0)
	if t>=1.30 and t<2.35 and tick!=_spin_tick:
		_spin_tick = tick
		if sound_enabled: Sfx.play(&"toy_click",-13.0,0.0)
	if t>=PREP_TIME: show_side()


func show_side() -> void:
	_mount.position = _mount_home
	_cartridge.hide()
	_camera.size = CAMERA_SIZE
	_camera.position = CAMERA_HOME
	_camera.look_at(CAMERA_TARGET)
	if render_view.render_target_update_mode!=SubViewport.UPDATE_ALWAYS:
		render_view.render_target_update_mode = SubViewport.UPDATE_ONCE


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


func begin(fired: bool, accumulated: int, lost: int = 0) -> void:
	fired_result = fired
	safe_count = clampi((lost if fired else accumulated)/ToolRussianRoulette.STEPS_PER_EMPTY,0,5)
	_before_count = safe_count if fired else maxi(safe_count-1,0)
	settled = false
	_outcome_emitted = false
	_dirty = true
	_time = 0.0
	render_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	show_side()
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
	_cylinder.rotation.z = -TAU*4.0
	_hammer.rotation.z = 0
	show_side()
	_trigger.rotation.z = 0
	flag_root.hide()
	for paper: MeshInstance3D in confetti: paper.hide()
	for i: int in 6:
		chambers[i] = false

	_dirty = false
	render_view.render_target_update_mode = SubViewport.UPDATE_ONCE


func stop_rendering() -> void:
	if render_view != null:
		render_view.render_target_update_mode = SubViewport.UPDATE_DISABLED


func apply_time(seconds: float) -> void:
	_time = maxf(seconds,0.0)
	_assembly.transform = gun_pose_at(_time,fired_result)
	var turn: float = smoothstep(0.06,0.24,_time)
	_cylinder.rotation.z = -TAU*4.0-TAU/6.0*(_before_count+turn)
	var press: float = smoothstep(0.16,CLICK_TIME,_time)*(1.0-smoothstep(CLICK_TIME,CLICK_TIME+0.16,_time))
	_trigger.rotation.z = 0.18*press
	_hammer.rotation.z = -0.17*smoothstep(0.05,0.25,_time)*(1.0-smoothstep(0.27,CLICK_TIME,_time))
	for i: int in 6:
		chambers[i] = i<(_before_count if _time<CLICK_TIME else safe_count)

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
		if _time-CLICK_TIME<0.07 and sound_enabled:
			Sfx.play(&"toy_party_pop" if fired_result else &"toy_click",-4.0,0.0)


static func result_time(fired: bool) -> float:
	return FLAG_RESULT_TIME if fired else SAFE_RESULT_TIME


static func total_time(fired: bool) -> float:
	return FLAG_TOTAL_TIME if fired else SAFE_TOTAL_TIME


## 발사 결과 문구: 깃발이 나와 턴이 끝날 때만 알린다. 안전한 찰칵(누적·이동 예정 칸)은 글자 없이 총 연출로만 보여 준다.
static func result_caption(fired: bool, _accumulated: int, lost: int, _can_continue: bool = true) -> String:
	if fired:
		return "뿅! 누적 %d칸 사라짐 · 턴 종료" % lost
	return ""


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
