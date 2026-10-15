# File: res://tests/ui_smoke.gd
# Class: (SceneTree 스크립트, class_name 없음)
# Role: 프로토타입 화면 스모크 테스트. 치트 버튼 없이 버튼/오버레이 시그널만으로 4인 한 판(드래프트 -> 타일 선택 카드 -> 개입 -> 승리 결과창)을 끝까지 진행해 오류·교착이 없는지 확인한다
extends SceneTree

const MAX_ACTIONS: int = 6000

var _board: MainBoard = null
var _frames: int = 0
var _actions: int = 0
var _checked_layout: bool = false
var _seen_phases: Dictionary = {}
var _draft_rounds: Array[int] = []
var _tile_picks: int = 0
var _cards_played: int = 0
var _evolutions: int = 0
var _bombs_passed: int = 0
var _castles: int = 0
var _bangs: int = 0
var _failures: Array[String] = []
var _rng := RandomNumberGenerator.new()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_rng.seed = int(OS.get_environment("SMOKE_SEED")) if OS.get_environment("SMOKE_SEED") != "" else 20261015
		var scene: PackedScene = load("res://scenes/main_board.tscn")
		_board = scene.instantiate()
		root.add_child(_board)
		_board.manager.step_delay_sec = 0.0
		return false
	if not _checked_layout:
		_checked_layout = true
		_check_layout()
		return false
	if _board.manager.is_game_over or _actions >= MAX_ACTIONS:
		return _finish()
	_step_once()
	return false


func _check_layout() -> void:
	_assert(_board._tile_views.size() == 29, "타일 29개가 그려져야 한다 (%d)" % _board._tile_views.size())
	_assert(_board._pawn_views.size() == 16, "말 16개 (%d)" % _board._pawn_views.size())
	_assert(_board._law_labels.size() == 4, "법전 슬롯 4개")
	_assert(_board._hand_boxes.size() == 4, "손패 행 4개")
	_assert(not _board._debug_box.visible, "디버그 패널은 기본으로 접혀 있어야 한다")
	_board._debug_toggle.pressed.emit()
	_assert(_board._debug_box.visible, "토글 버튼으로 디버그 패널이 펼쳐진다")
	_board._debug_toggle.pressed.emit()
	_assert(not _board._debug_box.visible, "다시 누르면 접힌다")
	_assert(_board._draft_overlay != null, "1라운드 시작에 증강 드래프트 오버레이가 떠야 한다")
	for index: int in 29:
		var tile: ColorRect = _board._tile_views[index]
		_assert(tile.position.x >= 0.0 and tile.position.y >= 0.0 and tile.position.x + tile.size.x <= 690.0 and tile.position.y + tile.size.y <= 768.0, "타일 %d가 보드 영역 안에 있어야 한다" % index)
	for a: int in 29:
		for b: int in range(a + 1, 29):
			var rect_a := Rect2((_board._tile_views[a] as ColorRect).position, Vector2(46, 46))
			var rect_b := Rect2((_board._tile_views[b] as ColorRect).position, Vector2(46, 46))
			_assert(not rect_a.intersects(rect_b), "타일 %d와 %d가 겹침" % [a, b])


func _trace(message: String) -> void:
	if OS.get_environment("SMOKE_TRACE") != "":
		print("  trace: ", message)


