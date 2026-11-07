## Long-barrel silver revolver silhouette traced from the user's 400x240 reference.
## The cylinder seat intentionally stays empty; display size is a uniform transform.
class_name RevolverBody3D
extends Node3D

const CYLINDER_CENTER: Vector3 = Vector3(0,0.30,0)
const CYLINDER_LENGTH: float = 1.50
const CYLINDER_RADIUS: float = 1.03
const REFERENCE_ORIGIN: Vector2 = Vector2(244,71)
const REFERENCE_UNIT: float = 0.04
const BARREL_LENGTH: float = 6.92
const BARREL_ROOT: Vector3 = Vector3(-1.88,0.98,0)
var mount: Marker3D
var _steel: StandardMaterial3D
var _dark_steel: StandardMaterial3D


func _ready() -> void:
	build()


func build() -> void:
	if mount!=null: return
	_steel = material(Color("aebac4"),0.74,0.29)
	_dark_steel = material(Color("64727d"),0.67,0.34)
	var frame := smooth(reference_shape(PackedVector2Array([Vector2(198,37),Vector2(215,36),Vector2(274,36),Vector2(283,39),Vector2(290,48),Vector2(298,60),Vector2(314,68),Vector2(334,78),Vector2(329,93),Vector2(308,109),Vector2(289,114),Vector2(277,112),Vector2(218,111),Vector2(199,108),Vector2(198,90)])),5)
	var window: PackedVector2Array = rounded_rectangle(Rect2(-1.08,-0.82,2.40,2.24),0.075)
	part("OpenCylinderFrame",ring(frame,window,0.64,0.035),_steel)
	# Hollow cylindrical barrel, crown and collar. Its axis points to the left.
	var barrel_profile := PackedVector2Array([Vector2(0.385,0),Vector2(0.385,0.07),Vector2(0.375,BARREL_LENGTH-0.035),Vector2(0.350,BARREL_LENGTH),Vector2(0.190,BARREL_LENGTH),Vector2(0.170,BARREL_LENGTH-0.025),Vector2(0.170,0)])
	var barrel: MeshInstance3D = part("HollowRoundBarrel",lathe(barrel_profile,96),_steel)
	barrel.position = BARREL_ROOT
	barrel.rotation.y = -PI/2.0
	var collar: MeshInstance3D = part("BarrelCollar",lathe(PackedVector2Array([Vector2(0.425,0),Vector2(0.425,0.22),Vector2(0.37,0.22),Vector2(0.37,0)]),72),_steel)
	collar.position = BARREL_ROOT+Vector3(0.025,0,0)
	collar.rotation.y = -PI/2.0
	part("UpperBarrelRib",solid(reference_shape(PackedVector2Array([Vector2(25,35),Vector2(195,35),Vector2(198,46),Vector2(24,46)])),0.24,0.025),_steel)
	part("FrontSight",solid(smooth(reference_shape(PackedVector2Array([Vector2(27,35),Vector2(28,27),Vector2(34,27),Vector2(49,34),Vector2(62,36)])),3),0.13,0.018),_dark_steel)
	part("FullLengthLowerShroud",solid(smooth(reference_shape(PackedVector2Array([Vector2(24,57),Vector2(194,56),Vector2(197,59),Vector2(197,73),Vector2(193,76),Vector2(27,76),Vector2(23,72)])),3),0.59,0.035),_steel)
	var under: MeshInstance3D = part("RecessedEjectorRod",lathe(PackedVector2Array([Vector2(0.04,0),Vector2(0.105,0.05),Vector2(0.105,2.50),Vector2(0.055,2.60),Vector2(0,2.60),Vector2(0,0)]),48),_dark_steel)
	under.position = Vector3(-1.89,0.28,0.305)
	under.rotation.y = -PI/2.0
	# Curved grip frame with separate rounded charcoal grip panels.
	var grip := smooth(reference_shape(PackedVector2Array([Vector2(335,80),Vector2(340,84),Vector2(343,103),Vector2(355,129),Vector2(367,156),Vector2(378,184),Vector2(384,204),Vector2(377,207),Vector2(347,207),Vector2(320,210),Vector2(316,205),Vector2(314,178),Vector2(310,153),Vector2(302,138),Vector2(291,136),Vector2(284,136),Vector2(285,119),Vector2(304,112),Vector2(309,96),Vector2(322,87)])),5)
	part("CurvedGripFrame",solid(grip,0.70,0.045),_steel)
	part("BlackRoundedGrip",solid(scaled(grip,reference_point(Vector2(333,145)),0.995),0.91,0.085),material(Color("171d22"),0.04,0.64))
	# A genuinely open, curved D-shaped trigger guard.
	var guard := smooth(reference_shape(PackedVector2Array([Vector2(224,108),Vector2(222,121),Vector2(228,137),Vector2(240,146),Vector2(257,150),Vector2(273,145),Vector2(283,134),Vector2(287,118),Vector2(281,108),Vector2(258,104),Vector2(239,104)])),6)
	part("OpenCurvedTriggerGuard",ring(guard,scaled(guard,reference_point(Vector2(254,125)),0.84),0.26,0.025),_steel)
	var trigger := smooth(reference_shape(PackedVector2Array([Vector2(260,107),Vector2(267,111),Vector2(270,119),Vector2(267,128),Vector2(261,136),Vector2(248,142),Vector2(256,134),Vector2(260,125),Vector2(260,116),Vector2(256,111)])),5)
	part("CurvedTrigger",solid(trigger,0.14,0.018),_dark_steel)
	var hammer := smooth(reference_shape(PackedVector2Array([Vector2(291,63),Vector2(294,55),Vector2(300,50),Vector2(308,49),Vector2(318,50),Vector2(323,53),Vector2(317,55),Vector2(309,55),Vector2(306,60),Vector2(307,66),Vector2(301,69)])),4)
	part("ExposedCurvedHammer",solid(hammer,0.22,0.025),_dark_steel)
	# Restrained side-plate and fastener details, clear of the cylinder opening.
	var plate := smooth(reference_shape(PackedVector2Array([Vector2(280,52),Vector2(291,60),Vector2(307,70),Vector2(326,78),Vector2(321,91),Vector2(306,105),Vector2(281,106),Vector2(278,94)])),4)
	part("RearSidePlate",solid(plate,0.665,0.012),material(Color("a4b2bd"),0.70,0.32))
	var latch := smooth(reference_shape(PackedVector2Array([Vector2(286,77),Vector2(291,71),Vector2(298,73),Vector2(304,80),Vector2(299,85),Vector2(288,84)])),4)
	part("CylinderReleaseLatch",solid(latch,0.73,0.018),_dark_steel)
	for side: float in [-1.0,1.0]:
		screw(reference_point(Vector2(326,113)),0.458*side,0.055,side)
		screw(reference_point(Vector2(363,168)),0.458*side,0.045,side)
		screw(reference_point(Vector2(290,79)),0.375*side,0.045,side)
		screw(reference_point(Vector2(278,97)),0.345*side,0.040,side)
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


static func reference_point(pixel: Vector2) -> Vector2:
	return Vector2((pixel.x-REFERENCE_ORIGIN.x)*REFERENCE_UNIT,CYLINDER_CENTER.y+(REFERENCE_ORIGIN.y-pixel.y)*REFERENCE_UNIT)


static func reference_shape(pixels: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for pixel: Vector2 in pixels: result.append(reference_point(pixel))
	return result


static func smooth(points: PackedVector2Array, steps: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	var n: int = points.size()
	for i: int in n:
		var p0: Vector2 = points[(i+n-1)%n]
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[(i+1)%n]
		var p3: Vector2 = points[(i+2)%n]
		# Limit corner handles so long photo contours do not overshoot short corners.
		var m1: Vector2 = (p2-p0).normalized()*minf(p0.distance_to(p1),p1.distance_to(p2))*0.65
		var m2: Vector2 = (p3-p1).normalized()*minf(p1.distance_to(p2),p2.distance_to(p3))*0.65
		for j: int in steps:
			var t: float = float(j)/steps
			result.append((2*t*t*t-3*t*t+1)*p1+(t*t*t-2*t*t+t)*m1+(-2*t*t*t+3*t*t)*p2+(t*t*t-t*t)*m2)
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
