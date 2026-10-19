# File: res://scenes/rulebook.gd
# Class: class_name Rulebook
# Role: 규칙 도감. 배지와 역할별 아이콘은 개별 이미지로 표시하고, 본문·카드·탭은 기존 UI 노드로 구성한다. 카드·교칙 문구는 실제 데이터에서 읽어 온다.
class_name Rulebook
extends Control

const PAPER: Color = Color("fbf4df")
const PAPER_LINE: Color = Color(0.72, 0.6, 0.4, 0.22)
const LEATHER: Color = Color("8a6a4a")
const LEATHER_DARK: Color = Color("5f4630")
const INK: Color = Color("6b4a2a")
const ORANGE: Color = Color("e08a1a")
const ACCENT: Color = Color("c2457a")
const GREEN: Color = Color("2f8f4e")
const BLUE: Color = Color("2f7fb8")
const GOLD: Color = Color("c98a14")
const FRAME: Color = Color("bfe9d8")
const FRAME_EDGE: Color = Color("5fc9a0")
const TEAL: Color = Color("7cc4b4")
const TEAL_DARK: Color = Color("4a9a8a")
const TAB_NAMES: Array[String] = ["시작하기", "한 턴", "보드", "잡기", "도구", "말", "카드", "법전"]
const TAB_ICONS: Array[StringName] = [&"face", &"hourglass", &"grid", &"sword", &"dice", &"crown", &"book", &"gear"]
const TAB_ART: Array[StringName] = [&"start", &"turn", &"board", &"capture"]
const ART: Dictionary = {
	&"start": preload("res://assets/ui/trickcal/rulebook/UI_RULE_START.tres"),
	&"turn": preload("res://assets/ui/trickcal/rulebook/UI_RULE_TURN.tres"),
	&"board": preload("res://assets/ui/trickcal/rulebook/UI_RULE_BOARD.tres"),
	&"capture": preload("res://assets/ui/trickcal/rulebook/UI_RULE_CAPTURE.tres"),
	&"hidden_trap": preload("res://assets/ui/trickcal/rulebook/UI_RULE_HIDDEN_TRAP.tres"),
	&"pass": preload("res://assets/ui/trickcal/rulebook/UI_RULE_PASS.tres"),
	&"island": preload("res://assets/ui/trickcal/rulebook/UI_RULE_ISLAND.tres"),
	&"pawn_ability": preload("res://assets/ui/trickcal/rulebook/UI_RULE_PAWN_ABILITY.tres"),
	&"tool_swap": preload("res://assets/ui/trickcal/rulebook/UI_RULE_TOOL_SWAP.tres"),
	&"card_law": preload("res://assets/ui/trickcal/rulebook/UI_RULE_CARD_LAW.tres"),
	&"fair_roll": preload("res://assets/ui/trickcal/rulebook/UI_RULE_FAIR_ROLL.tres"),
	&"badge": preload("res://assets/ui/trickcal/rulebook/UI_RULE_BADGE.tres"),
	&"laurel": preload("res://assets/ui/trickcal/rulebook/UI_RULE_LAUREL.tres"),
}
## 위쪽 두 탭이 묶는 장: 규칙 기본(0~3), 도감(4~7).
const GROUP_NAMES: Array[String] = ["기본 규칙", "도감"]
const GROUP_SIZE: int = 4
const STAGE: Vector2 = Vector2(1366.0, 768.0)

## 현재 장 번호(0부터).
var spread: int = 0
var _stage: Control = null
var _left_holder: VBoxContainer = null
var _right_holder: Container = null
var _right_scroll: ScrollContainer = null
var _notebook_title: Label = null
var _list_buttons: Array[Button] = []
var _group_tabs: Array[Button] = []
var _page_label: Label = null
var _prev: Button = null
var _next: Button = null
var _prev_name: Label = null
var _next_name: Label = null
var _list_box: VBoxContainer = null


## 부모 위에 규칙 도감을 연다. 반환: 도감 노드 (이름은 Popup이라 설정 팝업과 같은 방식으로 찾는다).
static func open(parent: Control, start_spread: int = 0) -> Rulebook:
	var book := Rulebook.new()
	parent.add_child(book)
	book.show_spread(start_spread)
	return book


func _init() -> void:
	name = "Popup"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 50
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.13, 0.12, 0.2, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_stage = Control.new()
	_stage.custom_minimum_size = STAGE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_stage)
	_build_book()
	_build_header()
	_build_list()
	_build_notebook()
	_build_cards_area()
	_build_arrows()
	_build_ribbon()


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_RIGHT: show_spread(spread + 1)
		KEY_LEFT: show_spread(spread - 1)
		KEY_ESCAPE: close()
		_: return
	get_viewport().set_input_as_handled()


func close() -> void:
	queue_free()


func spread_count() -> int:
	return TAB_NAMES.size()


# ---------------------------------------------------------------------------
# 틀: 책 테두리, 머리글, 왼쪽 항목 줄, 노트, 카드 칸, 화살표, 리본
# ---------------------------------------------------------------------------