func _step_once() -> void:
	var manager: TurnManager = _board.manager
	_seen_phases[manager.current_state] = true
	_actions += 1
	if OS.get_environment("SMOKE_TRACE") != "":
		print("act ", _actions, " state=", manager.current_state, " player=", manager.current_player_id(), " round=", _board.state.round_number)
	match manager.current_state:
		TurnManager.State.PHASE_ROUND_START:
			_play_draft(manager)
		TurnManager.State.PHASE_TURN_BEGIN, TurnManager.State.PHASE_ROLL_WAIT:
			if manager.current_state == TurnManager.State.PHASE_TURN_BEGIN and (_try_tile_card(manager) or _try_turn_begin_buttons(manager)):
				return
			if _board._stop_button.visible and _rng.randi_range(0, 1) == 0:
				_board._stop_button.pressed.emit()
			elif _board._bell_button.visible and _rng.randi_range(0, 2) == 0:
				_board._bell_button.pressed.emit()
			else:
				_board._roll_button.pressed.emit()
		TurnManager.State.PHASE_SELECT_PAWN:
			var options: Array[Button] = []
			for button: Button in _board._pawn_buttons:
				if not button.disabled:
					options.append(button)
			if options.is_empty():
				_failures.append("말 선택 단계인데 고를 수 있는 말이 없다")
				manager.force_timeout()
				return
			var chosen: Button = options[_rng.randi_range(0, options.size() - 1)]
			chosen.mouse_entered.emit()
			chosen.mouse_exited.emit()
			chosen.pressed.emit()
		TurnManager.State.PHASE_INTERRUPT_ROLL, TurnManager.State.PHASE_RESOLUTION:
			_assert(_board._skip_button.visible, "개입 창에는 [개입 패스(진행)] 버튼이 보여야 한다")
			_assert(_board._hint_label.text.contains("개입 기회"), "개입 안내 문구가 보여야 한다")
			if not _try_interrupt_card(manager):
				_board._skip_button.pressed.emit()
		_:
			manager.force_timeout()


## 드래프트: 가끔은 직접 고르고(진화는 기물 선택창 포함), 가끔은 자동 선택 버튼을 쓴다.
func _play_draft(manager: TurnManager) -> void:
	var round_number: int = _board.state.round_number
	if not _draft_rounds.has(round_number):
		_draft_rounds.append(round_number)
	_assert(_board._draft_overlay != null, "라운드 %d 드래프트 오버레이가 보여야 한다" % round_number)
	var pending: Array[int] = manager.draft_pending_players()
	if pending.is_empty():
		return
	if _rng.randi_range(0, 2) == 0:
		_board._on_draft_auto_pressed()
		return
	var player_id: int = pending[0]
	var offers: Array[StringName] = manager.draft_offers_for(player_id)
	var index: int = _rng.randi_range(0, offers.size() - 1)
	var definition: AugmentDef = AugmentRegistry.get_def(offers[index])
	var before_basic: int = _board.state.basic_pawns_of(player_id).size()
	_board._on_augment_chosen(player_id, index, definition)
	if _board._choice_overlay != null:
		# 기물 진화: 기물 선택창이 떴다. 첫 번째 말을 고른다.
		_board._pick_augment_with_pawn(_board.state.basic_pawns_of(player_id)[0].entity_id, player_id, index)
		_board._close_choice()
	if _board.state.basic_pawns_of(player_id).size() < before_basic:
		_evolutions += 1


func _try_tile_card(manager: TurnManager) -> bool:
	var player_id: int = manager.current_player_id()
	for card_id: StringName in _board.state.hands[player_id]:
		var card: BaseCard = CardRegistry.get_card(card_id)
		if not card.needs_tile() or _rng.randi_range(0, 1) == 0:
			continue
		_board._on_card_pressed(player_id, card_id)
		if not _board._tile_pick_active:
			continue
		_assert(_board._pick_banner.visible, "타일 선택 모드 안내가 보여야 한다")
		var valid: Array[int] = []
		for tile: int in 29:
			if (_board._pick_marks[tile] as ReferenceRect).visible:
				valid.append(tile)
		_assert(not valid.is_empty(), "선택 가능한 타일이 표시되어야 한다")
		# 잘못된 타일을 먼저 눌러도 모드가 유지되어야 한다.
		_board._complete_tile_pick(GameEnums.GOAL_TILE if not valid.has(GameEnums.GOAL_TILE) else valid[0])
		var tile_to_use: int = valid[_rng.randi_range(0, valid.size() - 1)]
		if _board._tile_pick_active:
			_board._complete_tile_pick(tile_to_use)
		_tile_picks += 1
		_cards_played += 1
		return true
	return false


