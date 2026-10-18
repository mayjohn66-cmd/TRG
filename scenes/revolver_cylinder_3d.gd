## Standalone revolver cylinder. Six actual through-bores; one removable cartridge.
class_name RevolverCylinder3D
extends Node3D

const RADIUS: float = 1.03
const FACE_RADIUS: float = 0.985
const HALF_LENGTH: float = 0.60
const CHAMBER_CIRCLE: float = 0.62
const BORE_RADIUS: float = 0.215
const LIP_RADIUS: float = 0.235
const AXLE_RADIUS: float = 0.15
const OUTER_SEGMENTS: int = 96
const BORE_SEGMENTS: int = 48
const AXLE_SEGMENTS: int = 32

@export_range(-1,5) var loaded_chamber: int = 2
var drum: MeshInstance3D
var cartridge: Node3D
var _spin: Tween


func _ready() -> void:
	build()


func build() -> void:
	if drum!=null: return
	var steel: StandardMaterial3D = metal(Color("b9c5cf"),0.65,0.28)
	drum = MeshInstance3D.new()
	drum.name = "SixBoreSteelDrum"
	drum.mesh = make_body()
	drum.material_override = steel
	add_child(drum)
	# Rear ejector hub, separate from the six chamber bores.
	add_part(self,"EjectorHub",0.125,1.27,Vector3.ZERO,steel)
	add_part(self,"EjectorCap",0.17,0.035,Vector3(0,0,0.65),steel)
	cartridge = Node3D.new()
	cartridge.name = "SingleLoadedCartridge"
	add_child(cartridge)
	var brass: StandardMaterial3D = metal(Color("d7a34d"),0.68,0.27)
	var rim: StandardMaterial3D = metal(Color("efc56b"),0.60,0.23)
	add_part(cartridge,"BrassCase",0.202,1.08,Vector3(0,0,0.055),brass)
	add_part(cartridge,"CaseRim",0.223,0.032,Vector3(0,0,0.613),rim)
	add_part(cartridge,"PrimerSeat",0.095,0.008,Vector3(0,0,0.634),brass)
	add_part(cartridge,"Primer",0.069,0.012,Vector3(0,0,0.643),metal(Color("d5d1b7"),0.48,0.31))
	set_loaded(loaded_chamber)


func set_loaded(index: int) -> void:
	loaded_chamber = clampi(index,-1,5)
	if cartridge==null: return
	cartridge.visible = loaded_chamber>=0
	if cartridge.visible:
		var center: Vector2 = chamber_center(loaded_chamber)
		cartridge.position = Vector3(center.x,center.y,0)


