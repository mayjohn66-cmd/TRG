## Focused presentation check: public outcomes, confirmation, turn boundaries and phone layout.
extends SceneTree

var board: MainBoard
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func frames(count: int = 3) -> void:
	for index: int in count: await process_frame

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func capture(label: String) -> void:
	var folder := OS.get_environment("ROLL_HISTORY_CAPTURE_DIR")
	if folder.is_empty(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))

func show_result(result: RollResult) -> void:
	board._handle_roll_event({"player_id":1,"result":result.to_dict()})
	await frames()
	board._place_roll_history()

func yut(face: int) -> RollResult:
	# Use a real tool result with a reproducible face, without touching match RNG.
	var tool := ToolYut.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 68
	for index: int in 200:
		var result := tool.roll(rng)
		if int(result.details.face)==face: return result
	return null

func run() -> void:
	create_timer(80).timeout.connect(func() -> void: printerr("ROLL_HISTORY_FAIL timeout"); quit(1))
	MobileSupport.force_touch = true
	root.content_scale_size = Vector2i(1366,768)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.size = Vector2i(844,390)
	board = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	board.instant_roll_for_test = true
	root.add_child(board)
	await frames()
	board._bot.set_enabled(false)
	board.manager.set_process(false)
	board.ai_mode = false
	board.pacing_enabled = false
	board._close_opening()
	board._on_draft_auto_pressed()
	await frames()
	board._reset_presentation()
	board._close_draft_overlay()
	board._close_augment_review()
	board._announcer.cancel()
	board.set_process(false)
	board.layout_for(root.get_visible_rect().size)
	var before := board.state.rng.state
	var history := board._roll_history
	check(not history.visible,"no history before the first reveal")
	await show_result(yut(4))
	await show_result(yut(5))
	await show_result(yut(4))
	check(history.entries.map(func(item: Dictionary) -> String: return item.text)==["윷","모","윷"],"Yut face sequence is retained in order")
	check(history._footer.text==L10n.t("한 번 더"),"reroll is marked")
	for size: Vector2i in [Vector2i(844,390),Vector2i(740,360),Vector2i(1366,768)]:
		root.size = size
		await frames()
		board.layout_for(root.get_visible_rect().size)
		board._place_roll_history()
		await frames()
		board._place_roll_history()
		check(root.get_visible_rect().encloses(history.get_rect()),"history fits viewport "+str(size))
		check(history.position.x+history.size.x<board._board_center().x-170,"Yut history stays beside tool "+str(size))
		await capture("yut_%d" % size.x)
	await show_result(yut(0))
	check(history.entries.back().text=="낙" and history._footer.text==L10n.t("턴 종료"),"Nak remains visible as terminal outcome")
	var count := history.entries.size()
	history.reveal(board._roll_turn_serial-1,1,yut(3).to_dict())
	check(history.entries.size()==count,"stale reveal cannot append")
	board._on_phase_changed(TurnManager.State.PHASE_TURN_BEGIN,1,30)
	await show_result(yut(2))
	check(history.entries.size()==1 and history.entries[0].text=="개","new turn for the same player resets sequence")
	var gun := ToolRussianRoulette.new()
	board.state.tools[1] = gun
	board.manager.current_state = TurnManager.State.PHASE_ROLL_WAIT
	board._refresh_all()
	var rng := RandomNumberGenerator.new()
	rng.seed = 52
	gun.load_chamber(2)
	await show_result(gun.roll(rng))
	await show_result(gun.roll(rng))
	await show_result(gun.roll(rng))
	check(history.entries.map(func(item: Dictionary) -> String: return item.text)==["성공","성공","실패"],"safe shots followed by failure")
	check(history._header.text.contains(L10n.tf("%d회 성공",[2])),"failure does not increase success count")
	await capture("revolver_fail")
	board._on_phase_changed(TurnManager.State.PHASE_TURN_BEGIN,1,30)
	gun.load_chamber(5)
	await show_result(gun.roll(rng))
	await show_result(gun.roll(rng))
	await show_result(gun.cash_out())
	check(history.entries.size()==2 and history._footer.text==L10n.tf("%d칸 확정",[6]),"cash-out confirms six steps without a phantom shot")
	board._on_phase_changed(TurnManager.State.PHASE_TURN_BEGIN,1,30)
	gun.load_chamber(5)
	for index: int in 5: await show_result(gun.roll(rng))
	check(history.entries.size()==5 and history._footer.text==L10n.tf("%d칸 확정",[15]),"automatic fifth safe shot is counted")
	await capture("revolver_five")
	for language: String in ["en","ja","ko"]:
		L10n.set_language(language)
		history._refresh()
		await frames()
		var font := history._footer.get_theme_font("font")
		check(font.get_string_size(history._footer.text,HORIZONTAL_ALIGNMENT_LEFT,-1,19).x<=history._footer.size.x,"footer fits "+language)
		await capture("revolver_"+language)
	var blackjack := ToolBlackjack.new()
	var dealt := blackjack.roll(rng)
	while not dealt.can_continue: dealt = blackjack.roll(rng)
	await show_result(dealt)
	await show_result(blackjack.cash_out())
	check(history.entries.size()==1,"stand does not count as another blackjack draw")
	await frames()
	board._place_roll_history()
	check(not history.get_rect().intersects(board._stage_blackjack.get_rect()),"stage history does not cover cards")
	await capture("blackjack")
	var long_draw := dealt.to_dict()
	for index: int in 5: history.reveal(board._roll_turn_serial,1,long_draw)
	for size: Vector2i in [Vector2i(844,390),Vector2i(740,360),Vector2i(1366,768)]:
		root.size = size
		await frames()
		board.layout_for(root.get_visible_rect().size)
		board._place_roll_history()
		await frames()
		board._place_roll_history()
		check(not history.get_rect().intersects(board._stage_blackjack.get_rect()),"six stage results do not cover cards "+str(size))
		check(root.get_visible_rect().encloses(history.get_rect()),"six stage results fit "+str(size))
		await capture("blackjack_six_%d" % size.x)
	var yacht := ToolYacht.new()
	await show_result(yacht.roll(rng))
	await show_result(yacht.cash_out())
	check(history.entries.size()==1,"Yacht confirmation does not count as a roll")
	await show_result(yacht.roll(rng))
	await show_result(yacht.roll(rng))
	await show_result(yacht.roll(rng))
	count = history.entries.size()
	await show_result(yacht.roll(rng))
	check(history.entries.size()==count,"automatic Yacht confirmation is not another roll")
	board._reset_presentation()
	history.arm(board._roll_turn_serial,1,&"LIFE_ROULETTE")
	var seven := RollResult.make(&"LIFE_ROULETTE",7,{"face":7})
	seven.reroll = true
	for index: int in 8: history.reveal(board._roll_turn_serial,1,seven.to_dict())
	check(history.entries.size()==8 and history._rows.get_child_count()==6,"long chains retain total and show recent six")
	check((history._rows.get_child(0) as Label).text.begins_with("3  "),"recent rows retain original roll numbers")
	check(history.mouse_filter==Control.MOUSE_FILTER_IGNORE,"history does not intercept roll input")
	check(board.state.rng.state==before,"presentation leaves match RNG unchanged")
	board._reset_presentation()
	check(history.entries.is_empty() and not history.visible,"reset clears current history")
	# Actual animation must not expose the result on arrival of roll_resolved.
	board.instant_roll_for_test = false
	board.state.tools[1] = ToolYut.new()
	board._handle_roll_event({"player_id":2,"result":yut(4).to_dict()})
	check(history.entries.is_empty(),"throw begins without revealing outcome")
	await create_timer(3.0).timeout
	check(history.entries.size()==1 and history.entries[0].text=="윷","throw appends only after presentation reveal")
	board.queue_free()
	await frames()
	for failure: String in failures: printerr("ROLL_HISTORY_FAIL "+failure)
	print("ROLL_HISTORY_CHECKS ",checks)
	if failures.is_empty(): print("ROLL_HISTORY_OK")
	quit(0 if failures.is_empty() else 1)
