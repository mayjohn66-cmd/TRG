## Four rigid half-round wooden sticks. The engine supplies the result; this
## timeline only tosses and settles into a matching physical face arrangement.
class_name YutThrow3D
extends TextureRect

signal stick_landed(index: int)

const VIEW_SIZE: Vector2 = Vector2(500,300)
const RENDER_SIZE: Vector2i = Vector2i(1000,600)
const LEAD_TIME: float = 0.10
const FLIGHT_TIMES: Array[float] = [0.66,0.70,0.735,0.775]
const REBOUND_TIME: float = 0.22
const RESULT_TIME: float = 1.12
const NAK_RESULT_TIME: float = 1.75
const TOTAL_TIME: float = RESULT_TIME+0.65
const RADIUS: float = 0.27
const HALF_LENGTH: float = 1.15
const TABLE_Y: float = 0.105
const MARKED_STICK: int = 3
## 낙(落)일 때 표시 가락이 떨어지는 판 밖 자리.
const NAK_X: float = 3.1
const NAK_Z: float = 0.6
const FINAL_X: Array[float] = [-1.65,-0.55,0.55,1.65]
const FINAL_Z: Array[float] = [-0.15,0.20,-0.15,0.18]
const FINAL_YAW: Array[float] = [-12.0,5.0,-7.0,12.0]
const CAMERA_HOME: Vector3 = Vector3(0,8.5,9.6)
const CAMERA_TARGET: Vector3 = Vector3(0,0.65,0)
const CAMERA_SIZE: float = 4.5
const WOOD_SHADER: Shader = preload("res://assets/ui/trickcal/yut/yut_wood.gdshader")
const OUTLINE_SHADER: Shader = preload("res://assets/ui/trickcal/yut/yut_outline.gdshader")
const SHADOW_SHADER: Shader = preload("res://assets/ui/trickcal/dice/contact_shadow.gdshader")
static var _body_mesh: ArrayMesh
static var _mark_meshes: Array[ArrayMesh] = []
static var _wood: Texture2D
var render_view: SubViewport
var sticks: Array[Node3D] = []
var shadows: Array[MeshInstance3D] = []
var landed: Array[bool] = [false,false,false,false]
var _rebounded: Array[bool] = [false,false,false,false]
var result_value: int = 1
var settled: bool = false
var _power: float = 0.5
var _camera: Camera3D
var _mat: MeshInstance3D
var _time: float = 0.0
var _nak_target := Vector3(NAK_X, TABLE_Y, NAK_Z)
var _nak_edge_fraction: float = 0.70


func _init() -> void:
	custom_minimum_size = VIEW_SIZE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	render_view = SubViewport.new()
	render_view.name = "YutViewport"
	render_view.size = RENDER_SIZE
	render_view.own_world_3d = true
	render_view.transparent_bg = true
	render_view.gui_disable_input = true
	render_view.msaa_3d = Viewport.MSAA_2X
	render_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(render_view)
	texture = render_view.get_texture()
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = CAMERA_SIZE
	_camera.position = CAMERA_HOME
	render_view.add_child(_camera)
	_camera.look_at(CAMERA_TARGET)
	_camera.current = true
	var mat := MeshInstance3D.new()
	mat.mesh = MahjongSlam3D.rounded_box(Vector3(2.9,0.04,1.70),0.035)
	mat.position.y = 0.05
	var felt := StandardMaterial3D.new()
	felt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	felt.albedo_color = Color("9cbb77")
	mat.material_override = felt
	render_view.add_child(mat)
	_mat = mat
	if _body_mesh == null:
		_body_mesh = make_body_mesh()
		_mark_meshes = [make_mark_mesh(false),make_mark_mesh(true)]
		_wood = load("res://assets/ui/trickcal/yut/YUT_WOOD.png") as Texture2D
	var wood := ShaderMaterial.new()
	wood.shader = WOOD_SHADER
	wood.set_shader_parameter("wood",_wood)
	var ink := ShaderMaterial.new()
	ink.shader = OUTLINE_SHADER
	var carved := StandardMaterial3D.new()
	carved.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	carved.vertex_color_use_as_albedo = true
	for index: int in 4:
		var stick := Node3D.new()
		stick.name = "WoodenYut%d" % index
		render_view.add_child(stick)
		sticks.append(stick)
		var outline := MeshInstance3D.new()
		outline.mesh = _body_mesh
		outline.material_override = ink
		stick.add_child(outline)
		var body := MeshInstance3D.new()
		body.mesh = _body_mesh
		body.material_override = wood
		stick.add_child(body)
		var marks := MeshInstance3D.new()
		marks.mesh = _mark_meshes[1 if index == MARKED_STICK else 0]
		marks.material_override = carved
		stick.add_child(marks)
		var shadow := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(1.1,3.0)
		shadow.mesh = plane
		shadow.position.y = TABLE_Y
		var shade := ShaderMaterial.new()
		shade.shader = SHADOW_SHADER
		shadow.material_override = shade
		render_view.add_child(shadow)
		shadows.append(shadow)


