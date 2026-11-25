# File: res://scenes/room_rules_panel.gd
# Class: class_name RoomRulesPanel
# Role: [방 규칙 설정] 창. 싱글(놀이터) 커스텀과 친선 줘팸터 방장이 함께 쓴다. 고른 값은
#       GameSession.set_rule로 브라우저 프로필에 남는다 (바꾸지 않은 항목은 난이도 기본값). 온라인은 방장이 판을 시작할 때 모두에게 보낸다.
class_name RoomRulesPanel
extends Control

signal closed()

const BanPanel := preload("res://scenes/room_ban_panel.gd")

## [키, 제목, [[값, 버튼 글, 적용 설명], ...]]
const ROWS: Array = [
	["trap_reveal", "함정 카드 정체", [
		[true, "공개 [기본]", "모든 함정의 정체와 효과가 보여요."],
		[false, "비공개 [심리전]", "상대 함정은 밟거나 해체할 때 정체가 드러나요."],
	]],
	["super_freq", "초증강 등장 빈도", [
		[1, "기본", "초증강이 기본 확률로 등장해요."],
		[2, "축제 (확률 2배)", "증강 선택지에서 초증강이 더 자주 나와요."],
		[3, "대축제 (확률 3배)", "증강 선택지에서 초증강이 가장 자주 나와요."],
		[0, "끄기", "초증강이 등장하지 않아요."],
	]],
	["laws", "특수 승리 법전", [
		[true, "켜기 [기본]", "법전 조건을 달성하면 특수 승리할 수 있어요."],
		[false, "끄기 [완주 승부만]", "말 4개 완주로만 순위를 정해요."],
	]],
	["speed", "게임 속도", [
		["normal", "기본 템포", "8·14·20라운드에 템포 업이 발동해요."],
		["speed", "스피드전", "4·8·12라운드 템포 업 · 리벤지 부스터 +2칸"],
	]],
]

const PAPER := Color("fffdf4")
const OPTION_FILL := Color("f2f7ed")
const OPTION_EDGE := Color("b0cbbb")
const SELECTED_FILL := Color("167759")
const SELECTED_EDGE := Color("0e5945")
var _selectors: Dictionary[String, RuleStepper] = {}
var _preset: RuleStepper
var _preset_note: Label = null
var _scroll: ScrollContainer = null
var _column: VBoxContainer
var _body: HBoxContainer
var _ban_panel: BanPanel
var _layout_tabs: HBoxContainer
var _layout_tab_buttons: Array[Button] = []
var _narrow_page := 0
## 친선전 방장 화면에서 열었다: 난이도와 상관없는 방 규칙(GameSession.room_rules)을 보여 준다.
var room_mode: bool = false


## 화면 전체를 덮는 창을 만들어 parent에 붙인다.
static func open(parent: Node, for_room: bool = false) -> RoomRulesPanel:
	var panel := RoomRulesPanel.new()
	panel.name = "RoomRulesPanel"
	panel.room_mode = for_room
	parent.add_child(panel)
	return panel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not get_parent() is Control:
		size = get_viewport_rect().size  # 창(Window)에 바로 붙으면 앵커가 화면을 따르지 않는다
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 80
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	card.name = "RulesCard"
	card.add_theme_stylebox_override("panel", LobbyTheme.style(Color("e5f1e5"), Color("528f77"), 3, 28, 10, 19))
	center.add_child(card)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 12)
	card.add_child(_column)
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", LobbyTheme.style(Color("d2e9d6"), Color("afd0bc"), 1, 17, 0, 12))
	var title := LobbyTheme.label("방 규칙 설정", 28, SELECTED_EDGE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)
	_column.add_child(header)
	_layout_tabs = HBoxContainer.new()
	_layout_tabs.add_theme_constant_override("separation", 7)
	_column.add_child(_layout_tabs)
	for page: int in 2:
		var tab := _button(["방 규칙", "밴 설정"][page], _select_page.bind(page), 17)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size.y = 40.0
		tab.toggle_mode = true
		_layout_tab_buttons.append(tab)
		_layout_tabs.add_child(tab)
	_body = HBoxContainer.new()
	_body.add_theme_constant_override("separation", 9)
	_column.add_child(_body)
	# 규칙 줄은 스크롤 상자 안에: 번역이 길어 창이 화면보다 커지면 안쪽만 스크롤한다
	_scroll = ScrollContainer.new()
	_scroll.name = "RulesScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	_scroll.follow_focus = true
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_stretch_ratio = 1.23
	_body.add_child(_scroll)
	var gutter := MarginContainer.new()
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_theme_constant_override("margin_right", 10)
	_scroll.add_child(gutter)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 14)
	gutter.add_child(rows)
	rows.add_child(_make_presets())
	for row: Array in ROWS:
		rows.add_child(_make_row(row))
	rows.add_child(_make_row(board_row()))
	if room_mode:
		var options: Array = []
		for level: int in range(1, BotTemper.LEVELS.size() + 1):
			options.append([level, BotTemper.label(level), "빈자리에 추가한 컴퓨터에 이 난이도를 적용해요."])
		rows.add_child(_make_row(["bot_level", "빈자리 컴퓨터 난이도", options]))
	_ban_panel = BanPanel.new()
	_ban_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ban_panel.changed.connect(_on_bans_changed)
	_body.add_child(_ban_panel)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	_column.add_child(footer)
	var reset := _button("기본값으로", _on_reset, 16)
	reset.name = "ResetRules"
	reset.custom_minimum_size = Vector2(166, 50)
	footer.add_child(reset)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var ok := LobbyTheme.cream_button("확인", close, 24)
	ok.name = "CloseRules"
	ok.custom_minimum_size = Vector2(148, 54)
	footer.add_child(ok)
	_refresh()
	_fit_modal()
	get_viewport().size_changed.connect(_fit_modal)


