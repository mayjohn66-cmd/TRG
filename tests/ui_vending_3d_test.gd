extends "res://tests/ui_mobile_fx_test.gd"

func run() -> void:
	create_timer(60).timeout.connect(func() -> void: printerr("VENDING_UI_FAIL timeout"); quit(1))
	MatchTelemetry.test_sender = func(_url: String, _body: PackedByteArray, _type: String) -> void: pass
	var saved_board: StringName = GameSession.board_id()
	GameSession.set_board(&"monatium")
	root.content_scale_size = Vector2i(1366,768)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	await window(Vector2i(1366,768))
	await fixture()
	board.instant_roll_for_test = false
	board._skill_hint.hide()
	var before: Dictionary = TurnSnapshot.capture(board.state).data
	var rng_before: int = board.state.rng.state
	for drink: StringName in VendingDrinks.ids():
		board._play_vending_pull(12,drink)
		var panel: Panel = board.get_node("VendingPullModal")
		var stage: Control = panel.get_node("Vending3D")
		var viewport: SubViewport = stage.get("render_view")
		var tween: Tween = panel.get_meta("vending_tween")
		tween.pause()
		stage.set_process(false)
		tween.custom_step(0.58)
		stage.call("set_time",0.58)
		await frames(6) # First use also uploads the 3D meshes before capture.
		check(stage.get("phase") == &"drop", "can drops inside bay")
		if drink == &"energy": await capture("vending-drop")
		tween.custom_step(0.30)
		stage.call("set_time",0.88)
		check(stage.get("phase") == &"tray", "can reaches tray before reveal")
		if drink == &"energy": await capture("vending-tray")
		tween.custom_step(0.98)
		stage.call("set_time",1.86)
		await frames(5)
		check((stage.get("can") as Node3D).name == "Can_"+String(drink), "3D can follows authoritative drink")
		check((panel.get_node("DrinkName") as Label).text == L10n.t(VendingDrinks.name_of(drink))+"!", "correct drink name")
		check((panel.get_node("DrinkBuff") as Label).text == L10n.t(VendingDrinks.text_of(drink)), "correct buff text")
		check(board._fx_until_msec > Time.get_ticks_msec(), "board waits for modal")
		await capture("vending-"+String(drink))
		if drink == &"milk":
			await window(Vector2i(844,390))
			await frames(6)
			await capture("vending-mobile")
			var rect: Rect2 = panel.get_global_rect()
			check(root.get_visible_rect().encloses(rect), "modal fits phone")
			near("vending modal center",rect.get_center(),root.get_visible_rect().get_center())
			await window(Vector2i(1366,768))
		tween.custom_step(1.2)
		await frames(4)
		check(not is_instance_valid(panel) and not is_instance_valid(stage) and not is_instance_valid(viewport), "finished effect frees panel and 3D viewport")
		board.sweep_oneshot_fx(true)
		board._fx_until_msec = 0
	# Natural playback timing and cancellation, independent of test seeking.
	board._play_vending_pull(12,&"energy")
	var natural: Panel = board.get_node("VendingPullModal")
	var deadline := board._fx_until_msec + 500
	while (is_instance_valid(natural) or Time.get_ticks_msec() < board._fx_until_msec) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not is_instance_valid(natural), "natural playback completes")
	check(Time.get_ticks_msec() >= board._fx_until_msec, "natural hold expires")
	board._play_vending_pull(12,&"coffee")
	var canceled: Panel = board.get_node("VendingPullModal")
	board.sweep_oneshot_fx(true)
	await frames(4)
	check(not is_instance_valid(canceled), "rematch/reset cancels 3D presentation")
	check(TurnSnapshot.capture(board.state).data==before and board.state.rng.state==rng_before, "presentation changes no game state or RNG")
	board.queue_free()
	await frames(4)
	GameSession.set_board(saved_board)
	MatchTelemetry.test_sender = Callable()
	for failure: String in failures: printerr("VENDING_UI_FAIL ",failure)
	print("VENDING_3D_UI ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
