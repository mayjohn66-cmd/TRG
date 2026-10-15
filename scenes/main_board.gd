# File: res://scenes/main_board.gd
# Class: class_name MainBoard
# Role: 로컬 핫시트 플레이 화면. 29칸 보드·4인 말·중앙 법전·손패·증강 드래프트·타일 선택 모드·결과창을 기본 도형으로 그리고, TurnManager의 시그널만 구독하며 act()로만 행동을 보낸다
class_name MainBoard
extends Control

const PLAYER_IDS: Array[int] = [1, 2, 3, 4]
const PLAYER_COLORS: Dictionary = {
	1: Color("e5484d"),
	2: Color("3e8bff"),
	3: Color("30a46c"),
	4: Color("f5b700"),
}
const BOARD_ORIGIN: Vector2 = Vector2(483, 108)
const BOARD_SIZE: float = 400.0
const TILE_SIZE: float = 40.0
const PAWN_RADIUS: float = 5.5
const STEP_DELAY: float = 0.22
const CELL_OFFSETS: Array[Vector2] = [Vector2(-6, -5), Vector2(6, -5), Vector2(-6, 3), Vector2(6, 3)]
const CARD_SIZE: Vector2 = Vector2(100, 140)
const PROFILE_SIZE: Vector2 = Vector2(300, 124)
## 프로필 HUD 카드의 모서리 위치(코너 번호): 0 우하단(로컬 플레이어) / 1 우상단 / 2 좌상단 / 3 좌하단 (출발선 0번이 우하단이라 반시계 턴 순서와 같다).
const CORNER_POSITIONS: Array[Vector2] = [
	Vector2(1058, 636),
	Vector2(1058, 48),
	Vector2(8, 48),
	Vector2(8, 636),
]
## 카드 독 안에서 카드가 놓이는 기준 y (호버 시 15px 솟아오른다).
const DOCK_CARD_Y: float = 8.0
## 호버 툴팁이 뜨기까지 커서를 가만히 대고 있어야 하는 시간(초).
const TIP_DELAY: float = 0.35
const COLOR_BG: Color = Color("0d1018")
const COLOR_PANEL: Color = Color("1a2030")
const COLOR_PANEL_EDGE: Color = Color("39435c")
const COLOR_GOLD: Color = Color("ffd43b")
const CARD_CATEGORY_COLORS: Dictionary = {
	GameEnums.CardCategory.INSTANT: Color("ff922b"),
	GameEnums.CardCategory.TRAP: Color("be4bdb"),
	GameEnums.CardCategory.SUMMON: Color("20c997"),
}
const CARD_CATEGORY_NAMES: Dictionary = {
	GameEnums.CardCategory.INSTANT: "즉발",
	GameEnums.CardCategory.TRAP: "함정",
	GameEnums.CardCategory.SUMMON: "소환",
}
## 카드 프레임 하단에 보여 주는 한 줄 요약.
const CARD_SUMMARIES: Dictionary = {
	&"ACT_01": "턴 순서를 뒤집고 1라운드 동안 역주행",
	&"ACT_02": "앞뒤 3칸 안의 선두 적을 자동 저격. 회피하면 카드 1장 버림",
	&"ACT_03": "다음 플레이어 4칸 후퇴. 즉발 카드로 -8 떠넘김",
	&"ACT_04": "0번에서 후퇴해 19/28번에 선 말을 완주",
	&"ACT_05": "잡히거나 함정을 밟은 턴을 되감기",
	&"ACT_06": "법전의 교칙 1개를 강제 파기",
	&"TRP_01": "타일에 뒷면 함정 설치 (타일 선택)",
	&"TRP_02": "눈금 4 이상으로 지나는 적을 2턴 구속",
	&"TRP_03": "지뢰 + 양옆 [1]. 밟으면 반경 2칸 추방",
	&"TRP_04": "코너를 무인도로. 짝수가 나와야 탈출",
	&"SUM_01": "도적 NPC 소환. 가까운 말 추격",
	&"SUM_02": "중앙에 고스트 소환. 역주행 순찰",
}


## 비어 있는 법전 슬롯에 그리는 어두운 점선 테두리.
class DashedBorder extends Control:
	var line_color: Color = Color("4a5368")

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var area := Rect2(Vector2(3, 3), size - Vector2(6, 6))
		var corners: Array[Vector2] = [area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)]
		for index: int in 4:
			draw_dashed_line(corners[index], corners[(index + 1) % 4], line_color, 2.0, 6.0)


const PHASE_NAMES: Dictionary = {
	TurnManager.State.PHASE_ROUND_START: "라운드 시작 - 증강 드래프트",
	TurnManager.State.PHASE_TURN_BEGIN: "턴 시작 - 카드·함정·소환 사용 가능",
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
	&"invalid_index": "올바르지 않은 선택입니다",
	&"nothing_to_cash_out": "확정할 누적치가 없습니다",
	&"game_over": "게임이 끝났습니다",
	&"ambiguous_pair": "교환할 체스 기물 두 개를 골라야 합니다",
	&"no_instant_card": "떠넘길 즉발 카드가 없습니다",
}
const CATEGORY_COLORS: Dictionary = {
	GameEnums.AugmentCategory.PAWN_EVOLUTION: Color("ffa94d"),
	GameEnums.AugmentCategory.TOOL_SWAP: Color("74c0fc"),
	GameEnums.AugmentCategory.LAW_ENACT: Color("ffe066"),
	GameEnums.AugmentCategory.CARD_PACKAGE: Color("da77f2"),
}

## 이 화면을 보는 플레이어. 이 플레이어의 프로필·기물 독이 우측 하단에 놓인다 (멀티플레이에서 P2~P4로 접속해도 본인이 우측 하단).
var local_player_id: int = 1
var manager: TurnManager = null
var state: GameState = null

var _board_layer: Control = null
var _pawn_layer: Node2D = null
var _tile_views: Dictionary = {}
var _highlights: Dictionary = {}
var _pick_marks: Dictionary = {}
var _tile_marks: Dictionary = {}
var _pawn_views: Dictionary = {}
var _npc_views: Dictionary = {}
var _flash_law_ids: Dictionary = {}

var _ribbon: PanelContainer = null
var _header_label: Label = null
var _toast_label: Label = null
var _phase_label: Label = null
var _queue_label: Label = null
var _pick_banner: Label = null
var _tag_labels: Dictionary = {}
var _board_hover_pawn: int = -1
var _profiles: Dictionary = {}
var _law_slots: Array[PanelContainer] = []
var _law_labels: Array[Label] = []
var _law_descs: Array[Label] = []
var _law_badges: Array[PanelContainer] = []
var _law_badge_labels: Array[Label] = []
var _law_dashes: Array[Control] = []
var _roll_button: Button = null
var _stop_button: Button = null
var _bell_button: Button = null
var _skip_button: Button = null
var _castle_button: Button = null
var _bomb_button: Button = null
var _new_game_button: Button = null
var _hint_label: Label = null
var _fruit_label: Label = null
var _pawn_bar: Panel = null
var _pawn_buttons: Array[Button] = []
var _pawn_slot_parts: Array[Dictionary] = []
var _tool_board: PanelContainer = null
var _tool_title: Label = null
var _tool_rows_box: VBoxContainer = null
var _tool_result_label: Label = null
var _tool_rows: Dictionary = {}
var _tool_board_key: String = ""
var _tool_highlight: String = ""
var _status_strip: HBoxContainer = null
var _tip_panel: PanelContainer = null
var _tip_title: Label = null
var _tip_ability: Label = null
var _tip_right: VBoxContainer = null
var _tip_source: Variant = null
var _tip_provider: Callable = Callable()
var _tip_clock: float = 0.0
var _zoom_view: PanelContainer = null
var _zoom_key: String = ""
var _drag_press: Dictionary = {}
var _drag_active: bool = false
var _drag_ghost: PanelContainer = null
var _drop_zone: PanelContainer = null
var _drop_label: Label = null
var _dock: Control = null
var _dock_tabs: HBoxContainer = null
var _dock_player: int = -1
var _debug_toggle: Button = null
var _log_toggle: Button = null
var _debug_box: PanelContainer = null
var _log_panel: PanelContainer = null
var _tool_option: OptionButton = null
var _card_option: OptionButton = null
var _timer_check: CheckBox = null
var _log: RichTextLabel = null
var _center_banner: PanelContainer = null
var _center_label: Label = null
## 연출 대기 시간(await)을 0초로 건너뛰는 플래그 (헤드리스·ui_smoke 자동 진행용).
var instant_roll_for_test: bool = false
var _presenter: RollPresenter = null
var _announcer: EventAnnouncer = null
var _power_bar: ProgressBar = null
var _power_label: Label = null
var _charging: bool = false
var _charge_by_key: bool = false
var _charge_clock: float = 0.0
var _charge_value: float = 0.0
var _pending_power: float = 0.5
var _fx_busy: bool = false
var _fx_generation: int = 0
## 굴림 연출마다 늘어나는 번호: 새 연출이 앞선 연출을 덮어쓰면(취소) 앞선 연출의 뒷정리가 입력 잠금을 풀지 않게 한다.
var _fx_serial: int = 0
var _stack_overlay: Control = null
## 사람이 조작하는 플레이어 번호 (AI 대전 모드에서 P2~P4는 봇이 맡는다).
const HUMAN_ID: int = 1  ## local_player_id의 기본값 (테스트 참조용)
## true면 [1P vs 3AI 봇] 모드: P2~P4를 BotController가 조작하고 P1의 손패만 앞면으로 보인다. false면 4인 수동 조작.
var ai_mode: bool = true
var _bot: BotController = null
var _mode_toggle: Button = null

var _choice_overlay: Control = null
var _draft_overlay: Control = null
var _draft_player: int = -1
var _result_overlay: Control = null
var _auto_draft_enabled: bool = false

var _tile_pick_active: bool = false
var _tile_pick_player: int = -1
var _tile_pick_card: StringName = &""


func _ready() -> void:
	manager = TurnManager.new()
	manager.name = "TurnManager"
	manager.hotseat_mode = true
	manager.step_delay_sec = STEP_DELAY
	manager.stack_choice_enabled = true
	_bot = BotController.new()
	_bot.name = "BotController"
	_bot.manager = manager
	_bot.busy_check = _bot_should_wait
	_bot.enabled = ai_mode
	add_child(_bot)
	add_child(manager)
	manager.set_process(false)  # 제한 시간은 체크박스로 켤 때만 흐른다 (혼자 테스트할 때 자동 진행 방지)
	manager.phase_changed.connect(_on_phase_changed)
	manager.event_received.connect(_on_event)
	manager.action_rejected.connect(_on_action_rejected)
	manager.turn_order_reversed.connect(_on_turn_order_reversed)
	manager.game_over.connect(_on_game_over)
	_build_ui()
	_new_game()


## 코너 번호(0 우하단, 1 우상단, 2 좌상단, 3 좌하단)에 앉는 플레이어: 로컬 플레이어 기준 상대 좌석.
func get_player_for_corner(corner_idx: int) -> int:
	return ((local_player_id - 1 + corner_idx) % 4) + 1


## get_player_for_corner()의 역함수: 플레이어가 앉는 코너 번호.
func corner_of_player(player_id: int) -> int:
	return posmod(player_id - local_player_id, 4)


func _process(delta: float) -> void:
	if manager == null or manager.state == null or state == null:
		return
	if not manager.is_game_over:
		_phase_label.text = _phase_text()
	_bot.instant = instant_roll_for_test
	if _charging:
		# 파워 게이지: 0% ~ 100%를 빠르게 왕복한다 (손을 떼는 순간의 값이 연출 세기가 된다).
		_charge_clock += delta
		_charge_value = pingpong(_charge_clock * 1.6, 1.0)
		_power_bar.value = _charge_value * 100.0
		_power_label.text = "POWER %d%%" % int(_charge_value * 100.0)
		var fill: StyleBoxFlat = _style(Color("51cf66") if _charge_value < 0.4 else (Color("fcc419") if _charge_value < 0.75 else Color("ff6b6b")), Color("fff3bf"), 2, 7, 0, 0)
		_power_bar.add_theme_stylebox_override("fill", fill)
	_update_tip(delta)
	# 말 선택 단계: 지금 고를 수 있는 내 말 도형이 위아래로 통통 튄다.
	var selecting: bool = manager.current_state == TurnManager.State.PHASE_SELECT_PAWN and not manager.is_game_over
	var wave: float = -absf(sin(Time.get_ticks_msec() / 1000.0 * 7.0)) * 6.0
	for pawn: PlayerPawn in state.pawns:
		var view: Node2D = _pawn_views.get(pawn.entity_id)
		if view == null:
			continue
		var bounce: Node2D = view.get_node_or_null("Bounce")
		if bounce != null:
			var active: bool = selecting and pawn.owner_id == manager.current_player_id() and pawn.is_selectable()
			bounce.position.y = wave if active else 0.0
	for index: int in _pawn_slot_parts.size():
		var slot_button: Button = _pawn_buttons[index]
		var base_y: float = 12.0
		slot_button.position.y = base_y + wave if selecting and not slot_button.disabled else base_y


func _input(event: InputEvent) -> void:
	if manager == null or state == null:
		return
	if _handle_card_pointer(event):
		return
	if event is InputEventMouseMotion:
		_update_board_pawn_tip((event as InputEventMouseMotion).position)
	if manager.current_state != TurnManager.State.PHASE_SELECT_PAWN:
		return
	if _ui_busy() or _is_bot_turn() or _choice_overlay != null or _draft_overlay != null or _result_overlay != null or _stack_overlay != null or _tile_pick_active:
		return
	var button_event: InputEventMouseButton = event as InputEventMouseButton
	if button_event != null:
		# 보드 위의 내 말 도형을 직접 클릭해 이동한다.
		if button_event.pressed and button_event.button_index == MOUSE_BUTTON_LEFT:
			var clicked: int = _pawn_at(button_event.position)
			if clicked != -1:
				get_viewport().set_input_as_handled()
				_on_pawn_pressed(clicked)
		return
	if not (event is InputEventMouseMotion):
		return
	var hovered: int = _pawn_at((event as InputEventMouseMotion).position)
	if hovered != -1 and hovered != _board_hover_pawn:
		_preview_pawn(hovered)
		_board_hover_pawn = hovered
	elif hovered == -1 and _board_hover_pawn != -1:
		_clear_highlight()


## 화면 좌표 근처(18px)에 있는, 지금 고를 수 있는 내 말의 ID. 없으면 -1.
func _pawn_at(mouse: Vector2) -> int:
	var found: int = -1
	var best: float = 18.0
	for pawn: PlayerPawn in state.selectable_pawns(manager.current_player_id()):
		var view: Node2D = _pawn_views.get(pawn.entity_id)
		if view == null or not view.visible:
			continue
		var distance: float = view.position.distance_to(mouse)
		if distance < best:
			best = distance
			found = pawn.entity_id
	return found


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or key_event.echo:
		return
	# Ctrl/Alt/Meta/Shift 조합은 브라우저·OS 단축키(예: Ctrl+Shift+R 강력 새로고침)이므로 게임 단축키로 쓰지 않는다.
	if key_event.ctrl_pressed or key_event.alt_pressed or key_event.meta_pressed or key_event.shift_pressed:
		return
	var roll_key: bool = key_event.keycode == KEY_R or key_event.keycode == KEY_SPACE
	if not key_event.pressed:
		# 키를 떼는 순간 굴린다 (꾹 눌러 모은 파워 게이지 확정)
		if roll_key and _charging and _charge_by_key:
			_on_roll_pressed()
		return
	if key_event.keycode == KEY_ESCAPE:
		_cancel_tile_pick()
		return
	if _choice_overlay != null or _draft_overlay != null or _result_overlay != null or _stack_overlay != null:
		return
	if key_event.keycode == KEY_SPACE and state != null and state.tools[manager.current_player_id()] is ToolHalliGalli:
		_on_bell_pressed()
	elif roll_key:
		_begin_charge(true)


# ---------------------------------------------------------------------------
# 새 게임
# ---------------------------------------------------------------------------

