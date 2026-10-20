# File: res://tests/ui_smoke.gd
# Class: (SceneTree 스크립트, class_name 없음)
# Role: 프로토타입 화면 스모크 테스트. 치트 버튼 없이 버튼/오버레이 시그널만으로 4인 한 판(드래프트 -> 타일 선택 카드 -> 개입 -> 승리 결과창)을 끝까지 진행해 오류·교착이 없는지 확인한다
extends SceneTree

const MAX_ACTIONS: int = 40000

var _board: MainBoard = null
var _frames: int = 0
var _actions: int = 0
var _checked_layout: bool = false
var _seen_phases: Dictionary = {}
var _draft_rounds: Array[int] = []
var _banner_picks: int = 0
var _popups: int = 0
var _tile_picks: int = 0
var _cards_played: int = 0
var _evolutions: int = 0
var _bombs_passed: int = 0
var _skills: int = 0
var _bangs: int = 0
var _roulette_seen: int = 0
var _roulette_forced: bool = false
var _board_clicks: int = 0
var _ai: bool = false
var _fog_checks: int = 0
var _idle_frames: int = 0
var _stack_choices: int = 0
var _failures: Array[String] = []
var _rng := RandomNumberGenerator.new()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_rng.seed = int(OS.get_environment("SMOKE_SEED")) if OS.get_environment("SMOKE_SEED") != "" else 20261015
		GameSession.view_mode = 1 if OS.get_environment("SMOKE_VIEW") == "tilt" else 0  # SMOKE_VIEW=tilt: 기울인 탑뷰로 한 판 진행
		var scene: PackedScene = load("res://scenes/main_board.tscn")
		_board = scene.instantiate()
		root.add_child(_board)
		_board.manager.step_delay_sec = 0.0
		_board.instant_roll_for_test = true  # 굴림 연출 대기 시간을 0초로 건너뛴다 (연출 자체는 ui_fx_test.gd가 검증)
		# SMOKE_AI=1이면 [1P vs 3AI 봇] 모드로 진행한다: 스모크는 P1만 조작하고 P2~P4는 BotController가 맡는다.
		_ai = OS.get_environment("SMOKE_AI") == "1"
		_board.ai_mode = _ai
		_board._bot.set_enabled(_ai)
		_board._refresh_mode_toggle()
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
	_assert(_board._tile_views.size() == BoardSpec.tile_count, "타일 %d개가 그려져야 한다 (%d)" % [BoardSpec.tile_count, _board._tile_views.size()])
	_assert(_board._pawn_views.size() == 16, "말 16개 (%d)" % _board._pawn_views.size())
	_assert(_board._law_labels.size() == 4, "법전 슬롯 4개")
	_assert(_board._profiles.size() == 4, "모서리 프로필 HUD 카드 4개")
	_assert(not _board._debug_box.visible and not _board._log_panel.visible, "치트/디버그와 전체 로그 서랍은 기본으로 숨겨져 있어야 한다")
	_board._debug_toggle.pressed.emit()
	_assert(_board._debug_box.visible and not _board._log_panel.visible, "[치트/디버그] 버튼으로 디버그 서랍이 열린다")
	_board._log_toggle.pressed.emit()
	_assert(_board._log_panel.visible and not _board._debug_box.visible, "[전체 로그] 버튼은 로그 서랍을 열고 디버그 서랍을 닫는다")
	_board._log_toggle.pressed.emit()
	_assert(not _board._log_panel.visible and not _board._debug_box.visible, "다시 누르면 닫힌다")
	_check_hud_layout()
	_assert(_board._draft_overlay != null, "1라운드 시작에 증강 드래프트 오버레이가 떠야 한다")
	for index: int in BoardSpec.tile_count:
		_assert(Rect2(Vector2.ZERO, Vector2(1366, 768)).encloses(_tile_rect(index)), "타일 %d가 화면 안에 있어야 한다" % index)
	for a: int in BoardSpec.tile_count:
		for b: int in range(a + 1, BoardSpec.tile_count):
			_assert(Geometry2D.intersect_polygons(_tile_polygon(a), _tile_polygon(b)).is_empty(), "타일 %d와 %d가 겹침" % [a, b])


## 타일이 화면에서 실제로 차지하는 사각형 (원근·압축 배율 반영).
## 마름모 보드의 타일은 모양(윤곽)으로 겹침을 본다 (바깥 사각형은 마름모 배치에서 서로 겹친다).
func _tile_polygon(index: int) -> PackedVector2Array:
	var tile: BoardSkin.Tile = _board._tile_views[index]
	var result := PackedVector2Array()
	for point: Vector2 in tile.outline_points:
		result.append(tile.position + tile.size / 2.0 + (point - tile.size / 2.0) * tile.scale)
	return result


