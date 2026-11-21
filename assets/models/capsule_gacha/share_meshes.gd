@tool
extends EditorScenePostImport


func _post_import(scene: Node) -> Object:
	# Stock capsules differ in paint only. Keep their geometry shared in the web pack.
	var shared: Dictionary = {}
	for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		var mesh := instance.mesh as ArrayMesh
		if mesh == null or mesh.get_surface_count() != 1:
			continue
		var key := var_to_bytes(mesh.surface_get_arrays(0)).hex_encode().sha256_text()
		if shared.has(key):
			var material := mesh.surface_get_material(0)
			instance.mesh = shared[key]
			instance.set_surface_override_material(0, material)
		else:
			shared[key] = mesh
	return scene
