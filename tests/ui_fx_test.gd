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
	await _test_presenters()
	await _test_gauge_and_lock()
	await _test_instant_flag()
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