func begin(value: int, power: float) -> void:
	result_value = value
	# Normal throws retain their small cached render target and original framing.
	custom_minimum_size = VIEW_SIZE
	size = VIEW_SIZE
	render_view.size = RENDER_SIZE
	_camera.size = CAMERA_SIZE
	_nak_target = Vector3(NAK_X, TABLE_Y, NAK_Z)
	_nak_edge_fraction = 0.70
	_power = clampf(power,0,1)
	landed = [false,false,false,false]
	_rebounded = [false,false,false,false]
	settled = false
	_time = -0.001
	render_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	apply_time(0.0)
	Sfx.play(&"yut_toss",-6.0,0.0)


static func result_time(value: int) -> float:
	return NAK_RESULT_TIME if value == 0 else RESULT_TIME


## Enlarge only the transparent frame for 낙, keeping pixels per world unit
## unchanged. The fourth stick can cross the real board rim without clipping.
func set_nak_exit(screen_offset: Vector2, edge_fraction: float) -> void:
	var frame := Vector2(maxf(VIEW_SIZE.x, absf(screen_offset.x)*2.0+180.0), maxf(VIEW_SIZE.y, absf(screen_offset.y)*2.0+220.0)).ceil()
	custom_minimum_size = frame
	size = frame
	render_view.size = Vector2i(frame*2.0)
	_camera.size = CAMERA_SIZE*frame.y/VIEW_SIZE.y
	var pixel: Vector2 = (frame/2.0+screen_offset)*2.0
	var ray: Vector3 = _camera.project_ray_normal(pixel)
	var origin: Vector3 = _camera.project_ray_origin(pixel)
	_nak_target = origin+ray*((TABLE_Y-origin.y)/ray.y)
	_nak_edge_fraction = clampf(edge_fraction, 0.2, 0.9)


static func flat_faces(value: int) -> Array[bool]:
	match value:
		0: return [true,false,true,false]  # 낙: 남은 세 가락은 아무렇게나, 표시 가락(3번)은 판 밖으로
		1: return [true,false,false,false]
		2: return [true,true,false,false]
		3: return [true,true,true,false]
		4: return [true,true,true,true]
	return [false,false,false,false]


static func final_orientation(index: int, flat: bool) -> Quaternion:
	return Quaternion(Vector3.UP,deg_to_rad(FINAL_YAW[index]))*Quaternion(Vector3.FORWARD,PI if flat else 0.0)


static func impact_time(index: int) -> float:
	return LEAD_TIME+FLIGHT_TIMES[index]


## Exact support of the un-bevelled half cylinder. The small end bevel lies
## inside this hull, so spinning ends can never cut through the ground.
static func support_height(rotation: Quaternion) -> float:
	var basis := Basis(rotation)
	var a: float = basis.x.y
	var b: float = basis.y.y
	var c: float = basis.z.y
	var cross_section: float = sqrt(a*a+b*b) if b <= 0.0 else absf(a)
	return RADIUS*cross_section+b*RADIUS*0.5+absf(c)*HALF_LENGTH


