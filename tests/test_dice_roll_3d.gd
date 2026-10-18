class_name TestDiceRoll3D
extends TestCase


func test_all_six_results_show_the_correct_physical_top_face() -> void:
	for face: int in range(1, 7):
		for power: float in [0.0, 0.5, 1.0]:
			var pose: Transform3D = DiceRoll3D.pose_at(DiceRoll3D.ROLL_TIME, face, power)
			check_eq(DiceRoll3D.top_face(pose.basis.get_rotation_quaternion()), face, "final top face matches the engine result")
			check((pose.basis * DiceRoll3D.FACE_NORMALS[face - 1]).is_equal_approx(Vector3.UP), "result face rests flat, not on an edge")
			check(pose.origin.is_equal_approx(Vector3.UP), "die comes to rest on the table")
			check(pose.is_equal_approx(DiceRoll3D.pose_at(3.0, face, power)), "held result cannot keep rotating")


func test_six_faces_have_real_distinct_pips_and_opposite_faces_sum_to_seven() -> void:
	for face: int in range(1, 7):
		var pips: Array[Vector2] = DiceRoll3D.pip_positions(face)
		check_eq(pips.size(), face, "physical pip count")
		check(DiceRoll3D.FACE_NORMALS[face - 1].is_equal_approx(-DiceRoll3D.FACE_NORMALS[6 - face]), "opposite pair adds to seven")
		for i: int in pips.size():
			check(absf(pips[i].x) + DiceRoll3D.PIP_RADIUS < 1.0 - DiceRoll3D.ROUND_RADIUS, "pip stays on flat face")
			for j: int in range(i + 1, pips.size()):
				check(pips[i].distance_to(pips[j]) > 2.0 * DiceRoll3D.PIP_RADIUS, "pips do not overlap")


func test_tumbling_corners_never_pass_below_the_table() -> void:
	for face: int in range(1, 7):
		for power: float in [0.0, 1.0]:
			for step: int in range(1, 121):
				var pose: Transform3D = DiceRoll3D.pose_at(float(step) / 120.0, face, power)
				var rotation: Quaternion = pose.basis.get_rotation_quaternion()
				check(pose.origin.y + 0.00001 >= DiceRoll3D.support_height(rotation), "rotating rounded cube stays above the table")
				check(absf(pose.basis.determinant() - 1.0) < 0.0001, "roll never squashes the cube")
			for contact: float in [0.48, 0.78, 1.0]:
				var before: Transform3D = DiceRoll3D.pose_at(contact - 0.00001, face, power)
				var after: Transform3D = DiceRoll3D.pose_at(contact + 0.00001, face, power)
				check(before.origin.distance_to(after.origin) < 0.002, "bounce contacts never teleport the die")
