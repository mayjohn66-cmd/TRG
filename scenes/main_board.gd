# File: res://scenes/main_board.gd
# Class: class_name MainBoard
# Role: 로컬 핫시트 프로토타입 화면. 29칸 보드·4인 말·중앙 법전·손패를 기본 도형으로 그리고, TurnManager의 시그널만 구독하고 act()로만 행동을 보낸다
class_name MainBoard
extends Control

const PLAYER_IDS: Array[int] = [1, 2, 3, 4]
const PLAYER_COLORS: Dictionary = {
	1: Color("e5484d"),
	2: Color("3e8bff"),
	3: Color("30a46c"),
	4: Color("f5b700"),
}
const BOARD_ORIGIN: Vector2 = Vector2(74, 120)
const BOARD_SIZE: float = 540.0
const TILE_SIZE: float = 46.0
const PAWN_RADIUS: float = 6.5
const STEP_DELAY: float = 0.22
const PANEL_X: float = 700.0
const CELL_OFFSETS: Array[Vector2] = [Vector2(-10, -10), Vector2(10, -10), Vector2(-10, 10), Vector2(10, 10)]

const PHASE_NAMES: Dictionary = {
	TurnManager.State.PHASE_ROUND_START: "라운드 시작 (증강 드래프트)",
	TurnManager.State.PHASE_TURN_BEGIN: "턴 시작 - 카드·함정 사용 가능",
	TurnManager.State.PHASE_ROLL_WAIT: "판정 도구 굴리기",
	TurnManager.State.PHASE_INTERRUPT_ROLL: "개입 타이밍 A - 카드 사용 가능",
	TurnManager.State.PHASE_SELECT_PAWN: "이동할 말 선택",
	TurnManager.State.PHASE_MOVING_STEP: "이동 중...",
	TurnManager.State.PHASE_RESOLUTION: "정산 / 개입 타이밍 B - 카드 사용 가능",
	TurnManager.State.PHASE_NEUTRAL_NPC: "중립 NPC 페이즈",
}
const YUT_NAMES: Dictionary = {-1: "빽도", 1: "도", 2: "개", 3: "걸", 4: "윷", 5: "모"}
const HAND_NAMES: Dictionary = {
	&"high_card": "노페어", &"one_pair": "원페어", &"two_pair": "투페어", &"three_kind": "트리플",
	&"straight": "스트레이트", &"flush": "플러시", &"full_house": "풀하우스", &"four_kind": "포카드",
	&"straight_flush": "스트레이트 플러시",
}
const SLOT_SYMBOLS: Array[String] = ["체리", "레몬", "종", "BAR", "다이아", "7"]
const REJECT_REASONS: Dictionary = {
	&"wrong_phase": "지금은 할 수 없는 행동입니다",
	&"not_playable_now": "지금 단계에서는 쓸 수 없는 카드입니다",
	&"not_your_turn": "내 턴이 아닙니다",
	&"card_not_in_hand": "손패에 없는 카드입니다",
	&"invalid_target": "대상이 올바르지 않거나 조건을 만족하지 않습니다",
	&"invalid_pawn": "선택할 수 없는 말입니다",
	&"nothing_to_cash_out": "확정할 누적치가 없습니다",
	&"game_over": "게임이 끝났습니다",
}

var manager: TurnManager = null
var state: GameState = null

var _board_layer: Control = null
var _pawn_layer: Node2D = null
var _tile_views: Dictionary = {}
var _highlights: Dictionary = {}
var _trap_marks: Dictionary = {}
var _pawn_views: Dictionary = {}
var _npc_views: Dictionary = {}
var _flash_law_ids: Dictionary = {}

var _header_label: Label = null
var _phase_label: Label = null
var _queue_label: Label = null
var _player_labels: Dictionary = {}
var _law_labels: Array[Label] = []
var _roll_button: Button = null
var _stop_button: Button = null
var _bell_button: Button = null
var _skip_button: Button = null
var _hint_label: Label = null
var _pawn_buttons: Array[Button] = []
var _hand_boxes: Dictionary = {}
var _tool_option: OptionButton = null
var _card_option: OptionButton = null
var _timer_check: CheckBox = null
var _fruit_label: Label = null
var _log: RichTextLabel = null
var _banner: Label = null
var _choice_overlay: Control = null


func _ready() -> void:
	manager = TurnManager.new()
	manager.name = "TurnManager"
	manager.hotseat_mode = true
	manager.step_delay_sec = STEP_DELAY
	add_child(manager)
	manager.set_process(false)  # 제한 시간은 체크박스로 켤 때만 흐른다 (혼자 테스트할 때 자동 진행 방지)
	manager.phase_changed.connect(_on_phase_changed)
	manager.event_received.connect(_on_event)
	manager.action_rejected.connect(_on_action_rejected)
	manager.turn_order_reversed.connect(_on_turn_order_reversed)
	manager.game_over.connect(_on_game_over)
	_build_ui()
	_new_game()


func _process(_delta: float) -> void:
	if manager != null and manager.state != null and not manager.is_game_over:
		_phase_label.text = _phase_text()


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo or _choice_overlay != null:
		return
	if key_event.keycode == KEY_SPACE:
		_on_bell_pressed()
	elif key_event.keycode == KEY_R:
		_on_roll_pressed()


# ---------------------------------------------------------------------------
# 새 게임
# ---------------------------------------------------------------------------

func _new_game() -> void:
	_close_choice()
	for view: Node in _pawn_views.values():
		view.queue_free()
	for view: Node in _npc_views.values():
		view.queue_free()
	_pawn_views.clear()
	_npc_views.clear()
	_banner.visible = false
	_log.clear()
	manager.start_game(PLAYER_IDS, 0)
	state = manager.state
	_bind_state()
	_build_tiles_once()
	_build_pawn_views()
	_log_line("새 게임을 시작했습니다. 4인 핫시트: 버튼을 눌러 모든 플레이어를 번갈아 조작하세요.", Color("adb5bd"))
	_refresh_all()