func _new_game() -> void:
	_close_choice()
	_close_draft_overlay()
	_close_result_overlay()
	_cancel_tile_pick()
	for view: Node in _pawn_views.values():
		view.queue_free()
	for view: Node in _npc_views.values():
		view.queue_free()
	_pawn_views.clear()
	_npc_views.clear()
	_log.clear()
	_toast_label.text = ""
	_dock_player = -1
	_fx_generation += 1
	_fx_busy = false
	_bot.set_enabled(ai_mode)
	_stop_charge()
	_presenter.cancel()
	_announcer.cancel()
	_cancel_card_drag()
	_close_zoom()
	_tip_end()
	_tool_board_key = ""
	_close_stack_overlay()
	state = null
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
	state.pawn_promoted.connect(func(pawn_id: int) -> void:
		_log_line("[승진] %s → 체스:퀸! (나이트 점프 + 코너 스침 + 룩 +1칸)" % _pawn_name(pawn_id), Color("ffd43b"))
		_announce("기물 능력", "[발동!] 체스 퀸 승진", "%s이(가) 퀸으로 승진: 나이트 점프 + 코너 스침 + 룩 +1칸" % _pawn_name(pawn_id), Color("ffd43b"), null, 1.2))
	state.pawn_evolved.connect(func(pawn_id: int, kind: int, unit_no: int) -> void: _log_line("[진화] %s → %s" % [_pawn_name(pawn_id), PawnCatalog.unit_label(kind, unit_no)], Color("ffa94d")))
	state.pawns_stacked.connect(func(leader_id: int, member_ids: Array[int]) -> void: _log_line("%s 업기 (%d마리)" % [_pawn_name(leader_id), member_ids.size()], Color("ffd43b")))
	state.pawns_swapped.connect(func(a_id: int, b_id: int) -> void: _log_line("%s ↔ %s 위치 교환" % [_pawn_name(a_id), _pawn_name(b_id)], Color("ffd43b")))
	state.attachment_triggered.connect(func(tile: int, id: String, pawn_id: int, _cutscene: StringName) -> void:
		_log_line("[설치물] %d번 타일 %s 발동! (%s)" % [tile, _attachment_name(id), _pawn_name(pawn_id)], Color("ff6b6b"))
		_announce("함정 발동", "[발동!] %s" % _attachment_name(id), "%s\n%d번 타일에서 %s에게 발동" % [str(CARD_SUMMARIES.get(StringName(id), "")), tile, _pawn_name(pawn_id)], Color("ff6b6b"), null, 1.2))
	state.npc_vanished.connect(func(npc_id: int, tile: int) -> void:
		_announce("중립 기물", "NPC가 사냥을 마치고 사라졌습니다", "%d번 타일 - 중립 기물은 한 번 잡으면 사라집니다" % tile, Color("fa5252"), null, 1.3))
	state.attachment_placed.connect(func(tile: int, id: String, owner_id: int) -> void:
		if id != "MINE_NUM":
			_log_line("P%d가 %d번 타일에 [%s]을(를) 설치했습니다" % [owner_id, tile, "뒷면 카드" if id.begins_with("TRP") else _attachment_name(id)], Color("adb5bd"))
		_refresh_tiles())
	state.card_drawn.connect(func(player_id: int, card_id: StringName) -> void: _log_line("[카드] P%d 생떼 카드 획득: %s" % [player_id, _card_name(card_id)], Color("ffa94d")))
	state.card_stolen.connect(func(player_id: int, card_id: StringName) -> void: _log_line("P%d의 카드 [%s]를 도적이 빼앗았습니다" % [player_id, _card_name(card_id)], Color("ff6b6b")))
	state.npc_spawned.connect(func(_npc_id: int, tile: int) -> void:
		_log_line("중립 NPC가 %d번 타일에 소환되었습니다. 라운드가 끝날 때 움직입니다." % tile, Color("fa5252"))
		_refresh_all())
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
	background.color = COLOR_BG
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	# 보드판 받침: 화면 정중앙의 둥근 판
	var plate := Panel.new()
	plate.position = Vector2(453, 74)
	plate.size = Vector2(460, 464)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel", _style(Color("171d2c"), COLOR_PANEL_EDGE, 3, 24, 16, 0))
	add_child(plate)
	_board_layer = Control.new()
	_board_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board_layer)
	_pawn_layer = Node2D.new()
	add_child(_pawn_layer)

	_build_ribbon()
	_build_profiles()
	_build_law_board()
	_build_tool_board()
	_build_status_strip()
	_build_action_bar()
	_build_dock()
	_build_pawn_dock()
	_build_center_banner()
	_build_roll_fx()
	_build_drawers()
	_build_mode_toggle()
	_build_drop_zone()
	_build_hover_tip()


## 상단 중앙 리본 배너: 라운드 / 현재 턴 / 진행 방향과 최근 이벤트 한 줄(토스트).
func _build_ribbon() -> void:
	_ribbon = PanelContainer.new()
	_ribbon.position = Vector2(343, 6)
	_ribbon.custom_minimum_size = Vector2(680, 60)
	_ribbon.size = Vector2(680, 60)
	_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ribbon.add_theme_stylebox_override("panel", _style(Color("14301f"), COLOR_GOLD, 2, 14, 10, 6))
	add_child(_ribbon)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ribbon.add_child(box)
	_header_label = _make_label("", 20, Color("f1f3f5"))
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_header_label)
	_toast_label = _make_label("", 13, Color("ffe8a3"))
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.clip_text = true
	box.add_child(_toast_label)


## 화면 네 모서리의 플레이어 프로필 HUD 카드 (아바타 액자 + 완주 구슬 + 도구 뱃지 + 기물 아이콘 + 세트 효과).
func _build_profiles() -> void:
	for player_id: int in PLAYER_IDS:
		var color: Color = PLAYER_COLORS[player_id]
		var panel := PanelContainer.new()
		panel.position = CORNER_POSITIONS[corner_of_player(player_id)]
		panel.custom_minimum_size = PROFILE_SIZE
		panel.size = PROFILE_SIZE
		panel.pivot_offset = PROFILE_SIZE / 2.0
		add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(row)

		var left := VBoxContainer.new()
		left.add_theme_constant_override("separation", 2)
		left.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(left)
		var avatar := PanelContainer.new()
		avatar.custom_minimum_size = Vector2(64, 64)
		avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar.add_theme_stylebox_override("panel", _style(color.darkened(0.05), color.lightened(0.55), 3, 14, 0, 0))
		left.add_child(avatar)
		var avatar_label := _make_label("P%d" % player_id, 24, Color("0d1018"))
		avatar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		avatar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		avatar.add_child(avatar_label)
		var apostle := _make_label("사도 #%d" % player_id, 11, color.lightened(0.4))
		apostle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		left.add_child(apostle)

		var right := VBoxContainer.new()
		right.add_theme_constant_override("separation", 1)
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(right)
		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		right.add_child(top)
		var name_label := _make_label("플레이어 %d" % player_id, 15, color.lightened(0.2))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(name_label)
		var count_label := _make_label("카드 x0", 12, Color("ced4da"))
		top.add_child(count_label)
		var done_label := _make_label("", 14, color.lightened(0.3))
		right.add_child(done_label)
		var tool_badge := PanelContainer.new()
		tool_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tool_badge.add_theme_stylebox_override("panel", _style(Color("2b3550"), Color("5c6b94"), 1, 8, 0, 3))
		right.add_child(tool_badge)
		var tool_label := _make_label("", 11, Color("dbe4ff"))
		tool_label.clip_text = true
		tool_badge.add_child(tool_label)
		var pawn_icons := HBoxContainer.new()
		pawn_icons.add_theme_constant_override("separation", 4)
		pawn_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
		right.add_child(pawn_icons)
		var icon_labels: Array[Label] = []
		for slot: int in range(1, GameEnums.PAWNS_PER_PLAYER + 1):
			var icon := PanelContainer.new()
			icon.custom_minimum_size = Vector2(28, 24)
			icon.mouse_filter = Control.MOUSE_FILTER_STOP
			icon.add_theme_stylebox_override("panel", _style(Color("2b3550"), color.lightened(0.2), 1, 6, 0, 2))
			var icon_label := _make_label("", 13, Color("f1f3f5"))
			icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.add_child(icon_label)
			_bind_tip(icon, _fill_pawn_tip.bind(player_id * 10 + slot))
			pawn_icons.add_child(icon)
			icon_labels.append(icon_label)
		var synergy_label := _make_label("", 11, COLOR_GOLD)
		synergy_label.clip_text = true
		right.add_child(synergy_label)
		_profiles[player_id] = {
			"panel": panel,
			"count": count_label,
			"done": done_label,
			"tool": tool_label,
			"pawns": icon_labels,
			"synergy": synergy_label,
		}


## 좌측 중앙 '엘리아스 중앙 법전' 위젯: 4개의 둥근 카드형 슬롯 (빈 슬롯은 점선 테두리, 활성 교칙은 명패).
func _build_law_board() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(8, 190)
	panel.custom_minimum_size = Vector2(300, 0)
	panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, COLOR_PANEL_EDGE, 2, 14, 10, 10))
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(_make_label("엘리아스 중앙 법전", 16, COLOR_GOLD))
	box.add_child(_make_label("최대 4슬롯 - 가득 차면 가장 오래된 교칙이 밀려남", 10, Color("868e96")))
	for slot: int in GameEnums.MAX_LAWS:
		var slot_panel := PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(280, 66)
		box.add_child(slot_panel)
		var dash := DashedBorder.new()
		slot_panel.add_child(dash)
		var inner := HBoxContainer.new()
		inner.add_theme_constant_override("separation", 8)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_panel.add_child(inner)
		var badge := PanelContainer.new()
		badge.custom_minimum_size = Vector2(36, 36)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_theme_stylebox_override("panel", _style(COLOR_GOLD, Color("fff3bf"), 2, 18, 0, 0))
		inner.add_child(badge)
		var badge_label := _make_label("", 14, Color("2b2100"))
		badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_child(badge_label)
		var text_box := VBoxContainer.new()
		text_box.add_theme_constant_override("separation", 0)
		text_box.alignment = BoxContainer.ALIGNMENT_CENTER
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(text_box)
		var name_label := _make_label("", 13, Color("dee2e6"))
		name_label.clip_text = true
		text_box.add_child(name_label)
		var desc_label := _make_label("", 10, Color("adb5bd"))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.max_lines_visible = 3
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.add_child(desc_label)
		_law_slots.append(slot_panel)
		_law_labels.append(name_label)
		_law_descs.append(desc_label)
		_law_badges.append(badge)
		_law_badge_labels.append(badge_label)
		_law_dashes.append(dash)


## 우측 중앙 '판정 도구 전광판': 지금 턴 플레이어의 도구가 "무엇이 나오면 몇 칸 가는지"만 보여 주고, 굴림 결과 줄에 불이 들어온다.
func _build_tool_board() -> void:
	_tool_board = PanelContainer.new()
	_tool_board.position = Vector2(1008, 182)
	_tool_board.custom_minimum_size = Vector2(350, 0)
	_tool_board.size = Vector2(350, 10)
	_tool_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tool_board.add_theme_stylebox_override("panel", _style(Color("101626"), COLOR_PANEL_EDGE, 2, 14, 10, 10))
	add_child(_tool_board)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tool_board.add_child(box)
	_tool_title = _make_label("", 15, COLOR_GOLD)
	box.add_child(_tool_title)
	_tool_rows_box = VBoxContainer.new()
	_tool_rows_box.add_theme_constant_override("separation", 3)
	_tool_rows_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_tool_rows_box)
	_fruit_label = _make_label("", 11, Color("ced4da"))
	_fruit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fruit_label.custom_minimum_size = Vector2(326, 0)
	box.add_child(_fruit_label)
	_tool_result_label = _make_label("", 15, Color("fff3bf"))
	_tool_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tool_result_label.custom_minimum_size = Vector2(326, 0)
	box.add_child(_tool_result_label)


## 보드 아래 한 줄 상태 띠: 단계 / 안내 문구 / 이동 대기열. (개입 카드 탭이 뜨면 그 자리를 양보한다.)
func _build_status_strip() -> void:
	_status_strip = HBoxContainer.new()
	_status_strip.position = Vector2(283, 590)
	_status_strip.size = Vector2(800, 24)
	_status_strip.add_theme_constant_override("separation", 10)
	_status_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status_strip)
	_phase_label = _make_label("", 13, COLOR_GOLD)
	_status_strip.add_child(_phase_label)
	_hint_label = _make_label("", 12, Color("a5d8ff"))
	_hint_label.clip_text = true
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_strip.add_child(_hint_label)
	_queue_label = _make_label("", 11, Color("adb5bd"))
	_status_strip.add_child(_queue_label)
	_pick_banner = _make_label("", 13, Color("63e6be"))
	_pick_banner.position = Vector2(473, 78)
	_pick_banner.size = Vector2(440, 26)
	_pick_banner.clip_text = true
	_pick_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pick_banner.add_theme_stylebox_override("normal", _style(Color("0b3b33"), Color("63e6be"), 2, 8, 0, 3))
	_pick_banner.visible = false
	add_child(_pick_banner)
	_new_game_button = _make_button("새 게임", _new_game, 12, Color("3b4766"), 8)
	_new_game_button.position = Vector2(246, 8)
	_new_game_button.size = Vector2(90, 32)
	add_child(_new_game_button)


## 보드 아래 중앙의 메인 액션 바(굴리기·멈추기·개입 패스·특수 버튼).
func _build_action_bar() -> void:
	var action_row := HFlowContainer.new()
	action_row.position = Vector2(183, 544)
	action_row.size = Vector2(1000, 44)
	action_row.alignment = FlowContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("h_separation", 8)
	action_row.add_theme_constant_override("v_separation", 4)
	add_child(action_row)
	_roll_button = _make_button("[주사위 굴리기 (R)]", _on_roll_pressed, 19, Color("2b8a3e"), 14)
	_roll_button.custom_minimum_size = Vector2(280, 44)
	_roll_button.tooltip_text = "주사위/윷은 꾹 눌러 파워 게이지를 채우고 손을 떼면 굴러갑니다 (R / Space 키도 동일)"
	_roll_button.button_down.connect(_begin_charge.bind(false))
	_roll_button.button_up.connect(_on_roll_button_up)
	action_row.add_child(_roll_button)
	_stop_button = _make_button("멈추고 이동 확정", _on_stop_pressed, 16, Color("37506b"), 14)
	_stop_button.custom_minimum_size = Vector2(240, 44)
	action_row.add_child(_stop_button)
	_skip_button = _make_button("개입 패스(진행)", _on_skip_pressed, 16, Color("7a4a14"), 14)
	_skip_button.custom_minimum_size = Vector2(160, 44)
	action_row.add_child(_skip_button)
	_bell_button = _make_button("종 치기 (Space)", _on_bell_pressed, 14)
	_bell_button.custom_minimum_size = Vector2(0, 44)
	action_row.add_child(_bell_button)
	_castle_button = _make_button("[캐슬링(위치 교환)]", _on_castle_pressed, 14)
	_castle_button.custom_minimum_size = Vector2(0, 44)
	_castle_button.tooltip_text = "체스 2세트: 내 체스 기물 두 개의 위치를 맞바꿉니다 (턴 시작 시 1회)"
	action_row.add_child(_castle_button)
	_bomb_button = _make_button("[폭탄 떠넘기기]", _on_pass_bomb_pressed, 14)
	_bomb_button.custom_minimum_size = Vector2(0, 44)
	_bomb_button.tooltip_text = "즉발 카드 1장을 소모해 우노 +4 페널티를 두 배(-8)로 다음 플레이어에게 넘깁니다"
	action_row.add_child(_bomb_button)

	# 개입 창에서는 상태 띠 자리에 '카드를 낼 수 있는 플레이어' 탭이 뜬다.
	_dock_tabs = HBoxContainer.new()
	_dock_tabs.position = Vector2(343, 590)
	_dock_tabs.size = Vector2(680, 28)
	_dock_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	_dock_tabs.add_theme_constant_override("separation", 6)
	_dock_tabs.visible = false
	add_child(_dock_tabs)


## 하단 정중앙 TCG 스타일 카드 독. 카드는 _refresh_hands()가 채운다.
func _build_dock() -> void:
	_dock = Control.new()
	_dock.position = Vector2(313, 616)
	_dock.size = Vector2(740, 152)
	_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dock)


## 주사위/판정 결과를 보드 한가운데에 크게 띄우는 배너.
func _build_center_banner() -> void:
	_center_banner = PanelContainer.new()
	_center_banner.visible = false
	_center_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_banner.add_theme_stylebox_override("panel", _style(Color("101626"), COLOR_GOLD, 4, 20, 22, 18))
	add_child(_center_banner)
	_center_label = _make_label("", 30, Color("ffffff"))
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_label.add_theme_constant_override("outline_size", 6)
	_center_label.add_theme_color_override("font_outline_color", Color("0d1018"))
	_center_banner.add_child(_center_label)