func _tile_rect(index: int) -> Rect2:
	var points: PackedVector2Array = _tile_polygon(index)
	var rect := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		rect = rect.expand(point)
	return rect


## 상용 HUD 배치 검증: 보드는 화면 정중앙, 프로필 카드는 네 모서리, 서로 겹치는 HUD가 없어야 한다.
func _check_hud_layout() -> void:
	_assert(not _board._intro_blocks() and _board._opening == null, "즉시 모드에서는 오프닝 인트로가 건너뛰어져 증강 선택을 막지 않는다")
	var board_rect := Rect2()
	for index: int in BoardSpec.tile_count:
		board_rect = _tile_rect(index) if index == 0 else board_rect.merge(_tile_rect(index))
	_assert(absf(board_rect.get_center().x - 683.0) < 4.0, "보드판은 화면 가로 정중앙이어야 한다 (%s)" % str(board_rect))
	# 테이블에 둘러앉은 자리: 네 모서리: 나(P1) 우하단(큼), 다음 순서 P2 우상단, 맞은편 P3 좌하단, 이전 순서 P4 좌상단 (상대 좌석 매핑).
	var expected_anchor: Dictionary = {1: MainBoard.SEAT_ME, 2: MainBoard.SEAT_RIGHT, 3: MainBoard.SEAT_TOP, 4: MainBoard.SEAT_LEFT}
	var rects: Dictionary = {}
	for player_id: int in [1, 2, 3, 4]:
		var panel: Control = _board._profiles[player_id]["panel"]
		var rect: Rect2 = panel.get_global_rect()
		rects[player_id] = rect
		_assert(Rect2(Vector2.ZERO, Vector2(1366, 768)).encloses(rect), "P%d 프로필 카드가 화면 안에 있어야 한다 %s" % [player_id, str(rect)])
		_assert(_board.seat_anchor_of(player_id) == expected_anchor[player_id], "P%d 좌석 앵커 (%s)" % [player_id, str(_board.seat_anchor_of(player_id))])
		_assert(not rect.intersects(board_rect), "P%d 프로필 카드가 보드판을 가리면 안 된다" % player_id)
		_assert(_board._profiles[player_id]["avatar"] is AvatarSlot, "P%d 아바타 칸" % player_id)
	_assert((rects[3] as Rect2).get_center().x < 683.0 and (rects[3] as Rect2).get_center().y > 384.0, "맞은편(P3)은 좌하단")
	_assert((rects[1] as Rect2).size.x > (rects[2] as Rect2).size.x and (rects[1] as Rect2).size.y > (rects[2] as Rect2).size.y, "내 프로필 카드가 가장 크다")
	_assert((rects[2] as Rect2).get_center().x > 683.0 and (rects[2] as Rect2).get_center().y < 384.0, "다음 순서(P2)는 오른쪽 위")
	_assert((rects[4] as Rect2).get_center().x < 683.0 and (rects[4] as Rect2).get_center().y < 384.0, "이전 순서(P4)는 왼쪽 위")
	_assert((rects[1] as Rect2).get_center().x > 683.0 and (rects[1] as Rect2).get_center().y > 384.0, "나(P1)는 우하단")
	for a: int in [1, 2, 3, 4]:
		for b: int in [1, 2, 3, 4]:
			if a < b:
				_assert(not (rects[a] as Rect2).intersects(rects[b]), "P%d·P%d 프로필이 겹치지 않는다" % [a, b])
	var law_rect: Rect2 = (_board._law_slots[0] as Control).get_global_rect().merge((_board._law_slots[3] as Control).get_global_rect())
	_assert(not law_rect.intersects(board_rect), "법전 위젯이 보드판을 가리면 안 된다")
	_assert(law_rect.position.x < 400.0 and not law_rect.intersects(rects[3]) and not law_rect.intersects(rects[4]), "법전 위젯은 왼쪽 프로필 아래 좌측 중앙에 있어야 한다")
	_assert(_board._law_labels.size() == 4 and _board._law_dashes.size() == 4, "법전 슬롯 4개")
	for dash: Control in _board._law_dashes:
		_assert(dash.visible, "비어 있는 법전 슬롯은 점선 테두리가 보여야 한다")


func _trace(message: String) -> void:
	if OS.get_environment("SMOKE_TRACE") != "":
		print("  trace: ", message)