func _bind_state() -> void:
	state.pawn_stepped.connect(_on_pawn_stepped)
	state.pawn_warped.connect(_on_pawn_stepped)
	state.pawn_sent_to_start.connect(func(pawn_id: int, _by: int) -> void: _log_line("%s 출발선으로 복귀" % _pawn_name(pawn_id), Color("ff8787")))
	state.pawn_finished.connect(func(pawn_id: int) -> void: _log_line("[완주] %s 완주!" % _pawn_name(pawn_id), Color("69db7c")))
	state.pawns_stacked.connect(func(leader_id: int, member_ids: Array[int]) -> void: _log_line("%s 업기 (%d마리)" % [_pawn_name(leader_id), member_ids.size()], Color("ffd43b")))
	state.pawns_swapped.connect(func(a_id: int, b_id: int) -> void: _log_line("%s ↔ %s 위치 교환" % [_pawn_name(a_id), _pawn_name(b_id)], Color("ffd43b")))
	state.attachment_triggered.connect(func(tile: int, _id: String, pawn_id: int, _cutscene: StringName) -> void: _log_line("[함정] 함정 발동! %d번 타일에서 %s" % [tile, _pawn_name(pawn_id)], Color("ff6b6b")))
	state.attachment_placed.connect(func(tile: int, _id: String, owner_id: int) -> void: _log_line("P%d가 %d번 타일에 함정을 설치했습니다 (뒷면)" % [owner_id, tile], Color("adb5bd")))
	state.card_drawn.connect(func(player_id: int, card_id: StringName) -> void: _log_line("[빵집] P%d 생떼 카드 획득: %s" % [player_id, _card_name(card_id)], Color("ffa94d")))
	state.card_stolen.connect(func(player_id: int, card_id: StringName) -> void: _log_line("P%d의 카드 [%s]를 도적이 빼앗았습니다" % [player_id, _card_name(card_id)], Color("ff6b6b")))
	state.npc_spawned.connect(func(_npc_id: int, _tile: int) -> void: _refresh_all())
	state.rulebook.law_added.connect(_on_law_added)
	state.rulebook.law_removed.connect(func(law: LawResource) -> void:
		_log_line("[법전] 교칙 파기: [%s] %s" % [law.law_id, law.law_name], Color("ff8787"))
		_refresh_laws())
	state.rulebook.law_applied.connect(_on_law_applied)


