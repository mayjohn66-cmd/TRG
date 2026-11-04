## Real failure action: retain old owner's tool name while the next turn is resolved.
extends "res://tests/capture_darts_integration.gd"
func _run() -> void:
	MatchTelemetry.test_sender = func(_url: String, _body: PackedByteArray, _type: String) -> void: pass
	_board._on_draft_auto_pressed()
	await settle(15)
	quiet()
	var manager: TurnManager = _board.manager
	var state: GameState = _board.state
	var owner: int = _board._dock_owner()
	manager.current_turn_index = manager.player_order.find(owner)
	manager.change_state(TurnManager.State.PHASE_TURN_BEGIN)
	quiet()
	_board.instant_roll_for_test = false
	state.tools[owner] = ToolRegistry.create(&"DICE_HWATU")
	state.hands[owner] = [&"ACT_17"]
	var tip := _board.get_node_or_null("FirstMatchTip") as CanvasLayer
	if tip != null: tip.hide()
	recording = true
	manager.act(&"play_card",{"player_id":owner,"card_id":&"ACT_17"})
	_board._refresh_all()
	await settle(65)
	var panel: Control = _board._hammer_panel
	var label: Label = panel.find_child("HammerLevel",true,false)
	_expect(label.text == "화투 패 +1","title uses current player's actual tool")
	await snap("01-hwatu-plus-one")
	# Verify alternate real tool names use the same route without changing rules.
	for id: StringName in [&"D6",&"DICE_TAROT",&"DICE_DARTS"]:
		state.tools[owner] = ToolRegistry.create(id)
		_board._refresh_hammer_panel()
		_expect(label.text == state.tools[owner].display_name+" +1","actual tool title: "+String(id))
	state.tools[owner] = ToolRegistry.create(&"DICE_HWATU")
	_board._refresh_all()
	var probe := RandomNumberGenerator.new()
	for value: int in range(1,100):
		probe.seed = value
		if probe.randi_range(0,99) >= TurnManager.hammer_chance(1):
			state.rng.seed = value
			break
	await click(panel.find_child("HammerUp",true,false))
	var stage: Control = _board.get_node_or_null("HammerBreakStage")
	for i: int in 60:
		if stage != null: break
		await process_frame
		stage = _board.get_node_or_null("HammerBreakStage")
	_expect(stage != null,"real failed upgrade starts physical break stage")
	if stage == null:
		printerr("HAMMER_BREAK_FAIL missing stage")
		quit(1)
		return
	var forge: HammerForgeView = stage.find_child("BreakingForge",true,false)
	_expect((stage.find_child("BrokenToolTitle",true,false) as Label).text == "화투 패 +1","failed player's name is retained after turn advances")
	_expect(manager.current_player_id()!=owner and not manager.hammer_pending(owner) and not state.hammer_bonus.has(owner),"failure still ends turn and removes pending bonus")
	var snapshot := TurnSnapshot.capture(state).data
	var rng_after: int = state.rng.state
	while is_instance_valid(stage) and forge._time < 0.34: await process_frame
	await snap("02-die-cracking")
	while is_instance_valid(stage) and forge._time < 0.61: await process_frame
	_expect(forge.shattered,"intact die replaced with textured fragments")
	await snap("03-die-shattered")
	_expect(TurnSnapshot.capture(state).data==snapshot and state.rng.state==rng_after,"fracture changes no gameplay state or RNG")
	for i: int in 100:
		await process_frame
		if _board.get_node_or_null("HammerBreakStage")==null and not _board._presentation_active() and not _board._announcer.holding(): break
	_expect(_board.get_node_or_null("HammerBreakStage")==null,"failure overlay cleans up")
	recording = false
	_board._announcer.cancel()
	_board.enqueue_step(_board._play_hammer_break.bind("화투 패",2))
	await settle(3)
	_board._reset_presentation()
	await settle(3)
	_expect(_board.get_node_or_null("HammerBreakStage")==null and not _board._presentation_active(),"reset cancels fracture and unlocks presentation")
	var board: MainBoard = _board
	_board = null
	board.queue_free()
	await settle(6)
	for failure: String in _failures: printerr("HAMMER_BREAK_FAIL ",failure)
	print("HAMMER_BREAK_NATIVE ",_failures.size()," failures; frames=",recorded_frames)
	MatchTelemetry.test_sender = Callable()
	quit(0 if _failures.is_empty() else 1)
