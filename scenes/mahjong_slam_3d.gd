## Three real rounded solid tiles. Landing time, face exposure and audio share
## one local timeline; the authoritative game clock and outcomes never pause.
class_name MahjongSlam3D
extends TextureRect

## 앞면 렌더 뷰 캐시 상한 (한 번에 3장을 쓴다).
const MAX_FACE_VIEWS: int = 6

signal tile_landed(index: int)

const VIEW_SIZE: Vector2 = Vector2(500,260)
const RENDER_SIZE: Vector2i = Vector2i(1000,520)
const LEAD_TIME: float = 0.10
const FALL_TIME: float = 0.20
const DROP_HEIGHT: float = 0.90
const INTERVAL: float = 0.24
const CONTACT_HOLD: float = 0.035
const SETTLE_TIME: float = 0.15
const RESULT_TIME: float = LEAD_TIME+FALL_TIME+INTERVAL*2.0+SETTLE_TIME
const TOTAL_TIME: float = RESULT_TIME+0.62
const HALF: Vector3 = Vector3(0.64,0.30,0.94)
const RADIUS: float = 0.10
const TABLE_Y: float = 0.115
const CAMERA_SIZE: float = 3.5
const CAMERA_HOME: Vector3 = Vector3(0,8.4,9.3)
const CAMERA_TARGET: Vector3 = Vector3(0,1.0,0)
const BODY_SHADER: Shader = preload("res://assets/ui/trickcal/mahjong/tile_body.gdshader")
const OUTLINE_SHADER: Shader = preload("res://assets/ui/trickcal/dice/toy_outline.gdshader")
const SHADOW_SHADER: Shader = preload("res://assets/ui/trickcal/dice/contact_shadow.gdshader")
static var _body_mesh: ArrayMesh
var render_view: SubViewport
var tiles: Array[Node3D] = []
var shadows: Array[MeshInstance3D] = []
var landed: Array[bool] = [false,false,false]
var tile_ids: Array[int] = []
var _faces: Array[MeshInstance3D] = []
var _face_views: Dictionary = {}
var _back_view: SubViewport
var _camera: Camera3D
var _time: float = 0.0


func _init() -> void:
	custom_minimum_size = VIEW_SIZE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	render_view = SubViewport.new()
	render_view.name = "MahjongViewport"
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
	mat.mesh = rounded_box(Vector3(2.8,0.045,1.47),0.04)
	mat.position.y = 0.05
	var felt := StandardMaterial3D.new()
	felt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	felt.albedo_color = Color("9cbb77")
	mat.material_override = felt
	render_view.add_child(mat)
	_back_view = _make_face_view(-1)
	if _body_mesh == null:
		_body_mesh = rounded_box(HALF,RADIUS)
	for index: int in 3:
		var token := Node3D.new()
		token.name = "MahjongTile%d" % index
		render_view.add_child(token)
		tiles.append(token)
		var outline := MeshInstance3D.new()
		outline.mesh = _body_mesh
		var ink := ShaderMaterial.new()
		ink.shader = OUTLINE_SHADER
		outline.material_override = ink
		token.add_child(outline)
		var body := MeshInstance3D.new()
		body.mesh = _body_mesh
		var material := ShaderMaterial.new()
		material.shader = BODY_SHADER
		body.material_override = material
		token.add_child(body)
		var face: MeshInstance3D = _face_plane(null)
		face.position.y = HALF.y+0.006
		token.add_child(face)
		_faces.append(face)
		var back: MeshInstance3D = _face_plane(_back_view.get_texture())
		back.position.y = -HALF.y-0.006
		back.rotation.x = PI
		token.add_child(back)
		var shadow := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(2.0,2.8)
		shadow.mesh = plane
		shadow.position = Vector3((index-1)*1.63,TABLE_Y,0)
		var shade := ShaderMaterial.new()
		shade.shader = SHADOW_SHADER
		shadow.material_override = shade
		render_view.add_child(shadow)
		shadows.append(shadow)


func _face_plane(face_texture: Texture2D) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.10,1.68)
	var mesh := MeshInstance3D.new()
	mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = face_texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mesh.material_override = material
	return mesh


func _make_face_view(tile: int) -> SubViewport:
	MahjongFace.prepare(tile)
	var viewport := SubViewport.new()
	viewport.size = MahjongFace.FACE_SIZE
	viewport.gui_disable_input = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var face := MahjongFace.new()
	face.tile_id = tile
	face.back = tile < 0
	face.size = Vector2(MahjongFace.FACE_SIZE)
	viewport.add_child(face)
	return viewport


## 패 앞면 렌더 뷰는 최근 MAX_FACE_VIEWS장만 남긴다 (패 종류마다 SubViewport·렌더 타깃을 계속 붙잡으면 웹 메모리가 는다).
func _trim_face_views() -> void:
	while _face_views.size() > MAX_FACE_VIEWS:
		var oldest: int = -999
		for tile: int in _face_views.keys():
			if not tile_ids.has(tile):
				oldest = tile
				break
		if oldest == -999:
			return
		(_face_views[oldest] as Node).queue_free()
		_face_views.erase(oldest)


