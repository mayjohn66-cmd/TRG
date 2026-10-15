# File: res://tests/ui_fx_test.gd
# Class: (SceneTree 스크립트, class_name 없음)
# Role: 판정 도구 연출(파워 게이지·주사위 셔플·룰렛 감속·슬롯 3릴 순차 정지·홀덤 카드 플립)과 입력 잠금을 실시간으로 검증한다. instant_roll_for_test 스킵 플래그도 확인한다
extends SceneTree

var _board: MainBoard = null
var _frames: int = 0
var _started: bool = false
var _failures: Array[String] = []


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		var scene: PackedScene = load("res://scenes/main_board.tscn")
		_board = scene.instantiate()
		root.add_child(_board)
		_board.manager.step_delay_sec = 0.0
		return false
	if _frames == 3 and not _started:
		_started = true
		_run()
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _run() -> void:
	_board._on_draft_auto_pressed()
	for i: int in 4:
		await process_frame
	await _test_mode_toggle()
	# 이후 연출·게이지 테스트는 직접 조작하므로 4P 수동 조작 모드로 진행한다 (봇 호흡은 마지막에 따로 검증)
	_board.ai_mode = false
	_board._bot.set_enabled(false)
	_board._refresh_mode_toggle()
	_board._announcer.cancel()  # 드래프트가 띄운 알림은 비우고 시작한다
	await _test_presenters()
	_board._announcer.cancel()
	await _test_gauge_and_lock()
	await _test_instant_flag()
	await _test_announcer()
	await _test_hud_overhaul()
	await _test_bot_pacing()
	if _failures.is_empty():
		print("UI_FX_OK")
		quit(0)
	else:
		for message: String in _failures:
			printerr("UI_FX_FAIL: " + message)
		quit(1)


## 연출 하나를 시작해 끝날 때까지 프레임마다 sampler를 호출한다. 걸린 실제 시간을 반환한다.
func _play(tool_id: StringName, result: Dictionary, sampler: Callable = Callable()) -> float:
	var presenter: RollPresenter = _board._presenter
	presenter.instant = false
	var started: float = _now()
	presenter.play(tool_id, result, 0.8)
	while presenter.active:
		if sampler.is_valid():
			sampler.call(_now() - started)
		await process_frame
	return _now() - started


