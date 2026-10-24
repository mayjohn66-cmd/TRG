## SUPER_06 only: ignition, authoritative dice result, overheat and cleanup.
extends "res://tests/ui_super_fx_test.gd"

var shots: Dictionary = {}
var phases: Array[StringName] = []
var activation_rng := 0
var activation_seen := false

func _run() -> void:
	GameSession.mode = GameSession.MODE_AI
	GameSession.pace_scale = 1.0
	await _check(SuperAugments.GAMBLER)
	_expect(phases.has(&"charge") and phases.has(&"transfer") and phases.has(&"ignite"),"Soul charges, travels and ignites")
	await _new_board()
	await _roll_case(4,0,false,"boost",false)
	await _roll_case(3,3,false,"bonus",false)
	await _roll_case(1,0,false,"overheat",false)
	await _roll_case(1,0,false,"cancel",true)
	await _roll_case(4,0,true,"expired",false)
	await _drop_board()
	if _failures.is_empty():
		print("UI_GAMBLER_OK")
		quit(0)
	else:
		for failure: String in _failures:
			printerr("UI_GAMBLER_FAIL: "+failure)
		quit(1)

func _stage(effect: StringName) -> void:
	super._stage(effect)
	_board._bot.set_enabled(false)
	_board.manager.set_process(false)

func _process(_delta: float) -> bool:
	if _board==null or not is_instance_valid(_board):
		return false
	var stage: Node2D = _board.get_node_or_null("GamblerStage")
	if stage!=null:
		if not activation_seen:
			activation_seen = true
			activation_rng = _board.state.rng.state
			_expect(not stage._art.is_empty(),"Golden soul illustration is loaded")
		if not phases.has(stage.phase):
			phases.append(stage.phase)
		_expect(_board.state.rng.state==activation_rng,"Ignition consumes no simulation RNG")
		_expect(_board._flame_colors(1).is_empty()==not stage.ignited,"Profile flame starts at the actual soul arrival")
		_expect(_board._flame_colors(2).is_empty(),"Another player's tool does not ignite")
		if stage.elapsed>0.25:
			capture("activation_"+String(stage.phase))
	return false

func _new_board() -> void:
	_board = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	root.add_child(_board)
	var guard := 0
	while (not _board._draft_open or _board._intro_blocks()) and guard<2400:
		guard += 1
		await process_frame
	_stage(SuperAugments.GAMBLER)
	_board._reset_presentation()
	_board._draft_open = false
	_board._draft_deferred.clear()
	_board._announcer.cancel()
	_board.manager.draft_enabled = false

func _roll_case(face: int, bonus: int, expired: bool, label: String, cancel: bool) -> void:
	_board._reset_presentation()
	_board._announcer.cancel()
	_board._presenter.cancel()
	var manager: TurnManager = _board.manager
	var player := manager.current_player_id()
	manager.current_state = TurnManager.State.PHASE_ROLL_WAIT
	manager.move_queue.clear()
	_board.state.gambler_round[player] = _board.state.round_number-(1 if expired else 0)
	_board.state.permanent_roll_bonus[player] = bonus
	var result := RollResult.make(&"D6",face)
	result.details = {"face":face}
	var tool := ScriptedTool.new([result])
	tool.tool_id = &"D6"
	_board.state.tools[player] = tool
	_board._refresh_all()
	manager.act(&"roll",{"player_id":player})
	var rng_after := _board.state.rng.state
	var expected := (face+bonus)*(1 if expired else 2)
	if face==1 and not expired:
		_expect(manager.move_queue.is_empty() and manager.current_player_id()!=player,"Overheat ends the turn without movement")
	else:
		_expect(manager.move_queue==[expected],"Real engine movement matches boosted value")
	var elapsed := 0.0
	var saw_result := false
	var saw_toss := false
	while elapsed<6.0:
		await process_frame
		elapsed += 1.0/60.0
		var stage: Node2D = _board.get_node_or_null("GamblerResult")
		if _board._presenter.active:
			saw_toss = true
			_expect(stage==null,"Result is not revealed before the real roll settles")
		if stage!=null:
			saw_result = true
			_expect(not expired,"Expired buff has no result effect")
			_expect(_board._presenter.visible and _board._presenter._augment_hold>0.0,"Real settled die stays visible during result")
			_expect(_board._presentation_step_busy(),"Next presentation waits for result")
			_expect(_board.state.rng.state==rng_after,"Result consumes no simulation RNG")
			if face>1:
				_expect(int(stage.values.to)==expected and int(stage.values.from)==face+bonus,"Formula uses actual engine bonuses")
			if stage.elapsed>0.46:
				capture(label)
				if face==1:
					_expect(_board._presenter.modulate.r<0.5,"Overheated die visibly chars")
				if cancel:
					_board._reset_presentation()
					break
		if elapsed>1.0 and not _board._fx_busy and stage==null:
			break
	_expect(saw_toss,"Uses the real D6 throw")
	_expect(saw_result==not expired,"Only current-round gambler rolls show a result")
	_expect(_board._presenter.modulate.r>0.99 and _board._presenter._augment_hold==0.0,"Tint and hold restore on finish or cancellation")
	await process_frame
	_expect(not _board._gambler_result_busy(),"No lingering result gate")
	await create_timer(1.8).timeout  # Let this roll's final movement summary finish.

func capture(label: String) -> void:
	var folder := OS.get_environment("GAMBLER_CAPTURE_DIR")
	if folder.is_empty() or shots.has(label):
		return
	shots[label] = true
	_save.call_deferred(folder,label)

func _save(folder: String, label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))
