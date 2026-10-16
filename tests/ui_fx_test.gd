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
	await _test_game_menu()
	await _test_view_modes()
	await _test_avatar_seats()
	# 이후 연출·게이지 테스트는 직접 조작하므로 4P 수동 조작 모드로 진행한다 (봇 호흡은 마지막에 따로 검증)
	_board.ai_mode = false
	_board._bot.set_enabled(false)
	_board._refresh_mode_toggle()
	_board._announcer.cancel()  # 드래프트가 띄운 알림은 비우고 시작한다
	_board.pacing_enabled = false  # 아래 테스트들은 연출 길이를 직접 재므로 [N 차례] 알림·이동 뒤 멈춤은 끈다 (따로 검사한다)
	# 메뉴의 속도/호흡 설정은 _apply_pace()로 이동 간격도 바꾸므로,
	# _process()에서 지정했던 테스트용 즉시 이동 조건을 다시 복원한다.
	_board.manager.step_delay_sec = 0.0
	await _test_presenters()
	_board._announcer.cancel()
	await _test_gauge_and_lock()
	await _test_instant_flag()
	await _test_announcer()
	await _test_aspect_layout()
	await _test_roll_pad()
	await _test_hud_overhaul()
	await _test_bot_pacing()
	await _test_action_beats()
	await _test_tool_cards_fit()
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
	# 화투: 새로 뒤집는 패만 뒤집히고 이미 나온 패는 앞면으로 놓인다 (고! 한 번)
	var hwatu_result: Dictionary = {"tool_id": &"DICE_HWATU", "steps": 7, "details": {"cards": [1, 5, 40], "new_cards": [40], "hand": &"kkeut", "label": "3끗", "go_count": 1, "go_type": &"gwang", "bonus": 5, "accumulated": 7}}
	elapsed = await _play(&"DICE_HWATU", hwatu_result)
	_expect(elapsed >= 0.4 and elapsed < 3.0, "화투 연출 시간 (%.2f초)" % elapsed)
	_expect(presenter.last_display == "1월 열끗 2월 열끗 11월 광", "화투 최종 패 (%s)" % presenter.last_display)
	# 마작: 패 3개 동시 쯔모
	elapsed = await _play(&"DICE_MAHJONG", {"tool_id": &"DICE_MAHJONG", "steps": 5, "details": {"tiles": [0, 1, 2], "hand": &"shuntsu", "label": "슌쯔"}})
	_expect(elapsed >= 0.4 and elapsed < 3.0 and presenter.last_display == "1만 2만 3만", "마작 연출 (%.2f초, %s)" % [elapsed, presenter.last_display])
	# 타로: 뒷면 5장 중 한 장만 뒤집힌다
	var tarot_flips: Array[int] = []
	var sample_tarot: Callable = func(_t: float) -> void:
		var flipped: int = 0
		for flag: bool in presenter._card_flipped:
			if flag:
				flipped += 1
		if tarot_flips.is_empty() or tarot_flips.back() != flipped:
			tarot_flips.append(flipped)
	elapsed = await _play(&"DICE_TAROT", {"tool_id": &"DICE_TAROT", "steps": 6, "details": {"fate": &"chariot", "name": "VII. 전차 (The Chariot)", "flipped": 2, "fool_leap": false}}, sample_tarot)
	_expect(elapsed >= 0.4 and elapsed < 3.0 and presenter.last_display.contains("VII"), "타로 연출 (%.2f초, %s)" % [elapsed, presenter.last_display])
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
	_expect(_board._roll_button.size.x >= 120.0 and _board._roll_button.size.x == _board._roll_button.size.y, "굴리기 버튼은 큼직한 원형 (%s)" % str(_board._roll_button.size))
	_expect(not _board._select_banner.visible, "연출 중에는 말 선택 배너가 보이지 않는다")
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


