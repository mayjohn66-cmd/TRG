## Standalone revolver cylinder. Six actual through-bores; one removable cartridge.
class_name RevolverCylinder3D
extends Node3D

const RADIUS: float = 1.03
const FACE_RADIUS: float = 0.985
const HALF_LENGTH: float = 0.60
const CHAMBER_CIRCLE: float = 0.62
const BORE_RADIUS: float = 0.215
const LIP_RADIUS: float = 0.245
const AXLE_RADIUS: float = 0.15
const OUTER_SEGMENTS: int = 144
const BORE_SEGMENTS: int = 48
const AXLE_SEGMENTS: int = 32
const FLUTE_DEPTH: float = 0.105
const FLUTE_HALF_WIDTH: float = 0.24

@export_range(-1,5) var loaded_chamber: int = 2
var drum: MeshInstance3D
var cartridge: Node3D
var _spin: Tween


func _ready() -> void:
	build()


func build() -> void:
	if drum!=null: return
	var steel: StandardMaterial3D = metal(Color("a8b4c0"),0.70,0.34)
	drum = MeshInstance3D.new()
	drum.name = "SixBoreSteelDrum"
	drum.mesh = make_body()
	drum.material_override = steel
	add_child(drum)
	# Rear extractor: six broad arms between chambers and a small hexagonal hub.
	add_part(self,"EjectorHub",0.125,1.27,Vector3.ZERO,steel)
	var extractor := MeshInstance3D.new()
	extractor.name = "SixArmExtractor"
	extractor.mesh = make_extractor()
	extractor.material_override = metal(Color("7e8d9b"),0.72,0.31)
	add_child(extractor)
	add_part(self,"ExtractorWasher",0.137,0.018,Vector3(0,0,0.670),steel)
	var bolt: MeshInstance3D = add_part(self,"HexagonalHub",0.095,0.035,Vector3(0,0,0.694),metal(Color("697987"),0.68,0.32))
	(bolt.mesh as CylinderMesh).radial_segments = 6
	var lips := MeshInstance3D.new()
	lips.name = "ChamberEntranceRecesses"
	lips.mesh = make_lip_rings()
	lips.material_override = metal(Color("697b8b"),0.65,0.38)
	add_child(lips)
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
	fluted_wall(geometry)
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


## Six shallow machined pockets. The end bands and chamber positions stay intact.
static func wall_radius(angle: float, z: float) -> float:
	var nearest: float = wrapf(angle-PI/6.0,-PI/6.0,PI/6.0)
	var across: float = 0.5+0.5*cos(PI*nearest/FLUTE_HALF_WIDTH) if absf(nearest)<FLUTE_HALF_WIDTH else 0.0
	var along: float = smoothstep(-0.55,-0.42,z)*(1.0-smoothstep(0.20,0.42,z))
	return RADIUS-FLUTE_DEPTH*across*along


static func wall_point(angle: float, z: float) -> Vector3:
	var r: float = wall_radius(angle,z)
	return Vector3(cos(angle)*r,sin(angle)*r,z)


static func wall_normal(angle: float, z: float) -> Vector3:
	var step: float = 0.0005
	var da: float = (wall_radius(angle+step,z)-wall_radius(angle-step,z))/(2.0*step)
	var dz: float = (wall_radius(angle,z+step)-wall_radius(angle,z-step))/(2.0*step)
	var radial := Vector3(cos(angle),sin(angle),0)
	var tangent := Vector3(-sin(angle),cos(angle),0)
	return (radial-tangent*da/wall_radius(angle,z)-Vector3(0,0,dz)).normalized()


static func fluted_wall(out: Dictionary) -> void:
	var rings: Array[float] = [-0.55,-0.53,-0.50,-0.46,-0.42,-0.35,-0.20,0.0,0.12,0.20,0.26,0.32,0.37,0.40,0.42,0.48,0.55]
	for row: int in rings.size()-1:
		var z0: float = rings[row]
		var z1: float = rings[row+1]
		for i: int in OUTER_SEGMENTS:
			var a: float = TAU*i/OUTER_SEGMENTS
			var b: float = TAU*(i+1)/OUTER_SEGMENTS
			triangle(out,wall_point(a,z0),wall_point(b,z0),wall_point(b,z1),wall_normal(a,z0),wall_normal(b,z0),wall_normal(b,z1))
			triangle(out,wall_point(a,z0),wall_point(b,z1),wall_point(a,z1),wall_normal(a,z0),wall_normal(b,z1),wall_normal(a,z1))


static func make_extractor() -> ArrayMesh:
	var out: Dictionary = {"vertices":PackedVector3Array(),"normals":PackedVector3Array()}
	var shape := PackedVector2Array()
	for arm: int in 6:
		var a: float = arm*TAU/6.0
		shape.append(Vector2.from_angle(a-0.16)*0.37)
		shape.append(Vector2.from_angle(a+0.16)*0.37)
		shape.append(Vector2.from_angle(a+PI/6.0-0.12)*0.205)
		shape.append(Vector2.from_angle(a+PI/6.0+0.12)*0.205)
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(shape)
	for i: int in range(0,indices.size(),3):
		for face: float in [-1.0,1.0]:
			var z: float = 0.656 if face>0.0 else 0.602
			var scale_xy: float = 0.94 if face>0.0 else 1.0
			var a: Vector2 = shape[indices[i]]*scale_xy
			var b: Vector2 = shape[indices[i+1]]*scale_xy
			var c: Vector2 = shape[indices[i+2]]*scale_xy
			var n := Vector3(0,0,face)
			triangle(out,Vector3(a.x,a.y,z),Vector3(b.x,b.y,z),Vector3(c.x,c.y,z),n,n,n)
	for i: int in shape.size():
		var a: Vector2 = shape[i]
		var b: Vector2 = shape[(i+1)%shape.size()]
		var side: Vector3 = Vector3(b.y-a.y,a.x-b.x,0).normalized()
		var bevel: Vector3 = (side+Vector3.BACK).normalized()
		var p0 := Vector3(a.x,a.y,0.602)
		var p1 := Vector3(b.x,b.y,0.602)
		var p2 := Vector3(b.x,b.y,0.642)
		var p3 := Vector3(a.x,a.y,0.642)
		var p4 := Vector3(b.x*0.94,b.y*0.94,0.656)
		var p5 := Vector3(a.x*0.94,a.y*0.94,0.656)
		triangle(out,p0,p1,p2,side,side,side)
		triangle(out,p0,p2,p3,side,side,side)
		triangle(out,p3,p2,p4,bevel,bevel,bevel)
		triangle(out,p3,p4,p5,bevel,bevel,bevel)
	return mesh_from_geometry(out)


static func make_lip_rings() -> ArrayMesh:
	var out: Dictionary = {"vertices":PackedVector3Array(),"normals":PackedVector3Array()}
	for hole: int in 6:
		band(out,chamber_center(hole),LIP_RADIUS+0.001,0.601,LIP_RADIUS+0.012,0.601,BORE_SEGMENTS,-1.0)
	return mesh_from_geometry(out)


static func mesh_from_geometry(geometry: Dictionary) -> ArrayMesh:
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
