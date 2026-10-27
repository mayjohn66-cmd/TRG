extends SceneTree

var started := false
var failures: Array[String] = []
var board: MainBoard

func _process(_delta: float) -> bool:
	if not started:
		started = true
		run()
	return false

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func frames(count: int) -> void:
	for index: int in count:
		await process_frame

func capture(title: String) -> void:
	var directory := OS.get_environment("TRAIN_CAPTURE_DIR")
	if directory=="":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(title+".png"))

func arrange(side_index: int) -> Array[int]:
	board.instant_roll_for_test = true
	board._reset_presentation()
	board._announcer.cancel()
	board.state.clear_npcs()
	for tile: int in BoardSpec.tile_count:
		board.state.board.get_tile(tile).attachments.clear()
	for pawn: PlayerPawn in board.state.pawns:
		pawn.reset_to_start()
		pawn.kind = GameEnums.PawnKind.BASIC
		pawn.unit_no = 1
		pawn.shield = false
	var start := side_index*BoardSpec.side
	for pair: Vector2i in [Vector2i(11,start+2),Vector2i(21,start+4),Vector2i(31,start+6),Vector2i(41,posmod(start+BoardSpec.side+3,BoardSpec.tile_count)),Vector2i(12,0)]:
		var pawn: PlayerPawn = board.state.get_pawn(pair.x)
		pawn.has_left_start = true
		pawn.current_tile_idx = pair.y
	var white: PlayerPawn = board.state.get_pawn(31)
	white.kind = GameEnums.PawnKind.GO
	white.unit_no = 2
	white.shield = true
	for tile: int in [start+3,start+6,posmod(start+BoardSpec.side+3,BoardSpec.tile_count)]:
		board.state.place_attachment(tile,TrapMine.new(1))
	board._refresh_all()
	board._announcer.cancel()
	board._announced_round = board.state.round_number
	board.instant_roll_for_test = false
	return [start+3,start+6]

