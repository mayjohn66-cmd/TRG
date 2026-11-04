## Native integration capture: real MainBoard roll action, authoritative result,
## and shared 3D presenter. Telemetry is disabled for the fixture.
extends "res://tests/ui_fx_test.gd"
var capture_out := OS.get_environment("DARTS_CAPTURE_OUT")
var observed: Array[Dictionary] = []
var recording := false
var recorded_frames := 0

func _initialize() -> void:
	if OS.get_environment("DARTS_SAVE_FRAMES") == "1":
		DirAccess.make_dir_recursive_absolute(capture_out.path_join("frames"))
		RenderingServer.frame_post_draw.connect(_save_frame)

func _save_frame() -> void:
	if recording:
		root.get_texture().get_image().save_webp(capture_out.path_join("frames/frame-%04d.webp" % recorded_frames), true, 0.97)
		recorded_frames += 1

func settle(n: int) -> void:
	for i: int in n: await process_frame

func quiet() -> void:
	_board._announcer.cancel()
	_board._reset_presentation()
	_board._close_opening()
	_board._close_draft_overlay()
	_board._close_augment_review()
	_board._announced_round = _board.state.round_number
	_board._bot.set_enabled(false)
	_board.manager.set_process(false)
	_board.pacing_enabled = false

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_out.path_join(name + ".png"))

func click(control: Control) -> void:
	var point := control.get_global_transform_with_canvas() * (control.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = point
	root.push_input(press, true)
	await process_frame
	press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = point
	root.push_input(press, true)

func _run() -> void:
	MatchTelemetry.test_sender = func(_url: String, _body: PackedByteArray, _type: String) -> void: pass
	_board._on_draft_auto_pressed()
	await settle(15)
	quiet()
	var manager: TurnManager = _board.manager
	var state: GameState = _board.state
	manager.current_turn_index = manager.player_order.find(_board.local_player_id)
	manager.change_state(TurnManager.State.PHASE_TURN_BEGIN)
	quiet()
	var me := manager.current_player_id()
	state.tools[me] = ToolRegistry.create(&"DICE_DARTS")
	_board.instant_roll_for_test = false
	_board._fx_busy = false
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void:
		if kind == &"roll_resolved": observed.append(data["result"]))
	_board._refresh_all()
	recording = true
	await settle(18)
	await snap("01-aiming")
	await settle(42)
	await click(_board._roll_button)
	await settle(25)
	await snap("02-embedded-result")
	if observed.is_empty():
		printerr("DARTS_3D_FAIL no roll from native button")
	else:
		var result: Dictionary = observed[0]
		var details: Dictionary = result["details"]
		_expect(result["tool_id"] == &"DICE_DARTS", "real button resolves darts")
		_expect(_board._presenter._dart_view != null, "real roll uses 3D presenter")
		if _board._presenter._dart_view != null and _board._presenter._dart_view.has_method("hit_point"):
			var expected := Vector3(sin(float(details["angle"]) * TAU) * float(details["radius"]) * 2.0, cos(float(details["angle"]) * TAU) * float(details["radius"]) * 2.0, -0.14)
			_expect(_board._presenter._dart_view._dart.position.distance_to(expected) < 0.00001, "actual roll hit equals embedded mesh")
		print("DARTS_3D actual result ", JSON.stringify(result))
	await settle(44)
	await snap("03-input-restored")
	# A second legal turn exercises bull reset/reuse and the extra-roll caption.
	quiet()
	manager.current_turn_index = manager.player_order.find(me)
	manager.change_state(TurnManager.State.PHASE_TURN_BEGIN)
	quiet()
	_board._fx_busy = false
	_board._refresh_all()
	await settle(30)
	_board._dart_aim.set_process(false)
	_board._dart_aim._aim_radius = 0.0
	if _board._dart_aim.has_method("_present"): _board._dart_aim._present()
	await click(_board._roll_button)
	await settle(25)
	await snap("04-bull-result")
	_expect(observed.size() >= 2 and bool(observed[-1]["details"].get("bull", false)), "second throw bull from captured aim")
	await settle(30)
	_board._place_roll_history()
	await snap("05-target-stamp")
	_expect(_board._roll_history.visible and _board._roll_history._success.count == 1, "bull reveal prints one public target stamp")
	_expect(not _board._roll_history._rows.visible and not _board._roll_history._footer.visible, "bull history replaces plaques with a target stamp")
	await settle(18)
	quiet()
	_board._dart_aim.set_aiming(false)
	_board._dart_aim.hide()
	await snap("05-cleanup")
	recording = false
	print("DARTS_3D recorded frames ", recorded_frames)
	for failure: String in _failures: printerr("DARTS_3D_FAIL ", failure)
	print("DARTS_3D native capture ", _failures.size(), " failures")
	MatchTelemetry.test_sender = Callable()
	# Let SceneTree tear down the live match, just as closing the game does.
	await settle(4)
	print("DARTS_3D quitting")
	quit(0 if _failures.is_empty() and not observed.is_empty() else 1)
