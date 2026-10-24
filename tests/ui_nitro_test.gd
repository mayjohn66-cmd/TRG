## SUPER_10 only: one controlled dash, acceleration, collision, finish and reset.
extends "res://tests/ui_super_fx_test.gd"

var shots: Dictionary = {}
var seen: Array[StringName] = []
var case_name := "corner"
var started := false
var ended := false
var observing := true
var rng_before := 0
var source := Vector2.ZERO
var arrival := Vector2.ZERO
var last_distance := 0.0
var last_elapsed := 0.0
var early_speed := 0.0
var late_speed := 0.0
var stage_count := 0

func _run() -> void:
	GameSession.mode = GameSession.MODE_AI
	GameSession.pace_scale = 1.0
	await _check(SuperAugments.NITRO)
	_expect(stage_count==1 and started and ended,"Lane and movement use one stage")
	_expect(seen==[&"lane",&"charge",&"dash",&"brake"],"Lane, charge, accelerated dash and clean corner stop are visible")
	_expect(late_speed>early_speed*1.5 and early_speed>0,"The moving pawn accelerates instead of gliding at a fixed speed")
	await _edge("collision",false)
	await _edge("finish",false)
	await _edge("corner",true)
	await _pending_reset()
	if _failures.is_empty():
		print("UI_NITRO_OK")
		quit(0)
	else:
		for failure: String in _failures:
			printerr("UI_NITRO_FAIL: "+failure)
		quit(1)

func _stage(effect: StringName) -> void:
	super._stage(effect)
	_board._bot.set_enabled(false)
	_board.manager.set_process(false)
	var placements := {11:3,12:1,21:12,31:15,41:20}
	if case_name=="collision":
		placements = {11:2,12:1,21:5,41:5,31:6}
	if case_name=="finish":
		placements = {11:BoardSpec.tile_count-3,12:1,21:12,31:15,41:20}
	for pawn: PlayerPawn in _board.state.pawns:
		pawn.has_left_start = placements.has(pawn.entity_id)
		pawn.current_tile_idx = int(placements.get(pawn.entity_id,0))
		var view: Node2D = _board._pawn_views[pawn.entity_id]
		_board._kill_fx(view)
		view.position = _board._pawn_position(pawn)
		view.visible = pawn.has_left_start
	source = _board._pawn_views[11].position
	_board._super_changes.clear()

func _process(_delta: float) -> bool:
	if not observing or _board==null or not is_instance_valid(_board):
		return false
	var stage: Node2D = _board.get_node_or_null("NitroStage")
	if stage!=null:
		if not started:
			started = true
			stage_count += 1
			rng_before = _board.state.rng.state
			arrival = stage.points[-1]
			_expect(stage.pawn_id==11 and not stage.artwork.is_empty(),"The front pawn and its real artwork are used")
			_expect(stage.path.back()==(5 if case_name=="collision" else 0 if case_name=="finish" else BoardSpec.side),"The route stops at the actual first blocker, corner or finish")
		if not seen.has(stage.phase):
			seen.append(stage.phase)
		_expect(_board.state.rng.state==rng_before,"Visuals consume no gameplay RNG")
		if not stage._complete:
			_expect(_board._fx_skip_steps.has(11),"Ordinary tile hops cannot compete with the dash")
		if stage.phase==&"lane":
			_expect(_board._pawn_views[11].position.distance_to(source)<0.1,"The lane appears before movement")
		if stage.phase==&"dash":
			var time := float(stage.elapsed)
			var speed := (float(stage.distance)-last_distance)/maxf(time-last_elapsed,0.001)
			var progress: float = (time-stage.DASH_START)/float(stage.dash_time)
			if progress>0.15 and progress<0.40:
				early_speed = maxf(early_speed,speed)
			if progress>0.70:
				late_speed = maxf(late_speed,speed)
			last_elapsed = time
			last_distance = float(stage.distance)
		if case_name=="collision" and not stage.arrived:
			for id: int in [21,41]:
				_expect(_board._pawn_views[id].visible and not _board._fx_running(_board._pawn_views[id]),"Victims wait for the actual collision")
		var readable: bool = stage.phase!=&"dash" or (float(stage.elapsed)-stage.DASH_START)/float(stage.dash_time)>0.70
		if float(stage.elapsed)>0.14 and case_name=="corner" and readable:
			capture(String(stage.phase))
		if stage.phase==&"impact":
			capture("collision")
		if case_name=="finish" and stage.arrived:
			capture("finish")
	elif started and not ended:
		ended = true
		_expect(not _board._nitro_skips.has(11) and not _board._fx_skip_steps.has(11),"The dash releases all movement gates")
	return false