static func pose_at(seconds: float, index: int, value: int, power: float, nak_target: Vector3 = Vector3(NAK_X, TABLE_Y, NAK_Z), edge_fraction: float = 0.70) -> Transform3D:
	var strength: float = clampf(power,0,1)
	var flight: float = FLIGHT_TIMES[index]
	var u: float = clampf((seconds-LEAD_TIME)/flight,0,1)
	var target: Quaternion = final_orientation(index,flat_faces(value)[index])
	var rotation: Quaternion
	var lift: float
	var progress: float = smoothstep(0.0,1.0,u)
	if seconds < impact_time(index):
		var initial: Quaternion = Quaternion(Vector3.FORWARD,PI)
		rotation = initial.slerp(target,progress)
		var turns: float = 2.0+floorf(strength*1.99)
		rotation *= Quaternion(Vector3.FORWARD,TAU*turns*pow(1.0-u,2.0))
		rotation *= Quaternion(Vector3.RIGHT,sin(PI*u)*(0.18+index*0.025))
		lift = sin(PI*u)*lerpf(1.0,1.45,strength)
	else:
		var rebound: float = clampf((seconds-impact_time(index))/REBOUND_TIME,0,1)
		var decay: float = (1.0-rebound)*(1.0-rebound)
		rotation = target*Quaternion(Vector3.FORWARD,0.07*sin(TAU*rebound)*decay)
		lift = 0.10*sin(PI*rebound)*(1.0-rebound)
	var final_x: float = FINAL_X[index]
	var final_z: float = FINAL_Z[index]
	var x: float = lerpf(FINAL_X[index]*0.56,final_x,progress)
	var z: float = lerpf(0.85+index*0.025,final_z,progress)
	if value == 0 and index == MARKED_STICK and seconds >= impact_time(index):
		# One continuous second hop: three stay put, this stick skips over the rim.
		var escape: float = clampf((seconds-impact_time(index))/(NAK_RESULT_TIME-impact_time(index)),0,1)
		x = lerpf(final_x,nak_target.x,escape)
		z = lerpf(final_z,nak_target.z,escape)
		rotation = target*Quaternion(Vector3.RIGHT,TAU*escape)*Quaternion(Vector3.UP,PI*sin(PI*escape))
		lift = 0.38*sin(PI*escape)-0.8*pow(clampf((escape-edge_fraction)/(1.0-edge_fraction),0,1),2.0)
		return Transform3D(Basis(rotation),Vector3(x,TABLE_Y+support_height(rotation)+lift,z))
	return Transform3D(Basis(rotation),Vector3(x,TABLE_Y+support_height(rotation)+maxf(lift,0),z))


func apply_time(seconds: float) -> void:
	var shake: float = 0.0
	for index: int in 4:
		sticks[index].visible = seconds >= LEAD_TIME
		sticks[index].transform = pose_at(seconds,index,result_value,_power,_nak_target,_nak_edge_fraction)
		var lift: float = maxf(sticks[index].position.y-TABLE_Y-support_height(sticks[index].quaternion),0)
		shadows[index].visible = sticks[index].visible
		if result_value == 0 and index == MARKED_STICK:
			var escape: float = (seconds-impact_time(index))/(NAK_RESULT_TIME-impact_time(index))
			shadows[index].visible = shadows[index].visible and escape < _nak_edge_fraction
		shadows[index].position.x = sticks[index].position.x
		shadows[index].position.z = sticks[index].position.z
		shadows[index].rotation.y = deg_to_rad(FINAL_YAW[index])
		shadows[index].scale = Vector3.ONE*(1.0+lift*0.16)
		(shadows[index].material_override as ShaderMaterial).set_shader_parameter("opacity",0.32/(1.0+lift*1.8))
		var since: float = seconds-impact_time(index)
		if since >= 0 and since < 0.07:
			shake += 0.016*sin(since/0.07*TAU)*(1.0-since/0.07)
		if since >= 0 and not landed[index]:
			landed[index] = true
			if _time < impact_time(index) and since < 0.08:
				Sfx.play(&"yut_clack",-2.0-index*0.5,0.0,0.94+index*0.04)
			stick_landed.emit(index)
		if since >= REBOUND_TIME and not _rebounded[index]:
			_rebounded[index] = true
			if index in [0,2] and since-REBOUND_TIME < 0.06:
				Sfx.play(&"yut_clack",-11.0,0.0,1.10)
	_camera.position = CAMERA_HOME+Vector3(0,shake,0)
	settled = seconds >= result_time(result_value)
	_time = seconds


