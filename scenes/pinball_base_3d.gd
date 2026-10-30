## Static, editable tabletop peg-board base. No ball, animation, collision or
## game-result handling is attached in this modeling pass. X=width, Z=length.
extends RefCounted

const HOLES: Array[int] = [2, 4, 6, 10, 5, 3, 1]
const ARCH_Z: float = -1.55

var root: Node3D
var paints: Dictionary = {}


func build(number_textures: Dictionary = {}) -> Node3D:
	root = Node3D.new()
	root.name = "PinballBaseV01"
	_paint("wood", "9d7049", 0.0, 0.48)
	_paint("wood_edge", "674a35", 0.0, 0.5)
	_paint("cream", "fff1cf", 0.0, 0.36)
	_paint("mint", "abd689", 0.0, 0.48)
	_paint("green", "547c42", 0.0, 0.45)
	_paint("gold", "e6b94e", 0.45, 0.28)
	_paint("steel", "bdcbd0", 0.65, 0.24)
	_paint("spring", "607574", 0.6, 0.32)
	_paint("pocket", "345e51", 0.0, 0.6)
	_paint("jackpot", "c88731", 0.2, 0.35)
	_paint("coral", "ed9275", 0.0, 0.28)
	_slab("WalnutLowerCase", _outline(3.40, 4.52), -0.40, 0.02, "wood")
	_slab("LowerCaseEdge", _outline(3.39, 4.50), -0.40, -0.27, "wood_edge")
	_slab("CreamCarrier", _outline(3.32, 4.45), 0.02, 0.30, "cream")
	_slab("RecessedMintPlayfield", _outline(3.04, 3.06), 0.30, 0.45, "mint")
	var rim := PackedVector3Array()
	for point: Vector2 in _outline(3.25, 4.36):
		rim.append(Vector3(point.x, 0.34, point.y))
	_tube("ContinuousGoldRim", rim, 0.075, "gold", true)
	# Two raised rails form a genuine U-turn track, connected to the right lane.
	for radius: float in [2.61, 2.98]:
		var rail := PackedVector3Array([Vector3(radius, 0.58, 3.50)])
		for step: int in 65:
			var angle: float = -PI * float(step) / 64.0
			rail.append(Vector3(cos(angle) * radius, 0.58, ARCH_Z + sin(angle) * radius))
		_tube("LaunchRailInner" if radius < 2.8 else "LaunchRailOuter", rail, 0.055, "steel")
	_box("CreamLaunchLane", Vector3(0.34, 0.025, 5.16), Vector3(2.79, 0.47, 0.96), "cream")
	_box("LaneSeparator", Vector3(0.09, 0.18, 5.0), Vector3(2.50, 0.52, 0.88), "gold")
	_build_pegs()
	_build_pockets(number_textures)
	_build_plunger()
	# An embossed clover gives the otherwise empty upper field a quiet toy mark.
	_cylinder("CloverCoin", Vector3(0, 0.48, -3.18), 0.36, 0.055, "gold", 40)
	for angle: float in [-PI / 2.0, PI / 6.0, 5.0 * PI / 6.0]:
		_cylinder("CloverLeaf", Vector3(cos(angle) * 0.11, 0.518, -3.18 + sin(angle) * 0.11), 0.12, 0.026, "green", 20)
	for x: float in [-3.15, 3.15]:
		for z: float in [-0.8, 2.70]:
			_cylinder("RimScrew", Vector3(x, 0.325, z), 0.065, 0.024, "gold", 16)
			_box("ScrewSlot", Vector3(0.065, 0.005, 0.012), Vector3(x, 0.34, z), "wood_edge")
	for x: float in [-2.50, 2.50]:
		for z: float in [-2.0, 3.55]:
			_cylinder("RubberFoot", Vector3(x, -0.49, z), 0.30, 0.18, "green", 24)
	_own(root)
	return root


func _build_pegs() -> void:
	var holder := Node3D.new()
	holder.name = "StaggeredPegs33"
	root.add_child(holder)
	for row: int in 6:
		for column: int in (6 if row % 2 == 0 else 5):
			var x: float = -2.30 + column * 0.83 + (0.415 if row % 2 else 0.0)
			var z: float = -0.96 + row * 0.66
			var peg := Node3D.new()
			peg.name = "Peg_%d_%d" % [row, column]
			holder.add_child(peg)
			_cylinder("SteelStem", Vector3(x, 0.57, z), 0.075, 0.24, "steel", 16, peg)
			_cylinder("GoldCollar", Vector3(x, 0.47, z), 0.12, 0.045, "gold", 20, peg)
			_sphere("RoundedCap", Vector3(x, 0.70, z), 0.135, "gold", Vector3(1.0, 0.65, 1.0), peg)