## AI 모드: 지금 봇이 행동할 차례이거나 사람이 할 일이 없으면 이번 프레임은 건너뛴다 (BotController가 _process에서 진행한다).
func _wait_for_bots(manager: TurnManager) -> bool:
	_actions -= 1  # 기다리는 프레임은 조작 횟수로 세지 않는다
	_idle_frames += 1
	var human: int = MainBoard.HUMAN_ID
	if manager.counter_pending():
		# 반격 대기: 맞은 사람이 P1이면 반격 팝업이 떠야 하고, 봇이면 봇이 고른다.
		_board._update_reaction_popup(0.0)
		var human_victim: bool = int(manager.pending_counter()["victim"]) == human
		_assert((_board._reaction_popup != null) == human_victim, "AI 모드의 반격 팝업은 P1이 공격당했을 때만 떠야 한다")
		if not human_victim:
			return true
		_actions += 1
		return false
	match manager.current_state:
		TurnManager.State.PHASE_ROUND_START:
			if _board._draft_overlay == null:
				return true
			return false
		TurnManager.State.PHASE_TURN_BEGIN, TurnManager.State.PHASE_ROLL_WAIT, TurnManager.State.PHASE_SELECT_PAWN:
			if manager.current_player_id() != human:
				return true
		TurnManager.State.PHASE_INTERRUPT_ROLL, TurnManager.State.PHASE_RESOLUTION:
			if manager.stack_offer_pending():
				if manager.current_player_id() != human:
					return true
			elif not manager.counter_pending():
				return true  # 개입 창은 봇이 자동으로 넘긴다
		TurnManager.State.PHASE_MOVING_STEP, TurnManager.State.PHASE_NEUTRAL_NPC:
			return true
	_actions += 1
	return false


func _step_once() -> void:
	var manager: TurnManager = _board.manager
	_seen_phases[manager.current_state] = true
	_actions += 1
	if _actions % 5 == 0 and manager.current_state != TurnManager.State.PHASE_ROUND_START:
		_board._refresh_all()  # 이동 도중 멈춘 상태에서 표본을 뽑아도 HUD·토큰이 낡지 않도록 먼저 최신으로 칠한다
		_check_bounds()
		_check_pawn_labels()
		_check_fog_of_war()
	if OS.get_environment("SMOKE_TRACE") != "":
		print("act ", _actions, " state=", manager.current_state, " player=", manager.current_player_id(), " round=", _board.state.round_number)
	if _ai and _wait_for_bots(manager):
		return
	if manager.counter_pending():
		_react_in_window(manager)
		return
	match manager.current_state:
		TurnManager.State.PHASE_ROUND_START:
			_play_draft(manager)
		TurnManager.State.PHASE_TURN_BEGIN, TurnManager.State.PHASE_ROLL_WAIT:
			if not _roulette_forced and manager.current_state == TurnManager.State.PHASE_TURN_BEGIN:
				# 디버그 패널의 판정 도구 드롭다운으로 현재 플레이어를 러시안 룰렛으로 바꿔 룰렛 전용 UI를 검증한다.
				_roulette_forced = true
				_board._tool_option.item_selected.emit(ToolRegistry.ALL_IDS.find(&"REVOLVER"))
				# 윷놀이 기물이 있어야 [선택적 업기] 팝업이 뜬다: P1·P2의 기본 말 두 개씩을 윷 세트로 시작시킨다 (진화 증강과 같은 경로).
				for pawn_id: int in [11, 12, 21, 22]:
					if _board.state.get_pawn(pawn_id).kind == GameEnums.PawnKind.BASIC:
						_board.state.evolve_pawn(_board.state.get_pawn(pawn_id), GameEnums.PawnKind.YUT)
				# 필살기 보유 기물(룩·차·비행기·흑돌)도 나눠 준다.
				var skill_pawns: Array = [[13, GameEnums.PawnKind.CHESS, 4], [14, GameEnums.PawnKind.GO, 1], [23, GameEnums.PawnKind.JANGGI, 2], [24, GameEnums.PawnKind.MONOPOLY, 2], [33, GameEnums.PawnKind.GO, 1], [43, GameEnums.PawnKind.JANGGI, 2]]
				for entry: Array in skill_pawns:
					_board.state.give_unit(_board.state.get_pawn(int(entry[0])), entry[1], [int(entry[2])] as Array[int])
				_board._refresh_all()
			if manager.current_state == TurnManager.State.PHASE_TURN_BEGIN and (_try_tile_card(manager) or _try_turn_begin_buttons(manager)):
				return
			if _board._stop_button.visible and not _board._stop_button.disabled and _rng.randi_range(0, 1) == 0:
				_board._stop_button.pressed.emit()
			else:
				_board._roll_button.pressed.emit()
		TurnManager.State.PHASE_SELECT_PAWN:
			var options: Array[Button] = []
			for button: Button in _board._select_cards:
				if not button.disabled:
					options.append(button)
			if options.is_empty():
				_failures.append("말 선택 단계인데 고를 수 있는 말이 없다")
				manager.force_timeout()
				return
			var chosen: Button = options[_rng.randi_range(0, options.size() - 1)]
			# 가끔은 버튼 대신 보드 위의 말 도형을 직접 클릭한다 (호버 미리보기 포함).
			var chosen_index: int = _board._select_cards.find(chosen)
			var chosen_pawn: PlayerPawn = _board.state.get_pawn(manager.current_player_id() * 10 + chosen_index + 1)
			var chosen_view: Node2D = _board._pawn_views.get(chosen_pawn.entity_id)
			_check_select_banner(manager, options)
			var banner_rect: Rect2 = (_board._select_banner as Control).get_global_rect()
			if _board._select_banner.visible and _rng.randi_range(0, 2) == 0:
				# 말 선택 배너의 카드를 직접 눌러 고른다 (호버 미리보기 포함).
				var card: Button = _board._select_cards[chosen_index]
				card.mouse_entered.emit()
				_assert(_board._flash_pawn == chosen_pawn.entity_id, "카드에 호버하면 해당 말이 깜빡이기 시작해야 한다")
				card.mouse_exited.emit()
				card.pressed.emit()
				_banner_picks += 1
				return
			if chosen_view != null and chosen_view.visible and not banner_rect.has_point(chosen_view.position) and _rng.randi_range(0, 1) == 0:
				var hover := InputEventMouseMotion.new()
				hover.position = chosen_view.position
				_board._input(hover)
				var click := InputEventMouseButton.new()
				click.position = chosen_view.position
				click.button_index = MOUSE_BUTTON_LEFT
				click.pressed = true
				_board._input(click)
				_board_clicks += 1
				return
			chosen.mouse_entered.emit()
			chosen.mouse_exited.emit()
			chosen.pressed.emit()
		TurnManager.State.PHASE_INTERRUPT_ROLL, TurnManager.State.PHASE_RESOLUTION:
			if manager.stack_offer_pending():
				# 윷놀이 기물 [선택적 업기] 팝업: 화면 중앙의 두 버튼 중 하나를 누른다.
				_assert(_board._stack_overlay != null, "업기 제안이 있으면 선택 팝업이 떠야 한다")
				if _board._stack_overlay != null:
					var choices: Array[Button] = []
					for node: Node in _board._stack_overlay.find_children("*", "Button", true, false):
						choices.append(node as Button)
					_assert(choices.size() == 2, "업기 팝업에는 [업기]/[그냥 두기] 버튼 두 개")
					choices[_rng.randi_range(0, choices.size() - 1)].pressed.emit()
					_stack_choices += 1
				return
			_react_in_window(manager)
		_:
			manager.force_timeout()


