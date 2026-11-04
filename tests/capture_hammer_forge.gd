## Real enhancement card + existing buttons, with illustrated props.
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
	_board._announcer.instant = true # Inspect forge itself without generic notice obscuring it.
	state.hands[owner] = [&"ACT_17"]
	var tip := _board.get_node_or_null("FirstMatchTip") as CanvasLayer
	if tip != null: tip.hide()
	recording = true
	manager.act(&"play_card", {"player_id": owner, "card_id": &"ACT_17"})
	_board._refresh_all()
	await settle(65)
	var panel: Control = _board._hammer_panel
	var forge: HammerForgeView = panel.find_child("HammerForge", true, false)
	var impacts: Array[int] = []
	forge.impact.connect(func(success: bool, value: int) -> void:
		if success: impacts.append(value))
	_expect(panel.visible and forge.level == 1, "actual card opens illustrated +1 forge")
	_expect(root.get_visible_rect().encloses(panel.get_global_rect()), "panel stays within viewport")
	_expect(forge.get_global_rect().end.y < (panel.find_child("HammerUp", true, false) as Control).get_global_rect().position.y, "art never covers action buttons")
	await snap("01-forge-ready")
	var before := TurnSnapshot.capture(state).data
	var rng_before: int = state.rng.state
	forge.show_level(1, true)
	await settle(24)
	_expect(TurnSnapshot.capture(state).data == before and state.rng.state == rng_before, "art animation changes no state or RNG")
	# Select a deterministic success in this fixture, then invoke the actual button.
	var probe := RandomNumberGenerator.new()
	for seed_value: int in range(1,100):
		probe.seed = seed_value
		if probe.randi_range(0,99) < TurnManager.hammer_chance(1):
			state.rng.seed = seed_value
			break
	await click(panel.find_child("HammerUp", true, false))
	await settle(8)
	await snap("02-forge-contact")
	var resolved := TurnSnapshot.capture(state).data
	var resolved_rng: int = state.rng.state
	await settle(5)
	await snap("02b-success-sparks-and-number")
	await settle(20)
	_expect(impacts == [2], "one success impact fires exactly once at contact")
	_expect(TurnSnapshot.capture(state).data == resolved and state.rng.state == resolved_rng, "success sparks and number change no state or RNG")
	_expect(not forge.is_processing() and forge.success_finished(), "success effects finish and return to idle")
	_expect(manager.hammer_level(owner) == 2 and forge.level == 2, "existing upgrade button advances rules and art together")
	await snap("03-forge-upgraded")
	await click(panel.find_child("HammerStop", true, false))
	await settle(6)
	_expect(not panel.visible and int(state.hammer_bonus.get(owner,0)) == 2 and not forge.is_processing(), "stop banks +2, hides forge and stops processing")
	recording = false
	state.hammer_bonus.erase(owner)
	state.hammer_pending[owner] = 4
	for seed_value: int in range(1,100):
		probe.seed = seed_value
		if probe.randi_range(0,99) < TurnManager.hammer_chance(4):
			state.rng.seed = seed_value
			break
	manager.act(&"hammer_up", {"player_id": owner})
	await settle(3)
	_expect(not manager.hammer_pending(owner) and int(state.hammer_bonus.get(owner,0)) == 5, "max upgrade still auto-banks +5")
	_expect(_board.get_node_or_null("HammerSuccessStage") != null, "terminal +5 plays the same success effect")
	await settle(12)
	await snap("04-max-success-effect")
	await settle(45)
	_expect(_board._announcer.history.has("강화 성공!"), "terminal +5 keeps success feedback after forge closes")
	_expect(_board.get_node_or_null("HammerSuccessStage") == null, "terminal success cleans up")
	_board._announcer.cancel()
	_board.enqueue_step(_board._play_hammer_success.bind("기본 주사위",3))
	await settle(4)
	_board._reset_presentation()
	await settle(3)
	_expect(_board.get_node_or_null("HammerSuccessStage") == null and not _board._presentation_active(), "reset cancels success effect without locking input")
	var board: MainBoard = _board
	_board = null
	board.queue_free()
	await settle(6)
	# Relevant pre-existing rules cover free +1, bank/apply once and both risky outcomes.
	BoardSpec.apply(24)
	var rules := TestV11Content.new()
	rules.tree = self
	rules.current_test = "test_enhancement_hammer_first_upgrade_is_free_then_risk"
	rules.test_enhancement_hammer_first_upgrade_is_free_then_risk()
	rules.cleanup()
	for failure: String in rules.failures: _failures.append(failure)
	for failure: String in _failures: printerr("HAMMER_FORGE_FAIL ", failure)
	print("HAMMER_FORGE_NATIVE ", _failures.size(), " failures; rules=", rules.assertions, "; frames=", recorded_frames)
	MatchTelemetry.test_sender = Callable()
	quit(0 if _failures.is_empty() else 1)

