extends SceneTree
var rows: Array[Dictionary]=[]
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var folder:=OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(folder)
	for type: String in ["ImporterMesh","PortableCompressedTexture2D"]:
		var methods: Array=[]
		for method: Dictionary in ClassDB.class_get_method_list(type,true):
			if "lod" in str(method.name) or "surface" in str(method.name) or method.name=="create_from_image": methods.append(method)
		var file:=FileAccess.open(folder.path_join(type+"-api.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(methods,"  "))
	await scan("res://assets/models")
	var file:=FileAccess.open(folder.path_join("model-audit.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"  "))
	print("MODEL_AUDIT_OK: ",rows.size()," resources")
	quit()
func scan(path: String) -> void:
	var directory:=DirAccess.open(path)
	for name: String in directory.get_directories():
		if name!="optimized": await scan(path.path_join(name))
	for name: String in directory.get_files():
		if name.get_extension() not in ["glb","scn","tscn","res"]: continue
		var resource_path:=path.path_join(name)
		var resource:=load(resource_path)
		var meshes: Dictionary={}
		var textures: Dictionary={}
		var hierarchy: Array[String]=[]
		if resource is PackedScene:
			var instance: Node=resource.instantiate()
			collect(instance,meshes,textures,hierarchy)
			instance.free()
		elif resource is Mesh: meshes[resource.get_rid()]=resource
		else: continue
		var triangles:=0
		var vertices:=0
		for mesh: Mesh in meshes.values():
			for surface: int in mesh.get_surface_count():
				var arrays:=mesh.surface_get_arrays(surface)
				if arrays.is_empty(): continue
				var v: int=arrays[Mesh.ARRAY_VERTEX].size()
				vertices+=v
				triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null else v)/3
		rows.append({"path":resource_path,"bytes":FileAccess.get_file_as_bytes(resource_path).size(),"meshes":meshes.size(),"vertices":vertices,"triangles":triangles,"textures":textures.values(),"nodes":hierarchy})
		await process_frame
func collect(node: Node,meshes: Dictionary,textures: Dictionary,hierarchy: Array[String]) -> void:
	hierarchy.append(str(node.name))
	if node is MeshInstance3D:
		var mesh:=node.mesh as Mesh
		if mesh!=null:
			meshes[mesh.get_rid()]=mesh
			for i: int in mesh.get_surface_count():
				var material:=node.get_active_material(i) as BaseMaterial3D
				if material!=null:
					for slot: int in BaseMaterial3D.TEXTURE_MAX:
						var texture:=material.get_texture(slot)
						if texture!=null: textures[texture.get_rid()]={"path":texture.resource_path,"width":texture.get_width(),"height":texture.get_height()}
	for child: Node in node.get_children(): collect(child,meshes,textures,hierarchy)
