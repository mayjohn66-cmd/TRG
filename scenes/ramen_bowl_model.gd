## Small, real 3D ramen asset: closed ceramic shell around an open cavity,
## curled noodle tubes below the lip, and restrained black/red decoration.
extends RefCounted

const SEGMENTS: int = 72
const FOOD_Y: float = 1.19
const LIP_Y: float = 1.52
const PROFILE: Array[Vector2] = [
	Vector2(0, 0.08), Vector2(0.66, 0.08), Vector2(0.74, 0.12),
	Vector2(0.76, 0.21), Vector2(0.94, 0.28), Vector2(1.12, 0.44),
	Vector2(1.30, 0.69), Vector2(1.46, 1.01), Vector2(1.57, 1.32),
	Vector2(1.60, 1.44), Vector2(1.63, 1.48), Vector2(1.64, 1.52),
	Vector2(1.62, 1.56), Vector2(1.57, 1.57), Vector2(1.52, 1.55),
	Vector2(1.49, 1.51), Vector2(1.48, 1.44), Vector2(1.39, 1.13),
	Vector2(1.23, 0.83), Vector2(1.02, 0.58), Vector2(0.74, 0.41),
	Vector2(0.45, 0.36), Vector2(0, 0.36)
]

static var _ceramic: ArrayMesh
static var _noodles: ArrayMesh
static var _band: ArrayMesh

static func material(color: Color, roughness: float = 0.4) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	result.metallic_specular = 0.32
	return result

static func make_model() -> Node3D:
	if _ceramic == null:
		_ceramic = lathe(PROFILE, true)
		_band = lathe([Vector2(1.258, 0.63), Vector2(1.316, 0.72), Vector2(1.362, 0.81)], false)
		_noodles = noodle_mesh()
	var root := Node3D.new()
	root.name = "DeepRamenBowl3D"
	var ceramic: MeshInstance3D = part(root, "CeramicBody", _ceramic, material(Color.WHITE, 0.27))
	(ceramic.material_override as StandardMaterial3D).vertex_color_use_as_albedo = true
	part(root, "RedBand", _band, material(Color("bd3929"), 0.36))
	var mound := SphereMesh.new()
	mound.radius = 1.22
	mound.height = 0.16
	mound.radial_segments = 48
	mound.rings = 12
	part(root, "NoodleMound", mound, material(Color("bb4120"), 0.55)).position.y = 1.10
	var noodles: MeshInstance3D = part(root, "Noodles", _noodles, material(Color("e65d30"), 0.4))
	(noodles.material_override as StandardMaterial3D).vertex_color_use_as_albedo = true
	var sesame := SphereMesh.new()
	sesame.radius = 0.025
	sesame.height = 0.018
	sesame.radial_segments = 8
	sesame.rings = 4
	var seed_paint: StandardMaterial3D = material(Color("ffe4a5"), 0.6)
	var seaweed := BoxMesh.new()
	seaweed.size = Vector3(0.115, 0.009, 0.04)
	var seaweed_paint: StandardMaterial3D = material(Color("293c24"), 0.8)
	for index: int in 28:
		var radius: float = 0.23 + 0.86 * sqrt(float(index) / 28.0)
		var angle: float = index * 2.4
		var garnish: MeshInstance3D = part(root, "Sesame%d" % index, sesame, seed_paint) if index < 18 else part(root, "Seaweed%d" % index, seaweed, seaweed_paint)
		garnish.position = Vector3(cos(angle) * radius, FOOD_Y + 0.06, sin(angle) * radius)
		garnish.rotation.y = angle + 0.6
	# A small flame mark on the front follows the black/red motif without text.
	var flame := SurfaceTool.new()
	flame.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shape := PackedVector2Array([Vector2(-0.06, 0), Vector2(-0.09, 0.05), Vector2(-0.03, 0.15), Vector2(0, 0.08), Vector2(0.04, 0.22), Vector2(0.09, 0.05), Vector2(0.06, 0)])
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(shape)
	for index: int in indices:
		flame.set_normal(Vector3.BACK)
		flame.add_vertex(Vector3(shape[index].x, shape[index].y + 0.62, 1.37))
	var emblem := material(Color("ffe3a5"), 0.55)
	emblem.cull_mode = BaseMaterial3D.CULL_DISABLED
	part(root, "FlameMark", flame.commit(), emblem)
	return root