func run() -> void:
	create_timer(65).timeout.connect(func() -> void: printerr("TRAIN_UI_FAIL timeout");quit(1))
	GameSession.mode = GameSession.MODE_AI
	GameSession.pace_scale = 1.0
	board = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	board.instant_roll_for_test = true
	root.add_child(board)
	await frames(4)
	board.ai_mode = false
	board._bot.set_enabled(false)
	board._on_draft_auto_pressed()
	board._announcer.cancel()
	board.pacing_enabled = false
	await frames(6)
	board._reset_presentation()
	board.manager.set_process(false)
	var sides: Array[int] = [0,1,2,3]
	if OS.get_environment("TRAIN_CAPTURE_DIR")!="":
		sides = [1]
	for side: int in sides:
		var traps := arrange(side)
		var stage := board._train_stage
		var victim_start: Vector2 = board._pawn_views[21].position
		var rng_before := board.state.rng.state
		var report := NpcSweep.run(board.state,side*BoardSpec.side,1,BoardSpec.side,&"TRAIN",1,true)
		board.state.npc_swept.emit(&"TRAIN",report.path,report.ejected)
		board._refresh_all()
		check(board.state.rng.state==rng_before,"Presentation never consumes gameplay RNG")
		check((report.ejected as Array).has(11) and (report.ejected as Array).has(21) and (report.ejected as Array).has(31),"Train clears allied, opposing and shielded pawns exactly as the engine specifies")
		check(board.state.get_pawn(41).has_left_start and board.state.get_pawn(12).has_left_start,"Other sides and the goal safe zone remain untouched")
		check(board._train_controlled.size()==3,"Exactly the authoritative path victims are controlled")
		check((board._tile_views[traps[0]] as BoardSkin.Tile).trap_on,"Destroyed trap art stays visible before the locomotive arrives")
		check(board._ui_busy(),"Input is blocked during the staged sweep")
		var saw_lay := false
		var saw_pause := false
		var saw_train := false
		var saw_impact := false
		var victim_moved := false
		var saw_all_wagons := false
		var saw_zoom := false
		var saw_forward_flight := false
		var saw_steam := false
		var last_motion := -1.0
		var motion_index := 0
		for tick: int in 1800:
			check(Engine.time_scale==1.0,"Presentation does not change global time scale")
			if stage.mode==&"lay":
				check(not stage.train.visible and stage.passed.is_empty(),"No train or contact before tracks are laid")
				if stage.laid_count>=3 and not saw_lay:
					saw_lay = true
					await capture("lay")
			if stage.mode==&"pause" and not saw_pause:
				saw_pause = true
				check(stage.laid_count==stage.segments.size() and not stage.train.visible,"All track sections land before the deliberate pause")
				check((board._tile_views[traps[0]] as BoardSkin.Tile).trap_on,"Pause preserves traps and victims")
				await capture("pause")
				if OS.get_environment("TRAIN_CAPTURE_DIR")!="":
					root.size = Vector2i(844,390)
					await frames(2)
					await capture("pause_mobile")
					root.size = Vector2i(1366,768)
					await frames(2)
			if stage.mode==&"run":
				if not saw_steam and not stage.smoke.is_empty():
					var steam: Node3D = stage.smoke[0].node
					saw_steam = true
					check(steam is Sprite3D and steam.texture==PaintedFx.SMOKE,"Chimney steam is a transparent painted billboard rather than sphere geometry")
					check(steam.billboard==BaseMaterial3D.BILLBOARD_ENABLED and not steam.shaded and steam.modulate.a<=0.78,"Steam faces the camera and fades without scene-light shading")
				if not saw_zoom:
					saw_zoom = true
					check(is_equal_approx(board._pawn_layer.scale.x,1.12) and board._pawn_layer.scale==board._board_layer.scale,"Entry zoom reaches 12 percent and board/pawns share the camera")
					check(board._tool_board.scale==Vector2.ONE,"HUD is not enlarged by the world camera")
					var norm := BoardLayout.tile_norm(stage.path[2])
					var model_ground := stage.image.transform*stage.camera.unproject_position(Vector3(norm.x,0,norm.y))
					check(model_ground.distance_to(board._pawn_layer.transform*board._tile_center(stage.path[2]))<0.1,"3D rail projection stays attached to the zoomed board in the same frame")
					await capture("entry_zoom")
				if stage.front_distance>stage.distance*0.65 and not saw_train:
					saw_train = true
					saw_all_wagons = stage.train.get_node_or_null("FreightWagon04")!=null
					await capture("train")
				if stage.contact_times.has(traps[0]) and not saw_impact:
					saw_impact = true
					check(not (board._tile_views[traps[0]] as BoardSkin.Tile).trap_on,"Trap art breaks when the front reaches its tile")
					await capture("impact")
			victim_moved = victim_moved or (board._pawn_views[21] as Node2D).position.distance_to(victim_start)>20.0
			for id: int in board._train_controlled:
				var info: Dictionary = board._train_controlled[id]
				var view: Node2D = board._pawn_views[id]
				if float(info.hit)<0.0:
					check(view.position.is_equal_approx(info.position),"Victim waits at its original tile until the locomotive arrives")
				elif not saw_forward_flight:
					var age := stage.elapsed-float(info.hit)
					if age>0.08 and age<0.3:
						saw_forward_flight = true
						var forward := (board._project(stage.origin+stage.direction*0.1)-board._project(stage.origin)).normalized()
						var horizontal_flight := view.position-(info.position as Vector2)-Vector2(0,-240.0*age+320.0*age*age)
						check(horizontal_flight.dot(forward)>age*250.0,"Impact throws the actual pawn mainly in the train's travel direction")
						await capture("pawn_flight")
			if stage.mode==&"idle" and not board._presentation_active():
				break
			if OS.get_environment("TRAIN_RECORD")=="1" and stage.elapsed-last_motion>=0.05:
				last_motion = stage.elapsed
				await capture("motion_%03d" % motion_index)
				motion_index += 1
			await process_frame
		check(saw_lay and saw_pause and saw_train and saw_impact,"Track laying, pause, moving train and timed impacts all appear")
		check(saw_all_wagons and stage.wheels.size()==22,"Approved locomotive, all four wagons and rotating wheels are retained")
		check(saw_steam and stage.smoke.is_empty(),"Painted chimney steam appears and clears when the train finishes")
		check(stage.passed==(report.path as Array[int]),"Every route tile is contacted once and in the correct direction")
		check(victim_moved,"Actual victim sprites are physically thrown off the track")
		check(saw_zoom and saw_forward_flight,"Entry camera and forward collision flight both play")
		check(board._pawn_layer.scale==Vector2.ONE and board._board_layer.scale==Vector2.ONE and is_zero_approx(board._train_camera_weight),"Camera restores its original scale after the wagons pass")
		check(stage.mode==&"idle" and not stage.visible and board._train_controlled.is_empty() and board._train_trap_hold.is_empty(),"The presentation and all temporary holds finish cleanly")
		check(not board._presentation_active(),"No duplicate late capture animation remains in the queue")
		await capture("result")
	# Interrupt during the zoomed run must release camera, sprite and trap holds.
	arrange(2)
	var aborted := NpcSweep.run(board.state,16,1,8,&"TRAIN",1,true)
	board.state.npc_swept.emit(&"TRAIN",aborted.path,aborted.ejected)
	while board._train_stage.mode!=&"run":
		await process_frame
	board._reset_presentation()
	board._refresh_all()
	check(board._train_stage.mode==&"idle" and not board._train_stage.visible and board._train_controlled.is_empty() and board._train_trap_hold.is_empty(),"Reset during the run restores the authoritative board safely")
	check(board._pawn_layer.scale==Vector2.ONE and board._board_layer.scale==Vector2.ONE and board._pawn_layer.position==board._off_center,"Interrupting a zoom restores the world camera")
	# A stalled browser frame must retain exact, ordered contact times rather than
	# starting all victim flights from the late frame's timestamp.
	var stage := board._train_stage
	stage.set_process(false)
	stage.play(aborted.path,1.0,board._train_plane)
	stage.advance(stage.run_start+RunawayTrainStage.RUN_TIME+0.05)
	var previous_hit := -1.0
	for tile: int in stage.path:
		check(stage.contact_times.has(tile) and float(stage.contact_times[tile])>previous_hit,"Skipped frames retain distinct contacts in route order")
		previous_hit = float(stage.contact_times[tile])
	check(previous_hit<stage.elapsed,"Late frames preserve the real impact time")
	stage.cancel()
	board._train_release()
	board.instant_roll_for_test = true
	board._announcer.cancel()
	await frames(2)
	board.queue_free()
	await frames(3)
	if failures.is_empty():
		print("TRAIN_UI_OK")
	else:
		for message: String in failures:
			printerr("TRAIN_UI_FAIL "+message)
	quit(0 if failures.is_empty() else 1)
