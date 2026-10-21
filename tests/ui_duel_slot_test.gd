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

func capture(title: String) -> void:
	var directory := OS.get_environment("DUEL_CAPTURE_DIR")
	if directory == "":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(title + ".png"))

func make_arena(game_id: int) -> DuelArena:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9810 + game_id
	board._open_duel_arena(1, 2, game_id, DuelRules.setup_game(game_id, rng))
	var arena := board._duel_arena
	arena.local_seats = [1, 2]
	arena.push_event(&"duel_started", {})
	arena.open()
	return arena

func run() -> void:
	create_timer(65).timeout.connect(func() -> void: printerr("DUEL_SLOT_FAIL timeout"); quit(1))
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
	board.instant_roll_for_test = false
	var games: Array[int] = [0, 1, 2, 3, 4, 5]
	if OS.get_environment("DUEL_CAPTURE_DIR") != "":
		games = [1]
	for game_id: int in games:
		var rng_before := board.state.rng.state
		var arena := make_arena(game_id)
		var selected: Array[int] = []
		arena.game_selected.connect(func(value: int) -> void: selected.append(value))
		await frames(3)
		check(not arena._message.visible, "No bottom description during the slot reveal")
		check(arena._step == &"roulette" and arena.animating and board._bot_should_wait(), "Bots wait until the reel and rule introduction finish")
		check(arena._clock < 0.0 and arena._timer_left == 0.0 and arena._buttons.get_child_count() == 0, "No game clock, timeout or input before selection")
		arena._submit(1, 0)
		check(arena._submitted.is_empty(), "Early inputs cannot commit a choice during selection")
		var spin_shot := false
		var brake_shot := false
		var selected_shot := false
		var rules_shot := false
		while arena._step in [&"roulette", &"selected", &"rules", &"preparing"]:
			var slot := arena._game_slot
			if slot.active:
				check(selected.is_empty() and arena._drawing.reveal.is_empty(), "The authoritative result stays hidden during the draw")
			if slot.elapsed > 0.65 and not spin_shot:
				spin_shot = true
				await capture("spinning")
			if slot.elapsed > 2.0 and not brake_shot:
				brake_shot = true
				await capture("braking")
			if arena._step == &"selected" and not selected_shot:
				selected_shot = true
				check(slot.settled and posmod(roundi(slot.reel_position), DuelRules.GAME_COUNT) == game_id, "The center ticket exactly matches the engine game")
				check(arena._buttons.get_child_count() == 0 and arena._clock < 0.0, "The locked ticket is shown before gameplay")
				await capture("selected")
			if arena._step == &"rules" and not rules_shot:
				rules_shot = true
				check(not arena._message.visible and not slot.visible and arena._intro_panel.visible, "Rules replace the slot rather than appearing underneath it")
				check(arena._intro_headline.text == DuelArena.INTRO_HEADLINES[game_id] and arena._intro_how.text == DuelArena.INTRO_HOW[game_id], "Large instructions match the selected game")
				check(arena._intro_how.get_theme_font_size("font_size") >= 24 and arena._buttons.get_child_count() == 1, "Large readable instructions have a single start button")
				await capture("rules")
				if OS.get_environment("DUEL_CAPTURE_DIR") != "":
					root.size = Vector2i(844, 390)
					await frames(3)
					await capture("rules_mobile")
					root.size = Vector2i(1366, 768)
					await frames(3)
			if arena._step == &"rules" and not arena._intro_ready:
				check(arena._clock < 0.0 and arena._timer_left == 0.0 and arena.animating, "Reading never starts a gameplay clock")
				# One game exercises automatic continuation; the others use the button.
				if game_id != 0 and arena._intro_elapsed > 0.8:
					arena._confirm_intro()
			await process_frame
		check(spin_shot and brake_shot and selected_shot and rules_shot, "Spin, braking, selected ticket and rule introduction all occur")
		check(selected == [game_id] and arena._game_slot.visited.size() > DuelRules.GAME_COUNT, "Only one selected event after multiple reel cycles")
		check(arena._step == &"play" and not arena.animating and not arena._game_slot.visible and arena._buttons.get_child_count() > 0, "Inputs only open once the introduction ends")
		check(board.state.rng.state == rng_before, "Cosmetic reel does not consume authoritative RNG")
		check(DuelRules.time_limit(game_id) >= DuelRules.ROULETTE_TIME + DuelRules.INTRO_TIME + DuelRules.TIME_BARREL_PICK, "Engine deadline includes the complete presentation allowance")
		await capture("play")
		if OS.get_environment("DUEL_CAPTURE_DIR") != "":
			root.size = Vector2i(844, 390)
			await frames(3)
			var visual := arena.get_global_transform().get_scale() * arena.size
			check(visual.y <= board.get_viewport_rect().size.y - 25, "The modal fits a short mobile viewport")
			await capture("play_mobile")
			root.size = Vector2i(1366, 768)
		arena.close_now()
		await create_timer(0.3).timeout
		check(not is_instance_valid(arena) and board._duel_arena == null, "Closing removes the slot and releases the arena reference")
	# Even an outcome already received from the network must wait behind the reel.
	var queued := make_arena(DuelRules.Game.RPS)
	queued.push_event(&"duel_revealed", {"picks": {1: 0, 2: 1}, "winner": 1, "detail": "바위 vs 가위", "decided_by": &"hand"})
	await frames(3)
	check(queued._drawing.reveal.is_empty() and queued.holds_board(), "Queued network outcomes wait behind selection and hold board effects")
	queued.close_now()
	await create_timer(0.35).timeout
	check(not is_instance_valid(queued) and board._duel_arena == null and not board._bot_should_wait(), "Closing during spin safely releases all presentation holds")
	# Card previews queued behind an introduction must have an owner even if
	# the presentation is reset before the announcement can consume them.
	board._is_playing_presentation = true
	var preview := board._make_card_preview(&"ACT_09")
	board._announce("test", "test", "", Color.WHITE, preview)
	check(preview.is_inside_tree() and not preview.visible, "Queued card previews remain owned and hidden")
	board._reset_presentation()
	await frames(3)
	check(not is_instance_valid(preview), "Cancelling a presentation frees pending card previews")
	board.instant_roll_for_test = true
	if failures.is_empty():
		print("DUEL_SLOT_OK")
	else:
		for message: String in failures:
			printerr("DUEL_SLOT_FAIL " + message)
	quit(0 if failures.is_empty() else 1)