## 우측 상단의 [치트/디버그] / [전체 로그] 버튼과, 눌렀을 때만 우측에서 열리는 오버레이 서랍 두 개.
func _build_drawers() -> void:
	_debug_toggle = _make_button("[치트/디버그]", _on_debug_toggle_pressed, 13, Color("4a3a66"), 8)
	_debug_toggle.position = Vector2(1100, 8)
	_debug_toggle.size = Vector2(140, 30)
	add_child(_debug_toggle)
	_log_toggle = _make_button("[전체 로그]", _on_log_toggle_pressed, 13, Color("2f4a66"), 8)
	_log_toggle.position = Vector2(1248, 8)
	_log_toggle.size = Vector2(110, 30)
	add_child(_log_toggle)

	var debug_drawer: Dictionary = _make_drawer("치트 / 디버그", _on_debug_toggle_pressed)
	_debug_box = debug_drawer["panel"]
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	(debug_drawer["body"] as VBoxContainer).add_child(scroll)
	var debug_content: VBoxContainer = _build_debug_panel()
	debug_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(debug_content)

	var log_drawer: Dictionary = _make_drawer("전체 로그", _on_log_toggle_pressed)
	_log_panel = log_drawer["panel"]
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.fit_content = false
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 12)
	(log_drawer["body"] as VBoxContainer).add_child(_log)


## 우측에서 열리는 오버레이 서랍 틀. 기본은 숨김이다.
func _make_drawer(title: String, close_callback: Callable) -> Dictionary:
	var panel := PanelContainer.new()
	panel.position = Vector2(922, 44)
	panel.custom_minimum_size = Vector2(436, 716)
	panel.size = Vector2(436, 716)
	panel.visible = false
	panel.add_theme_stylebox_override("panel", _style(Color("131826"), COLOR_PANEL_EDGE, 3, 16, 24, 12))
	add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	var title_label := _make_label(title, 16, COLOR_GOLD)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	header.add_child(_make_button("닫기", close_callback, 12, Color("5c2b2b"), 8))
	return {"panel": panel, "body": body}


func _build_debug_panel() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var law_buttons := HFlowContainer.new()
	law_buttons.add_theme_constant_override("h_separation", 4)
	law_buttons.add_theme_constant_override("v_separation", 3)
	box.add_child(law_buttons)
	law_buttons.add_child(_make_label("교칙 추가(테스트):", 12, Color("868e96")))
	for law_id: String in LawRegistry.ALL_IDS:
		var sample: LawResource = LawRegistry.create(law_id)
		var law_button: Button = _make_button("%s %s" % [law_id.trim_prefix("LAW_"), sample.law_name], _on_add_law_pressed.bind(law_id), 11)
		law_button.tooltip_text = "[%s] %s\n%s\n(작동 시점: %s)" % [law_id, sample.law_name, sample.description, sample.trigger_timing]
		law_buttons.add_child(law_button)
	var debug_row := HFlowContainer.new()
	debug_row.add_theme_constant_override("h_separation", 6)
	debug_row.add_theme_constant_override("v_separation", 3)
	box.add_child(debug_row)
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
	for card_id: StringName in CardRegistry.all_ids():
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
	return box


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_section(text: String) -> Label:
	return _make_label(text, 13, Color("74c0fc"))


func _make_button(text: String, callback: Callable, font_size: int, base_color: Color = Color("3b4766"), radius: int = 8) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	_apply_button_style(button, base_color, radius)
	if callback.is_valid():
		button.pressed.connect(callback)
	return button


## 둥근 모서리·테두리가 있는 게임풍 버튼 스타일 (일반/호버/눌림/비활성).
func _apply_button_style(button: Button, base_color: Color, radius: int) -> void:
	var normal: StyleBoxFlat = _style(base_color, base_color.lightened(0.3), 2, radius, 4, 6)
	var hover: StyleBoxFlat = _style(base_color.lightened(0.15), COLOR_GOLD, 2, radius, 6, 6)
	var pressed: StyleBoxFlat = _style(base_color.darkened(0.2), COLOR_GOLD, 2, radius, 0, 6)
	var disabled: StyleBoxFlat = _style(base_color.darkened(0.55), base_color.darkened(0.25), 2, radius, 0, 6)
	for box: StyleBoxFlat in [normal, hover, pressed, disabled]:
		box.set_content_margin(SIDE_LEFT, 12)
		box.set_content_margin(SIDE_RIGHT, 12)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_disabled_color", Color("7b8499"))


## 둥근 모서리·테두리·그림자가 있는 패널 스타일.
func _style(bg: Color, border: Color = Color(0, 0, 0, 0), border_width: int = 0, radius: int = 10, shadow: int = 0, margin: int = 8) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(margin)
	if shadow > 0:
		box.shadow_color = Color(0, 0, 0, 0.5)
		box.shadow_size = shadow
		box.shadow_offset = Vector2(0, 3)
	return box


func _on_debug_toggle_pressed() -> void:
	_log_panel.visible = false
	_debug_box.visible = not _debug_box.visible


func _on_log_toggle_pressed() -> void:
	_debug_box.visible = false
	_log_panel.visible = not _log_panel.visible


# ---------------------------------------------------------------------------
# 보드 / 말 그리기
# ---------------------------------------------------------------------------

## 타일 번호 -> 0~1 정규화 좌표 (화면 렌더링 전용, BoardGraph 연결 규칙과 무관).
## 출발선(0번)은 우하단에서 시작해 반시계 방향으로 돈다: 0 우하단 -> 5 우상단 -> 10 좌상단 -> 15 좌하단 -> 다시 0.
## 지름길 1은 5(우상단)->20,21,22(중앙),23,24->15(좌하단), 지름길 2는 10(좌상단)->25,26,22,27,28->0(우하단).
static func tile_norm(index: int) -> Vector2:
	if index <= 5:
		return Vector2(1.0, 1.0 - index / 5.0)
	if index <= 10:
		return Vector2(1.0 - (index - 5) / 5.0, 0.0)
	if index <= 15:
		return Vector2(0.0, (index - 10) / 5.0)
	if index <= 19:
		return Vector2((index - 15) / 5.0, 1.0)
	match index:
		20: return Vector2(5.0 / 6.0, 1.0 / 6.0)
		21: return Vector2(4.0 / 6.0, 2.0 / 6.0)
		22: return Vector2(0.5, 0.5)
		23: return Vector2(2.0 / 6.0, 4.0 / 6.0)
		24: return Vector2(1.0 / 6.0, 5.0 / 6.0)
		25: return Vector2(1.0 / 6.0, 1.0 / 6.0)
		26: return Vector2(2.0 / 6.0, 2.0 / 6.0)
		27: return Vector2(4.0 / 6.0, 4.0 / 6.0)
		28: return Vector2(5.0 / 6.0, 5.0 / 6.0)
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
		var tile := Panel.new()
		tile.size = Vector2(TILE_SIZE, TILE_SIZE)
		tile.position = _tile_center(index) - tile.size / 2.0
		var tile_color: Color = _tile_color(index, node.tile_type)
		tile.add_theme_stylebox_override("panel", _style(tile_color, tile_color.darkened(0.4), 2, 8, 0, 0))
		tile.gui_input.connect(_on_tile_gui_input.bind(index))
		_board_layer.add_child(tile)
		_tile_views[index] = tile

		var light: bool = _is_light_tile(index, node.tile_type)
		# 타일 안 요소 배치: 번호=좌상단, 설명=하단 중앙, 설치물 배지=우상단, 말=정중앙.
		var text_color: Color = Color("212529") if light else Color("f8f9fa")
		var number := _make_label(str(index), 12, text_color)
		number.position = Vector2(3, 0)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(number)
		var tag: String = _tile_tag(index, node.tile_type)
		var tag_label := _make_label(tag, 9, text_color)
		tag_label.name = "Tag"
		tag_label.position = Vector2(0, TILE_SIZE - 14)
		tag_label.size = Vector2(TILE_SIZE, 13)
		tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(tag_label)
		_tag_labels[index] = tag_label
		var mark := _make_label("", 10, Color("ff6b6b"))
		mark.position = Vector2(TILE_SIZE - 4, 0)
		mark.add_theme_constant_override("outline_size", 4)
		mark.add_theme_color_override("font_outline_color", Color("111418"))
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(mark)
		_tile_marks[index] = mark
		var highlight := ReferenceRect.new()
		highlight.border_color = Color("ffe066")
		highlight.border_width = 3.0
		highlight.editor_only = false
		highlight.size = tile.size
		highlight.visible = false
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(highlight)
		_highlights[index] = highlight
		var pick_mark := ReferenceRect.new()
		pick_mark.border_color = Color("63e6be")
		pick_mark.border_width = 4.0
		pick_mark.editor_only = false
		pick_mark.size = tile.size
		pick_mark.visible = false
		pick_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(pick_mark)
		_pick_marks[index] = pick_mark


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
		TileNode.TileType.START_GOAL: return "▲출발"
		TileNode.TileType.BAKERY: return "빵집"
		TileNode.TileType.PORTAL: return "옷장"
	if index == GameEnums.CENTER_TILE:
		return "중앙"
	if index == 5:
		return "코너↙"
	if index == 10:
		return "코너↘"
	if index == 15:
		return "합류"
	return ""


func _build_pawn_views() -> void:
	for pawn: PlayerPawn in state.pawns:
		var view := Node2D.new()
		var bounce := Node2D.new()
		bounce.name = "Bounce"
		view.add_child(bounce)
		var body := Polygon2D.new()
		body.name = "Body"
		body.polygon = _circle_points(PAWN_RADIUS, 20)
		body.color = PLAYER_COLORS[pawn.owner_id]
		bounce.add_child(body)
		var ring := Line2D.new()
		ring.name = "Ring"
		ring.width = 1.5
		ring.default_color = Color("f8f9fa")
		ring.closed = true
		for point: Vector2 in _circle_points(PAWN_RADIUS, 20):
			ring.add_point(point)
		bounce.add_child(ring)
		var number := _make_label(str(pawn.slot), 9, Color("111111"))
		number.name = "Slot"
		number.position = Vector2(-3, -7)
		bounce.add_child(number)
		var kind_label := _make_label("", 10, Color("ffffff"))
		kind_label.name = "Kind"
		kind_label.position = Vector2(4, -14)
		kind_label.add_theme_constant_override("outline_size", 5)
		kind_label.add_theme_color_override("font_outline_color", Color("111418"))
		bounce.add_child(kind_label)
		var stack_badge := _make_label("", 13, Color("ffe066"))
		stack_badge.name = "Stack"
		stack_badge.position = Vector2(-9, -10)
		stack_badge.add_theme_constant_override("outline_size", 6)
		stack_badge.add_theme_color_override("font_outline_color", Color("111418"))
		bounce.add_child(stack_badge)
		var badge := _make_label("", 9, Color("ffffff"))
		badge.name = "Badge"
		badge.position = Vector2(-12, 5)
		badge.add_theme_constant_override("outline_size", 5)
		badge.add_theme_color_override("font_outline_color", Color("111418"))
		bounce.add_child(badge)
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
	var micro := Vector2(((pawn.slot - 1) % 2) * 4.0 - 2.0, ((pawn.slot - 1) / 2) * 4.0 - 2.0)
	var position_in_tile: Vector2 = _tile_center(pawn.current_tile_idx) + CELL_OFFSETS[owner_index] + micro
	if pawn.is_finished:
		position_in_tile = _tile_center(GameEnums.GOAL_TILE) + Vector2(-22 + owner_index * 14 + (pawn.slot - 1) * 3.0, 38)
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
		# 출발 전 대기 말과 완주한 말은 보드에 그리지 않는다. 대기 말은 첫 걸음을 뗄 때 출발선에서 나타나 전진하고,
		# 완주 현황은 오른쪽 패널의 미니 슬롯(●●○○)과 [이동할 말] 버튼으로 확인한다.
		view.visible = pawn.carrier == null and not pawn.is_finished and pawn.has_left_start
		view.modulate = Color.WHITE
		(view.get_node("Bounce/Kind") as Label).text = PawnCatalog.unit_letter(pawn.kind, pawn.unit_no)
		var badge_text: String = ""
		var stacked: bool = not pawn.carried.is_empty()
		(view.get_node("Bounce/Stack") as Label).text = "x%d" % (pawn.carried.size() + 1) if stacked else ""
		(view.get_node("Bounce/Slot") as Label).visible = not stacked
		if pawn.restrained_turns > 0 or pawn.blocked_this_turn:
			badge_text += " 구속"
		if pawn.is_imprisoned:
			badge_text += " 감옥"
		(view.get_node("Bounce/Badge") as Label).text = badge_text
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
		(_npc_views[npc.entity_id] as Node2D).position = _tile_center(npc.current_tile_idx) + Vector2(0, -22)
	for npc_id: int in _npc_views.keys():
		if state.get_npc(npc_id) == null:
			(_npc_views[npc_id] as Node).queue_free()
			_npc_views.erase(npc_id)


func _refresh_tiles() -> void:
	if _tile_marks.is_empty():
		return
	for index: int in GameEnums.TILE_COUNT:
		var parts: Array[String] = []
		var tips: Array[String] = []
		var color: Color = Color("ff6b6b")
		for attachment: TileAttachment in state.board.get_tile(index).attachments:
			match attachment.attachment_id:
				"TRP_01", "TRP_02", "TRP_03":
					parts.append(_trap_badge(attachment))
					tips.append(_trap_tooltip(attachment))
				"MINE_NUM":
					parts.append("[1]")
					color = Color("8ce99a")
				"TRP_04":
					parts.append("섬")
					color = Color("74c0fc")
				"HOTEL":
					parts.append("호텔")
					color = PLAYER_COLORS.get(attachment.owner_id, Color("ffd43b"))
		(_tile_views[index] as Control).tooltip_text = "\n".join(tips)
		var mark: Label = _tile_marks[index]
		mark.text = " ".join(parts)
		mark.position = Vector2(TILE_SIZE - 2 - mark.get_minimum_size().x, 0)
		mark.add_theme_color_override("font_color", color)


## 타일 위 함정 배지. AI 모드(타일 은신): P1이 설치한 함정만 이름이 보이고 봇이 설치한 함정은 뒷면 [? 함정]으로만 보인다.
## 수동 모드는 예전처럼 모든 은신 함정이 "?"로 보인다.
func _trap_badge(attachment: TileAttachment) -> String:
	if not ai_mode:
		return "?"
	if attachment.owner_id == local_player_id:
		return {"TRP_01": "거울", "TRP_02": "나락", "TRP_03": "지뢰"}.get(attachment.attachment_id, "함정")
	return "?함정"


func _trap_tooltip(attachment: TileAttachment) -> String:
	if ai_mode and attachment.owner_id == local_player_id:
		return "[내 함정] %s" % _attachment_name(attachment.attachment_id)
	return "[? 함정] P%d가 설치한 뒷면 함정" % attachment.owner_id if ai_mode else "[? 함정]"


func _on_pawn_stepped(pawn_id: int, _from_tile: int, _to_tile: int) -> void:
	var view: Node2D = _pawn_views.get(pawn_id)
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	if view == null or pawn == null:
		return
	view.visible = pawn.carrier == null and not pawn.is_finished
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
	if manager == null or manager.state == null:
		return
	state = manager.state
	_refresh_header()
	_refresh_players()
	_refresh_laws()
	_refresh_tiles()
	_refresh_pawns()
	_refresh_hands()
	_refresh_controls()
	_refresh_overlays()


func _phase_text() -> String:
	var text: String = PHASE_NAMES[manager.current_state]
	if _timer_check != null and _timer_check.button_pressed and manager.phase_time_left > 0.0:
		text += "  (%.1f초)" % manager.phase_time_left
	return text


func _refresh_header() -> void:
	var player_id: int = manager.current_player_id()
	var reversed: bool = manager.turn_direction == -1
	var direction: String = "역방향 ◀" if reversed else "정방향 ▶"
	var reverse_text: String = "  |  이동 역주행 %d라운드" % state.reverse_move_rounds_left if state.reverse_move_rounds_left > 0 else ""
	_header_label.text = "라운드 %d   |   현재 턴: P%d   |   진행 방향: %s%s" % [state.round_number, player_id, direction, reverse_text]
	_header_label.add_theme_color_override("font_color", (PLAYER_COLORS[player_id] as Color).lightened(0.35))
	# 리본은 정방향이면 초록, 우노 리버스(턴 방향 -1)면 주황으로 반전하고 테두리는 현재 턴 플레이어 색이다.
	_ribbon.add_theme_stylebox_override("panel", _style(Color("4a2a0c") if reversed else Color("14301f"), PLAYER_COLORS[player_id], 3, 14, 10, 6))
	_phase_label.text = _phase_text()
	_refresh_direction()
	var queue_text: String = "남은 이동 대기열: %s" % str(manager.move_queue) if not manager.move_queue.is_empty() else ""
	if manager.command_stack != null and manager.command_stack.interrupt_count() > 0:
		queue_text += "   개입 대기 카드: %d장 (나중에 낸 카드부터 실행)" % manager.command_stack.interrupt_count()
	if _fx_busy:
		queue_text = ""  # 굴림 연출 중에는 결과가 먼저 새지 않게 숨긴다
	_queue_label.text = queue_text
	_queue_label.visible = queue_text != ""