## 드래프트: 가끔은 직접 고르고(진화는 기물 선택창 포함), 가끔은 자동 선택 버튼을 쓴다.
func _play_draft(manager: TurnManager) -> void:
	var round_number: int = _board.state.round_number
	if not _draft_rounds.has(round_number):
		_draft_rounds.append(round_number)
	_assert(_board._draft_overlay != null, "라운드 %d 드래프트 오버레이가 보여야 한다" % round_number)
	var pending: Array[int] = []
	for candidate: int in manager.draft_pending_players():
		if not _ai or candidate == MainBoard.HUMAN_ID:
			pending.append(candidate)  # AI 모드에서는 사람(P1)만 직접 고르고 봇은 BotController가 고른다
	if pending.is_empty():
		return
	if not _ai and _rng.randi_range(0, 2) == 0:
		_board._on_draft_auto_pressed()
		return
	var player_id: int = pending[0]
	_check_draft_cards()
	var offers: Array[StringName] = manager.draft_offers_for(player_id)
	if _rng.randi_range(0, 2) == 0:
		# 리롤: 슬롯 하나가 다른 증강으로 바뀌고 오버레이가 새로 그려지며 그 슬롯의 리롤 버튼은 잠긴다
		var slot: int = _rng.randi_range(0, offers.size() - 1)
		_board._on_augment_reroll(player_id, slot)
		offers = manager.draft_offers_for(player_id)
		_assert(manager.draft_reroll_used(player_id, slot), "리롤 사용이 기록돼야 한다")
		_assert(_board._draft_reroll_buttons[slot].disabled, "리롤한 슬롯의 버튼은 비활성이어야 한다")
		_check_draft_cards()
	var index: int = _rng.randi_range(0, offers.size() - 1)
	var definition: AugmentDef = AugmentRegistry.get_def(offers[index])
	var before_basic: int = _board.state.basic_pawns_of(player_id).size()
	_board._on_augment_chosen(player_id, index, definition)
	if _board._choice_overlay != null:
		# 기물 진화: 기물 선택창이 떴다. 뒤의 증강 카드 화면은 숨겨져 겹쳐 보이지 않아야 한다. 첫 번째 말을 고른다.
		_assert(_board._draft_overlay == null or not _board._draft_overlay.visible, "말 고르기 중에는 증강 카드 화면이 숨겨진다")
		_board._pick_augment_with_pawn(_board.state.basic_pawns_of(player_id)[0].entity_id, player_id, index)
		_board._close_choice()
	if _board.state.basic_pawns_of(player_id).size() < before_basic:
		_evolutions += 1


