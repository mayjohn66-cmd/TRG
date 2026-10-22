extends SceneTree

var started := false
var board: MainBoard
var failures: Array[String] = []
var mouse_notified := false

func _process(_delta: float) -> bool:
	if not started:
		started = true
		run()
	return false

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func frames(count: int) -> void:
	for index: int in count: await process_frame

func capture(name: String) -> void:
	var directory := OS.get_environment("PUMPKIN_CAPTURE_DIR")
	if directory.is_empty(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(name + ".png"))
	print("PUMPKIN_FRAME ", name, " ", Engine.get_process_frames())

func wait_turn(arena: DuelArena, seat: int) -> void:
	while arena._step != &"play" or arena._turn != seat:
		if arena._step == &"rules" and arena._intro_elapsed > 0.15: arena._confirm_intro()
		await process_frame

func click_button(arena: DuelArena, index: int) -> void:
	var button := arena._hole_buttons[index]
	var point := button.get_global_transform_with_canvas() * (button.size / 2.0)
	if not mouse_notified:
		mouse_notified = true
		root.notify_mouse_entered()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for down: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = point
		click.global_position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		click.pressed = down
		root.push_input(click, true)
		await process_frame

func fixture() -> DuelArena:
	var arena := DuelArena.new()
	arena.setup(board, 1, 2, [], DuelRules.Game.BARREL, {"bomb": 2, "holes": 5})
	board.add_child(arena)
	arena.open()
	arena._begin_game()
	return arena

func run() -> void:
	create_timer(65).timeout.connect(func() -> void: printerr("PUMPKIN_UI_FAIL timeout"); quit(1))
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
	manager.duel_game_override = DuelRules.Game.BARREL
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
	check(arena != null and manager.duel_pending(), "Actual ACT_09 starts pumpkin roulette")
	if arena == null:
		quit(1)
		return
	arena.open()
	await wait_turn(arena, challenger)
	var stage := arena._pumpkin_stage
	check(stage.visible and not arena._drawing.visible and stage.buttons.size() == 5, "Five connected switches replace the old cask")
	check(stage.used.is_empty() and not stage.popped, "No button reveals the hidden losing index")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/trickcal/duel/pumpkin/petit-speaki-angry.source.json"))
	check(source["animation"] == "Angry1_1" and source["viewer_id"] == "Pet_MiniSpeaki" and source["frame_count"] == DuelPumpkinStage.ANGRY_FRAMES, "The requested native pet animation has all 73 frames")
	check(is_equal_approx(float(source["duration_seconds"]), DuelPumpkinStage.ANGRY_DURATION), "Playback retains the native full animation duration")
	var bomb := int(manager.pending_duel()["setup"]["bomb"])
	var safe: Array[int] = []
	for index: int in 5:
		if index != bomb: safe.append(index)
	await capture("ready")
	for index: int in 4:
		var seat := challenger if index % 2 == 0 else defender
		await wait_turn(arena, seat)
		if index % 2 == 0:
			await click_button(arena, safe[index])
		else:
			var key := InputEventKey.new()
			key.keycode = KEY_1 + safe[index]
			key.pressed = true
			root.push_input(key, true)
			await process_frame
		check(stage.active and arena._step == &"waiting" and arena.holds_board(), "GUI and keyboard inputs immediately lock during wire travel")
		arena._pick_hole(safe[(index+1)%4])
		check(arena._opened_holes.size() == index + 1, "Rapid duplicate input cannot consume the next player's turn")
		if index == 0:
			while stage.elapsed < 0.2: await process_frame
			await capture("wire_pulse")
		while stage.active: await process_frame
		check(not stage.popped and stage.buttons[safe[index]].disabled, "Safe buttons stay depressed and cannot be reused")
		check(board.state.get_pawn(challenger*10+1).has_left_start and board.state.get_pawn(defender*10+1).has_left_start, "Safe presses eject neither pawn")
		if index == 0: await capture("safe")
	await wait_turn(arena, challenger)
	check(stage.used.size() == 4 and not stage.buttons[bomb].disabled, "After four safe presses only the losing button remains")
	if not OS.get_environment("PUMPKIN_CAPTURE_DIR").is_empty():
		root.size = Vector2i(844,390)
		await frames(3)
		var visual := arena.get_global_transform().get_scale() * arena.size
		check(visual.y <= board.get_viewport_rect().size.y-25, "All five switch hit targets fit a short mobile viewport")
		await capture("mobile")
		root.size = Vector2i(1366,768)
		await frames(3)
	var loser_view: Node2D = board._pawn_views[challenger*10+1]
	var loser_position := loser_view.position
	await click_button(arena,bomb)
	var rng_after := board.state.rng.state
	while stage.elapsed < 0.60: await process_frame
	check(not stage.popped and stage.result_text.is_empty(), "Inflation precedes the explosion and defeat announcement")
	await capture("inflating")
	while stage.elapsed < DuelPumpkinStage.POP_AT + 0.10: await process_frame
	check(stage.popped and stage.active and arena.holds_board(), "Pumpkin bursts and native Angry1_1 begins before board effects")
	await capture("burst")
	while stage.elapsed < DuelPumpkinStage.POP_AT + 1.10: await process_frame
	check(loser_view.position.distance_to(loser_position) < 0.1 and board._fx_holding(), "Losing pawn stays visually in place throughout the angry animation")
	await capture("angry")
	while stage.active: await process_frame
	while stage.result_text.is_empty(): await process_frame
	await capture("defeat")
	while is_instance_valid(arena): await process_frame
	check(not board.state.get_pawn(challenger*10+1).has_left_start, "The actual pressing player loses and their pawn is ejected")
	check(board.state.rng.state == rng_after, "Wire pulses, fragments and native animation consume no game RNG")
	check(board._duel_arena == null and not manager.duel_pending(), "The real ACT_09 closes cleanly after the result")
	board._reset_presentation()
	board._announcer.cancel()
	# Spectators may receive several presses at once: public reactions stay ordered.
	arena = fixture()
	stage = arena._pumpkin_stage
	arena.push_event(&"duel_pick_in", {"player_id":1,"hole":0,"bomb":false})
	arena.push_event(&"duel_pick_in", {"player_id":2,"hole":2,"bomb":true})
	arena.push_event(&"duel_revealed", {"winner":1})
	await frames(3)
	check(stage.used == [0] and not stage.popped, "A queued losing press does not interrupt the earlier safe pulse")
	while stage.selected != 2: await process_frame
	check(not stage.popped and stage.elapsed < 0.1, "Queued explosion starts at its own first frame")
	arena.close_now()
	check(not stage.active, "Closing unblocks a pending native animation")
	await create_timer(0.30).timeout
	check(not is_instance_valid(arena), "Cancelling frees switches and animation nodes")
	board.instant_roll_for_test = true
	board.queue_free()
	await frames(4)
	if failures.is_empty(): print("PUMPKIN_UI_OK")
	else:
		for message: String in failures: printerr("PUMPKIN_UI_FAIL " + message)
	quit(0 if failures.is_empty() else 1)