func displayed_value() -> int:
	if result_value == 0 and settled:
		return 0  # 표시 가락이 판 밖: 낙
	var count: int = 0
	var marked: bool = false
	for index: int in 4:
		if (sticks[index].quaternion*Vector3.DOWN).dot(Vector3.UP)>0.9:
			count += 1
			marked = marked or index == MARKED_STICK
	return 5 if count == 0 else count


## Floor contact in render pixels, for small board-space dust rings. The stick
## and its shadow remain in the same 3D world; no second group bounce is added.
func ground_pixel_at(index: int) -> Vector2:
	var floor_point: Vector3 = pose_at(impact_time(index), index, result_value, _power).origin
	floor_point.y = TABLE_Y
	return _camera.unproject_position(floor_point)


## 펠트 윷판을 보이거나 숨긴다 (보드 마당 위로 던질 때는 마당이 곧 윷판이다).
func set_mat_visible(shown: bool) -> void:
	if _mat != null:
		_mat.visible = shown


func stop_rendering() -> void:
	if render_view != null:
		render_view.render_target_update_mode = SubViewport.UPDATE_DISABLED


static func _triangle(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, points: Array[Vector3], dirs: Array[Vector3], coords: Array[Vector2]) -> void:
	var order: Array[int] = [0,1,2]
	# Godot front faces use clockwise winding, opposite the cross-product normal.
	if (points[1]-points[0]).cross(points[2]-points[0]).dot(dirs[0])>0:
		order = [0,2,1]
	for index: int in order:
		vertices.append(points[index])
		normals.append(dirs[index])
		uvs.append(coords[index])


