## 파워 게이지 부활 (1.3.1): 주사위·윷·친치로·야추·핀볼은 굴리기 버튼(스페이스)을 꾹 누르면 게이지가 왕복하고, 떼는 순간 값이 연출 세기가 된다.
## 짧게 누르면 예전처럼 원클릭, 버튼 밖에서 떼면 취소, 게이지 없는 도구는 그대로.
extends SceneTree

var board: MainBoard
var failures: Array[String] = []
var rolls: Array[Dictionary] = []


func _initialize() -> void:
	run.call_deferred()


func frames(count: int = 2) -> void:
	for index: int in count:
		await process_frame


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func fixture() -> void:
	board = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	board.instant_roll_for_test = true
	root.add_child(board)
	await frames()
	board._bot.set_enabled(false)
	board.manager.set_process(false)
	board.pacing_enabled = false
	board._close_opening()
	board._on_draft_auto_pressed()
	await frames()
	board._reset_presentation()
	board._close_draft_overlay()
	board._close_augment_review()
	board._announcer.cancel()
	board.manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void:
		if kind == &"roll_resolved":
			rolls.append(data["result"]))
	await frames()


## 지금 차례인 사람에게 도구를 쥐여 주고 차례 시작 상태로 맞춘다.
func give(tool_id: StringName) -> void:
	board._reset_presentation()
	board._announcer.cancel()
	board._close_draft_overlay()
	board._close_augment_review()
	board._fx_busy = false  # 앞 시험의 굴림 연출(즉시 모드 아님)이 남긴 상태
	var roller: int = board.manager.current_player_id()
	board.local_player_id = roller
	board.state.tools[roller] = ToolRegistry.create(tool_id)
	board.instant_roll_for_test = false
	board._refresh_all()
	for _wait: int in 300:
		if not board._ui_busy():
			break
		await process_frame
	for _wait: int in 120:
		board._refresh_all()
		if board._roll_button.is_visible_in_tree() or (board._stage_yacht != null and board._stage_yacht.is_visible_in_tree()):
			break
		await process_frame


## 다음 사람 차례 시작까지 엔진을 넘긴다 (연출은 즉시 모드로).
func next_turn() -> void:
	board.instant_roll_for_test = true
	var start_player: int = board.manager.current_player_id()
	for _step: int in 120:
		if board.manager.current_state == TurnManager.State.PHASE_TURN_BEGIN and board.manager.current_player_id() != start_player:
			break
		if board.manager.current_state == TurnManager.State.PHASE_ROUND_START:
			board._on_draft_auto_pressed()
		board._reset_presentation()
		board._announcer.cancel()
		board.manager.force_timeout()
		await frames()
	print("NEXT_TURN state=", board.manager.current_state, " player=", board.manager.current_player_id())


func hold(seconds: float) -> void:
	await create_timer(seconds).timeout
	await frames()


