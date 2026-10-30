## Only SUPER_02, through its actual engine and draft presentation queue.
extends "res://tests/ui_super_fx_test.gd"

var seen: Array[StringName] = []
var shots: Dictionary = {}
var rng_at_stage := 0
var stage_started := false
var checked_end := false
var expected_hands := {1:5,2:0,3:1,4:2}

func _run() -> void:
	GameSession.mode = GameSession.MODE_AI
	GameSession.pace_scale = 1.0
	await _check(SuperAugments.REDISTRIBUTE)
	_expect(seen==[&"gather",&"equalize",&"shuffle",&"return"],"Gather, equalize, shuffle and return play in order")
	_expect(checked_end,"Redistribution finishes and restores pawn presentation")
	if _failures.is_empty():
		print("UI_REDISTRIBUTION_OK")
		quit(0)
	else:
		for failure: String in _failures:
			printerr("UI_REDISTRIBUTION_FAIL: "+failure)
		quit(1)

func _stage(effect: StringName) -> void:
	super._stage(effect)
	_board.ai_mode = false
	_board._bot.set_enabled(false)
	_board.manager.set_process(false)
	for owner: int in expected_hands:
		(_board.state.hands[owner] as Array).clear()
		for index: int in int(expected_hands[owner]):
			(_board.state.hands[owner] as Array).append(&"ACT_02")
	_board._refresh_hands()

func _process(_delta: float) -> bool:
	if _board==null or not is_instance_valid(_board):
		return false
	var stage: Node2D = _board.get_node_or_null("RedistributionStage")
	if stage!=null:
		if not stage_started:
			stage_started = true
			rng_at_stage = _board.state.rng.state
			_expect(stage.hand_counts==expected_hands,"Collection uses the actual pre-effect hand counts")
			_expect(stage.reference_player in _board.state.player_ids,"Laggard reference is captured with the effect")
			for card: Dictionary in stage.cards:
				_expect(int(card.owner)!=2,"An empty hand does not produce collection cards")
			_expect(stage.cards.filter(func(card: Dictionary) -> bool: return int(card.owner)>0).size()==8,"Every old hand card is collected, including hands larger than three")
		if not seen.has(stage.phase):
			seen.append(stage.phase)
		_expect(not _board._draw_fx.busy(),"The existing new-card delivery waits for the returned shuffled deck")
		_expect(_board.state.rng.state==rng_at_stage,"Presentation never consumes authoritative RNG")
		if stage.phase==&"gather":
			for info: Dictionary in stage.pawns:
				var view: Node2D = (info.view as WeakRef).get_ref()
				_expect(view.position.is_equal_approx(info.from),"Pieces wait while old hands are collected")
		var capture_at: Dictionary = {&"gather":0.30,&"equalize":0.88,&"shuffle":1.46,&"return":2.02}
		if stage.elapsed>float(capture_at[stage.phase]):
			capture(str(stage.phase))
	elif stage_started and not checked_end:
		checked_end = true
		for pawn: PlayerPawn in _board.state.pawns:
			var view: Node2D = _board._pawn_views[pawn.entity_id]
			_expect(view.position.distance_to(_board._pawn_position(pawn))<0.1,"Piece lands on the authoritative redistributed position")
			_expect(view.z_index==0 and view.scale.is_equal_approx(Vector2.ONE),"Temporary flight pose is cleared")
		for owner: int in _board.state.active_players(_board.state.player_ids):
			_expect((_board.state.hands[owner] as Array).size()==SuperAugments.redistribute_cards(),"The original engine deals exactly the configured count")
		capture("ready_to_deal")
	if checked_end and not _board._draw_fx._current.is_empty():
		var current: Dictionary = _board._draw_fx._current
		if bool(current.get("local",false)) and bool(current.get("face",false)) and float(current.get("time",0.0))>0.75:
			capture("redeal")
	return false

func capture(label: String) -> void:
	var folder := OS.get_environment("REDISTRIBUTION_CAPTURE_DIR")
	if folder=="" or shots.has(label):
		return
	shots[label] = true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))
