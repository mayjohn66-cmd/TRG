## Repeatable straight track for the pastel toy train. Y up, travel toward -X.
## Ends are flush cuts, with five evenly spaced sleeper groups for staged placement.
extends RefCounted

const LENGTH := 3.2
const GAUGE := 1.92
const RAIL_TOP := 0.40
const SLEEPER_COUNT := 5
const SLEEPER_PITCH := LENGTH/SLEEPER_COUNT
const SLEEPER_WIDTH := 2.75
const GEOMETRY = preload("res://scenes/runaway_train_3d.gd")
var geometry = GEOMETRY.new()
var root: Node3D
var materials: Dictionary = {}
var shapes: Dictionary = {}

func build() -> Node3D:
	root = Node3D.new()
	root.name = "RunawayStraightTrackV01"
	for entry: Array in [["sleeper","c8986f",0.0,0.65],["chair","879692",0.15,0.45],["rail_head","b2c5cc",0.45,0.31],["rail_web","718991",0.25,0.48],["rail_foot","879e9f",0.25,0.40],["fastener","d5ad70",0.25,0.40]]:
		var material := StandardMaterial3D.new()
		material.resource_name = entry[0]
		material.albedo_color = Color(entry[1])
		material.metallic = entry[2]
		material.roughness = entry[3]
		materials[entry[0]] = material
	var sleepers := _group(root,"Sleepers")
	for index: int in SLEEPER_COUNT:
		var sleeper := _group(sleepers,"Sleeper%02d" % (index+1))
		sleeper.position.x = -LENGTH/2.0+SLEEPER_PITCH*(index+0.5)
		_box(sleeper,"RoundedTimber",Vector3(0.34,0.15,SLEEPER_WIDTH),Vector3(0,0.075,0),"sleeper",0.04)
		for side: float in [-1.0,1.0]:
			var chair := _group(sleeper,"LeftChair" if side<0.0 else "RightChair")
			chair.position = Vector3(0,0,side*GAUGE/2.0)
			_box(chair,"SteelSeatPlate",Vector3(0.29,0.035,0.47),Vector3(0,0.1625,0),"chair",0.014)
			for edge: float in [-1.0,1.0]:
				_part(chair,"RoundedBoltOuter" if edge<0 else "RoundedBoltInner",_bolt_shape(),Vector3(0,0.195,edge*0.19),"fastener")
	for side: float in [-1.0,1.0]:
		var rail := _group(root,"RailLeft" if side<0.0 else "RailRight")
		rail.position.z = side*GAUGE/2.0
		_rail(rail,"WideRailFoot",0.29,0.06,0.18,0.012,"rail_foot")
		_rail(rail,"RecessedRailWeb",0.10,0.15,0.265,0.009,"rail_web")
		_rail(rail,"RoundedRunningHead",0.22,0.07,0.365,0.022,"rail_head")
	for data: Array in [["Start",LENGTH/2.0],["End",-LENGTH/2.0]]:
		var marker := Marker3D.new()
		marker.name = data[0]
		marker.position = Vector3(data[1],RAIL_TOP,0)
		root.add_child(marker)
	root.set_meta("segment_length",LENGTH)
	root.set_meta("rail_gauge",GAUGE)
	root.set_meta("rail_top",RAIL_TOP)
	root.set_meta("sleeper_pitch",SLEEPER_PITCH)
	_own(root)
	return root

func _rail(parent: Node3D, title: String, width: float, height: float, y: float, radius: float, paint: String) -> void:
	var profile := PackedVector2Array()
	# Round only the cross-section: both ends remain exactly +/- LENGTH/2.
	var corners: Array[Vector2] = [Vector2(width/2-radius,height/2-radius),Vector2(-width/2+radius,height/2-radius),Vector2(-width/2+radius,-height/2+radius),Vector2(width/2-radius,-height/2+radius)]
	for corner: int in 4:
		for step: int in 5:
			var angle := (corner*PI/2.0)+float(step)*PI/8.0
			profile.append(corners[corner]+Vector2(cos(angle),sin(angle))*radius)
	profile.reverse()
	var key := "rail_%s_%s_%s" % [str(width),str(height),str(radius)]
	if not shapes.has(key):
		shapes[key] = geometry._extrude(profile,LENGTH)
	var node := _part(parent,title,shapes[key],Vector3(0,y,0),paint)
	node.rotation.y = PI/2.0

func _bolt_shape() -> ArrayMesh:
	if not shapes.has("bolt"):
		shapes["bolt"] = geometry._lathe(PackedVector2Array([Vector2(0,-0.018),Vector2(0.033,-0.018),Vector2(0.045,-0.008),Vector2(0.045,0.008),Vector2(0.033,0.018),Vector2(0,0.018)]),16)
	return shapes["bolt"]

func _box(parent: Node3D, title: String, size: Vector3, at: Vector3, paint: String, bevel: float) -> void:
	var key := "box_%s_%s" % [str(size),str(bevel)]
	if not shapes.has(key):
		shapes[key] = geometry._round_box(size,bevel)
	_part(parent,title,shapes[key],at,paint)

func _part(parent: Node3D, title: String, mesh: Mesh, at: Vector3, paint: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = title
	node.mesh = mesh
	node.material_override = materials[paint]
	node.position = at
	parent.add_child(node,true)
	return node

func _group(parent: Node3D, title: String) -> Node3D:
	var node := Node3D.new()
	node.name = title
	parent.add_child(node)
	return node

func _own(node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = root
		_own(child)
