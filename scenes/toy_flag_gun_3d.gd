## Illustrated 2.5D revolver: independent cylinder/hammer/trigger and three views.
## Source PNGs remain intact; shader masks separate moving parts at runtime.
## Only public outcome/accumulation data enters this scene; no loaded-slot data.
class_name ToyFlagGun3D
extends TextureRect

signal outcome_reached(fired: bool)

const VIEW_SIZE: Vector2 = Vector2(500,300)
const RENDER_SIZE: Vector2i = Vector2i(1000,600)
const CAMERA_HOME: Vector3 = Vector3(0,0.10,12)
const CAMERA_TARGET: Vector3 = Vector3(-0.15,0.10,0)
const CAMERA_SIZE: float = 4.0
const PREP_TIME: float = 2.85
const ART_WIDTH: float = 4.2
const ART_HEIGHT: float = 2.8
const ART_SHADER: Shader = preload("res://assets/ui/trickcal/revolver/revolver_art_v02.gdshader")
const SIDE: Texture2D = preload("res://assets/ui/trickcal/revolver/revolver_side_v02.png")
const REAR: Texture2D = preload("res://assets/ui/trickcal/revolver/revolver_open_v02.png")
const QUARTER: Texture2D = preload("res://assets/ui/trickcal/revolver/revolver_quarter_v02.png")
const CLICK_TIME: float = 0.32
const SAFE_RESULT_TIME: float = 0.48
const SAFE_TOTAL_TIME: float = 0.85
const FLAG_RESULT_TIME: float = 0.92
const FLAG_TOTAL_TIME: float = 1.65
const FLAG_EXTEND: float = 0.26
const CONFETTI_COUNT: int = 18
const MUZZLE: Vector3 = Vector3(-1.98,0.66,0.12)
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
var _profile: Node3D
var _rear: Node3D
var _quarter: MeshInstance3D
var _rear_disk: MeshInstance3D
var _side_drum: MeshInstance3D
var _hammer: Node3D
var _prep_click: bool = false
var _spin_tick: int = -1
var _art_materials: Array[ShaderMaterial] = []
var _morph_parts: Array[Dictionary] = []
var _last_morph: float = -1.0
var _trigger: Node3D
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
	_profile = Node3D.new()
	_profile.name = "IllustratedSideView"
	_assembly.add_child(_profile)
	art_piece(_profile,SIDE,3)
	_cylinder = Node3D.new()
	_cylinder.position = art_point(Vector2(0.586,0.326))
	_profile.add_child(_cylinder)
	_side_drum = art_piece(_cylinder,SIDE,6,Vector2(0.586,0.326))
	_hammer = Node3D.new()
	_hammer.position = art_point(Vector2(0.708,0.284))
	_profile.add_child(_hammer)
	art_piece(_hammer,SIDE,4,Vector2(0.708,0.284))
	_trigger = Node3D.new()
	_trigger.position = art_point(Vector2(0.610,0.510))
	_profile.add_child(_trigger)
	art_piece(_trigger,SIDE,5,Vector2(0.610,0.510))
	_rear = Node3D.new()
	_rear.name = "OpenCylinderView"
	_assembly.add_child(_rear)
	art_piece(_rear,REAR,1)
	_rear_disk = art_piece(_rear,REAR,2,Vector2(0.3307,0.4453))
	_rear_disk.position = art_point(Vector2(0.3307,0.4453))
	_quarter = art_piece(_assembly,QUARTER,7)
	# These views are source illustrations, not a full geometric revolver.
	set_views(0,0,1)


static func art_point(uv: Vector2) -> Vector3:
	return Vector3((uv.x-0.5)*ART_WIDTH,(0.5-uv.y)*ART_HEIGHT,0)


func art_piece(parent: Node3D, image: Texture2D, piece: int, pivot: Vector2 = Vector2(0.5,0.5)) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
	var indices := PackedInt32Array([0,1,2,0,2,3])
	if image==SIDE or image==QUARTER:
		uvs = landmarks(image==SIDE)
		var mean := PackedVector2Array()
		var other: PackedVector2Array = landmarks(image!=SIDE)
		for i: int in uvs.size(): mean.append((uvs[i]+other[i])*0.5)
		indices = Geometry2D.triangulate_delaunay(mean)
	for uv: Vector2 in uvs:
		vertices.append(art_point(uv)-art_point(pivot))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
	node.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = ART_SHADER
	material.set_shader_parameter("art",image)
	material.set_shader_parameter("piece",piece)
	material.render_priority = 2 if image==REAR else (1 if image==QUARTER else 0)
	node.material_override = material
	_art_materials.append(material)
	parent.add_child(node)
	if image==SIDE or image==QUARTER:
		_morph_parts.append({"mesh":mesh,"pivot":pivot})
	return node