func spin() -> void:
	if _spin!=null: _spin.kill()
	_spin = create_tween()
	_spin.tween_property(self,"rotation:z",rotation.z+TAU*4.0,1.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


static func chamber_center(index: int) -> Vector2:
	var angle: float = PI/6.0+index*TAU/6.0
	return Vector2(cos(angle),sin(angle))*CHAMBER_CIRCLE


static func metal(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


static func add_part(parent: Node3D, title: String, radius: float, length: float, at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = title
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 64
	node.mesh = mesh
	node.rotation.x = PI/2.0
	node.position = at
	node.material_override = material
	parent.add_child(node)
	return node


static func make_body() -> ArrayMesh:
	var geometry: Dictionary = {"vertices":PackedVector3Array(),"normals":PackedVector3Array()}
	var outline := PackedVector2Array()
	for i: int in OUTER_SEGMENTS:
		outline.append(Vector2.from_angle(TAU*i/OUTER_SEGMENTS)*FACE_RADIUS)
	for hole: int in 6:
		for i: int in BORE_SEGMENTS:
			outline.append(chamber_center(hole)+Vector2.from_angle(TAU*i/BORE_SEGMENTS)*LIP_RADIUS)
	for i: int in AXLE_SEGMENTS:
		outline.append(Vector2.from_angle(TAU*i/AXLE_SEGMENTS)*AXLE_RADIUS)
	var triangles: PackedInt32Array = Geometry2D.triangulate_delaunay(outline)
	for i: int in range(0,triangles.size(),3):
		var a: Vector2 = outline[triangles[i]]
		var b: Vector2 = outline[triangles[i+1]]
		var c: Vector2 = outline[triangles[i+2]]
		var center: Vector2 = (a+b+c)/3.0
		var inside_hole: bool = center.length()<AXLE_RADIUS-0.00001
		for hole: int in 6:
			inside_hole = inside_hole or center.distance_to(chamber_center(hole))<LIP_RADIUS-0.00001
		if inside_hole: continue
		for sign_z: float in [-1.0,1.0]:
			var n := Vector3(0,0,sign_z)
			triangle(geometry,Vector3(a.x,a.y,HALF_LENGTH*sign_z),Vector3(b.x,b.y,HALF_LENGTH*sign_z),Vector3(c.x,c.y,HALF_LENGTH*sign_z),n,n,n)
	# Continuous side walls and beveled outer edges.
	band(geometry,Vector2.ZERO,RADIUS,-0.55,RADIUS,0.55,OUTER_SEGMENTS,1.0)
	band(geometry,Vector2.ZERO,FACE_RADIUS,0.60,RADIUS,0.55,OUTER_SEGMENTS,-1.0)
	band(geometry,Vector2.ZERO,FACE_RADIUS,-0.60,RADIUS,-0.55,OUTER_SEGMENTS,1.0)
	band(geometry,Vector2.ZERO,AXLE_RADIUS,-0.60,AXLE_RADIUS,0.60,AXLE_SEGMENTS,-1.0)
	for hole: int in 6:
		var center: Vector2 = chamber_center(hole)
		band(geometry,center,BORE_RADIUS,-0.55,BORE_RADIUS,0.55,BORE_SEGMENTS,-1.0)
		band(geometry,center,BORE_RADIUS,0.55,LIP_RADIUS,0.60,BORE_SEGMENTS,-1.0)
		band(geometry,center,BORE_RADIUS,-0.55,LIP_RADIUS,-0.60,BORE_SEGMENTS,1.0)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = geometry.vertices
	arrays[Mesh.ARRAY_NORMAL] = geometry.normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh


static func triangle(out: Dictionary, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	# Godot front faces use clockwise winding.
	if (b-a).cross(c-a).dot(na+nb+nc)>0.0:
		out.vertices.append_array(PackedVector3Array([a,c,b]))
		out.normals.append_array(PackedVector3Array([na,nc,nb]))
	else:
		out.vertices.append_array(PackedVector3Array([a,b,c]))
		out.normals.append_array(PackedVector3Array([na,nb,nc]))


static func band(out: Dictionary, center: Vector2, r0: float, z0: float, r1: float, z1: float, count: int, direction: float) -> void:
	for i: int in count:
		var a: Vector2 = Vector2.from_angle(TAU*i/count)
		var b: Vector2 = Vector2.from_angle(TAU*(i+1)/count)
		var p0 := Vector3(center.x+a.x*r0,center.y+a.y*r0,z0)
		var p1 := Vector3(center.x+b.x*r0,center.y+b.y*r0,z0)
		var p2 := Vector3(center.x+b.x*r1,center.y+b.y*r1,z1)
		var p3 := Vector3(center.x+a.x*r1,center.y+a.y*r1,z1)
		var n0: Vector3 = Vector3(a.x*(z1-z0),a.y*(z1-z0),r0-r1).normalized()*direction
		var n1: Vector3 = Vector3(b.x*(z1-z0),b.y*(z1-z0),r0-r1).normalized()*direction
		triangle(out,p0,p1,p2,n0,n1,n1)
		triangle(out,p0,p2,p3,n0,n1,n0)
