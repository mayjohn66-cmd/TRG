## Static low-poly case behind the existing dice/input layer; no extra idle rendering.
## 1.3.1 (기획서 PRESENTATION 2.3 · HANDOFF-008): 주사위 컵은 케이스와 떼어 낸 가동 소품이다. 케이스 메시에서 컵 부분을 잘라 내
## YachtRoll3D(주사위와 같은 화면)로 넘긴다. 그쪽에서 컵이 흔들리고 기울어져 입구로 주사위를 쏟는다.
class_name YachtCase3D
extends TextureRect

const MODEL_PATH: String="res://assets/models/optimized/v5/yacht_case/case.scn"
const VIEW_SIZE:=Vector2(800,352)
## 케이스 화면 좌표(월드 x)로 이보다 오른쪽 삼각형은 컵 (케이스 오른쪽 끝 5.71 · 컵 왼쪽 끝 6.22).
const CUP_SPLIT_X: float = 6.0
const CUP_MATERIALS: Array[String] = ["Cup leather", "Cup burgundy lining"]
var render_view: SubViewport
static var _split: Dictionary = {}


## 케이스 모델을 컵 없는 케이스와 컵으로 나눈다 (한 번만, 같은 메시를 함께 쓴다).
## case: 원래 메시 좌표의 케이스 / cup: 컵 바닥 가운데를 원점으로 옮긴 컵 (케이스 화면 월드 축) / pivot: 그 바닥 가운데 (케이스 화면 월드 좌표) / height: 컵 높이
static func split_model() -> Dictionary:
	if not _split.is_empty():
		return _split
	var root: Node3D = (load(MODEL_PATH) as PackedScene).instantiate() as Node3D
	root.rotation.x = PI * .5
	var source: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0]
	var to_world: Transform3D = root.transform * source.transform
	var case_mesh := ArrayMesh.new()
	var cup_parts: Array = []  # [material, tris(world), normals(world), uvs]
	var low := Vector3.INF
	var high := -Vector3.INF
	for surface: int in source.mesh.get_surface_count():
		var arrays: Array = source.mesh.surface_get_arrays(surface)
		var material: Material = source.mesh.surface_get_material(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(vertices.size()))
		var whole_cup: bool = material != null and CUP_MATERIALS.has(material.resource_name)
		var keep := PackedInt32Array()
		var cup_vertices := PackedVector3Array()
		var cup_normals := PackedVector3Array()
		var cup_uvs := PackedVector2Array()
		for tri: int in indices.size() / 3:
			var corner: Array[int] = [indices[tri * 3], indices[tri * 3 + 1], indices[tri * 3 + 2]]
			var centre: Vector3 = (to_world * vertices[corner[0]] + to_world * vertices[corner[1]] + to_world * vertices[corner[2]]) / 3.0
			if whole_cup or centre.x > CUP_SPLIT_X:
				for index: int in corner:
					var world: Vector3 = to_world * vertices[index]
					cup_vertices.append(world)
					cup_normals.append((to_world.basis * normals[index]).normalized() if not normals.is_empty() else Vector3.BACK)
					cup_uvs.append(uvs[index] if not uvs.is_empty() else Vector2.ZERO)
					low = low.min(world)
					high = high.max(world)
			else:
				keep.append_array(PackedInt32Array(corner))
		if not keep.is_empty():
			var kept: Array = arrays.duplicate()
			kept[Mesh.ARRAY_INDEX] = keep
			case_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, kept)
			case_mesh.surface_set_material(case_mesh.get_surface_count() - 1, material)
		if not cup_vertices.is_empty():
			cup_parts.append([material, cup_vertices, cup_normals, cup_uvs])
	# 컵 바닥 가운데(화면에서 먼 쪽 끝 z = 바닥)를 원점으로: 이 점을 축으로 흔들고 기울인다
	var pivot := Vector3((low.x + high.x) * .5, (low.y + high.y) * .5, low.z)
	var cup_mesh := ArrayMesh.new()
	for part: Array in cup_parts:
		var moved := PackedVector3Array()
		for point: Vector3 in (part[1] as PackedVector3Array):
			moved.append(point - pivot)
		var cup_arrays: Array = []
		cup_arrays.resize(Mesh.ARRAY_MAX)
		cup_arrays[Mesh.ARRAY_VERTEX] = moved
		cup_arrays[Mesh.ARRAY_NORMAL] = part[2]
		cup_arrays[Mesh.ARRAY_TEX_UV] = part[3]
		cup_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, cup_arrays)
		cup_mesh.surface_set_material(cup_mesh.get_surface_count() - 1, part[0])
	_split = {"case": case_mesh, "case_transform": source.transform, "cup": cup_mesh, "pivot": pivot, "height": high.z - low.z, "radius": (high.x - low.x) * .5}
	root.free()
	return _split

func _init() -> void:
	size=VIEW_SIZE
	expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode=TextureRect.STRETCH_SCALE
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	if DisplayServer.get_name()=="headless": return # Static artwork has no simulation to run.
	render_view=SubViewport.new()
	render_view.name="YachtCaseViewport"
	render_view.size=Vector2i(800,352)
	render_view.own_world_3d=true
	render_view.transparent_bg=true
	render_view.gui_disable_input=true
	render_view.msaa_3d=Viewport.MSAA_2X
	render_view.render_target_update_mode=SubViewport.UPDATE_ONCE
	add_child(render_view)
	texture=render_view.get_texture()
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=VIEW_SIZE.y/42.0
	camera.position=Vector3(0,0,16)
	render_view.add_child(camera)
	camera.current=true
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("e4eadb")
	environment.environment.ambient_light_energy=.65
	render_view.add_child(environment)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-30,-30,0)
	light.light_energy=1.1
	render_view.add_child(light)
	var model: Node3D=(load(MODEL_PATH) as PackedScene).instantiate() as Node3D
	model.rotation.x=PI*.5 # Blender XY tray faces the same camera as the dice.
	var case_only: MeshInstance3D = model.find_children("*","MeshInstance3D",true,false)[0]
	case_only.mesh = split_model()["case"]  # 컵은 YachtRoll3D가 따로 그린다 (가동 소품)
	for node: Node in model.find_children("*","MeshInstance3D",true,false):
		var mesh:=node as MeshInstance3D
		for surface: int in mesh.mesh.get_surface_count():
			var source:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source!=null and source.resource_name.begins_with("Green felt"):
				var felt:=source.duplicate() as StandardMaterial3D
				felt.albedo_texture=CardMat.FABRIC
				felt.albedo_color*=Color(1.9,1.9,1.9,1)
				felt.uv1_scale=Vector3(3,2,1)
				mesh.set_surface_override_material(surface,felt)
	render_view.add_child(model)

func set_active(enabled: bool) -> void:
	if render_view==null: return
	if enabled:
		preload("res://scenes/web_3d_budget.gd").restore(self)
		render_view.render_target_update_mode=SubViewport.UPDATE_ONCE
	else:
		preload("res://scenes/web_3d_budget.gd").park(self)