## 턴 시작 전용 UI: 폭탄 떠넘기기·캐슬링 버튼과 뱅! 카드를 (가끔) 누른다.
func _try_turn_begin_buttons(manager: TurnManager) -> bool:
	var player_id: int = manager.current_player_id()
	_assert(_board._bomb_button.visible == manager.can_pass_bomb(player_id), "폭탄 떠넘기기 버튼 표시가 규칙과 일치해야 한다")
	_assert(_board._castle_button.visible == manager.can_castle(player_id), "캐슬링 버튼 표시가 규칙과 일치해야 한다")
	if _board._bomb_button.visible and _rng.randi_range(0, 1) == 0:
		_board._bomb_button.pressed.emit()
		_bombs_passed += 1
		return true
	if _board._castle_button.visible and _rng.randi_range(0, 1) == 0:
		_board._castle_button.pressed.emit()
		if _board._choice_overlay != null:
			var picks: Array[Button] = []
			for node: Node in _board._choice_overlay.find_children("*", "Button", true, false):
				picks.append(node as Button)
			if picks.size() > 1:
				picks[0].pressed.emit()
			_board._close_choice()
		_castles += 1
		return true
	for card_id: StringName in _board.state.hands[player_id]:
		if card_id == &"ACT_02" and BangCommand.find_target(_board.state, player_id) != null and _rng.randi_range(0, 1) == 0:
			_board._on_card_pressed(player_id, card_id)
			_cards_played += 1
			_bangs += 1
			return true
	return false


func _try_interrupt_card(manager: TurnManager) -> bool:
	for player_id: int in [1, 2, 3, 4]:
		for card_id: StringName in _board.state.hands[player_id]:
			var card: BaseCard = CardRegistry.get_card(card_id)
			if not card.is_playable_in(manager.current_state) or not card.could_play(_board.state, player_id):
				continue
			if _rng.randi_range(0, 2) != 0:
				continue
			_board._on_card_pressed(player_id, card_id)
			if _board._choice_overlay != null:
				var options: Array = []
				for node: Node in _board._choice_overlay.find_children("*", "Button", true, false):
					options.append(node)
				if options.size() > 1:
					(options[0] as Button).pressed.emit()
				_board._close_choice()
			_cards_played += 1
			return true
	return false


func _finish() -> bool:
	var manager: TurnManager = _board.manager
	var phase_names: Array[String] = []
	for phase: int in _seen_phases.keys():
		phase_names.append(str(phase))
	print("UI_SMOKE actions=%d round=%d game_over=%s winner=%d reason=%s phases=%d drafts=%s tile_picks=%d cards=%d evolutions=%d bombs_passed=%d castles=%d bangs=%d" % [_actions, _board.state.round_number, manager.is_game_over, _board.state.winner, VictoryChecker.reason_text(_board._last_reason), _seen_phases.size(), str(_draft_rounds), _tile_picks, _cards_played, _evolutions, _bombs_passed, _castles, _bangs])
	_assert(manager.is_game_over, "치트 없이 한 판이 끝까지 진행되어 승리자가 나와야 한다 (조작 %d회)" % _actions)
	_assert(_draft_rounds.has(1), "1라운드 드래프트가 열렸어야 한다")
	_assert(_board._result_overlay != null, "게임 종료 결과창이 떠야 한다")
	if _board._result_overlay != null:
		var restart_found: bool = false
		for node: Node in _board._result_overlay.find_children("*", "Button", true, false):
			if (node as Button).text == "새 게임 시작":
				restart_found = true
		_assert(restart_found, "결과창에 [새 게임 시작] 버튼이 있어야 한다")
	for round_number: int in _draft_rounds:
		_assert([1, 4, 7].has(round_number), "드래프트는 1, 4, 7라운드에만 열려야 한다 (%d)" % round_number)
	if _failures.is_empty():
		print("UI_SMOKE_OK")
		quit(0)
	else:
		for message: String in _failures:
			printerr("UI_SMOKE_FAIL: " + message)
		quit(1)
	return true


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