static func _box(bg: Color, border: Color, border_width: int, radius: int, shadow: int = 0, margin: int = 0, shadow_color: Color = Color(0, 0, 0, 0.25)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.shadow_color = shadow_color
	box.shadow_size = shadow
	box.set_content_margin_all(margin)
	return box


func _place(node: Control, pos: Vector2, node_size: Vector2) -> void:
	node.position = pos
	node.size = node_size
	_stage.add_child(node)


## 역할에 맞춘 개별 PNG. AtlasTexture는 투명 여백만 제외하며 원본 픽셀은 보존한다.
static func _art(role: StringName, extent: Vector2) -> TextureRect:
	var image := TextureRect.new()
	image.name = "Art_" + String(role)
	image.set_meta("art_role", role)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	image.texture = ART[role] as Texture2D
	image.custom_minimum_size = extent
	image.size = extent
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image


## 연한 청록 테두리의 큰 책 틀 두 겹과 그 안의 크림색 바탕.
func _build_book() -> void:
	var outer := Panel.new()
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_theme_stylebox_override("panel", _box(Color("e9f7ee"), FRAME, 12, 40, 18, 0, Color(0, 0, 0, 0.45)))
	_place(outer, Vector2(186, 108), Vector2(1156, 634))
	var edge := Panel.new()
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.add_theme_stylebox_override("panel", _box(Color("f3ecd2"), FRAME_EDGE, 4, 30))
	_place(edge, Vector2(204, 126), Vector2(1120, 598))


func _build_header() -> void:
	var back := Button.new()
	back.name = "CloseBook"
	back.focus_mode = Control.FOCUS_NONE
	HubArt.button(back, &"round_button", 80)
	var chevron := HubArt.icon(&"next")
	chevron.flip_h = true
	chevron.set_anchors_preset(Control.PRESET_FULL_RECT)
	chevron.offset_left = 16
	chevron.offset_top = 14
	chevron.offset_right = -16
	chevron.offset_bottom = -14
	back.add_child(chevron)
	back.pressed.connect(close)
	_place(back, Vector2(30, 18), Vector2(80, 80))
	var title := HubKit.outlined("규칙 도감", 50, Color.WHITE, Color("3a3250"), 12)
	_place(title, Vector2(126, 28), Vector2(360, 66))
	var badge := Label.new()
	badge.text = "?"
	badge.add_theme_font_size_override("font_size", 24)
	badge.add_theme_color_override("font_color", Color.WHITE)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_stylebox_override("normal", _box(Color("4a4560"), Color("2a2640"), 3, 18))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(badge, Vector2(330, 44), Vector2(38, 38))
	# 위쪽 탭 두 개 (책 위로 살짝 솟은 베이지 탭)
	for index: int in GROUP_NAMES.size():
		var tab := Button.new()
		tab.name = "Group%d" % index
		tab.text = GROUP_NAMES[index]
		tab.focus_mode = Control.FOCUS_NONE
		tab.add_theme_font_size_override("font_size", 20)
		tab.pressed.connect(func() -> void: show_spread(index * GROUP_SIZE))
		_place(tab, Vector2(500 + index * 170, 66), Vector2(160, 52))
		_group_tabs.append(tab)


## 왼쪽 세로 항목 줄: 현재 탭의 장 4개. 고른 항목은 흰 알약에 점선 느낌의 초록 테두리.
func _build_list() -> void:
	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 12)
	_list_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_list_box, Vector2(28, 148), Vector2(196, 420))
	for index: int in TAB_NAMES.size():
		var button := Button.new()
		button.name = "Tab%d" % index
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(196, 86)
		button.pressed.connect(show_spread.bind(index))
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var disc := Panel.new()
		disc.name = "Disc"
		disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		disc.position = Vector2(2, -4)
		disc.size = Vector2(52, 52)
		button.add_child(disc)
		var icon: Control
		if index < TAB_ART.size():
			icon = _art(TAB_ART[index], Vector2(40, 40))
			icon.position = Vector2(6, 6)
		else:
			icon = HubKit.Icon.new(TAB_ICONS[index], Color("2f6f66"), Color("ffe48a"))
			icon.position = Vector2(8, 8)
			icon.size = Vector2(36, 36)
		disc.add_child(icon)
		var plate := Label.new()
		plate.name = "Plate"
		plate.text = TAB_NAMES[index]
		plate.add_theme_font_size_override("font_size", 22)
		plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plate.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.position = Vector2(30, 22)
		plate.size = Vector2(160, 50)
		button.add_child(plate)
		_list_box.add_child(button)
		_list_buttons.append(button)


func _build_notebook() -> void:
	var leather := Panel.new()
	leather.mouse_filter = Control.MOUSE_FILTER_IGNORE
	leather.add_theme_stylebox_override("panel", _box(LEATHER, LEATHER_DARK, 4, 22, 8, 0, Color(0, 0, 0, 0.35)))
	_place(leather, Vector2(256, 140), Vector2(552, 574))
	var paper := LinedPaper.new()
	_place(paper, Vector2(272, 156), Vector2(520, 542))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(column, Vector2(290, 168), Vector2(484, 520))
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 8)
	column.add_child(title_row)
	title_row.add_child(_art(&"laurel", Vector2(44, 34)))
	_notebook_title = Label.new()
	_notebook_title.add_theme_font_size_override("font_size", 30)
	_notebook_title.add_theme_color_override("font_color", Color("4a3520"))
	title_row.add_child(_notebook_title)
	var mirrored := _art(&"laurel", Vector2(44, 34))
	mirrored.flip_h = true
	title_row.add_child(mirrored)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_left_holder = VBoxContainer.new()
	_left_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_holder.add_theme_constant_override("separation", 10)
	scroll.add_child(_left_holder)
	var medal := _art(&"badge", Vector2(80, 96))
	medal.name = "RulebookBadge"
	_place(medal, Vector2(740, 112), Vector2(80, 96))


func _build_cards_area() -> void:
	_right_scroll = ScrollContainer.new()
	_right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_place(_right_scroll, Vector2(834, 142), Vector2(468, 570))
	_right_holder = VBoxContainer.new()
	_right_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_holder.add_theme_constant_override("separation", 12)
	_right_scroll.add_child(_right_holder)


