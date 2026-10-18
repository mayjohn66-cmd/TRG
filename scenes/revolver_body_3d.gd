## Standalone silver revolver body. The cylinder seat intentionally stays empty.
class_name RevolverBody3D
extends Node3D

const CYLINDER_CENTER: Vector3 = Vector3(0,0.30,0)
const CYLINDER_LENGTH: float = 1.50
const CYLINDER_RADIUS: float = 1.03
const BARREL_LENGTH: float = 4.10
const BARREL_ROOT: Vector3 = Vector3(-1.12,0.92,0)
var mount: Marker3D
var _steel: StandardMaterial3D
var _dark_steel: StandardMaterial3D


func _ready() -> void:
	build()


func build() -> void:
	if mount!=null: return
	_steel = material(Color("a8b4c0"),0.70,0.34)
	_dark_steel = material(Color("657481"),0.67,0.35)
	var frame := smooth(PackedVector2Array([Vector2(-1.13,1.59),Vector2(-0.92,1.68),Vector2(0.88,1.69),Vector2(1.20,1.49),Vector2(1.50,1.12),Vector2(1.60,0.65),Vector2(1.80,0.25),Vector2(1.82,-0.10),Vector2(1.57,-0.61),Vector2(1.22,-0.88),Vector2(0.80,-1.09),Vector2(-0.55,-1.09),Vector2(-1.09,-0.86),Vector2(-1.15,-0.62)]),5)
	var window: PackedVector2Array = rounded_rectangle(Rect2(-0.86,-0.80,1.85,2.16),0.09)
	part("OpenCylinderFrame",ring(frame,window,0.68,0.04),_steel)
	# Hollow cylindrical barrel, crown and collar. Its axis points to the left.
	var barrel_profile := PackedVector2Array([Vector2(0.38,0),Vector2(0.38,0.06),Vector2(0.345,BARREL_LENGTH-0.04),Vector2(0.320,BARREL_LENGTH),Vector2(0.190,BARREL_LENGTH),Vector2(0.170,BARREL_LENGTH-0.025),Vector2(0.170,0)])
	var barrel: MeshInstance3D = part("HollowRoundBarrel",lathe(barrel_profile,96),_steel)
	barrel.position = BARREL_ROOT
	barrel.rotation.y = -PI/2.0
	var collar: MeshInstance3D = part("BarrelCollar",lathe(PackedVector2Array([Vector2(0.425,0),Vector2(0.425,0.22),Vector2(0.37,0.22),Vector2(0.37,0)]),72),_steel)
	collar.position = BARREL_ROOT+Vector3(0.025,0,0)
	collar.rotation.y = -PI/2.0
	part("UpperBarrelRib",solid(PackedVector2Array([Vector2(-5.10,1.28),Vector2(-5.02,1.48),Vector2(-1.14,1.55),Vector2(-1.10,1.28)]),0.22,0.025),_steel)
	part("FrontSight",solid(smooth(PackedVector2Array([Vector2(-5.02,1.45),Vector2(-5.00,1.78),Vector2(-4.90,1.80),Vector2(-4.51,1.59),Vector2(-4.48,1.47)]),3),0.13,0.018),_dark_steel)
	var under: MeshInstance3D = part("UnderBarrelHousing",lathe(PackedVector2Array([Vector2(0.04,0),Vector2(0.13,0.06),Vector2(0.13,2.55),Vector2(0.085,2.68),Vector2(0,2.68),Vector2(0,0)]),64),_steel)
	under.position = Vector3(-1.12,0.35,0)
	under.rotation.y = -PI/2.0
	# Curved grip frame with separate rounded charcoal grip panels.
	var grip := smooth(PackedVector2Array([Vector2(1.12,-0.61),Vector2(1.79,-0.32),Vector2(2.02,-0.55),Vector2(2.10,-1.18),Vector2(2.35,-1.94),Vector2(2.61,-2.58),Vector2(2.62,-2.87),Vector2(2.36,-3.00),Vector2(1.51,-3.00),Vector2(1.23,-2.88),Vector2(1.21,-2.63),Vector2(1.31,-2.17),Vector2(1.26,-1.73),Vector2(1.12,-1.39),Vector2(0.96,-1.13),Vector2(0.97,-0.83)]),5)
	part("CurvedGripFrame",solid(grip,0.70,0.045),_steel)
	part("BlackRoundedGrip",solid(scaled(grip,Vector2(1.76,-1.68),0.94),0.90,0.075),material(Color("303c46"),0.08,0.57))
	# A genuinely open, curved D-shaped trigger guard.
	var guard := smooth(PackedVector2Array([Vector2(-0.51,-0.84),Vector2(-0.68,-1.09),Vector2(-0.63,-1.51),Vector2(-0.39,-1.82),Vector2(0.08,-1.97),Vector2(0.64,-1.94),Vector2(1.05,-1.70),Vector2(1.20,-1.31),Vector2(1.14,-0.97),Vector2(0.88,-0.82),Vector2(0.25,-0.82)]),6)
	part("OpenCurvedTriggerGuard",ring(guard,scaled(guard,Vector2(0.25,-1.36),0.81),0.26,0.025),_steel)
	var trigger := smooth(PackedVector2Array([Vector2(0.58,-0.81),Vector2(0.82,-0.89),Vector2(0.92,-1.10),Vector2(0.84,-1.37),Vector2(0.66,-1.57),Vector2(0.39,-1.66),Vector2(0.57,-1.44),Vector2(0.65,-1.21),Vector2(0.63,-1.01)]),5)
	part("CurvedTrigger",solid(trigger,0.14,0.018),_dark_steel)
	var hammer := smooth(PackedVector2Array([Vector2(1.05,1.10),Vector2(1.28,1.43),Vector2(1.52,1.57),Vector2(1.80,1.62),Vector2(1.98,1.78),Vector2(2.12,1.81),Vector2(2.09,1.61),Vector2(1.89,1.38),Vector2(1.80,1.16),Vector2(1.59,0.94),Vector2(1.29,0.94)]),4)
	part("ExposedCurvedHammer",solid(hammer,0.22,0.025),_dark_steel)
	# Restrained side-plate and fastener details, clear of the cylinder opening.
	var plate := smooth(PackedVector2Array([Vector2(1.12,1.15),Vector2(1.39,0.91),Vector2(1.64,0.33),Vector2(1.70,-0.04),Vector2(1.43,-0.58),Vector2(1.10,-0.69),Vector2(1.04,-0.31),Vector2(1.04,0.44)]),4)
	part("RearSidePlate",solid(plate,0.708,0.012),material(Color("a0aebb"),0.68,0.39))
	for side: float in [-1.0,1.0]:
		screw(Vector2(1.48,-1.32),0.452*side,0.09,side)
		screw(Vector2(2.02,-2.58),0.452*side,0.085,side)
		screw(Vector2(1.26,0.18),0.36*side,0.065,side)
		screw(Vector2(1.38,-0.43),0.36*side,0.055,side)
	mount = Marker3D.new()
	mount.name = "EmptyCylinderMount"
	mount.position = CYLINDER_CENTER
	mount.rotation.y = PI/2.0
	add_child(mount)