func _make_presets() -> Control:
	var card := _section()
	card.name = "RulePresets"
	var box := card.get_child(0) as VBoxContainer
	box.add_child(LobbyTheme.label("빠른 설정", 20, LobbyTheme.INK))
	_preset = RuleStepper.new("Preset", "빠른 설정", MatchRules.PRESETS)
	_preset.picked.connect(_on_preset)
	box.add_child(_preset)
	_preset_note = _note("")
	_preset_note.name = "PresetNote"
	_preset.detail = _preset_note
	box.add_child(_preset_note)
	return card


func _fit_modal() -> void:
	var viewport_size := get_viewport_rect().size
	if not get_parent() is Control:
		size = viewport_size
	var width := minf(1112.0, maxf(0.0, viewport_size.x - 74.0))
	_column.custom_minimum_size.x = width
	var split := width >= 820.0
	_body.custom_minimum_size.y = clampf(viewport_size.y - (210.0 if split else 257.0), 100.0, 552.0)
	_layout_tabs.visible = not split
	_scroll.visible = split or _narrow_page == 0
	_ban_panel.visible = split or _narrow_page == 1
	for i: int in _layout_tab_buttons.size():
		_layout_tab_buttons[i].set_pressed_no_signal(i == _narrow_page)


func _select_page(page: int) -> void:
	_narrow_page = page
	_fit_modal()


func _on_bans_changed(key: String, ids: Array) -> void:
	GameSession.set_rule(key, ids)
	_refresh()


func _on_preset(key: Variant) -> void:
	GameSession.apply_preset(StringName(key))
	_refresh()


func _make_row(row: Array) -> Control:
	var key: String = row[0]
	var card := _section()
	var box := card.get_child(0) as VBoxContainer
	box.add_child(LobbyTheme.label(row[1], 20, LobbyTheme.INK))
	var selector := RuleStepper.new("Rule_%s" % key, row[1], row[2])
	selector.picked.connect(_on_pick.bind(key))
	_selectors[key] = selector
	box.add_child(selector)
	selector.detail = _note("")
	box.add_child(selector.detail)
	return card


static func _section() -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := LobbyTheme.style(PAPER, Color("c9ddce"), 1, 17, 0, 16)
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 13)
	card.add_child(box)
	return card


static func _note(text: String) -> Label:
	var note := LobbyTheme.label(text, 14, LobbyTheme.INK_SOFT)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return note