func _refresh_direction() -> void:
	if not _tag_labels.has(GameEnums.GOAL_TILE):
		return
	var reversed: bool = manager.turn_direction == -1
	var start_tag: Label = _tag_labels[GameEnums.GOAL_TILE]
	start_tag.text = "▼역주행" if reversed else "▲출발"
	start_tag.add_theme_color_override("font_color", Color("ffe8cc") if reversed else Color("f8f9fa"))


func _refresh_players() -> void:
	for player_id: int in PLAYER_IDS:
		var card: Dictionary = _profiles[player_id]
		var color: Color = PLAYER_COLORS[player_id]
		var finished: int = 0
		for pawn: PlayerPawn in state.pawns_of(player_id):
			if pawn.is_finished:
				finished += 1
		var marbles: Array[String] = []
		for index: int in GameEnums.PAWNS_PER_PLAYER:
			marbles.append("●" if index < finished else "○")
		(card["done"] as Label).text = "완주 %s  %d/4" % [" ".join(marbles), finished]
		(card["count"] as Label).text = "카드 x%d" % (state.hands[player_id] as Array).size()
		(card["tool"] as Label).text = "도구: %s" % (state.tools[player_id] as BaseJudgmentTool).display_name
		var icon_labels: Array = card["pawns"]
		for index: int in icon_labels.size():
			var icon_pawn: PlayerPawn = state.get_pawn(player_id * 10 + index + 1)
			var icon_text: String = PawnCatalog.unit_letter(icon_pawn.kind, icon_pawn.unit_no) if icon_pawn.kind != GameEnums.PawnKind.BASIC else "기"
			(icon_labels[index] as Label).text = "완" if icon_pawn.is_finished else icon_text
		var bomb_text: String = " [우노+4 %d칸]" % state.penalty_of(player_id) if state.penalty_of(player_id) != 0 else ""
		(card["synergy"] as Label).text = _set_synergy_text(player_id).replace("(", "").replace(")", "") + bomb_text
		var panel: PanelContainer = card["panel"]
		# 현재 턴 플레이어: 밝은 황금 테두리 3px + 살짝 확대
		var is_turn: bool = player_id == manager.current_player_id() and not manager.is_game_over
		if is_turn:
			panel.add_theme_stylebox_override("panel", _style(Color("273049"), COLOR_GOLD, 3, 14, 20, 8))
			panel.scale = Vector2(1.04, 1.04)
		else:
			panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, color.darkened(0.25), 2, 14, 8, 8))
			panel.scale = Vector2.ONE


## 프로필 카드 툴팁: 말마다 "[2번 말 - 체스:비숍 (코너 스침 지름길)]" 한 줄씩.
func _pawn_tooltip(player_id: int) -> String:
	var lines: Array[String] = []
	for pawn: PlayerPawn in state.pawns_of(player_id):
		var line: String = "[%d번 말 - %s (%s)]" % [pawn.slot, pawn.display_label(), PawnCatalog.ability_text(pawn.kind, pawn.unit_no)]
		if pawn.is_finished:
			line += " 완주"
		elif pawn.restrained_turns > 0 or pawn.blocked_this_turn:
			line += " 구속"
		lines.append(line)
	return "\n".join(lines)


## "[폰][나][기][기]" 형태의 기물 4종 미니 아이콘 (기 = 기본 말, 완 = 완주).
func _pawn_mini(player_id: int) -> String:
	var tokens: Array[String] = []
	for pawn: PlayerPawn in state.pawns_of(player_id):
		var letter: String = PawnCatalog.unit_letter(pawn.kind, pawn.unit_no) if pawn.kind != GameEnums.PawnKind.BASIC else "기"
		if pawn.is_finished:
			letter = "완"
		tokens.append("[%s]" % letter)
	return "".join(tokens)


## "[체스:폰] [체스:나이트] [기본] [기본]" 형태의 말 4개 요약. 상태 이상은 뒤에 붙인다.
func _pawn_tokens(player_id: int) -> String:
	var tokens: Array[String] = []
	for pawn: PlayerPawn in state.pawns_of(player_id):
		var token: String = pawn.display_label()
		if pawn.is_finished:
			token += "·완주"
		if pawn.restrained_turns > 0 or pawn.blocked_this_turn:
			token += "·구속"
		if pawn.is_imprisoned:
			token += "·감옥"
		tokens.append("[%s]" % token)
	return " ".join(tokens)


## 2세트 이상 모은 세트를 "(체스 2세트 활성)" 식으로 나열하고, 4세트면 특수 승리 조건 이름을 덧붙인다.
func _set_synergy_text(player_id: int) -> String:
	var parts: Array[String] = []
	for kind: GameEnums.PawnKind in PawnCatalog.EVOLVABLE_SETS:
		var count: int = state.set_count(player_id, kind)
		if count >= GameEnums.PAWNS_PER_PLAYER:
			var privilege: String = " (잡기 추가 굴림)" if kind == GameEnums.PawnKind.JANGGI else ""
			parts.append("(%s 4세트: %s%s)" % [PawnCatalog.display_set_name(kind), PawnCatalog.SPECIAL_VICTORY_NAMES[kind], privilege])
		elif count >= GameEnums.SET_SYNERGY_2:
			var extra: String = " - 무적" if kind == GameEnums.PawnKind.GO else ""
			parts.append("(%s %d세트 활성%s)" % [PawnCatalog.display_set_name(kind), count, extra])
	return " ".join(parts)


func _refresh_laws() -> void:
	for slot: int in _law_labels.size():
		var active: bool = slot < state.rulebook.active_laws_queue.size()
		_law_dashes[slot].visible = not active
		_law_badges[slot].visible = active
		if active:
			var law: LawResource = state.rulebook.active_laws_queue[slot]
			var flashing: bool = _flash_law_ids.has(law.law_id)
			_law_slots[slot].add_theme_stylebox_override("panel", _style(Color("4a3d12") if flashing else Color("2e2a1a"), COLOR_GOLD, 2, 12, 6, 8))
			_law_badge_labels[slot].text = law.law_id.trim_prefix("LAW_")
			_law_labels[slot].text = law.law_name
			_law_labels[slot].add_theme_color_override("font_color", Color("fff3bf") if flashing else Color("f1f3f5"))
			_law_descs[slot].text = law.description
			_law_slots[slot].tooltip_text = "[%s] %s\n%s" % [law.law_id, law.law_name, law.description]
		else:
			_law_slots[slot].add_theme_stylebox_override("panel", _style(Color("10131b"), Color(0, 0, 0, 0), 0, 12, 0, 8))
			_law_labels[slot].text = "빈 슬롯 %d" % (slot + 1)
			_law_labels[slot].add_theme_color_override("font_color", Color("5c6068"))
			_law_descs[slot].text = ""
			_law_slots[slot].tooltip_text = ""


func _refresh_hands() -> void:
	for child: Node in _dock.get_children():
		child.queue_free()
	for child: Node in _dock_tabs.get_children():
		child.queue_free()
	# AI 모드: 하단 독에는 사람(P1)의 손패만 앞면으로 보인다 (봇의 손패는 장수만 프로필 카드에 표시).
	var in_window: bool = _in_intervention_window() and not ai_mode
	var holders: Array[int] = _window_holders() if in_window else ([] as Array[int])
	if in_window and not holders.has(_dock_player):
		_dock_player = holders[0] if not holders.is_empty() else manager.current_player_id()
	var player_id: int = _dock_player if in_window else (local_player_id if ai_mode else manager.current_player_id())
	if not in_window:
		_dock_player = player_id
	# 개입 창: 카드를 낼 수 있는 플레이어 탭 (현재 턴 플레이어의 손패는 평소 독에 상시 표시)
	_dock_tabs.visible = in_window and not holders.is_empty()
	_status_strip.visible = not _dock_tabs.visible
	if _dock_tabs.visible:
		_dock_tabs.add_child(_make_label("개입 카드:", 13, Color("adb5bd")))
		for holder: int in holders:
			var tab: Button = _make_button("P%d (%d장)" % [holder, (state.hands[holder] as Array).size()], _on_dock_tab_pressed.bind(holder), 12, (PLAYER_COLORS[holder] as Color).darkened(0.4), 8)
			tab.custom_minimum_size = Vector2(110, 28)
			tab.disabled = holder == player_id
			_dock_tabs.add_child(tab)
	var hand: Array = state.hands[player_id]
	if hand.is_empty():
		var empty := _make_label("P%d 손패 없음" % player_id, 14, Color("5c6068"))
		empty.position = Vector2(0, 60)
		empty.size = Vector2(_dock.size.x, 24)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_dock.add_child(empty)
		return
	var count: int = hand.size()
	var step: float = minf(CARD_SIZE.x + 6.0, (_dock.size.x - CARD_SIZE.x) / maxf(count - 1, 1))
	var total: float = CARD_SIZE.x + step * (count - 1)
	var start_x: float = (_dock.size.x - total) / 2.0
	for index: int in count:
		var card_id: StringName = hand[index]
		var card_view: PanelContainer = _make_card_view(player_id, card_id)
		card_view.position = Vector2(start_x + step * index, DOCK_CARD_Y)
		_dock.add_child(card_view)


## 지금 개입 창(INTERRUPT_ROLL / RESOLUTION)인가.
func _in_intervention_window() -> bool:
	var phase: TurnManager.State = manager.current_state
	return not manager.is_game_over and (phase == TurnManager.State.PHASE_INTERRUPT_ROLL or phase == TurnManager.State.PHASE_RESOLUTION)


## 개입 창에서 낼 수 있는 카드를 가진 플레이어들 (현재 턴 플레이어 먼저).
func _window_holders() -> Array[int]:
	var holders: Array[int] = []
	var order: Array[int] = [manager.current_player_id()]
	for player_id: int in PLAYER_IDS:
		if player_id != manager.current_player_id():
			order.append(player_id)
	for player_id: int in order:
		for card_id: StringName in state.hands[player_id]:
			var card: BaseCard = CardRegistry.get_card(card_id)
			if card.is_playable_in(manager.current_state) and card.could_play(state, player_id):
				holders.append(player_id)
				break
	return holders


func _on_dock_tab_pressed(player_id: int) -> void:
	_dock_player = player_id
	_refresh_hands()


