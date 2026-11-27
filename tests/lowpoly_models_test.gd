## Runtime replacements preserve animation anchors, UVs, materials and scene bounds.
extends SceneTree
var failures: Array[String]=[]
var checked: Dictionary={}
var counts:=0
var checked_textures: Dictionary={}
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	var folder:=args[0] if not args.is_empty() else "user://model-lightweight"
	DirAccess.make_dir_recursive_absolute(folder)
	var map_path:=folder.path_join("runtime-map.json") if not args.is_empty() else "res://assets/models/optimized/v4/model-map.json"
	var file:=FileAccess.open(map_path,FileAccess.READ)
	var mapping: Dictionary=JSON.parse_string(file.get_as_text())
	var before_triangles:=0
	var after_triangles:=0
	var maximum_bounds_error:=0.0
	for source: String in mapping:
		var original:=load(source)
		var replacement:=load(str(mapping[source]))
		if replacement==null: failures.append("Missing "+str(mapping[source]));continue
		verify_dependencies(str(mapping[source]))
		if original is PackedScene:
			var a: Node=original.instantiate()
			var b: Node=replacement.instantiate()
			var old:=nodes(a)
			var fresh:=nodes(b)
			if old.keys()!=fresh.keys(): failures.append("Changed node paths "+source)
			for key: String in old:
				if not fresh.has(key): continue
				var left: Node=old[key]
				var right: Node=fresh[key]
				if left is Node3D and not left.transform.is_equal_approx(right.transform): failures.append("Changed anchor pose "+source+":"+key)
				if left is MeshInstance3D and left.mesh!=null:
					before_triangles+=triangles(left.mesh)
					after_triangles+=triangles(right.mesh)
					var old_box: AABB=left.mesh.get_aabb()
					var new_box: AABB=right.mesh.get_aabb()
					var error: float=maxf(old_box.position.distance_to(new_box.position),old_box.end.distance_to(new_box.end))/maxf(old_box.size.length(),.0001)
					maximum_bounds_error=maxf(maximum_bounds_error,error)
					if error>.065: failures.append("Silhouette bounds changed "+source+":"+key+" error="+str(error))
					if left.mesh.get_surface_count()!=right.mesh.get_surface_count(): failures.append("Missing material surfaces "+key)
					for surface: int in right.mesh.get_surface_count():
						var material: BaseMaterial3D=right.get_active_material(surface) as BaseMaterial3D
						if material!=null:
							for slot: int in BaseMaterial3D.TEXTURE_MAX:
								var texture:=material.get_texture(slot)
								if texture!=null and not checked_textures.has(texture.get_rid()):
									checked_textures[texture.get_rid()]=true
									var image:=texture.get_image()
									if image==null or image.is_empty(): failures.append("Texture pixels missing "+texture.resource_path)
						var arrays: Array=right.mesh.surface_get_arrays(surface)
						for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
							if not vertex.is_finite(): failures.append("Nonfinite mesh "+key);break
						if arrays[Mesh.ARRAY_TEX_UV]!=null:
							for uv: Vector2 in arrays[Mesh.ARRAY_TEX_UV]:
								if not uv.is_finite(): failures.append("Nonfinite UV "+key);break
			counts+=old.size()
			a.free()
			b.free()
		await process_frame
	var report: Dictionary={"models":mapping.size(),"nodes_checked":counts,"scene_instance_triangles_before":before_triangles,"scene_instance_triangles_after":after_triangles,"maximum_relative_bounds_error":maximum_bounds_error,"dependency_resources":checked.size(),"failures":failures}
	file=FileAccess.open(folder.path_join("validation-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	if failures.is_empty(): print("LOWPOLY_MODELS_OK ",mapping.size()," models; ",counts," nodes; bounds error ",maximum_bounds_error)
	else:
		for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
func nodes(root_node: Node) -> Dictionary:
	var result: Dictionary={".":root_node}
	for child: Node in root_node.find_children("*","",true,false): result[str(root_node.get_path_to(child))]=child
	return result
func triangles(mesh: Mesh) -> int:
	var total:=0
	for surface: int in mesh.get_surface_count():
		var arrays:=mesh.surface_get_arrays(surface)
		total+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null else arrays[Mesh.ARRAY_VERTEX].size())/3
	return total
func verify_dependencies(path: String) -> void:
	if checked.has(path): return
	checked[path]=true
	for entry: String in ResourceLoader.get_dependencies(path):
		var dependency:=entry.get_slice("::",2) if "::" in entry else entry
		if dependency.is_empty(): dependency=entry.get_slice("::",0)
		if dependency.begins_with("res://assets/models/") and not dependency.begins_with("res://assets/models/optimized/v4/"):
			failures.append("Legacy dependency would be excluded: "+dependency)
		if dependency.begins_with("res://"): verify_dependencies(dependency)
