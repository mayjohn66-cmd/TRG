## v1.1 신규 콘텐츠 화면: 다트 조준판(던진 순간의 조준이 굴림에 실린다), 주식 차트·다트 결과 그림, 강화 망치 선택 판, 현상금 WANTED 표식, 멜론 크기, 오이 카드 손패.
extends "res://tests/ui_fx_test.gd"
var checks := 0


func _expect(ok: bool, message: String) -> void:
	checks += 1
	super._expect(ok, message)


func settle(n: int = 4) -> void:
	for i: int in n:
		await process_frame


func quiet() -> void:
	_board._announcer.cancel()
	_board._reset_presentation()
	_board._close_opening()
	_board._close_draft_overlay()
	_board._close_augment_review()
	_board._announced_round = _board.state.round_number
	_board._bot.set_enabled(false)
	_board.manager.set_process(false)
	_board.pacing_enabled = false


func _run() -> void:
	MatchTelemetry.test_sender = func(_url: String, _body: PackedByteArray, _type: String) -> void: pass
	_board._on_draft_auto_pressed()
	await settle(10)
	quiet()
	var manager: TurnManager = _board.manager
	var state: GameState = _board.state
	manager.current_turn_index = manager.player_order.find(_board.local_player_id)
	manager.change_state(TurnManager.State.PHASE_TURN_BEGIN)
	quiet()
	var me: int = manager.current_player_id()

	# 1) 다트: 조준판 없이 [다트 던지기] 한 번으로 던진다 (꽂히는 자리는 완전한 운)
	state.tools[me] = ToolRegistry.create(&"DICE_DARTS")
	_board.instant_roll_for_test = false
	_board._fx_busy = false
	_board._refresh_all()
	await settle(6)
	_expect(_board.find_child("DartAim", true, false) == null, "다트 차례에도 타이밍 조준판은 없다")
	_expect(_board._roll_button.text.contains("던지기"), "굴리기 버튼은 [다트 던지기] (%s)" % _board._roll_button.text)
	var events: Array = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void: events.append({"kind": kind, "data": data}))
	_board.instant_roll_for_test = true
	_board._on_roll_pressed()
	await settle()
	var rolled: Array = events.filter(func(event: Dictionary) -> bool: return event["kind"] == &"roll_resolved")
	_expect(not rolled.is_empty() and StringName(rolled[0]["data"]["result"]["tool_id"]) == &"DICE_DARTS", "다트를 던졌다")

	# 2) 결과 그림: 주식 차트·다트판이 같은 시계로 그려지고 끝나면 결과 글
	var presenter: RollPresenter = RollPresenter.new()
	root.add_child(presenter)
	presenter.instant = false
	_expect(RollPresenter.supports(&"DICE_STOCK") and RollPresenter.supports(&"DICE_DARTS"), "결과 연출 지원")
	presenter.play(&"DICE_STOCK", {"steps": 20, "details": {"event": &"limit_up", "history": [6, 7, 12], "before": 7, "price": 12, "delta": 5}})
	await create_timer(StockChartView.TOTAL_TIME + 0.2).timeout
	_expect(presenter.last_display.contains("대폭등! (Bull Market)"), "주식 차트: 대폭등 (%s)" % presenter.last_display)
	presenter.play(&"DICE_DARTS", {"steps": 15, "details": {"radius": 0.5, "angle": 0.04, "number": 5, "ring": "트리플", "multiplier": 3, "bull": false}})
	await create_timer(DartBoardView.TOTAL_TIME + 0.2).timeout
	_expect(presenter.last_display.contains("트리플") and presenter.last_display.contains("15"), "다트: 트리플 5 → 15칸 (%s)" % presenter.last_display)
	presenter.queue_free()

	# 3) 강화 망치: 카드를 내면 선택 판, [멈추기]로 확정하면 사라진다
	manager.current_turn_index = manager.player_order.find(me)
	manager.change_state(TurnManager.State.PHASE_TURN_BEGIN)
	quiet()
	state.hands[me] = [&"ACT_17"]
	manager.act(&"play_card", {"player_id": me, "card_id": &"ACT_17"})
	_board._refresh_all()
	await settle()
	var panel: Control = _board._hammer_panel
	_expect(panel.visible and (panel.find_child("HammerLevel", true, false) as Label).text.contains("+1"), "강화 망치 선택 판 (+1)")
	_expect((panel.find_child("HammerUp", true, false) as Button).text.contains("70"), "다음 강화 확률 70% 표시")
	_expect(_board._roll_button.disabled, "고르는 동안 굴리기 잠김")
	(panel.find_child("HammerStop", true, false) as Button).pressed.emit()
	await settle()
	_expect(not panel.visible and int(state.hammer_bonus.get(me, 0)) == 1, "[멈추기] → +1 확정, 판이 사라진다")
	state.hammer_bonus.erase(me)

	# 4) 현상금 WANTED 표식 / 멜론 크기 / 오이 카드 손패
	var enemy: int = manager.player_order[(manager.player_order.find(me) + 1) % manager.player_order.size()]
	var target: PlayerPawn = state.pawns_of(enemy)[0]
	target.has_left_start = true
	target.current_tile_idx = 10
	state.bounties[me] = target.entity_id
	_board._refresh_all()
	await settle()
	var view: Node2D = _board._pawn_views[target.entity_id]
	_expect(view.get_node_or_null("WantedMark") != null, "수배된 말 머리 위 WANTED")
	state.bounties.erase(me)
	_board._refresh_all()
	await settle()
	_expect(view.get_node_or_null("WantedMark") == null or view.get_node("WantedMark").is_queued_for_deletion(), "현상금이 끝나면 표식이 사라진다")
	var melon: PlayerPawn = state.pawns_of(me)[0]
	melon.evolve(GameEnums.PawnKind.ARCADE, 7)
	melon.has_left_start = true
	melon.current_tile_idx = 3
	melon.melon_size = 2
	_board._refresh_all()
	await settle()
	var token: Node2D = _board._pawn_views[melon.entity_id].find_child("Token", true, false) as Node2D
	_expect(token != null and token.scale.x > 1.3, "멜론이 커진 만큼 크게 그린다 (%.2f)" % (token.scale.x if token else 0.0))
	state.hands[me] = [&"JNK_CUKE"]
	_board._refresh_all()
	await settle()
	_expect(_board._dock.get_child_count() >= 1, "오이 카드가 손패에 보인다")

	_board._close_choice()
	MatchTelemetry.test_sender = Callable()
	var board: MainBoard = _board
	_board = null
	board.queue_free()
	await settle()
	for failure: String in _failures:
		printerr("V11_UI_FAIL ", failure)
	print("V11_UI ", checks, " assertions; ", _failures.size(), " failures")
	quit(0 if _failures.is_empty() else 1)