# ---------------------------------------------------------------------------
# UI 구성
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("1b1e24")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_header_label = _make_label("", 20, Color("f1f3f5"))
	_header_label.position = Vector2(24, 8)
	add_child(_header_label)
	_phase_label = _make_label("", 16, Color("ffd43b"))
	_phase_label.position = Vector2(24, 40)
	add_child(_phase_label)
	_queue_label = _make_label("", 13, Color("adb5bd"))
	_queue_label.position = Vector2(24, 66)
	add_child(_queue_label)

	_board_layer = Control.new()
	_board_layer.position = Vector2.ZERO
	add_child(_board_layer)
	_pawn_layer = Node2D.new()
	add_child(_pawn_layer)

	_banner = _make_label("", 40, Color("ffd43b"))
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.add_theme_color_override("font_outline_color", Color("111418"))
	_banner.position = Vector2(110, 360)
	_banner.visible = false
	add_child(_banner)

	var panel := VBoxContainer.new()
	panel.position = Vector2(PANEL_X, 8)
	panel.size = Vector2(650, 752)
	panel.add_theme_constant_override("separation", 3)
	add_child(panel)

	panel.add_child(_make_section("플레이어"))
	for player_id: int in PLAYER_IDS:
		var row: Label = _make_label("", 14, PLAYER_COLORS[player_id])
		_player_labels[player_id] = row
		panel.add_child(row)

	panel.add_child(_make_section("중앙 법전 (최대 4슬롯, 가득 차면 가장 오래된 교칙이 밀려남)"))
	for slot: int in GameEnums.MAX_LAWS:
		var law_label: Label = _make_label("", 13, Color("dee2e6"))
		_law_labels.append(law_label)
		panel.add_child(law_label)
	var law_buttons := HFlowContainer.new()
	law_buttons.add_theme_constant_override("h_separation", 4)
	law_buttons.add_theme_constant_override("v_separation", 3)
	panel.add_child(law_buttons)
	law_buttons.add_child(_make_label("교칙 추가(테스트):", 12, Color("868e96")))
	for law_id: String in LawRegistry.ALL_IDS:
		var sample: LawResource = LawRegistry.create(law_id)
		var law_button: Button = _make_button("%s %s" % [law_id.trim_prefix("LAW_"), sample.law_name], _on_add_law_pressed.bind(law_id), 11)
		law_button.tooltip_text = "[%s] %s\n%s\n(작동 시점: %s)" % [law_id, sample.law_name, sample.description, sample.trigger_timing]
		law_buttons.add_child(law_button)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	panel.add_child(action_row)
	_roll_button = _make_button("주사위 굴리기 (R)", _on_roll_pressed, 16)
	_roll_button.custom_minimum_size = Vector2(220, 40)
	action_row.add_child(_roll_button)
	_stop_button = _make_button("멈추고 이동 확정", _on_stop_pressed, 14)
	action_row.add_child(_stop_button)
	_bell_button = _make_button("종 치기 (Space)", _on_bell_pressed, 14)
	action_row.add_child(_bell_button)
	_skip_button = _make_button("카드 사용 끝 - 넘기기", _on_skip_pressed, 14)
	action_row.add_child(_skip_button)
	_hint_label = _make_label("", 13, Color("a5d8ff"))
	panel.add_child(_hint_label)
	_fruit_label = _make_label("", 12, Color("868e96"))
	panel.add_child(_fruit_label)

	var pawn_row := HBoxContainer.new()
	pawn_row.add_theme_constant_override("separation", 6)
	panel.add_child(pawn_row)
	pawn_row.add_child(_make_label("이동할 말:", 13, Color("adb5bd")))
	for slot: int in range(1, GameEnums.PAWNS_PER_PLAYER + 1):
		var pawn_button: Button = _make_button("말 %d" % slot, Callable(), 13)
		pawn_button.custom_minimum_size = Vector2(120, 30)
		_pawn_buttons.append(pawn_button)
		pawn_row.add_child(pawn_button)

	panel.add_child(_make_section("생떼 카드 손패 (클릭해서 해당 플레이어로 사용)"))
	for player_id: int in PLAYER_IDS:
		var hand_row := HBoxContainer.new()
		hand_row.add_theme_constant_override("separation", 4)
		panel.add_child(hand_row)
		_hand_boxes[player_id] = hand_row

	var debug_row := HFlowContainer.new()
	debug_row.add_theme_constant_override("h_separation", 6)
	debug_row.add_theme_constant_override("v_separation", 3)
	panel.add_child(debug_row)
	debug_row.add_child(_make_label("현재 플레이어 판정 도구:", 12, Color("868e96")))
	_tool_option = OptionButton.new()
	_tool_option.custom_minimum_size = Vector2(190, 0)
	for tool_id: StringName in ToolRegistry.ALL_IDS:
		_tool_option.add_item(ToolRegistry.create(tool_id).display_name)
	_tool_option.item_selected.connect(_on_tool_selected)
	debug_row.add_child(_tool_option)
	debug_row.add_child(_make_label("카드 지급:", 12, Color("868e96")))
	_card_option = OptionButton.new()
	_card_option.custom_minimum_size = Vector2(190, 0)
	for card_id: StringName in CardRegistry.DECK_COMPOSITION.keys():
		_card_option.add_item("%s %s" % [card_id, CardRegistry.get_card(card_id).display_name])
		_card_option.set_item_metadata(_card_option.item_count - 1, card_id)
	debug_row.add_child(_card_option)
	debug_row.add_child(_make_button("현재 플레이어에게", _on_grant_card_pressed, 12))
	debug_row.add_child(_make_button("도적 소환(10번)", _on_spawn_npc_pressed.bind(GameEnums.NpcBehavior.CHASE_NEAREST, 10), 12))
	debug_row.add_child(_make_button("고스트 소환(22번)", _on_spawn_npc_pressed.bind(GameEnums.NpcBehavior.PATROL_REVERSE, 22), 12))
	_timer_check = CheckBox.new()
	_timer_check.text = "제한 시간 사용"
	_timer_check.toggled.connect(func(enabled: bool) -> void: manager.set_process(enabled))
	debug_row.add_child(_timer_check)
	debug_row.add_child(_make_button("새 게임", _new_game, 12))

	panel.add_child(_make_section("로그"))
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.fit_content = false
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.custom_minimum_size = Vector2(0, 120)
	_log.add_theme_font_size_override("normal_font_size", 12)
	panel.add_child(_log)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_section(text: String) -> Label:
	var label: Label = _make_label(text, 13, Color("74c0fc"))
	label.add_theme_constant_override("line_spacing", 0)
	return label