func _test_presenters() -> void:
	var presenter: RollPresenter = _board._presenter
	# 기본 주사위: 0.5초 셔플 + 펀치, 최종 눈금이 찍힌다
	var elapsed: float = await _play(&"D6", {"tool_id": &"D6", "steps": 4, "details": {}})
	_expect(elapsed >= 0.55 and elapsed < 2.5, "주사위 연출 시간 (%.2f초)" % elapsed)
	_expect(presenter.last_display == "4", "주사위 최종 눈금이 엔진 결과와 같아야 한다 (%s)" % presenter.last_display)
	# 윷
	elapsed = await _play(&"YUT", {"tool_id": &"YUT", "steps": 3, "details": {"face": 3}})
	_expect(elapsed >= 0.55 and presenter.last_display == "걸", "윷 연출 (%.2f초, %s)" % [elapsed, presenter.last_display])
	# 인생게임 룰렛: 1.2초 EASE_OUT 감속 - 초반이 후반보다 훨씬 빠르게 돈다
	var samples: Array[Vector2] = []
	var sample_roulette: Callable = func(t: float) -> void:
		if presenter._wheel != null:
			samples.append(Vector2(t, presenter._wheel.angle))
	elapsed = await _play(&"LIFE_ROULETTE", {"tool_id": &"LIFE_ROULETTE", "steps": 7, "details": {"face": 7}}, sample_roulette)
	_expect(elapsed >= 1.2 and elapsed < 3.0, "룰렛 연출 시간 (%.2f초)" % elapsed)
	_expect(presenter.last_display == "7", "룰렛 최종 눈금 (%s)" % presenter.last_display)
	var early: float = _angle_between(samples, 0.0, 0.3)
	var late: float = _angle_between(samples, 0.9, 1.2)
	_expect(early > late * 3.0 and late >= 0.0, "룰렛은 감속해야 한다 (초반 %.2f > 후반 %.2f)" % [early, late])
	# 777 슬롯: 0.4 -> 0.8 -> 1.2초에 릴이 차례로 멈춘다
	var stop_times: Array[float] = [-1.0, -1.0, -1.0]
	var sample_slot: Callable = func(t: float) -> void:
		for index: int in 3:
			if stop_times[index] < 0.0 and presenter._reel_stopped[index]:
				stop_times[index] = t
	elapsed = await _play(&"SLOT_777", {"tool_id": &"SLOT_777", "steps": 4, "details": {"reels": [1, 1, 5]}}, sample_slot)
	_expect(stop_times[0] > 0.0 and stop_times[0] < stop_times[1] and stop_times[1] < stop_times[2], "릴이 순서대로 멈춰야 한다 %s" % str(stop_times))
	_expect(absf(stop_times[0] - 0.4) < 0.2 and absf(stop_times[1] - 0.8) < 0.2 and absf(stop_times[2] - 1.2) < 0.2, "릴 정지 간격 0.4/0.8/1.2초 %s" % str(stop_times))
	_expect(presenter.last_display == "레몬|레몬|7", "슬롯 최종 심볼 (%s)" % presenter.last_display)
	# 홀덤: 카드 5장이 0.15초 간격으로 한 장씩 뒤집힌다
	var flip_times: Array[float] = [-1.0, -1.0, -1.0, -1.0, -1.0]
	var cards: Array = [51, 38, 0, 12, 25]
	var sample_cards: Callable = func(t: float) -> void:
		for index: int in 5:
			if flip_times[index] < 0.0 and presenter._card_flipped.size() == 5 and presenter._card_flipped[index]:
				flip_times[index] = t
	elapsed = await _play(&"HOLDEM", {"tool_id": &"HOLDEM", "steps": 1, "details": {"cards": cards, "hand": &"high_card"}}, sample_cards)
	var increasing: bool = true
	for index: int in range(1, 5):
		increasing = increasing and flip_times[index] > flip_times[index - 1]
	_expect(increasing and flip_times[0] >= 0.0, "카드가 순서대로 뒤집혀야 한다 %s" % str(flip_times))
	_expect(absf((flip_times[4] - flip_times[0]) - 0.6) < 0.2, "카드 플립 간격 0.15초 %s" % str(flip_times))
	var expected: Array[String] = []
	for card: int in cards:
		expected.append(RollPresenter.card_text(card))
	_expect(presenter.last_display == " ".join(PackedStringArray(expected)), "홀덤 최종 카드 (%s)" % presenter.last_display)
	_expect(not presenter.visible, "연출이 끝나면 패널이 숨겨져야 한다")
	# instant: 즉시 완료
	presenter.instant = true
	var before: float = _now()
	await presenter.play(&"SLOT_777", {"tool_id": &"SLOT_777", "steps": 1, "details": {"reels": [0, 1, 2]}}, 0.5)
	_expect(_now() - before < 0.1 and presenter.last_display == "체리|레몬|종", "instant면 연출을 건너뛴다")
	presenter.instant = false


func _angle_between(samples: Array[Vector2], from_time: float, to_time: float) -> float:
	var first: float = -1.0
	var last: float = -1.0
	for sample: Vector2 in samples:
		if sample.x >= from_time and first < 0.0:
			first = sample.y
		if sample.x <= to_time:
			last = sample.y
	return last - first if first >= 0.0 else 0.0