## 테이블 좌석 배치와 아바타 칸: 인원·내 자리에 따라 앵커가 정해지고, 감정 반응과 에셋 슬롯이 동작한다.
func _test_avatar_seats() -> void:
	var saved_ids: Array[int] = _board._player_ids.duplicate()
	var saved_local: int = _board.local_player_id
	var cases: Array = [
		[[1, 2] as Array[int], 1, {1: &"me", 2: &"right"}],
		[[1, 2] as Array[int], 2, {2: &"me", 1: &"right"}],
		[[1, 2, 3] as Array[int], 1, {1: &"me", 2: &"right", 3: &"left"}],
		[[1, 2, 3, 4] as Array[int], 1, {1: &"me", 2: &"right", 3: &"top", 4: &"left"}],
		[[1, 2, 3, 4] as Array[int], 3, {3: &"me", 4: &"right", 1: &"top", 2: &"left"}],
		[[2, 4] as Array[int], 4, {4: &"me", 2: &"right"}],
	]
	for entry: Array in cases:
		_board._player_ids = entry[0]
		_board.local_player_id = entry[1]
		_board._compute_seats()
		for player_id: int in (entry[2] as Dictionary).keys():
			_expect(_board.seat_anchor_of(player_id) == (entry[2] as Dictionary)[player_id], "인원 %s, 내 자리 %d: P%d 앵커 %s" % [str(entry[0]), entry[1], player_id, str(_board.seat_anchor_of(player_id))])
	_board._player_ids = saved_ids
	_board.local_player_id = saved_local
	_board._compute_seats()
	# 아바타 칸: 에셋이 없으면 자리표시자, 반응하면 감정 이름이 보이고 시간이 지나면 돌아온다
	var avatar: AvatarSlot = _board._profiles[2]["avatar"]
	_expect(not avatar.has_art() and avatar.emotion == AvatarSlot.Emotion.IDLE, "에셋이 없으면 자리표시자")
	avatar.react(AvatarSlot.Emotion.ANGRY, 0.0)
	_expect(avatar.emotion == AvatarSlot.Emotion.ANGRY and avatar._caption.visible and avatar._caption.text == "분노", "자리표시자가 감정 이름을 보여 준다")
	avatar.react(AvatarSlot.Emotion.IDLE, 0.0)
	_expect(not avatar._caption.visible, "기본 표정에서는 감정 이름이 사라진다")
	# 스프라이트 시트 슬롯: 감정별 애니메이션이 재생되고 없는 감정은 idle로 대신한다
	var frames := SpriteFrames.new()
	var image := Image.create(40, 60, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	for animation: StringName in [&"idle", &"happy"]:
		if not frames.has_animation(animation):
			frames.add_animation(animation)
		frames.add_frame(animation, texture)
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	avatar.use_frames(frames)
	_expect(avatar.has_art() and avatar._sprite != null and avatar._sprite.animation == &"idle", "스프라이트 시트를 넣으면 idle이 재생된다")
	_expect(is_equal_approx(avatar._sprite.scale.y, avatar.size.y / 60.0), "스프라이트는 칸 높이에 맞춰진다")
	avatar.react(AvatarSlot.Emotion.HAPPY, 0.0)
	_expect(avatar._sprite.animation == &"happy" and not avatar._caption.visible, "happy 애니메이션 재생 (에셋이 있으면 자리표시자 글자는 숨김)")
	avatar.react(AvatarSlot.Emotion.ANGRY, 0.0)
	_expect(avatar._sprite.animation == &"idle", "없는 감정(angry)은 idle로 대신한다")
	# 정지 이미지 슬롯
	avatar.set_character(&"nonexistent_character")
	_expect(not avatar.has_art(), "없는 캐릭터는 다시 자리표시자")
	avatar.use_portrait(texture)
	_expect(avatar.has_art() and avatar._portrait != null, "정지 이미지 한 장도 쓸 수 있다")
	avatar.react(AvatarSlot.Emotion.CHEER, 0.0)
	avatar.react(AvatarSlot.Emotion.IDLE, 0.0)
	avatar.set_character(AvatarSlot.DEFAULT_CHARACTER)
	_expect(not avatar.has_art(), "기본 캐릭터 에셋이 없으면 자리표시자로 돌아간다")
	# 게임 이벤트가 아바타를 반응시킨다: 말이 잡히면 피해자는 분노, 잡은 쪽은 웃음
	var victim: PlayerPawn = _board.state.get_pawn(21)
	_board.state.pawn_sent_to_start.emit(victim.entity_id, 1)
	_expect((_board._profiles[2]["avatar"] as AvatarSlot).emotion == AvatarSlot.Emotion.ANGRY and (_board._profiles[1]["avatar"] as AvatarSlot).emotion == AvatarSlot.Emotion.HAPPY, "말이 잡히면 피해자 분노 / 잡은 쪽 웃음")
	_board.state.pawn_finished.emit(31)
	_expect((_board._profiles[3]["avatar"] as AvatarSlot).emotion == AvatarSlot.Emotion.CHEER, "완주하면 환호")
	for player_id: int in [1, 2, 3, 4]:
		(_board._profiles[player_id]["avatar"] as AvatarSlot).react(AvatarSlot.Emotion.IDLE, 0.0)


## 보드 시점: 탑뷰 <-> 기울인 탑뷰. 규칙 좌표는 그대로이고 화면 배치만 바뀐다.
func _test_view_modes() -> void:
	_expect(_board.view_mode == MainBoard.ViewMode.TOP and _board._plate.visible and not _board._board_surface.visible, "기본은 탑뷰")
	var top_centers: Array[Vector2] = []
	for index: int in 29:
		top_centers.append(_board._tile_center(index))
	var pawn_id: int = 11
	var pawn: PlayerPawn = _board.state.get_pawn(pawn_id)
	var top_pawn_position: Vector2 = _board._pawn_position(pawn)
	_board.set_view_mode(MainBoard.ViewMode.TILT)
	_expect(not _board._plate.visible and _board._board_surface.visible and _board._table_bg.visible and _board._pawn_layer.y_sort_enabled, "기울인 시점: 보드 면·테이블이 켜지고 말이 깊이순으로 그려진다")
	var far_tile: Control = _board._tile_views[8]   # 위쪽(먼 쪽) 줄
	var near_tile: Control = _board._tile_views[18]  # 아래쪽(가까운 쪽) 줄
	_expect(far_tile.scale.x < near_tile.scale.x and absf(near_tile.scale.x - 1.0) < 0.001, "먼 타일은 작고 가까운 타일은 원래 크기")
	_expect(near_tile.scale.y < near_tile.scale.x, "타일은 세로로 눌린다")
	_expect(_board._tile_center(8).y < _board._tile_center(18).y and _board._tile_center(18).y - _board._tile_center(8).y < top_centers[18].y - top_centers[8].y, "세로 간격이 압축된다")
	var tag: Label = _board._tag_labels[0]
	_expect(absf(tag.scale.y * near_tile.scale.y / near_tile.scale.x - 1.0) < 0.01, "타일 글자는 되돌려 찌그러지지 않는다")
	var all_inside: bool = true
	for a: int in 29:
		var tile_a: Control = _board._tile_views[a]
		var rect_a := Rect2(tile_a.position + tile_a.size / 2.0 - tile_a.size * tile_a.scale / 2.0, tile_a.size * tile_a.scale)
		all_inside = all_inside and Rect2(Vector2.ZERO, Vector2(1366, 768)).encloses(rect_a)
		for b: int in range(a + 1, 29):
			var tile_b: Control = _board._tile_views[b]
			var rect_b := Rect2(tile_b.position + tile_b.size / 2.0 - tile_b.size * tile_b.scale / 2.0, tile_b.size * tile_b.scale)
			_expect(not rect_a.intersects(rect_b), "기울인 시점에서 타일 %d와 %d가 겹침" % [a, b])
	_expect(all_inside, "기울인 시점의 모든 타일이 화면 안")
	_expect((_board._pawn_views[pawn_id] as Node2D).get_node("Shadow").visible, "말 그림자가 보인다")
	_expect(_board._board_edge.points.size() == 4 and _board._track_lines.size() == 3, "보드 면 4점, 경로선 3개가 다시 그려진다")
	# 경로선이 새 위치를 따라간다
	_expect(_board._track_lines[0].points[0].is_equal_approx(_board._tile_center(0)), "경로선이 투영 좌표를 따라간다")
	# 시점은 설정으로 저장된다
	_expect(GameSession.view_mode == MainBoard.ViewMode.TILT, "시점이 세션 설정에 기록된다")
	_board.set_view_mode(MainBoard.ViewMode.TOP)
	var restored: bool = true
	for index: int in 29:
		restored = restored and _board._tile_center(index).is_equal_approx(top_centers[index])
	_expect(restored and _board._plate.visible and not _board._board_surface.visible and not _board._table_bg.visible, "탑뷰로 돌아오면 모든 좌표와 받침이 그대로 돌아온다")
	_expect(_board._pawn_position(pawn).is_equal_approx(top_pawn_position) and not _board._pawn_layer.y_sort_enabled, "말 위치도 그대로")
	GameSession.view_mode = MainBoard.ViewMode.TOP


## 상단 UI는 [메뉴] 버튼 하나뿐이고, 메뉴 안에서 계속하기/게임 설정/전체 로그/새 게임/모드/치트/게임 나가기를 고른다.
func _test_game_menu() -> void:
	var top_buttons: Array[Button] = []
	for child: Node in _board.get_children():
		var button: Button = child as Button
		if button != null and button.visible and button.position.y < 44.0 and button.size.y <= 40.0:
			top_buttons.append(button)
	_expect(top_buttons.size() == 1 and top_buttons[0] == _board._menu_button, "상단에는 [메뉴] 버튼 하나만 남는다 (%d개)" % top_buttons.size())
	_expect(_board._mode_toggle.get_parent() == null and _board._new_game_button.get_parent() == null and _board._debug_toggle.get_parent() == null, "닫힌 메뉴에서는 모드·새 게임·치트 버튼이 화면에 없다")
	_expect(not _board._menu_is_open(), "처음에는 메뉴가 닫혀 있다")
	_board._menu_button.pressed.emit()
	_expect(_board._menu_is_open() and _board._menu_page == &"main", "[메뉴]를 누르면 메뉴가 열린다")
	var labels: Array[String] = []
	for child: Node in _board._menu_box.get_children():
		if child is Button:
			labels.append((child as Button).text)
	_expect(labels.has("계속하기") and labels.has("게임 설정") and labels.has("전체 로그") and labels.has("새 게임") and labels.has("게임 나가기"), "메뉴 항목: %s" % str(labels))
	_expect(_board._mode_toggle.get_parent() == _board._menu_box and _board._debug_toggle.get_parent() == _board._menu_box, "혼자 하는 판에서는 모드 전환과 치트도 메뉴 안에 있다")
	# 메뉴가 열려 있는 동안 봇은 쉰다
	_expect(_board._bot_should_wait(), "혼자 하는 판은 메뉴가 열려 있는 동안 봇이 멈춘다")
	# 게임 설정
	_board._show_menu_page(&"settings")
	_expect(_board._menu_page == &"settings" and _board._menu_box.find_child("PacingCheck", true, false) != null and _board._menu_box.find_child("TimerCheck", true, false) != null, "게임 설정 화면: 연출 멈춤·제한 시간 옵션")
	var pacing_before: bool = _board.pacing_enabled
	(_board._menu_box.find_child("PacingCheck", true, false) as CheckBox).button_pressed = not pacing_before
	_expect(_board.pacing_enabled == not pacing_before, "연출 멈춤 옵션이 바로 적용된다")
	(_board._menu_box.find_child("PacingCheck", true, false) as CheckBox).button_pressed = pacing_before
	_expect(_board.pacing_enabled == pacing_before, "다시 원래대로")
	# 나가기는 한 번 더 확인한다
	_board._show_menu_page(&"confirm_exit")
	var confirm_labels: Array[String] = []
	for child: Node in _board._menu_box.get_children():
		if child is Button:
			confirm_labels.append((child as Button).text)
	_expect(str(confirm_labels) == str(["나가기", "취소"]), "나가기 확인 화면: %s" % str(confirm_labels))
	# ESC: 하위 화면 -> 메인 -> 닫기
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	_board._unhandled_key_input(escape)
	_expect(_board._menu_is_open() and _board._menu_page == &"main", "ESC는 먼저 메인 메뉴로 돌아간다")
	_board._unhandled_key_input(escape)
	_expect(not _board._menu_is_open(), "ESC로 메뉴가 닫힌다")
	_board._unhandled_key_input(escape)
	_expect(_board._menu_is_open(), "닫혀 있을 때 ESC는 메뉴를 연다")
	# 메뉴 안의 [전체 로그]는 로그 서랍을 열고 메뉴를 닫는다
	_board._log_toggle.pressed.emit()
	_expect(not _board._menu_is_open() and _board._log_panel.visible, "[전체 로그]는 로그 서랍을 열고 메뉴를 닫는다")
	_board._log_toggle.pressed.emit()
	_expect(not _board._log_panel.visible, "다시 열어 닫는다")
	_board._open_menu()
	_board._show_menu_page(&"main")
	_board._close_menu()
	_expect(_board._mode_toggle.get_parent() == null and _board._bot_should_wait() == _board._ui_busy(), "메뉴를 닫으면 버튼이 정리되고 봇은 메뉴 때문에 멈추지 않는다")


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


## 룰렛은 원판을 잡고 돌리는 패드, 러시안 룰렛은 방아쇠 패드, 나머지는 둥근 굴리기 버튼. 패드 조작이 엔진 굴림으로 이어지고 원판은 엔진 눈금에 멈춘다.
func _test_roll_pad() -> void:
	var manager: TurnManager = _board.manager
	var pad: RollPad = _board._roll_pad
	_board.instant_roll_for_test = true
	_board._announcer.cancel()
	var guard: int = 0
	while not (manager.current_state == TurnManager.State.PHASE_TURN_BEGIN) and guard < 400:
		guard += 1
		manager.force_timeout()
		await process_frame
	var current: int = manager.current_player_id()
	manager.state.tools[current] = ToolRegistry.create(&"D6")
	_board._refresh_controls()
	_expect(pad.kind == RollPad.Kind.NONE and _board._roll_button.visible and not pad.visible, "주사위는 둥근 굴리기 버튼")
	_expect(_board._roll_button.position.y > 400.0 and absf(_board._roll_button.position.x + 65.0 - 683.0) < 1.0, "굴리기 버튼은 보드 아래쪽(17·18번 위) 가운데")
	manager.state.tools[current] = ToolRegistry.create(&"HOLDEM")
	_board._refresh_controls()
	var big_center: Vector2 = _board._roll_button.position + _board._roll_button.size / 2.0
	_expect(_board._roll_button.visible and _board._roll_button.size.x >= 180.0 and big_center.distance_to(Vector2(683, 346)) < 2.0, "홀덤(버튼형)은 보드 한가운데에 큰 버튼 (%s %s)" % [str(big_center), str(_board._roll_button.size)])
	manager.state.tools[current] = ToolRegistry.create(&"CHINCHIRO")
	_board._refresh_controls()
	_expect(_board._roll_button.size.x == 130.0 and _board._roll_button.position.y > 400.0, "친치로(차징형)는 보드 아래 작은 버튼 (%s %s)" % [str(_board._roll_button.size), str(_board._roll_button.position)])
	manager.state.tools[current] = ToolRegistry.create(&"LIFE_ROULETTE")
	_board._refresh_controls()
	_expect(pad.kind == RollPad.Kind.ROULETTE and pad.visible and not _board._roll_button.visible, "룰렛은 원판 패드")
	_expect(pad.scale.x >= 1.8 and (pad.position + pad.size / 2.0).distance_to(Vector2(683, 346)) < 2.0, "룰렛 원판은 보드 한가운데에 크게 (%s)" % str(pad.scale))
	var faces: Array[int] = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void:
		if kind == &"roll_resolved":
			faces.append(int((data["result"] as Dictionary)["details"].get("face", -1))))
	var center: Vector2 = pad._wheel.position + pad._wheel.size / 2.0
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = center
	pad._gui_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = center
	pad._gui_input(release)
	_expect(faces.size() == 1 and pad.last_face == faces[0], "원판을 톡 치면 굴러가고 원판은 엔진 눈금에 멈춘다 (%s / %d)" % [str(faces), pad.last_face])
	# 느리게 천천히 문지르기만 하면 던진 것이 아니다
	manager.force_timeout()
	guard = 0
	while not (manager.current_state == TurnManager.State.PHASE_TURN_BEGIN) and guard < 400:
		guard += 1
		manager.force_timeout()
		await process_frame
	current = manager.current_player_id()
	manager.state.tools[current] = ToolRegistry.create(&"REVOLVER")
	_board._refresh_controls()
	_expect(pad.kind == RollPad.Kind.REVOLVER and pad._gun.visible and not pad._wheel.visible, "러시안 룰렛은 리볼버 패드")
	var before: int = faces.size()
	var shots: Array = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void:
		if kind == &"roll_resolved" and (data["result"] as Dictionary)["tool_id"] == &"REVOLVER":
			shots.append(data["result"]))
	pad.trigger_pulled.emit()
	_expect(shots.size() == 1, "방아쇠를 당기면 엔진이 굴린다")
	_board.instant_roll_for_test = false