func _verify_result() -> void:
	var pawn: PlayerPawn = _board.state.get_pawn(11)
	var view: Node2D = _board._pawn_views[11]
	_expect(is_zero_approx(view.rotation) and view.modulate==Color.WHITE and view.z_index==0,"Pawn presentation returns to rest")
	if case_name=="finish":
		_expect(pawn.is_finished and not view.visible,"The real finish is shown once, then the pawn leaves the board")
	else:
		_expect(pawn.current_tile_idx==(5 if case_name=="collision" else BoardSpec.side) and view.position.distance_to(_board._pawn_position(pawn))<0.1,"The dash lands at the authoritative destination")
	if case_name=="collision":
		_expect(not _board.state.get_pawn(21).has_left_start and not _board.state.get_pawn(41).has_left_start,"Both actual blockers are ejected")
		_expect(_board.state.get_pawn(31).current_tile_idx==6,"A pawn beyond the blocker is untouched")

func _drop_board() -> void:
	if observing and ended:
		_verify_result()
	await super._drop_board()

func _new_board(kind: String) -> void:
	case_name = kind
	started = false
	ended = false
	stage_count = 0
	seen.clear()
	last_distance = 0
	last_elapsed = 0
	_board = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	root.add_child(_board)
	var guard := 0
	while (not _board._draft_open or _board._intro_blocks()) and guard<2400:
		guard += 1
		await process_frame
	_stage(SuperAugments.NITRO)
	_board._draft_overlay.hide()
	_board._announcer.cancel()
	_board._draft_deferred.clear()
	SuperAugments.apply(SuperAugments.NITRO,_board.state,1)
	_board._on_super_picked(1,SuperAugments.NITRO)

func _edge(kind: String, cancel: bool) -> void:
	await _new_board(kind)
	_board._draft_open = false
	_board._release_draft_deferred()
	var start := Time.get_ticks_msec()
	while _board._presentation_active() and Time.get_ticks_msec()-start<16000:
		await process_frame
		var stage: Node2D = _board.get_node_or_null("NitroStage")
		if cancel and stage!=null and stage.phase==&"dash":
			observing = false
			_board._reset_presentation()
			await process_frame
			await process_frame
			_expect(_board.get_node_or_null("NitroStage")==null and _board._nitro_skips.is_empty() and not _board._fx_skip_steps.has(11),"Reset clears the running stage and movement gates")
			_verify_result()
			break
	if not cancel:
		_expect(started and ended and stage_count==1 and not _board._presentation_active(),"The requested edge-case dash finishes once")
	await _drop_board()
	observing = true

func _pending_reset() -> void:
	await _new_board("corner")
	observing = false
	_expect(_board._nitro_skips.has(11),"A deferred dash reserves movement ownership")
	_board._reset_presentation()
	_expect(_board._nitro_skips.is_empty() and not _board._fx_skip_steps.has(11),"Reset before playback releases the deferred movement gate")
	await _drop_board()

func capture(label: String) -> void:
	var folder := OS.get_environment("NITRO_CAPTURE_DIR")
	if folder.is_empty() or shots.has(label):
		return
	shots[label] = true
	_save.call_deferred(folder,label)

func _save(folder: String,label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))