func _build_pockets(numbers: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "SevenRecessedPockets"
	root.add_child(holder)
	var left: float = -2.88
	var width: float = 5.20 / 7.0
	for index: int in 7:
		var centre: float = left + (index + 0.5) * width
		var pocket := Node3D.new()
		pocket.name = "Pocket_%d_Value_%d" % [index, HOLES[index]]
		holder.add_child(pocket)
		var jackpot: bool = index == 3
		_box("RecessFloor", Vector3(width - 0.09, 0.025, 0.87), Vector3(centre, 0.315, 3.56), "jackpot" if jackpot else "pocket", pocket)
		_box("FrontLip", Vector3(width - 0.025, 0.23, 0.15), Vector3(centre, 0.425, 4.05), "gold" if jackpot else "cream", pocket)
		_box("NumberPlaque", Vector3(width - 0.10, 0.06, 0.36), Vector3(centre, 0.57, 4.14), "gold" if jackpot else "cream", pocket)
		if numbers.has(HOLES[index]):
			var ink := StandardMaterial3D.new()
			ink.albedo_texture = numbers[HOLES[index]]
			ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			ink.cull_mode = BaseMaterial3D.CULL_DISABLED
			var plane := PlaneMesh.new()
			plane.size = Vector2(0.44, 0.31)
			var label := MeshInstance3D.new()
			label.name = "BakedNumber_%d" % HOLES[index]
			label.mesh = plane
			label.material_override = ink
			label.position = Vector3(centre, 0.605, 4.14)
			pocket.add_child(label)
	for index: int in 8:
		_box("PocketDivider", Vector3(0.08, 0.26, 1.02), Vector3(left + index * width, 0.44, 3.54), "cream", holder)
		_box("DividerGoldCap", Vector3(0.09, 0.035, 1.02), Vector3(left + index * width, 0.587, 3.54), "gold", holder)
	# A small star stamped on the middle entrance, without covering the opening.
	var star := PackedVector2Array()
	for point: int in 10:
		var angle: float = -PI / 2.0 + point * PI / 5.0
		var radius: float = 0.19 if point % 2 == 0 else 0.087
		star.append(Vector2(-0.28, 2.76) + Vector2(cos(angle), sin(angle)) * radius)
	_slab("JackpotStar", star, 0.455, 0.49, "gold")


func _build_plunger() -> void:
	var holder := Node3D.new()
	holder.name = "StaticSpringPlunger"
	root.add_child(holder)
	var rod := PackedVector3Array([Vector3(2.79, 0.67, 3.28), Vector3(2.79, 0.67, 4.72)])
	_tube("PlungerRod", rod, 0.048, "steel", false, holder)
	var coil := PackedVector3Array()
	for step: int in 193:
		var t: float = step / 192.0
		var angle: float = t * TAU * 7.0
		coil.append(Vector3(2.79 + cos(angle) * 0.13, 0.67 + sin(angle) * 0.13, lerpf(3.43, 4.31, t)))
	_tube("SevenTurnSteelSpring", coil, 0.029, "spring", false, holder)
	_box("BallPusher", Vector3(0.32, 0.16, 0.12), Vector3(2.79, 0.65, 3.32), "steel", holder)
	var collar: MeshInstance3D = _cylinder("FrontGuideBushing", Vector3(2.79, 0.67, 4.40), 0.15, 0.15, "gold", 24, holder)
	collar.rotation.x = PI / 2.0
	var knob: MeshInstance3D = _cylinder("CoralPullKnob", Vector3(2.79, 0.67, 4.78), 0.23, 0.20, "coral", 40, holder)
	knob.rotation.x = PI / 2.0
	_sphere("RoundedKnobEnd", Vector3(2.79, 0.67, 4.89), 0.23, "coral", Vector3(1, 1, 0.40), holder)


func _outline(radius: float, bottom: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step: int in 65:
		var angle: float = PI + PI * float(step) / 64.0
		points.append(Vector2(cos(angle) * radius, ARCH_Z + sin(angle) * radius))
	var corner: float = 0.38
	for step: int in 13:
		var angle: float = PI * 0.5 * step / 12.0
		points.append(Vector2(radius - corner, bottom - corner) + Vector2(cos(angle), sin(angle)) * corner)
	for step: int in 13:
		var angle: float = PI * 0.5 + PI * 0.5 * step / 12.0
		points.append(Vector2(-radius + corner, bottom - corner) + Vector2(cos(angle), sin(angle)) * corner)
	return points


func _slab(node_name: String, outline: PackedVector2Array, low: float, high: float, paint: String) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	for start: int in range(0, triangles.size(), 3):
		for corner: int in 3:
			var point: Vector2 = outline[triangles[start + corner]]
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(point.x, high, point.y))
		for corner: int in [2, 1, 0]:
			var point: Vector2 = outline[triangles[start + corner]]
			st.set_normal(Vector3.DOWN)
			st.add_vertex(Vector3(point.x, low, point.y))
	for index: int in outline.size():
		var a: Vector2 = outline[index]
		var b: Vector2 = outline[(index + 1) % outline.size()]
		var normal := Vector3(b.y - a.y, 0.0, a.x - b.x).normalized()
		var corners: Array[Vector3] = [Vector3(a.x, low, a.y), Vector3(b.x, low, b.y), Vector3(b.x, high, b.y), Vector3(a.x, high, a.y)]
		for vertex: int in [0, 1, 2, 0, 2, 3]:
			st.set_normal(normal)
			st.add_vertex(corners[vertex])
	return _mesh(node_name, st.commit(), Vector3.ZERO, paint)


func _tube(node_name: String, path: PackedVector3Array, radius: float, paint: String, closed: bool = false, parent: Node3D = null) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = path.size()
	var rings: Array[PackedVector3Array] = []
	for index: int in count:
		var before: Vector3 = path[(index - 1 + count) % count] if closed or index > 0 else path[0]
		var after: Vector3 = path[(index + 1) % count] if closed or index < count - 1 else path[count - 1]
		var tangent: Vector3 = (after - before).normalized()
		var axis: Vector3 = Vector3.RIGHT if absf(tangent.dot(Vector3.UP)) > 0.9 else Vector3.UP
		var u: Vector3 = tangent.cross(axis).normalized()
		var v: Vector3 = tangent.cross(u).normalized()
		var ring := PackedVector3Array()
		for side: int in 10:
			var angle: float = TAU * side / 10.0
			ring.append(path[index] + (u * cos(angle) + v * sin(angle)) * radius)
		rings.append(ring)
	for index: int in (count if closed else count - 1):
		var next: int = (index + 1) % count
		for side: int in 10:
			var adjacent: int = (side + 1) % 10
			for pair: Vector2i in [Vector2i(index, side), Vector2i(next, side), Vector2i(next, adjacent), Vector2i(index, side), Vector2i(next, adjacent), Vector2i(index, adjacent)]:
				var point: Vector3 = rings[pair.x][pair.y]
				st.set_normal((point - path[pair.x]).normalized())
				st.add_vertex(point)
	return _mesh(node_name, st.commit(), Vector3.ZERO, paint, parent)


func _paint(key: String, color: String, metal: float, rough: float) -> void:
	var material := StandardMaterial3D.new()
	material.resource_name = key
	material.albedo_color = Color(color)
	material.metallic = metal
	material.roughness = rough
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	paints[key] = material


func _box(node_name: String, dimensions: Vector3, position: Vector3, paint: String, parent: Node3D = null) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = dimensions
	return _mesh(node_name, shape, position, paint, parent)


func _cylinder(node_name: String, position: Vector3, radius: float, height: float, paint: String, segments: int = 24, parent: Node3D = null) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = segments
	return _mesh(node_name, shape, position, paint, parent)


func _sphere(node_name: String, position: Vector3, radius: float, paint: String, scale: Vector3 = Vector3.ONE, parent: Node3D = null) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	shape.radial_segments = 20
	shape.rings = 10
	var item: MeshInstance3D = _mesh(node_name, shape, position, paint, parent)
	item.scale = scale
	return item


func _mesh(node_name: String, shape: Mesh, position: Vector3, paint: String, parent: Node3D = null) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = node_name
	item.mesh = shape
	item.material_override = paints[paint]
	item.position = position
	(parent if parent != null else root).add_child(item)
	return item


func _own(node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = root
		_own(child)
