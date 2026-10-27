## SUPER_09 only: true leading enemy, one shot, ejection, boost and reset.
extends "res://tests/ui_super_fx_test.gd"

var shots: Dictionary = {}
var seen: Array[StringName] = []
var started := false
var ended := false
var observing := true
var rng_before := 0
var original_target := Vector2.ZERO
var original_booster := Vector2.ZERO
var fired := false
var impact_seen := false
var target_style: Dictionary = {}

func _run() -> void:
	GameSession.mode = GameSession.MODE_AI
	GameSession.pace_scale = 1.0
	await _check(SuperAugments.SNIPER)
	_expect(started and ended and fired and impact_seen,"Acquisition, one shot and release all finish")
	_expect(seen==[&"acquire",&"locked",&"impact"],"The reticle closes, holds lock and fires")
	await _check_cancel()
	if _failures.is_empty():
		print("UI_SNIPER_OK")
		quit(0)
	else:
		for failure: String in _failures:
			printerr("UI_SNIPER_FAIL: "+failure)
		quit(1)

func _stage(effect: StringName) -> void:
	super._stage(effect)
	_board._bot.set_enabled(false)
	_board.manager.set_process(false)
	var placements := {11:4,21:20,31:15,41:6}
	for pawn: PlayerPawn in _board.state.pawns:
		pawn.has_left_start = placements.has(pawn.entity_id)
		pawn.current_tile_idx = int(placements.get(pawn.entity_id,0))
		var view: Node2D = _board._pawn_views[pawn.entity_id]
		_board._kill_fx(view)
		view.position = _board._pawn_position(pawn)
		view.visible = pawn.has_left_start
	original_target = _board._pawn_views[21].position
	original_booster = _board._pawn_views[11].position
	var view: Node2D = _board._pawn_views[21]
	target_style = {"scale":view.scale,"rotation":view.rotation,"tint":view.modulate,"z":view.z_index}

func _process(_delta: float) -> bool:
	if not observing or _board==null or not is_instance_valid(_board):
		return false
	var stage: Node2D = _board.get_node_or_null("SniperStage")
	if stage!=null:
		if not started:
			started = true
			rng_before = _board.state.rng.state
			_expect(stage.target_id==21,"The actual leading enemy is selected")
			_expect(not _board.state.get_pawn(21).has_left_start and _board.state.get_pawn(11).current_tile_idx==8,"Engine ejection and +4 advance are authoritative before visuals")
		if not seen.has(stage.phase):
			seen.append(stage.phase)
		_expect(_board.state.rng.state==rng_before,"Aiming and hit feedback consume no gameplay RNG")
		_expect(_board._pawn_views[21].position.distance_to(original_target)<0.1,"The actual target stays at its source through the hit hold")
		_expect(_board._pawn_views[11].position.distance_to(original_booster)<0.1,"My advance waits until the sniper sequence ends")
		_expect(stage._veil.mouse_filter==Control.MOUSE_FILTER_IGNORE,"The vignette does not intercept controls")
		_expect(stage._tracer.mouse_filter==Control.MOUSE_FILTER_IGNORE and stage._tracer_material.shader==stage.TRACER_SHADER,"The sniper uses a nonblocking tapered tracer")
		_expect(stage.to_global(stage._at).distance_to(_board._pawn_layer.to_global(original_target+Vector2(0,-20)))<0.1,"Reticle and painted impact align with the actual target layer")
		if stage.elapsed>stage.HIT_AT+0.045:
			_expect(not stage._tracer.visible,"The tracer disappears after the bullet reaches its target")
		if stage.phase==&"acquire" and stage.elapsed>0.25:
			capture("acquire")
		if stage.phase==&"locked" and stage.elapsed>0.70:
			capture("locked")
		if stage.fired:
			fired = true
		if stage.hit_started:
			impact_seen = true
			if stage.elapsed>stage.HIT_AT+0.04:
				capture("impact")
	elif started and not ended:
		ended = true
		var view: Node2D = _board._pawn_views[21]
		_expect(view.modulate==target_style.tint and view.z_index!=36,"Target tint and focus depth restore before normal ejection")
	return false

func _drop_board() -> void:
	if observing and ended:
		var victim: PlayerPawn = _board.state.get_pawn(21)
		var booster: PlayerPawn = _board.state.get_pawn(11)
		_expect(not victim.has_left_start and victim.current_tile_idx==0 and victim.revenge_boost,"The victim stays ejected with its actual revenge bonus")
		_expect(booster.current_tile_idx==8 and _board._pawn_views[11].position.distance_to(_board._pawn_position(booster))<0.1,"The real queued advance finishes at +4")
		_expect(_board.state.get_pawn(31).current_tile_idx==15 and _board.state.get_pawn(41).current_tile_idx==6,"Unselected opponents remain in place")
	await super._drop_board()

func _check_cancel() -> void:
	observing = false
	_board = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	root.add_child(_board)
	var guard := 0
	while (not _board._draft_open or _board._intro_blocks()) and guard<2400:
		guard += 1
		await process_frame
	_stage(SuperAugments.SNIPER)
	_board._draft_overlay.hide()
	_board._announcer.cancel()
	_board._draft_deferred.clear()
	_board._super_changes.clear()
	SuperAugments.apply(SuperAugments.SNIPER,_board.state,1)
	_board._on_super_picked(1,SuperAugments.SNIPER)
	_board._draft_open = false
	_board._release_draft_deferred()
	guard = 0
	while _board.get_node_or_null("SniperStage")==null and guard<600:
		guard += 1
		await process_frame
	await create_timer(0.70).timeout
	_board._reset_presentation()
	await process_frame
	await process_frame
	var view: Node2D = _board._pawn_views[21]
	_expect(_board.get_node_or_null("SniperStage")==null,"Reset removes the reticle and vignette")
	_expect(view.modulate==target_style.tint and view.scale==target_style.scale and view.z_index==int(target_style.z),"Reset restores pawn tint, size and depth")
	_expect(not view.visible and not _board.state.get_pawn(21).has_left_start,"Reset preserves the actual ejection result")
	await _drop_board()

func capture(label: String) -> void:
	var folder := OS.get_environment("SNIPER_CAPTURE_DIR")
	if folder.is_empty() or shots.has(label):
		return
	shots[label] = true
	_save.call_deferred(folder,label)

func _save(folder: String,label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))
