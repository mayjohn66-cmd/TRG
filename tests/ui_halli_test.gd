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
	var directory := OS.get_environment("HALLI_CAPTURE_DIR")
	if directory.is_empty():
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(name + ".png"))

func wait_play(arena: DuelArena) -> void:
	while arena._step != &"play":
		if arena._step == &"rules" and arena._intro_elapsed > 0.15:
			arena._confirm_intro()
		await process_frame

func fixture(seats: Array[int]) -> DuelArena:
	var arena := DuelArena.new()
	arena.setup(board, 1, 2, seats, DuelRules.Game.HALLI, {"cards": [1, 1, 2, 3], "interval": 0.55})
	board.add_child(arena)
	arena.open()
	arena._begin_game()
	arena._game_label.text = DuelRules.game_name(arena.game)
	arena.animating = false
	return arena

func resolved(arena: DuelArena, picks: Dictionary) -> Dictionary:
	var data := DuelRules.resolve(arena.game, arena.setup_data, arena.challenger, arena.defender, picks)
	data["picks"] = picks
	return data

func run() -> void:
	create_timer(65).timeout.connect(func() -> void: printerr("HALLI_UI_FAIL timeout"); quit(1))
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
	manager.duel_game_override = DuelRules.Game.HALLI
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
	check(arena != null and manager.duel_pending(), "Actual ACT_09 starts Halli Galli")
	if arena == null:
		quit(1)
		return
	arena.open()
	await wait_play(arena)
	var stage := arena._halli_stage
	check(stage.visible and stage.active and not arena._drawing.visible and not arena._message.visible, "Illustrated cards and bell replace the placeholder without bottom rules")
	check(arena._buttons.get_child_count() == 2 and stage.bell_button.disabled, "Hotseat has two distinct press controls")
	for child: Button in arena._buttons.get_children():
		check(child.action_mode == BaseButton.ACTION_MODE_BUTTON_PRESS, "Reaction records mouse-down, not release")
	await capture("first_card")
	var mark := DuelRules.reaction_mark(arena.game, arena.setup_data)
	while arena._clock < mark + 0.10:
		await process_frame
	check(stage.visible_counts().x + stage.visible_counts().y == 5, "The decisive card is visible by its authoritative mark")
	await capture("five")
	arena._press(challenger)
	var first := int(arena._submitted[challenger])
	arena._press(challenger)
	check(arena._submitted.size() == 1 and stage.strikes.size() == 1 and stage.ring_age == 0.0, "First press rings immediately and repeated input is ignored")
	await create_timer(0.14).timeout
	arena._press(defender)
	var rng_after := board.state.rng.state
	check(arena.animating and arena.holds_board() and stage.result["winner"] == challenger, "Actual engine outcome waits for the bell reveal")
	check(int((stage.result["picks"] as Dictionary)[challenger]) == first, "Presentation preserves the exact submitted milliseconds")
	await capture("ring_win")
	if not OS.get_environment("HALLI_CAPTURE_DIR").is_empty():
		root.size = Vector2i(844, 390)
		await frames(3)
		var visual := arena.get_global_transform().get_scale() * arena.size
		check(visual.y <= board.get_viewport_rect().size.y - 25, "Cards, bell and controls fit a short mobile viewport")
		await capture("win_mobile")
		root.size = Vector2i(1366, 768)
	while is_instance_valid(arena):
		await process_frame
	check(board._duel_arena == null and not manager.duel_pending(), "Actual duel releases the arena")
	check(not board.state.get_pawn(defender * 10 + 1).has_left_start, "The engine ejects the actual losing pawn")
	check(board.state.rng.state == rng_after, "Cosmetic motion does not consume game RNG")
	board._reset_presentation()
	board._announcer.cancel()
	# Boundary checks cover every pile overwrite, including 5-card games.
	arena = fixture([1])
	stage = arena._halli_stage
	var rng := RandomNumberGenerator.new()
	for seed_value: int in 200:
		rng.seed = seed_value
		var cards := DuelRules.halli_cards(rng)
		arena.setup_data["cards"] = cards
		var counts := Vector2i.ZERO
		for index: int in cards.size():
			var at := float(index) * DuelRules.HALLI_INTERVAL
			if index > 0:
				check(stage.visible_counts(at - 0.0001) == counts, "A folding card never leaks its next face")
			counts[index % 2] = cards[index]
			check(stage.visible_counts(at) == counts, "Faces change at exactly the engine card boundary")
	arena.setup_data["cards"] = [1, 1, 2, 3]
	await frames(2)
	check(not stage.bell_button.disabled, "The illustrated bell is directly clickable in single-seat games")
	stage.bell_button.button_down.emit()
	check(arena._submitted.has(1) and not arena._submitted.has(2), "The central bell submits only the local seat")
	var frozen_counts := stage.visible_counts()
	await create_timer(0.65).timeout
	check(stage.visible_counts() == frozen_counts, "Early input freezes the shown cards while awaiting the opponent")
	arena._press(2)
	check(not arena._submitted.has(2), "Remote seats cannot submit through a local control")
	arena._play_reveal(resolved(arena, {1: int(arena._submitted[1]), 2: 1800}))
	await frames(2)
	check(stage.result["decided_by"] == &"foul" and int(stage.result["winner"]) == 2 and stage.visible_counts() == frozen_counts, "Early foul keeps future cards hidden and shows the authoritative winner")
	await capture("foul")
	arena.close_now()
	await create_timer(0.30).timeout
	# A spectator may receive both bot values before any cards have been dealt.
	arena = fixture([])
	stage = arena._halli_stage
	arena._play_reveal(resolved(arena, {1: 1800, 2: 1940}))
	await create_timer(0.40).timeout
	check(stage.result.is_empty() and stage.strikes.is_empty() and arena.holds_board(), "Queued bot/network values do not spoil the reaction or ring early")
	while arena._step == &"play":
		await process_frame
	check(stage.result["winner"] == 1 and stage.ring_seat == 1 and stage.visible_counts() == Vector2i(2, 3), "A remote bell plays at its recorded time with the correct top cards")
	await capture("spectator")
	arena.close_now()
	await create_timer(0.30).timeout
	# Both missed inputs keep the existing engine default, without a phantom bell strike.
	arena = fixture([1, 2])
	stage = arena._halli_stage
	while arena._step == &"play":
		await process_frame
	check(arena._submitted == {1: -1, 2: -1}, "Timeout submits a miss for each local seat")
	await arena._play_reveal(resolved(arena, arena._submitted))
	check(stage.result["decided_by"] == &"nobody" and stage.strikes.is_empty(), "No-input adjudication never invents a bell press")
	await capture("timeout")
	arena.close_now()
	await create_timer(0.30).timeout
	# Interrupt a pending remote reveal before its timestamp.
	arena = fixture([])
	stage = arena._halli_stage
	arena._play_reveal(resolved(arena, {1: 1800, 2: 1940}))
	await frames(2)
	arena.close_now()
	check(not stage.active and stage.result.is_empty(), "Closing cancels the presentation before a deferred remote ring")
	await create_timer(0.30).timeout
	check(not is_instance_valid(arena), "Cancelled Halli stage is freed")
	board.instant_roll_for_test = true
	board.queue_free()
	await frames(4)
	if failures.is_empty():
		print("HALLI_UI_OK")
	else:
		for message: String in failures:
			printerr("HALLI_UI_FAIL " + message)
	quit(0 if failures.is_empty() else 1)