## 굴림 버튼을 꾹 누르면 게이지가 왕복하고, 떼면 연출이 돌며 그동안 입력이 잠기고, 끝나면 결과가 공개된다.
func _test_gauge_and_lock() -> void:
	var manager: TurnManager = _board.manager
	_board.instant_roll_for_test = false
	manager.state.tools[manager.current_player_id()] = ToolRegistry.create(&"D6")
	_board._refresh_all()
	var rolled: Array[Dictionary] = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void:
		if kind == &"roll_resolved":
			rolled.append(data))
	_expect(not _board._roll_button.disabled, "턴 시작에 굴림 버튼이 활성이어야 한다")
	_board._roll_button.button_down.emit()
	_expect(_board._charging and _board._power_bar.visible, "버튼을 누르면 파워 게이지가 보인다")
	var low: float = 100.0
	var high: float = 0.0
	var started: float = _now()
	while _now() - started < 1.4:
		await process_frame
		low = minf(low, _board._power_bar.value)
		high = maxf(high, _board._power_bar.value)
	_expect(low < 30.0 and high > 70.0, "게이지가 0~100%%를 왕복해야 한다 (%.0f ~ %.0f)" % [low, high])
	var power_at_release: float = _board._charge_value
	_board._roll_button.pressed.emit()  # 손을 뗀 순간
	_expect(not _board._charging and not _board._power_bar.visible, "손을 떼면 게이지가 사라진다")
	_expect(absf(_board._pending_power - power_at_release) < 0.01, "손을 뗀 순간의 파워가 연출에 전달된다")
	_expect(_board._fx_busy and _board._presenter.active, "굴림 연출이 재생 중이어야 한다")
	_expect(_board._roll_button.disabled, "연출 중에는 굴림 버튼이 잠긴다")
	for button: Button in _board._pawn_buttons:
		_expect(button.disabled, "연출 중에는 말 선택 버튼이 잠긴다")
	_expect(rolled.size() == 1, "엔진은 이미 결과를 확정했다")
	var wait_start: float = _now()
	while _board._fx_busy and _now() - wait_start < 4.0:
		await process_frame
	_expect(not _board._fx_busy, "연출이 끝나면 입력 잠금이 풀린다")
	_expect(_board._presenter.last_display == str(int((rolled[0]["result"] as Dictionary)["steps"])), "연출의 최종 눈금이 엔진 결과와 같아야 한다 (%s)" % _board._presenter.last_display)
	_expect(_board._center_banner.visible, "연출 뒤 중앙 결과 배너가 뜬다")
	# 키보드: R을 누르고 있다가 떼면 굴린다
	_board.manager.force_timeout()
	for i: int in 3:
		await process_frame
	var guard: int = 0
	while manager.current_state != TurnManager.State.PHASE_TURN_BEGIN and not manager.is_game_over and guard < 200:
		guard += 1
		manager.force_timeout()
		await process_frame
		await process_frame


func _test_instant_flag() -> void:
	var manager: TurnManager = _board.manager
	_board.instant_roll_for_test = true
	manager.state.tools[manager.current_player_id()] = ToolRegistry.create(&"D6")
	_board._refresh_all()
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.pressed = true
	_board._unhandled_key_input(key)
	_expect(_board._charging and _board._charge_by_key, "R 키를 누르면 충전이 시작된다")
	_expect(not _board._power_bar.visible, "instant 모드에서는 게이지를 보이지 않는다")
	var release := InputEventKey.new()
	release.keycode = KEY_R
	release.pressed = false
	_board._unhandled_key_input(release)
	_expect(not _board._fx_busy, "instant 모드는 연출 대기 없이 즉시 결과를 공개한다")
	_expect(manager.current_state != TurnManager.State.PHASE_TURN_BEGIN, "키를 떼면 굴림이 확정된다")


## 기본 모드는 [1P vs 3AI 봇]이고, 토글로 언제든 [4P 수동 조작]으로 바꿀 수 있다.
func _test_mode_toggle() -> void:
	_expect(_board.ai_mode, "기본 모드는 1P vs 3AI 봇이어야 한다")
	_expect(_board._mode_toggle.text == "[모드: 1P vs 3AI 봇]", "기본 토글 문구 (%s)" % _board._mode_toggle.text)
	_expect(_board._bot.enabled, "기본으로 봇이 켜져 있다")
	_board._mode_toggle.pressed.emit()
	_expect(not _board.ai_mode and not _board._bot.enabled and _board._mode_toggle.text == "[모드: 4P 수동 조작]", "토글하면 4P 수동 조작")
	_board._mode_toggle.pressed.emit()
	_expect(_board.ai_mode and _board._bot.enabled, "다시 토글하면 AI 대전")


