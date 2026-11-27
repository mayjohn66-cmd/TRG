## Split the optimized model without duplicating its shared mesh/material files.
extends SceneTree
const SOURCE:="res://assets/models/optimized/v4/darts/v02/dartboard_v02.scn"
const OUTPUT:="res://assets/models/optimized/v5/darts/"
const FIXED: Array[String]=["BeveledSolidHousing","RaisedCreamEdge","ExtrudedNumbers","FourInsetRivets","RearMountingFeet"]
const ROTATING: Array[String]=["TwelveSolidScoringSectors","RaisedDividerWires"]

func _initialize() -> void:
	var before:=FileAccess.get_sha256(SOURCE)
	var source:Node3D=(load(SOURCE) as PackedScene).instantiate()
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var report:={"source":SOURCE,"source_sha256":before,"parts":[]}
	for spec:Array in [["FixedDartboardFrame","fixed_frame.scn",FIXED],["RotatingDartboardTarget","rotating_target.scn",ROTATING]]:
		var root:=Node3D.new()
		root.name=spec[0]
		for key:StringName in source.get_meta_list(): root.set_meta(key,source.get_meta(key))
		for node_name:String in spec[2]:
			assert(source.has_node(node_name),"Missing authored model part: "+node_name)
			var part:=source.get_node(node_name).duplicate() as Node3D
			root.add_child(part)
			part.owner=root
		var packed:=PackedScene.new()
		assert(packed.pack(root)==OK)
		var path:String=OUTPUT+spec[1]
		assert(ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)==OK)
		root.free()
		var readback:Node3D=(load(path) as PackedScene).instantiate()
		assert(readback.get_child_count()==spec[2].size())
		for node_name:String in spec[2]:
			assert(readback.get_node(node_name).transform.is_equal_approx(source.get_node(node_name).transform))
			assert((readback.get_node(node_name) as MeshInstance3D).mesh==source.get_node(node_name).mesh)
		readback.free()
		report.parts.append({"output":path,"nodes":spec[2],"bytes":FileAccess.get_file_as_bytes(path).size(),"dependencies":ResourceLoader.get_dependencies(path),"saved_readback":true})
	source.free()
	assert(FileAccess.get_sha256(SOURCE)==before,"Original model must remain unchanged")
	var file:=FileAccess.open(OUTPUT+"split-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("DARTBOARD_SPLIT_OK ",JSON.stringify(report))
	quit()
