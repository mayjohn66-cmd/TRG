extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var folder := "res://assets/models/selection_props/v2/"
	var names := ["icebox_open","icebox_stocked","wrapped_strawberry_chocolate","wrapped_chocolate","wrapped_mint_chocolate","icecream_strawberry_chocolate","icecream_chocolate","icecream_mint_chocolate"]
	var total := 0
	for name: String in names:
		var model := load(folder+name+".glb") as PackedScene
		if model==null: printerr("SELECTION_PROP_FAIL ",name);quit(1);return
		var node := model.instantiate() as Node3D
		root.add_child(node)
		var meshes := node.find_children("*","MeshInstance3D",true,false)
		if meshes.is_empty(): printerr("EMPTY_PROP ",name);quit(1);return
		for child: Node in meshes:
			var mesh := child as MeshInstance3D
			if not mesh.get_aabb().size.is_finite(): printerr("INVALID_BOUNDS ",name);quit(1);return
		total+=meshes.size()
		if name=="cookie_tin_filled":
			if node.find_children("PickCookie_*","",true,false).size()!=5: printerr("MISSING_COOKIES");quit(1);return
		if name=="icebox_stocked":
			if node.find_children("PickWrapped_*","",true,false).size()!=12: printerr("MISSING_PACKETS");quit(1);return
		node.queue_free()
		await process_frame
	for path: String in ["res://assets/models/fortune_cookie/platter_v1/plate_runtime.scn","res://assets/models/fortune_cookie/platter_v1/cookie_platter_heaped.tscn"]:
		var model:=load(path) as PackedScene
		if model==null: printerr("PLATTER_LOAD_FAIL ",path);quit(1);return
		var node:=model.instantiate()
		if path.ends_with("heaped.tscn") and node.find_children("PickCookie_*","Node3D",true,false).size()!=16:
			printerr("PLATTER_COOKIE_COUNT_FAIL");quit(1);return
		node.free()
	print("SELECTION_PROPS_GODOT_OK: ",names.size()+2," models, ",total," mesh instances plus shared platter")
	quit()
