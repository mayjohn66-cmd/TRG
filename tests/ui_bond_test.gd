## SUPER_12 only: front/rear selection, clasp, persistent cuffs, shared result and reset.
extends "res://tests/ui_super_fx_test.gd"

var seen: Array[StringName] = []
var started := false
var ended := false
var transfer_seen := false
var echo_seen := false
var observing := true
var rng_before := 0
var positions: Dictionary = {}
var shots: Dictionary = {}
var result_kind: StringName = &"bind"

func _run() -> void:
	GameSession.mode = GameSession.MODE_AI
	GameSession.pace_scale = 1.0
	await _check(SuperAugments.GUARANTEE)
	_expect(started and ended and seen==[&"mark",&"reach",&"lock",&"pulse"],"Two ends grow separately, lock once, and pulse together")
	await _result(&"eject")
	await _result(&"finish")
	await _cancel_case()
	if _failures.is_empty():
		print("UI_BOND_OK")
		quit(0)
	else:
		for failure: String in _failures:
			printerr("UI_BOND_FAIL: "+failure)
		quit(1)

func _stage(effect: StringName) -> void:
	super._stage(effect)
	_board._bot.set_enabled(false)
	_board.manager.set_process(false)
	for id: int in [11,12,13]:
		positions[id] = _board._pawn_views[id].position

func _process(_delta: float) -> bool:
	if not observing or _board==null or not is_instance_valid(_board):
		return false
	var stage: Node2D = _board.get_node_or_null("BondStage")
	if stage!=null:
		if not started:
			started = true
			rng_before = _board.state.rng.state
			_expect(stage.a_id==13 and stage.b_id==11,"The real front and rear pawns are bonded")
		if not seen.has(stage.phase):
			seen.append(stage.phase)
		_expect(_board.state.rng.state==rng_before,"Chain visuals consume no gameplay RNG")
		_expect(stage._veil.mouse_filter==Control.MOUSE_FILTER_IGNORE,"The focus veil does not intercept controls")
		_expect(_board._pawn_views[12].position.distance_to(positions[12])<0.1,"The middle pawn remains untouched")
		if stage.mode==&"bind":
			for id: int in [11,13]:
				_expect(_board._pawn_views[id].position.distance_to(positions[id])<0.1,"Chains attach to the actual pawns without moving them")
			if stage.elapsed>0.13 and stage.phase!=&"mark":
				capture(String(stage.phase))
		else:
			_expect(stage.mode==result_kind,"The actual finish/ejection selects the pulse colour")
			transfer_seen = transfer_seen or stage.phase==&"transfer"
			echo_seen = echo_seen or stage.phase==&"echo"
			if stage.elapsed>0.30:
				capture(String(stage.mode)+"_"+String(stage.phase))
	elif started and not ended:
		ended = true
		for id: int in [11,13]:
			_expect(_board._pawn_views[id].z_index==0,"Focus depth returns to normal")
	return false

func _drop_board() -> void:
	if observing and ended and result_kind==&"bind":
		_expect(_board.state.bonds.get(13)==11 and _board.state.bonds.get(11)==13,"The real bond remains unchanged")
		for id: int in [11,13]:
			_expect(_board._pawn_views[id].get_node_or_null("BondRing")!=null,"Both bonded pawns keep their small metal cuffs")
		_expect(_board._pawn_views[12].get_node_or_null("BondRing")==null,"The middle pawn gets no cuff")
	await super._drop_board()

func _new_board() -> void:
	observing = false
	_board = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	root.add_child(_board)
	var guard := 0
	while (not _board._draft_open or _board._intro_blocks()) and guard<2400:
		guard += 1
		await process_frame
	_stage(SuperAugments.GUARANTEE)
	_board._draft_open = false
	_board._draft_deferred.clear()
	_board._super_changes.clear()
	started = false
	ended = false
	seen.clear()
	transfer_seen = false
	echo_seen = false

func _result(kind: StringName) -> void:
	await _new_board()
	result_kind = kind
	_board.state.bind_pawns(_board.state.get_pawn(13),_board.state.get_pawn(11))
	observing = true
	if kind==&"eject":
		_board.state.send_to_start(_board.state.get_pawn(13),2)
	else:
		_board.state.finish_stack(_board.state.get_pawn(13))
	await process_frame
	await process_frame
	var start := Time.get_ticks_msec()
	while _board._presentation_active() and Time.get_ticks_msec()-start<18000:
		await process_frame
	await process_frame
	await process_frame
	_expect(started and ended and transfer_seen and echo_seen,"A shared result travels down the chain and reaches the partner once")
	_expect(not _board._presentation_active() and _board.state.bonds.is_empty(),"The resolved bond releases its presentation queue")
	# Normal finish settling may start after the result-pulse queue releases.
	var settle_start := Time.get_ticks_msec()
	while (_board._pawn_views[11].visible or _board._pawn_views[13].visible) and Time.get_ticks_msec()-settle_start<1800:
		await process_frame
	for id: int in [11,13]:
		var pawn: PlayerPawn = _board.state.get_pawn(id)
		_expect(pawn.is_finished if kind==&"finish" else not pawn.has_left_start,"Both pawns retain the actual shared outcome")
		_expect(not _board._pawn_views[id].visible,"Both resolved pawns leave the board: %s / %d" % [kind,id])
		_expect(_board._pawn_views[id].get_node_or_null("BondRing")==null,"Resolved cuffs are removed")
	await _drop_board()

func _cancel_case() -> void:
	await _new_board()
	result_kind = &"bind"
	SuperAugments.apply(SuperAugments.GUARANTEE,_board.state,1)
	_board._on_super_picked(1,SuperAugments.GUARANTEE)
	_board._release_draft_deferred()
	var guard := 0
	while _board.get_node_or_null("BondStage")==null and guard<600:
		guard += 1
		await process_frame
	await create_timer(0.40).timeout
	_board._reset_presentation()
	await process_frame
	await process_frame
	_expect(_board.get_node_or_null("BondStage")==null,"Reset removes the chain, lock and focus veil")
	for id: int in [11,13]:
		_expect(_board._pawn_views[id].z_index==0,"Reset restores both pawn depths")
	_expect(_board.state.bonds.get(13)==11,"Cancelling visuals does not cancel the actual bond")
	await _drop_board()

func capture(label: String) -> void:
	var folder := OS.get_environment("BOND_CAPTURE_DIR")
	if folder.is_empty() or shots.has(label):
		return
	shots[label] = true
	_save.call_deferred(folder,label)

func _save(folder: String,label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))