func run() -> void:
	create_timer(120).timeout.connect(func() -> void: printerr("POWER_GAUGE_FAIL timeout"); quit(1))
	root.size = Vector2i(1366, 768)
	await fixture()
	# 1) 주사위: 꾹 누르면 게이지, 떼면 그 값으로 굴린다
	await give(&"D6")
	await frames(3)
	# 굴리기 전: 내 도구(주사위)가 굴리기 버튼 위 보드에 놓여 있다
	var prop: ToolRestProp = board.rest_prop()
	check(prop != null and prop.visible and prop.tool_id == &"D6", "굴리기 전 굴리기 버튼 위에 내 주사위가 놓여 있다")
	if prop != null:
		var button_rect: Rect2 = board._roll_button.get_global_rect()
		var prop_rect: Rect2 = prop.get_global_rect()
		check(prop_rect.end.y <= button_rect.position.y + 10.0 and absf(prop_rect.get_center().x - button_rect.get_center().x) < 2.0, "소품은 버튼 바로 위 가운데 (%s / %s)" % [prop_rect, button_rect])
	board._roll_button.button_down.emit()
	await hold(0.3)
	check(board.power_charging(), "주사위: 굴리기 버튼을 누르고 있으면 게이지가 뜬다")
	var gauge: Control = board.find_child("PowerGauge", true, false)
	check(gauge != null and gauge.visible, "게이지가 화면에 보인다")
	var value: float = board.power_value()
	check(value > 0.05, "누르고 있는 동안 게이지가 오른다 (%.2f)" % value)
	board._roll_button.pressed.emit()
	await frames()
	check(not board.power_charging(), "손을 떼면 게이지가 닫힌다")
	check(rolls.size() == 1, "떼는 순간 굴린다")
	check(board.rest_prop() == null or not board.rest_prop().visible, "굴리면 소품은 숨는다 (굴림 연출이 대신)")
	check(absf(board._pending_power - value) < 0.15, "모은 값이 연출 세기가 된다 (%.2f / %.2f)" % [board._pending_power, value])
	# 2) 버튼 밖에서 떼면 취소
	await next_turn()
	rolls.clear()
	await give(&"YUT")
	board._roll_button.button_down.emit()
	await hold(0.15)
	board._roll_button.button_up.emit()
	await frames(3)
	check(not board.power_charging() and rolls.is_empty(), "윷: 버튼 밖에서 떼면 굴리지 않고 게이지만 닫힌다")
	# 3) 스페이스를 꾹 눌렀다 떼기
	for _wait: int in 240:
		board._refresh_all()
		if not board._ui_busy() and board._roll_button.is_visible_in_tree() and not board._roll_button.disabled:
			break
		await process_frame
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	board._unhandled_key_input(key)
	await hold(0.2)
	check(board.power_charging(), "스페이스를 누르고 있으면 게이지")
	var up := InputEventKey.new()
	up.keycode = KEY_SPACE
	up.pressed = false
	board._unhandled_key_input(up)
	await frames()
	check(rolls.size() == 1 and not board.power_charging(), "스페이스를 떼면 굴린다")
	# 4) 게이지 없는 도구는 그대로 바로 굴린다
	await next_turn()
	rolls.clear()
	await give(&"SLOT_777")
	board._roll_button.button_down.emit()
	await frames()
	check(not board.power_charging(), "슬롯은 게이지가 없다")
	board._roll_button.pressed.emit()
	await frames()
	check(rolls.size() == 1, "슬롯은 바로 굴린다")
	# 5) 야추: [주사위 5개 굴리기]도 꾹 눌러 모은다
	await next_turn()
	rolls.clear()
	await give(&"DICE_YACHT")
	for _wait: int in 120:
		board._refresh_all()
		if board._stage_yacht.gauge_buttons()[0].is_visible_in_tree():
			break
		await process_frame
	board._stage_yacht.visible = true  # 헤드리스 시험 보드는 굴리기 화면 허용(연출 대기) 판정이 늦어 직접 띄운다
	board._stage_yacht.sync(board.state.tools[board.manager.current_player_id()], true)
	await frames()
	var yacht_start: Button = board._stage_yacht.gauge_buttons()[0]
	yacht_start.button_down.emit()
	await hold(0.2)
	check(board.power_charging(), "야추 굴리기 버튼도 게이지")
	yacht_start.pressed.emit()
	await frames()
	check(not board.power_charging(), "야추: 떼면 게이지가 닫힌다")
	# 6) 핀볼: [발사 준비] 뒤 발사 버튼을 꾹 누르면 스프링이 당겨진다
	await next_turn()
	rolls.clear()
	await give(&"DICE_PINBALL")
	board._roll_button.pressed.emit()  # 발사 준비
	for _wait: int in 120:
		board._refresh_all()
		if board._roll_button.is_visible_in_tree() and not board._roll_button.disabled and board._pinball_ready_key == board._pinball_key():
			break
		await process_frame
	board._stage_pinball.visible = true
	board._roll_button.visible = true
	board._roll_button.disabled = false
	board._roll_button.button_down.emit()
	await hold(0.25)
	check(board.power_charging(), "핀볼: 준비 뒤 발사 버튼을 누르고 있으면 게이지")
	check(board._stage_pinball.pull > 0.05, "핀볼 스프링이 게이지만큼 당겨진다 (%.2f)" % board._stage_pinball.pull)
	board._roll_button.pressed.emit()
	await frames()
	check(not board.power_charging() and rolls.size() == 1, "핀볼: 떼면 발사")
	if failures.is_empty():
		print("UI power gauge test passed")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)
