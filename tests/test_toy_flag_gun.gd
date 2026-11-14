class_name TestToyFlagGun
extends TestCase


func test_assembled_model_keeps_the_fitted_cylinder_and_independent_parts() -> void:
	var before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var model: Node3D = ToyFlagGun3D.MODEL.instantiate()
	check_eq(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), before + 46, "The flat approved assembly contains exactly its 46 owned nodes, without displaced copies")
	defer_free(model)
	var mount: Node3D = model.get_node("Body/CylinderMount")
	var drum: Node3D = mount.get_node("Cylinder")
	check_eq(mount.get_child_count(),1,"only one geometric cylinder is mounted")
	check(drum.has_node("SixBoreSteelDrum") and drum.has_node("SingleLoadedCartridge"),"approved six-bore drum and single cartridge are used")
	check(drum.scale.is_equal_approx(Vector3(1,1,1.44)),"assembly preserves its fitted length")
	check(model.has_node("Body/ExposedCurvedHammer") and model.has_node("Body/CurvedTrigger"),"actual hammer and trigger can animate independently")
	# Check all vertices of the closed model against the real resting camera.
	check_mesh_framing(model,Transform3D.IDENTITY)


func check_mesh_framing(node: Node3D, parent_transform: Transform3D) -> void:
	var transformed: Transform3D = parent_transform*node.transform
	if node is MeshInstance3D:
		var instance: MeshInstance3D = node
		for surface: int in instance.mesh.get_surface_count():
			var vertices: PackedVector3Array = instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices:
				var p: Vector3 = ToyFlagGun3D.HOME+transformed*vertex*ToyFlagGun3D.MODEL_SCALE-ToyFlagGun3D.CAMERA_TARGET
				check(absf(p.x)<3.20 and absf(p.y)<1.90,"closed model fits the gameplay camera")
	for child: Node in node.get_children():
		if child is Node3D: check_mesh_framing(child,transformed)


func test_six_loaded_positions_keep_the_original_accumulation_loss_and_cashout() -> void:
	var rng := RandomNumberGenerator.new()
	for slot: int in 6:
		var tool := ToolRussianRoulette.new()
		tool.load_chamber(slot)
		for pull: int in 5:
			var result: RollResult = tool.roll(rng)
			if pull==slot:
				check(result.details.fired and result.steps==0 and result.ends_turn,"party flag preserves the fired outcome and turn end")
				check_eq(result.details.lost,pull*3,"same accumulated steps disappear")
				break
			check(not result.details.fired and result.steps==(pull+1)*3,"empty clicks preserve +3 accumulation")
			if pull==4:
				check(not result.can_continue and not tool.has_pending_state(),"fifth safe pull commits fifteen automatically")
			else:
				check(result.can_continue and tool.has_pending_state(),"safe click allows a later choice")
	var tool := ToolRussianRoulette.new()
	tool.load_chamber(4)
	tool.roll(rng)
	tool.roll(rng)
	var confirmed: RollResult = tool.cash_out()
	check(confirmed.details.voluntary and confirmed.steps==6 and not tool.has_pending_state(),"voluntary stop confirms six without another roll")
	print("TOY_REVOLVER_OUTCOME_COVERAGE 6/6")


func test_spring_unfolds_monotonically_and_recoil_returns_to_a_rigid_rest_pose() -> void:
	var previous: float = 0.0
	for i: int in 101:
		var seconds: float = ToyFlagGun3D.CLICK_TIME+ToyFlagGun3D.FLAG_EXTEND*i/100.0
		var extension: float = ToyFlagGun3D.spring_extension(seconds)
		check(extension>=previous and extension<=1.000001,"pole unfolds continuously without snapping backwards")
		previous = extension
		var pose: Transform3D = ToyFlagGun3D.gun_pose_at(seconds,true)
		check(absf(pose.basis.determinant()-1.0)<0.00001,"plastic body remains rigid")
	check(ToyFlagGun3D.gun_pose_at(2.0,true).is_equal_approx(Transform3D(Basis.IDENTITY,ToyFlagGun3D.HOME)),"toy returns to its exact resting pose")
	check_eq(ToyFlagGun3D.spring_extension(0),0.0,"flag cannot deploy before public click time")
	check_eq(ToyFlagGun3D.spring_extension(3),1.0,"flag stays attached at full extension")


func test_confetti_and_deployed_flag_fit_the_same_fixed_camera() -> void:
	var camera: Basis = Basis.looking_at(ToyFlagGun3D.CAMERA_TARGET-ToyFlagGun3D.CAMERA_HOME)
	var half_y: float = ToyFlagGun3D.CAMERA_SIZE*0.5
	var half_x: float = half_y*ToyFlagGun3D.RENDER_SIZE.x/ToyFlagGun3D.RENDER_SIZE.y
	for index: int in ToyFlagGun3D.CONFETTI_COUNT:
		for i: int in 34:
			var pose: Transform3D = ToyFlagGun3D.confetti_pose_at(i*0.03,index)
			var point: Vector3 = pose.origin-ToyFlagGun3D.CAMERA_TARGET
			check(absf(point.dot(camera.x))<half_x-0.12 and absf(point.dot(camera.y))<half_y-0.12,"paper travels inside the view rather than being cropped")
	for x: float in [-1.8,-0.32]:
		for y: float in [-0.80,0.0]:
			var point: Vector3 = ToyFlagGun3D.HOME+ToyFlagGun3D.MUZZLE+Vector3(x,y,0.12)-ToyFlagGun3D.CAMERA_TARGET
			check(absf(point.dot(camera.x))<half_x-0.12 and absf(point.dot(camera.y))<half_y-0.12,"entire star flag remains inside the view")


func test_flag_has_real_wave_geometry_and_clockwise_faces() -> void:
	var arrays: Array = ToyFlagGun3D.make_flag_mesh().surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	check_eq(vertices.size(),189,"21 by 9 vertices support actual cloth ripples")
	for i: int in range(0,indices.size(),3):
		var a: Vector3 = vertices[indices[i]]
		var b: Vector3 = vertices[indices[i+1]]
		var c: Vector3 = vertices[indices[i+2]]
		check((b-a).cross(c-a).dot(Vector3.BACK)<0,"cloth uses Godot clockwise front faces")


func test_captions_and_sounds_describe_a_party_toy_and_actual_steps() -> void:
	check_eq(ToyFlagGun3D.result_caption(true,0,6),"뿅! 누적 6칸 사라짐 · 턴 종료","flag reports actual lost steps")
	check_eq(ToyFlagGun3D.result_caption(false,9,0),"","safe click shows no accumulation caption (the gun animation tells it)")
	check_eq(ToyFlagGun3D.result_caption(false,15,0,false),"","automatic fifteen shows no planned-move caption")
	check(Sfx.synth(&"toy_click").get_length()<0.06,"plastic click stays short")
	check(Sfx.synth(&"toy_party_pop").data!=Sfx.synth(&"shot").data,"party spring does not reuse a gunshot")
	check(Sfx.synth(&"toy_party_pop")==Sfx.synth(&"toy_party_pop"),"party sound is cached")
