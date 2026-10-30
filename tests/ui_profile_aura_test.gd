## Only the persistent Devil/Gambler profile marks, not their activation stages.
extends "res://tests/ui_super_fx_test.gd"

func _run() -> void:
	GameSession.mode = GameSession.MODE_AI
	_board = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	root.add_child(_board)
	var guard := 0
	while (not _board._draft_open or _board._intro_blocks()) and guard<2400:
		guard += 1
		await process_frame
	_board._bot.set_enabled(false)
	_board.manager.set_process(false)
	_board._reset_presentation()
	_board._draft_overlay.hide()
	_board._announcer.cancel()
	var panel: Control = _board._profiles[1].panel
	var original_size := panel.size
	var rng_before := _board.state.rng.state
	_board.state.permanent_roll_bonus[1] = 3
	_board._refresh_super_marks()
	await create_timer(0.85).timeout
	var devil: Control = panel.get_node_or_null("SuperFlame")
	_expect(devil!=null and devil.get_script()==SuperFX.PROFILE_AURA,"Profile uses the refined aura")
	_expect(devil.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Aura does not intercept profile controls")
	_expect(devil.size==panel.size and panel.size==original_size,"Aura follows the outer card without changing layout")
	_expect(devil.global_position.distance_to(panel.global_position)<0.1,"Aura follows the outer edge rather than the content inset")
	_expect((_board._profiles[2].panel as Control).get_node_or_null("SuperFlame")==null,"Unbuffed profiles remain clear")
	var resting_scale := panel.scale
	panel.scale = resting_scale*0.96
	await process_frame
	await process_frame
	_expect(devil.get_global_rect().is_equal_approx(panel.get_global_rect()),"Aura follows profile reaction scaling")
	panel.scale = resting_scale
	await process_frame
	await capture("devil")
	_board.state.permanent_roll_bonus.erase(1)
	_board.state.gambler_round[1] = _board.state.round_number
	_board._refresh_super_marks()
	_expect(panel.get_node("SuperFlame")==devil,"Updating the active effect does not restart its animation")
	await create_timer(0.65).timeout
	_expect(devil.colors==[Color("ffd43b"),Color("ff922b")],"Gambler keeps its gold and amber identity")
	await capture("gambler")
	_board.state.permanent_roll_bonus[1] = 3
	_board._refresh_super_marks()
	_expect(devil.colors.size()==4,"Both buffs coexist on the same profile")
	await create_timer(0.65).timeout
	await capture("combined")
	_board.state.round_number += 1
	_board._refresh_super_marks()
	_expect(devil.colors==[Color("9c36b5"),Color("e03131")],"Round expiration removes gold but preserves the permanent contract")
	_board._super_hidden["1:SUPER_03"] = true
	_board._refresh_super_marks()
	_expect(panel.get_node_or_null("SuperFlame")==null,"Hidden or expired marks disappear immediately")
	_board._super_hidden.clear()
	_board._refresh_super_marks()
	_expect(panel.get_node_or_null("SuperFlame")!=null,"A hidden mark can return in the same frame")
	_board.state.permanent_roll_bonus.clear()
	_board._refresh_super_marks()
	_expect(panel.get_node_or_null("SuperFlame")==null,"No stale effect remains after removal")
	_expect(_board.state.rng.state==rng_before,"Profile animation consumes no gameplay RNG")
	await _drop_board()
	if _failures.is_empty():
		print("UI_PROFILE_AURA_OK")
		quit(0)
	else:
		for failure: String in _failures:
			printerr("UI_PROFILE_AURA_FAIL: "+failure)
		quit(1)

func capture(label: String) -> void:
	var folder := OS.get_environment("PROFILE_AURA_CAPTURE_DIR")
	if folder.is_empty():
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))