func _make_button(text: String, callback: Callable, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	if callback.is_valid():
		button.pressed.connect(callback)
	return button


# ---------------------------------------------------------------------------
# 보드 / 말 그리기
# ---------------------------------------------------------------------------

## 타일 번호 -> 0~1 정규화 좌표. 출발선(0번)은 좌하단, 5번 우하단, 10번 우상단, 15번 좌상단 코너다.
static func tile_norm(index: int) -> Vector2:
	if index <= 5:
		return Vector2(index / 5.0, 1.0)
	if index <= 10:
		return Vector2(1.0, 1.0 - (index - 5) / 5.0)
	if index <= 15:
		return Vector2(1.0 - (index - 10) / 5.0, 0.0)
	if index <= 19:
		return Vector2(0.0, (index - 15) / 5.0)
	match index:
		20: return Vector2(5.0 / 6.0, 5.0 / 6.0)
		21: return Vector2(4.0 / 6.0, 4.0 / 6.0)
		22: return Vector2(0.5, 0.5)
		23: return Vector2(2.0 / 6.0, 2.0 / 6.0)
		24: return Vector2(1.0 / 6.0, 1.0 / 6.0)
		25: return Vector2(5.0 / 6.0, 1.0 / 6.0)
		26: return Vector2(4.0 / 6.0, 2.0 / 6.0)
		27: return Vector2(2.0 / 6.0, 4.0 / 6.0)
		28: return Vector2(1.0 / 6.0, 5.0 / 6.0)
	return Vector2(0.5, 0.5)


func _tile_center(index: int) -> Vector2:
	return BOARD_ORIGIN + tile_norm(index) * BOARD_SIZE


func _build_tiles_once() -> void:
	if not _tile_views.is_empty():
		return
	_add_track_line([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 0] as Array[int])
	_add_track_line([5, 20, 21, 22, 23, 24, 15] as Array[int])
	_add_track_line([10, 25, 26, 22, 27, 28, 0] as Array[int])
	for index: int in GameEnums.TILE_COUNT:
		var node: TileNode = state.board.get_tile(index)
		var tile := ColorRect.new()
		tile.size = Vector2(TILE_SIZE, TILE_SIZE)
		tile.position = _tile_center(index) - tile.size / 2.0
		tile.color = _tile_color(index, node.tile_type)
		_board_layer.add_child(tile)
		_tile_views[index] = tile

		var number := _make_label(str(index), 15, Color("212529") if _is_light_tile(index, node.tile_type) else Color("f8f9fa"))
		number.position = Vector2(3, 0)
		tile.add_child(number)
		var tag: String = _tile_tag(index, node.tile_type)
		if tag != "":
			var tag_label := _make_label(tag, 10, Color("212529") if _is_light_tile(index, node.tile_type) else Color("f8f9fa"))
			tag_label.position = Vector2(3, 29)
			tile.add_child(tag_label)
		var trap := ColorRect.new()
		trap.color = Color("c92a2a")
		trap.size = Vector2(10, 10)
		trap.position = Vector2(TILE_SIZE - 12, 2)
		trap.visible = false
		tile.add_child(trap)
		_trap_marks[index] = trap
		var highlight := ReferenceRect.new()
		highlight.border_color = Color("ffe066")
		highlight.border_width = 3.0
		highlight.editor_only = false
		highlight.size = tile.size
		highlight.visible = false
		tile.add_child(highlight)
		_highlights[index] = highlight


func _add_track_line(route: Array[int]) -> void:
	var line := Line2D.new()
	line.width = 4.0
	line.default_color = Color("495057")
	for tile_index: int in route:
		line.add_point(_tile_center(tile_index))
	_board_layer.add_child(line)


func _is_light_tile(index: int, tile_type: TileNode.TileType) -> bool:
	return tile_type == TileNode.TileType.NORMAL and index < GameEnums.OUTER_TRACK_SIZE and not [5, 10, 15].has(index)


func _tile_color(index: int, tile_type: TileNode.TileType) -> Color:
	match tile_type:
		TileNode.TileType.START_GOAL: return Color("2f9e44")
		TileNode.TileType.BAKERY: return Color("e8890c")
		TileNode.TileType.PORTAL: return Color("9c36b5")
	if index == GameEnums.CENTER_TILE:
		return Color("b8860b")
	if [5, 10, 15].has(index):
		return Color("495057")
	if index >= GameEnums.OUTER_TRACK_SIZE:
		return Color("1c5d99")
	return Color("ced4da")


func _tile_tag(index: int, tile_type: TileNode.TileType) -> String:
	match tile_type:
		TileNode.TileType.START_GOAL: return "출발/결승"
		TileNode.TileType.BAKERY: return "빵집"
		TileNode.TileType.PORTAL: return "옷장"
	if index == GameEnums.CENTER_TILE:
		return "중앙"
	if index == 5 or index == 10:
		return "코너↘" if index == 5 else "코너↙"
	if index == 15:
		return "합류"
	return ""


func _build_pawn_views() -> void:
	for pawn: PlayerPawn in state.pawns:
		var view := Node2D.new()
		var body := Polygon2D.new()
		body.polygon = _circle_points(PAWN_RADIUS, 20)
		body.color = PLAYER_COLORS[pawn.owner_id]
		view.add_child(body)
		var ring := Line2D.new()
		ring.width = 1.5
		ring.default_color = Color("f8f9fa")
		ring.closed = true
		for point: Vector2 in _circle_points(PAWN_RADIUS, 20):
			ring.add_point(point)
		view.add_child(ring)
		var number := _make_label(str(pawn.slot), 10, Color("111111"))
		number.position = Vector2(-4, -8)
		view.add_child(number)
		var badge := _make_label("", 11, Color("ffffff"))
		badge.position = Vector2(5, -17)
		badge.name = "Badge"
		view.add_child(badge)
		view.position = _pawn_position(pawn)
		_pawn_layer.add_child(view)
		_pawn_views[pawn.entity_id] = view


func _circle_points(radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in count:
		var angle: float = TAU * i / count
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _pawn_position(pawn: PlayerPawn) -> Vector2:
	var owner_index: int = PLAYER_IDS.find(pawn.owner_id)
	var micro := Vector2(((pawn.slot - 1) % 2) * 7.0 - 3.5, ((pawn.slot - 1) / 2) * 7.0 - 3.5)
	var position_in_tile: Vector2 = _tile_center(pawn.current_tile_idx) + CELL_OFFSETS[owner_index] + micro
	if pawn.is_finished:
		position_in_tile = _tile_center(GameEnums.GOAL_TILE) + Vector2(-26 + owner_index * 17 + (pawn.slot - 1) * 3.0, 44)
	return position_in_tile


func _refresh_pawns() -> void:
	for pawn: PlayerPawn in state.pawns:
		var view: Node2D = _pawn_views.get(pawn.entity_id)
		if view == null:
			continue
		if view.has_meta("tween"):
			var running: Tween = view.get_meta("tween")
			if running != null and running.is_valid():
				running.kill()
		view.position = _pawn_position(pawn)
		view.visible = pawn.carrier == null
		view.modulate = Color(1, 1, 1, 0.45) if pawn.is_finished else Color.WHITE
		var badge: Label = view.get_node("Badge")
		badge.text = "x%d" % (pawn.carried.size() + 1) if not pawn.carried.is_empty() else ""
	for npc: NeutralNPC in state.npcs:
		if not _npc_views.has(npc.entity_id):
			var marker := Polygon2D.new()
			marker.polygon = PackedVector2Array([Vector2(0, -11), Vector2(10, 0), Vector2(0, 11), Vector2(-10, 0)])
			marker.color = Color("fa5252") if npc.behavior == GameEnums.NpcBehavior.CHASE_NEAREST else Color("da77f2")
			var caption := _make_label("도적" if npc.behavior == GameEnums.NpcBehavior.CHASE_NEAREST else "고스트", 10, Color.WHITE)
			caption.position = Vector2(-12, 11)
			marker.add_child(caption)
			_pawn_layer.add_child(marker)
			_npc_views[npc.entity_id] = marker
		(_npc_views[npc.entity_id] as Node2D).position = _tile_center(npc.current_tile_idx) + Vector2(0, -26)
	for npc_id: int in _npc_views.keys():
		if state.get_npc(npc_id) == null:
			(_npc_views[npc_id] as Node).queue_free()
			_npc_views.erase(npc_id)


func _refresh_tiles() -> void:
	for index: int in GameEnums.TILE_COUNT:
		(_trap_marks[index] as ColorRect).visible = not state.board.get_tile(index).attachments.is_empty()


func _on_pawn_stepped(pawn_id: int, _from_tile: int, _to_tile: int) -> void:
	var view: Node2D = _pawn_views.get(pawn_id)
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	if view == null or pawn == null:
		return
	if view.has_meta("tween"):
		var previous: Tween = view.get_meta("tween")
		if previous != null and previous.is_valid():
			previous.kill()
	var tween: Tween = create_tween()
	tween.tween_property(view, "position", _pawn_position(pawn), maxf(STEP_DELAY * 0.85, 0.05))
	view.set_meta("tween", tween)


# ---------------------------------------------------------------------------
# 갱신
# ---------------------------------------------------------------------------

func _refresh_all() -> void:
	if state == null:
		return
	_refresh_header()
	_refresh_players()
	_refresh_laws()
	_refresh_tiles()
	_refresh_pawns()
	_refresh_hands()
	_refresh_controls()


func _phase_text() -> String:
	var text: String = PHASE_NAMES[manager.current_state]
	if _timer_check.button_pressed and manager.phase_time_left > 0.0:
		text += "  (%.1f초)" % manager.phase_time_left
	return text


func _refresh_header() -> void:
	var player_id: int = manager.current_player_id()
	var direction: String = "정방향 ▶" if manager.turn_direction == 1 else "역방향 ◀"
	var reverse_text: String = "  |  이동 역주행 %d라운드" % state.reverse_move_rounds_left if state.reverse_move_rounds_left > 0 else ""
	_header_label.text = "라운드 %d   현재 턴: P%d   턴 방향: %s%s" % [state.round_number, player_id, direction, reverse_text]
	_header_label.add_theme_color_override("font_color", PLAYER_COLORS[player_id])
	_phase_label.text = _phase_text()
	var queue_text: String = "남은 이동 대기열: %s" % str(manager.move_queue) if not manager.move_queue.is_empty() else ""
	if manager.command_stack != null and manager.command_stack.interrupt_count() > 0:
		queue_text += "   개입 대기 카드: %d장 (나중에 낸 카드부터 실행)" % manager.command_stack.interrupt_count()
	_queue_label.text = queue_text


func _refresh_players() -> void:
	for player_id: int in PLAYER_IDS:
		var finished: int = 0
		for pawn: PlayerPawn in state.pawns_of(player_id):
			if pawn.is_finished:
				finished += 1
		var tool: BaseJudgmentTool = state.tools[player_id]
		var marker: String = "▶" if player_id == manager.current_player_id() else "  "
		(_player_labels[player_id] as Label).text = "%s P%d   완주 %d/4   카드 %d장   도구: %s" % [marker, player_id, finished, (state.hands[player_id] as Array).size(), tool.display_name]


func _refresh_laws() -> void:
	for slot: int in _law_labels.size():
		var label: Label = _law_labels[slot]
		if slot < state.rulebook.active_laws_queue.size():
			var law: LawResource = state.rulebook.active_laws_queue[slot]
			label.text = "슬롯 %d  [%s] %s - %s" % [slot + 1, law.law_id, law.law_name, law.description]
			label.add_theme_color_override("font_color", Color("ffe066") if _flash_law_ids.has(law.law_id) else Color("dee2e6"))
		else:
			label.text = "슬롯 %d  (비어 있음)" % (slot + 1)
			label.add_theme_color_override("font_color", Color("5c6068"))


func _refresh_hands() -> void:
	for player_id: int in PLAYER_IDS:
		var row: HBoxContainer = _hand_boxes[player_id]
		for child: Node in row.get_children():
			child.queue_free()
		var title: Label = _make_label("P%d 손패:" % player_id, 13, PLAYER_COLORS[player_id])
		title.custom_minimum_size = Vector2(70, 0)
		row.add_child(title)
		var hand: Array = state.hands[player_id]
		if hand.is_empty():
			row.add_child(_make_label("(없음)", 12, Color("5c6068")))
		for card_id: StringName in hand:
			var card: BaseCard = CardRegistry.get_card(card_id)
			var button: Button = _make_button(card.display_name, _on_card_pressed.bind(player_id, card_id), 12)
			button.tooltip_text = "%s (%s)" % [card.display_name, card_id]
			button.disabled = not _card_usable_now(player_id, card)
			row.add_child(button)


func _card_usable_now(player_id: int, card: BaseCard) -> bool:
	if manager.is_game_over or not card.is_playable_in(manager.current_state):
		return false
	if manager.current_state == TurnManager.State.PHASE_TURN_BEGIN and player_id != manager.current_player_id():
		return false
	return true


func _refresh_controls() -> void:
	var player_id: int = manager.current_player_id()
	var current_phase: TurnManager.State = manager.current_state
	var tool: BaseJudgmentTool = state.tools[player_id]
	var over: bool = manager.is_game_over
	var can_roll: bool = not over and (current_phase == TurnManager.State.PHASE_TURN_BEGIN or current_phase == TurnManager.State.PHASE_ROLL_WAIT)
	_roll_button.disabled = not can_roll
	if tool is ToolRussianRoulette:
		_roll_button.text = "방아쇠 당기기 (R)"
	else:
		_roll_button.text = "주사위 굴리기 (R) - %s" % tool.display_name
	_stop_button.visible = tool.has_pending_state() and current_phase == TurnManager.State.PHASE_ROLL_WAIT
	if tool is ToolRussianRoulette:
		_stop_button.text = "멈추고 %d칸 이동" % (tool as ToolRussianRoulette).accumulated
	_bell_button.visible = tool is ToolHalliGalli
	_fruit_label.visible = tool is ToolHalliGalli
	if tool is ToolHalliGalli:
		_fruit_label.text = "바닥 과일 합계 %s - 어느 한 과일이 5개면 종을 치세요 (적립 보너스 +%d칸)" % [str((tool as ToolHalliGalli).fruit_totals), (tool as ToolHalliGalli).banked_bonus]
	var window_open: bool = not over and (current_phase == TurnManager.State.PHASE_INTERRUPT_ROLL or current_phase == TurnManager.State.PHASE_RESOLUTION or current_phase == TurnManager.State.PHASE_ROUND_START)
	_skip_button.visible = window_open
	_hint_label.text = _hint_text(current_phase, tool)

	var selecting: bool = not over and current_phase == TurnManager.State.PHASE_SELECT_PAWN
	for index: int in _pawn_buttons.size():
		var button: Button = _pawn_buttons[index]
		var pawn: PlayerPawn = state.get_pawn(player_id * 10 + index + 1)
		for connection: Dictionary in button.pressed.get_connections():
			button.pressed.disconnect(connection["callable"])
		for connection: Dictionary in button.mouse_entered.get_connections():
			button.mouse_entered.disconnect(connection["callable"])
		for connection: Dictionary in button.mouse_exited.get_connections():
			button.mouse_exited.disconnect(connection["callable"])
		button.text = "말 %d (%s)" % [pawn.slot, "완주" if pawn.is_finished else "%d번" % pawn.current_tile_idx]
		button.disabled = not selecting or not pawn.is_selectable()
		button.pressed.connect(_on_pawn_pressed.bind(pawn.entity_id))
		button.mouse_entered.connect(_preview_pawn.bind(pawn.entity_id))
		button.mouse_exited.connect(_clear_highlight)
	_tool_option.disabled = over or not (current_phase == TurnManager.State.PHASE_TURN_BEGIN or current_phase == TurnManager.State.PHASE_ROLL_WAIT) or tool.has_pending_state()
	var tool_index: int = ToolRegistry.ALL_IDS.find(tool.tool_id)
	if tool_index != -1:
		_tool_option.select(tool_index)


func _hint_text(current_phase: TurnManager.State, tool: BaseJudgmentTool) -> String:
	if manager.is_game_over:
		return "게임 종료. [새 게임]으로 다시 시작하세요."
	match current_phase:
		TurnManager.State.PHASE_TURN_BEGIN:
			return "카드를 쓰거나 [굴리기]를 누르세요. (판정 도구: %s)" % tool.display_name
		TurnManager.State.PHASE_ROLL_WAIT:
			if tool.has_pending_state():
				return "계속 당기거나, 멈추고 누적 칸수만큼 이동하세요. 실탄이 나오면 모두 증발합니다!"
			return "다시 굴려야 합니다 (재굴림)." if not manager.move_queue.is_empty() else "굴리세요."
		TurnManager.State.PHASE_INTERRUPT_ROLL:
			return "눈금이 정해졌습니다. 개입 카드를 낼 플레이어는 지금 카드를 누르세요. 끝나면 [넘기기]."
		TurnManager.State.PHASE_SELECT_PAWN:
			return "이동할 말을 고르세요 (버튼에 마우스를 올리면 도착 경로가 노란 테두리로 보입니다)."
		TurnManager.State.PHASE_RESOLUTION:
			return "정산 완료. 잡힌 플레이어는 [바이츠 더 더스트]로 되감을 수 있습니다. 끝나면 [넘기기]."
		TurnManager.State.PHASE_MOVING_STEP:
			return "말이 한 칸씩 이동합니다..."
	return ""


# ---------------------------------------------------------------------------
# 버튼 입력 (모든 행동은 TurnManager.act()로만 보낸다)
# ---------------------------------------------------------------------------

func _act(action: StringName, params: Dictionary = {}) -> void:
	if params.get("player_id") == null:
		params["player_id"] = manager.current_player_id()
	manager.act(action, params)
	_refresh_all()


func _on_roll_pressed() -> void:
	if manager.is_game_over or _roll_button.disabled:
		return
	if manager.current_state == TurnManager.State.PHASE_TURN_BEGIN:
		_act(&"proceed")
	if manager.current_state == TurnManager.State.PHASE_ROLL_WAIT:
		_act(&"roll")


func _on_stop_pressed() -> void:
	_act(&"stop")


func _on_bell_pressed() -> void:
	if state != null and state.tools[manager.current_player_id()] is ToolHalliGalli:
		_act(&"bell")


func _on_skip_pressed() -> void:
	manager.force_timeout()
	_refresh_all()


func _on_pawn_pressed(pawn_id: int) -> void:
	_clear_highlight()
	_act(&"select_pawn", {"pawn_id": pawn_id})


func _on_add_law_pressed(law_id: String) -> void:
	if state.rulebook.has_law(law_id):
		_log_line("[%s]는 이미 법전에 있습니다." % law_id, Color("868e96"))
		return
	state.rulebook.enqueue_law(LawRegistry.create(law_id))
	_refresh_all()


func _on_tool_selected(index: int) -> void:
	var player_id: int = manager.current_player_id()
	var new_tool: BaseJudgmentTool = ToolRegistry.create(ToolRegistry.ALL_IDS[index])
	if new_tool is ToolHalliGalli:
		new_tool.on_turn_begin(state.rng)
	state.tools[player_id] = new_tool
	_log_line("P%d의 판정 도구를 [%s](으)로 바꿨습니다." % [player_id, new_tool.display_name], Color("adb5bd"))
	_refresh_all()


func _on_grant_card_pressed() -> void:
	var card_id: StringName = _card_option.get_item_metadata(_card_option.selected)
	if not state.give_card(manager.current_player_id(), card_id):
		_log_line("손패가 가득 찼습니다.", Color("868e96"))
	_refresh_all()


func _on_spawn_npc_pressed(behavior: GameEnums.NpcBehavior, tile: int) -> void:
	var display_id: StringName = &"SUM_01" if behavior == GameEnums.NpcBehavior.CHASE_NEAREST else &"SUM_02"
	state.spawn_npc(tile, behavior, manager.current_player_id(), display_id)
	_log_line("중립 NPC 소환! 라운드가 끝날 때 움직입니다.", Color("fa5252"))
	_refresh_all()


func _on_card_pressed(player_id: int, card_id: StringName) -> void:
	var card: BaseCard = CardRegistry.get_card(card_id)
	match card_id:
		&"ACT_04":
			var options: Array[Dictionary] = []
			for pawn: PlayerPawn in state.pawns_of(player_id):
				if card.can_play(state, player_id, {"pawn_id": pawn.entity_id}):
					options.append({"label": "말 %d (%d번 타일)" % [pawn.slot, pawn.current_tile_idx], "value": pawn.entity_id})
			if options.is_empty():
				_log_line("[%s] 0번에서 빽도로 후퇴해 19/28번에 있는 말이 필요합니다." % card.display_name, Color("868e96"))
				return
			_show_choice("완주시킬 말을 고르세요", options, _play_card_with.bind(player_id, card_id, "pawn_id"))
		&"ACT_06":
			var options: Array[Dictionary] = []
			for law: LawResource in state.rulebook.active_laws_queue:
				options.append({"label": "[%s] %s" % [law.law_id, law.law_name], "value": law.law_id})
			if options.is_empty():
				_log_line("파기할 교칙이 법전에 없습니다.", Color("868e96"))
				return
			_show_choice("이의 있음! 파기할 교칙을 고르세요", options, _play_card_with.bind(player_id, card_id, "law_id"))
		&"TRP_01":
			var options: Array[Dictionary] = []
			for tile: int in range(1, GameEnums.TILE_COUNT):
				if card.can_play(state, player_id, {"tile": tile}):
					options.append({"label": str(tile), "value": tile})
			_show_choice("함정을 설치할 타일 번호", options, _play_card_with.bind(player_id, card_id, "tile"), 7)
		_:
			_act(&"play_card", {"player_id": player_id, "card_id": card_id})


func _play_card_with(value: Variant, player_id: int, card_id: StringName, param_name: String) -> void:
	_act(&"play_card", {"player_id": player_id, "card_id": card_id, param_name: value})


# ---------------------------------------------------------------------------
# 선택 오버레이 / 경로 미리보기
# ---------------------------------------------------------------------------

func _show_choice(title: String, options: Array[Dictionary], on_pick: Callable, columns: int = 1) -> void:
	_close_choice()
	_choice_overlay = Control.new()
	_choice_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_choice_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_choice_overlay.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(_make_label(title, 16, Color("f1f3f5")))
	var grid := GridContainer.new()
	grid.columns = columns
	box.add_child(grid)
	for option: Dictionary in options:
		var button: Button = _make_button(str(option["label"]), _on_choice_picked.bind(option["value"], on_pick), 14)
		button.custom_minimum_size = Vector2(60, 32)
		grid.add_child(button)
	box.add_child(_make_button("취소", _close_choice, 13))
	add_child(_choice_overlay)


func _on_choice_picked(value: Variant, on_pick: Callable) -> void:
	_close_choice()
	on_pick.call(value)


func _close_choice() -> void:
	if _choice_overlay != null:
		_choice_overlay.queue_free()
		_choice_overlay = null


func _preview_pawn(pawn_id: int) -> void:
	_clear_highlight()
	if manager.current_state != TurnManager.State.PHASE_SELECT_PAWN or manager.move_queue.is_empty():
		return
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	if pawn == null or not pawn.is_selectable():
		return
	var ctx := RuleContext.new()
	ctx.state = state
	ctx.actor_id = pawn.owner_id
	ctx.dice_value = manager.move_queue[0]
	ctx.direction = state.movement_direction()
	ctx.pawn = pawn
	ctx.trigger_timing = RuleContext.ON_MOVE_CALC
	ctx = state.rulebook.process_context(ctx)
	for tile: int in state.board.calculate_path(pawn, ctx.dice_value * ctx.direction, ctx):
		(_highlights[tile] as ReferenceRect).visible = true


func _clear_highlight() -> void:
	for highlight: ReferenceRect in _highlights.values():
		highlight.visible = false


# ---------------------------------------------------------------------------
# 엔진 이벤트 -> 화면/로그
# ---------------------------------------------------------------------------

func _on_phase_changed(_new_state: TurnManager.State, _player_id: int, _limit: float) -> void:
	_refresh_all()


func _on_action_rejected(player_id: int, action: StringName, reason: StringName) -> void:
	_log_line("P%d %s 거부: %s" % [player_id, action, REJECT_REASONS.get(reason, str(reason))], Color("ff8787"))


func _on_turn_order_reversed(new_direction: int) -> void:
	_log_line("[리버스] 우노 리버스! 턴 방향이 %s이 되었습니다." % ("정방향" if new_direction == 1 else "역방향"), Color("ffd43b"))
	_refresh_all()


func _on_game_over(winner_id: int, reason: StringName) -> void:
	_banner.text = "P%d 승리!  (%s)" % [winner_id, "특수 승리: 천하제일 4업" if reason == &"yut_four_stack" else "4개 말 모두 완주"]
	_banner.add_theme_color_override("font_color", PLAYER_COLORS[winner_id])
	_banner.visible = true
	_log_line("[승리] P%d 승리! (%s)" % [winner_id, reason], PLAYER_COLORS[winner_id])
	_refresh_all()


func _on_law_added(new_law: LawResource, removed_law: LawResource) -> void:
	var text: String = "[법전] 교칙 제정: [%s] %s" % [new_law.law_id, new_law.law_name]
	if removed_law != null:
		text += "  (가장 오래된 [%s] %s이(가) 밀려났습니다)" % [removed_law.law_id, removed_law.law_name]
	_log_line(text, Color("ffe066"))
	_refresh_laws()


func _on_law_applied(law: LawResource, timing: String, dice_before: int, dice_after: int) -> void:
	var detail: String = ""
	if dice_before != dice_after:
		detail = "  눈금 %d → %d" % [dice_before, dice_after]
	_log_line("[법전] [%s] %s 작동 (%s)%s" % [law.law_id, law.law_name, timing, detail], Color("ffe066"))
	_flash_law_ids[law.law_id] = true
	_refresh_laws()
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		_flash_law_ids.erase(law.law_id)
		if state != null:
			_refresh_laws())


func _on_event(kind: StringName, data: Dictionary) -> void:
	match kind:
		&"roll_resolved": _log_roll(data)
		&"move_resolved": _log_move(data)
		&"card_played":
			var card: BaseCard = CardRegistry.get_card(data["card_id"])
			_log_line("[카드] P%d [%s] 사용%s" % [data["player_id"], card.display_name, " (개입 대기열 - 나중에 낸 카드부터 실행)" if data["queued"] else ""], Color("74c0fc"))
		&"bell_result":
			_log_line("P%d 종 %s" % [data["player_id"], "성공! 보너스 +2 적립" if data["success"] else "실패"], Color("ffa94d"))
		&"npc_phase_resolved":
			for report: Dictionary in data["reports"]:
				_log_line("[NPC] NPC가 %s로 이동 (잡힌 말: %s)" % [str(report["path"]), str(report["caught"])], Color("fa5252"))
		&"augment_offers": _log_line("증강 드래프트가 열렸습니다.", Color("adb5bd"))
	_refresh_all()


func _log_roll(data: Dictionary) -> void:
	var result: Dictionary = data["result"]
	var details: Dictionary = result["details"]
	var text: String = "[굴림] P%d [%s] " % [data["player_id"], state.tools[data["player_id"]].display_name]
	match result["tool_id"]:
		&"YUT": text += "%s (%d칸)" % [YUT_NAMES.get(result["steps"], "?"), result["steps"]]
		&"HOLDEM": text += "%s → %d칸" % [HAND_NAMES.get(details["hand"], "?"), result["steps"]]
		&"SLOT_777":
			var symbols: Array[String] = []
			for reel: int in details["reels"]:
				symbols.append(SLOT_SYMBOLS[reel])
			text += "%s → %d칸" % [" | ".join(symbols), result["steps"]]
		&"HALLI_GALLI": text += "기본 %d + 보너스 %d = %d칸" % [details["base"], details["bonus"], result["steps"]]
		&"REVOLVER":
			if details["fired"]:
				text += "탕! 누적 %d칸 증발, 턴 종료" % details["lost"]
			else:
				text += "찰칵(빈 총) 누적 %d칸" % result["steps"]
		_: text += "%d칸" % result["steps"]
	if result["reroll"]:
		text += "  ★ 재굴림!"
	_log_line(text, Color("f1f3f5"))


func _log_move(data: Dictionary) -> void:
	var pawn_id: int = data["pawn_id"]
	var text: String = "[이동] %s 이동" % _pawn_name(pawn_id)
	if data["canceled"]:
		text += " 취소됨 (교칙)"
	else:
		text += " 경로 %s" % str(data["path"])
	if data["bounced"]:
		text += "  결승선에서 튕겨 나옴"
	if data["warped"]:
		text += "  옷장 워프 → 중앙"
	if data["stopped_early"]:
		text += "  이동 중단"
	if not (data["captured"] as Array).is_empty():
		text += "  [잡기] 잡음 %s" % str(data["captured"])
	if data["extra_turn"]:
		text += "  (추가 턴)"
	if data["drawn_card"] != &"":
		text += "  [빵집] 카드 획득"
	if not (data["effects"] as Array).is_empty():
		text += "  교칙 효과 %s" % str(data["effects"])
	_log_line(text, PLAYER_COLORS[state.get_pawn(pawn_id).owner_id])


func _log_line(text: String, color: Color) -> void:
	if _log == null:
		return
	_log.append_text("[color=#%s]%s[/color]\n" % [color.to_html(false), text])


func _pawn_name(pawn_id: int) -> String:
	var pawn: PlayerPawn = state.get_pawn(pawn_id) if state != null else null
	if pawn == null:
		return "말#%d" % pawn_id
	return "P%d-말%d" % [pawn.owner_id, pawn.slot]


func _card_name(card_id: StringName) -> String:
	var card: BaseCard = CardRegistry.get_card(card_id)
	return card.display_name if card != null else str(card_id)
