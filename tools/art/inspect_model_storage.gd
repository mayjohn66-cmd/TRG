extends SceneTree
func _initialize() -> void:
	var path: String=OS.get_cmdline_user_args()[0]
	print("DEPS ",ResourceLoader.get_dependencies(path))
	var resource:=load(path)
	if resource is PackedScene:
		var node: Node=resource.instantiate()
		var meshes:=node.find_children("*","MeshInstance3D",true,false)
		for i: int in mini(meshes.size(),3):
			var mesh: Mesh=meshes[i].mesh
			print(mesh.resource_path," local=",mesh.resource_local_to_scene," vertices=",mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size())
			if mesh.surface_get_material(0)!=null: print("MAT ",mesh.surface_get_material(0).resource_path)
		node.free()
	quit()
