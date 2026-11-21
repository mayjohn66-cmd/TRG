extends TestCase

const MOTION = preload("res://scenes/pinball_motion.gd")


func test_physical_falls_hit_real_pegs_and_settle_inside_requested_pocket() -> void:
	var model: Node3D = (load("res://assets/models/pinball/pinball_base_v01.tscn") as PackedScene).instantiate()
	defer_free(model)
	var pegs: Array[Vector2] = []
	for peg: Node3D in model.get_node("StaggeredPegs33").get_children():
		var stem: MeshInstance3D = peg.get_node("SteelStem")
		pegs.append(Vector2(stem.position.x, stem.position.z))
	for hole: int in 7:
		var pocket: MeshInstance3D = model.get_node("SevenRecessedPockets/Pocket_%d_Value_%d/RecessFloor" % [hole, ToolPinball.HOLES[hole]])
		for mask: int in [0, 1, 2]:
			var bits: Array[int] = []
			for bit: int in 6:
				bits.append((mask >> bit) & 1)
			var flight: Dictionary = MOTION.trajectory(hole, bits)
			var points: PackedVector3Array = flight["positions"]
			var target: Vector3 = points[-1]
			check_eq(flight["hole"], hole, "physical launch reaches the authoritative result")
			check(int(flight["hits"]) >= 3, "fall actually collides with multiple pegs")
			check(float(flight["duration"]) < 3.1, "physics settles without an extended input lock")
			check(points[0].is_equal_approx(MOTION.arch_position(1.0)), "track exit and physics join without teleporting")
			check(absf(target.x - pocket.position.x) + MOTION.RADIUS < pocket.get_aabb().size.x / 2.0, "ball rests within physical pocket width")
			check(absf(target.z - pocket.position.z) + MOTION.RADIUS <= pocket.get_aabb().size.z / 2.0 + 0.001, "ball rests within physical pocket depth")
			check(is_equal_approx(target.y - MOTION.RADIUS, pocket.position.y + pocket.get_aabb().size.y / 2.0), "ball rests on actual pocket floor")
			check(MOTION.sample(points, float(flight["duration"]) + 1.0).is_equal_approx(target), "playback holds its natural resting point")
			var minimum_contact: float = INF
			for index: int in range(1, points.size()):
				check(points[index].distance_to(points[index - 1]) < 0.10, "fixed-step motion has no position snaps")
				var a := Vector2(points[index - 1].x, points[index - 1].z)
				var b := Vector2(points[index].x, points[index].z)
				for peg: Vector2 in pegs:
					var clearance: float = peg.distance_to(Geometry2D.get_closest_point_to_segment(peg, a, b))
					minimum_contact = minf(minimum_contact, clearance)
					check(clearance >= 0.249, "sphere does not pass through peg caps")
			check(minimum_contact < 0.254, "trajectory touches pegs rather than avoiding them")


func test_ball_fits_launch_rails_along_the_complete_arch() -> void:
	for step: int in 101:
		var point: Vector3 = MOTION.arch_position(step / 100.0)
		var radial: float = Vector2(point.x, point.z - MOTION.ARCH_Z).length()
		check(radial - MOTION.RADIUS > 2.61 + 0.055, "ball clears inner rail")
		check(radial + MOTION.RADIUS < 2.98 - 0.055, "ball clears outer rail")


func test_gravity_accelerates_before_first_contact_and_impacts_change_velocity() -> void:
	var flight: Dictionary = MOTION.trajectory(3, [1])
	var points: PackedVector3Array = flight["positions"]
	var impacts: PackedFloat32Array = flight["impacts"]
	var before: Vector3 = (points[2] - points[1]) / MOTION.STEP
	var later: Vector3 = (points[10] - points[9]) / MOTION.STEP
	check(impacts[0] > 10.0 * MOTION.STEP, "acceleration sample precedes first contact")
	check(later.z > before.z + 0.3, "gravity increases downhill speed instead of constant route speed")
	var contact: int = roundi(impacts[0] / MOTION.STEP)
	var incoming: Vector3 = (points[contact - 1] - points[contact - 2]) / MOTION.STEP
	var outgoing: Vector3 = (points[contact + 2] - points[contact + 1]) / MOTION.STEP
	check(incoming.normalized().dot(outgoing.normalized()) < 0.98, "peg contact changes travel direction")
