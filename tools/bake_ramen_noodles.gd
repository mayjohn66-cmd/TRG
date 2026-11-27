# File: res://tools/bake_ramen_noodles.gd
# Role: 놀이터 라면 그릇의 면발 메시를 미리 구워 assets/models/ramen/noodles_baked.res로 저장한다.
#       ramen_bowl_model.gd의 noodle_mesh()를 바꾸면 다시 실행한다: godot --headless --path . -s res://tools/bake_ramen_noodles.gd
#       원본을 구운 뒤 build_lowpoly_models.gd로 게임용 경량본을 갱신한다.
extends SceneTree

const Model = preload("res://scenes/ramen_bowl_model.gd")
const SOURCE_BAKE_PATH := "res://assets/models/ramen/noodles_baked.res"


func _init() -> void:
	var mesh: ArrayMesh = Model.noodle_mesh()
	var error: Error = ResourceSaver.save(mesh, SOURCE_BAKE_PATH, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		printerr("면발 메시를 저장하지 못했다: %s" % error_string(error))
		quit(1)
		return
	print("baked source %s (%d vertices); rebuild runtime low-poly models next" % [SOURCE_BAKE_PATH, (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()])
	quit(0)