## 말 선택 단계: 배너가 떠 있고(사람 차례), 카드 4장의 크기·활성 상태·결과 예고 문구가 규격에 맞는지 확인한다.
func _check_select_banner(manager: TurnManager, options: Array[Button]) -> void:
	var banner: Control = _board._select_banner
	_assert(banner.visible, "말 선택 단계에는 이동할 말 선택 배너가 자동으로 떠야 한다")
	_assert(banner.get_global_rect().position.y >= 540.0, "배너는 보드 아래쪽에 있어야 한다")
	_assert((_board._select_title as Label).text.begins_with("[어느 말을") and (_board._select_title as Label).text.ends_with("칸 이동시킬까요?]"), "배너 제목 문구")
	_assert(_board._select_cards.size() == 4, "배너에는 말 카드 4장")
	for index: int in 4:
		var card: Button = _board._select_cards[index]
		_assert(card.size.x >= 135.0 and card.size.y >= 165.0, "말 카드는 최소 135x165")
		var slot_pawn: PlayerPawn = _board.state.get_pawn(manager.current_player_id() * 10 + index + 1)
		_assert(card.disabled == not _board._can_pick_now(slot_pawn), "배너 카드의 활성 상태는 말을 고를 수 있는지와 같아야 한다")
		_assert(not (_board._pawn_buttons[index] as Button).has_theme_stylebox_override("hover") or not (_board._pawn_buttons[index] as Button).disabled, "독 슬롯은 선택 단계에서도 눌러서 고르는 용도가 아니다")
		var result_text: String = (_board._select_parts[index]["result"] as Label).text
		_assert(result_text != "", "카드마다 결과 예고 문구가 있어야 한다")
		if not card.disabled:
			_assert(result_text.begins_with("→"), "선택 가능한 카드의 예고는 [→ N번 ...] 형식")


func _check_draft_cards() -> void:
	_assert(_board._draft_cards.size() == 3, "증강 카드는 3장이어야 한다")
	for card: Button in _board._draft_cards:
		_assert(card.size.x >= 260.0 and card.size.y >= 390.0, "증강 카드는 최소 260x390")
	_assert(_board._draft_reroll_buttons.size() == 3, "카드마다 리롤 버튼이 있어야 한다")


func _try_tile_card(manager: TurnManager) -> bool:
	var player_id: int = manager.current_player_id()
	for card_id: StringName in _board.state.hands[player_id]:
		var card: BaseCard = CardRegistry.get_card(card_id)
		if manager.card_played_this_turn() or not card.needs_tile() or _rng.randi_range(0, 1) == 0:
			continue
		_board._on_card_pressed(player_id, card_id)
		if not _board._tile_pick_active:
			continue
		_assert(_board._pick_banner.visible, "타일 선택 모드 안내가 보여야 한다")
		var valid: Array[int] = []
		for tile: int in BoardSpec.tile_count:
			if (_board._pick_marks[tile] as BoardSkin.Ring).visible:
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
## 화면 밖으로 잘리는 UI가 없는지 검사한다: 보이는 손패 카드·하단 조작 버튼·말 선택 버튼이 모두 창 안에 있어야 한다.
## 보드 토큰은 현재 기물·소유자·이미지를 반영하고, 툴팁에는 이름과 능력이 있어야 한다.
func _check_pawn_labels() -> void:
	for pawn: PlayerPawn in _board.state.pawns:
		var view: Node2D = _board._pawn_views[pawn.entity_id]
		var token: PawnToken = view.get_node_or_null("Bounce/Token") as PawnToken
		_assert(token != null, "말 %d의 토큰 렌더러가 있어야 한다" % pawn.entity_id)
		if token == null:
			continue
		_assert(token.pawn == pawn and token.owner_color == MainBoard.PLAYER_COLORS[pawn.owner_id], "보드 토큰은 현재 말과 소유자 색상을 반영한다")
		var expected: Dictionary = PawnArt.sprite(pawn)
		_assert(token.artwork.get("texture") == expected.get("texture"), "보드 토큰 이미지는 현재 세부 병종 또는 폴백과 일치한다")
	var owner_id: int = _board._dock_owner()
	for index: int in _board._pawn_buttons.size():
		var pawn: PlayerPawn = _board.state.get_pawn(owner_id * 10 + index + 1)
		var tip: String = _board._pawn_info_text(pawn.entity_id)
		_assert(tip.contains(PawnCatalog.full_name(pawn.kind, pawn.unit_no)) and tip.contains(PawnCatalog.ability_text(pawn.kind, pawn.unit_no)), "기물 툴팁에 전체 이름과 고유 능력이 있어야 한다 (%s)" % tip)
		_assert(not tip.contains("시너지") and not tip.contains("2세트") and not tip.contains("4세트"), "기물 툴팁에 세트 설명이 없어야 한다 (%s)" % tip)
		if PawnSkills.has_skill(pawn):
			_assert(tip.contains("[1회]"), "필살기 보유 기물 툴팁에는 [1회] 필살기 줄이 있어야 한다 (%s)" % tip)
	for player_id: int in [1, 2, 3, 4]:
		_assert(_board.get_player_for_corner(_board.corner_of_player(player_id)) == player_id, "좌석 매핑은 역함수 관계여야 한다")