## 중앙 이벤트 알림: 대기열 순서대로 한 건씩 뜨고, 떠 있는 동안 입력이 잠기며, 클릭(skip)으로 넘어가고, instant면 건너뛴다.
func _test_announcer() -> void:
	_board.instant_roll_for_test = false
	var announcer: EventAnnouncer = _board._announcer
	announcer.cancel()
	announcer.history.clear()
	_board._announce("테스트", "첫 알림", "", Color.WHITE, null, 0.5)
	_board._announce("테스트", "둘째 알림", "", Color.WHITE, null, 0.5)
	_expect(announcer.active and announcer.visible and _board._ui_busy(), "알림이 뜨면 입력이 잠긴다")
	_expect(_board._roll_button.disabled, "알림 중 굴리기 버튼 비활성")
	announcer.skip_current()
	await process_frame
	await process_frame
	_expect(announcer.active, "첫 알림을 넘겨도 둘째 알림이 남아 있다")
	announcer.skip_current()
	await process_frame
	await process_frame
	_expect(not announcer.active and not announcer.visible and not _board._ui_busy(), "대기열이 비면 잠금 해제")
	announcer.history.clear()
	_board.instant_roll_for_test = true
	_board._announce("테스트", "건너뜀", "", Color.WHITE, null, 0.5)
	_expect(not announcer.active, "instant면 알림을 띄우지 않는다")
	_board.instant_roll_for_test = false


