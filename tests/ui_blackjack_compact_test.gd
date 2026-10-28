## Only the compact Blackjack presentation, batch deal and its input lifecycle.
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

func result_for(hand: Array[int], fresh: Array[int] = []) -> RollResult:
	var tool := ToolBlackjack.new()
	tool.cards.assign(hand)
	tool._started = true
	return tool._after_draw(hand.duplicate() if fresh.is_empty() else fresh,false)

func show_result(result: RollResult) -> void:
	board._handle_roll_event({"player_id":1,"result":result.to_dict()})
	await frames()

func capture(label: String) -> void:
	var folder := OS.get_environment("BLACKJACK_CAPTURE_DIR")
	if folder.is_empty(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))

func batch(stage: BlackjackStage, result: RollResult, completion: Dictionary) -> void:
	await stage.play(result.to_dict())
	completion.done = true

func run() -> void:
	create_timer(70).timeout.connect(func() -> void: printerr("BLACKJACK_COMPACT_FAIL timeout"); quit(1))
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
	board.state.tools[1] = ToolBlackjack.new()
	board.manager.current_state = TurnManager.State.PHASE_ROLL_WAIT
	board._refresh_all()
	var stage := board._stage_blackjack
	var rng_before := board.state.rng.state
	var opening := result_for([2,2,2,2,2,2])
	for language: String in ["ko","en","ja"]:
		L10n.set_language(language)
		for phone: Vector2i in [Vector2i(844,390),Vector2i(740,360),Vector2i(1366,768)]:
			root.size = phone
			await frames()
			board.layout_for(root.get_visible_rect().size)
			await show_result(opening)
			check(stage.size==BlackjackStage.STAGE_SIZE,"fixed size "+language+str(phone))
			check(root.get_visible_rect().encloses(stage.get_rect()),"stage stays in viewport "+language+str(phone))
			check(stage.cards.size()==6 and stage._row.get_child_count()==3,"six cards retain actual hand with three views")
			check(not board._roll_history.visible,"no separate Blackjack history above stage")
			check(stage._total_label.text==L10n.tf("합계 %d",[12]),"large current total")
			check(stage._count_label.text==L10n.tf("%d장",[6]),"actual card count")
			for node: Control in [stage._hit_button,stage._stand_button,stage._total_label,stage._move_label,stage._count_label]:
				var box := Rect2(stage.get_global_transform().affine_inverse()*node.global_position,node.size)
				check(Rect2(Vector2.ZERO,stage.size).encloses(box),"content stays in fixed stage: "+node.name)
			for button: Button in [stage._hit_button,stage._stand_button]:
				var text_width := button.get_theme_font("font").get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
				check(text_width<=button.size.x-20,"button caption fits "+language)
			for card: JudgmentCard in stage._row.get_children():
				for corner: Vector2 in [Vector2.ZERO,Vector2(card.size.x,0),card.size,Vector2(0,card.size.y)]:
					check(Rect2(Vector2.ZERO,stage.size).has_point(stage.get_global_transform().affine_inverse()*(card.get_global_transform()*corner)),"overlapped cards stay in stage")
			await capture("pending_%s_%d" % [language,phone.x])
	L10n.set_language("ko")
	var long_hand: Array[int] = []
	for index: int in 10: long_hand.append(1)
	long_hand.append(2)
	for index: int in 9: long_hand.append(1)
	# A possible 20-card hand: the two drops ten aces from 20 to 12; nine more aces reach 21.
	await show_result(result_for(long_hand,[1]))
	check(stage.cards==long_hand and stage._row.get_child_count()==3,"20-card hand remains compact")
	check(stage._total_label.text=="BLACKJACK!" and stage._move_label.text.contains(L10n.t("한 번 더")),"21 and reroll remain explicit")
	check(stage.size==BlackjackStage.STAGE_SIZE and not board._roll_history.visible,"long hand cannot grow stage or history")
	var banner_labels := board._center_banner.find_children("*","Label",true,false)
	check(not banner_labels.is_empty() and str(banner_labels[0].text).length()<65 and not str(banner_labels[0].text).contains("[A A"),"final notice does not enumerate the hand")
	await capture("blackjack_twenty")
	await show_result(result_for([10,9,3],[3]))
	check(stage._total_label.text=="BUST!" and stage._move_label.text.contains("22") and stage._move_label.text.contains(L10n.t("턴 종료")),"bust shows total and turn end")
	await capture("bust")
	var tool := ToolBlackjack.new()
	tool.cards.assign([10,8])
	tool._started = true
	await show_result(tool.cash_out())
	check(stage._total_label.text==L10n.tf("합계 %d",[18]) and stage._move_label.text==L10n.tf("%d칸 확정",[8]),"stand confirms correct movement")
	for language: String in ["en","ja","ko"]:
		L10n.set_language(language)
		stage._refresh()
		check(stage._total_label.text==L10n.tf("합계 %d",[18]) and stage._move_label.text==L10n.tf("%d칸 확정",[8]),"confirmed result follows language changes "+language)
	# A standalone stage verifies actual buttons without dispatching unrelated match actions.
	var input_stage := BlackjackStage.new()
	root.add_child(input_stage)
	input_stage.instant = true
	input_stage.can_act = true
	input_stage.play(opening.to_dict())
	var actions := {"hit":0,"stand":0}
	input_stage.hit_pressed.connect(func() -> void: actions.hit += 1)
	input_stage.stand_pressed.connect(func() -> void: actions.stand += 1)
	input_stage._hit_button.pressed.emit()
	input_stage._stand_button.pressed.emit()
	check(actions.hit==1 and actions.stand==1,"compact controls dispatch their original actions")
	input_stage.active = true
	input_stage._refresh()
	input_stage._hit_button.pressed.emit()
	input_stage._stand_button.pressed.emit()
	check(actions.hit==1 and actions.stand==1 and input_stage._hit_button.disabled,"dealing blocks repeat input")
	input_stage.reset()
	input_stage.instant = false
	var completion := {"done":false}
	batch(input_stage,opening,completion)
	check(input_stage.active and input_stage._total_label.text=="…","batch starts without a premature total")
	await create_timer(0.14).timeout
	check(input_stage.cards.size()==6 and input_stage._row.get_child_count()==3,"opening cards arrive together")
	await create_timer(0.24).timeout
	check(completion.done and not input_stage.active and input_stage._total_label.text==L10n.tf("합계 %d",[12]),"six-card deal completes in one short animation")
	input_stage.reset()
	completion = {"done":false}
	batch(input_stage,opening,completion)
	await create_timer(0.04).timeout
	input_stage.reset()
	await create_timer(0.32).timeout
	check(input_stage.cards.is_empty() and not input_stage.active and not input_stage.started,"reset cancels an unfinished batch")
	input_stage.queue_free()
	check(board.state.rng.state==rng_before,"compact presentation leaves match RNG unchanged")
	board.queue_free()
	await frames()
	for failure: String in failures: printerr("BLACKJACK_COMPACT_FAIL "+failure)
	print("BLACKJACK_COMPACT_CHECKS ",checks)
	if failures.is_empty(): print("BLACKJACK_COMPACT_OK")
	quit(0 if failures.is_empty() else 1)