## 타일 은신: AI 모드에서는 P1이 설치한 함정만 이름이 보이고 봇이 설치한 함정은 뒷면 [? 함정]으로만 보여야 한다.
func _check_fog_of_war() -> void:
	if not _ai:
		return
	for index: int in BoardSpec.tile_count:
		for attachment: TileAttachment in _board.state.board.get_tile(index).attachments:
			if not ["TRP_01", "TRP_02", "TRP_03", "TRP_05"].has(attachment.attachment_id):
				continue
			_fog_checks += 1
			var mark_text: String = _board._trap_tooltip(attachment)  # 타일 위 글자 배지는 없애고 툴팁으로만 알린다
			if attachment.owner_id == MainBoard.HUMAN_ID:
				_assert(not mark_text.contains("?함정"), "내 함정은 이름이 보여야 한다 (%s)" % mark_text)
			else:
				_assert(mark_text.contains("? 함정") and not (mark_text.contains("나락") or mark_text.contains("거울") or mark_text.contains("지뢰") or mark_text.contains("도미노")), "봇의 함정은 [? 함정]으로만 보여야 한다 (%s)" % mark_text)


func _check_bounds() -> void:
	var window: Rect2 = Rect2(Vector2.ZERO, Vector2(1366, 768))
	var controls: Array[Control] = []
	for node: Node in _board._dock.get_children():
		# 손패 카드는 일부러 화면 아래로 반쯤 가려진 채 펼쳐진다 (호버하면 전체가 올라온다). 크기만 따로 검사한다.
		if node is Control and not node is PanelContainer and not node.is_queued_for_deletion():
			controls.append(node)
	for button: Control in [_board._roll_button, _board._stop_button, _board._skip_button]:
		if button.visible:
			controls.append(button)
	for button: Button in _board._pawn_buttons:
		if _board._pawn_bar.visible:
			controls.append(button)
	for player_id: int in [1, 2, 3, 4]:
		controls.append(_board._profiles[player_id]["panel"])
	for control: Control in controls:
		var rect: Rect2 = control.get_global_rect()
		if rect.size.x > 0.0 and not window.grow(2.0).encloses(rect):
			_failures.append("UI가 화면 밖으로 나갔다: %s %s" % [control.get_class(), str(rect)])
	# 카드 독의 카드는 140x196 전체 카드이고 윗부분(일러스트·이름)이 화면 안에 보여야 하며, 현재 턴 프로필은 황금 테두리로 강조된다.
	for node: Node in _board._dock.get_children():
		if node is PanelContainer and not node.is_queued_for_deletion():
			var hand_card: Control = node as Control
			_assert(hand_card.size.x >= 139.0 and hand_card.size.y >= 195.0, "카드는 전체 크기 140x196이어야 한다 (%s)" % str(hand_card.size))
			# 부채꼴로 기울어진 카드는 원점이 최대 30px쯤 아래로 밀리므로 여유를 둔다.
			_assert(hand_card.get_global_rect().position.y + 60.0 < 768.0, "카드 윗부분(일러스트·이름)은 화면 안에 보여야 한다")
	var turn_panel: PanelContainer = _board._profiles[_board.manager.current_player_id()]["panel"]
	_assert(turn_panel.scale.x > 1.0, "현재 턴 플레이어 프로필 카드는 확대되어야 한다")
	# 스포트라이트: 현재 턴만 환하게, 나머지는 어둡게 가라앉는다 (전체 승리 후에는 모두 밝게).
	if not _board.manager.is_game_over:
		for other: int in [1, 2, 3, 4]:
			var panel: Control = _board._profiles[other]["panel"]
			if other == _board.manager.current_player_id():
				_assert(panel.modulate.is_equal_approx(MainBoard.PROFILE_LIT), "현재 턴 프로필은 밝다 (%s)" % str(panel.modulate))
			else:
				_assert(panel.modulate.is_equal_approx(MainBoard.PROFILE_DIM) and panel.scale == Vector2.ONE, "다른 프로필은 어둡고 기본 크기다 (%s)" % str(panel.modulate))
	# 2x2 기물 슬롯: 완주/출전/대기 문구와 슬롯 수 (이동 도중 멈춘 상태에서 표본을 뽑아도 문구가 낡지 않도록 먼저 HUD를 최신 상태로 칠한다)
	_board._refresh_players()
	for other: int in [1, 2, 3, 4]:
		var slots: Array = _board._profiles[other]["slots"]
		_assert(slots.size() == 4, "프로필마다 기물 슬롯 4개")
		for index: int in slots.size():
			var pawn: PlayerPawn = _board.state.get_pawn(other * 10 + index + 1)
			var expected: String = "★완주" if pawn.is_finished else ("출전" if pawn.has_left_start else "대기")
			_assert((slots[index]["status"] as Label).text == expected, "기물 슬롯 상태 문구 (%s) P%d 말%d 실제=%s fin=%s left=%s" % [expected, other, index + 1, (slots[index]["status"] as Label).text, pawn.is_finished, pawn.has_left_start])
	var player_id: int = _board.manager.current_player_id()
	if _board.state.tools[player_id] is ToolRussianRoulette and not _board._is_bot_turn():
		var in_roll_phase: bool = _board.manager.current_state == TurnManager.State.PHASE_TURN_BEGIN or _board.manager.current_state == TurnManager.State.PHASE_ROLL_WAIT
		_assert(_board._roll_pad.kind == RollPad.Kind.REVOLVER and _board._stop_button.visible, "러시안 룰렛에서는 리볼버 패드 종류와 멈추기 버튼이 유지되어야 한다")
		if in_roll_phase:
			_assert(_board._roll_pad.visible, "굴릴 차례에는 방아쇠(리볼버 패드)가 보여야 한다")
		elif not _board._fx_busy and not _board._roll_pad.active:
			_assert(not _board._roll_pad.visible, "굴림이 끝나면 리볼버 패드는 지워져야 한다")
		_assert(_board._stop_button.disabled == not _board.state.tools[player_id].has_pending_state() or _board.manager.current_state != TurnManager.State.PHASE_ROLL_WAIT, "멈추기 버튼은 누적이 있을 때만 활성화")
		_roulette_seen += 1