func part(title: String, mesh: Mesh, surface: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = title
	node.mesh = mesh
	node.material_override = surface
	add_child(node)
	return node


func screw(at: Vector2, z: float, radius: float, side: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.018
	mesh.radial_segments = 32
	var node: MeshInstance3D = part("SteelScrew",mesh,_steel)
	node.position = Vector3(at.x,at.y,z)
	node.rotation.x = PI/2.0
	var slot: MeshInstance3D = part("ScrewSlot",solid(rounded_rectangle(Rect2(-radius*0.7,-0.009,radius*1.4,0.018),0.007),0.003,0),_dark_steel)
	slot.position = Vector3(at.x,at.y,z+0.011*side)
	slot.rotation.z = -0.48


static func material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	return result


static func smooth(points: PackedVector2Array, steps: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	var n: int = points.size()
	for i: int in n:
		var p0: Vector2 = points[(i+n-1)%n]
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[(i+1)%n]
		var p3: Vector2 = points[(i+2)%n]
		for j: int in steps:
			var t: float = float(j)/steps
			result.append(0.5*((2.0*p1)+(-p0+p2)*t+(2.0*p0-5.0*p1+4.0*p2-p3)*t*t+(-p0+3.0*p1-3.0*p2+p3)*t*t*t))
	return result


static func rounded_rectangle(rect: Rect2, radius: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	var centers: Array[Vector2] = [Vector2(rect.position.x+radius,rect.end.y-radius),Vector2(rect.end.x-radius,rect.end.y-radius),Vector2(rect.end.x-radius,rect.position.y+radius),Vector2(rect.position.x+radius,rect.position.y+radius)]
	for corner: int in 4:
		for i: int in 7:
			var angle: float = PI-(corner*PI/2.0)-i*PI/12.0
			result.append(centers[corner]+Vector2.from_angle(angle)*radius)
	return result


static func scaled(shape: PackedVector2Array, center: Vector2, factor: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in shape: result.append(center+(point-center)*factor)
	return result


static func resample(shape: PackedVector2Array, count: int) -> PackedVector2Array:
	var distances: Array[float] = [0.0]
	for i: int in shape.size(): distances.append(distances[-1]+shape[i].distance_to(shape[(i+1)%shape.size()]))
	var result := PackedVector2Array()
	var segment: int = 0
	for i: int in count:
		var target: float = distances[-1]*i/count
		while segment<shape.size()-1 and distances[segment+1]<target: segment += 1
		var weight: float = (target-distances[segment])/maxf(distances[segment+1]-distances[segment],0.000001)
		result.append(shape[segment].lerp(shape[(segment+1)%shape.size()],weight))
	return result


static func geometry() -> Dictionary:
	return {"vertices":PackedVector3Array(),"normals":PackedVector3Array()}


static func point(p: Vector2, z: float) -> Vector3:
	return Vector3(p.x,p.y,z)


static func quad(out: Dictionary, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	RevolverCylinder3D.triangle(out,a,b,c,normal,normal,normal)
	RevolverCylinder3D.triangle(out,a,c,d,normal,normal,normal)


static func center_of(shape: PackedVector2Array) -> Vector2:
	var center := Vector2.ZERO
	for p: Vector2 in shape: center += p
	return center/shape.size()


static func clockwise(shape: PackedVector2Array) -> PackedVector2Array:
	var area: float = 0.0
	for i: int in shape.size(): area += shape[i].cross(shape[(i+1)%shape.size()])
	var result: PackedVector2Array = shape.duplicate()
	if area>0.0: result.reverse()
	return result


static func loft(out: Dictionary, shape: PackedVector2Array, center: Vector2, depth: float, bevel: float, inner: bool) -> void:
	var radius: float = 0.0
	for p: Vector2 in shape: radius += p.distance_to(center)
	radius /= shape.size()
	var face_factor: float = 1.0+(bevel/maxf(radius,0.1))*(1.0 if inner else -1.0)
	var layers: Array[Vector2] = [Vector2(-depth/2.0,face_factor),Vector2(-depth/2.0+bevel,1.0),Vector2(depth/2.0-bevel,1.0),Vector2(depth/2.0,face_factor)]
	for row: int in 3:
		if is_zero_approx(layers[row+1].x-layers[row].x): continue
		for i: int in shape.size():
			var j: int = (i+1)%shape.size()
			var a: Vector2 = center+(shape[i]-center)*layers[row].y
			var b: Vector2 = center+(shape[j]-center)*layers[row].y
			var c: Vector2 = center+(shape[j]-center)*layers[row+1].y
			var d: Vector2 = center+(shape[i]-center)*layers[row+1].y
			var tangent: Vector2 = shape[j]-shape[i]
			var outward: Vector2 = Vector2(-tangent.y,tangent.x).normalized()*(-1.0 if inner else 1.0)
			var radial: Vector3 = Vector3(outward.x,outward.y,0)
			var n: Vector3 = (radial+Vector3(0,0,-1 if row==0 else (1 if row==2 else 0))).normalized()
			quad(out,point(a,layers[row].x),point(b,layers[row].x),point(c,layers[row+1].x),point(d,layers[row+1].x),n)


static func ring(outer_shape: PackedVector2Array, inner_shape: PackedVector2Array, depth: float, bevel: float) -> ArrayMesh:
	var outer: PackedVector2Array = resample(clockwise(outer_shape),128)
	var inner: PackedVector2Array = resample(clockwise(inner_shape),128)
	var co: Vector2 = center_of(outer)
	var ci: Vector2 = center_of(inner)
	var ro: float = 0.0
	var ri: float = 0.0
	for i: int in 128:
		ro += outer[i].distance_to(co)/128.0
		ri += inner[i].distance_to(ci)/128.0
	var face_outer: PackedVector2Array = scaled(outer,co,1.0-bevel/ro)
	var face_inner: PackedVector2Array = scaled(inner,ci,1.0+bevel/ri)
	var out: Dictionary = geometry()
	for i: int in 128:
		var j: int = (i+1)%128
		for side: float in [-1.0,1.0]:
			quad(out,point(face_outer[i],side*depth/2.0),point(face_outer[j],side*depth/2.0),point(face_inner[j],side*depth/2.0),point(face_inner[i],side*depth/2.0),Vector3(0,0,side))
	loft(out,outer,co,depth,bevel,false)
	loft(out,inner,ci,depth,bevel,true)
	return RevolverCylinder3D.mesh_from_geometry(out)


static func solid(shape: PackedVector2Array, depth: float, bevel: float) -> ArrayMesh:
	shape = clockwise(shape)
	var out: Dictionary = geometry()
	var center: Vector2 = center_of(shape)
	var radius: float = 0.0
	for p: Vector2 in shape: radius += p.distance_to(center)/shape.size()
	var face: PackedVector2Array = scaled(shape,center,1.0-bevel/maxf(radius,0.1))
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(face)
	for i: int in range(0,indices.size(),3):
		for side: float in [-1.0,1.0]:
			var n := Vector3(0,0,side)
			RevolverCylinder3D.triangle(out,point(face[indices[i]],side*depth/2.0),point(face[indices[i+1]],side*depth/2.0),point(face[indices[i+2]],side*depth/2.0),n,n,n)
	loft(out,shape,center,depth,bevel,false)
	return RevolverCylinder3D.mesh_from_geometry(out)


static func lathe(profile: PackedVector2Array, count: int) -> ArrayMesh:
	var out: Dictionary = geometry()
	for i: int in profile.size():
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[(i+1)%profile.size()]
		RevolverCylinder3D.band(out,Vector2.ZERO,a.x,a.y,b.x,b.y,count,1.0)
	return RevolverCylinder3D.mesh_from_geometry(out)