func begin(values: Array) -> void:
	tile_ids.clear()
	for index: int in 3:
		var tile: int = int(values[index])
		tile_ids.append(tile)
		if not _face_views.has(tile):
			_face_views[tile] = _make_face_view(tile)
		else:
			var view: SubViewport = _face_views[tile]
			_face_views.erase(tile)
			_face_views[tile] = view  # 최근에 쓴 패를 맨 뒤로
		(_faces[index].material_override as StandardMaterial3D).albedo_texture = (_face_views[tile] as SubViewport).get_texture()
	_trim_face_views()
	landed = [false,false,false]
	_time = -0.001
	render_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	apply_time(0.0)


static func impact_time(index: int) -> float:
	return LEAD_TIME+FALL_TIME+index*INTERVAL


static func support_height(rotation: Quaternion) -> float:
	var basis := Basis(rotation)
	var core: Vector3 = HALF-Vector3.ONE*RADIUS
	return absf(basis.x.y)*core.x+absf(basis.y.y)*core.y+absf(basis.z.y)*core.z+RADIUS


static func pose_at(seconds: float, index: int) -> Transform3D:
	var local: float = seconds-LEAD_TIME-index*INTERVAL
	var rotation: Quaternion
	var lift: float
	if local < 0.0:
		rotation = Quaternion(Vector3.RIGHT,PI)
		lift = DROP_HEIGHT
	elif local < FALL_TIME:
		var u: float = clampf(local/FALL_TIME,0,1)
		rotation = Quaternion(Vector3.RIGHT,PI*(1.0-smoothstep(0.0,0.78,u)))
		lift = DROP_HEIGHT*(1.0-u*u*u)
	else:
		var elapsed: float = local-FALL_TIME
		# Hold the contact pose for 35ms, then a single 3cm rebound and settle.
		var rebound: float = clampf((elapsed-CONTACT_HOLD)/(SETTLE_TIME-CONTACT_HOLD),0,1)
		rotation = Quaternion(Vector3.FORWARD,0.018*sin(PI*rebound)*(1.0-rebound))
		lift = 0.035*sin(PI*rebound)*(1.0-rebound)
	return Transform3D(Basis(rotation),Vector3((index-1)*1.63,TABLE_Y+support_height(rotation)+maxf(lift,0),0))


func apply_time(seconds: float) -> void:
	var shake: float = 0.0
	for index: int in 3:
		var start: float = LEAD_TIME+index*INTERVAL
		tiles[index].visible = seconds >= start
		tiles[index].transform = pose_at(seconds,index)
		var lift: float = maxf(tiles[index].position.y-TABLE_Y-support_height(tiles[index].quaternion),0)
		shadows[index].visible = tiles[index].visible
		shadows[index].scale = Vector3.ONE*(1.0+lift*0.22)
		(shadows[index].material_override as ShaderMaterial).set_shader_parameter("opacity",0.38/(1.0+lift*2.5))
		var since_impact: float = seconds-impact_time(index)
		if since_impact >= 0.0 and since_impact < 0.09:
			shake += sin(since_impact/0.09*TAU)*0.022*(1.0-since_impact/0.09)
		if seconds >= impact_time(index) and not landed[index]:
			landed[index] = true
			# A skipped frame catches up visually, without stacking stale sounds.
			if _time < impact_time(index) and since_impact <= 0.09:
				Sfx.play(&"mahjong_tap",-1.5+index*0.5,0.0,0.98+index*0.02)
			tile_landed.emit(index)
	_camera.position = CAMERA_HOME+Vector3(0,shake,0)
	_time = seconds


func stop_rendering() -> void:
	if render_view != null:
		render_view.render_target_update_mode = SubViewport.UPDATE_DISABLED


static func rounded_box(half: Vector3, radius: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	const SEGMENTS: int = 12
	var core_half: Vector3 = half-Vector3.ONE*radius
	for side: int in 6:
		var start: int = vertices.size()
		var n: Vector3 = DiceRoll3D.FACE_NORMALS[side]
		var u: Vector3 = DiceRoll3D.FACE_U[side]
		var v: Vector3 = DiceRoll3D.FACE_V[side]
		for row: int in SEGMENTS+1:
			for col: int in SEGMENTS+1:
				var unit: Vector3 = n+u*lerpf(-1,1,float(col)/SEGMENTS)+v*lerpf(-1,1,float(row)/SEGMENTS)
				var point: Vector3 = unit*half
				var core: Vector3 = point.clamp(-core_half,core_half)
				var normal: Vector3 = (point-core).normalized()
				vertices.append(core+normal*radius)
				normals.append(normal)
		for row: int in SEGMENTS:
			for col: int in SEGMENTS:
				var a: int = start+row*(SEGMENTS+1)+col
				var b: int = a+SEGMENTS+1
				indices.append_array(PackedInt32Array([a,b,b+1,a,b+1,a+1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