## 창 비율 대응: 넓은 창이면 오른쪽 묶음은 오른쪽 끝으로, 보드는 가운데로, 왼쪽은 그대로. 높은 창이면 모두 세로 가운데로.
func _test_aspect_layout() -> void:
	var board: MainBoard = _board
	var right_panel: Control = board._tool_board
	var left_panel: Control = board._law_panel
	var plate_x: float = board._plate.position.x
	var base_right: float = right_panel.position.x - board._off_right.x
	var base_left: float = left_panel.position.x - board._off_left.x
	board.layout_for(Vector2(1666, 768))
	_expect(is_equal_approx(right_panel.position.x, base_right + 300.0) and is_equal_approx(left_panel.position.x, base_left), "넓은 창: 오른쪽 묶음은 끝으로, 왼쪽은 그대로")
	_expect(is_equal_approx(board._plate.position.x, MainBoard.PLATE_POS.x + 150.0), "넓은 창: 보드는 가운데로 (%s)" % str(board._plate.position))
	var shifted: Vector2 = board._board_center()
	_expect(is_equal_approx(shifted.x, 683.0 + 150.0 - (683.0 - (MainBoard.BOARD_ORIGIN.x + MainBoard.BOARD_SIZE / 2.0))), "알림·배너 중심이 보드를 따라간다")
	board.layout_for(Vector2(1366, 968))
	_expect(is_equal_approx(board._plate.position.y, MainBoard.PLATE_POS.y + 100.0) and is_equal_approx(right_panel.position.x, base_right), "높은 창: 세로 가운데 정렬")
	board.layout_for(Vector2(1000, 600))
	_expect(is_equal_approx(board._plate.position.x, MainBoard.PLATE_POS.x), "디자인보다 작은 창은 오프셋 0 (엔진이 축소)")
	board.layout_for(Vector2(1366, 768))
	_expect(is_equal_approx(plate_x, board._plate.position.x), "원래 크기로 돌아온다")


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
	_expect(_board._tool_board.size.x == 210.0 and _board._tool_board.size.y >= 140.0 and _board._tool_board.position.y + _board._tool_board.size.y <= 438.0, "판정 도구 카드는 폭 210 고정, 높이는 규칙표에 맞춰 늘어나되 굴림 버튼 행(y=440) 위에서 끝나야 한다")
	_expect(_board._tool_title.text == "텍사스 홀덤 딜러" and _board._tool_main.text.contains("포커 족보") and _board._tool_icon.custom_minimum_size == Vector2(48, 48), "홀덤 카드: 이름 + 핵심 규칙 + 48x48 심볼 (%s)" % _board._tool_main.text)
	manager.state.tools[current] = ToolRegistry.create(&"CHINCHIRO")
	_board._refresh_controls()
	_expect(_board._tool_title.text == "지하노역장 친치로" and _board._tool_main.text == "4 ~ 6 칸 고눈금 보장!" and _board._tool_sub.text == "(삐끗 시 -6칸 후퇴!)", "친치로 카드 문구 (%s)" % _board._tool_main.text)
	_expect(_board._tool_has_gauge(), "친치로도 홀드 & 릴리즈 파워 게이지를 쓴다")
	for tool_id: StringName in ToolRegistry.ALL_IDS:
		manager.state.tools[current] = ToolRegistry.create(tool_id)
		_board._refresh_controls()
		_expect(_board._tool_main.text != "" and _board.TOOL_CARDS.has(tool_id), "%s 카드 규칙 요약 있음" % tool_id)
	manager.state.tools[current] = ToolRegistry.create(&"D6")
	_board._refresh_controls()
	# 3) 기물 독 + 호버 툴팁
	_expect(_board._pawn_buttons.size() == 4 and (_board._pawn_buttons[0] as Button).size.x >= 76.0 and (_board._pawn_buttons[0] as Button).size.y >= 88.0, "기물 슬롯은 최소 76x88")
	_board._on_pawn_slot_hover(0)
	for i: int in 5:
		await process_frame
	_expect(not _board._tip_panel.visible, "0.35초 전에는 툴팁이 없다")
	var wait_start: float = _now()
	while _now() - wait_start < 0.6:
		await process_frame
	_expect(_board._tip_panel.visible and _board._tip_title.text != "" and _board._tip_ability.text != "", "0.35초 뒤 툴팁이 뜬다 (%s)" % _board._tip_title.text)
	# 세트 설명은 없고 필살기 보유 기물에만 필살기 줄이 있다
	_expect(not _board._tip_title.text.contains("세트 (") and not _board._tip_ability.text.contains("세트"), "툴팁에 세트 시너지 설명이 없다")
	var rook: PlayerPawn = null
	for pawn: PlayerPawn in manager.state.basic_pawns_of(3):
		rook = pawn
		break
	manager.state.give_unit(rook, GameEnums.PawnKind.CHESS, [4] as Array[int])
	_board._fill_pawn_tip(rook.entity_id)
	_expect(_board._tip_skill.visible and _board._tip_skill.text.contains("단독 캐슬링"), "룩 툴팁에는 필살기 줄이 있다 (%s)" % _board._tip_skill.text)
	var plain: PlayerPawn = null
	for pawn: PlayerPawn in manager.state.pawns:
		if not PawnSkills.has_skill(pawn):
			plain = pawn
			break
	_board._fill_pawn_tip(plain.entity_id)
	_expect(not _board._tip_skill.visible, "필살기 없는 기물에는 필살기 줄이 없다")
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
	_expect(_board._zoom_view != null and _board._zoom_view.size.x >= 252.0 and _board._zoom_view.size.y >= 353.0 and _board._zoom_view.size.y < 480.0, "클릭하면 손패와 같은 카드 UI로 약 252x353 이상 확대 (%s)" % str(_board._zoom_view.size if _board._zoom_view != null else Vector2.ZERO))
	_board._card_press(holder, &"ACT_01", Vector2(700, 700), Vector2(700, 640))
	_board._card_release(Vector2(701, 700))
	await process_frame
	_expect(_board._zoom_view == null, "다시 클릭하면 닫힌다 (토글)")
	# 5) 드래그: 잘못된 곳에 놓으면 카드가 남는다
	_board._announcer.cancel()  # [N 차례] 알림과 이동 뒤 멈춤을 건너뛰고 입력 가능 상태로 만든다
	_board._beat_until_msec = 0
	_expect(manager.current_state == TurnManager.State.PHASE_TURN_BEGIN and not _board._ui_busy(), "드래그 테스트 전제: 턴 시작, 입력 가능")
	_board._card_press(holder, &"TRP_01", Vector2(700, 700), Vector2(700, 640))
	_board._card_move(Vector2(720, 600))
	_expect(_board._drag_active and _board._drop_zone.visible, "끄는 동안 드롭 존이 보인다")
	_board._card_release(Vector2(100, 300))
	await process_frame
	_expect(not _board._drop_zone.visible and (manager.state.hands[holder] as Array).has(&"TRP_01"), "보드 밖에 놓으면 발동하지 않고 손패에 남는다")
	# 타일 지정형: 보드에 던지면 설치 위치 선택 UI가 열리고, 타일을 고르면 설치된다
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
	_expect(_board._tile_pick_active and _board._pick_banner.visible and _board._pick_cancel.visible, "보드에 던지면 설치할 타일을 고르는 UI가 열린다")
	_expect(not manager.state.board.get_tile(target).has_attachment(&"TRP_01"), "던지기만으로는 아직 설치되지 않는다")
	_board._complete_tile_pick(target)
	await process_frame
	_expect(manager.state.board.get_tile(target).has_attachment(&"TRP_01") and not (manager.state.hands[holder] as Array).has(&"TRP_01") and not _board._pick_cancel.visible, "타일을 고르면 설치되고 UI가 닫힌다")
	_expect(not _board._card_usable_now(holder, CardRegistry.get_card(&"ACT_01")), "굴리기 전 카드는 턴당 1장이라 두 번째 카드는 쓸 수 없다")
	manager._card_played_this_turn = false  # 다음 턴이 된 것으로 보고 이어서 검사한다
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
## 모든 판정 도구의 우측 카드(규칙표 포함)는 굴림 버튼 행(y=440) 위에서 끝나야 한다.
func _test_tool_cards_fit() -> void:
	var manager: TurnManager = _board.manager
	var player_id: int = manager.current_player_id()
	var original: BaseJudgmentTool = manager.state.tools[player_id]
	for tool_id: StringName in ToolRegistry.ALL_IDS:
		manager.state.tools[player_id] = ToolRegistry.create(tool_id)
		_board._refresh_controls()
		await process_frame
		var bottom: float = _board._tool_board.position.y + _board._tool_board.size.y
		_expect(bottom <= 438.0, "%s 도구 카드가 굴림 버튼 행 위에서 끝난다 (아래쪽 %.0f)" % [tool_id, bottom])
		_expect(_board._tool_board.size.x == 210.0, "%s 도구 카드 폭 210" % tool_id)
	manager.state.tools[player_id] = original
	_board._refresh_controls()