static func make_body_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	const ARC: int = 24
	var rings: Array[float] = [-HALF_LENGTH,-HALF_LENGTH+0.035,-HALF_LENGTH+0.12,0.0,HALF_LENGTH-0.12,HALF_LENGTH-0.035,HALF_LENGTH]
	var factors: Array[float] = [0.72,0.94,1.0,1.0,1.0,0.94,0.72]
	for ring: int in rings.size()-1:
		for segment: int in ARC:
			var points: Array[Vector3] = []
			var dirs: Array[Vector3] = []
			var coords: Array[Vector2] = []
			for pair: Vector2i in [Vector2i(ring,segment),Vector2i(ring,segment+1),Vector2i(ring+1,segment),Vector2i(ring+1,segment+1)]:
				var angle: float = PI*pair.y/ARC
				points.append(Vector3(cos(angle)*RADIUS*factors[pair.x],sin(angle)*RADIUS*factors[pair.x]-RADIUS*0.5,rings[pair.x]))
				dirs.append(Vector3(cos(angle),sin(angle),-0.55 if pair.x==0 else (0.55 if pair.x==6 else 0.0)).normalized())
				coords.append(Vector2(float(pair.y)/ARC,(rings[pair.x]+HALF_LENGTH)/(2.0*HALF_LENGTH)))
			_triangle(vertices,normals,uvs,[points[0],points[1],points[2]],[dirs[0],dirs[1],dirs[2]],[coords[0],coords[1],coords[2]])
			_triangle(vertices,normals,uvs,[points[1],points[3],points[2]],[dirs[1],dirs[3],dirs[2]],[coords[1],coords[3],coords[2]])
		var flat: Array[Vector3] = [Vector3(-RADIUS*factors[ring],-RADIUS*0.5,rings[ring]),Vector3(RADIUS*factors[ring],-RADIUS*0.5,rings[ring]),Vector3(-RADIUS*factors[ring+1],-RADIUS*0.5,rings[ring+1]),Vector3(RADIUS*factors[ring+1],-RADIUS*0.5,rings[ring+1])]
		for tri: Vector3i in [Vector3i(0,1,2),Vector3i(1,3,2)]:
			var face_points: Array[Vector3] = [flat[tri.x],flat[tri.y],flat[tri.z]]
			var face_uvs: Array[Vector2] = []
			for point: Vector3 in face_points:
				face_uvs.append(Vector2(point.x/(2.0*RADIUS)+0.5,(point.z+HALF_LENGTH)/(2.0*HALF_LENGTH)))
			_triangle(vertices,normals,uvs,face_points,[Vector3.DOWN,Vector3.DOWN,Vector3.DOWN],face_uvs)
	for end: int in [-1,1]:
		var center := Vector3(0,-RADIUS*0.5+RADIUS*0.72*0.4,HALF_LENGTH*end)
		for segment: int in ARC+1:
			var a: float = PI*segment/ARC
			var b: float = PI*((segment+1)%(ARC+1))/ARC
			var p := Vector3(cos(a)*RADIUS*0.72,sin(a)*RADIUS*0.72-RADIUS*0.5,HALF_LENGTH*end)
			var q := Vector3(cos(b)*RADIUS*0.72,sin(b)*RADIUS*0.72-RADIUS*0.5,HALF_LENGTH*end)
			var normal := Vector3(0,0,end)
			_triangle(vertices,normals,uvs,[center,p,q],[normal,normal,normal],[Vector2(0.5,0.5),Vector2(p.x/RADIUS*0.5+0.5,p.y/RADIUS+0.5),Vector2(q.x/RADIUS*0.5+0.5,q.y/RADIUS+0.5)])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh


static func make_mark_mesh(marked: bool) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	for z: float in [-0.66,-0.22,0.22,0.66]:
		_mark_bar(vertices,colors,Vector2(-0.10,z-0.09),Vector2(0.10,z+0.09),0.035,Color("714326"))
		_mark_bar(vertices,colors,Vector2(0.10,z-0.09),Vector2(-0.10,z+0.09),0.035,Color("714326"))
	if marked:
		for segment: int in 24:
			var angle: float = TAU*segment/24.0
			var next: float = TAU*(segment+1)/24.0
			var a: Vector2 = Vector2(cos(angle),sin(angle))
			var b: Vector2 = Vector2(cos(next),sin(next))
			var centre := Vector2(0,0.94)
			_mark_triangle(vertices,colors,[centre+a*0.075,centre+b*0.075,centre+a*0.042],Color("d64d55"))
			_mark_triangle(vertices,colors,[centre+b*0.075,centre+b*0.042,centre+a*0.042],Color("d64d55"))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.DOWN)
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh


static func _mark_bar(vertices: PackedVector3Array, colors: PackedColorArray, a: Vector2, b: Vector2, width: float, ink: Color) -> void:
	var delta: Vector2 = (b-a).normalized()
	var offset: Vector2 = Vector2(-delta.y,delta.x)*width*0.5
	_mark_triangle(vertices,colors,[a+offset,b+offset,a-offset],ink)
	_mark_triangle(vertices,colors,[b+offset,b-offset,a-offset],ink)


static func _mark_triangle(vertices: PackedVector3Array, colors: PackedColorArray, points: Array[Vector2], ink: Color) -> void:
	var p: Array[Vector3] = []
	for point: Vector2 in points:
		p.append(Vector3(point.x,-RADIUS*0.5-0.006,point.y))
	if (p[1]-p[0]).cross(p[2]-p[0]).dot(Vector3.DOWN)>0:
		p.reverse()
	for point: Vector3 in p:
		vertices.append(point)
		colors.append(ink.srgb_to_linear())
