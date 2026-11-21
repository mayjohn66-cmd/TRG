extends "res://tests/ui_mobile_fx_test.gd"

func choices(count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i: int in count:
		result.append({"label":"가나다라마바사아자차 · %d번 말 (12번 칸)" % (i+1),"name":"가나다라마바사아자차","detail":"%d번 말 · 12번 칸" % (i+1),"portrait":board._choice_portrait(i%3+2),"value":i+2})
	return result

func shape() -> void:
	var modal: Control = board._choice_overlay
	var panel: Panel = modal.get("panel")
	var rect: Rect2 = panel.get_global_rect()
	check(absf(rect.size.x-rect.size.y)<1.0,"panel is square")
	near("target panel center",rect.get_center(),root.get_visible_rect().get_center())
	check(root.get_visible_rect().encloses(rect),"panel fits viewport")
	check((modal.get_parent() as CanvasLayer).layer>=10000,"target stays above judgement tools")
	var title: Label = modal.get("title_label")
	var scrolling: ScrollContainer = modal.get("scroll")
	check(title.get_global_rect().end.y <= scrolling.get_global_rect().position.y,"title does not overlap choices")
	for entry: Dictionary in modal.get("cards"):
		var button: Button = entry["button"]
		check(absf(button.size.x-button.size.y)<1.1,"option is square")
		var text: Label = entry["label"]
		check(text.position.x>=0 and text.position.x+text.size.x<=button.size.x+1,"text stays inside card")
		var detail: Label = entry["detail"]
		if detail.visible:
			check(text.position.y+text.size.y<=detail.position.y+1,"name does not overlap pawn location")

func run() -> void:
	create_timer(55).timeout.connect(func() -> void: printerr("TARGET_UI_FAIL timeout"); quit(1))
	MatchTelemetry.test_sender = func(_url: String,_body: PackedByteArray,_type: String) -> void: pass
	root.content_scale_size = Vector2i(1366,768)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	await window(Vector2i(1366,768))
	await fixture()
	var picked: Array = []
	var before: Dictionary = TurnSnapshot.capture(board.state).data
	for resolution: Vector2i in [Vector2i(1366,768),Vector2i(844,390),Vector2i(390,844)]:
		await window(resolution)
		board._show_choice("[UNO 스킵] 대상을 고르세요",choices(3),func(value: Variant) -> void: picked.append(value))
		await frames(8)
		shape()
		await capture("target-choice-%dx%d" % [resolution.x,resolution.y])
		var modal: Control = board._choice_overlay
		var cancel: Button = modal.get("cancel_button")
		cancel.pressed.emit()
		await frames(3)
		check(board._choice_overlay==null and picked.is_empty(),"cancel does not choose a target")
	board._show_choice("[방해령 베루] 뒤로 밀 적 말을 고르세요",choices(12),func(value: Variant) -> void: picked.append(value))
	await frames(8)
	var many: Control = board._choice_overlay
	var scroll: ScrollContainer = many.get("scroll")
	check(scroll.get_v_scroll_bar().max_value>scroll.size.y,"many choices scroll inside the fixed panel")
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await frames(4)
	var cards: Array = many.get("cards")
	var last: Button = cards[-1]["button"]
	check(scroll.get_global_rect().intersects(last.get_global_rect()),"last choice is reachable")
	await capture("target-choice-scroll")
	last.pressed.emit()
	last.pressed.emit()
	await frames(3)
	check(picked==[13] and board._choice_overlay==null,"chosen value delivered exactly once")
	check(TurnSnapshot.capture(board.state).data==before,"choice/cancel does not mutate game state")
	await window(Vector2i(1366,768))
	var values: Array[Dictionary] = []
	for number: int in 20: values.append({"label":"%d칸" % (number+1),"value":number+1})
	board._show_choice("다음 굴림 결과를 고르세요",values,func(_value: Variant) -> void: pass,3)
	await frames(6)
	shape()
	check((board._choice_overlay.get("grid") as GridContainer).columns==3,"numeric choices use three columns")
	await capture("target-choice-numbers")
	board._close_choice()
	await frames(3)
	# Real UNO action with pinball equipped: actual callback/card consumption.
	var player: int = board.manager.current_player_id()
	board.manager.change_state(TurnManager.State.PHASE_TURN_BEGIN)
	board._reset_presentation()
	board._close_opening()
	board.state.tools[player] = ToolPinball.new()
	board.state.hands[player] = [&"ACT_15"]
	board.manager._card_played_this_turn = false
	board._on_card_pressed(player,&"ACT_15")
	await frames(6)
	check(board._choice_overlay!=null,"UNO card opens target modal")
	if board._choice_overlay!=null:
		check(not board._stage_pinball.visible,"pinball does not obscure target modal")
		await capture("target-choice-uno")
		var modal: Control = board._choice_overlay
		var target: int = int((modal.get("options") as Array)[0]["value"])
		var button: Button = (modal.get("cards") as Array)[0]["button"]
		button.pressed.emit()
		await frames(4)
		check(not board.state.has_card(player,&"ACT_15") and bool(board.state.rest_next_turn.get(target,false)),"selected target receives actual UNO effect")
	# The production regression: the hacking card uses the same square player picker.
	board._reset_presentation()
	board.manager.change_state(TurnManager.State.PHASE_TURN_BEGIN)
	board._announcer.cancel()
	board.state.hands[player] = [&"ACT_23"]
	board.manager._card_played_this_turn = false
	board._on_card_pressed(player, &"ACT_23")
	await frames(6)
	check(board._choice_overlay != null, "Professional Hacking opens the centered target modal")
	if board._choice_overlay != null:
		shape()
		await capture("target-choice-hacking")
		var modal: Control = board._choice_overlay
		var target: int = int((modal.get("options") as Array)[0]["value"])
		var entry: Dictionary = (modal.get("cards") as Array)[0]
		check((entry["face"] as TextureRect).texture != null, "Hacking target shows the player portrait")
		(entry["button"] as Button).pressed.emit()
		await frames(4)
		check(not board.state.has_card(player, &"ACT_23") and int(board.state.hacked_turns.get(target, 0)) == 1, "Hacking is applied only to the selected player")
	board.queue_free()
	await frames(4)
	MatchTelemetry.test_sender = Callable()
	for failure: String in failures: printerr("TARGET_UI_FAIL ",failure)
	print("TARGET_CHOICE_UI ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