## 좌석 상대 매핑·판정 도구 전광판·기물 독과 0.35초 호버 툴팁·카드 클릭 확대·드래그 앤 드롭 발동.
func _test_hud_overhaul() -> void:
	var manager: TurnManager = _board.manager
	_board.instant_roll_for_test = true
	_board._announcer.cancel()
	_board._cancel_card_drag()
	# 1) 좌석: 로컬 플레이어 기준 우하단 -> 우상단 -> 좌상단 -> 좌하단
	_board.local_player_id = 3
	_expect([_board.get_player_for_corner(0), _board.get_player_for_corner(1), _board.get_player_for_corner(2), _board.get_player_for_corner(3)] == [3, 4, 1, 2], "P3 화면의 좌석 매핑")
	_board.local_player_id = 1
	_expect([_board.get_player_for_corner(0), _board.get_player_for_corner(1), _board.get_player_for_corner(2), _board.get_player_for_corner(3)] == [1, 2, 3, 4], "P1 화면의 좌석 매핑")
	var p1_rect: Rect2 = (_board._profiles[1]["panel"] as Control).get_global_rect()
	_expect(p1_rect.get_center().x > 683.0 and p1_rect.get_center().y > 384.0, "P1 프로필은 우측 하단")
	# 2) 전광판
	var guard: int = 0
	while not (manager.current_state == TurnManager.State.PHASE_TURN_BEGIN) and guard < 400:
		guard += 1
		manager.force_timeout()
		await process_frame
	var current: int = manager.current_player_id()
	manager.state.tools[current] = ToolRegistry.create(&"HOLDEM")
	_board._refresh_controls()
	_expect(_board._tool_rows.size() == 6, "홀덤 전광판은 족보 6줄")
	_board._highlight_tool_result({"tool_id": &"HOLDEM", "steps": 5, "reroll": false, "details": {"hand": &"two_pair"}})
	_expect(_board._tool_highlight == "two_pair" and _board._tool_result_label.text == "투페어 -> 5칸 전진!", "투페어 줄에 불이 들어오고 결과가 뜬다 (%s)" % _board._tool_result_label.text)
	manager.state.tools[current] = ToolRegistry.create(&"HALLI_GALLI")
	_board._refresh_controls()
	_expect(str((_board._tool_rows["bonus"]["label"] as Label).text).contains("누적 중"), "할리갈리 전광판에 보너스 누적 줄")
	manager.state.tools[current] = ToolRegistry.create(&"D6")
	_board._refresh_controls()
	# 3) 기물 독 + 호버 툴팁
	_expect(_board._pawn_buttons.size() == 4 and (_board._pawn_buttons[0] as Button).size.x >= 68.0 and (_board._pawn_buttons[0] as Button).size.y >= 76.0, "기물 슬롯은 최소 68x76")
	_board._on_pawn_slot_hover(0)
	for i: int in 5:
		await process_frame
	_expect(not _board._tip_panel.visible, "0.35초 전에는 툴팁이 없다")
	var wait_start: float = _now()
	while _now() - wait_start < 0.6:
		await process_frame
	_expect(_board._tip_panel.visible and _board._tip_title.text != "" and _board._tip_ability.text != "" and _board._tip_right.get_child_count() >= 2, "0.35초 뒤 두 칸 툴팁이 뜬다 (%s)" % _board._tip_title.text)
	# 세트 효과 강조: 체스 2세트를 만들면 2세트 줄이 [작동 중]으로 켜지고 4세트 줄은 꺼져 있다
	var chess_ids: Array[int] = []
	for pawn: PlayerPawn in manager.state.pawns:
		if pawn.kind == GameEnums.PawnKind.CHESS and pawn.owner_id == 3:
			chess_ids.append(pawn.entity_id)
	for pawn: PlayerPawn in manager.state.basic_pawns_of(3):
		if chess_ids.size() >= 2:
			break
		manager.state.evolve_pawn(pawn, GameEnums.PawnKind.CHESS)
		chess_ids.append(pawn.entity_id)
	_board._fill_pawn_tip(chess_ids[0])
	var tip_text: String = ""
	for row: Node in _board._tip_right.get_children():
		for label: Node in row.find_children("*", "Label", true, false):
			tip_text += (label as Label).text + "|"
	_expect(tip_text.contains("[작동 중] 2세트: 캐슬링") and not tip_text.contains("[작동 중] 4세트"), "도달한 세트 단계만 강조된다 (%s)" % tip_text)
	_board._on_pawn_slot_unhover(_board._pawn_buttons[0])
	_expect(not _board._tip_panel.visible, "커서를 치우면 즉시 사라진다")
	# 4) 클릭 확대 (남의 턴에도 가능)
	var holder: int = current
	(manager.state.hands[holder] as Array).clear()
	manager.state.give_card(holder, &"ACT_01")
	manager.state.give_card(holder, &"TRP_01")
	_board._refresh_hands()
	_board._card_press(holder, &"ACT_01", Vector2(700, 700), Vector2(700, 640))
	_board._card_release(Vector2(701, 700))
	_expect(_board._zoom_view != null and _board._zoom_view.size.x >= 240.0 and _board._zoom_view.size.y >= 340.0 and _board._zoom_view.size.y < 400.0, "클릭하면 약 240x340으로 확대 (%s)" % str(_board._zoom_view.size if _board._zoom_view != null else Vector2.ZERO))
	_board._card_press(holder, &"ACT_01", Vector2(700, 700), Vector2(700, 640))
	_board._card_release(Vector2(701, 700))
	await process_frame
	_expect(_board._zoom_view == null, "다시 클릭하면 닫힌다 (토글)")
	# 5) 드래그: 잘못된 곳에 놓으면 카드가 남는다
	_expect(manager.current_state == TurnManager.State.PHASE_TURN_BEGIN and not _board._ui_busy(), "드래그 테스트 전제: 턴 시작, 입력 가능")
	_board._card_press(holder, &"TRP_01", Vector2(700, 700), Vector2(700, 640))
	_board._card_move(Vector2(720, 600))
	_expect(_board._drag_active and _board._drop_zone.visible, "끄는 동안 드롭 존이 보인다")
	_board._card_release(Vector2(100, 300))
	await process_frame
	_expect(not _board._drop_zone.visible and (manager.state.hands[holder] as Array).has(&"TRP_01"), "보드 밖에 놓으면 발동하지 않고 손패에 남는다")
	# 타일 지정형: 유효 타일 위에 직접 드롭
	var card: BaseCard = CardRegistry.get_card(&"TRP_01")
	var target: int = -1
	for index: int in GameEnums.TILE_COUNT:
		if card.can_play(manager.state, holder, {"tile": index}):
			target = index
			break
	_board._card_press(holder, &"TRP_01", Vector2(700, 700), Vector2(700, 640))
	_board._card_move(Vector2(720, 600))
	_board._card_release(_board._tile_center(target))
	await process_frame
	_expect(manager.state.board.get_tile(target).has_attachment(&"TRP_01") and not (manager.state.hands[holder] as Array).has(&"TRP_01"), "타일 위에 떨어뜨리면 즉시 설치된다")
	# 즉발 카드는 보드판 어디든 놓으면 발동
	_board._card_press(holder, &"ACT_01", Vector2(700, 700), Vector2(700, 640))
	_board._card_move(Vector2(720, 600))
	_board._card_release(Vector2(680, 300))
	await process_frame
	_expect(not (manager.state.hands[holder] as Array).has(&"ACT_01"), "즉발 카드를 보드에 놓으면 발동")
	manager.turn_direction = 1  # 우노 리버스가 뒤집은 진행 방향·역주행을 되돌려 다음 테스트에 영향이 없게 한다
	manager.state.reverse_move_rounds_left = 0
	_board.instant_roll_for_test = false


