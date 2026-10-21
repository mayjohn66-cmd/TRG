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
	var directory := OS.get_environment("QUICKDRAW_CAPTURE_DIR")
	if directory.is_empty():
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(name + ".png"))
	print("QUICKDRAW_FRAME ", name, " ", Engine.get_process_frames())

func wait_play(arena: DuelArena) -> void:
	var loading_shown := false
	var spin_shown := false
	while arena._step != &"play":
		if arena._step == &"preparing":
			if arena._quickdraw_stage.elapsed > 0.50 and not loading_shown:
				loading_shown = true
				await capture("cylinders_open")
			if arena._quickdraw_stage.elapsed > 1.65 and not spin_shown:
				spin_shown = true
				await capture("cylinders_spin")
		if arena._step == &"rules" and arena._intro_elapsed > 0.15:
			arena._confirm_intro()
		await process_frame

func fixture(seats: Array[int]) -> DuelArena:
	var arena := DuelArena.new()
	arena.setup(board, 1, 2, seats, DuelRules.Game.QUICKDRAW, {"signal": 2.0, "fake": 0.7})
	board.add_child(arena)
	arena.open()
	arena._game_label.text = DuelRules.game_name(arena.game)
	arena._begin_game()
	return arena

func resolved(arena: DuelArena, picks: Dictionary) -> Dictionary:
	var data := DuelRules.resolve(arena.game, arena.setup_data, arena.challenger, arena.defender, picks)
	data["picks"] = picks
	return data

