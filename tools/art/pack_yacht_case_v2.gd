## Offline native compression; keeps the editable Blender/GLB sources separate.
extends SceneTree
const SOURCE:="res://assets/models/yacht_case/v2/yacht-case-v2.glb"
const OUTPUT:="res://assets/models/optimized/v5/yacht_case/case.scn"
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT.get_base_dir())
	var model:Node=(load(SOURCE) as PackedScene).instantiate()
	model.scene_file_path=""
	var packed:=PackedScene.new()
	assert(packed.pack(model)==OK)
	assert(ResourceSaver.save(packed,OUTPUT,ResourceSaver.FLAG_COMPRESS|ResourceSaver.FLAG_BUNDLE_RESOURCES)==OK)
	model.free()
	var dependencies:=ResourceLoader.get_dependencies(OUTPUT)
	for dependency:String in dependencies:
		assert(not dependency.contains(".glb"),"Compressed runtime must not depend on a source GLB")
	var readback:=load(OUTPUT) as PackedScene
	assert(readback!=null)
	var instance:=readback.instantiate()
	assert(not instance.find_children("*","MeshInstance3D",true,false).is_empty())
	instance.free()
	print("YACHT_CASE_PACKED bytes=",FileAccess.get_file_as_bytes(OUTPUT).size()," dependencies=",dependencies)
	quit()