## 기물 독의 [필살기 발동] 버튼을 눌러 본다: 룩은 아군 선택, 차는 즉시 돌진, 비행기는 타일 선택, 흑돌은 슬링샷 조준.
func _try_skill(manager: TurnManager, player_id: int) -> bool:
	if _board._is_bot_turn() or _rng.randi_range(0, 2) != 0:
		return false
	for index: int in _board.active_skill_buttons().size():
		var button: Button = _board.active_skill_buttons()[index]
		if not button.visible or button.disabled:
			continue
		var pawn: PlayerPawn = _board.state.get_pawn(_board._dock_owner() * 10 + index + 1)
		button.pressed.emit()
		match PawnCatalog.skill_of(pawn.sub_type()):
			&"castle", &"drop":
				if _board._choice_overlay != null:
					var picks: Array[Button] = []
					for node: Node in _board._choice_overlay.find_children("*", "Button", true, false):
						picks.append(node as Button)
					if not picks.is_empty():
						picks[0].pressed.emit()
					_board._close_choice()
			&"warp":
				if _board._tile_pick_active:
					_board._complete_tile_pick(PawnSkills.plane_targets(pawn)[_rng.randi_range(0, PawnSkills.plane_targets(pawn).size() - 1)])
			&"shoot":
				if _board._aim_pawn != -1:
					for step: int in 3:
						var event := InputEventMouseButton.new()
						event.button_index = MOUSE_BUTTON_LEFT
						event.pressed = step == 0
						event.position = Vector2(600, 300) if step == 0 else Vector2(600.0 - 20.0 * _rng.randi_range(1, 7), 300.0 + _rng.randi_range(-80, 80))
						if step == 1:
							var move := InputEventMouseMotion.new()
							move.position = event.position
							_board._input(move)
							continue
						_board._input(event)
		_skills += 1
		return true
	return false


func _try_turn_begin_buttons(manager: TurnManager) -> bool:
	var player_id: int = manager.current_player_id()
	for index: int in _board.active_skill_buttons().size():
		var pawn: PlayerPawn = _board.state.get_pawn(_board._dock_owner() * 10 + index + 1)
		_assert(_board.active_skill_buttons()[index].visible == (PawnSkills.has_skill(pawn) and not pawn.is_finished), "필살기 버튼은 필살기 보유 기물에만 보인다")
	if _try_skill(manager, player_id):
		return true
	for card_id: StringName in _board.state.hands[player_id]:
		if card_id == &"ACT_02" and not manager.card_played_this_turn() and not BangCommand.target_players(_board.state, player_id).is_empty() and _rng.randi_range(0, 1) == 0:
			_board._on_card_pressed(player_id, card_id)
			# 저격할 상대를 프로필에서 고른다
			_assert(_board._snipe_pick, "뱅! 저격은 상대 프로필 선택 모드로 들어간다")
			if _board._snipe_pick:
				_board._complete_snipe(BangCommand.target_players(_board.state, player_id)[0])
			_cards_played += 1
			_bangs += 1
			return true
	return false


