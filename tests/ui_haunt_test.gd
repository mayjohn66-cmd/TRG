## 방해령 삼총사·허리케인 포스!! 화면: 확대 보기 하단의 작은 힌트, 베루·사리·메죵 대상 고르기, 법전 진행도 표기,
## 허리케인 승리 연출(모든 기물이 날아갔다가 제자리로 돌아온다, 건너뛰기 포함), 팝아트 결과 1쪽(좌상단 HURRICANE / FORCE!!, 하단 배너 달성 사유).
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
	_board.ai_mode = false


func _entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for rank: int in range(1, 5):
		var face := ColorRect.new()
		face.color = Color.BLACK
		out.append({"rank": rank, "name": "닉네임%d" % rank, "color": Color("ff6b6b"), "avatar": face, "art": null})
	return out


func _choice_buttons() -> Array[Button]:
	var found: Array[Button] = []
	if _board._choice_overlay == null:
		return found
	for node: Node in _board._choice_overlay.find_children("*", "Button", true, false):
		found.append(node as Button)
	return found


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
	var foe: int = 2 if me != 2 else 1
	for pawn: PlayerPawn in state.pawns:
		pawn.reset_to_start()
	var foe_pawn: PlayerPawn = state.pawns_of(foe)[0]
	foe_pawn.has_left_start = true
	foe_pawn.current_tile_idx = 12
	var mine: PlayerPawn = state.pawns_of(me)[0]
	mine.has_left_start = true
	mine.current_tile_idx = 5
	state.hands[me] = [&"ACT_18", &"ACT_19", &"ACT_20", &"ACT_17"]
	_board._refresh_all()
	await settle()

	# 1) 확대 보기: 방해령 카드에만 작은 힌트가 붙는다
	_board._open_zoom(me, &"ACT_18")
	await settle()
	var hint: Label = _board._zoom_view.find_child("CardHint", true, false) as Label
	_expect(hint != null and hint.text.contains("베루·사리·메죵을 모두 손패에 모으면 무언가 일어날지도...?"), "방해령 카드 확대 보기 하단에 힌트 문구")
	if hint != null:
		var base_px: int = (_board._zoom_view.find_child("CardTiming", true, false) as Label).get_theme_font_size("font_size")
		_expect(hint.get_theme_font_size("font_size") < base_px, "힌트는 본문보다 작은 글씨 (%d < %d)" % [hint.get_theme_font_size("font_size"), base_px])
	_board._close_zoom()
	_board._open_zoom(me, &"ACT_17")
	await settle()
	_expect(_board._zoom_view.find_child("CardHint", true, false) == null, "다른 카드에는 힌트가 없다")
	_board._close_zoom()

	# 2) 베루: 카드를 누르면 뒤로 밀 적 말 목록 → 고르면 뒤로 1칸
	_board._on_card_pressed(me, &"ACT_18")
	await settle()
	var buttons: Array[Button] = _choice_buttons()
	_expect(buttons.size() >= 1 and buttons.any(func(button: Button) -> bool: return button.text.contains("12번 칸")), "적 말 선택지에 위치가 보인다 (%d개)" % buttons.size())
	for button: Button in buttons:
		if button.text.contains("12번 칸"):
			button.pressed.emit()
			break
	await settle(6)
	_expect(foe_pawn.current_tile_idx == 11, "베루: 적 말이 12번 → 11번 칸")
	manager.change_state(TurnManager.State.PHASE_TURN_BEGIN)
	manager._card_played_this_turn = false
	quiet()

	# 3) 사리: 내 말 선택 → 앞으로 1칸
	_board._on_card_pressed(me, &"ACT_19")
	await settle()
	buttons = _choice_buttons()
	_expect(buttons.size() >= 1 and buttons.any(func(button: Button) -> bool: return button.text.contains("5번 칸")), "내 말 선택지")
	for button: Button in buttons:
		if button.text.contains("5번 칸"):
			button.pressed.emit()
			break
	await settle(6)
	_expect(mine.current_tile_idx == 6, "사리: 내 말이 5번 → 6번 칸")
	manager.change_state(TurnManager.State.PHASE_TURN_BEGIN)
	manager._card_played_this_turn = false
	quiet()

	# 4) 메죵: 상대 선택 → 눈금 -1이 걸린다
	_board._on_card_pressed(me, &"ACT_20")
	await settle()
	buttons = _choice_buttons()
	_expect(buttons.size() >= 1, "메죵 대상 선택지")
	if not buttons.is_empty():
		buttons[0].pressed.emit()
	await settle(6)
	_expect(state.roll_penalty.values().any(func(amount: Variant) -> bool: return int(amount) == 1), "메죵: 상대에게 다음 눈금 -1")
	_board._close_choice()

	# 5) 법전 진행도: 손패의 방해령 종류 수 (0/3 ~ 3/3)가 실시간으로 법전에 보인다
	state.rulebook.enqueue_law(LawRegistry.create("LAW_09"))
	state.hands[me] = [&"ACT_18"]
	_board._refresh_all()
	await settle()
	var law: VictoryLaw = LawRegistry.create("LAW_09") as VictoryLaw
	_expect(SpecialVictory.shown_progress(state, law, me) == 1, "손패 베루 1장 → 1/3")
	state.hands[me] = [&"ACT_18", &"ACT_19", &"ACT_20"]
	_board._refresh_all()
	await settle()
	_expect(SpecialVictory.shown_progress(state, law, me) == 3 and law.goal() == 3, "세 종류 → 3/3")
	_expect(MainBoard.law_win_reason("LAW_09", 3) == "베루·사리·메죵 3종 손패 집결 · 대폭풍으로 보드 초토화!", "달성 사유 문구")

	# 6) 허리케인 승리 연출: 모든 기물이 날아갔다가 폭풍이 걷히면 원래 자리로 돌아온다
	for pawn: PlayerPawn in state.pawns:
		pawn.reset_to_start()
	var spots: Array[int] = [3, 7, 11, 15, 19, 23]
	var placed: Array[PlayerPawn] = []
	for index: int in spots.size():
		var pawn: PlayerPawn = state.pawns[index]
		pawn.has_left_start = true
		pawn.current_tile_idx = spots[index]
		placed.append(pawn)
	_board._refresh_all()
	await settle()
	var homes: Dictionary = {}
	for pawn: PlayerPawn in placed:
		var view: Node2D = _board._pawn_views[pawn.entity_id]
		homes[pawn.entity_id] = {"pos": _board._pawn_position(pawn), "scale": Vector2.ONE * _board._depth_scale(_board.tile_norm(pawn.current_tile_idx).y), "rot": 0.0, "alpha": 1.0, "visible": pawn.carrier == null and not pawn.is_finished and pawn.has_left_start}
		view.visible = true  # 보드 위 기물로 보이게 (새로고침의 낙하 연출은 기다리지 않는다)
	_board.instant_roll_for_test = false  # 연출 켬
	_board._fx_busy = false
	var started: int = Time.get_ticks_msec()
	_board._play_hurricane_force(me)
	await settle(2)
	var layer: Node = _board.find_child("HurricaneLayer", true, false)
	var storm: HurricaneStorm = layer.find_child("HurricaneStorm", true, false) as HurricaneStorm if layer != null else null
	_expect(is_instance_valid(storm) and storm.active, "보드 위에 허리케인이 몰아친다")
	if is_instance_valid(storm):
		_expect(storm.center.distance_to(_board.get_global_transform_with_canvas() * _board._board_center()) < 24.0, "폭풍의 눈은 보드 중앙 (화면 흔들림 오차 안)")
	# 절정 직후: 기물이 모두 원래 자리에서 멀리 날아가 있다
	var flung_far: bool = false
	var frames: int = 0
	while frames < 600 and is_instance_valid(storm) and storm.active:
		frames += 1
		await process_frame
		if is_instance_valid(storm) and storm._time_view >= HurricaneStorm.CLIMAX_AT + 0.74 and storm._time_view < HurricaneStorm.CLEAR_AT and not flung_far:
			var far: int = 0
			for pawn: PlayerPawn in placed:
				var moved: Node2D = _board._pawn_views[pawn.entity_id]
				if moved.position.distance_to((homes[pawn.entity_id] as Dictionary)["pos"]) > 250.0 or moved.modulate.a < 0.5:
					far += 1
			flung_far = far == placed.size()
	_expect(flung_far, "폭풍 한가운데에서 보드 위 모든 기물(%d개)이 날아가 있다" % placed.size())
	await create_timer(1.2).timeout
	var restored: bool = true
	for pawn: PlayerPawn in placed:
		var back: Node2D = _board._pawn_views[pawn.entity_id]
		var home: Dictionary = homes[pawn.entity_id]
		if not (back.position.distance_to(home["pos"]) < 1.5 and back.scale.is_equal_approx(home["scale"]) and is_equal_approx(back.rotation, home["rot"]) and is_equal_approx(back.modulate.a, home["alpha"]) and back.visible == home["visible"]):
			print("DBG restore mismatch ", pawn.entity_id, " pos ", back.position, " vs ", home["pos"], " scale ", back.scale, " vs ", home["scale"], " rot ", back.rotation, " vs ", home["rot"], " a ", back.modulate.a, " vs ", home["alpha"], " vis ", back.visible, " vs ", home["visible"])
		restored = restored and back.position.distance_to(home["pos"]) < 1.5 and back.scale.is_equal_approx(home["scale"]) and is_equal_approx(back.rotation, home["rot"]) and is_equal_approx(back.modulate.a, home["alpha"]) and back.visible == home["visible"]
	_expect(restored, "폭풍이 걷히면 모든 기물이 원래 모습으로 돌아온다")
	_expect(_board.find_child("HurricaneLayer", true, false) == null or _board.find_child("HurricaneLayer", true, false).is_queued_for_deletion(), "연출이 끝나면 폭풍 층이 치워진다")
	_expect(Time.get_ticks_msec() - started < 6000, "연출은 6초 안에 끝난다")
	# 건너뛰기: 클릭하면 바로 끝나고 기물은 원래 모습이다
	_board._play_hurricane_force(me)
	await settle(3)
	var skip_layer: Node = _board.find_child("HurricaneLayer", true, false)
	var skip_storm: HurricaneStorm = skip_layer.find_child("HurricaneStorm", true, false) as HurricaneStorm if skip_layer != null else null
	if is_instance_valid(skip_storm):
		await create_timer(0.9).timeout
		skip_storm.skip()
	await settle(6)
	var skip_restored: bool = true
	for pawn: PlayerPawn in placed:
		var again: Node2D = _board._pawn_views[pawn.entity_id]
		skip_restored = skip_restored and again.position.distance_to((homes[pawn.entity_id] as Dictionary)["pos"]) < 1.5 and is_equal_approx(again.modulate.a, float((homes[pawn.entity_id] as Dictionary)["alpha"]))
	_expect(skip_restored, "중간에 건너뛰어도 기물은 원래 모습으로 돌아온다")
	_board.instant_roll_for_test = true

	# 7) 팝아트 결과 1쪽: 좌상단 HURRICANE / FORCE!!, 하단 배너에 법전 이름 + 따옴표 달성 사유
	var page := ResultComicPage.new()
	root.add_child(page)
	page.setup(_entries(), "방해령 허리케인 포스!!", "\"달성 사유: 베루·사리·메죵 3종 손패 집결 · 대폭풍으로 보드 초토화!\"", "HURRICANE\nFORCE!!")
	await settle()
	_expect(page.popart_label != null and page.popart_label.text == "HURRICANE\nFORCE!!", "팝아트 타이틀 HURRICANE / FORCE!!")
	_expect(page.victory_label.text == "방해령 허리케인 포스!!" and page.condition_label.text == "\"달성 사유: 베루·사리·메죵 3종 손패 집결 · 대폭풍으로 보드 초토화!\"", "하단 배너: 법전 이름 + 따옴표 달성 사유 (괄호로 다시 감싸지 않는다)")
	if page.popart_label != null:
		var view_size: Vector2 = page.size if page.size.x > 2.0 else Vector2(1366, 768)
		_expect(page.popart_label.position.x < view_size.x * 0.2 and page.popart_label.position.y < view_size.y * 0.3, "타이틀은 좌상단 (%s)" % page.popart_label.position)
		page.set_time(ResultComicPage.STAMP_AT - 0.1)
		_expect(page.popart_label.modulate.a < 0.5, "1st 도장보다 먼저 나오지 않는다")
		page.set_time(ResultComicPage.DURATION)
		_expect(page.popart_label.modulate.a > 0.99 and page.popart_label.scale.is_equal_approx(Vector2.ONE), "도장 뒤에 쾅 찍혀 제자리")
	var plain := ResultComicPage.new()
	root.add_child(plain)
	plain.setup(_entries(), "카이지의 한방 역전법", "한 턴에 18칸 폭발 전진 성공!")
	await settle()
	_expect(plain.popart_label == null and plain.condition_label.text.begins_with("("), "다른 법전은 기존처럼 괄호 조건, 팝아트 타이틀 없음")
	page.queue_free()
	plain.queue_free()
	# 주문서: 메인 보드에서 LAW_09 승리 결과 문구가 팝아트로 이어진다
	state.rank_reasons[me] = &"LAW_09"
	_board._law_win_detail[me] = {"law": "LAW_09", "value": 3, "tiles": []}
	var texts: Array[String] = _board.result_comic_texts(me)
	_expect(texts[0] == "방해령 허리케인 포스!!" and texts[1] == "\"달성 사유: 베루·사리·메죵 3종 손패 집결 · 대폭풍으로 보드 초토화!\"", "결과 1쪽 문구가 LAW_09로 채워진다 (%s)" % str(texts))
	_expect(MainBoard.POPART_TITLES.get("LAW_09", "") == "HURRICANE\nFORCE!!", "LAW_09 팝아트 타이틀 표")
	state.rank_reasons.erase(me)

	_board._close_choice()
	MatchTelemetry.test_sender = Callable()
	var board: MainBoard = _board
	_board = null
	board.queue_free()
	await settle()
	for failure: String in _failures:
		printerr("HAUNT_UI_FAIL ", failure)
	print("HAUNT_UI ", checks, " assertions; ", _failures.size(), " failures")
	quit(0 if _failures.is_empty() else 1)
