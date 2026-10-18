class_name TestRouletteSpin
extends TestCase


func test_all_faces_directions_powers_and_drag_offsets_finish_at_sector_center() -> void:
	for face: int in range(1,11):
		for power: float in [0.0,0.5,1.0]:
			for direction: float in [-1.0,1.0]:
				for start: float in [-9.2,0.0,0.313,8.17]:
					var distance: float = RouletteSpin3D.travel_for(face,power,start,direction)
					var end: float = start+direction*distance
					check_eq(RouletteSpin3D.face_under_pointer(end),face,"physical sector below pointer matches authoritative result")
					check(absf(wrapf(end-(face-1)*RouletteSpin3D.STEP,-PI,PI))<0.00001,"wheel stops at center, never a misleading boundary")
					check(distance>=2*TAU and distance<=5*TAU,"power changes travel within safe 2..5 turns")
	print("ROULETTE_FACE_COVERAGE 10/10, both directions")


func test_continuous_acceleration_and_braking_never_reverse_the_wheel() -> void:
	var previous: float = 0.0
	for step: int in 1001:
		var time: float = step*RouletteSpin3D.TOTAL_TIME/1000.0
		var value: float = RouletteSpin3D.progress_at(time)
		check(value>=previous and value<=1.000001,"rotation is monotonic throughout acceleration and brake")
		previous = value
	for time: float in [RouletteSpin3D.LEAD_TIME,RouletteSpin3D.LEAD_TIME+RouletteSpin3D.ACCEL_TIME,RouletteSpin3D.LEAD_TIME+RouletteSpin3D.ACCEL_TIME+RouletteSpin3D.COAST_TIME,RouletteSpin3D.SPIN_TIME]:
		var dt: float = 0.0001
		var before: float = (RouletteSpin3D.progress_at(time)-RouletteSpin3D.progress_at(time-dt))/dt
		var after: float = (RouletteSpin3D.progress_at(time+dt)-RouletteSpin3D.progress_at(time))/dt
		check(absf(before-after)<0.002,"phase changes preserve angular velocity")
	check(RouletteSpin3D.progress_at(0.0)==0 and is_equal_approx(RouletteSpin3D.progress_at(10.0),1.0),"timeline has stable endpoints")


func test_pointer_ticks_follow_physical_sector_boundaries_in_both_directions() -> void:
	for direction: float in [-1.0,1.0]:
		for start: float in [0.0,0.19,3.91]:
			var distance: float = RouletteSpin3D.travel_for(7,0.7,start,direction)
			var times: Array[float] = RouletteSpin3D.crossing_times(start,distance,direction)
			var previous: float = 0.0
			for time: float in times:
				check(time>previous and time<RouletteSpin3D.SPIN_TIME,"ticks are ordered and stop before final settlement")
				var a: float = start+direction*distance*RouletteSpin3D.progress_at(time-0.00001)
				var b: float = start+direction*distance*RouletteSpin3D.progress_at(time+0.00001)
				check(RouletteSpin3D.face_under_pointer(a)!=RouletteSpin3D.face_under_pointer(b),"each click coincides with an actual label boundary crossing")
				previous = time


func test_toy_geometry_has_outward_faces_and_stays_inside_the_camera() -> void:
	var camera: Basis = Basis.looking_at(RouletteSpin3D.CAMERA_TARGET-RouletteSpin3D.CAMERA_HOME)
	for mesh: ArrayMesh in [RouletteSpin3D.make_housing_mesh(),RouletteSpin3D.make_rotor_mesh(),RouletteSpin3D.make_pointer_mesh()]:
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i: int in range(0,vertices.size(),3):
			var cross: Vector3 = (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i])
			if cross.length_squared()>0.000001:
				check(cross.dot(normals[i])<0,"all nondegenerate triangles use clockwise front faces")
		for vertex: Vector3 in vertices:
			var point: Vector3 = vertex-RouletteSpin3D.CAMERA_TARGET
			check(absf(point.dot(camera.x))<RouletteSpin3D.CAMERA_SIZE*0.5-0.1 and absf(point.dot(camera.y))<RouletteSpin3D.CAMERA_SIZE*0.5-0.1,"housing remains inside orthographic frame")


func test_temporary_click_and_stop_are_distinct_short_cached_sounds() -> void:
	var tick: AudioStreamWAV = Sfx.synth(&"roulette_tick")
	var stop: AudioStreamWAV = Sfx.synth(&"roulette_stop")
	check(tick.get_length()<0.04 and stop.get_length()<0.10,"provisional feedback remains short")
	check(tick==Sfx.synth(&"roulette_tick") and stop==Sfx.synth(&"roulette_stop"),"audio data is cached")
	check(tick.data!=stop.data and tick.data!=Sfx.synth(&"yut_clack").data,"pointer and stop have distinct sounds")
