## Only SUPER_03: actual draft queue, payoff timing, authoritative state and reset.
extends "res://tests/ui_super_fx_test.gd"

var seen: Array[StringName] = []
var shots: Dictionary = {}
var stage_started := false
var checked_end := false
var offering_id := -1
var bonus_at_stage := 0
var rng_at_stage := 0
var observe := true

func _run() -> void:
	GameSession.mode = GameSession.MODE_AI
	GameSession.pace_scale = 1.0
	await _check(SuperAugments.DEVIL)
	_expect(seen==[&"offering",&"consume",&"transfer",&"ignite"],"Offering, sacrifice, energy transfer and ignition play in order")
	_expect(checked_end,"The contract restores the sacrificed pawn's presentation")
	observe = false
	await _check_cancel()
	if _failures.is_empty():
		print("UI_DEVIL_OK")
		quit(0)
	else:
		for failure: String in _failures:
			printerr("UI_DEVIL_FAIL: "+failure)
		quit(1)

func _stage(effect: StringName) -> void:
	super._stage(effect)
	_board.ai_mode = false
	_board._bot.set_enabled(false)
	_board.manager.set_process(false)
	offering_id = _board.state.pawns_of(1)[3].entity_id

func _process(_delta: float) -> bool:
	if not observe or _board==null or not is_instance_valid(_board):
		return false
	var stage: Node2D = _board.get_node_or_null("DevilContractStage")
	if stage!=null:
		if not stage_started:
			stage_started = true
			bonus_at_stage = int(_board.state.permanent_roll_bonus.get(1,0))
			rng_at_stage = _board.state.rng.state
			_expect(stage.pawn_id==offering_id and stage.player_id==1,"Only the actual finished offering belongs to this contract")
			_expect(bonus_at_stage==SuperAugments.devil_bonus(),"The rule grants its configured bonus exactly once")
		if not seen.has(stage.phase):
			seen.append(stage.phase)
		_expect(_board.state.rng.state==rng_at_stage,"Contract visuals never consume simulation RNG")
		_expect(int(_board.state.permanent_roll_bonus[1])==bonus_at_stage,"Visual stages never award another bonus")
		var pawn: PlayerPawn = _board.state.get_pawn(offering_id)
		_expect(not pawn.is_finished and not pawn.has_left_start,"The engine's offering remains reset throughout the ritual")
		var view: Node2D = _board._pawn_views[offering_id]
		if stage.phase==&"offering" and stage.elapsed>0.15:
			_expect(view.visible and view.modulate.a>0.8,"The completed pawn is readable before the sacrifice")
		if stage.phase==&"transfer":
			_expect(not view.visible,"Only after absorption does the offering disappear")
		# A UI refresh must not expose persistent flames ahead of the energy arrival.
		_board._refresh_super_marks()
		if stage.elapsed<stage.ARRIVAL:
			_expect(_board._flame_colors(1).is_empty(),"Permanent flames wait until the transfer arrives")
		else:
			_expect(stage.ignited and not _board._flame_colors(1).is_empty(),"Arrival ignites the actual contract holder")
		_expect(_board._flame_colors(2).is_empty(),"Another player's profile never gains contract flames")
		var capture_at: Dictionary = {&"offering":0.40,&"consume":0.95,&"transfer":1.67,&"ignite":2.20}
		if stage.elapsed>float(capture_at[stage.phase]):
			capture(str(stage.phase))
	elif stage_started and not checked_end:
		checked_end = true
		var pawn: PlayerPawn = _board.state.get_pawn(offering_id)
		var view: Node2D = _board._pawn_views[offering_id]
		_expect(not view.visible and view.position.distance_to(_board._pawn_position(pawn))<0.1,"Offering returns hidden to its actual start position")
		_expect(view.z_index==0 and is_zero_approx(view.rotation) and view.modulate.is_equal_approx(Color.WHITE),"No ritual draw order, tilt or tint remains")
	return false

func _check_cancel() -> void:
	_board = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	root.add_child(_board)
	var guard := 0
	while (not _board._draft_open or _board._intro_blocks()) and guard<2400:
		guard += 1
		await process_frame
	_stage(SuperAugments.DEVIL)
	var pawn: PlayerPawn = _board.state.get_pawn(offering_id)
	pawn.is_finished = false
	pawn.reset_to_start()
	_board.state.permanent_roll_bonus[1] = SuperAugments.devil_bonus()
	for interrupted_at: float in [0.90,2.20]:
		var stage := SuperFX.DEVIL_STAGE.new()
		_board.add_child(stage)
		stage.play(_board,1,offering_id,1.0)
		stage.elapsed = interrupted_at
		await process_frame
		await process_frame
		_board._reset_presentation()
		# A newer pending pick owns this key; the cancelled scene must not erase it.
		_board._super_hidden["1:SUPER_03"] = true
		await process_frame
		await process_frame
		await process_frame
		_expect(not is_instance_valid(stage),"Reset removes the ritual both before and after payoff")
		_expect(_board._super_hidden.has("1:SUPER_03"),"A cancelled ritual leaves a newer pending reveal intact")
		_board._super_hidden.erase("1:SUPER_03")
		var view: Node2D = _board._pawn_views[offering_id]
		_expect(not view.visible and view.position.is_equal_approx(_board._pawn_position(pawn)),"Reset restores the current authoritative pawn location")
		_expect(view.z_index==0 and view.modulate.is_equal_approx(Color.WHITE) and is_zero_approx(view.rotation),"Reset clears temporary ritual transforms")
	# A later pick may already have advanced the engine; reveal it on its own turn.
	var rest := _board._pawn_position(pawn)
	var queued_stage := SuperFX.DEVIL_STAGE.new()
	_board.add_child(queued_stage)
	queued_stage.play(_board,1,offering_id,1.0,{"rest_position":rest,"rest_visible":false})
	pawn.has_left_start = true
	pawn.current_tile_idx = 12
	queued_stage.elapsed = queued_stage.TOTAL_TIME
	await process_frame
	await process_frame
	queued_stage.queue_free()
	await process_frame
	var settled: Node2D = _board._pawn_views[offering_id]
	_expect(not settled.visible and settled.position.is_equal_approx(rest),"Completion preserves this pick's reset until subsequent queued effects")
	await _drop_board()

func capture(label: String) -> void:
	var folder := OS.get_environment("DEVIL_CAPTURE_DIR")
	if folder=="" or shots.has(label):
		return
	shots[label] = true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))