func _build_arrows() -> void:
	_prev = _arrow_button(false)
	_prev.name = "PrevPage"
	_prev.pressed.connect(func() -> void: show_spread(spread - 1))
	_place(_prev, Vector2(210, 396), Vector2(50, 76))
	_prev_name = _arrow_label()
	_place(_prev_name, Vector2(196, 474), Vector2(78, 24))
	_next = _arrow_button(true)
	_next.name = "NextPage"
	_next.pressed.connect(func() -> void: show_spread(spread + 1))
	_place(_next, Vector2(1304, 396), Vector2(50, 76))
	_next_name = _arrow_label()
	_place(_next_name, Vector2(1290, 474), Vector2(78, 24))


func _arrow_button(forward: bool) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	# 좌우는 같은 이미지의 수평 반전만 사용해 굵기와 비율을 맞춘다.
	var icon := HubArt.icon(&"next")
	icon.flip_h = not forward
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(icon)
	button.mouse_entered.connect(func() -> void: if not button.disabled: HubKit._bounce(button, 1.15))
	button.mouse_exited.connect(func() -> void: HubKit._bounce(button, 1.0))
	button.pivot_offset = Vector2(25, 38)
	return button


func _arrow_label() -> Label:
	var label := HubKit.outlined("", 17, Color.WHITE, Color("3a3250"), 5)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _build_ribbon() -> void:
	var ribbon := Ribbon.new()
	_place(ribbon, Vector2(560, 706), Vector2(246, 56))
	_page_label = HubKit.outlined("", 20, Color.WHITE, Color("8a3a0a"), 5)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_label.position = Vector2(30, 10)
	_page_label.size = Vector2(186, 30)
	ribbon.add_child(_page_label)


# ---------------------------------------------------------------------------
# 장 바꾸기
# ---------------------------------------------------------------------------

func show_spread(index: int) -> void:
	spread = clampi(index, 0, spread_count() - 1)
	for holder: Node in [_left_holder, _right_holder]:
		for child: Node in holder.get_children():
			holder.remove_child(child)
			child.queue_free()
	var content: Dictionary = _chapter(spread)
	_notebook_title.text = content["title"]
	var first: bool = true
	for block: Variant in content["left"]:
		var node: Control = block as Control
		if first and node is RichTextLabel:
			first = false
		_left_holder.add_child(node)
	for block: Variant in content["right"]:
		_right_holder.add_child(block as Control)
	_right_scroll.scroll_vertical = 0
	var group: int = spread / GROUP_SIZE
	for index2: int in _group_tabs.size():
		var active: bool = index2 == group
		var tab: Button = _group_tabs[index2]
		tab.add_theme_color_override("font_color", Color("6b4a2a") if active else Color("8a7a58"))
		tab.add_theme_color_override("font_hover_color", Color("6b4a2a"))
		for state: String in ["normal", "hover", "pressed"]:
			var style: StyleBoxFlat = _box(Color("fbf4df") if active else Color("c9b98e"), Color("e6d6a8") if active else Color("a8975f"), 3, 16, 0, 4)
			style.corner_radius_bottom_left = 0
			style.corner_radius_bottom_right = 0
			tab.add_theme_stylebox_override(state, style)
		tab.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		tab.size = Vector2(160, 52 if active else 44)
		tab.position.y = 66 if active else 74
	for index3: int in _list_buttons.size():
		var visible_here: bool = index3 / GROUP_SIZE == group
		var button: Button = _list_buttons[index3]
		button.visible = visible_here
		var selected: bool = index3 == spread
		var disc: Panel = button.get_node("Disc")
		var plate: Label = button.get_node("Plate")
		var teal_back: StyleBoxFlat = _box(Color("f4fffa") if selected else TEAL, Color("3f9a2b") if selected else TEAL_DARK, 4, 22, 5, 0, Color(0, 0, 0, 0.25))
		button.add_theme_stylebox_override("normal", teal_back)
		var teal_hover: StyleBoxFlat = teal_back.duplicate()
		teal_hover.bg_color = Color.WHITE if selected else TEAL.lightened(0.12)
		button.add_theme_stylebox_override("hover", teal_hover)
		button.add_theme_stylebox_override("pressed", teal_back)
		disc.add_theme_stylebox_override("panel", _box(Color("fffdf0"), Color("3f9a2b") if selected else TEAL_DARK, 4, 26, 3))
		plate.add_theme_color_override("font_color", Color("2f6f66") if selected else Color.WHITE)
		plate.add_theme_color_override("font_outline_color", Color(0.1, 0.35, 0.3, 0.9))
		plate.add_theme_constant_override("outline_size", 0 if selected else 5)
	_page_label.text = "%d / %d" % [spread + 1, spread_count()]
	_prev.disabled = spread == 0
	_next.disabled = spread == spread_count() - 1
	_prev.modulate.a = 0.35 if _prev.disabled else 1.0
	_next.modulate.a = 0.35 if _next.disabled else 1.0
	_prev_name.text = TAB_NAMES[spread - 1] if spread > 0 else ""
	_next_name.text = TAB_NAMES[spread + 1] if spread < spread_count() - 1 else ""


# ---------------------------------------------------------------------------
# 글·카드 부품
# ---------------------------------------------------------------------------

## BBCode 문단 (갈색 잉크). [b]굵게[/b] [color=#c2457a]강조[/color]
func _rich(text: String, size_px: int = 19, color: Color = INK) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("normal_font_size", size_px)
	label.add_theme_font_size_override("bold_font_size", size_px)
	label.add_theme_color_override("default_color", color)
	label.add_theme_constant_override("line_separation", 6)
	label.custom_minimum_size = Vector2(440, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 굵은 글씨는 글꼴에 굵은체가 없어 뭉개지므로 형광펜으로 칠한 것처럼 노란 띠로 강조한다 (밑줄은 쓰지 않는다).
	label.text = text.replace("[b]", "[bgcolor=#ffe45c99]").replace("[/b]", "[/bgcolor]")
	return label


## 첫 글자를 주황색으로 크게 강조한 노트 문단 (원본 노트의 머리글자 느낌).
func _note(text: String, size_px: int = 19) -> RichTextLabel:
	var cut: int = 0
	while cut < text.length() and text[cut] == "[":
		cut = text.find("]", cut) + 1
	if cut < text.length():
		text = text.substr(0, cut) + "[color=#e08a1a][font_size=%d]%s[/font_size][/color]" % [size_px + 6, text[cut]] + text.substr(cut + 1)
	return _rich(text, size_px)


func _heading(text: String, color: Color = ACCENT) -> Control:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_color_override("font_color", color)
	return label


## 노란 쪽지 팁 상자.
func _tip(text: String) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color("fff0b8"), Color("e0b23a"), 2, 12, 0, 10))
	panel.add_child(_rich("[b]꿀팁[/b]  " + text, 18))
	return panel


