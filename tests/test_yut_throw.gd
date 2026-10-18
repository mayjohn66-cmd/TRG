class_name TestYutThrow
extends TestCase


func test_six_results_have_matching_physical_faces_and_a_unique_backdo() -> void:
	var counts: Dictionary = {-1:1,1:1,2:2,3:3,4:4,5:0}
	for value: int in ToolYut.FACES:
		var flags: Array[bool] = YutThrow3D.flat_faces(value)
		check_eq(flags.size(),4,"exactly four wooden sticks")
		check_eq(flags.count(true),counts[value],"belly count matches the actual result")
		for index: int in 4:
			var pose: Transform3D = YutThrow3D.pose_at(2.0,index,value,0.5)
			var flat: bool = (pose.basis*Vector3.DOWN).dot(Vector3.UP)>0.9
			check(flat==flags[index],"actual flat-face normal matches the selected outcome")
			check(pose.is_equal_approx(YutThrow3D.pose_at(4.0,index,value,0.5)),"settled sticks cannot keep spinning")
	check(not YutThrow3D.flat_faces(1)[YutThrow3D.MARKED_STICK],"ordinary Do has the marked stick facing down")
	check(YutThrow3D.flat_faces(-1)[YutThrow3D.MARKED_STICK],"only Backdo reveals the marked belly as the single flat")
	check_eq(ToolYut.FACES,[-1,1,2,3,4,5] as Array[int],"engine outcome set stays unchanged")
	print("YUT_FACE_COVERAGE 6/6")


func test_actual_half_round_mesh_stays_rigid_and_above_the_mat() -> void:
	var mesh: ArrayMesh = YutThrow3D.make_body_mesh()
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(vertices.size()>100,"real half-round body has curved geometry")
	for value: int in ToolYut.FACES:
		for power: float in [0.0,1.0]:
			for index: int in 4:
				for step: int in 13:
					var time: float = YutThrow3D.LEAD_TIME+step/10.0
					var pose: Transform3D = YutThrow3D.pose_at(time,index,value,power)
					var lowest: float = INF
					for vertex: Vector3 in vertices:
						lowest = minf(lowest,(pose*vertex).y)
					check(lowest >= YutThrow3D.TABLE_Y-0.00001,"actual mesh corners stay above the landing mat")
					check(absf(pose.basis.determinant()-1.0)<0.0001,"hard wooden sticks never squash or stretch")
				var hit: float = YutThrow3D.impact_time(index)
				var before: Transform3D = YutThrow3D.pose_at(hit-0.00001,index,value,power)
				var after: Transform3D = YutThrow3D.pose_at(hit+0.00001,index,value,power)
				check(before.origin.distance_to(after.origin)<0.003,"first contacts do not teleport")


func test_every_toss_fits_the_camera_and_settled_sticks_do_not_overlap() -> void:
	var camera: Basis = Basis.looking_at(YutThrow3D.CAMERA_TARGET-YutThrow3D.CAMERA_HOME)
	var half_height: float = YutThrow3D.CAMERA_SIZE*0.5
	var half_width: float = half_height*YutThrow3D.RENDER_SIZE.x/YutThrow3D.RENDER_SIZE.y
	for value: int in ToolYut.FACES:
		for power: float in [0.0,1.0]:
			for index: int in 4:
				for step: int in 41:
					var time: float = YutThrow3D.LEAD_TIME+step*0.03
					var pose: Transform3D = YutThrow3D.pose_at(time,index,value,power)
					for x: float in [-1.0,1.0]:
						for y: float in [-1.0,1.0]:
							for z: float in [-1.0,1.0]:
								var corner := Vector3(x*YutThrow3D.RADIUS,y*YutThrow3D.RADIUS*0.5,z*YutThrow3D.HALF_LENGTH)
								var point: Vector3 = pose*corner-YutThrow3D.CAMERA_TARGET
								check(absf(point.dot(camera.x))<half_width-0.05 and absf(point.dot(camera.y))<half_height-0.05,"spinning ends and outline remain inside render frame")
		for index: int in 3:
			var a: Transform3D = YutThrow3D.pose_at(2.0,index,value,0.5)
			var b: Transform3D = YutThrow3D.pose_at(2.0,index+1,value,0.5)
			var a_width: float = absf(a.basis.x.x)*YutThrow3D.RADIUS+absf(a.basis.z.x)*YutThrow3D.HALF_LENGTH
			var b_width: float = absf(b.basis.x.x)*YutThrow3D.RADIUS+absf(b.basis.z.x)*YutThrow3D.HALF_LENGTH
			check(a.origin.x+a_width<b.origin.x-b_width,"resting sticks have a real gap rather than interpenetrating")


func test_wood_surface_and_carvings_face_outward_in_godot() -> void:
	for mesh: ArrayMesh in [YutThrow3D.make_body_mesh(),YutThrow3D.make_mark_mesh(false),YutThrow3D.make_mark_mesh(true)]:
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i: int in range(0,vertices.size(),3):
			var cross: Vector3 = (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i])
			if cross.length_squared()>0.00000001:
				check(cross.dot(normals[i]+normals[i+1]+normals[i+2])<0,"clockwise outward surfaces remain visible below the inverted outline")
	check(ResourceLoader.exists("res://assets/ui/trickcal/yut/YUT_WOOD.png"),"real generated wood texture is bundled")


func test_power_changes_only_motion_and_sounds_are_distinct_cached_wood() -> void:
	for value: int in ToolYut.FACES:
		for index: int in 4:
			check(YutThrow3D.pose_at(2.0,index,value,0.0).is_equal_approx(YutThrow3D.pose_at(2.0,index,value,1.0)),"power cannot change final result or placement")
	check(not YutThrow3D.pose_at(0.4,0,1,0.0).is_equal_approx(YutThrow3D.pose_at(0.4,0,1,1.0)),"power visibly changes the flight")
	var sound: AudioStreamWAV = Sfx.synth(&"yut_clack")
	check(sound != null and sound.get_length()<0.10,"wood contact is a short click")
	check(sound.data!=Sfx.synth(&"mahjong_tap").data,"wood clack is distinct from hard resin tiles")
	check(sound==Sfx.synth(&"yut_clack"),"wood sound sample is cached")
	check(Sfx.synth(&"yut_toss") != null,"throw has its own short air cue")
