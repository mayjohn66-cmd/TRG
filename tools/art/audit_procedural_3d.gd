extends SceneTree

var rows: Array = []
var folder: String

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	folder = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(folder)
	var factory := ToolWarmup.new()
	root.add_child(factory)
	for id: StringName in ToolWarmup.ORDER:
		var view := factory._make(id)
		root.add_child(view)
		factory._pose(id, view)
		await process_frame
		measure(str(id), view)
		view.free()
	var coin := preload("res://scenes/fate_coin_3d.gd").new()
	root.add_child(coin)
	measure("FATE_COIN", coin)
	coin.free()
	factory.free()
	var output := FileAccess.open(folder.path_join("procedural-budget.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify(rows, "  "))
	print("PROCEDURAL_AUDIT_OK ", rows.size(), " scenes")
	quit()

func measure(id: String, view: Node) -> void:
	var meshes: Dictionary = {}
	var targets: Array = []
	collect(view, meshes, targets)
	var triangles := 0
	var vertices := 0
	var array_bytes := 0
	for mesh: Mesh in meshes.values():
		for surface: int in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			if arrays.is_empty(): continue
			var count: int = arrays[Mesh.ARRAY_VERTEX].size()
			vertices += count
			triangles += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null else count) / 3
			for data: Variant in arrays:
				if data != null: array_bytes += data.to_byte_array().size()
	rows.append({"id":id, "meshes":meshes.size(), "triangles":triangles, "vertices":vertices, "geometry_bytes":array_bytes, "targets":targets})

func collect(node: Node, meshes: Dictionary, targets: Array) -> void:
	if node is MeshInstance3D and node.mesh != null:
		meshes[node.mesh.get_rid()] = node.mesh
	if node is MultiMeshInstance3D and node.multimesh != null:
		var mesh: Mesh = node.multimesh.mesh
		if mesh != null: meshes[mesh.get_rid()] = mesh
	if node is SubViewport:
		targets.append({"width":node.size.x, "height":node.size.y, "msaa":node.msaa_3d, "is_3d":not node.disable_3d})
	for child: Node in node.get_children(): collect(child, meshes, targets)