## Corresponding contours keep barrel/drum/grip aligned during the view dissolve.
static func landmarks(side: bool) -> PackedVector2Array:
	var pixels: PackedVector2Array
	if side:
		pixels = PackedVector2Array([Vector2(0,0),Vector2(1536,0),Vector2(1536,1024),Vector2(0,1024),Vector2(95,137),Vector2(48,204),Vector2(51,307),Vector2(200,182),Vector2(670,185),Vector2(670,313),Vector2(600,357),Vector2(766,197),Vector2(770,457),Vector2(1024,202),Vector2(1023,460),Vector2(1233,203),Vector2(1110,300),Vector2(1292,377),Vector2(1382,580),Vector2(1482,846),Vector2(1246,883),Vector2(1182,444),Vector2(957,501),Vector2(800,548),Vector2(911,690),Vector2(1070,600),Vector2(952,647),Vector2(400,250),Vector2(1300,650),Vector2(1100,400)])
	else:
		pixels = PackedVector2Array([Vector2(0,0),Vector2(1536,0),Vector2(1536,1024),Vector2(0,1024),Vector2(252,24),Vector2(199,97),Vector2(196,190),Vector2(300,96),Vector2(692,158),Vector2(645,275),Vector2(627,343),Vector2(725,163),Vector2(670,429),Vector2(971,188),Vector2(925,454),Vector2(1183,262),Vector2(1087,383),Vector2(1216,429),Vector2(1318,691),Vector2(1395,948),Vector2(1198,976),Vector2(1104,530),Vector2(940,514),Vector2(780,552),Vector2(896,695),Vector2(1035,635),Vector2(864,642),Vector2(415,202),Vector2(1220,740),Vector2(1040,450)])
	# Exclude silhouette extrema whose depth order changes between projections.
	# The remaining landmarks form one non-folding correspondence mesh.
	pixels.remove_at(19)
	pixels.remove_at(4)
	for i: int in pixels.size(): pixels[i] /= Vector2(1536,1024)
	return pixels


func morph_side_view(amount: float) -> void:
	if is_equal_approx(amount,_last_morph): return
	_last_morph = amount
	var side: PackedVector2Array = landmarks(true)
	var quarter: PackedVector2Array = landmarks(false)
	for part: Dictionary in _morph_parts:
		var vertices := PackedVector3Array()
		for i: int in side.size():
			vertices.append(art_point(quarter[i].lerp(side[i],amount))-art_point(part.pivot))
		(part.mesh as ArrayMesh).surface_update_vertex_region(0,0,vertices.to_byte_array())


func set_views(rear_opacity: float, quarter_opacity: float, side_opacity: float) -> void:
	_rear.visible = rear_opacity>0.001
	_quarter.visible = quarter_opacity>0.001
	_profile.visible = side_opacity>0.001
	for material: ShaderMaterial in _art_materials:
		var source: Texture2D = material.get_shader_parameter("art")
		material.set_shader_parameter("opacity",rear_opacity if source==REAR else (quarter_opacity if source==QUARTER else side_opacity))


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
	var orbit: float = smoothstep(1.35,PREP_TIME,t)
	var enter: float = smoothstep(1.40,1.56,t)
	var morph: float = smoothstep(2.05,2.80,t)
	var side_blend: float = smoothstep(0.40,0.75,morph)
	morph_side_view(morph)
	# Keep the incoming image opaque under the fading image to avoid green ghosts.
	set_views(1.0-enter,(1.0-side_blend) if enter>0.0 else 0.0,1.0 if side_blend>0.0 else 0.0)
	_rear_disk.position = art_point(Vector2(0.3307,0.4453).lerp(Vector2(0.586,0.265),close))
	_rear_disk.scale = Vector3.ONE*lerpf(1.0,0.66,close)
	var spin: float = smoothstep(1.30,2.35,t)
	_rear_disk.rotation.z = -TAU*4.0*spin
	(_side_drum.material_override as ShaderMaterial).set_shader_parameter("spin",spin*4.0)
	(_quarter.material_override as ShaderMaterial).set_shader_parameter("spin",spin*4.0)
	_rear.rotation.y = -0.18*orbit
	_quarter.rotation.y = 0
	_profile.rotation.y = 0
	if t>=1.30 and not _prep_click:
		_prep_click = true
		if t<1.37: Sfx.play(&"toy_click",-6.0,0.0)
	var tick: int = int(spin*18.0)
	if t>=1.30 and t<2.35 and tick!=_spin_tick:
		_spin_tick = tick
		Sfx.play(&"toy_click",-13.0,0.0)
	if t>=PREP_TIME:
		show_side()


static func preparation_caption(seconds: float) -> String:
	if seconds<0.85: return "여섯 약실 · 한 발 장전"
	if seconds<1.30: return "실린더 결합"
	if seconds<2.35: return "실린더 회전…"
	if seconds<PREP_TIME: return "준비 중…"
	return "발사하거나 정지하세요"


func show_side() -> void:
	morph_side_view(1.0)
	set_views(0,0,1)
	_profile.rotation.y = 0
	(_side_drum.material_override as ShaderMaterial).set_shader_parameter("spin",0.0)


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
	_cylinder.rotation.z = 0
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
	(_side_drum.material_override as ShaderMaterial).set_shader_parameter("spin",turn)
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