## 반격 대기: 공격당한 사람이 반격 카드를 들고 있으면 가운데 반격 팝업(InterceptionPrompt)이 떠야 하고, [발동!]이나 [그냥 맞기]를 누른다.
func _react_in_window(manager: TurnManager) -> void:
	_assert(not _board._skip_button.visible, "예전 [개입 패스] 버튼은 더 이상 보이지 않는다")
	_board._update_reaction_popup(0.0)
	var holder: int = _board._reaction_holder()
	if holder == -1:
		manager.force_timeout()  # 봇의 반격 차례이거나 반격 대기가 아니다: 자동 진행
		return
	_assert(_board._reaction_popup != null and _board._reaction_popup.name == "InterceptionPrompt" and _board._reaction_use_button != null and _board._reaction_pass_button != null, "반격 팝업과 [발동!]/[그냥 맞기] 버튼이 떠야 한다")
	_assert(_board._hint_label.text.contains("팝업"), "팝업 안내 문구가 보여야 한다")
	_popups += 1
	if _rng.randi_range(0, 1) == 0:
		_board._reaction_use_button.pressed.emit()
		_cards_played += 1
	else:
		_board._reaction_pass_button.pressed.emit()


func _finish() -> bool:
	var manager: TurnManager = _board.manager
	var phase_names: Array[String] = []
	for phase: int in _seen_phases.keys():
		phase_names.append(str(phase))
	print("UI_SMOKE actions=%d round=%d game_over=%s winner=%d reason=%s phases=%d drafts=%s tile_picks=%d cards=%d evolutions=%d bombs_passed=%d skills=%d bangs=%d roulette=%d board_clicks=%d banner_picks=%d popups=%d stack_choices=%d ai=%s fog_checks=%d" % [_actions, _board.state.round_number, manager.is_game_over, _board.state.winner, VictoryChecker.reason_text(_board._last_reason), _seen_phases.size(), str(_draft_rounds), _tile_picks, _cards_played, _evolutions, _bombs_passed, _skills, _bangs, _roulette_seen, _board_clicks, _banner_picks, _popups, _stack_choices, str(_ai), _fog_checks])
	_assert(manager.is_game_over, "치트 없이 한 판이 끝까지 진행되어 승리자가 나와야 한다 (조작 %d회)" % _actions)
	_assert(_draft_rounds.has(1), "1라운드 드래프트가 열렸어야 한다")
	_assert(_board._result_overlay != null, "게임 종료 결과창이 떠야 한다")
	if _board._result_overlay != null:
		var restart_found: bool = false
		for node: Node in _board._result_overlay.find_children("*", "Button", true, false):
			if (node as Button).text == "같은 설정으로 바로 재시작":
				restart_found = true
		_assert(restart_found, "결과창에 [같은 설정으로 바로 재시작] 버튼이 있어야 한다")
		var lobby_found: bool = false
		for node: Node in _board._result_overlay.find_children("*", "Button", true, false):
			if (node as Button).text == "로비로 나가기":
				lobby_found = true
		_assert(lobby_found, "결과창에 [로비로 나가기] 버튼이 있어야 한다")
		var labels: String = ""
		for node: Node in _board._result_overlay.find_children("*", "Label", true, false):
			labels += (node as Label).text + "\n"
		_assert(labels.contains("플레이한 라운드") and labels.contains("승리 요인"), "결과창에 라운드 수와 승리 요인이 보여야 한다")
		var ranking: Node = _board._result_overlay.find_child("RankingList", true, false)
		_assert(ranking != null and ranking.get_child_count() == _board._player_ids.size(), "결과창에 참가자 수만큼 순위 줄이 있다")
		if ranking != null and ranking.get_child_count() > 0:
			_assert(int(ranking.get_child(0).get_meta("rank")) == 1 and int(ranking.get_child(0).get_meta("player")) == _board.state.winner, "1등 줄은 승자")
			for index: int in ranking.get_child_count():
				_assert(int(ranking.get_child(index).get_meta("rank")) == index + 1, "순위는 1등부터 차례대로")
	# 🏆 법전 슬롯 툴팁: 조건과 모두의 진행도
	_board.state.rulebook.set_laws_from_ids(["LAW_01"])
	_board._fill_law_tip(0)
	_assert(_board._tip_title.text.contains("투기장의 지배자"), "법전 툴팁 제목")
	_assert(_board._tip_skill.visible and _board._tip_skill.text.split("\n").size() == _board._player_ids.size() and _board._tip_skill.text.contains("/6 처치"), "법전 툴팁에 플레이어마다 진행도 줄: " + _board._tip_skill.text)
	for round_number: int in _draft_rounds:
		_assert(GameEnums.is_draft_round(round_number), "드래프트는 1라운드부터 3라운드마다만 열려야 한다 (%d)" % round_number)
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