## 행동 사이의 호흡: 이동이 끝나면 잠깐 입력이 잠기고, 새 플레이어의 턴에는 [N 차례] 알림이 뜬다.
func _test_action_beats() -> void:
	var manager: TurnManager = _board.manager
	_board._bot.set_enabled(false)  # 앞선 봇 검사의 봇이 턴을 넘겨 알림이 끼어들지 않게 한다
	manager.set_process(false)  # 단계 제한 시간으로 턴이 저절로 넘어가지 않게 한다
	_board.pacing_enabled = false
	_board._announcer.cancel()  # (알림이 비면 화면이 다시 그려지므로 알림 기능을 끈 채로 비운다)
	_board._beat_until_msec = 0
	_board.instant_roll_for_test = false
	_board._announced_round = _board.state.round_number  # 이미 알린 라운드·턴으로 본다
	_board._announced_turn_key = "%d:%d" % [_board.state.round_number, manager.current_player_id()]
	_board._fx_busy = false
	_board.pacing_enabled = true
	_expect(not _board._ui_busy(), "전제: 호흡 검사 시작 시 대기 없음")
	_board._start_beat(0.3)
	_expect(_board._ui_busy(), "이동이 끝난 직후에는 잠깐 입력이 잠긴다")
	await create_timer(0.3 * GameSession.pace_scale + 0.15).timeout  # 연출 속도 배율만큼 길어진다
	_expect(not _board._ui_busy(), "호흡이 끝나면 다시 입력할 수 있다 (fx=%s aim=%s ann=%s hist=%s)" % [str(_board._fx_busy), str(_board._aim_pawn), str(_board._announcer.active), str(_board._announcer.history.slice(-3))])
	_board._announced_turn_key = ""
	_board._announcer.history.clear()
	_board._check_turn_banner()
	if manager.current_state == TurnManager.State.PHASE_TURN_BEGIN:
		_expect(_board._announcer.history.size() == 1 and _board._announcer.active, "새 턴에는 [N 차례] 알림이 뜬다")
		_board._check_turn_banner()
		_expect(_board._announcer.history.size() == 1, "같은 턴에는 알림을 다시 띄우지 않는다")
	_board._announcer.cancel()
	_board._beat_until_msec = 0
	_board.pacing_enabled = false


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
