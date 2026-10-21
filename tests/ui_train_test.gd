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
				if stage.front_distance>stage.distance*0.65 and not saw_train:
					saw_train = true
					saw_all_wagons = stage.train.get_node_or_null("FreightWagon04")!=null
					await capture("train")
				if stage.contact_times.has(traps[0]) and not saw_impact:
					saw_impact = true
					check(not (board._tile_views[traps[0]] as BoardSkin.Tile).trap_on,"Trap art breaks when the front reaches its tile")
					await capture("impact")
			victim_moved = victim_moved or (board._pawn_views[21] as Node2D).position.distance_to(victim_start)>20.0
			if stage.mode==&"idle" and not board._presentation_active():
				break
			await process_frame
		check(saw_lay and saw_pause and saw_train and saw_impact,"Track laying, pause, moving train and timed impacts all appear")
		check(saw_all_wagons and stage.wheels.size()==22,"Approved locomotive, all four wagons and rotating wheels are retained")
		check(stage.passed==(report.path as Array[int]),"Every route tile is contacted once and in the correct direction")
		check(victim_moved,"Actual victim sprites are physically thrown off the track")
		check(stage.mode==&"idle" and not stage.visible and board._train_controlled.is_empty() and board._train_trap_hold.is_empty(),"The presentation and all temporary holds finish cleanly")
		check(not board._presentation_active(),"No duplicate late capture animation remains in the queue")
		await capture("result")
	# Reset during construction must release both sprite and trap holds.
	arrange(2)
	var aborted := NpcSweep.run(board.state,16,1,8,&"TRAIN",1,true)
	board.state.npc_swept.emit(&"TRAIN",aborted.path,aborted.ejected)
	await frames(4)
	board._reset_presentation()
	board._refresh_all()
	check(board._train_stage.mode==&"idle" and not board._train_stage.visible and board._train_controlled.is_empty() and board._train_trap_hold.is_empty(),"Reset during track placement restores the authoritative board safely")
	board.instant_roll_for_test = true
	board._announcer.cancel()
	await frames(2)
	if failures.is_empty():
		print("TRAIN_UI_OK")
	else:
		for message: String in failures:
			printerr("TRAIN_UI_FAIL "+message)
	quit(0 if failures.is_empty() else 1)