func run() -> void:
	create_timer(65).timeout.connect(func() -> void: printerr("QUICKDRAW_UI_FAIL timeout"); quit(1))
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
	manager.duel_game_override = DuelRules.Game.QUICKDRAW
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
	check(arena != null and manager.duel_pending(), "Actual ACT_09 starts Quickdraw")
	if arena == null:
		quit(1)
		return
	arena.open()
	await wait_play(arena)
	var stage := arena._quickdraw_stage
	check(stage.guns.size() == 2 and stage.guns[0].flip_h and not stage.guns[1].flip_h, "Approved revolvers face each other")
	check(stage.guns[0]._cylinder != null and stage.guns[1]._cylinder != null, "Both guns reuse the assembled 3D cylinder model")
	check(stage.visible and not arena._drawing.visible, "Two 3D guns replace the cowboy placeholder")
	for button: Button in arena._buttons.get_children():
		check(button.action_mode == BaseButton.ACTION_MODE_BUTTON_PRESS, "Fire records mouse-down")
	await capture("ready")
	var mark := DuelRules.reaction_mark(arena.game, arena.setup_data)
	while arena._clock < mark:
		await process_frame
	await capture("draw")
	while arena._clock < mark + 0.10:
		await process_frame
	var key := InputEventKey.new()
	key.keycode = KEY_A
	key.pressed = true
	arena._input(key)
	var first := int(arena._submitted[challenger])
	arena._press(challenger)
	check(stage.strikes.size() == 1 and arena._submitted.size() == 1, "Local fire is immediate and deduplicated")
	await create_timer(0.14).timeout
	key.keycode = KEY_L
	arena._input(key)
	var rng_after := board.state.rng.state
	check(arena.holds_board() and stage.result.is_empty(), "Pawn ejection waits for the flag reveal")
	await create_timer(0.65).timeout
	check(stage.guns[0].flag_root.visible and stage.guns[1].flag_root.visible, "Both discharges unfold party flags")
	await capture("flags")
	while stage.result.is_empty():
		await process_frame
	check(int(stage.result["winner"]) == challenger and int(stage.result["picks"][challenger]) == first, "Exact recorded reaction milliseconds decide the winner")
	await capture("result")
	if not OS.get_environment("QUICKDRAW_CAPTURE_DIR").is_empty():
		root.size = Vector2i(844, 390)
		await frames(3)
		var visual := arena.get_global_transform().get_scale() * arena.size
		check(visual.y <= board.get_viewport_rect().size.y - 25, "Both revolvers fit a short mobile viewport")
		await capture("mobile")
		root.size = Vector2i(1366, 768)
	while is_instance_valid(arena):
		await process_frame
	check(board._duel_arena == null and not manager.duel_pending(), "Actual ACT_09 duel releases input and renderer")
	check(not board.state.get_pawn(defender * 10 + 1).has_left_start, "The actual losing pawn is ejected")
	check(board.state.rng.state == rng_after, "Cosmetic preparation and shots never consume game RNG")
	board._reset_presentation()
	board._announcer.cancel()
	arena = fixture([])
	stage = arena._quickdraw_stage
	await frames(8)
	check(arena._step == &"preparing" and arena._clock < 0.0 and arena.animating, "Loading is outside the reaction clock")
	arena._press(1)
	check(arena._submitted.is_empty() and arena._buttons.get_child_count() == 0, "Loading cannot accidentally commit an early shot")
	await capture("loading")
	while arena._step == &"preparing":
		await process_frame
	arena._play_reveal(resolved(arena, {1: 2200, 2: 2340}))
	await create_timer(0.4).timeout
	check(stage.strikes.is_empty() and stage.result.is_empty(), "Queued remote inputs remain hidden before their timestamps")
	while stage.result.is_empty():
		await process_frame
	check(stage.strikes == {1: 2200, 2: 2340} and stage.result["winner"] == 1, "Remote shots play at their recorded timestamps")
	arena.close_now()
	await create_timer(0.30).timeout
	arena = fixture([1])
	stage = arena._quickdraw_stage
	while arena._step != &"play":
		await process_frame
	while arena._clock < 0.75:
		await process_frame
	check(stage.cue == 1, "A burp is a visible fake signal")
	var fire_button := arena._buttons.get_child(0) as Button
	var click_point := fire_button.get_global_transform_with_canvas() * (fire_button.size / 2.0)
	var motion := InputEventMouseMotion.new()
	motion.position = click_point
	root.notify_mouse_entered()
	root.push_input(motion, true)
	var click := InputEventMouseButton.new()
	click.position = click_point
	click.global_position = click_point
	click.button_index = MOUSE_BUTTON_LEFT
	click.button_mask = MOUSE_BUTTON_MASK_LEFT
	click.pressed = true
	root.push_input(click, true)
	check(arena._submitted.has(1), "The visible fire button records an actual GUI press without waiting for release")
	arena._play_reveal(resolved(arena, {1: int(arena._submitted[1]), 2: -1}))
	while stage.result.is_empty():
		await process_frame
	check(stage.result["decided_by"] == &"foul" and stage.result["winner"] == 2, "Firing at the fake signal remains an authoritative foul")
	await capture("foul")
	arena.close_now()
	await create_timer(0.30).timeout
	arena = fixture([1, 2])
	stage = arena._quickdraw_stage
	while arena._step in [&"preparing", &"play"]:
		await process_frame
	check(arena._submitted == {1: -1, 2: -1}, "No-input timeout submits two misses")
	await arena._play_reveal(resolved(arena, arena._submitted))
	check(stage.strikes.is_empty() and stage.result["decided_by"] == &"nobody", "Timeout invents no flag shots")
	arena.close_now()
	await create_timer(0.30).timeout
	arena = fixture([])
	stage = arena._quickdraw_stage
	await frames(2)
	arena.close_now()
	check(not stage.active and not stage.preparing, "Closing cancels and unblocks preparation")
	for gun: ToyFlagGun3D in stage.guns:
		check(gun.render_view.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Cancelled guns stop both viewport renderers")
	await create_timer(0.30).timeout
	board.instant_roll_for_test = true
	board.queue_free()
	await frames(4)
	if failures.is_empty():
		print("QUICKDRAW_UI_OK")
	else:
		for message: String in failures:
			printerr("QUICKDRAW_UI_FAIL " + message)
	quit(0 if failures.is_empty() else 1)
