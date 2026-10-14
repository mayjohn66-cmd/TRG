# File: res://tests/ui_smoke.gd
# Class: (SceneTree 스크립트, class_name 없음)
# Role: 프로토타입 화면 스모크 테스트. 메인 씬을 띄우고 버튼 시그널만으로 4인 턴을 수백 번 진행해 스크립트 오류·교착·UI 불일치가 없는지 확인한다
extends SceneTree

const MAX_ACTIONS: int = 1500

var _board: MainBoard = null
var _frames: int = 0
var _actions: int = 0
var _checked_layout: bool = false
var _seen_phases: Dictionary = {}
var _cards_played: int = 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		var scene: PackedScene = load("res://scenes/main_board.tscn")
		_board = scene.instantiate()
		root.add_child(_board)
		_board.manager.step_delay_sec = 0.0
		return false
	if not _checked_layout:
		_checked_layout = true
		_check_layout()
		_prepare_scenario()
		return false
	if _board.manager.is_game_over or _actions >= MAX_ACTIONS:
		return _finish()
	_step_once()
	return false


func _trace(message: String) -> void:
	if OS.get_environment("SMOKE_TRACE") != "":
		print("  trace: ", message)


func _check_layout() -> void:
	_assert(_board._tile_views.size() == 29, "타일 29개가 그려져야 한다 (%d)" % _board._tile_views.size())
	_assert(_board._pawn_views.size() == 16, "말 16개 (%d)" % _board._pawn_views.size())
	_assert(_board._law_labels.size() == 4, "법전 슬롯 4개")
	_assert(_board._hand_boxes.size() == 4, "손패 행 4개")
	for index: int in 29:
		var tile: ColorRect = _board._tile_views[index]
		_assert(tile.position.x >= 0.0 and tile.position.y >= 0.0 and tile.position.x + tile.size.x <= 700.0 and tile.position.y + tile.size.y <= 768.0, "타일 %d가 보드 영역 안에 있어야 한다" % index)
	# 타일끼리 겹치지 않아야 한다.
	for a: int in 29:
		for b: int in range(a + 1, 29):
			var rect_a := Rect2((_board._tile_views[a] as ColorRect).position, Vector2(46, 46))
			var rect_b := Rect2((_board._tile_views[b] as ColorRect).position, Vector2(46, 46))
			_assert(not rect_a.intersects(rect_b), "타일 %d와 %d가 겹침" % [a, b])


func _prepare_scenario() -> void:
	# 법전 5개를 넣어 FIFO 밀어내기를 화면에서 확인할 수 있게 한다.
	for law_id: String in ["LAW_01", "LAW_02", "LAW_08", "LAW_05", "LAW_07"]:
		_board._on_add_law_pressed(law_id)
	_assert(_board.state.rulebook.active_laws_queue.size() == 4, "법전은 4슬롯")
	_assert(not _board.state.rulebook.has_law("LAW_01"), "가장 오래된 LAW_01이 밀려났어야 한다")
	_assert(_board._law_labels[3].text.contains("LAW_07"), "법전 슬롯 4에 최신 교칙이 보여야 한다")


func _step_once() -> void:
	if OS.get_environment("SMOKE_TRACE") != "":
		print("act ", _actions, " state=", _board.manager.current_state, " player=", _board.manager.current_player_id(), " queue=", _board.manager.move_queue)
	var manager: TurnManager = _board.manager
	_seen_phases[manager.current_state] = true
	_actions += 1
	# 가끔 카드를 지급하고 사용해 본다.
	if _actions % 17 == 0:
		_board._card_option.select(_actions % _board._card_option.item_count)
		_board._on_grant_card_pressed()
	if _actions % 29 == 0:
		_board._tool_option.select((_actions / 29) % _board._tool_option.item_count)
		_board._on_tool_selected(_board._tool_option.selected)
	match manager.current_state:
		TurnManager.State.PHASE_TURN_BEGIN, TurnManager.State.PHASE_ROLL_WAIT:
			if _board._stop_button.visible and _actions % 2 == 0:
				_board._stop_button.pressed.emit()
			elif _board._bell_button.visible and _actions % 3 == 0:
				_board._bell_button.pressed.emit()
			else:
				_board._roll_button.pressed.emit()
		TurnManager.State.PHASE_SELECT_PAWN:
			for button: Button in _board._pawn_buttons:
				if not button.disabled:
					button.mouse_entered.emit()
					button.mouse_exited.emit()
					button.pressed.emit()
					break
		TurnManager.State.PHASE_INTERRUPT_ROLL, TurnManager.State.PHASE_RESOLUTION:
			_trace("try_cards")
			_try_cards(manager)
			_trace("after cards visible=%s phase_time=%s" % [_board._skip_button.visible, manager.phase_time_left])
			if _board._skip_button.visible:
				_board._skip_button.pressed.emit()
			_trace("after skip")
		_:
			manager.force_timeout()


func _try_cards(manager: TurnManager) -> void:
	for player_id: int in [1, 2, 3, 4]:
		var hand: Array = _board.state.hands[player_id]
		if hand.is_empty() or _actions % 2 == 1:
			continue
		var card_id: StringName = hand[0]
		var card: BaseCard = CardRegistry.get_card(card_id)
		if card_id == &"ACT_06" and _board.state.rulebook.active_laws_queue.is_empty():
			continue
		if card_id == &"ACT_06":
			_board._play_card_with(_board.state.rulebook.active_laws_queue[0].law_id, player_id, card_id, "law_id")
		elif card_id == &"ACT_05" or card_id == &"ACT_01":
			_board._on_card_pressed(player_id, card_id)
		else:
			continue
		_cards_played += 1
		return


func _finish() -> bool:
	var manager: TurnManager = _board.manager
	print("UI_SMOKE actions=%d round=%d game_over=%s phases=%d cards_played=%d" % [_actions, _board.state.round_number, manager.is_game_over, _seen_phases.size(), _cards_played])
	_assert(_actions > 100, "충분한 횟수의 행동을 진행했어야 한다")
	if _failures.is_empty():
		print("UI_SMOKE_OK")
		quit(0)
	else:
		for message: String in _failures:
			printerr("UI_SMOKE_FAIL: " + message)
		quit(1)
	return true


var _failures: Array[String] = []


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