static func part(root: Node3D, node_name: String, mesh: Mesh, paint: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = node_name
	item.mesh = mesh
	item.material_override = paint
	root.add_child(item)
	item.owner = root
	return item

static func lathe(profile: Array[Vector2], ceramic: bool) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row: int in profile.size() - 1:
		var color := Color("30323d")
		if row >= 10 and row <= 14:
			color = Color("f1dfb8")
		elif row >= 15:
			color = Color("232630")
		if not ceramic:
			color = Color.WHITE
		for segment: int in SEGMENTS:
			var points: Array[Vector3] = []
			var normals: Array[Vector3] = []
			for sample: Vector2i in [Vector2i(row, segment), Vector2i(row + 1, segment), Vector2i(row + 1, segment + 1), Vector2i(row, segment + 1)]:
				var angle: float = TAU * float(sample.y) / SEGMENTS
				var p: Vector2 = profile[sample.x]
				var tangent: Vector2 = profile[mini(sample.x + 1, profile.size() - 1)] - profile[maxi(sample.x - 1, 0)]
				var normal := Vector2(tangent.y, -tangent.x).normalized()
				points.append(Vector3(p.x * cos(angle), p.y, p.x * sin(angle)))
				normals.append(Vector3(normal.x * cos(angle), normal.y, normal.x * sin(angle)))
			triangle(surface, points, normals, [0, 1, 2], color)
			triangle(surface, points, normals, [0, 2, 3], color)
	return surface.commit()

static func noodle_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SIDES: int = 6
	const SAMPLES: int = 112
	for strand: int in 26:
		var path: Array[Vector3] = []
		var phase: float = strand * 1.87
		for index: int in SAMPLES + 1:
			var t: float = float(index) / SAMPLES
			var angle: float = t * TAU * (7.0 + strand % 3) + phase
			var u: float = lerpf(-0.78, 0.78, t) + sin(angle) * 0.043
			var v: float = sin(phase) * 0.18 + cos(t * TAU * 1.2 + phase) * 0.16 + cos(angle) * 0.08
			var flat: Vector2 = Vector2(u, v).rotated(strand * 0.79) * 1.42
			var height: float = FOOD_Y + 0.035 * (1.0 - flat.length() / 1.3) + sin(angle * 0.53 + phase) * 0.025
			path.append(Vector3(flat.x, height, flat.y))
		var rings: Array[PackedVector3Array] = []
		var radial_normals: Array[PackedVector3Array] = []
		for index: int in path.size():
			var direction: Vector3 = (path[mini(index + 1, path.size() - 1)] - path[maxi(index - 1, 0)]).normalized()
			var side: Vector3 = direction.cross(Vector3.UP).normalized()
			var up: Vector3 = side.cross(direction).normalized()
			var ring := PackedVector3Array()
			var normals := PackedVector3Array()
			for edge: int in SIDES:
				var angle: float = TAU * float(edge) / SIDES
				var normal: Vector3 = side * cos(angle) + up * sin(angle)
				ring.append(path[index] + normal * 0.023)
				normals.append(normal)
			rings.append(ring)
			radial_normals.append(normals)
		var shade: float = 0.86 + (strand % 4) * 0.04
		for index: int in path.size() - 1:
			for edge: int in SIDES:
				var next_edge: int = (edge + 1) % SIDES
				var points: Array[Vector3] = [rings[index][edge], rings[index + 1][edge], rings[index + 1][next_edge], rings[index][next_edge]]
				var normals: Array[Vector3] = [radial_normals[index][edge], radial_normals[index + 1][edge], radial_normals[index + 1][next_edge], radial_normals[index][next_edge]]
				triangle(surface, points, normals, [0, 1, 2], Color(shade, shade, shade))
				triangle(surface, points, normals, [0, 2, 3], Color(shade, shade, shade))
	return surface.commit()

static func triangle(surface: SurfaceTool, points: Array[Vector3], normals: Array[Vector3], indices: Array, color: Color) -> void:
	var order: Array = indices.duplicate()
	var cross: Vector3 = (points[order[1]] - points[order[0]]).cross(points[order[2]] - points[order[0]])
	if cross.length_squared() < 0.0000000001:
		return
	if cross.dot(normals[order[0]] + normals[order[1]] + normals[order[2]]) > 0.0:
		order.reverse()
	for index: int in order:
		surface.set_normal(normals[index])
		surface.set_color(color)
		surface.add_vertex(points[index])