## 실제 카드 모양의 세로형 프레임 (100x140): 상단 카드명 / 중앙 카테고리 색 아이콘 / 하단 요약. 호버 시 15px 솟아오르며 테두리가 빛난다.
func _make_card_view(player_id: int, card_id: StringName) -> PanelContainer:
	var card: BaseCard = CardRegistry.get_card(card_id)
	var usable: bool = _card_usable_now(player_id, card)
	var accent: Color = CARD_CATEGORY_COLORS[card.category]
	var view := PanelContainer.new()
	view.custom_minimum_size = CARD_SIZE
	view.size = CARD_SIZE
	var idle_style: StyleBoxFlat = _style(Color("20263a"), accent.darkened(0.15), 2, 10, 8, 6)
	var glow_style: StyleBoxFlat = _style(Color("2c3550"), Color("fff3bf"), 4, 10, 18, 6)
	view.add_theme_stylebox_override("panel", idle_style)
	view.modulate = Color.WHITE if usable else Color(0.62, 0.62, 0.68)
	view.tooltip_text = "%s (%s) - %s\n%s" % [card.display_name, card_id, _category_text(card.category), CARD_SUMMARIES.get(card_id, "")]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(box)
	var title := _make_label(card.display_name + (" ▣" if card.needs_tile() else ""), 12, Color("f8f9fa"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(0, 30)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)
	var icon := PanelContainer.new()
	icon.custom_minimum_size = Vector2(0, 40)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_theme_stylebox_override("panel", _style(accent.darkened(0.35), accent, 2, 8, 0, 2))
	box.add_child(icon)
	var icon_label := _make_label("%s\n%s" % [CARD_CATEGORY_NAMES[card.category], str(card_id).replace("_", " ")], 11, Color("fff9db"))
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_child(icon_label)
	var summary := _make_label(str(CARD_SUMMARIES.get(card_id, "")), 10, Color("ced4da"))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.max_lines_visible = 4
	summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(summary)
	view.gui_input.connect(_on_card_gui_input.bind(player_id, card_id, view))
	view.mouse_entered.connect(_on_card_hover.bind(view, glow_style, true))
	view.mouse_exited.connect(_on_card_hover.bind(view, idle_style, false))
	return view


func _on_card_hover(view: PanelContainer, style: StyleBoxFlat, raised: bool) -> void:
	if not is_instance_valid(view):
		return
	view.add_theme_stylebox_override("panel", style)
	view.z_index = 5 if raised else 0
	if view.has_meta("lift"):
		var previous: Tween = view.get_meta("lift")
		if previous != null and previous.is_valid():
			previous.kill()
	var tween: Tween = create_tween()
	tween.tween_property(view, "position:y", DOCK_CARD_Y - 15.0 if raised else DOCK_CARD_Y, 0.1)
	view.set_meta("lift", tween)


## 카드를 누르면 드래그/클릭 판정을 시작한다 (실제 처리는 _handle_card_pointer가 한다).
func _on_card_gui_input(event: InputEvent, player_id: int, card_id: StringName, view: Control) -> void:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	_card_press(player_id, card_id, get_viewport().get_mouse_position(), view.global_position)


func _card_press(player_id: int, card_id: StringName, pointer: Vector2, home: Vector2) -> void:
	_drag_press = {"player": player_id, "card": card_id, "origin": pointer, "home": home}


## 전역 포인터 입력: 카드 위에서 시작한 누르기를 클릭(확대 토글) 또는 드래그(보드에 던져 발동)로 해석한다. 처리했으면 true.
func _handle_card_pointer(event: InputEvent) -> bool:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and not _drag_press.is_empty():
		_card_move(motion.position)
		return true
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return false
	if button.pressed:
		# 확대 카드 밖(손패 독 제외)을 누르면 확대가 닫힌다.
		if _zoom_view != null and _zoom_view.visible and _drag_press.is_empty() and not Rect2(_dock.global_position, _dock.size).has_point(button.position):
			_close_zoom()
		return false
	if _drag_press.is_empty():
		return false
	_card_release(button.position)
	return true


func _card_move(pointer: Vector2) -> void:
	if _drag_press.is_empty():
		return
	if not _drag_active and pointer.distance_to(_drag_press["origin"]) > 10.0:
		_drag_begin()
	if _drag_active:
		_drag_update(pointer)


func _card_release(pointer: Vector2) -> void:
	var press: Dictionary = _drag_press
	_drag_press = {}
	if _drag_active:
		_drag_drop(pointer, press)
	else:
		_toggle_zoom(int(press["player"]), press["card"])


func _drag_begin() -> void:
	var card_id: StringName = _drag_press["card"]
	var player_id: int = int(_drag_press["player"])
	var card: BaseCard = CardRegistry.get_card(card_id)
	_drag_active = true
	_close_zoom()
	_drag_ghost = _make_card_face(card_id)
	_drag_ghost.z_index = 70
	_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_ghost.scale = Vector2(1.1, 1.1)
	_drag_ghost.pivot_offset = CARD_SIZE / 2.0
	add_child(_drag_ghost)
	var usable: bool = _card_usable_now(player_id, card)
	_drop_label.text = "[여기에 놓아 카드 발동!]" if usable else "[지금은 쓸 수 없는 카드입니다]"
	if card.needs_tile():
		_drop_label.text = "[원하는 타일 위에 놓아 설치/소환!]" if usable else "[지금은 쓸 수 없는 카드입니다]"
		if usable:
			for index: int in GameEnums.TILE_COUNT:
				(_pick_marks[index] as ReferenceRect).visible = card.can_play(state, player_id, {"tile": index})
	_drop_zone.visible = true


func _drag_update(pointer: Vector2) -> void:
	if _drag_ghost == null:
		return
	_drag_ghost.position = pointer - CARD_SIZE / 2.0
	var card: BaseCard = CardRegistry.get_card(_drag_press["card"]) if not _drag_press.is_empty() else null
	var over_board: bool = _board_rect().has_point(pointer)
	_drop_zone.add_theme_stylebox_override("panel", _style(Color(1.0, 0.83, 0.23, 0.22 if over_board else 0.08), COLOR_GOLD if over_board else Color("b8962e"), 5 if over_board else 3, 24, 0, 0))
	if card != null and card.needs_tile():
		var hovered: int = _tile_at(pointer)
		for index: int in _highlights.keys():
			(_highlights[index] as ReferenceRect).visible = index == hovered


func _drag_drop(pointer: Vector2, press: Dictionary) -> void:
	_drag_active = false
	_drop_zone.visible = false
	_clear_highlight()
	for mark: ReferenceRect in _pick_marks.values():
		mark.visible = false
	var player_id: int = int(press["player"])
	var card_id: StringName = press["card"]
	var card: BaseCard = CardRegistry.get_card(card_id)
	var reason: String = ""
	var tile: int = -1
	if not _card_usable_now(player_id, card):
		reason = "지금은 [%s]를 쓸 수 없습니다." % card.display_name
	elif card.needs_tile():
		tile = _tile_at(pointer)
		if tile == -1:
			reason = "[%s]는 보드판의 타일 위에 놓아야 합니다." % card.display_name
		elif not card.can_play(state, player_id, {"tile": tile}):
			reason = "%d번 타일에는 [%s]를 쓸 수 없습니다." % [tile, card.display_name]
	elif not _board_rect().has_point(pointer):
		reason = "카드를 보드판 위에 놓아야 발동합니다."
	if reason != "":
		_log_line(reason, Color("ff8787"))
		_return_ghost(press["home"])
		return
	_free_ghost()
	if tile != -1:
		_act(&"play_card", {"player_id": player_id, "card_id": card_id, "tile": tile})
	else:
		_on_card_pressed(player_id, card_id)


## 못 쓰는 위치/타이밍에 놓인 카드가 손패 원위치로 스르륵 돌아간다.
func _return_ghost(home: Vector2) -> void:
	if _drag_ghost == null:
		return
	var ghost: PanelContainer = _drag_ghost
	_drag_ghost = null
	var tween: Tween = create_tween()
	tween.tween_property(ghost, "global_position", home, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(ghost.queue_free)


func _free_ghost() -> void:
	if _drag_ghost != null:
		_drag_ghost.queue_free()
		_drag_ghost = null


func _cancel_card_drag() -> void:
	_drag_press = {}
	_drag_active = false
	_free_ghost()
	if _drop_zone != null:
		_drop_zone.visible = false


func _board_rect() -> Rect2:
	return Rect2(Vector2(453, 74), Vector2(460, 464))


## 화면 좌표 아래의 보드 타일 번호. 없으면 -1.
func _tile_at(pointer: Vector2) -> int:
	for index: int in _tile_views.keys():
		if (_tile_views[index] as Control).get_global_rect().has_point(pointer):
			return index
	return -1


func _toggle_zoom(player_id: int, card_id: StringName) -> void:
	var key: String = "%d:%s" % [player_id, card_id]
	if _zoom_view != null and _zoom_view.visible and _zoom_key == key:
		_close_zoom()
		return
	_open_zoom(player_id, card_id)


## 손패 카드를 2.5배(240x340)로 확대해 이름·분류·효과·사용 가능 타이밍을 또렷하게 보여 준다. 남의 턴에도 볼 수 있다.
func _open_zoom(player_id: int, card_id: StringName) -> void:
	_close_zoom()
	var card: BaseCard = CardRegistry.get_card(card_id)
	var accent: Color = CARD_CATEGORY_COLORS[card.category]
	_zoom_key = "%d:%s" % [player_id, card_id]
	_zoom_view = PanelContainer.new()
	_zoom_view.z_index = 30
	_zoom_view.custom_minimum_size = Vector2(240, 340)
	_zoom_view.size = Vector2(240, 340)
	_zoom_view.position = Vector2(563, 262)
	_zoom_view.add_theme_stylebox_override("panel", _style(Color("20263a"), accent, 5, 18, 28, 14))
	_zoom_view.gui_input.connect(func(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_close_zoom())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zoom_view.add_child(box)
	var title := _make_label(card.display_name, 26, Color("f8f9fa"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)
	var tag := _make_label("%s  (%s)" % [CARD_CATEGORY_NAMES[card.category], str(card_id).replace("_", " ")], 13, accent.lightened(0.3))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tag)
	var effect := _make_label(str(CARD_SUMMARIES.get(card_id, "")), 15, Color("dee2e6"))
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.custom_minimum_size = Vector2(210, 0)
	effect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(effect)
	var timing := _make_label("발동 타이밍: %s" % _card_timing_text(card), 12, Color("ffe8a3"))
	timing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	timing.custom_minimum_size = Vector2(210, 0)
	timing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(timing)
	var how := _make_label("사용법: " + ("보드판의 원하는 타일 위로 드래그해서 놓기" if card.needs_tile() else "보드판 위로 드래그해서 놓기"), 12, Color("a5d8ff"))
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size = Vector2(210, 0)
	how.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(how)
	var status := _make_label("지금 사용 가능" if _card_usable_now(player_id, card) else "지금은 사용할 수 없음", 12, Color("69db7c") if _card_usable_now(player_id, card) else Color("868e96"))
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(status)
	add_child(_zoom_view)


func _card_timing_text(card: BaseCard) -> String:
	var names: Array[String] = []
	for phase: int in card.playable_phases:
		var full: String = PHASE_NAMES.get(phase, "")
		names.append(full.split(" - ")[0])
	return " / ".join(names) if not names.is_empty() else "-"


func _close_zoom() -> void:
	if _zoom_view != null:
		_zoom_view.queue_free()
		_zoom_view = null
	_zoom_key = ""


# ---------------------------------------------------------------------------
# 호버 툴팁 (기물 능력 & 세트 시너지): 0.35초 이상 가리키고 있으면 뜨고, 벗어나면 즉시 사라진다
# ---------------------------------------------------------------------------

## 카드를 끄는 동안 보드판 테두리에 뜨는 드롭 존 하이라이트.
func _build_drop_zone() -> void:
	_drop_zone = PanelContainer.new()
	_drop_zone.position = Vector2(453, 74)
	_drop_zone.size = Vector2(460, 464)
	_drop_zone.z_index = 20
	_drop_zone.visible = false
	_drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_zone.add_theme_stylebox_override("panel", _style(Color(1.0, 0.83, 0.23, 0.08), Color("b8962e"), 3, 24, 0, 0))
	add_child(_drop_zone)
	_drop_label = _make_label("[여기에 놓아 카드 발동!]", 22, COLOR_GOLD)
	_drop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drop_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_drop_label.add_theme_constant_override("outline_size", 6)
	_drop_label.add_theme_color_override("font_outline_color", Color("0d1018"))
	_drop_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_zone.add_child(_drop_label)


func _build_hover_tip() -> void:
	_tip_panel = PanelContainer.new()
	_tip_panel.visible = false
	_tip_panel.z_index = 90
	_tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_panel.add_theme_stylebox_override("panel", _style(Color(0.06, 0.08, 0.13, 0.94), COLOR_GOLD, 2, 10, 12, 10))
	add_child(_tip_panel)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_panel.add_child(columns)
	# 왼쪽 칸: 이 기물의 이름과 고유 능력
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.custom_minimum_size = Vector2(200, 0)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(left)
	left.add_child(_make_label("기물 효과", 11, Color("868e96")))
	_tip_title = _make_label("", 15, COLOR_GOLD)
	_tip_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_title.custom_minimum_size = Vector2(200, 0)
	left.add_child(_tip_title)
	_tip_ability = _make_label("", 13, Color("f1f3f5"))
	_tip_ability.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_ability.custom_minimum_size = Vector2(200, 0)
	left.add_child(_tip_ability)
	var divider := VSeparator.new()
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(divider)
	# 오른쪽 칸: 세트 시너지 (던파 세트 효과처럼 도달한 단계가 강조된다)
	_tip_right = VBoxContainer.new()
	_tip_right.add_theme_constant_override("separation", 5)
	_tip_right.custom_minimum_size = Vector2(250, 0)
	_tip_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(_tip_right)


## 기물 툴팁 내용을 두 칸(왼쪽: 고유 능력 / 오른쪽: 세트 시너지)으로 채운다.
func _fill_pawn_tip(pawn_id: int) -> void:
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	for child: Node in _tip_right.get_children():
		_tip_right.remove_child(child)
		child.queue_free()
	if pawn == null:
		return
	var status: String = ""
	if pawn.is_finished:
		status = "  (완주)"
	elif pawn.restrained_turns > 0 or pawn.blocked_this_turn:
		status = "  (구속)"
	elif pawn.is_imprisoned:
		status = "  (감옥)"
	_tip_title.text = "%s  - P%d%s" % [PawnCatalog.full_name(pawn.kind, pawn.unit_no), pawn.owner_id, status]
	_tip_ability.text = PawnCatalog.ability_text(pawn.kind, pawn.unit_no)
	_tip_right.add_child(_make_label("세트 효과", 11, Color("868e96")))
	if pawn.kind == GameEnums.PawnKind.BASIC:
		_tip_right.add_child(_make_label("기본 말은 세트 시너지가 없습니다.\n기물 진화 증강으로 세트를 모으세요.", 12, Color("adb5bd")))
		return
	var owned: Array[int] = []
	for member: PlayerPawn in state.pawns_of(pawn.owner_id):
		if member.kind == pawn.kind:
			owned.append(member.unit_no)
	var data: Dictionary = PawnCatalog.set_panel_data(pawn.kind, owned)
	var header := _make_label("%s 세트  (%d/%d)" % [data["set_name"], data["count"], GameEnums.PAWNS_PER_PLAYER], 15, COLOR_GOLD)
	_tip_right.add_child(header)
	var roster: Array[String] = []
	for member_info: Dictionary in data["members"]:
		roster.append("%s %s" % ["●" if member_info["owned"] else "○", member_info["name"]])
	_tip_right.add_child(_make_label("   ".join(roster), 12, Color("ced4da")))
	for key: String in ["bonus2", "bonus4"]:
		var bonus: Dictionary = data[key]
		var active: bool = bonus["active"]
		var row := PanelContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_stylebox_override("panel", _style(Color("4a3d12") if active else Color("181e30"), COLOR_GOLD if active else Color("2c3550"), 2 if active else 1, 8, 0, 5))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 1)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(box)
		var head: Label = _make_label(("[작동 중] " if active else "") + str(bonus["label"]), 13, Color("fff3bf") if active else Color("7b8499"))
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(head)
		var body: Label = _make_label(str(bonus["text"]), 11, Color("ffe8a3") if active else Color("6c757d"))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(228, 0)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(body)
		_tip_right.add_child(row)


func _bind_tip(control: Control, provider: Callable) -> void:
	control.mouse_entered.connect(_tip_begin.bind(control, provider))
	control.mouse_exited.connect(_tip_end.bind(control))


func _tip_begin(source: Variant, provider: Callable) -> void:
	_tip_source = source
	_tip_provider = provider
	_tip_clock = 0.0
	_tip_panel.visible = false


func _tip_end(source: Variant = null) -> void:
	if source != null and _tip_source != source:
		return
	_tip_source = null
	_tip_clock = 0.0
	if _tip_panel != null:
		_tip_panel.visible = false


func _update_tip(delta: float) -> void:
	if _tip_source == null or _tip_panel == null:
		return
	if _tip_source is Object and not is_instance_valid(_tip_source):
		_tip_end()
		return
	_tip_clock += delta
	if _tip_clock < TIP_DELAY:
		return
	if not _tip_panel.visible:
		_tip_provider.call()
		_tip_panel.visible = true
		_tip_panel.reset_size()
	var pointer: Vector2 = get_viewport().get_mouse_position()
	var spot: Vector2 = pointer + Vector2(16, 18)
	var limit: Vector2 = Vector2(1366, 768) - _tip_panel.size - Vector2(4, 4)
	if spot.x > limit.x:
		spot.x = pointer.x - _tip_panel.size.x - 12.0
	_tip_panel.position = Vector2(clampf(spot.x, 4.0, limit.x), clampf(spot.y, 4.0, limit.y))


## 보드 위의 아무 말(상대 말 포함) 위에 커서가 있으면 그 말의 툴팁을 예약한다.
func _update_board_pawn_tip(pointer: Vector2) -> void:
	var found: int = -1
	var best: float = 14.0
	for pawn: PlayerPawn in state.pawns:
		var view: Node2D = _pawn_views.get(pawn.entity_id)
		if view == null or not view.visible:
			continue
		var distance: float = view.position.distance_to(pointer)
		if distance < best:
			best = distance
			found = pawn.entity_id
	var key: String = "board:%d" % found
	if found == -1:
		if _tip_source is String and str(_tip_source).begins_with("board:"):
			_tip_end()
	elif _tip_source != key:
		_tip_begin(key, _fill_pawn_tip.bind(found))


## 기물 툴팁 3줄: 전체 이름 / 고유 능력 / 세트 시너지 현황.
func _pawn_info_text(pawn_id: int) -> String:
	var pawn: PlayerPawn = state.get_pawn(pawn_id) if state != null else null
	if pawn == null:
		return ""
	var lines: Array[String] = []
	var status: String = ""
	if pawn.is_finished:
		status = "  (완주)"
	elif pawn.restrained_turns > 0 or pawn.blocked_this_turn:
		status = "  (구속)"
	elif pawn.is_imprisoned:
		status = "  (감옥)"
	lines.append("%s  - P%d%s" % [PawnCatalog.full_name(pawn.kind, pawn.unit_no), pawn.owner_id, status])
	lines.append("고유 능력: %s" % PawnCatalog.ability_text(pawn.kind, pawn.unit_no))
	var synergy: String = PawnCatalog.synergy_line(pawn.kind, state.set_count(pawn.owner_id, pawn.kind))
	lines.append(synergy if synergy != "" else "세트 시너지: 없음 (기본 말)")
	return "\n".join(lines)


# ---------------------------------------------------------------------------
# 우측 하단 대형 기물 선택 독
# ---------------------------------------------------------------------------

func _build_pawn_dock() -> void:
	_pawn_bar = Panel.new()
	_pawn_bar.position = Vector2(1058, 542)
	_pawn_bar.size = Vector2(300, 90)
	_pawn_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pawn_bar.add_theme_stylebox_override("panel", _style(Color("131826"), COLOR_PANEL_EDGE, 2, 12, 8, 0))
	add_child(_pawn_bar)
	for slot: int in GameEnums.PAWNS_PER_PLAYER:
		var button := Button.new()
		button.position = Vector2(6 + slot * 73, 12)
		button.size = Vector2(68, 76)
		button.custom_minimum_size = Vector2(68, 76)
		button.focus_mode = Control.FOCUS_NONE
		var letter := _make_label("", 24, Color("f8f9fa"))
		letter.position = Vector2(0, 10)
		letter.size = Vector2(68, 32)
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(letter)
		var place := _make_label("", 13, Color("ffe8a3"))
		place.position = Vector2(0, 46)
		place.size = Vector2(68, 20)
		place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		place.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(place)
		var number := _make_label(str(slot + 1), 11, Color("adb5bd"))
		number.position = Vector2(6, 2)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(number)
		var badge := _make_label("", 13, Color("0d1018"))
		badge.position = Vector2(42, 2)
		badge.size = Vector2(24, 18)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_stylebox_override("normal", _style(COLOR_GOLD, Color("fff3bf"), 1, 8, 0, 1))
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.visible = false
		button.add_child(badge)
		button.pressed.connect(_on_pawn_slot_pressed.bind(slot))
		button.mouse_entered.connect(_on_pawn_slot_hover.bind(slot))
		button.mouse_exited.connect(_on_pawn_slot_unhover.bind(button))
		_pawn_bar.add_child(button)
		_pawn_buttons.append(button)
		_pawn_slot_parts.append({"letter": letter, "place": place, "badge": badge})


## 기물 독이 보여 주는 주인: AI 모드는 항상 로컬 플레이어, 4P 수동 모드는 현재 턴 플레이어.
func _dock_owner() -> int:
	return local_player_id if ai_mode else manager.current_player_id()


func _on_pawn_slot_pressed(slot: int) -> void:
	_on_pawn_pressed(_dock_owner() * 10 + slot + 1)


func _on_pawn_slot_hover(slot: int) -> void:
	var pawn_id: int = _dock_owner() * 10 + slot + 1
	_preview_pawn(pawn_id)
	_tip_begin(_pawn_buttons[slot], _fill_pawn_tip.bind(pawn_id))


func _on_pawn_slot_unhover(button: Button) -> void:
	_clear_highlight()
	_tip_end(button)


func _refresh_pawn_dock() -> void:
	var owner_id: int = _dock_owner()
	var color: Color = PLAYER_COLORS[owner_id]
	var selecting: bool = not manager.is_game_over and manager.current_state == TurnManager.State.PHASE_SELECT_PAWN
	for index: int in _pawn_buttons.size():
		var button: Button = _pawn_buttons[index]
		var parts: Dictionary = _pawn_slot_parts[index]
		var pawn: PlayerPawn = state.get_pawn(owner_id * 10 + index + 1)
		var letter: String = PawnCatalog.unit_letter(pawn.kind, pawn.unit_no)
		(parts["letter"] as Label).text = letter if letter != "" else "말"
		var place: String = "완주" if pawn.is_finished else ("대기" if not pawn.has_left_start else "%d번" % pawn.current_tile_idx)
		if pawn.blocked_this_turn or pawn.restrained_turns > 0:
			place = "구속"
		elif pawn.is_imprisoned:
			place = "감옥"
		(parts["place"] as Label).text = place
		var badge: Label = parts["badge"]
		badge.visible = not pawn.carried.is_empty()
		badge.text = "x%d" % (pawn.carried.size() + 1)
		var can_pick: bool = selecting and pawn.owner_id == manager.current_player_id() and pawn.is_selectable() and not _ui_busy() and not _is_bot_turn()
		button.disabled = not can_pick
		var base: Color = color.darkened(0.55)
		button.add_theme_stylebox_override("normal", _style(base.lightened(0.1) if can_pick else base, COLOR_GOLD if can_pick else color.darkened(0.2), 4 if can_pick else 2, 10, 14 if can_pick else 2, 4))
		button.add_theme_stylebox_override("hover", _style(base.lightened(0.25), Color("fff3bf"), 4, 10, 16, 4))
		button.add_theme_stylebox_override("pressed", _style(base.darkened(0.1), COLOR_GOLD, 4, 10, 0, 4))
		button.add_theme_stylebox_override("disabled", _style(base.darkened(0.2) if pawn.is_finished else base, color.darkened(0.35), 2, 10, 0, 4))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.modulate = Color(1, 1, 1, 0.55) if pawn.is_finished else Color.WHITE


# ---------------------------------------------------------------------------
# 우측 중앙 판정 도구 전광판
# ---------------------------------------------------------------------------

## 도구별 눈금/족보 이동 규칙: [행 ID, 문구]. 결과가 나오면 해당 행에 불이 들어온다.
const TOOL_RULES: Dictionary = {
	&"D6": [["all", "1 ~ 6칸 전진"]],
	&"YUT": [["-1", "빽도 (-1): 1칸 후퇴"], ["1", "도 (1칸)"], ["2", "개 (2칸)"], ["3", "걸 (3칸)"], ["4", "★ 윷 (4칸 + 1회 재굴림)"], ["5", "★ 모 (5칸 + 1회 재굴림)"]],
	&"LIFE_ROULETTE": [["base", "1 ~ 10칸 전진"], ["seven", "★ 행운의 7 당첨: 7칸 전진 + 1회 추가 회전!"]],
	&"HOLDEM": [["high_card", "노페어 (1칸)"], ["one_pair", "원페어 (3칸)"], ["two_pair", "투페어 (5칸)"], ["three_kind", "트리플 (7칸)"], ["straight", "스트레이트 (10칸)"], ["flush", "★ 플러시 이상 (15칸!)"]],
	&"HALLI_GALLI": [["base", "기본 1 ~ 3칸 전진"], ["bonus", ""]],
	&"SLOT_777": [["miss", "꽝 (1칸)"], ["pair", "2개 일치 (4칸)"], ["triple", "3개 일치 (8칸)"], ["jackpot", "★ 777 잭팟 (20칸 폭풍 전진!)"]],
	&"REVOLVER": [["empty", "빈 총을 당길 때마다 +3칸 누적 (최대 15칸)"], ["fired", "실탄 발사 시 0칸 증발 & 즉시 턴 종료!"]],
}


func _refresh_tool_board(tool: BaseJudgmentTool, player_id: int) -> void:
	var key: String = "%d:%s" % [player_id, tool.tool_id]
	if key != _tool_board_key:
		_tool_board_key = key
		_tool_highlight = ""
		for child: Node in _tool_rows_box.get_children():
			child.queue_free()
		_tool_rows.clear()
		_tool_result_label.text = ""
		for entry: Array in TOOL_RULES.get(tool.tool_id, []):
			var row := PanelContainer.new()
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var label := _make_label(str(entry[1]), 13, Color("ced4da"))
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.custom_minimum_size = Vector2(318, 0)
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(label)
			_tool_rows_box.add_child(row)
			_tool_rows[str(entry[0])] = {"panel": row, "label": label}
	_tool_title.text = "%s 판정 도구: %s" % ["내" if ai_mode else "P%d" % player_id, tool.display_name]
	_tool_title.add_theme_color_override("font_color", (PLAYER_COLORS[player_id] as Color).lightened(0.3))
	if tool is ToolHalliGalli:
		var halli: ToolHalliGalli = tool as ToolHalliGalli
		(_tool_rows["bonus"]["label"] as Label).text = "과일 5개 종치기 적립 보너스: 현재 +%d칸 누적 중" % halli.banked_bonus
		_fruit_label.text = "바닥 과일 합계 %s - 어느 한 과일이 5개면 종을 치세요" % str(halli.fruit_totals)
	_fruit_label.visible = tool is ToolHalliGalli
	_paint_tool_rows()


func _paint_tool_rows() -> void:
	for row_id: String in _tool_rows.keys():
		var lit: bool = _tool_highlight != "" and (row_id == _tool_highlight or (_tool_highlight == "base+bonus" and (row_id == "base" or row_id == "bonus")))
		var panel: PanelContainer = _tool_rows[row_id]["panel"]
		var label: Label = _tool_rows[row_id]["label"]
		panel.add_theme_stylebox_override("panel", _style(Color("5a4710") if lit else Color("181e30"), COLOR_GOLD if lit else Color("2c3550"), 3 if lit else 1, 8, 10 if lit else 0, 5))
		label.add_theme_color_override("font_color", Color("fff3bf") if lit else Color("ced4da"))


## 굴림 결과에 해당하는 전광판 행: 불이 들어올 행 ID와 결과 문구.
func _tool_result_info(result: Dictionary) -> Dictionary:
	var details: Dictionary = result["details"]
	var steps: int = int(result["steps"])
	var row: String = ""
	var text: String = ""
	match result["tool_id"]:
		&"D6":
			row = "all"
			text = "%d -> %d칸 전진!" % [steps, steps]
		&"YUT":
			row = str(steps)
			text = ("%s -> 1칸 후퇴!" if steps < 0 else "%s -> %d칸 전진!") % ([YUT_NAMES.get(steps, "?")] if steps < 0 else [YUT_NAMES.get(steps, "?"), steps])
		&"LIFE_ROULETTE":
			row = "seven" if int(details["face"]) == ToolLifeRoulette.JACKPOT_FACE else "base"
			text = "%d -> %d칸 전진!%s" % [steps, steps, "  행운의 7! 한 번 더!" if row == "seven" else ""]
		&"HOLDEM":
			var hand: StringName = details["hand"]
			row = "flush" if ["flush", "full_house", "four_kind", "straight_flush"].has(str(hand)) else str(hand)
			text = "%s -> %d칸 전진!" % [HAND_NAMES.get(hand, "?"), steps]
		&"HALLI_GALLI":
			row = "base+bonus" if int(details["bonus"]) > 0 else "base"
			text = "기본 %d + 보너스 %d -> %d칸 전진!" % [details["base"], details["bonus"], steps]
		&"SLOT_777":
			row = {1: "miss", 4: "pair", 8: "triple", 20: "jackpot"}.get(steps, "miss")
			text = "%s -> %d칸 전진!" % [{"miss": "꽝", "pair": "2개 일치", "triple": "3개 일치", "jackpot": "777 잭팟"}[row], steps]
		&"REVOLVER":
			if details["fired"]:
				row = "fired"
				text = "탕! 누적 %d칸 증발 -> 0칸, 턴 종료!" % details["lost"]
			else:
				row = "empty"
				text = "찰칵 -> 누적 %d칸 (멈추면 %d칸 전진)" % [steps, steps]
	if result["reroll"]:
		text += "  (재굴림!)"
	return {"row": row, "text": text}


func _highlight_tool_result(result: Dictionary) -> void:
	var info: Dictionary = _tool_result_info(result)
	_tool_highlight = str(info["row"])
	_tool_result_label.text = str(info["text"])
	_paint_tool_rows()


func _category_text(category: GameEnums.CardCategory) -> String:
	match category:
		GameEnums.CardCategory.TRAP: return "타일 설치형 (사용 후 보드판의 타일을 클릭)"
		GameEnums.CardCategory.SUMMON: return "중립 NPC 소환형"
	return "즉발·개입형"


func _card_usable_now(player_id: int, card: BaseCard) -> bool:
	if manager.is_game_over or _ui_busy() or manager.stack_offer_pending() or not card.is_playable_in(manager.current_state):
		return false
	if ai_mode and player_id != local_player_id:
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
	_roll_button.disabled = not can_roll or _tile_pick_active or _ui_busy() or manager.stack_offer_pending() or _is_bot_turn()
	var can_stop: bool = not over and tool.has_pending_state() and current_phase == TurnManager.State.PHASE_ROLL_WAIT
	if tool is ToolRussianRoulette:
		# 러시안 룰렛: [방아쇠 당기기]와 [멈추고 N칸 이동 확정]을 한 세트로 상시 노출한다. 1발도 못 당겼으면 멈추기는 비활성(회색)이고,
		# 누적이 생기면 초록색으로 바뀐다.
		_roll_button.text = "[방아쇠 당기기 (+%d칸 누적)] (R)" % ToolRussianRoulette.STEPS_PER_EMPTY
		_stop_button.visible = not over
		_stop_button.text = "[멈추고 %d칸 이동 확정]" % (tool as ToolRussianRoulette).accumulated
		_stop_button.disabled = not can_stop or _tile_pick_active or _is_bot_turn()
		_stop_button.modulate = Color(0.55, 1.0, 0.62) if can_stop else Color.WHITE
	else:
		_roll_button.text = "주사위 굴리기 (R) - %s" % tool.display_name
		_stop_button.visible = can_stop
		_stop_button.text = "멈추고 이동 확정"
		_stop_button.disabled = false
		_stop_button.modulate = Color.WHITE
	_bell_button.visible = tool is ToolHalliGalli and not _is_bot_turn()
	_refresh_tool_board(state.tools[_dock_owner()], _dock_owner())
	var window_open: bool = not over and (current_phase == TurnManager.State.PHASE_INTERRUPT_ROLL or current_phase == TurnManager.State.PHASE_RESOLUTION)
	# AI 모드: 개입 창은 사람(P1)이 낼 카드를 들고 있을 때만 [패스]를 보여 주고, 아니면 봇이 0.8초 뒤 자동으로 넘긴다.
	_skip_button.visible = window_open and not manager.stack_offer_pending() and (not ai_mode or _human_can_intervene())
	_skip_button.disabled = _ui_busy()
	_skip_button.text = "개입 카드 사용 / 패스" if ai_mode else "개입 패스(진행)"
	_castle_button.visible = not over and manager.can_castle(player_id) and not _is_bot_turn()
	_bomb_button.visible = not over and manager.can_pass_bomb(player_id) and not _is_bot_turn()
	if _bomb_button.visible:
		_bomb_button.text = "[폭탄 떠넘기기 (%d칸)]" % (state.penalty_of(player_id) * 2)
	_hint_label.text = _hint_text(current_phase, tool)

	_refresh_pawn_dock()
	_tool_option.disabled = over or not (current_phase == TurnManager.State.PHASE_TURN_BEGIN or current_phase == TurnManager.State.PHASE_ROLL_WAIT) or tool.has_pending_state()
	var tool_index: int = ToolRegistry.ALL_IDS.find(tool.tool_id)
	if tool_index != -1:
		_tool_option.select(tool_index)


func _hint_text(current_phase: TurnManager.State, tool: BaseJudgmentTool) -> String:
	if manager.is_game_over:
		return "게임 종료. [새 게임]으로 다시 시작하세요."
	if _fx_busy:
		return "굴러가는 중..."
	if _is_bot_turn() and not manager.stack_offer_pending() and current_phase != TurnManager.State.PHASE_INTERRUPT_ROLL and current_phase != TurnManager.State.PHASE_RESOLUTION:
		return "P%d (AI 봇)가 생각하는 중입니다..." % manager.current_player_id()
	if ai_mode and (current_phase == TurnManager.State.PHASE_INTERRUPT_ROLL or current_phase == TurnManager.State.PHASE_RESOLUTION) and not manager.stack_offer_pending():
		return "[개입 카드 사용 / 패스] 낼 카드가 있으면 아래 카드를 누르세요. 낼 카드가 없으면 잠시 뒤 자동으로 넘어갑니다."
	if manager.stack_offer_pending():
		return "윷놀이 기물 업기: [업기 (하나로 합체)] 또는 [그냥 두기 (개별 유지)]를 고르세요. (시간이 지나면 자동으로 업기)"
	if _tile_pick_active:
		return "타일 선택 모드: 보드판에서 사용할 타일(초록 테두리)을 클릭하세요. 취소는 ESC 또는 오른쪽 클릭."
	match current_phase:
		TurnManager.State.PHASE_TURN_BEGIN:
			var pending: int = state.penalty_of(manager.current_player_id())
			if pending != 0:
				return "우노 +4 페널티 %d칸이 걸려 있습니다! 즉발 카드가 있으면 [폭탄 떠넘기기], 아니면 굴리는 순간 가장 앞선 말이 후퇴합니다." % pending
			if _tool_has_gauge():
				return "굴리기 버튼(또는 R/Space)을 꾹 눌러 파워 게이지를 채우고 손을 떼면 굴러갑니다. 카드(▣ 표시는 타일 클릭)도 쓸 수 있습니다. (판정 도구: %s)" % tool.display_name
			return "카드(▣ 표시는 타일을 클릭해 설치/소환)를 쓰거나 [굴리기]를 누르세요. (판정 도구: %s)" % tool.display_name
		TurnManager.State.PHASE_ROLL_WAIT:
			if tool.has_pending_state():
				return "계속 당기거나, 멈추고 누적 칸수만큼 이동하세요. 실탄이 나오면 모두 증발합니다!"
			return "다시 굴려야 합니다 (재굴림)." if not manager.move_queue.is_empty() else ("굴리기 버튼을 꾹 눌렀다 떼서 굴리세요." if _tool_has_gauge() else "굴리세요.")
		TurnManager.State.PHASE_INTERRUPT_ROLL:
			return "[개입 기회! 카드를 사용하거나 '패스'를 누르세요]  눈금이 정해졌습니다. 개입 카드를 가진 플레이어는 지금 카드를 누르세요."
		TurnManager.State.PHASE_SELECT_PAWN:
			return "이동할 말을 고르세요 (버튼에 마우스를 올리면 도착 경로가 노란 테두리로 보입니다)."
		TurnManager.State.PHASE_RESOLUTION:
			return "[개입 기회! 카드를 사용하거나 '패스'를 누르세요]  잡힌 플레이어는 [바이츠 더 더스트]로 되감을 수 있습니다."
		TurnManager.State.PHASE_MOVING_STEP:
			return "말이 한 칸씩 이동합니다..."
		TurnManager.State.PHASE_ROUND_START:
			return "라운드 시작 증강 드래프트 중입니다."
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
	# 손을 뗀 순간의 파워 게이지 값을 연출에 넘긴다 (게이지가 없는 도구·클릭은 0.5).
	_pending_power = _charge_value if _charging and _tool_has_gauge() else 0.5
	_stop_charge()
	if manager.is_game_over or _roll_button.disabled or _ui_busy() or _is_bot_turn():
		return
	if manager.current_state == TurnManager.State.PHASE_TURN_BEGIN:
		_act(&"proceed")
	if manager.current_state == TurnManager.State.PHASE_ROLL_WAIT:
		_act(&"roll")


## 굴림 버튼/키를 누르기 시작했다. 주사위·윷이면 파워 게이지가 좌우로 왕복하기 시작한다.
func _begin_charge(by_key: bool) -> void:
	if _charging or _roll_button.disabled or _ui_busy() or manager.is_game_over or _stack_overlay != null or _is_bot_turn():
		return
	if _tile_pick_active:
		return
	_charging = true
	_charge_by_key = by_key
	_charge_clock = 0.0
	_charge_value = 0.0
	_power_bar.visible = _tool_has_gauge() and not instant_roll_for_test
	_power_label.visible = _power_bar.visible


func _on_roll_button_up() -> void:
	# pressed(굴리기 확정)가 먼저 처리된 뒤에도 게이지가 남아 있으면(버튼 밖에서 뗌) 취소한다.
	call_deferred("_stop_charge_if_unconfirmed")


func _stop_charge_if_unconfirmed() -> void:
	if _charging and not _charge_by_key:
		_stop_charge()


func _stop_charge() -> void:
	_charging = false
	_charge_by_key = false
	if _power_bar != null:
		_power_bar.visible = false
		_power_label.visible = false


## 현재 판정 도구가 홀드 & 릴리즈 파워 게이지를 쓰는가 (기본 D6, 박달나무 윷).
func _tool_has_gauge() -> bool:
	if state == null:
		return false
	var tool: BaseJudgmentTool = state.tools[manager.current_player_id()]
	return tool.tool_id == &"D6" or tool.tool_id == &"YUT"


func _on_stop_pressed() -> void:
	if _stop_button.disabled:
		return
	_act(&"stop")


func _on_bell_pressed() -> void:
	if state != null and state.tools[manager.current_player_id()] is ToolHalliGalli:
		_act(&"bell")


func _on_skip_pressed() -> void:
	manager.force_timeout()
	_refresh_all()


func _on_castle_pressed() -> void:
	var pairs: Array[Array] = CastleCommand.valid_pairs(state, manager.current_player_id())
	if pairs.size() <= 1:
		_act(&"castle")
		return
	var options: Array[Dictionary] = []
	for pair: Array in pairs:
		var a: PlayerPawn = pair[0]
		var b: PlayerPawn = pair[1]
		options.append({
			"label": "%s(%d번) ↔ %s(%d번)" % [a.display_label(), a.current_tile_idx, b.display_label(), b.current_tile_idx],
			"value": [a.entity_id, b.entity_id],
		})
	_show_choice("위치를 맞바꿀 체스 기물 두 개", options, _on_castle_picked)


func _on_castle_picked(value: Variant) -> void:
	var ids: Array = value
	_act(&"castle", {"pawn_a": int(ids[0]), "pawn_b": int(ids[1])})


func _on_pass_bomb_pressed() -> void:
	_act(&"pass_bomb")


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


func _on_card_pressed(player_id: int, card_id: StringName) -> void:
	var card: BaseCard = CardRegistry.get_card(card_id)
	if card.needs_tile():
		_begin_tile_pick(player_id, card_id)
		return
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
		_:
			_act(&"play_card", {"player_id": player_id, "card_id": card_id})


func _play_card_with(value: Variant, player_id: int, card_id: StringName, param_name: String) -> void:
	_act(&"play_card", {"player_id": player_id, "card_id": card_id, param_name: value})


# ---------------------------------------------------------------------------
# 타일 선택 모드 (TRP/SUM 카드)
# ---------------------------------------------------------------------------

func _begin_tile_pick(player_id: int, card_id: StringName) -> void:
	var card: BaseCard = CardRegistry.get_card(card_id)
	if not _card_usable_now(player_id, card):
		_log_line("지금은 [%s]를 쓸 수 없습니다 (내 턴 시작 구간에서만)." % card.display_name, Color("868e96"))
		return
	_tile_pick_active = true
	_tile_pick_player = player_id
	_tile_pick_card = card_id
	var valid_count: int = 0
	for index: int in GameEnums.TILE_COUNT:
		var valid: bool = card.can_play(state, player_id, {"tile": index})
		(_pick_marks[index] as ReferenceRect).visible = valid
		if valid:
			valid_count += 1
	if valid_count == 0:
		_log_line("[%s]를 놓을 수 있는 타일이 없습니다." % card.display_name, Color("868e96"))
		_cancel_tile_pick()
		return
	_pick_banner.text = "[%s] P%d - 사용할 타일을 클릭하세요 (ESC/오른쪽 클릭: 취소)" % [card.display_name, player_id]
	_pick_banner.visible = true
	_refresh_controls()


func _cancel_tile_pick() -> void:
	if not _tile_pick_active and _pick_banner != null and not _pick_banner.visible:
		return
	_tile_pick_active = false
	_tile_pick_card = &""
	if _pick_banner != null:
		_pick_banner.visible = false
	for mark: ReferenceRect in _pick_marks.values():
		mark.visible = false
	if manager != null and manager.state != null:
		_refresh_controls()


func _on_tile_gui_input(event: InputEvent, index: int) -> void:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed or not _tile_pick_active:
		return
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_tile_pick()
	elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
		_complete_tile_pick(index)


## 고른 타일로 카드를 사용한다. 그 타일에 쓸 수 없으면 선택 모드를 유지한다.
func _complete_tile_pick(tile: int) -> void:
	if not _tile_pick_active:
		return
	var card: BaseCard = CardRegistry.get_card(_tile_pick_card)
	if not card.can_play(state, _tile_pick_player, {"tile": tile}):
		_log_line("%d번 타일에는 [%s]를 쓸 수 없습니다. 다른 타일을 고르세요." % [tile, card.display_name], Color("ff8787"))
		return
	var player_id: int = _tile_pick_player
	var card_id: StringName = _tile_pick_card
	_cancel_tile_pick()
	_act(&"play_card", {"player_id": player_id, "card_id": card_id, "tile": tile})


# ---------------------------------------------------------------------------
# 오버레이: 선택창 / 증강 드래프트 / 결과창
# ---------------------------------------------------------------------------

## 오버레이 패널의 불투명한 어두운 배경 (뒤의 화면이 비치지 않게 한다).
func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("14171c")
	style.border_color = Color("5c6068")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(20)
	return style


func _new_overlay() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	return overlay


func _show_choice(title: String, options: Array[Dictionary], on_pick: Callable, columns: int = 1) -> void:
	_close_choice()
	_choice_overlay = _new_overlay()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_choice_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
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


func _refresh_overlays() -> void:
	_refresh_draft_overlay()
	_refresh_stack_overlay()
	if manager.is_game_over and _result_overlay == null:
		_show_result_overlay()


## 드래프트 중이면 아직 고르지 않은 첫 플레이어(P1 -> P4 순서)의 3지선다를 화면 중앙에 띄운다.
func _refresh_draft_overlay() -> void:
	var pending: Array[int] = []
	if manager.current_state == TurnManager.State.PHASE_ROUND_START and not manager.is_game_over:
		for candidate: int in manager.draft_pending_players():
			# AI 모드에서는 P1이 고른 뒤 봇들이 BotController로 자동 선택하므로 오버레이에는 사람만 나온다.
			if not (ai_mode and _bot.is_bot(candidate)):
				pending.append(candidate)
	if pending.is_empty():
		_close_draft_overlay()
		return
	var player_id: int = pending[0]
	if _auto_draft_enabled and not ai_mode and player_id != PLAYER_IDS[0]:
		manager.auto_pick_draft(player_id)
		_log_line("P%d 증강 자동 선택 완료" % player_id, Color("868e96"))
		_refresh_all()
		return
	if _draft_overlay != null and _draft_player == player_id:
		return
	_build_draft_overlay(player_id, pending.size())


func _build_draft_overlay(player_id: int, remaining: int) -> void:
	_close_draft_overlay()
	_draft_player = player_id
	_draft_overlay = _new_overlay()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draft_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title: Label = _make_label("라운드 %d 증강 드래프트 - P%d 차례 (%d/%d)" % [state.round_number, player_id, PLAYER_IDS.size() - remaining + 1, PLAYER_IDS.size()], 20, PLAYER_COLORS[player_id])
	box.add_child(title)
	box.add_child(_make_label("3개 중 하나를 고르세요. 기물 진화 / 판정 도구 교체 / 교칙 제정 / 생떼 카드 패키지가 섞여 나옵니다.", 12, Color("adb5bd")))
	var offers: Array[StringName] = manager.draft_offers_for(player_id)
	for index: int in offers.size():
		var definition: AugmentDef = AugmentRegistry.get_def(offers[index])
		var text: String = "[%s]  %s\n%s" % [AugmentDef.category_name(definition.category), definition.display_name, definition.describe(state, player_id)]
		var button: Button = _make_button(text, _on_augment_chosen.bind(player_id, index, definition), 14)
		button.custom_minimum_size = Vector2(560, 74)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_color_override("font_color", CATEGORY_COLORS[definition.category])
		box.add_child(button)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	box.add_child(footer)
	var auto_check := CheckBox.new()
	auto_check.text = "P2~P4는 무작위 자동 선택"
	auto_check.button_pressed = _auto_draft_enabled
	auto_check.toggled.connect(_on_auto_draft_toggled)
	footer.add_child(auto_check)
	footer.add_child(_make_button("남은 전원 무작위 자동 선택", _on_draft_auto_pressed, 13))
	add_child(_draft_overlay)


func _close_draft_overlay() -> void:
	if _draft_overlay != null:
		_draft_overlay.queue_free()
		_draft_overlay = null
	_draft_player = -1


func _on_auto_draft_toggled(enabled: bool) -> void:
	_auto_draft_enabled = enabled
	_close_draft_overlay()
	_refresh_draft_overlay()


func _on_draft_auto_pressed() -> void:
	for player_id: int in manager.draft_pending_players():
		manager.auto_pick_draft(player_id)
	_refresh_all()


func _on_augment_chosen(player_id: int, index: int, definition: AugmentDef) -> void:
	if definition.needs_pawn_choice(state, player_id):
		var options: Array[Dictionary] = []
		for pawn: PlayerPawn in state.basic_pawns_of(player_id):
			options.append({"label": "말 %d번 (현재 %d번 타일)" % [pawn.slot, pawn.current_tile_idx], "value": pawn.entity_id})
		_show_choice("진화시킬 기본 말을 고르세요", options, _pick_augment_with_pawn.bind(player_id, index))
		return
	_act(&"pick_augment", {"player_id": player_id, "index": index})


func _pick_augment_with_pawn(pawn_id: int, player_id: int, index: int) -> void:
	_act(&"pick_augment", {"player_id": player_id, "index": index, "pawn_id": pawn_id})


func _show_result_overlay() -> void:
	_close_result_overlay()
	_result_overlay = _new_overlay()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(560, 0)
	panel.add_child(box)
	var winner_id: int = state.winner
	var title: Label = _make_label("게임 종료!", 34, Color("ffd43b"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var summary: Label = _make_label("승리자: P%d  /  달성 조건: %s" % [winner_id, _winner_reason_text()], 20, PLAYER_COLORS.get(winner_id, Color.WHITE))
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(summary)
	var restart: Button = _make_button("새 게임 시작", _new_game, 20)
	restart.custom_minimum_size = Vector2(0, 52)
	box.add_child(restart)
	add_child(_result_overlay)


var _last_reason: StringName = &""


func _winner_reason_text() -> String:
	return VictoryChecker.reason_text(_last_reason)


func _close_result_overlay() -> void:
	if _result_overlay != null:
		_result_overlay.queue_free()
		_result_overlay = null


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
	ctx.is_preview = true  # Dry-Run: 법전 로그·깜빡임 없이 수치만 계산
	ctx = state.rulebook.process_context(ctx)
	# 실제 이동과 같은 계산(포 넘기 +2, 포석 -1 등 기물 능력 포함)으로 예상 경로를 구한다.
	var path: Array[int] = MoveExecutor.plan_path(state, pawn, ctx, MoveReport.new())
	for index: int in path.size():
		var highlight: ReferenceRect = _highlights[path[index]]
		highlight.visible = true
		highlight.border_width = 6.0 if index == path.size() - 1 else 3.0


func _clear_highlight() -> void:
	for highlight: ReferenceRect in _highlights.values():
		highlight.visible = false
		highlight.border_width = 3.0
	_board_hover_pawn = -1


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
	_last_reason = reason
	_log_line("[승리] P%d 승리! - %s" % [winner_id, VictoryChecker.reason_text(reason)], PLAYER_COLORS[winner_id])
	_close_draft_overlay()
	_cancel_tile_pick()
	_show_result_overlay()
	_refresh_all()


func _ui_busy() -> bool:
	return _fx_busy or (_announcer != null and _announcer.active)


func _announce(tag: String, headline: String, body: String, color: Color, extra: Control = null, duration: float = 1.5) -> void:
	if _announcer == null:
		return
	_announcer.instant = instant_roll_for_test
	_announcer.announce(tag, headline, body, color, extra, duration)
	if _announcer.active:
		_refresh_controls()


## 새 교칙이 제정되면 현재 법전 전체를 중앙에 띄우고 새로 들어온 줄을 금색으로 강조한다.
func _announce_law_added(new_law: LawResource, removed_law: LawResource) -> void:
	var board := VBoxContainer.new()
	board.add_theme_constant_override("separation", 4)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for law: LawResource in state.rulebook.active_laws_queue:
		var is_new: bool = law == new_law
		var row := PanelContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.custom_minimum_size = Vector2(420, 0)
		row.add_theme_stylebox_override("panel", _style(Color("4a3d12") if is_new else Color("1b2030"), COLOR_GOLD if is_new else Color("3b4252"), 3 if is_new else 1, 8, 6, 5))
		var text: String = "%s[%s] %s - %s" % ["NEW  " if is_new else "", law.law_id, law.law_name, law.description]
		var label := _make_label(text, 13, Color("fff3bf") if is_new else Color("adb5bd"))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)
		board.add_child(row)
	var body: String = new_law.description
	if removed_law != null:
		body += "\n(가장 오래된 [%s] %s이(가) 밀려났습니다)" % [removed_law.law_id, removed_law.law_name]
	_announce("법전 개정", "새 교칙: %s" % new_law.law_name, body, COLOR_GOLD, board, 2.6)


## 카드 사용 알림에 붙일 카드 앞면 (손패 카드와 같은 모양, 클릭 불가).
func _make_card_preview(card_id: StringName) -> Control:
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_make_card_face(card_id))
	return holder


## 앞면 카드 한 장 (100x140, 클릭 불가). 알림 미리보기와 드래그 중인 카드가 쓴다.
func _make_card_face(card_id: StringName) -> PanelContainer:
	var card: BaseCard = CardRegistry.get_card(card_id)
	var accent: Color = CARD_CATEGORY_COLORS[card.category]
	var view := PanelContainer.new()
	view.custom_minimum_size = CARD_SIZE
	view.size = CARD_SIZE
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_theme_stylebox_override("panel", _style(Color("2c3550"), accent, 4, 10, 8, 6))
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(box)
	var title := _make_label(card.display_name, 14, Color("f8f9fa"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)
	var summary := _make_label(str(CARD_SUMMARIES.get(card_id, "")), 11, Color("ced4da"))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(summary)
	return view


func _on_law_added(new_law: LawResource, removed_law: LawResource) -> void:
	var text: String = "[법전] 교칙 제정: [%s] %s" % [new_law.law_id, new_law.law_name]
	if removed_law != null:
		text += "  (가장 오래된 [%s] %s이(가) 밀려났습니다)" % [removed_law.law_id, removed_law.law_name]
	_log_line(text, Color("ffe066"))
	_refresh_laws()
	_announce_law_added(new_law, removed_law)


func _on_law_applied(law: LawResource, timing: String, dice_before: int, dice_after: int, modified: bool) -> void:
	# 값을 실제로 바꾼 교칙만 보여 준다. 이동 계산(ON_MOVE_CALC) 교칙은 매 걸음 로그를 도배하지 않도록
	# 이동 보고서(move_resolved)의 요약 한 줄로만 남긴다 (경로·눈금이 실제로 달라졌을 때).
	if not modified:
		return
	if timing != RuleContext.ON_MOVE_CALC:
		var detail: String = ""
		if dice_before != dice_after:
			detail = "  눈금 %d → %d" % [dice_before, dice_after]
		_log_line("[법전] [%s] %s 작동 (%s)%s" % [law.law_id, law.law_name, timing, detail], Color("ffe066"))
		_announce("법전 발동", "[%s] %s" % [law.law_id, law.law_name], (law.description + detail.strip_edges().insert(0, "\n") if detail != "" else law.description), Color("ffe066"), null, 1.1)
	_flash_law_ids[law.law_id] = true
	_refresh_laws()
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		_flash_law_ids.erase(law.law_id)
		if state != null:
			_refresh_laws())


func _on_event(kind: StringName, data: Dictionary) -> void:
	match kind:
		&"roll_resolved":
			_handle_roll_event(data)
		&"stack_resolved":
			var stack_names: Array[String] = []
			for member_id: Variant in data["members"]:
				stack_names.append(_pawn_name(int(member_id)))
			if data["stacked"]:
				_log_line("[업기] P%d: %s 하나로 합체!" % [data["player_id"], ", ".join(stack_names)], Color("ffd43b"))
			else:
				_log_line("[업기] P%d: 그냥 두기 - 개별 유지" % data["player_id"], Color("adb5bd"))
		&"move_resolved": _log_move(data)
		&"card_played":
			var card: BaseCard = CardRegistry.get_card(data["card_id"])
			_log_line("[카드] P%d [%s] 사용%s" % [data["player_id"], card.display_name, " (개입 대기열 - 나중에 낸 카드부터 실행)" if data["queued"] else ""], Color("74c0fc"))
			_announce("카드 발동", "[P%d 발동!] %s" % [data["player_id"], card.display_name], ("개입 대기열에 쌓였습니다 (나중에 낸 카드부터 실행)\n" if data["queued"] else "") + str(CARD_SUMMARIES.get(data["card_id"], "")), PLAYER_COLORS[int(data["player_id"])], _make_card_preview(data["card_id"]), 1.2)
		&"bell_result":
			_log_line("P%d 종 %s" % [data["player_id"], "성공! 보너스 +2 적립" if data["success"] else "실패"], Color("ffa94d"))
		&"npc_phase_resolved":
			for report: Dictionary in data["reports"]:
				_log_line("[NPC] NPC가 %s로 이동 (잡힌 말: %s)" % [str(report["path"]), str(report["caught"])], Color("fa5252"))
				if not (report["caught"] as Array).is_empty():
					var npc_name: String = "도적" if report["display_id"] == &"SUM_01" else "고스트"
					var stolen: String = ""
					if not (report["stolen_cards"] as Array).is_empty():
						stolen = " / 카드 %d장 강탈" % (report["stolen_cards"] as Array).size()
					_announce("중립 기물", "%s가 말을 잡았습니다!" % npc_name, "잡힌 말 %d개%s" % [(report["caught"] as Array).size(), stolen], Color("fa5252"), null, 1.5)
		&"augment_offers":
			_log_line("[증강] 라운드 %d 증강 드래프트가 열렸습니다." % data["round"], Color("ffa94d"))
		&"augment_picked":
			_log_line("[증강] P%d%s: %s - %s" % [data["player_id"], " (자동)" if data["auto"] else "", AugmentRegistry.get_def(data["augment_id"]).display_name, data["text"]], Color("ffa94d"))
			_announce("P%d 증강 선택" % data["player_id"], AugmentRegistry.get_def(data["augment_id"]).display_name, str(data["text"]), Color("ffa94d"), null, 1.4)
		&"bang_resolved":
			var target_name: String = _pawn_name(int(data["target"]))
			if data["dodged"]:
				_log_line("[뱅!] P%d의 총알이 %s를 노렸지만 P%d가 [%s]를 버리고 회피(빗나감)!" % [data["shooter"], target_name, state.get_pawn(int(data["target"])).owner_id, _card_name(data["discarded_card"])], Color("ffa8a8"))
			else:
				_log_line("[뱅!] P%d의 총알이 %s 명중! 손패가 없어 출발선으로 돌아갑니다." % [data["shooter"], target_name], Color("ff6b6b"))
		&"castled":
			_log_line("[캐슬링] P%d: %s ↔ %s 위치 교환" % [data["player_id"], _pawn_name(int(data["pawn_a"])), _pawn_name(int(data["pawn_b"]))], Color("74c0fc"))
			_announce("기물 능력", "[P%d 발동!] 캐슬링" % data["player_id"], "%s와(과) %s의 위치를 맞바꿉니다" % [_pawn_name(int(data["pawn_a"])), _pawn_name(int(data["pawn_b"]))], Color("74c0fc"), null, 1.1)
		&"pawn_knocked":
			_log_line("[알까기] %s이(가) %d번 → %d번으로 튕겨 나갔습니다" % [_pawn_name(int(data["pawn_id"])), data["from"], data["to"]], Color("b197fc"))
		&"pawn_pushed_back":
			_log_line("[포석] 무적의 바둑돌에 막혀 %s이(가) %d번 → %d번으로 밀려났습니다" % [_pawn_name(int(data["pawn_id"])), data["from"], data["to"]], Color("b197fc"))
		&"bomb_passed":
			_log_line("[우노 +4] P%d가 [%s]를 소모해 폭탄을 P%d에게 떠넘겼습니다 (%d칸)" % [data["from"], _card_name(data["card_id"]), data["to"], data["amount"]], Color("ffd43b"))
		&"bomb_applied":
			if int(data["pawn_id"]) == -1:
				_log_line("[우노 +4] P%d: 후퇴시킬 말이 없어 페널티가 사라졌습니다" % data["player_id"], Color("ffd43b"))
			else:
				_log_line("[우노 +4] P%d의 %s이(가) %d칸 후퇴 (%d번 → %d번)" % [data["player_id"], _pawn_name(int(data["pawn_id"])), data["steps"], data["from"], state.get_pawn(int(data["pawn_id"])).current_tile_idx], Color("ffd43b"))
		&"game_over":
			_last_reason = data["reason"]
	_refresh_all()


func _log_roll(data: Dictionary) -> String:
	var result: Dictionary = data["result"]
	var details: Dictionary = result["details"]
	var prefix: String = "[굴림] P%d [%s] " % [data["player_id"], state.tools[data["player_id"]].display_name]
	var text: String = ""
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
	_log_line(prefix + text, Color("f1f3f5"))
	return text


func _log_move(data: Dictionary) -> void:
	var pawn_id: int = data["pawn_id"]
	var text: String = "[이동] %s" % _pawn_name(pawn_id)
	if data["canceled"]:
		text += " 이동 취소됨" + (" (무인도에 갇혀 있음: 짝수 눈금이 필요)" if data["jailed"] else " (교칙)")
	else:
		text += " 경로 %s" % str(data["path"])
	if data["released"]:
		text += "  무인도 탈출!"
	if data["bounced"]:
		text += "  결승선에서 튕겨 나옴"
	if data["warped"]:
		text += "  옷장 워프 → 중앙"
	if data["stopped_early"]:
		text += "  이동 중단"
	if not (data["captured"] as Array).is_empty():
		text += "  [잡기] %s" % str(data["captured"])
	if data["extra_turn"]:
		text += "  (추가 턴)"
	if data["bonus_roll"]:
		text += "  (사기 윷: 추가 굴림)"
	if not (data["law_notes"] as Array).is_empty():
		text += "  [법전] 이동 변조: %s" % ", ".join(data["law_notes"])
	if not (data["ability_notes"] as Array).is_empty():
		text += "  [능력] %s" % ", ".join(data["ability_notes"])
	if not (data["rammed"] as Array).is_empty():
		text += "  [차 들이받기] %s 추방" % str(data["rammed"])
		_announce("기물 능력", "[발동!] 장기 차 돌진", "경로의 적 %s을(를) 들이받아 추방했습니다" % str(data["rammed"]), Color("ff922b"), null, 1.1)
	if not (data["destroyed"] as Array).is_empty():
		text += "  [증기선] 상대 설치물 파괴 %d개" % (data["destroyed"] as Array).size()
	if int(data["dog_cards"]) > 0:
		text += "  [강아지] 지나친 빵집에서 카드 %d장" % data["dog_cards"]
	if data["pushed_back"]:
		text += "  [포석] 무적에 막혀 한 칸 후퇴"
	if not (data["restrained"] as Array).is_empty():
		text += "  [초나라 포진] 구속 %s" % str(data["restrained"])
	if data["hotel_built"]:
		text += "  호텔 건설"
	if int(data["salary_cards"]) > 0:
		text += "  월급날: 카드 %d장" % data["salary_cards"]
	if data["drawn_card"] != &"":
		text += "  [빵집] 카드 획득"
	if not (data["effects"] as Array).is_empty():
		text += "  교칙 효과 %s" % str(data["effects"])
	_log_line(text, PLAYER_COLORS[state.get_pawn(pawn_id).owner_id])


func _log_line(text: String, color: Color) -> void:
	if _log == null:
		return
	_log.append_text("[color=#%s]%s[/color]\n" % [color.to_html(false), text])
	# 상단 리본의 토스트: 가장 최근 이벤트 한 줄 요약
	if _toast_label != null:
		_toast_label.text = text
		_toast_label.add_theme_color_override("font_color", color.lightened(0.25))


func _pawn_name(pawn_id: int) -> String:
	var pawn: PlayerPawn = state.get_pawn(pawn_id) if state != null else null
	if pawn == null:
		return "말#%d" % pawn_id
	return "P%d-말%d" % [pawn.owner_id, pawn.slot]


func _card_name(card_id: StringName) -> String:
	var card: BaseCard = CardRegistry.get_card(card_id)
	return card.display_name if card != null else str(card_id)


func _attachment_name(attachment_id: String) -> String:
	match attachment_id:
		"TRP_01": return "거울의 힘"
		"TRP_02": return "나락"
		"TRP_03": return "지뢰"
		"TRP_04": return "무인도"
		"HOTEL": return "호텔"
	return attachment_id


## 주사위·판정 도구 결과를 보드 한가운데에 큼직하게 띄웠다가 서서히 사라지게 한다.
func _show_center_banner(text: String, color: Color) -> void:
	if _center_banner == null:
		return
	_center_label.text = text
	_center_label.add_theme_color_override("font_color", color)
	_center_banner.reset_size()
	var board_center: Vector2 = BOARD_ORIGIN + Vector2(BOARD_SIZE, BOARD_SIZE) / 2.0
	_center_banner.position = board_center - _center_banner.size / 2.0
	_center_banner.modulate = Color.WHITE
	_center_banner.visible = true
	if _center_banner.has_meta("fade"):
		var previous: Tween = _center_banner.get_meta("fade")
		if previous != null and previous.is_valid():
			previous.kill()
	var tween: Tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(_center_banner, "modulate:a", 0.0, 0.45)
	tween.tween_callback(func() -> void: _center_banner.visible = false)
	_center_banner.set_meta("fade", tween)


## 파워 게이지(굴림 버튼 위)와 판정 도구 연출기를 만든다.
func _build_roll_fx() -> void:
	_power_bar = ProgressBar.new()
	_power_bar.position = Vector2(533, 518)
	_power_bar.size = Vector2(300, 18)
	_power_bar.min_value = 0.0
	_power_bar.max_value = 100.0
	_power_bar.show_percentage = false
	_power_bar.visible = false
	_power_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_bar.add_theme_stylebox_override("background", _style(Color("0b0e16"), Color("5c6b94"), 2, 9, 0, 0))
	_power_bar.add_theme_stylebox_override("fill", _style(Color("51cf66"), Color("fff3bf"), 2, 7, 0, 0))
	add_child(_power_bar)
	_power_label = _make_label("POWER 0%", 12, Color("fff3bf"))
	_power_label.position = Vector2(533, 498)
	_power_label.size = Vector2(300, 18)
	_power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_power_label.visible = false
	add_child(_power_label)
	_presenter = RollPresenter.new()
	add_child(_presenter)
	_announcer = EventAnnouncer.new()
	_announcer.center = BOARD_ORIGIN + Vector2(BOARD_SIZE, BOARD_SIZE) / 2.0
	add_child(_announcer)
	_announcer.drained.connect(func() -> void:
		if state != null:
			_refresh_all())


## 엔진이 확정한 굴림 결과를 연출한 뒤 로그·중앙 배너로 공개한다. 연출 중에는 입력을 잠가 결과가 먼저 새지 않게 한다.
func _handle_roll_event(data: Dictionary) -> void:
	var result: Dictionary = data["result"]
	var tool_id: StringName = result["tool_id"]
	_presenter.instant = instant_roll_for_test
	if instant_roll_for_test or not RollPresenter.supports(tool_id):
		_reveal_roll(data)
		return
	var generation: int = _fx_generation
	_fx_serial += 1
	var serial: int = _fx_serial
	_fx_busy = true
	_refresh_controls()
	await _presenter.play(tool_id, result, _pending_power)
	if generation != _fx_generation or serial != _fx_serial:
		return
	_fx_busy = false
	_reveal_roll(data)
	_refresh_all()


func _reveal_roll(data: Dictionary) -> void:
	if int(data["player_id"]) == _dock_owner():
		_highlight_tool_result(data["result"])
	var roll_text: String = _log_roll(data)
	var details: Dictionary = (data["result"] as Dictionary)["details"]
	var fired: bool = bool(details.get("fired", false))
	_show_center_banner("P%d  %s" % [data["player_id"], roll_text.strip_edges()], Color("ff8787") if fired else Color("fff3bf"))


## 윷놀이 기물의 [선택적 업기] 팝업: 화면 중앙에 [업기 (하나로 합체)] / [그냥 두기 (개별 유지)] 두 버튼을 띄운다.
func _refresh_stack_overlay() -> void:
	var pending: bool = manager.stack_offer_pending() and not manager.is_game_over
	if not pending:
		_close_stack_overlay()
		return
	if _stack_overlay != null:
		return
	var offer: Dictionary = manager.pending_stack_offer()
	var mover: PlayerPawn = state.get_pawn(int(offer["mover"]))
	var names: Array[String] = []
	for other_id: Variant in offer["others"]:
		names.append(state.get_pawn(int(other_id)).display_label())
	_stack_overlay = _new_overlay()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stack_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("131826"), COLOR_GOLD, 4, 18, 26, 20))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := _make_label("윷놀이 기물 - 선택적 업기", 20, COLOR_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var body := _make_label("%s이(가) 아군 [%s]와(과) 같은 타일에 도착했습니다.\n하나로 합체할까요?" % [mover.display_label(), ", ".join(names)], 14, Color("dee2e6"))
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(body)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)
	var stack_button: Button = _make_button("[업기 (하나로 합체)]", _on_stack_choice.bind(true), 16, Color("2b8a3e"), 12)
	stack_button.custom_minimum_size = Vector2(230, 48)
	buttons.add_child(stack_button)
	var keep_button: Button = _make_button("[그냥 두기 (개별 유지)]", _on_stack_choice.bind(false), 16, Color("495057"), 12)
	keep_button.custom_minimum_size = Vector2(230, 48)
	buttons.add_child(keep_button)
	add_child(_stack_overlay)


