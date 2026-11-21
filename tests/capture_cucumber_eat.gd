## Real hand-card drag into the board, three bites, then input restored.
extends "res://tests/capture_darts_integration.gd"

func _run() -> void:
	MatchTelemetry.test_sender = func(_url: String, _body: PackedByteArray, _type: String) -> void: pass
	_board._on_draft_auto_pressed()
	await settle(15)
	quiet()
	_board.instant_roll_for_test = true
	var owner: int = _board._dock_owner()
	_board.manager.current_turn_index = _board.manager.player_order.find(owner)
	_board.manager.change_state(TurnManager.State.PHASE_TURN_BEGIN)
	quiet()
	_board.state.hands[owner] = [&"JNK_CUKE"]
	_board._fx_busy = false
	_board._refresh_all()
	_board._roll_button.hide()
	var tip := _board.get_node_or_null("FirstMatchTip") as CanvasLayer
	if tip != null: tip.hide()
	_board._skill_hint.hide()
	await settle(16)
	_expect(_board._card_usable_now(owner, CardRegistry.get_card(&"JNK_CUKE")), "cucumber hand card is usable")
	_board._open_zoom(owner, &"JNK_CUKE")
	await settle(8)
	await snap("01-card-description")
	_board._close_zoom()
	await settle(4)
	var before: Dictionary = TurnSnapshot.capture(_board.state).data
	var rng_before: int = _board.state.rng.state
	var events: Array = []
	_board.manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void:
		if kind == &"card_played": events.append(data))
	_board.instant_roll_for_test = false
	recording = true
	await settle(12)
	var hand_card: Control = _board._dock.get_child(0)
	await drag(hand_card, _board._board_center() + Vector2(110, -50))
	var frames: int = 0
	while frames < 45 and _board.get_node_or_null("CucumberEat") == null:
		await process_frame
		frames += 1
	var stage: Control = _board.get_node_or_null("CucumberEat")
	_expect(stage != null, "actual hand drag starts eating")
	if stage == null:
		for failure: String in _failures: printerr("CUCUMBER_EAT_FAIL ", failure)
		quit(1)
		return
	var captured: Dictionary = {}
	while frames < 150 and (stage.busy() or _board._presentation_active()):
		await process_frame
		frames += 1
		if stage.busy() and not captured.has(stage.bite_count):
			captured[stage.bite_count] = true
			if stage.bite_count < 3:
				await snap("02-bite-%d" % stage.bite_count)
		_expect(not _board._announcer.active, "no generic card activation banner")
	_expect(captured.has(1) and captured.has(2) and captured.has(3), "all three bites play")
	await settle(15)
	recording = false
	_expect(events.size() == 1 and events[0].card_id == &"JNK_CUKE", "one real card use event")
	_expect((_board.state.hands[owner] as Array).is_empty(), "card is consumed")
	_expect(TurnSnapshot.capture(_board.state).data == before and _board.state.rng.state == rng_before, "eating changed no gameplay state or RNG")
	_expect(not stage.busy() and not stage.visible and not _board._ui_busy(), "animation finishes and input unlocks")
	_expect(not is_instance_valid(_board._drag_ghost), "no lingering thrown card")
	await snap("03-eaten-input-restored")
	# Reusing the same stage for another seat must not retain bites or a sprite.
	var other: int = 2 if owner == 1 else 1
	_board._play_cucumber_eat(other)
	await settle(8)
	_expect(stage.busy() and stage.bite_count == 0, "remote seat reuses stage with a whole cucumber")
	_board._reset_presentation()
	await settle(2)
	_expect(not stage.busy() and not stage.visible, "reset cancels the eating effect")
	for failure: String in _failures: printerr("CUCUMBER_EAT_FAIL ", failure)
	print("CUCUMBER_EAT_NATIVE ", _failures.size(), " failures; ", recorded_frames, " frames")
	MatchTelemetry.test_sender = Callable()
	quit(0 if _failures.is_empty() else 1)

func drag(control: Control, destination: Vector2) -> void:
	var point: Vector2 = control.get_global_transform_with_canvas() * (control.size * Vector2(0.5, 0.3))
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await settle(4)
	point = control.get_global_transform_with_canvas() * (control.size * Vector2(0.5, 0.3))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = point
	root.push_input(press, true)
	await process_frame
	for step: int in range(1, 11):
		motion = InputEventMouseMotion.new()
		motion.position = point.lerp(destination, step / 10.0)
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion, true)
		await process_frame
	press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = destination
	root.push_input(press, true)
