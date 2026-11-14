class_name TestDiceRoll3D
extends TestCase
const Bowl = preload("res://scenes/chinchiro_bowl_model.gd")


func test_chinchiro_bowl_has_a_solid_wall_open_cavity_and_no_degenerate_faces() -> void:
	var mesh: ArrayMesh = Bowl.make_mesh()
	var arrays: Array = mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var edges: Dictionary = {}
	for index: int in range(0, points.size(), 3):
		var a: Vector3 = points[index]
		var b: Vector3 = points[index+1]
		var c: Vector3 = points[index+2]
		check((b-a).cross(c-a).length_squared()>0.000000001,"bowl has no zero-area triangles")
		for vertex: int in range(index,index+3):
			check(points[vertex].is_finite() and normals[vertex].is_finite(),"finite ceramic geometry and normals")
			var next: int = index+(vertex-index+1)%3
			var p: Vector3 = (points[vertex]*10000.0).round()
			var q: Vector3 = (points[next]*10000.0).round()
			var key: String = "%s|%s"%[str(p),str(q)] if str(p)<str(q) else "%s|%s"%[str(q),str(p)]
			edges[key] = int(edges.get(key,0))+1
	for count: int in edges.values():
		check(count==2,"ceramic shell is watertight, including the foot and lip")
	check(mesh.get_aabb().size.y>2.1,"rice bowl has visible depth")
	check(is_equal_approx(Bowl.floor_height(0),Bowl.FLOOR_Y) and Bowl.floor_height(3.1)>2.0,"low central cavity rises into a curved wall")


func test_chinchiro_bounces_stay_inside_the_bowl_and_keep_every_loaded_result() -> void:
	var vertices: PackedVector3Array = DiceRoll3D._make_body_mesh().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for entry: Vector2 in [Vector2(-1,-1),Vector2(-1,1),Vector2(1,-1),Vector2(1,1)]:
		for face: int in range(1,7):
			for power: float in [0.0,1.0]:
				for time: float in [0.42,0.55,0.70,0.85,1.0]:
					var pose: Transform3D = DiceRoll3D.bowl_pose_at(time,face,power,entry)
					check(absf(pose.basis.determinant()-pow(Bowl.DIE_SCALE,3))<0.0001,"die stays rigid inside the bowl")
					for vertex: int in range(0,vertices.size(),32):
						var point: Vector3 = pose*vertices[vertex]
						check(point.y>=Bowl.floor_height(Vector2(point.x,point.z).length())-0.002,"rounded die does not penetrate the ceramic")
				var final: Transform3D = DiceRoll3D.bowl_pose_at(1.0,face,power,entry)
				check_eq(DiceRoll3D.top_face(final.basis.orthonormalized().get_rotation_quaternion()),face,"loaded die result is preserved")
				check(final.is_equal_approx(DiceRoll3D.bowl_pose_at(3.0,face,power,entry)),"result remains still in the bowl")
	for contact: float in DiceRoll3D.BOWL_CONTACTS:
		var before: Transform3D = DiceRoll3D.bowl_pose_at(contact-0.00001,3,0.75,Vector2(1,1))
		var after: Transform3D = DiceRoll3D.bowl_pose_at(contact+0.00001,3,0.75,Vector2(1,1))
		check(before.origin.distance_to(after.origin)<0.003,"wall and floor contacts are continuous")


func test_yacht_results_face_the_camera_without_moving_after_settle() -> void:
	for face: int in range(1, 7):
		for index: int in 5:
			var pose: Transform3D = YachtRoll3D.pose_at(YachtRoll3D.TOTAL_TIME, face, index)
			check((pose.basis * DiceRoll3D.FACE_NORMALS[face - 1]).is_equal_approx(Vector3.BACK), "all six results face the viewer squarely in every slot")
			check(pose.is_equal_approx(YachtRoll3D.pose_at(8.0, face, index)), "held result remains completely still")
			check(is_equal_approx(pose.origin.x, (index - 2) * YachtRoll3D.GAP) and is_zero_approx(pose.origin.y), "five results settle into one row")


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


func test_chinchiro_faces_match_the_engine_including_negative_six() -> void:
	var values: Array[int] = DiceRoll3D.face_values(&"CHINCHIRO")
	check_eq(values, [4, 4, 5, 5, 6, -6] as Array[int], "loaded die has the engine's six values")
	for physical_side: int in range(1, 7):
		var value: int = values[physical_side - 1]
		check_eq(DiceRoll3D.pip_positions(absi(value)).size(), absi(value), "every loaded side has its painted pip count")
		var pose: Transform3D = DiceRoll3D.pose_at(DiceRoll3D.ROLL_TIME, physical_side, 0.5)
		check_eq(values[DiceRoll3D.top_face(pose.basis.get_rotation_quaternion()) - 1], value, "all six painted sides can rest face-up")
	for value: int in [4, 5, 6, -6]:
		var side: int = DiceRoll3D.physical_face_for(value, &"CHINCHIRO")
		check_eq(values[side - 1], value, "outcome selects a matching physical side")
	check(DiceRoll3D.physical_face_for(6, &"CHINCHIRO") != DiceRoll3D.physical_face_for(-6, &"CHINCHIRO"), "six and oops are distinct physical faces")
	check_eq(DiceRoll3D.face_values(&"D6"), [1, 2, 3, 4, 5, 6] as Array[int], "ordinary D6 keeps its original faces")
