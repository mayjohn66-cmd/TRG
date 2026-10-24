## godot --headless --path . -s res://tools/build_chinchiro_bowl.gd
extends SceneTree
const Model = preload("res://scenes/chinchiro_bowl_model.gd")

func _initialize() -> void:
	var folder: String = "res://assets/models/chinchiro"
	DirAccess.make_dir_recursive_absolute(folder)
	var model: Node3D = Model.make_model()
	var scene := PackedScene.new()
	assert(scene.pack(model)==OK)
	assert(ResourceSaver.save(scene,folder+"/rice_bowl_v01.tscn")==OK)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_scene(model,state)==OK)
	assert(document.write_to_filesystem(state,folder+"/rice_bowl_v01.glb")==OK)
	var reopened: Node3D = (load(folder+"/rice_bowl_v01.tscn") as PackedScene).instantiate()
	var mesh: Mesh = reopened.get_node("SolidCeramic").mesh
	assert(mesh.get_aabb().size.x>6.6 and mesh.get_aabb().size.y>1.8)
	print("CHINCHIRO_BOWL_MODEL_OK: ",mesh.get_faces().size()/3," triangles, ",mesh.get_aabb())
	reopened.free()
	model.free()
	quit(0)