static func _button(text: String, callback: Callable, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", SELECTED_EDGE)
	button.add_theme_color_override("font_hover_color", SELECTED_EDGE)
	button.add_theme_color_override("font_focus_color", SELECTED_EDGE)
	button.add_theme_color_override("font_pressed_color", SELECTED_EDGE)
	button.add_theme_stylebox_override("normal", LobbyTheme.style(OPTION_FILL, OPTION_EDGE, 1, 13, 0, 8))
	button.add_theme_stylebox_override("hover", LobbyTheme.style(Color("e4f2df"), SELECTED_FILL, 2, 13, 0, 8))
	button.add_theme_stylebox_override("pressed", LobbyTheme.style(Color("cce6d3"), SELECTED_EDGE, 2, 13, 0, 8))
	button.add_theme_stylebox_override("disabled", LobbyTheme.style(OPTION_FILL, OPTION_EDGE, 1, 13, 0, 8))
	button.add_theme_stylebox_override("focus", LobbyTheme.style(Color.TRANSPARENT, Color("b58227"), 2, 13))
	button.pressed.connect(callback)
	return button


## 보드판 줄: 고를 수 있는 보드는 BoardCatalog가 정한다 (값은 보드 id 글자).
static func board_row() -> Array:
	var options: Array = []
	for board: Dictionary in BoardCatalog.available():
		options.append([String(board["id"]), str(board["name"]), board.get("settings_note", board["desc"])])
	return ["board", "보드판", options]


func _on_pick(value: Variant, key: String) -> void:
	if key == "board":
		GameSession.set_board(value)  # 보드판은 방 규칙 override와 따로 저장한다 (컴퓨터 대전에도 적용)
	else:
		GameSession.set_rule(key, value)
	_refresh()


func _on_reset() -> void:
	GameSession.reset_rules()
	GameSession.set_board(BoardCatalog.DEFAULT_ID)
	_refresh()


## 현재 규칙을 선택 상태로 표시한다.
func _refresh() -> void:
	var rules: Dictionary = GameSession.room_rules() if room_mode else GameSession.match_rules()
	var preset: StringName = MatchRules.preset_of(rules)
	_preset.show_value(preset, "사용자 설정")
	for key: String in _selectors:
		_selectors[key].show_value(rules.get(key))
	_ban_panel.refresh(rules)


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


class RuleStepper extends HBoxContainer:
	signal picked(value: Variant)

	var _options: Array
	var _index := -1
	var _caption: Label
	var detail: Label

	func _ready() -> void:
		resized.connect(_reserve_text_space)
		detail.resized.connect(_reserve_text_space)
		_reserve_text_space.call_deferred()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
			_reserve_text_space.call_deferred()

	func _reserve_text_space() -> void:
		if detail == null or _caption.size.x <= 0.0 or detail.size.x <= 0.0:
			return
		_caption.custom_minimum_size.y = _option_height(_caption, 1)
		detail.custom_minimum_size.y = _option_height(detail, 2)
		detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	func _option_height(label: Label, column: int) -> float:
		var font := label.get_theme_font("font")
		var font_size := label.get_theme_font_size("font_size")
		var height := 0.0
		for option: Array in _options:
			var text := L10n.t(str(option[column]))
			var measured := font.get_multiline_string_size(
				text, HORIZONTAL_ALIGNMENT_LEFT, label.size.x, font_size)
			height = maxf(height, measured.y)
		return ceilf(height) + 4.0

	func _init(key: String, heading: String, options: Array) -> void:
		name = key
		_options = options
		var is_preset := key == "Preset"
		add_theme_constant_override("separation", 7)
		add_child(_arrow("Previous", heading, -1))
		var value := PanelContainer.new()
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var fill := SELECTED_FILL if is_preset else Color("dfede2")
		var edge := SELECTED_EDGE if is_preset else Color("a7c8b2")
		value.add_theme_stylebox_override("panel", LobbyTheme.style(fill, edge, 1, 13, 0, 6))
		add_child(value)
		_caption = LobbyTheme.label("", 18, Color.WHITE if is_preset else SELECTED_EDGE)
		_caption.name = "Value"
		_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value.add_child(_caption)
		add_child(_arrow("Next", heading, 1))

	func _arrow(node_name: String, heading: String, direction: int) -> Button:
		var button := RoomRulesPanel._button("", _step.bind(direction), 16)
		button.name = node_name
		button.custom_minimum_size = Vector2(50, 48)
		button.accessibility_name = "%s · %s" % [L10n.t(heading), L10n.t("◀ 이전" if direction < 0 else "다음 ▶")]
		button.disabled = _options.size() < 2
		var mark := ArrowMark.new()
		mark.direction = direction
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.modulate.a = 0.45 if button.disabled else 1.0
		button.add_child(mark)
		mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		return button

	func show_value(value: Variant, fallback: String = "") -> void:
		_index = -1
		_caption.text = fallback
		for index: int in _options.size():
			if str(_options[index][0]) == str(value):
				_index = index
				_caption.text = str(_options[index][1])
				break
		detail.text = str(_options[_index][2]) if _index >= 0 else ""
		_reserve_text_space.call_deferred()

	func _step(direction: int) -> void:
		if _options.size() < 2:
			return
		var start := _index if _index >= 0 or direction > 0 else 0
		var next := posmod(start + direction, _options.size())
		picked.emit(_options[next][0])


class ArrowMark extends Control:
	var direction: int = 1

	func _draw() -> void:
		var center := size * 0.5
		var top := center + Vector2(-3.5 * direction, -6.5)
		var point := center + Vector2(3.5 * direction, 0.0)
		var bottom := center + Vector2(-3.5 * direction, 6.5)
		draw_polyline(PackedVector2Array([top, point, bottom]), SELECTED_EDGE, 3.6, true)
		for at: Vector2 in [top, point, bottom]:
			draw_circle(at, 1.8, SELECTED_EDGE, true, -1.0, true)