## 봇 턴의 실제 연출 호흡: 턴 시작 0.5초 + 굴리기 직전 0.3초, 굴림 연출 뒤 결과 확인 0.6초 + 이동 선택 0.5초.
func _test_bot_pacing() -> void:
	var manager: TurnManager = _board.manager
	_board.instant_roll_for_test = false
	var guard: int = 0
	while not (manager.current_state == TurnManager.State.PHASE_TURN_BEGIN and manager.current_player_id() == 1) and guard < 600:
		guard += 1
		manager.force_timeout()
		await process_frame
	guard = 0
	while _board._fx_busy and guard < 600:
		guard += 1
		await process_frame
	_board.ai_mode = true
	_board._bot.set_enabled(true)
	_board._refresh_mode_toggle()
	manager.advance_to_next_player()  # P2(봇)의 턴 시작
	_expect(manager.current_player_id() == 2, "P2 차례")
	manager.state.tools[2] = ToolRegistry.create(&"D6")
	for player_id: int in [1, 2, 3, 4]:
		(manager.state.hands[player_id] as Array).clear()  # 카드가 없어야 개입 창·함정 사용 없이 순수한 호흡만 잴 수 있다
	_board._refresh_all()
	var events: Dictionary = {}
	var start: float = _now()
	manager.event_received.connect(func(kind: StringName, _data: Dictionary) -> void:
		if (kind == &"roll_resolved" or kind == &"move_resolved") and not events.has(kind):
			events[kind] = _now())
	var wait_start: float = _now()
	while not events.has(&"move_resolved") and _now() - wait_start < 12.0:
		await process_frame
	_expect(events.has(&"roll_resolved") and events.has(&"move_resolved"), "봇이 굴리고 말을 옮겼다 %s" % str(events))
	if events.has(&"roll_resolved") and events.has(&"move_resolved"):
		var roll_after: float = float(events[&"roll_resolved"]) - start
		var move_after: float = float(events[&"move_resolved"]) - float(events[&"roll_resolved"])
		_expect(roll_after >= 0.75, "봇은 턴 시작 후 0.5초 판단 + 0.3초 뒤에 굴린다 (%.2f초)" % roll_after)
		_expect(move_after >= 1.8, "굴림 연출(약 0.9초) + 결과 확인 0.6초 + 선택 0.5초 뒤에 말을 옮긴다 (%.2f초)" % move_after)
