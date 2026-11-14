# File: res://tools/strip_mesh_tangents.gd
# Role: 웹 용량 절감용 일회성 도구. 인라인 ArrayMesh를 쓰는 3D 장면에서 인덱스 없이 정점이 중복된 면을 합치고(SurfaceTool.index) 같은 파일로 다시 저장한다.
# 사용: godot --headless --path . -s res://tools/strip_mesh_tangents.gd -- res://assets/models/.../x.tscn ...
extends SceneTree


func _init() -> void:
	var paths: PackedStringArray = OS.get_cmdline_user_args()
	for path: String in paths:
		var scene: PackedScene = load(path)
		var root: Node = scene.instantiate()
		var cache: Dictionary = {}
		var removed: int = 0
		for node: Node in _walk(root):
			var instance: MeshInstance3D = node as MeshInstance3D
			if instance == null or not (instance.mesh is ArrayMesh):
				continue
			var source: ArrayMesh = instance.mesh
			if not cache.has(source):
				var result: Array = _strip(source)
				cache[source] = result[0]
				removed += int(result[1])
			instance.mesh = cache[source]
		var packed := PackedScene.new()
		packed.pack(root)
		var before: int = FileAccess.get_file_as_bytes(path).size()
		var err: int = ResourceSaver.save(packed, path)
		print("STRIP ", path, " err=", err, " surfaces merged=", removed, " bytes ", before, " -> ", FileAccess.get_file_as_bytes(path).size())
		root.free()
	quit(0)


func _walk(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child: Node in node.get_children():
		out.append_array(_walk(child))
	return out


## 삼각형 면에서 위치·법선·색·UV가 모두 같은 정점을 합치고 인덱스를 붙인다 (모양은 그대로, 정점 수만 준다). 줄지 않는 면은 그대로 둔다. [메시, 합친 면 수]
func _strip(source: ArrayMesh) -> Array:
	var rebuilt := ArrayMesh.new()
	rebuilt.resource_name = source.resource_name
	var merged: int = 0
	for index: int in source.get_surface_count():
		var arrays: Array = source.surface_get_arrays(index)
		var primitive: int = source.surface_get_primitive_type(index)
		if primitive == Mesh.PRIMITIVE_TRIANGLES:
			var tool := SurfaceTool.new()
			tool.create_from(source, index)
			var before: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			tool.index()
			var temp: ArrayMesh = tool.commit()
			var after: int = (temp.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			print("   surface ", index, " verts ", before, " -> ", after)
			if after < before:
				rebuilt.add_surface_from_arrays(primitive, temp.surface_get_arrays(0))
				merged += 1
			else:
				rebuilt.add_surface_from_arrays(primitive, arrays)
		else:
			rebuilt.add_surface_from_arrays(primitive, arrays)
		rebuilt.surface_set_name(index, source.surface_get_name(index))
		rebuilt.surface_set_material(index, source.surface_get_material(index))
	return [rebuilt, merged]
