## Only SUPER_07: real views, captured permutation, stacks and reset cleanup.
extends "res://tests/ui_super_fx_test.gd"

var seen: Array[StringName] = []
var shots: Dictionary = {}
var started := false
var ended := false
var rng_before := 0
var tiles: Dictionary = {}
var poses: Array[Dictionary] = []
var spin_samples: Array[float] = []

func _run() -> void:
	GameSession.mode = GameSession.MODE_AI
	GameSession.pace_scale = 1.0
	await _check(SuperAugments.CASTLING)
	_expect(started and ended,"Roulette finishes and removes its stage")
	_expect(seen==[&"mark",&"lift",&"spin",&"land"],"Source marks, lift, slowing spin and landing are visible")
	await _check_cancel()
	if _failures.is_empty():
		print("UI_CASTLING_OK")
		quit(0)
	else:
		for failure: String in _failures:
			printerr("UI_CASTLING_FAIL: "+failure)
		quit(1)

func _stage(effect: StringName) -> void:
	super._stage(effect)
	_board._bot.set_enabled(false)
	_board.manager.set_process(false)
	_board.state.stack_pawns(_board.state.get_pawn(11),_board.state.get_pawn(13))
	_board._pawn_views[13].hide()
	_board.state.get_pawn(41).is_finished = true
	_board._pawn_views[41].hide()

func _process(_delta: float) -> bool:
	if _board==null or not is_instance_valid(_board):
		return false
	var stage: Node2D = _board.get_node_or_null("CastlingStage")
	if stage!=null and not ended:
		if not started:
			started = true
			rng_before = _board.state.rng.state
			poses = stage.pawns.duplicate()
			for pawn: PlayerPawn in _board.state.pawns:
				tiles[pawn.entity_id] = pawn.current_tile_idx
			var ids := poses.map(func(item: Dictionary) -> int: return int(item.id))
			_expect(poses.size()==7 and not ids.has(13) and not ids.has(41) and not ids.has(14),"Only board leaders orbit; carried, finished and waiting pawns stay out")
		if not seen.has(stage.phase):
			seen.append(stage.phase)
		_expect(_board.state.rng.state==rng_before,"Roulette consumes no simulation RNG")
		for pawn: PlayerPawn in _board.state.pawns:
			_expect(pawn.current_tile_idx==int(tiles[pawn.entity_id]),"Presentation changes no authoritative tile")
		if stage.phase==&"spin" and stage.elapsed>0.95:
			capture("spin")
		if stage.phase==&"mark" and stage.elapsed>0.14:
			capture("mark")
		if stage.phase==&"lift" and stage.elapsed>0.54:
			capture("lift")
		if stage.phase==&"land" and stage.elapsed>2.28:
			capture("land")
	elif started and not ended:
		ended = true
		for item: Dictionary in poses:
			var view: Node2D = item.view.get_ref()
			_expect(view!=null and view.position.distance_to(item.to)<0.1,"Each real pawn lands at its captured destination")
			_expect(view.scale.is_equal_approx(item.scale) and is_equal_approx(view.rotation,float(item.rotation)) and view.z_index==int(item.z),"Pawn scale, rotation and depth return to rest")
	return false

func _check_cancel() -> void:
	_board = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	root.add_child(_board)
	var guard := 0
	while (not _board._draft_open or _board._intro_blocks()) and guard<2400:
		guard += 1
		await process_frame
	_stage(SuperAugments.CASTLING)
	_board._reset_presentation()
	_board._draft_overlay.hide()
	_board._announcer.cancel()
	SuperAugments.apply(SuperAugments.CASTLING,_board.state,1)
	var targets: Array[Dictionary] = []
	for pawn: PlayerPawn in SuperAugments.board_leaders(_board.state):
		targets.append({"pawn":pawn.entity_id,"tile":pawn.current_tile_idx,"position":_board._pawn_position(pawn)})
	var stage := SuperFX.CASTLING_STAGE.new()
	_board.add_child(stage)
	stage.play(_board,[{"kind":"castling_pose","pawns":targets}],1.0)
	# Another draft choice may already change the engine while this pick waits.
	var later: PlayerPawn = _board.state.get_pawn(int(targets[0].pawn))
	later.current_tile_idx = 7 if later.current_tile_idx!=7 else 8
	await create_timer(1.0).timeout
	_expect(stage.pawns[0].to==targets[0].position,"A later choice does not overwrite this pick's saved destination")
	_board._reset_presentation()
	await process_frame
	await process_frame
	_expect(_board.get_node_or_null("CastlingStage")==null,"Reset removes the roulette immediately")
	for target: Dictionary in targets:
		var pawn: PlayerPawn = _board.state.get_pawn(int(target.pawn))
		var view: Node2D = _board._pawn_views[int(target.pawn)]
		_expect(view.position.distance_to(_board._pawn_position(pawn))<0.1 and is_zero_approx(view.rotation),"Cancellation restores the current board pose")
	await _drop_board()

func capture(label: String) -> void:
	var folder := OS.get_environment("CASTLING_CAPTURE_DIR")
	if folder.is_empty() or shots.has(label):
		return
	shots[label] = true
	_save.call_deferred(folder,label)

func _save(folder: String,label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))
