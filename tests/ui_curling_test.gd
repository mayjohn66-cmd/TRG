extends SceneTree

var started := false
var board: MainBoard
var failures: Array[String] = []

func _process(_delta: float) -> bool:
	if not started:
		started = true
		run()
	return false

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func frames(count: int) -> void:
	for index: int in count:
		await process_frame

func capture(name: String) -> void:
	var directory := OS.get_environment("CURLING_CAPTURE_DIR")
	if directory.is_empty():
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(name + ".png"))

func mouse(stage: DuelCurlingStage, point: Vector2, pressed: bool) -> bool:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = pressed
	return stage.handle_input(event)

func drag(stage: DuelCurlingStage, point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	stage.handle_input(event)

func wait_pick(arena: DuelArena, seat: int) -> void:
	while arena._step != &"play" or arena._pick_seat != seat:
		if arena._step == &"rules" and arena._intro_elapsed > 0.15:
			arena._confirm_intro()
		await process_frame

func fixture() -> DuelArena:
	var arena := DuelArena.new()
	arena.setup(board, 1, 2, [], DuelRules.Game.CURLING, {"physics": true})
	board.add_child(arena)
	arena.open()
	arena._game_label.text = DuelRules.game_name(arena.game)
	arena._begin_game()
	return arena

func run() -> void:
	create_timer(70).timeout.connect(func() -> void: printerr("CURLING_UI_FAIL timeout"); quit(1))
	board = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	board.instant_roll_for_test = true
	root.add_child(board)
	await frames(4)
	board.ai_mode = false
	board._bot.set_enabled(false)
	board._on_draft_auto_pressed()
	board._announcer.cancel()
	board.pacing_enabled = false
	await frames(4)
	board._reset_presentation()
	board.manager.set_process(false)
	var manager := board.manager
	for index: int in 40:
		if manager.current_state == TurnManager.State.PHASE_TURN_BEGIN:
			break
		manager.force_timeout()
	manager.duel_game_override = DuelRules.Game.CURLING
	manager._card_played_this_turn = false
	board.state.clear_npcs()
	board.state.rulebook.active_laws_queue.clear()
	for tile: int in BoardSpec.tile_count:
		board.state.board.get_tile(tile).attachments.clear()
	for pawn: PlayerPawn in board.state.pawns:
		pawn.reset_to_start()
		pawn.kind = GameEnums.PawnKind.BASIC
		pawn.unit_no = 0
	var challenger := manager.current_player_id()
	var defender := 2 if challenger != 2 else 1
	for pair: Vector2i in [Vector2i(challenger * 10 + 1, 5), Vector2i(defender * 10 + 1, 14)]:
		var pawn := board.state.get_pawn(pair.x)
		pawn.has_left_start = true
		pawn.current_tile_idx = pair.y
	board._refresh_all()
	board._announcer.cancel()
	board._announced_round = board.state.round_number
	board.instant_roll_for_test = false
	board.state.give_card(challenger, &"ACT_09")
	board._duel_drop_target = defender
	board._on_card_pressed(challenger, &"ACT_09")
	var arena := board._duel_arena
	check(arena != null and manager.duel_pending(), "A real ACT_09 card starts the physical curling duel")
	if arena == null:
		quit(1)
		return
	arena.open()
	await wait_pick(arena, challenger)
	var stage := arena._curling_stage
	check(stage.visible and not arena._drawing.visible and not arena._message.visible, "Bottle cap tabletop replaces the numeric gauge and bottom instructions")
	check(DuelCurlingStage.ART.get_image().get_pixel(0, 0).a == 0.0, "The bottle cap sprite retains transparent alpha")
	var start := stage.to_screen(Vector2(BottleCapPhysics.START) / BottleCapPhysics.SCALE)
	var before_rng := board.state.rng.state
	check(not mouse(stage, start + Vector2(160, 120), true) and not stage.dragging, "Only pressing the cap begins a pull")
	check(not mouse(stage, start + Vector2(160, 120), false), "Non-gesture releases remain available to GUI buttons")
	mouse(stage, start, true)
	check(stage.dragging and stage.power == 0.0, "Pressing the cap immediately shows the forward arrow")
	mouse(stage, start + Vector2.ONE, false)
	check(arena._submitted.is_empty(), "A tiny pull does not consume a shot")
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = start
	touch.pressed = true
	stage.handle_input(touch)
	touch.canceled = true
	touch.pressed = false
	stage.handle_input(touch)
	check(not stage.dragging and arena._submitted.is_empty(), "Cancelled OS touch never shoots")
	for pair: Array in [[Vector2(0, -70), 90], [Vector2(70, 0), 180], [Vector2(0, 70), 270]]:
		mouse(stage, start, true)
		drag(stage, start + pair[0])
		check(stage.aim == pair[1] and stage.power > 0.0, "Pulling in any direction aims opposite to the pointer")
		stage.cancel_drag()
	if not OS.get_environment("CURLING_CAPTURE_DIR").is_empty():
		mouse(stage, start, true)
		drag(stage, stage.to_screen(Vector2(72 - 117, 126)))
		root.size = Vector2i(844, 390)
		await frames(3)
		check(not stage.dragging and arena._submitted.is_empty(), "Resizing cancels a held gesture")
		var mobile_start := stage.to_screen(Vector2(72, 126))
		mouse(stage, mobile_start, true)
		drag(stage, stage.to_screen(Vector2(-45, 126)))
		var visual := arena.get_global_transform().get_scale() * arena.size
		check(visual.y <= board.get_viewport_rect().size.y - 25, "Table and touch controls fit a short mobile viewport")
		await capture("aim_mobile")
		root.size = Vector2i(1366, 768)
		await frames(3)
		start = stage.to_screen(Vector2(72, 126))
	mouse(stage, start, true)
	drag(stage, stage.to_screen(Vector2(72 - 30, 126 - 5)))
	await capture("weak_pull")
	drag(stage, stage.to_screen(Vector2(72 - 117, 126)))
	check(stage.aim == 0 and stage.power > 0.85, "Pulling left aims forward and increases the impulse")
	check(board.state.rng.state == before_rng and stage.world.caps[0].pos == BottleCapPhysics.START, "Aiming changes neither physics nor game RNG")
	await capture("aim")
	mouse(stage, stage.to_screen(Vector2(72 - 117, 126)), false)
	var first := int(arena._submitted[challenger])
	mouse(stage, start, false)
	check(arena._submitted.size() == 1 and stage.mode == &"slide" and arena.animating and arena.holds_board(), "Release submits once and starts sliding immediately")
	check(manager.duel_pending() and board.state.get_pawn(challenger * 10 + 1).has_left_start, "The first shot never prematurely resolves the duel")
	await capture("slide")
	await wait_pick(arena, defender)
	var expected_first := BottleCapPhysics.new()
	expected_first.shoot(0, first)
	expected_first.settle()
	check(stage.world.caps == expected_first.caps, "The first visible stop exactly matches fixed-step authority")
	await capture("second_turn")
	# Touch input launches a stronger second cap down the same line.
	start = stage.to_screen(Vector2(72, 126))
	touch.canceled = false
	touch.pressed = true
	touch.position = start
	stage.handle_input(touch)
	var touch_drag := InputEventScreenDrag.new()
	touch_drag.index = 0
	touch_drag.position = stage.to_screen(Vector2(72 - 133, 126))
	stage.handle_input(touch_drag)
	touch.pressed = false
	touch.position = touch_drag.position
	stage.handle_input(touch)
	var second := int(arena._submitted[defender])
	check(arena._submitted.size() == 2 and stage.mode == &"slide", "The second player can flick using normal touch drag/release")
	var rng_after := board.state.rng.state
	var contact_shot := false
	var fall_shot := false
	while stage.mode != &"result":
		check(stage.result_winner == -1, "The winner stays hidden until the second cap settles")
		if stage.impacts > 0 and not contact_shot:
			contact_shot = true
			await capture("impact")
		if bool(stage.world.caps[0].out) and not fall_shot:
			fall_shot = true
			await capture("fall")
		await process_frame
	var expected := BottleCapPhysics.simulate(first, second)
	check(stage.world.caps == expected.caps, "Rendered collisions and falls exactly match the engine's integer simulation")
	check(contact_shot and fall_shot and stage.result_winner == defender, "The second cap physically pushes the first off the cliff and wins")
	check(board.state.rng.state == rng_after, "Spin, trails and impacts do not consume game RNG")
	await capture("result")
	while is_instance_valid(arena):
		await process_frame
	check(board._duel_arena == null and not manager.duel_pending(), "The completed arena and its input are released")
	check(not board.state.get_pawn(challenger * 10 + 1).has_left_start, "The actual losing board pawn is ejected")
	board._reset_presentation()
	board._announcer.cancel()
	# Exercise the normal Godot GUI route as well as direct drag gestures.
	arena = fixture()
	arena.local_seats = [1]
	arena._begin_curling_pick()
	await frames(4)
	var button := arena._buttons.get_child(0) as Button
	var click_point := button.get_global_transform_with_canvas() * (button.size / 2.0)
	var motion := InputEventMouseMotion.new()
	motion.position = click_point
	root.notify_mouse_entered()
	root.push_input(motion, true)
	for down: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = click_point
		click.global_position = click_point
		click.button_index = MOUSE_BUTTON_LEFT
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		click.pressed = down
		root.push_input(click, true)
		await process_frame
	check(arena._submitted.has(1), "The visible flick button works through the actual GUI mouse press/release route")
	arena.close_now()
	await create_timer(0.30).timeout
	# Variable render frame sizes only change sampling, never the physical outcome.
	for rate: int in [30, 60, 144]:
		arena = fixture()
		stage = arena._curling_stage
		stage.set_process(false)
		for pair: Vector2i in [Vector2i(0, first), Vector2i(1, second)]:
			stage.play_shot(pair.x, pair.y)
			for frame: int in rate * 6:
				stage.advance(1.0 / float(rate))
				if stage.mode == &"rest":
					break
		check(stage.world.caps == expected.caps, "30/60/144 FPS replays land at identical positions with identical spins")
		arena.close_now()
		await create_timer(0.30).timeout
	# A queued remote pair must still show both complete shots, in order.
	arena = fixture()
	stage = arena._curling_stage
	arena.push_event(&"duel_pick_in", {"player_id": 1, "value": first})
	arena.push_event(&"duel_pick_in", {"player_id": 2, "value": second})
	var data := DuelRules.resolve(DuelRules.Game.CURLING, {"physics": true}, 1, 2, {1: first, 2: second})
	data["picks"] = {1: first, 2: second}
	arena.push_event(&"duel_revealed", data)
	await frames(3)
	check(stage.shooter == 0 and stage.result_winner == -1 and arena.holds_board(), "Early network results cannot skip the first flight")
	arena.close_now()
	check(stage.mode == &"idle" and not stage.dragging, "Closing cancels a flight and unblocks awaited settlement")
	await create_timer(0.30).timeout
	check(not is_instance_valid(arena), "Cancelled physical stages are freed")
	board.instant_roll_for_test = true
	board.queue_free()
	await frames(4)
	if failures.is_empty():
		print("CURLING_UI_OK")
	else:
		for message: String in failures:
			printerr("CURLING_UI_FAIL " + message)
	quit(0 if failures.is_empty() else 1)
