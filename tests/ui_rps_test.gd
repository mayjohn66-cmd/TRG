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
	var directory := OS.get_environment("RPS_CAPTURE_DIR")
	if directory.is_empty():
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(name + ".png"))

func wait_for_play(arena: DuelArena) -> void:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 10000:
		if arena._step == &"rules" and arena._intro_elapsed > 0.15:
			arena._confirm_intro()
		if arena._step == &"play" and arena._pick_seat != -1:
			return
		await process_frame
	check(false, "The game opens after selection and its large instruction screen")

func run() -> void:
	create_timer(60).timeout.connect(func() -> void: printerr("RPS_UI_FAIL timeout"); quit(1))
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
	manager.duel_game_override = DuelRules.Game.RPS
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
	check(arena != null and manager.duel_pending(), "A real ACT_09 card starts the RPS duel")
	if arena == null:
		quit(1)
		return
	arena.open()
	await wait_for_play(arena)
	var stage := arena._rps_stage
	check(stage.visible and not arena._drawing.visible and not arena._message.visible, "Illustrated hands replace the placeholder and bottom instructions")
	check(arena._buttons.get_child_count() == 3, "Exactly three illustrated choices")
	for hand: int in 3:
		check(stage.art[hand] != null and stage.art[hand].get_image().get_pixel(0, 0).a == 0.0, "Each hand is a real transparent sprite")
	await capture("choose")
	if not OS.get_environment("RPS_CAPTURE_DIR").is_empty():
		root.size = Vector2i(844, 390)
		await frames(3)
		await capture("choose_mobile")
		root.size = Vector2i(1366, 768)
		await frames(3)
	# Two identical rounds must remain draws; a real winning hand ends round three.
	var rounds := [Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]
	for round_index: int in rounds.size():
		var pair: Vector2i = rounds[round_index]
		arena._choose(pair.x)
		arena._choose(2)  # A rapid second click cannot submit for the other seat.
		check(arena._submitted.size() == 1 and stage.revealed.is_empty(), "Double clicks cannot choose another player's hand or reveal the first pick")
		await frames(2)
		for index: int in 180:
			if arena._pick_seat == defender:
				break
			await process_frame
		check(arena._pick_seat == defender and stage.ready_seats.has(challenger), "Hotseat transfers only after the first choice is locked")
		arena._choose(pair.y)
		var rng_after_input := board.state.rng.state
		check(arena.animating and arena.holds_board() and stage.revealed.is_empty(), "Board captures wait for the simultaneous hand reveal")
		var windup_shot := false
		var reveal_shot := false
		while stage.active:
			if stage.elapsed < DuelRpsStage.THROW_AT:
				check(stage.revealed.is_empty(), "Neither secret hand is exposed during the windup")
				if stage.elapsed > 0.4 and not windup_shot:
					windup_shot = true
					if round_index == 2:
						await capture("windup")
			if stage.mode == &"result" and not reveal_shot:
				reveal_shot = true
				check(stage.revealed.size() == 2 and int(stage.revealed[challenger]) == pair.x and int(stage.revealed[defender]) == pair.y, "Both authoritative hands appear together")
				check(stage.winner == (-1 if round_index < 2 else challenger), "The result highlights the actual engine winner")
				check(board.state.rng.state == rng_after_input, "Hand animation does not consume gameplay RNG")
				if round_index == 2:
					await capture("win")
				elif round_index == 0:
					await capture("draw")
			await process_frame
		check(windup_shot and reveal_shot, "The windup and simultaneous reveal both play")
		if round_index < 2:
			await wait_for_play(arena)
			check(manager.duel_pending() and board.state.get_pawn(defender * 10 + 1).has_left_start, "Repeated draws never eject a pawn or award a default win")
			check(stage.revealed.is_empty() and arena._buttons.get_child_count() == 3, "A draw resets hidden choices and all three buttons")
		else:
			check(not manager.duel_pending() and not board.state.get_pawn(defender * 10 + 1).has_left_start, "Rock beats scissors and the losing pawn is ejected")
	var closing_at := Time.get_ticks_msec()
	while Time.get_ticks_msec() - closing_at < 10000:
		if not is_instance_valid(arena):
			break
		await process_frame
	check(not is_instance_valid(arena) and board._duel_arena == null, "The completed RPS arena is freed")
	# A close in the middle of a reveal must not expose hands later or stall the queue.
	var aborted := DuelRpsStage.new()
	aborted.arena = null
	root.add_child(aborted)
	aborted.play_reveal({1: 0, 2: 1}, 1)
	await frames(2)
	aborted.cancel()
	check(not aborted.active and aborted.revealed.is_empty(), "Cancelling windup leaves no delayed reveal")
	aborted.queue_free()
	board.instant_roll_for_test = true
	if failures.is_empty():
		print("RPS_UI_OK")
	else:
		for message: String in failures:
			printerr("RPS_UI_FAIL " + message)
	quit(0 if failures.is_empty() else 1)
