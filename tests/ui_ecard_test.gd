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
	if not ok:
		failures.append(message)

func frames(count: int) -> void:
	for index: int in count:
		await process_frame

func capture(name: String) -> void:
	var directory := OS.get_environment("ECARD_CAPTURE_DIR")
	if directory.is_empty():
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(name + ".png"))
	print("ECARD_FRAME ", name, " ", Engine.get_process_frames())

func wait_pick(arena: DuelArena, seat: int) -> void:
	while arena._step != &"play" or arena._pick_seat != seat:
		if arena._step == &"rules" and arena._intro_elapsed > 0.15: arena._confirm_intro()
		await process_frame

func click_choice(arena: DuelArena, citizen: bool) -> void:
	var button: Button
	for node: Button in arena._buttons.get_children():
		if node.name == ("CitizenChoice" if citizen else "SpecialChoice"): button = node
	check(button != null, "Only a remaining card has a selection button")
	if button == null: return
	var point := button.get_global_transform_with_canvas() * (button.size / 2.0)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	if not mouse_notified:
		mouse_notified = true
		root.notify_mouse_entered()
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
	arena.setup(board, 1, 2, [], DuelRules.Game.ECARD, {"hands": [[1, 4], [1, 4]]})
	board.add_child(arena)
	arena.open()
	arena._game_label.text = DuelRules.game_name(arena.game)
	arena._begin_game()
	return arena

func draw_data(round_index: int) -> Dictionary:
	return {"picks": {1: 1, 2: 1}, "winner": -1, "decided_by": &"draw", "draws": round_index,
		"ecard_hands": [[1, 4-round_index], [1, 4-round_index]]}

func run() -> void:
	create_timer(65).timeout.connect(func() -> void: printerr("ECARD_UI_FAIL timeout"); quit(1))
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
	manager.duel_game_override = DuelRules.Game.ECARD
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
	check(arena != null and manager.duel_pending(), "Actual ACT_09 starts E-card")
	if arena == null:
		quit(1)
		return
	arena.open()
	await wait_pick(arena, challenger)
	var stage := arena._ecard_stage
	check(stage.visible and not arena._drawing.visible and not arena._message.visible, "Simple symbol cards replace the text placeholder")
	check(stage.symbol(challenger, 0) == DuelEcardStage.QUEEN and stage.symbol(defender, 0) == DuelEcardStage.REBEL and stage.symbol(challenger, 1) == DuelEcardStage.CITIZEN, "Crown, farm tools and sword identify exactly the requested roles")
	await capture("initial_hand")
	for round_index: int in 4:
		await wait_pick(arena, challenger)
		check(DuelRules.ecard_count(arena.setup_data, true, 1) == 4-round_index, "Only the remaining citizens are selectable")
		await click_choice(arena, true)
		check(arena._submitted.get(challenger) == 1 and stage.revealed.is_empty() and stage.pending.is_empty(), "The first normal GUI selection stays face-down")
		check(DuelRules.ecard_count(arena.setup_data, true, 1) == 4-round_index, "A secret pick never reveals itself by changing the hand count")
		if round_index == 0: await capture("first_pick_hidden")
		await wait_pick(arena, defender)
		await click_choice(arena, true)
		check(arena.holds_board() and manager.duel_pending() and stage.revealed.is_empty(), "Both citizen inputs begin a simultaneous hidden flip without resolving the duel")
		while stage.revealed.is_empty(): await process_frame
		check(stage.revealed == {challenger: 1, defender: 1}, "Both citizens turn face-up together")
		if round_index == 0:
			while stage.elapsed < 0.75: await process_frame
			await capture("citizens_draw")
		while not stage.counts_applied: await process_frame
		check(DuelRules.ecard_count(arena.setup_data, true, 1) == 3-round_index and DuelRules.ecard_count(arena.setup_data, false, 1) == 3-round_index, "Each visible discard removes one actual citizen on both sides")
		if round_index == 0: await capture("discarded")
		await wait_pick(arena, challenger)
		check(stage.round_number == round_index + 2 and stage.revealed.is_empty(), "The next hand begins only after the discard finishes")
	check(arena._buttons.get_child_count() == 1 and arena._buttons.get_child(0).name == "SpecialChoice", "Exhausting citizens leaves exactly the special card")
	arena._choose(1)
	check(arena._submitted.is_empty(), "Trying to reuse a spent citizen cannot consume the turn")
	await capture("specials_only")
	if not OS.get_environment("ECARD_CAPTURE_DIR").is_empty():
		root.size = Vector2i(844, 390)
		await frames(3)
		var visual := arena.get_global_transform().get_scale() * arena.size
		check(visual.y <= board.get_viewport_rect().size.y - 25, "Remaining hand, played cards and controls fit mobile")
		await capture("mobile")
		root.size = Vector2i(1366, 768)
		await frames(3)
	await click_choice(arena, false)
	await wait_pick(arena, defender)
	await click_choice(arena, false)
	var rng_after := board.state.rng.state
	while stage.revealed.is_empty(): await process_frame
	check(stage.result["winner"] == defender and stage.result["decided_by"] == &"upset", "The last rebel defeats the last queen after four draws")
	check(arena.holds_board(), "The real pawn ejection waits for the deciding reveal")
	while stage.elapsed < 0.75: await process_frame
	await capture("rebellion_wins")
	while is_instance_valid(arena): await process_frame
	check(board._duel_arena == null and not manager.duel_pending(), "The actual ACT_09 duel closes after the deciding pair")
	check(not board.state.get_pawn(challenger*10+1).has_left_start, "The actual losing queen-side pawn is ejected")
	check(board.state.rng.state == rng_after, "Card flips and discarded-card animation never consume game RNG")
	board._reset_presentation()
	board._announcer.cancel()
	# Remote spectators can receive a backlog; each reveal and discard still plays in order.
	arena = fixture()
	stage = arena._ecard_stage
	arena.push_event(&"duel_revealed", draw_data(1))
	arena.push_event(&"duel_revealed", draw_data(2))
	await frames(3)
	check(stage.revealed.is_empty() and DuelRules.ecard_count(arena.setup_data, true, 1) == 4, "Queued future rounds do not reveal faces or deplete the visible hand early")
	while stage.round_number < 2: await process_frame
	check(DuelRules.ecard_count(arena.setup_data, true, 1) == 3 and stage.result["draws"] == 2, "The second queued round begins with exactly one pair discarded")
	arena.close_now()
	check(not stage.active, "Closing cancels and unblocks an active reveal")
	await create_timer(0.30).timeout
	check(not is_instance_valid(arena), "Cancelled card stages are freed")
	# Local timeout must also use an available card, even at the forced final round.
	arena = fixture()
	arena.local_seats = [1]
	arena.setup_data["hands"] = [[1, 0], [1, 0]]
	arena._step = &"play"
	arena._next_pick_seat()
	arena._on_local_timeout()
	check(arena._submitted == {1: 0}, "Local timeout cannot reuse the four discarded citizens")
	arena.close_now()
	await create_timer(0.30).timeout
	board.instant_roll_for_test = true
	board.queue_free()
	await frames(4)
	if failures.is_empty(): print("ECARD_UI_OK")
	else:
		for message: String in failures: printerr("ECARD_UI_FAIL " + message)
	quit(0 if failures.is_empty() else 1)