func _on_stack_choice(stack: bool) -> void:
	_close_stack_overlay()
	_act(&"stack_choice", {"stack": stack})


func _close_stack_overlay() -> void:
	if _stack_overlay != null:
		_stack_overlay.queue_free()
		_stack_overlay = null


## 좌상단 모드 토글: [모드: 1P vs 3AI 봇] / [모드: 4P 수동 조작]. 게임 중에도 언제든 바꿀 수 있다.
func _build_mode_toggle() -> void:
	_mode_toggle = _make_button("", _on_mode_toggle_pressed, 13, Color("2f5d50"), 8)
	_mode_toggle.position = Vector2(8, 8)
	_mode_toggle.size = Vector2(230, 32)
	_mode_toggle.tooltip_text = "AI 대전: P1만 직접 조작하고 P2~P4는 봇이 플레이합니다. 4P 수동 조작: 한 화면에서 모두 직접 조작합니다."
	add_child(_mode_toggle)
	_refresh_mode_toggle()


func _refresh_mode_toggle() -> void:
	_mode_toggle.text = "[모드: 1P vs 3AI 봇]" if ai_mode else "[모드: 4P 수동 조작]"


func _on_mode_toggle_pressed() -> void:
	ai_mode = not ai_mode
	_bot.set_enabled(ai_mode)
	_dock_player = -1
	_log_line("[모드] %s" % ("1P vs 3AI 봇: P2~P4를 AI가 조작합니다." if ai_mode else "4P 수동 조작: 모든 플레이어를 직접 조작합니다."), Color("63e6be"))
	_refresh_mode_toggle()
	if manager != null and manager.state != null:
		_refresh_all()


## 지금 턴이 AI 봇의 차례인가 (AI 모드에서 P2~P4).
func _is_bot_turn() -> bool:
	return ai_mode and _bot.is_bot(manager.current_player_id())


## 사람(P1)이 지금 개입 창에서 낼 수 있는 카드를 들고 있는가.
func _human_can_intervene() -> bool:
	for card_id: StringName in state.hands[local_player_id]:
		var card: BaseCard = CardRegistry.get_card(card_id)
		if card.is_playable_in(manager.current_state) and card.could_play(state, local_player_id):
			return true
	return false


## 봇은 화면의 굴림 연출이 끝날 때까지 기다린다.
func _bot_should_wait() -> bool:
	return _ui_busy()