## 오른쪽 하늘색 카드 한 장: 위 이름표(아이콘 + 제목), 아래 설명.
func _card(title: String, body: String, icon: StringName = &"face", tone: Color = Color("5fc1e8"), number: int = 0, art_role: StringName = &"") -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(0, 0)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", _box(tone.lightened(0.55), tone, 5, 24, 4, 8, Color(0, 0, 0, 0.18)))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	frame.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	column.add_child(head)
	var disc := Panel.new()
	disc.custom_minimum_size = Vector2(46, 46)
	disc.add_theme_stylebox_override("panel", _box(Color.WHITE, tone, 3, 23))
	head.add_child(disc)
	if number > 0:
		var digit := Label.new()
		digit.text = str(number)
		digit.add_theme_font_size_override("font_size", 24)
		digit.add_theme_color_override("font_color", tone.darkened(0.3))
		digit.set_anchors_preset(Control.PRESET_FULL_RECT)
		digit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		digit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		disc.add_child(digit)
	elif ART.has(art_role):
		var image := _art(art_role, Vector2(36, 36))
		image.position = Vector2(5, 5)
		disc.add_child(image)
	else:
		var glyph := HubKit.Icon.new(icon, tone.darkened(0.35), Color("ffe48a"))
		glyph.position = Vector2(7, 7)
		glyph.size = Vector2(32, 32)
		disc.add_child(glyph)
	var name_plate := PanelContainer.new()
	name_plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_plate.add_theme_stylebox_override("panel", _box(Color.WHITE, Color(tone, 0.0), 0, 16, 0, 5))
	head.add_child(name_plate)
	var name_label := Label.new()
	name_label.text = title
	name_label.add_theme_font_size_override("font_size", 19)
	name_label.add_theme_color_override("font_color", Color("3a5a6a"))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_plate.add_child(name_label)
	var body_panel := PanelContainer.new()
	body_panel.add_theme_stylebox_override("panel", _box(Color("fbfdff"), Color(tone, 0.0), 0, 14, 0, 8))
	column.add_child(body_panel)
	body_panel.add_child(_rich(body, 17, Color("3a4a5a")))
	(body_panel.get_child(0) as Control).custom_minimum_size = Vector2(190, 0)
	return frame


## 카드를 두 칸씩 늘어놓는 격자.
func _grid(cards: Array) -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for card: Variant in cards:
		grid.add_child(card as Control)
	return grid


func _chapter(index: int) -> Dictionary:
	match index:
		0: return _ch_start()
		1: return _ch_turn()
		2: return _ch_board()
		3: return _ch_capture()
		4: return _ch_tools()
		5: return _ch_pawns()
		6: return _ch_cards()
	return _ch_laws()


# ---------------------------------------------------------------------------
# 내용 (장 8개): 왼쪽 노트 + 오른쪽 카드
# ---------------------------------------------------------------------------

func _ch_start() -> Dictionary:
	return {
		"title": "시작하기",
		"left": [
			_note("주사위만 굴리는 게임이 아니에요. [b]윷, 룰렛, 화투, 마작[/b]까지 굴려 가며 둘에서 넷이 한 바퀴를 도는 [color=#c2457a]억지 레이스[/color]예요!"),
			_heading("이기는 법"),
			_rich("내 말 [b]4개를 전부[/b] 결승선(0번 칸)에 먼저 넣으면 승리예요. 한 개라도 남으면 계속 달려야 해요."),
			_heading("준비물"),
			_rich("· 내 말 4개 (처음엔 모두 출발선에 서 있어요)\n· 생떼 카드 손패 (최대 7장, 빵집이나 증강으로 얻어요)\n· 가운데 법전 4칸 (모두에게 적용되는 규칙 카드가 걸려요)"),
			_tip("처음이라면 [b]놀이터[/b]에서 컴퓨터와 먼저 한 판 해 보세요. 몇 판이면 금방 익숙해져요."),
		],
		"right": [
			_card("말마다 능력이 달라요", "체스 폰은 퀸으로 승급하고, 장기 포는 말을 넘어 달려요. 말마다 한 판에 한 번 쓰는 필살기도 있어요.", &"crown", Color("f08aa8"), 0, &"pawn_ability"),
			_card("굴리는 도구가 바뀌어요", "증강으로 주사위를 윷, 룰렛, 홀덤, 슬롯… 으로 바꿔요. 도구마다 규칙이 달라요.", &"dice", Color("5fc1e8"), 0, &"tool_swap"),
			_card("카드와 법전으로 판을 뒤집어요", "함정을 깔고, 상대 말을 출발선으로 날리고, 가운데 법전으로 모두의 규칙을 바꿔요.", &"book", Color("f0c14e"), 0, &"card_law"),
			_card("눈금은 항상 공정해요", "파워 게이지는 연출일 뿐이에요. 세게 눌러도 큰 숫자가 더 잘 나오진 않아요.", &"gear", Color("86d94f"), 0, &"fair_roll"),
		],
	}


func _ch_turn() -> Dictionary:
	return {
		"title": "한 턴은 이렇게",
		"left": [
			_note("한 턴은 [b]카드, 굴리기, 말 고르기, 정산[/b] 네 단계예요. 오른쪽 카드를 순서대로 읽어 보세요."),
			_heading("알아 두면 편해요", GREEN),
			_rich("· [b]재굴림[/b]: 윷말은 상대를 잡거나 4·5가 나오면 한 번 더 굴려요.\n· [b]후퇴는 없어요[/b]: 말은 절대 뒤로 가지 않아요. 대신 공격과 함정은 상대 말을 [b]출발선으로 날려 버려요[/b]. 날아간 말은 [b]🔥 복수 부스터[/b]로 다시 나올 때 +4칸! 길 위의 [b]⚡ 부스터 발판[/b](" + "·".join(BoardSpec.dash_tiles.map(func(tile: int) -> String: return str(tile))) + "번)에 멈추면 +3칸, 다른 말을 밟고 지나가면 [b]점프 부스트[/b] +1칸(최대 +3)!
· [b]증강[/b]: 1, 4, 7라운드처럼 [b]3라운드마다[/b] 모두가 3장 중 하나를 골라요.\n· [b]제한 시간[/b]: 온라인에서는 단계마다 시간이 있고, 지나면 알아서 진행돼요.\n· [b]컴퓨터 차례[/b]: 느리다 싶으면 설정에서 연출 속도를 바꿔 보세요."),
			_tip("카드는 [b]굴리기 전에만[/b] 낼 수 있어요. 눈금을 보고 고민하고 싶다면 이번 턴 카드는 아껴 두세요."),
		],
		"right": [
			_card("카드 한 장 (안 써도 돼요)", "굴리기 전에, 카드를 [b]보드판 위로 끌어다 놓으면[/b] 발동해요. 한 턴에 한 장까지예요.", &"book", Color("f0c14e"), 1),
			_card("굴리기", "[b]굴리기[/b] 버튼을 꾹 눌러 파워를 모으고 손을 떼요. (R이나 스페이스 키도 돼요)", &"dice", Color("86d94f"), 2),
			_card("말 고르기", "나온 눈금만큼 움직일 말을 골라요. 아래 말 카드나 보드 위의 말을 누르면 돼요.", &"face", Color("5fc1e8"), 3),
			_card("정산", "도착한 칸의 효과가 터져요. 피해를 입었다면 [b]바이츠 더 더스트[/b] 카드로 이번 턴을 되돌릴 수 있어요.", &"hourglass", Color("f08aa8"), 4),
		],
	}


func _ch_board() -> Dictionary:
	var board := MiniBoard.new()
	board.custom_minimum_size = Vector2(440, 440)
	board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return {
		"title": "보드 읽기",
		"left": [
			_note("보드는 [b]%d칸짜리 사각 한 바퀴[/b]예요. 우하단 0번에서 출발해 반시계로 돌고, 한 바퀴를 다 돌면 다시 0번이 결승선이에요." % BoardSpec.tile_count),
			_heading("눈여겨볼 칸"),
			_rich("[color=#2f8f4e][b]점프 코너 %s[/b][/color]  딱 멈추면 앞으로 폴짝!\n[color=#c98a14][b]%d번 반환점[/b][/color]  여기를 지나면 체스 폰이 퀸으로, 쇼기 말이 승급해요.\n[color=#d9822b][b]빵집 %s번[/b][/color]  멈추면 생떼 카드 한 장!\n[color=#8e4aa8][b]옷장 %s번[/b][/color]  딱 멈추면 순간이동!\n[color=#2fb59a][b]⚡ 부스터 발판 %s번[/b][/color]  딱 멈추면 +3칸 더 날아가요!" % [_join_tiles(BoardSpec.jump_corner_targets.keys()), BoardSpec.halfway_tile, _join_tiles(BoardSpec.bakery_tiles), _join_tiles(BoardSpec.portal_tiles), _join_tiles(BoardSpec.dash_tiles)]),
			_tip("점프와 옷장은 [b]딱 멈출 때만[/b] 작동해요. 그냥 지나가면 아무 일도 없어요. 눈금을 잘 맞춰 보세요."),
		],
		"right": [
			board,
			_rich("가운데는 비어 있어요. 굴리기 버튼과 주사위 연출이 이 빈 무대에서 펼쳐져요.", 16),
		],
	}


func _ch_capture() -> Dictionary:
	return {
		"title": "잡기 · 업기 · 완주",
		"left": [
			_note("적 말이 서 있는 칸에 [b]멈추면 그 말은 출발선으로[/b] 돌아가요. [b]출발선(0번)은 안전[/b]해서 잡을 수 없고, 내 말끼리는 잡지 않아요."),
			_heading("업기 (윷말만)"),
			_rich("윷말끼리 같은 칸에서 만나면 [b]하나로 합쳐[/b] 한꺼번에 움직여요. 든든하지만 잡히면 [color=#d6336c]같이 잡혀요[/color]! 합칠지 말지는 고를 수 있어요."),
			_heading("완주"),
			_rich("출발한 말이 0번에 닿으면 완주예요. 눈금이 남아도 괜찮아요. (법전 [b]결승선 문턱[/b]이 걸려 있으면 눈금이 정확해야 하고, 남으면 결승선 바로 앞에서 멈춰요.) 말 4개가 모두 완주하면 승리!"),
			_tip("잡힌 말은 [b]출발선에서 처음부터[/b]예요. 완주 직전에 잡히면 억울하니 선두 말은 적 앞을 조심하세요."),
		],
		"right": [
			_card("내 말이 앞에 있는데 적이 쫓아와요!", "나중에 도착해서 [b]멈춘 쪽이 잡아요[/b]. 스쳐 지나가기만 하면 안 잡혀요.", &"sword", Color("f08aa8"), 0, &"capture"),
			_card("함정은 어떻게 보여요?", "컴퓨터 대전에서는 상대가 깐 함정이 [b]뒷면[/b]으로만 보여요. 밟아 보기 전엔 몰라요. 내 함정은 내게 보여요.", &"key", Color("b197fc"), 0, &"hidden_trap"),
			_card("적이 막고 있는데 지나갈 수 있어요?", "네! 멈추지만 않으면 지나가요. (장기 포는 말을 넘으면 보너스를 받아요.)", &"play", Color("5fc1e8"), 0, &"pass"),
			_card("무인도에 갇혔어요!", "[b]짝수 눈금[/b]이 나오면 탈출해요. 홀수면 제자리예요.", &"hourglass", Color("f0c14e"), 0, &"island"),
		],
	}


func _ch_tools() -> Dictionary:
	var tools: Array = [
		["주사위", "1~6칸, 공정한 기본 도구", &"dice", Color("5fc1e8")],
		["윷", "도 1 · 개 2 · 걸 3 · 윷 4 · 모 5, 특도는 2칸 + 한 번 더", &"play", Color("86d94f")],
		["인생게임 룰렛", "원판을 돌려 1~10칸. 7이 나오면 7칸에 한 번 더!", &"gear", Color("f0c14e")],
		["홀덤", "카드 족보에 따라 1~15칸 (플러시 이상은 15칸)", &"book", Color("f08aa8")],
		["친치로", "4~6칸의 고눈금! 대신 [color=#d6336c]삐끗하면 0칸[/color]", &"dice", Color("b197fc")],
		["777 슬롯", "릴 3개. 꽝 1칸 · 두 개 4칸 · 세 개 8칸 · 777은 20칸!", &"crown", Color("f0c14e")],
		["러시안 룰렛", "당길수록 칸이 쌓이지만 폭죽 깃발이 나오면 [color=#d6336c]전부 증발[/color]하고 턴 종료. 멈출 때는 내 선택!", &"sword", Color("f08aa8")],
		["화투", "패 2장의 족보로 0~8칸. 망통이면 0칸에 턴 종료", &"leaf", Color("86d94f")],
		["마작", "패를 뽑아 족보로 칸 수가 정해져요", &"grid", Color("5fc1e8")],
		["타로", "카드 5장 중 한 장. 장마다 효과가 달라요", &"face", Color("b197fc")],
	]
	var cards: Array = []
	for entry: Array in tools:
		cards.append(_card(entry[0], entry[1], entry[2], entry[3]))
	return {
		"title": "굴리는 도구",
		"left": [
			_note("처음엔 [b]기본 주사위[/b]로 시작해요. 증강으로 오른쪽 도구 중 하나로 바꿀 수 있고, 도구마다 규칙이 달라요. 게임 중 오른쪽 카드에 규칙표가 나와요."),
			_heading("고르는 요령", GREEN),
			_rich("· 한 방을 노린다면 [b]친치로[/b]나 [b]슬롯[/b]\n· 안정적으로 가고 싶다면 [b]주사위[/b]나 [b]윷[/b]\n· 짜릿함을 원한다면 [b]러시안 룰렛[/b]"),
			_tip("러시안 룰렛은 [b]멈추기[/b] 버튼이 생명이에요. 욕심내다 한 방에 날아가지 마세요."),
		],
		"right": [_grid(cards)],
	}


func _ch_pawns() -> Dictionary:
	return {
		"title": "말과 필살기",
		"left": [
			_note("증강으로 기본 말을 여섯 계열 중 하나로 [b]진화[/b]시켜요. 보드 위 말에는 한 글자 라벨이 붙고, 마우스를 올리면 능력이 나와요."),
			_heading("필살기", ACCENT),
			_rich("말마다 [b]한 판에 한 번[/b] 쓰는 필살기가 있어요. 룩의 [b]캐슬링[/b], 차의 [b]돌진[/b], 비행기의 [b]직항 워프[/b], 흑돌의 [b]알까기[/b], 보병의 [b]모치고마 낙하[/b]예요."),
			_tip("필살기는 내 프로필 카드에서 눌러요. 굴리기 전에만 쓸 수 있고, 잡혀서 출발선으로 가도 되살아나지 않아요."),
		],
		"right": [_grid([
			_card("윷말", "잡거나 4·5가 나오면 한 번 더. 만나면 업기", &"play", Color("f08aa8")),
			_card("체스", "폰은 반환점 이상에서 퀸으로 승급 · 나이트는 함정과 말을 뛰어넘기 · 비숍은 코너를 스치면 +2칸 · 룩은 [b]필살기 캐슬링[/b](아군과 위치 교환)", &"crown", Color("5fc1e8")),
			_card("장기", "포는 길에 말이 있으면 +3칸 · 차는 [b]필살기 돌진[/b](선두 적을 잡으러 직진) · 마는 앞 칸이 비면 +2칸 · 상은 +3칸", &"sword", Color("f0c14e")),
			_card("모노폴리", "미니카는 도착 칸에 호텔 · 비행기는 옷장에서 더 멀리, [b]필살기 직항 워프[/b] · 증기선은 첫 적 함정을 부숴요 · 강아지는 빵집을 스치기만 해도 카드!", &"key", Color("86d94f")),
			_card("바둑", "흑돌은 [b]필살기 알까기[/b](튕겨서 직선의 적을 탈락) · 백돌은 잡히지 않고 같은 칸 아군도 지켜요(눈금 -1)", &"dice", Color("b197fc")),
			_card("쇼기", "반환점 이상을 지나면 [b]승급[/b](이동 +1칸) · 보병은 [b]필살기 모치고마 낙하[/b](대기 말을 바로 옆에 투입) · 비차 +2칸 · 각행은 코너 +2칸 · 계마는 첫 2칸 함정 무시", &"grid", Color("f08aa8")),
		])],
	}


func _card_entry(card_id: StringName, tone: Color) -> Control:
	var card: BaseCard = CardRegistry.get_card(card_id)
	var summary: String = MainBoard.card_summary(card_id).replace("\n", " ")
	var icon: StringName = &"book" if card_id == &"ACT_09" else (&"gear" if card_id.begins_with("ACT") else (&"key" if card_id.begins_with("TRP") else &"face"))
	return _card(card.display_name, summary, icon, tone)


func _ch_cards() -> Dictionary:
	var cards: Array = []
	for card_id: StringName in [&"ACT_01", &"ACT_02", &"ACT_03", &"ACT_04", &"ACT_05", &"ACT_06", &"ACT_07", &"ACT_08", &"ACT_09"]:
		cards.append(_card_entry(card_id, Color("f0c14e")))
	for card_id: StringName in [&"TRP_01", &"TRP_02", &"TRP_03", &"TRP_04", &"TRP_05"]:
		cards.append(_card_entry(card_id, Color("b197fc")))
	for card_id: StringName in [&"SUM_01", &"SUM_02"]:
		cards.append(_card_entry(card_id, Color("f08aa8")))
	return {
		"title": "생떼 카드",
		"left": [
			_note("빵집이나 증강에서 얻는 카드예요. 손패는 [b]최대 7장[/b]이고, 카드를 [b]보드판으로 끌어다 놓아[/b] 써요. 한 턴에 한 장, 굴리기 전에만 낼 수 있어요."),
			_heading("종류", GREEN),
			_rich("[color=#c98a14][b]노랑[/b][/color]  바로 터지는 카드 (9종)\n[color=#7a5cd6][b]보라[/b][/color]  칸을 골라 까는 함정 (5종, 상대에게는 뒷면)\n[color=#c2457a][b]분홍[/b][/color]  소환 카드 (2종, 중립 말이 움직여요)"),
			_tip("가위바위보 결투 카드는 [b]상대 프로필이나 말 위에[/b] 놓으면 그 상대와 바로 붙어요. 이기면 내 말이 +3칸 전진하고, 진 사람의 말 하나는 출발선으로 날아가요!"),
		],
		"right": [_grid(cards)],
	}


func _ch_laws() -> Dictionary:
	var cards: Array = []
	for index: int in 8:
		var law: LawResource = LawRegistry.create("LAW_%02d" % (index + 1))
		if law != null:
			cards.append(_card(law.law_name, law.description, &"book", Color("5fc1e8")))
	return {
		"title": "증강과 법전",
		"left": [
			_note("1, 4, 7라운드처럼 [b]3라운드마다[/b] 모두가 3장 중 하나를 골라요. 마음에 안 들면 카드마다 [b]한 번 다시 뽑기[/b]가 있어요."),
			_rich("· [b]기물 지급[/b]  말 하나를 새 기물로 진화\n· [b]도구 교체[/b]  굴리는 도구 바꾸기\n· [b]교칙 제정[/b]  가운데 법전에 새 규칙 걸기\n· [b]카드 패키지[/b]  생떼 카드 여러 장"),
			_heading("가운데 법전 (4칸)"),
			_rich("새 교칙이 들어오면 [b]가장 오래된 교칙이 밀려나요[/b]. 모두에게 적용되니, 나에게 유리한 교칙을 밀어내기 전에 써먹어 보세요. [b]이의 있음![/b] 카드로 하나를 지울 수도 있어요."),
			_tip("[b]아우토반 무제한 과속[/b]이 걸려 있으면 눈금 5 이상에 [b]+3칸[/b]이 붙어 너무 빨라져요. 코너 점프대나 빵집을 그냥 지나칠 수 있으니 [b]멈출 자리[/b]를 잘 보고 고르세요."),
		],
		"right": [_grid(cards)],
	}


# ---------------------------------------------------------------------------
# 그림 부품: 줄 노트 종이, 월계수, 금 메달, 아래 리본
# ---------------------------------------------------------------------------

## 크림색 종이에 옅은 가로줄이 그어진 노트 쪽.
class LinedPaper extends Control:
	func _draw() -> void:
		var base := StyleBoxFlat.new()
		base.bg_color = Color("fbf4df")
		base.set_corner_radius_all(12)
		draw_style_box(base, Rect2(Vector2.ZERO, size))
		var y: float = 78.0
		while y < size.y - 16.0:
			draw_line(Vector2(18, y), Vector2(size.x - 18, y), Color(0.72, 0.6, 0.4, 0.22), 2.0)
			y += 30.0
		# 종이 모서리의 접힌 느낌
		draw_colored_polygon(PackedVector2Array([Vector2(size.x - 40, size.y), Vector2(size.x, size.y - 40), Vector2(size.x, size.y)]), Color("e8dcb8"))


## 타일 번호 목록을 `4·10·14` 꼴로 이어 붙인다.
static func _join_tiles(tiles: Array) -> String:
	var parts: Array[String] = []
	for tile: Variant in tiles:
		parts.append(str(int(tile)))
	return "·".join(parts)


## 책 아래쪽에 걸친 주황 리본 (쪽 번호가 올라간다).
class Ribbon extends Control:
	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var body := PackedVector2Array([Vector2(24, 8), Vector2(w - 24, 8), Vector2(w - 24, h - 14), Vector2(24, h - 14)])
		draw_colored_polygon(PackedVector2Array([Vector2(0, 14), Vector2(24, 14), Vector2(24, h - 6), Vector2(0, h - 6), Vector2(12, h / 2.0 + 4)]), Color("c4612a"))
		draw_colored_polygon(PackedVector2Array([Vector2(w, 14), Vector2(w - 24, 14), Vector2(w - 24, h - 6), Vector2(w, h - 6), Vector2(w - 12, h / 2.0 + 4)]), Color("c4612a"))
		draw_colored_polygon(body, Color("f08a3c"))
		draw_line(Vector2(24, 12), Vector2(w - 24, 12), Color("ffc98a"), 3.0)
		draw_line(Vector2(24, h - 18), Vector2(w - 24, h - 18), Color("c4612a"), 3.0)


# ---------------------------------------------------------------------------
# 미니 보드 그림 (보드 읽기 쪽)
# ---------------------------------------------------------------------------

## 사각 트랙(BoardSpec)을 작게 그리고 점프·옷장 이동을 화살표로 보여 준다.
class MiniBoard extends Control:
	const CELL: float = 34.0
	const CORNER: float = 44.0

	static func _warp_text(targets: Dictionary) -> String:
		var parts: Array[String] = []
		for from_tile: int in targets.keys():
			parts.append("%d → %d" % [from_tile, int(targets[from_tile])])
		return ", ".join(parts)

	func _tile_pos(index: int) -> Vector2:
		var pad: float = 34.0
		var span: float = size.x - pad * 2.0
		return Vector2(pad, pad) + BoardLayout.tile_norm(index) * span

	func _draw() -> void:
		var paper := StyleBoxFlat.new()
		paper.bg_color = Color("e8f5c8")
		paper.border_color = Color("b9d48a")
		paper.set_border_width_all(3)
		paper.set_corner_radius_all(22)
		draw_style_box(paper, Rect2(Vector2.ZERO, size))
		var font: Font = get_theme_default_font()
		# 이동선 (타일 아래)
		for from_tile: int in BoardSpec.jump_corner_targets.keys():
			_arc(from_tile, int(BoardSpec.jump_corner_targets[from_tile]), Color("2f8f4e"))
		for from_tile: int in BoardSpec.portal_warp_targets.keys():
			_dashed(from_tile, int(BoardSpec.portal_warp_targets[from_tile]), Color("8e4aa8"))
		for index: int in BoardSpec.tile_count:
			var center: Vector2 = _tile_pos(index)
			var corner: bool = BoardSpec.corner_tiles.has(index)
			var side: float = CORNER if corner else CELL
			var fill: Color = Color("fffdf0")
			var edge: Color = Color("b9a56a")
			if BoardSpec.bakery_tiles.has(index):
				fill = Color("ffd98a")
				edge = Color("d9822b")
			elif BoardSpec.portal_tiles.has(index):
				fill = Color("e6d2f0")
				edge = Color("8e4aa8")
			elif index == 0:
				fill = Color("86d94f")
				edge = Color("2f8f4e")
			elif index == BoardSpec.halfway_tile:
				fill = Color("ffe48a")
				edge = Color("c98a14")
			elif corner:
				fill = Color("b6ea8c")
				edge = Color("2f8f4e")
			var box := StyleBoxFlat.new()
			box.bg_color = fill
			box.border_color = edge
			box.set_border_width_all(3)
			box.set_corner_radius_all(9 if not corner else 12)
			draw_style_box(box, Rect2(center - Vector2(side, side) / 2.0, Vector2(side, side)))
			var label: String = str(index)
			if index == 0:
				label = "출발"
			var label_size: int = 13 if not corner else 15
			var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
			draw_string(font, center + Vector2(-width / 2.0, label_size * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, Color("3a2f1f"))
		# 안쪽 범례
		var legend: Array = [[Color("86d94f"), "출발 · 결승"], [Color("b6ea8c"), "점프 코너 (%s)" % _warp_text(BoardSpec.jump_corner_targets)], [Color("ffe48a"), "반환점 (승급 기준)"], [Color("ffd98a"), "빵집 (카드 1장)"], [Color("e6d2f0"), "옷장 (%s)" % _warp_text(BoardSpec.portal_warp_targets)]]
		var origin := Vector2(92, 118)
		for index: int in legend.size():
			var spot: Vector2 = origin + Vector2(0, index * 30.0)
			var swatch := StyleBoxFlat.new()
			swatch.bg_color = legend[index][0]
			swatch.border_color = Color("8a7a45")
			swatch.set_border_width_all(2)
			swatch.set_corner_radius_all(5)
			draw_style_box(swatch, Rect2(spot, Vector2(20, 20)))
			draw_string(font, spot + Vector2(28, 16), legend[index][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("3a2f1f"))

	func _arc(from_tile: int, to_tile: int, color: Color) -> void:
		var a: Vector2 = _tile_pos(from_tile)
		var b: Vector2 = _tile_pos(to_tile)
		var mid: Vector2 = (a + b) / 2.0 + (size / 2.0 - (a + b) / 2.0).normalized() * 34.0
		var points := PackedVector2Array()
		for step: int in 17:
			var t: float = float(step) / 16.0
			points.append((1.0 - t) * (1.0 - t) * a + 2.0 * (1.0 - t) * t * mid + t * t * b)
		draw_polyline(points, color, 4.0, true)
		var tip: Vector2 = points[16]
		var dir: Vector2 = (points[16] - points[14]).normalized()
		var side: Vector2 = Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([tip + dir * 6.0, tip - dir * 8.0 + side * 7.0, tip - dir * 8.0 - side * 7.0]), color)

	func _dashed(from_tile: int, to_tile: int, color: Color) -> void:
		var a: Vector2 = _tile_pos(from_tile)
		var b: Vector2 = _tile_pos(to_tile)
		draw_dashed_line(a, b, color, 3.5, 9.0, true)
		var dir: Vector2 = (b - a).normalized()
		var side: Vector2 = Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([b - dir * 22.0 + dir * 8.0, b - dir * 30.0 + side * 7.0, b - dir * 30.0 - side * 7.0]), color)
