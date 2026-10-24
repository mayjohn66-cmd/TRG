# File: res://scenes/rulebook.gd
# Class: class_name Rulebook
# Role: 규칙 도감. 장마다 오른쪽에는 항목 제목 타일만 늘어놓고, 고른 항목은 왼쪽 노트에 그림·꼬리표·표·요점으로 크게 보여 준다.
#       도구 규칙표·기물 능력·카드·교칙 문구는 실제 데이터(TOOL_RULES·PawnCatalog·CardRegistry·VictoryLaw)에서 읽어 온다.
class_name Rulebook
extends Control

## 기록 코드를 불러왔다 (허브의 #태그·닉네임·법전 수 배지를 다시 그린다).
signal records_imported

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
## 법전 장 (도감 묶음의 법전 탭): 허브의 [법전 수집 N/8]이 바로 연다.
const LAW_SPREAD: int = 7
const TAB_NAMES: Array[String] = ["시작하기", "한 턴", "보드", "잡기", "도구", "말", "카드", "법전", "범용", "초증강"]
const TAB_ICONS: Array[StringName] = [&"face", &"hourglass", &"grid", &"sword", &"dice", &"crown", &"book", &"gear", &"key", &"star"]
const TAB_ART: Array[StringName] = [&"start", &"turn", &"board", &"capture"]
## 왼쪽 노트의 큰 그림 크기와 모서리 둥글기.
const HERO_ART: Vector2 = Vector2(132, 132)
const HERO_RADIUS: int = 24
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
## 위쪽 두 탭이 묶는 장: 규칙 기본(0~3), 도감(4~9: 도구·말·카드·법전·범용·초증강).
const GROUP_NAMES: Array[String] = ["기본 규칙", "도감"]
## 위쪽 탭(묶음)마다 첫 장의 번호: 기본 규칙 0~3, 도감 4~8.
const GROUP_STARTS: Array[int] = [0, 4]
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
var _law_badge: Button = null
var _save_notice: Label = null
var _code_field: LineEdit = null
var _page_label: Label = null
var _prev: Button = null
var _next: Button = null
var _prev_name: Label = null
var _next_name: Label = null
var _list_box: VBoxContainer = null
## 지금 장의 내용 ({"title", "entries"})과 고른 항목 번호.
var _content: Dictionary = {}
var entry: int = 0
var _tiles: Array[Control] = []
var _chapter_label: Label = null
## 카드 항목에서 왼쪽에 크게 보여 주는 카드 앞면 크기.
const CARD_FACE: Vector2 = Vector2(170, 238)
## 도감 오른쪽 그림 타일: 증강 카드 배율(두 칸씩)과 손패 카드 크기.
const AUGMENT_TILE_SCALE: float = 0.8
const CARD_TILE: Vector2 = Vector2(200, 280)
## 지금 보고 있는 그림 타일의 외곽선 색 (눈에 띄는 형광 분홍).
const SELECTED_OUTLINE: Color = Color("ff2d95")


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
	_build_save_tools()


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_RIGHT: show_spread(spread + 1)
		KEY_LEFT: show_spread(spread - 1)
		KEY_DOWN: show_entry(entry + 1)
		KEY_UP: show_entry(entry - 1)
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
	# 위쪽 탭 두 개 (책 위로 살짝 솟은 베이지 탭)
	for index: int in GROUP_NAMES.size():
		var tab := Button.new()
		tab.name = "Group%d" % index
		tab.text = GROUP_NAMES[index]
		tab.focus_mode = Control.FOCUS_NONE
		tab.add_theme_font_size_override("font_size", 20)
		tab.pressed.connect(func() -> void: show_spread(GROUP_STARTS[index]))
		_place(tab, Vector2(500 + index * 170, 66), Vector2(160, 52))
		_group_tabs.append(tab)


## 위 오른쪽: [트로피 법전 수집 N/8] + 큼직한 [내 기록 전용 링크 복사] / 아래 줄에 짧은 코드(4BGC-A51F) 입력 칸 + [입력].
## 링크를 눌러 접속하기만 하면 기록이 이어진다 (PlayerSave.apply_url_params). 코드 입력은 보조 수단.
func _build_save_tools() -> void:
	_law_badge = MetaIcon.pill("LawCollection", "", func() -> void: show_spread(LAW_SPREAD), 16)
	_place(_law_badge, Vector2(846, 18), Vector2(196, 44))
	var link: Button = LobbyTheme.small_button("내 기록 전용 링크 복사", _copy_share_link, &"teal", 17)
	link.name = "CopyShareLink"
	link.clip_text = true
	_place(link, Vector2(1050, 18), Vector2(290, 44))
	_code_field = LineEdit.new()
	_code_field.name = "ShortCodeField"
	_code_field.placeholder_text = "4BGC-A51F"
	_code_field.max_length = 40
	_code_field.add_theme_font_size_override("font_size", 16)
	_code_field.text_submitted.connect(func(text: String) -> void: apply_save_code(text))
	_place(_code_field, Vector2(846, 66), Vector2(150, 40))
	var apply: Button = LobbyTheme.small_button("입력", func() -> void: apply_save_code(_code_field.text), &"blue", 15)
	apply.name = "ApplyShortCode"
	_place(apply, Vector2(1000, 66), Vector2(64, 40))
	_save_notice = HubKit.outlined("", 14, Color.WHITE, Color("3a3250"), 4)
	_save_notice.name = "SaveNotice"
	_save_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_save_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(_save_notice, Vector2(1070, 62), Vector2(272, 48))
	_refresh_law_badge()


func _refresh_law_badge() -> void:
	if _law_badge != null:
		_law_badge.text = "법전 수집 %d/8" % PlayerSave.law_count()


## [내 기록 전용 링크 복사]: ?s=짧은코드&n=닉네임 링크를 클립보드에 넣는다 (카톡 나에게 보내기·메모에 두었다가 누르면 이어진다).
func _copy_share_link() -> void:
	MetaIcon.copy_to_clipboard(PlayerSave.share_url())
	_save_notice.text = "링크를 복사했어요! 누르기만 하면 이어져요 (%s)" % PlayerSave.short_code()


## 짧은 코드(4BGC-A51F, 닉네임#4BGC-A51F)나 예전 긴 코드를 불러온다: 성공하면 #태그·닉네임·도장이 바로 바뀐다. 성공하면 true.
func apply_save_code(code: String) -> bool:
	if code.strip_edges().is_empty():
		return false
	if not PlayerSave.import_any(code):
		_save_notice.text = "코드를 확인해 주세요 (예: 4BGC-A51F)"
		return false
	GameSession.reload_from_save()
	_save_notice.text = "기록을 불러왔어요 (#%s)" % GameSession.player_tag()
	if _code_field != null:
		_code_field.text = ""
	_refresh_law_badge()
	if _content.get("entries", []) is Array and not (_content.get("entries", []) as Array).is_empty():
		_rebuild_tiles()
	records_imported.emit()
	return true


## 왼쪽 세로 항목 줄: 현재 탭의 장 4개. 고른 항목은 흰 알약에 점선 느낌의 초록 테두리.
func _build_list() -> void:
	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 8)
	_list_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_list_box, Vector2(28, 148), Vector2(196, 520))  # 도감 묶음 6장(도구~초증강)이 들어간다
	for index: int in TAB_NAMES.size():
		var button := Button.new()
		button.name = "Tab%d" % index
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(196, 78)
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
	_chapter_label = Label.new()
	_chapter_label.name = "ChapterLabel"
	_chapter_label.add_theme_font_size_override("font_size", 15)
	_chapter_label.add_theme_color_override("font_color", Color("a08a60"))
	_chapter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_chapter_label)
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
# 장 바꾸기: 오른쪽은 항목 제목 타일, 고른 항목의 자세한 모습은 왼쪽 노트에 그림·표로 나온다
# ---------------------------------------------------------------------------

## 장을 연다. 처음에는 왼쪽에 그 장의 전체 설명(overview)이 나오고, 오른쪽 타일을 누르면 그 항목으로 바뀐다.
func show_spread(index: int, entry_index: int = -1) -> void:
	spread = clampi(index, 0, spread_count() - 1)
	_content = _chapter(spread)
	_rebuild_tiles()
	show_entry(entry_index)
	_right_scroll.scroll_vertical = 0
	var group: int = group_of(spread)
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
		var visible_here: bool = group_of(index3) == group
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


## 장 번호가 속한 위쪽 탭(묶음).
static func group_of(index: int) -> int:
	var group: int = 0
	for start_index: int in GROUP_STARTS.size():
		if index >= GROUP_STARTS[start_index]:
			group = start_index
	return group


## 지금 장의 항목 수.
func entry_count() -> int:
	return (_content.get("entries", []) as Array).size()


## 오른쪽 타일 중 하나를 골라 왼쪽 노트에 자세히 보여 준다. -1이면 장의 전체 설명.
func show_entry(index: int) -> void:
	var entries: Array = _content.get("entries", [])
	entry = clampi(index, -1, entries.size() - 1)
	for child: Node in _left_holder.get_children():
		_left_holder.remove_child(child)
		child.queue_free()
	var data: Dictionary = _content["overview"] if entry == -1 else entries[entry]
	_notebook_title.text = str(data["title"])
	_chapter_label.text = "%s  ·  전체 설명" % _content["title"] if entry == -1 else "%s  ·  %d / %d" % [_content["title"], entry + 1, entries.size()]
	for node: Control in _detail(data):
		_left_holder.add_child(node)
	for tile_index: int in _tiles.size():
		_paint_tile(_tiles[tile_index], tile_index == entry)


func _rebuild_tiles() -> void:
	for child: Node in _right_holder.get_children():
		_right_holder.remove_child(child)
		child.queue_free()
	_tiles.clear()
	var wide: bool = bool(_content.get("wide", false))
	var grid := GridContainer.new()
	grid.columns = 2 if wide else 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var entries: Array = _content.get("entries", [])
	for index: int in entries.size():
		var data: Dictionary = entries[index]
		var tile: Control = _picture_tile(data, show_entry.bind(index)) if wide else _tile(data)
		if not wide:
			(tile as Button).pressed.connect(show_entry.bind(index))
		grid.add_child(tile)
		_tiles.append(tile)
	_right_holder.add_child(grid)


## 오른쪽 제목 타일: 동그란 그림 + 이름만. 고르면 흰 바탕에 굵은 테두리.
func _tile(data: Dictionary) -> Button:
	var tone: Color = data.get("tone", Color("5fc1e8"))
	var button := Button.new()
	button.name = "Entry_" + str(data["title"])
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(142, 112)
	button.set_meta("tone", tone)
	button.tooltip_text = str(data.get("summary", "")).replace("[b]", "").replace("[/b]", "")
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 6
	column.offset_right = -6
	column.offset_top = 8
	column.offset_bottom = -6
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)
	var disc := Panel.new()
	disc.custom_minimum_size = Vector2(54, 54)
	disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.add_theme_stylebox_override("panel", _box(Color.WHITE, tone, 3, 27))
	column.add_child(disc)
	var picture: Control = _picture(data, Vector2(42, 42))
	picture.position = Vector2(6, 6)
	disc.add_child(picture)
	var name_label := Label.new()
	name_label.text = str(data["title"])
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color("3a4a5a"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.max_lines_visible = 2
	name_label.custom_minimum_size = Vector2(128, 0)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_label)
	return button


## 도감 그림 타일: 증강 선택 화면의 증강 카드(또는 손패 카드 앞면)를 줄여 두 칸씩 늘어놓는다.
func _picture_tile(data: Dictionary, on_pick: Callable) -> Control:
	var holder := Control.new()
	holder.name = "Entry_" + str(data["title"])
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	var card_size: Vector2
	var card_radius: int = 12
	if data.has("augment"):
		var definition: AugmentDef = AugmentRegistry.get_def(data["augment"])
		card_size = MainBoard.AUGMENT_CARD_SIZE * AUGMENT_TILE_SCALE
		card_radius = int(round(16.0 * AUGMENT_TILE_SCALE))  # 증강 카드 모서리(16)를 줄인 배율 그대로
		var card: Button = MainBoard.make_augment_card(MainBoard.augment_card_info(definition, null, 1), on_pick, AUGMENT_TILE_SCALE, true)
		card.position = -MainBoard.AUGMENT_CARD_SIZE * (1.0 - AUGMENT_TILE_SCALE) / 2.0  # 가운데 기준으로 줄였으니 왼쪽 위를 맞춘다
		holder.add_child(card)
	else:
		card_size = CARD_TILE
		var face := Button.new()
		face.focus_mode = Control.FOCUS_NONE
		face.size = CARD_TILE
		var card_data: BaseCard = CardRegistry.get_card(data["card"])
		for state: String in ["normal", "hover", "pressed", "focus"]:
			face.add_theme_stylebox_override(state, CardSkin.frame(card_data.category, false, 12))  # 도감은 마우스를 올려도 그대로
		var body: Control = CardSkin.body(card_data, CARD_TILE, MainBoard.card_summary(data["card"]), MainBoard.CARD_CATEGORY_NAMES[card_data.category], true)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_child(body)
		face.pressed.connect(on_pick)
		holder.add_child(face)
	holder.custom_minimum_size = card_size
	# 특수 승리 법전으로 졸업해 본 교칙: [달성 완료 ★] 도장 (영구 기록)
	if data.has("law_id") and PlayerSave.has_law(str(data["law_id"])):
		var stamp: PanelContainer = MetaIcon.stamp("달성 완료 ★", 18)
		stamp.position = Vector2(card_size.x * 0.5 - 64.0, card_size.y * 0.30)
		stamp.z_index = 7
		holder.add_child(stamp)
	# 지금 보고 있는 항목: 꼬리표 대신 눈에 띄는 색의 굵은 외곽선
	var marker := Panel.new()
	marker.name = "SelectedOutline"
	# 외곽선 모서리는 카드 모서리와 같은 둥글기로, 1px 바깥까지 덮어 카드 테두리가 모서리 틈으로 비치지 않게 한다
	marker.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0), SELECTED_OUTLINE, 6, card_radius + 1))
	marker.position = -Vector2.ONE  # 목록 스크롤에 잘리지 않게 거의 카드 안쪽에 그린다
	marker.size = card_size + Vector2.ONE * 2.0
	marker.z_index = 6
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.visible = false
	holder.add_child(marker)
	holder.set_meta("marker", marker)
	return holder


func _paint_tile(tile: Control, selected: bool) -> void:
	if tile.has_meta("marker"):
		(tile.get_meta("marker") as Control).visible = selected  # 그림 타일: 지금 보는 항목의 외곽선
		return
	var button: Button = tile as Button
	var tone: Color = button.get_meta("tone")
	var normal: StyleBoxFlat = _box(Color.WHITE if selected else tone.lightened(0.62), tone.darkened(0.15) if selected else tone, 5 if selected else 3, 20, 4 if selected else 2, 0, Color(0, 0, 0, 0.18))
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color.WHITE
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## 일러스트를 둥근 네모로 잘라 담는다: 둥근 판(clip_children)이 그림의 모서리를 가리고, 같은 둥글기의 외곽선을 그림 가장자리에 딱 맞춰 덧그린다.
static func _rounded_art(picture: Control, extent: Vector2, radius: int, tone: Color) -> Control:
	var holder := Control.new()
	holder.name = "RoundedArt"
	holder.custom_minimum_size = extent
	holder.size = extent
	holder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow := Panel.new()  # 그림 뒤의 옅은 그림자 (둥근 판과 같은 모양)
	shadow.name = "Shadow"
	shadow.add_theme_stylebox_override("panel", _box(tone.lightened(0.7), Color(0, 0, 0, 0), 0, radius, 4, 0, Color(0, 0, 0, 0.18)))
	shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(shadow)
	var mask := Panel.new()
	mask.name = "Mask"
	var mask_style: StyleBoxFlat = _box(Color.WHITE, Color(0, 0, 0, 0), 0, radius)
	mask_style.anti_aliasing = true
	mask.add_theme_stylebox_override("panel", mask_style)
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY  # 둥근 판 모양대로만 그림이 보인다
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(mask)
	var inset: float = 0.0
	var art: TextureRect = picture as TextureRect
	if art != null and art.texture != null:
		var ratio: float = float(art.texture.get_width()) / maxf(float(art.texture.get_height()), 1.0)
		if absf(ratio - 1.0) < 0.12 and not _is_cutout(art.texture):
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED  # 배경까지 그린 정사각 일러스트는 네모 칸을 빈틈없이 채운다
		else:
			inset = 10.0  # 배경이 투명한 오려 낸 그림은 외곽선에 닿지 않게 살짝 안쪽 가운데
	picture.custom_minimum_size = Vector2.ZERO
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)  # 둥근 판에 맞춰 늘이고 inset만큼 안쪽으로
	picture.offset_left = inset
	picture.offset_top = inset
	picture.offset_right = -inset
	picture.offset_bottom = -inset
	mask.add_child(picture)
	var outline := Panel.new()
	outline.name = "Outline"
	outline.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0), tone, 4, radius))
	outline.set_anchors_preset(Control.PRESET_FULL_RECT)
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(outline)
	return holder


## 모서리 픽셀이 투명하면 배경 없이 오려 낸 그림으로 본다.
static func _is_cutout(texture: Texture2D) -> bool:
	if texture is AtlasTexture:
		return true  # 도감 그림(ART)은 투명 여백을 잘라 낸 오려 낸 그림
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return false
	if image.is_compressed():
		image = image.duplicate()
		if image.decompress() != OK:
			return false
	return image.get_pixel(1, 1).a < 0.5 or image.get_pixel(image.get_width() - 2, image.get_height() - 2).a < 0.5


## 항목의 그림: 실제 일러스트(texture) > 도감 그림(art) > 번호 > 아이콘 순.
func _picture(data: Dictionary, extent: Vector2) -> Control:
	var tone: Color = data.get("tone", Color("5fc1e8"))
	var texture: Texture2D = data.get("texture", null)
	if texture != null:
		var image := TextureRect.new()
		image.texture = texture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		image.custom_minimum_size = extent
		image.size = extent
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return image
	if ART.has(data.get("art", &"")):
		return _art(data["art"], extent)
	if int(data.get("number", 0)) > 0:
		var digit := Label.new()
		digit.text = str(data["number"])
		digit.add_theme_font_size_override("font_size", int(extent.y * 0.62))
		digit.add_theme_color_override("font_color", tone.darkened(0.3))
		digit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		digit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		digit.custom_minimum_size = extent
		digit.size = extent
		digit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return digit
	var glyph := HubKit.Icon.new(data.get("icon", &"face"), tone.darkened(0.35), Color("ffe48a"))
	glyph.custom_minimum_size = extent
	glyph.size = extent
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return glyph


# ---------------------------------------------------------------------------
# 왼쪽 노트의 자세한 모습: 큰 그림 + 한 줄 요약 + 표 + 요점 + 꿀팁
# ---------------------------------------------------------------------------

func _detail(data: Dictionary) -> Array[Control]:
	var nodes: Array[Control] = []
	var tone: Color = data.get("tone", Color("5fc1e8"))
	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation", 14)
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if data.has("card"):
		hero.add_child(_card_face(data["card"]))
	elif data.get("texture", null) != null or ART.has(data.get("art", &"")):
		hero.add_child(_rounded_art(_picture(data, HERO_ART), HERO_ART, HERO_RADIUS, tone))
	else:
		var frame := PanelContainer.new()
		frame.custom_minimum_size = Vector2(132, 132)
		frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_theme_stylebox_override("panel", _box(tone.lightened(0.7), tone, 4, 24, 3, 8, Color(0, 0, 0, 0.15)))
		frame.add_child(_picture(data, Vector2(112, 112)))
		hero.add_child(frame)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(side)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for chip_text: Variant in data.get("chips", []):
		chips.add_child(_chip(str(chip_text), tone))
	if chips.get_child_count() > 0:
		side.add_child(chips)
	var summary: RichTextLabel = _rich(str(data.get("summary", "")), 20, Color("3a2f1f"))
	summary.custom_minimum_size = Vector2(0, 0)
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_child(summary)
	nodes.append(hero)
	if data.has("extra"):
		nodes.append((data["extra"] as Callable).call() as Control)  # 볼 때마다 새로 만든다 (지운 노드를 다시 붙이지 않게)
	var rows: Array = data.get("rows", [])
	if not rows.is_empty():
		nodes.append(_table(rows, tone))
	var points: Array = data.get("points", [])
	if not points.is_empty():
		nodes.append(_points(points, tone))
	if data.has("note"):
		nodes.append(_rich("[color=#8a7a58]%s[/color]" % str(data["note"]), 15))
	if data.has("tip"):
		nodes.append(_tip(str(data["tip"])))
	return nodes


## 둥근 알약 모양의 작은 꼬리표 (종류·시점 등).
func _chip(text: String, tone: Color) -> Control:
	var chip := Label.new()
	chip.text = text
	chip.add_theme_font_size_override("font_size", 15)
	chip.add_theme_color_override("font_color", Color.WHITE)
	chip.add_theme_stylebox_override("normal", _box(tone.darkened(0.12), tone.darkened(0.3), 0, 12, 0, 0))
	(chip.get_theme_stylebox("normal") as StyleBoxFlat).content_margin_left = 10
	(chip.get_theme_stylebox("normal") as StyleBoxFlat).content_margin_right = 10
	(chip.get_theme_stylebox("normal") as StyleBoxFlat).content_margin_top = 2
	(chip.get_theme_stylebox("normal") as StyleBoxFlat).content_margin_bottom = 2
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return chip


## 두 칸 표: 왼쪽은 색 꼬리표(조건·이름), 오른쪽은 결과. 행 하나는 [왼쪽, 오른쪽] 또는 [그림, 왼쪽, 오른쪽].
func _table(rows: Array, tone: Color) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _box(Color("fffdf6"), tone.lightened(0.2), 2, 16, 0, 10))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	for row_index: int in rows.size():
		var row: Array = rows[row_index]
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cells: Array = row
		if row.size() == 3:
			var icon_holder := Control.new()
			icon_holder.custom_minimum_size = Vector2(44, 44)
			icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var picture: Control = _picture({"texture": row[0]} if row[0] is Texture2D else {"icon": &"face", "tone": tone}, Vector2(44, 44))
			icon_holder.add_child(picture)
			line.add_child(icon_holder)
			cells = row.slice(1)
		if cells.size() == 1:
			# 머리말 없는 한 칸 행 (기물 패시브 등): 오른쪽 칸만 폭 전체로
			var whole: RichTextLabel = _rich(str(cells[0]), 16, Color("3a2f1f"))
			whole.custom_minimum_size = Vector2(0, 0)
			whole.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(whole)
			column.add_child(line)
			if row_index < rows.size() - 1:
				column.add_child(_table_rule(tone))
			continue
		var key := Label.new()
		key.text = str(cells[0])
		key.add_theme_font_size_override("font_size", 16)
		key.add_theme_color_override("font_color", tone.darkened(0.45))
		key.custom_minimum_size = Vector2(150, 0)
		key.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		key.add_theme_stylebox_override("normal", _box(tone.lightened(0.62), Color(0, 0, 0, 0), 0, 10, 0, 6))
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(key)
		var value: RichTextLabel = _rich(str(cells[1]), 16, Color("3a2f1f"))
		value.custom_minimum_size = Vector2(0, 0)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(value)
		column.add_child(line)
		if row_index < rows.size() - 1:
			column.add_child(_table_rule(tone))
	return panel


func _table_rule(tone: Color) -> ColorRect:
	var rule := ColorRect.new()
	rule.color = Color(tone, 0.25)
	rule.custom_minimum_size = Vector2(0, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


## 요점 목록: 줄마다 색 점 + 짧은 문장.
func _points(points: Array, tone: Color) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for point: Variant in points:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(14, 14)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.add_theme_stylebox_override("panel", _box(tone, tone.darkened(0.25), 2, 7))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(dot)
		var text: RichTextLabel = _rich(str(point), 17)
		text.custom_minimum_size = Vector2(0, 0)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(text)
		column.add_child(line)
	return column


## 카드 항목의 큰 그림: 게임 손패와 같은 카드 앞면.
func _card_face(card_id: StringName) -> Control:
	var card: BaseCard = CardRegistry.get_card(card_id)
	var face := PanelContainer.new()
	face.custom_minimum_size = CARD_FACE
	face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_theme_stylebox_override("panel", CardSkin.frame(card.category, false, 14))
	face.add_child(CardSkin.body(card, CARD_FACE, MainBoard.card_summary(card_id), MainBoard.CARD_CATEGORY_NAMES[card.category], true))
	return face


# ---------------------------------------------------------------------------
# 글 부품
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


## 노란 쪽지 팁 상자.
func _tip(text: String) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color("fff0b8"), Color("e0b23a"), 2, 12, 0, 10))
	panel.add_child(_rich("[b]꿀팁[/b]  " + text, 17))
	return panel


## 장 내용. 항목 목록의 첫 항목은 그 장의 전체 설명(overview)으로 빼서 장을 열 때 왼쪽에 보여 주고, 오른쪽 타일에는 넣지 않는다.
func _chapter(index: int) -> Dictionary:
	var content: Dictionary
	match index:
		0: content = _ch_start()
		1: content = _ch_turn()
		2: content = _ch_board()
		3: content = _ch_capture()
		4: content = _ch_tools()
		5: content = _ch_pawns()
		6: content = _ch_cards()
		7: content = _ch_laws()
		8: content = _ch_general()
		_: content = _ch_super()
	var entries: Array = content["entries"]
	content["overview"] = entries.pop_front()
	return content


# ---------------------------------------------------------------------------
# 내용 (장 10개). 장마다 항목 목록: title / tone / 그림(texture·art·number·icon) / chips / summary / rows / points / note / tip / extra
# ---------------------------------------------------------------------------

func _ch_start() -> Dictionary:
	return {"title": "시작하기", "entries": [
		{"title": "한눈에 보기", "art": &"start", "tone": Color("86d94f"), "chips": ["2~4인", "한 바퀴 레이스"],
			"summary": "말 [b]4개를 모두[/b] 결승선(0번)에 먼저 넣는 레이스예요.",
			"rows": [["이기는 법", "말 4개 완주 → 먼저 해낸 순서로 1·2·3위"], ["특수 승리", "법전의 조건을 라운드 끝까지 채우면 졸업"], ["손패", "생떼 카드 최대 7장"], ["출발", "말 4개 모두 출발선(0번)에서"]],
			"tip": "처음이라면 [b]놀이터[/b]에서 컴퓨터와 한 판 해 보세요."},
		{"title": "완주와 순위", "icon": &"crown", "tone": Color("86d94f"),
			"summary": "말이 0번에 닿으면 완주. 4개 모두 완주하면 [b]순위 확정[/b]!",
			"rows": [["1·2·3위", "먼저 해낸 순서대로"], ["4위", "마지막 남은 한 명"], ["특수 승리", "법전 조건을 채운 채 차례가 끝나면 바로 졸업"]]},
		{"title": "말마다 능력", "art": &"pawn_ability", "tone": Color("f08aa8"), "chips": ["증강", "필살기 1회"],
			"summary": "증강으로 말을 [b]체스·장기·쇼기…[/b]로 진화시켜요. 말마다 상시 능력과 한 판에 한 번 쓰는 필살기가 있어요.",
			"points": ["보드 위 말에 마우스를 올리면 능력이 보여요", "자세한 건 [b]도감 → 말[/b]"]},
		{"title": "굴리는 도구", "art": &"tool_swap", "tone": Color("5fc1e8"), "chips": ["13종"],
			"summary": "기본 주사위로 시작해 증강으로 [b]윷·룰렛·홀덤·슬롯…[/b]으로 바꿔요.",
			"points": ["도구마다 족보와 칸 수가 달라요", "게임 중 오른쪽 카드에 규칙표가 나와요", "자세한 건 [b]도감 → 도구[/b]"]},
		{"title": "카드와 법전", "art": &"card_law", "tone": Color("f0c14e"), "chips": ["생떼 카드", "특수 승리"],
			"summary": "함정을 깔고, 상대 말을 날리고, 법전의 특수 승리를 노려 판을 뒤집어요.",
			"points": ["카드는 빵집·증강에서 얻어요", "법전 조건은 차례가 끝날 때마다 판정해요"]},
	]}


func _ch_turn() -> Dictionary:
	var dash: String = _join_tiles(BoardSpec.dash_tiles)
	return {"title": "한 턴", "entries": [
		{"title": "한눈에 보기", "art": &"turn", "tone": Color("86d94f"), "chips": ["4단계"],
			"summary": "한 턴은 [b]카드 → 굴리기 → 말 고르기 → 정산[/b] 순서예요.",
			"rows": [["① 카드", "굴리기 전에 한 장 (안 써도 돼요)"], ["② 굴리기", "도구를 굴려 칸 수 결정"], ["③ 말 고르기", "그 칸 수만큼 움직일 말 선택"], ["④ 정산", "도착한 칸의 효과가 터져요"]],
			"tip": "카드는 [b]굴리기 전에만[/b] 낼 수 있어요. 눈금을 보고 고민하려면 아껴 두세요."},
		{"title": "카드 한 장", "number": 1, "tone": Color("f0c14e"), "chips": ["굴리기 전", "턴당 1장"],
			"summary": "카드를 [b]보드판 위로 끌어다 놓으면[/b] 발동해요.",
			"points": ["함정·소환은 놓은 뒤 칸을 골라요", "방어 카드는 끌어 쓰지 않아요 (공격받을 때 팝업)"]},
		{"title": "굴리기", "number": 2, "tone": Color("86d94f"), "chips": ["R / 스페이스"],
			"summary": "[b]굴리기[/b] 버튼을 꾹 눌러 파워를 모으고 손을 떼요.",
			"points": ["룰렛은 원판을 잡아 돌리고, 리볼버는 방아쇠를 당겨요"]},
		{"title": "말 고르기", "number": 3, "tone": Color("5fc1e8"),
			"summary": "아래 말 카드나 보드 위의 말을 누르면 그 말이 움직여요.",
			"points": ["카드에 도착 결과가 미리 보여요 (잡기·빵집·워프…)"]},
		{"title": "정산", "number": 4, "tone": Color("f08aa8"),
			"summary": "도착한 칸의 효과가 터져요. 공격받으면 방어 카드로 받아칠지 물어봐요.",
			"points": ["빵집이면 카드 1장, 옷장이면 순간이동", "적 말 위에 멈추면 잡기!"]},
		{"title": "보너스 이동", "icon": &"play", "tone": Color("63e6be"), "chips": ["후퇴 없음"],
			"summary": "말은 절대 뒤로 가지 않아요. 대신 여러 보너스로 앞으로 튀어 나가요.",
			"rows": [["복수 부스터", "출발선으로 날아간 말이 다시 나올 때 +4칸"], ["부스터 발판", "%s번에 딱 멈추면 +3칸" % dash], ["재굴림", "윷말은 적을 잡으면 한 번 더"]]},
		{"title": "증강 라운드", "icon": &"crown", "tone": Color("ffa94d"), "chips": ["3라운드마다"],
			"summary": "1·4·7라운드처럼 [b]3라운드마다[/b] 모두가 3장 중 하나를 골라요.",
			"points": ["1라운드는 기물 진화, 4라운드는 판정 도구·카드·기물 진화", "7라운드부터 법전·초증강도 등장", "카드마다 한 번 다시 뽑기", "자세한 건 [b]도감 → 법전[/b]"]},
		{"title": "템포 업", "icon": &"hourglass", "tone": Color("ff6b6b"), "chips": ["8·15·22라운드"],
			"summary": "판이 길어지면 [b]게임이 점점 빨라져요[/b]. 단계가 오르는 라운드 시작 전에 크게 경고해요.",
			"rows": [["8라운드 · 과열", "최종 이동 +1칸 · 리벤지 +6칸 · 법전·초증강 확률 상승"], ["15라운드 · 광기", "최종 이동 +2칸 · 리벤지 +8칸 · 법전에 무작위 특수 승리 1개 등록"], ["22라운드 · 대붕괴", "전원 이동 +3칸 · 결승선이 라운드마다 2칸씩 당겨짐"]],
			"points": ["당겨진 결승선은 체크무늬 칸으로 보여요", "그 칸에 들어서거나 서 있으면 바로 완주!"]},
	]}


func _ch_board() -> Dictionary:
	var make_board: Callable = func() -> Control:
		var board := MiniBoard.new()
		board.custom_minimum_size = Vector2(440, 440)
		board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		return board
	return {"title": "보드", "entries": [
		{"title": "한눈에 보기", "art": &"board", "tone": Color("86d94f"), "chips": ["%d칸" % BoardSpec.tile_count, "반시계"],
			"summary": "우하단 0번에서 출발해 반시계로 한 바퀴. 다시 0번이 [b]결승선[/b]이에요.", "extra": make_board,
			"points": ["옷장과 부스터 발판은 [b]딱 멈출 때만[/b] 작동해요", "오른쪽 칸 이름을 누르면 자세히 볼 수 있어요"]},
		{"title": "코너", "icon": &"grid", "tone": Color("2f8f4e"), "chips": [_join_tiles(BoardSpec.corner_tiles.slice(1)) + "번"],
			"summary": "딱 멈추면 [b]다음 굴림 결과 +1[/b]! 단, 이 칸에 함정이 있으면 버프 대신 함정이 발동해요.",
			"points": ["[b]코너 전용 함정[/b]만 설치할 수 있는 칸이에요", "무인도·우이의 소원빌기", "지나가는 상인·물의 세례를 받아라"]},
		{"title": "반환점", "icon": &"crown", "tone": Color("c98a14"), "chips": ["%d번" % BoardSpec.halfway_tile],
			"summary": "여기를 지나면 체스 폰은 [b]퀸[/b]으로, 쇼기 말은 [b]승급[/b]해요."},
		{"title": "빵집", "icon": &"book", "tone": Color("d9822b"), "chips": [_join_tiles(BoardSpec.bakery_tiles) + "번"],
			"summary": "딱 멈추면 [b]생떼 카드 1장[/b]! 어떤 카드인지는 본인만 알아요."},
		{"title": "옷장", "icon": &"key", "tone": Color("2f9aa3"), "chips": [_join_tiles(BoardSpec.portal_tiles) + "번"],
			"summary": "딱 멈추면 [b]순간이동[/b]! 두 옷장은 [b]왕복[/b]이라 밟은 쪽의 반대편으로 가요. 지나가기만 하면 아무 일도 없어요.",
			"rows": _warp_rows()},
		{"title": "부스터 발판", "icon": &"play", "tone": Color("2fb59a"), "chips": [_join_tiles(BoardSpec.dash_tiles) + "번"],
			"summary": "딱 멈추면 [b]+3칸[/b] 더 날아가요."},
		{"title": "함정 칸", "texture": TextureCache.fetch("res://assets/board/traps/HIDDEN.png"), "tone": Color("7a5cd6"), "chips": ["한 칸에 하나"],
			"summary": "함정이 깔린 칸은 [b]보라색[/b]으로 바뀌고 그 함정 그림이 보여요.",
			"points": ["상대가 숨긴 함정은 물음표로 보여요", "코너 함정은 누구에게나 공개", "코너·빵집·옷장·부스터 발판에는 일반 함정을 깔 수 없어요"]},
	]}


func _warp_rows() -> Array:
	var rows: Array = []
	for from_tile: int in BoardSpec.portal_warp_targets.keys():
		rows.append(["%d번 옷장" % from_tile, "→ %d번으로" % int(BoardSpec.portal_warp_targets[from_tile])])
	return rows


func _ch_capture() -> Dictionary:
	return {"title": "잡기", "entries": [
		{"title": "한눈에 보기", "art": &"capture", "tone": Color("f08aa8"),
			"summary": "적 말이 있는 칸에 [b]멈추면[/b] 그 말은 출발선으로 날아가요.",
			"rows": [["잡기", "멈춘 쪽이 잡아요 (스치기만 하면 안 잡혀요)"], ["출발선(0번)", "안전 지대: 잡을 수 없어요"], ["내 말끼리", "잡지 않아요"]],
			"tip": "완주 직전에 잡히면 억울해요. 선두 말은 적 앞을 조심!"},
		{"title": "말의 기본", "icon": &"play", "tone": Color("5fc1e8"), "chips": ["말 4개", "굴린 만큼 전진"],
			"summary": "내 말은 모두 [b]4개[/b]. 처음엔 전부 출발선(0번)에서 기다려요.",
			"rows": [["출발", "굴림 눈금만큼 한 말을 골라 내보내요"], ["이동", "눈금만큼 반시계로 한 칸씩 전진해요"], ["잡기", "적 말 위에 멈추면 그 말은 출발선으로"], ["잡히면", "출발선으로 돌아가 다시 출발해요 (리벤지 부스터 획득)"], ["완주", "0번에 닿으면 끝. 4개 모두 완주하면 순위 확정"]],
			"points": ["말마다 능력과 필살기가 달라요 ([b]도감 → 말[/b])", "보드 위 말에 마우스를 올리면 상태가 보여요"]},
		{"title": "공격 카드", "icon": &"sword", "tone": Color("ff6b6b"), "chips": ["%d종" % MainBoard.ATTACK_CARDS.size(), "발동 경보"],
			"summary": "상대 말과 차례를 흔드는 카드예요. 쓰면 먼저 [b]공격 카드 발동![/b] 경보가 뜨고 어떤 카드인지 공개돼요.",
			"rows": _card_rows(MainBoard.ATTACK_CARDS),
			"tip": "공격은 상대가 [b]방어 카드[/b]로 막을 수 있어요."},
		{"title": "방어 카드", "icon": &"sword", "tone": Color("74c0fc"), "chips": ["피격 시", "%d종" % _cards_of(GameEnums.CardCategory.COUNTER).size()],
			"summary": "내가 공격받으면 [b]방어 카드를 쓸지[/b] 팝업으로 물어봐요.",
			"rows": _card_rows(_cards_of(GameEnums.CardCategory.COUNTER)),
			"points": ["잡기·공격 카드·함정이 공격이에요", "그냥 맞기를 고르면 그 공격엔 다시 못 써요"]},
		{"title": "함정 카드", "art": &"hidden_trap", "tone": Color("b197fc"), "chips": ["칸에 깔기", "한 칸에 하나"],
			"summary": "칸을 골라 몰래 깔아 두는 카드예요. 누가 깔았는지만 알려지고 [b]어떤 카드인지는 비밀[/b]!",
			"rows": _card_rows(_cards_of(GameEnums.CardCategory.TRAP)),
			"points": ["일반 함정은 코너·빵집·옷장·부스터 발판을 뺀 칸에 깔아요", "코너 전용 함정은 코너에만 깔고, 누구에게나 공개돼요"]},
		{"title": "숨은 함정", "art": &"hidden_trap", "tone": Color("b197fc"),
			"summary": "상대가 깐 함정은 [b]물음표[/b]로만 보여요. 밟아 보기 전엔 몰라요.",
			"points": ["내 함정은 내 화면에서 그림이 보여요"]},
	]}


## 이 종류의 카드 (덱에 들어가는 것만, 카드 번호 순).
func _cards_of(category: int) -> Array:
	var result: Array = []
	for card_id: StringName in CardRegistry.DECK_COMPOSITION.keys():
		if CardRegistry.get_card(card_id).category == category:
			result.append(card_id)
	return result


## 카드 목록을 [이름, 한 줄 설명] 표로: 설명 앞의 [방어]·[코너] 같은 머리표는 뗀다.
func _card_rows(card_ids: Array) -> Array:
	var rows: Array = []
	for card_id: Variant in card_ids:
		var card: BaseCard = CardRegistry.get_card(StringName(card_id))
		var line: String = MainBoard.card_summary(StringName(card_id)).replace("\n", " ")
		if line.begins_with("[방어] "):
			line = line.trim_prefix("[방어] ")
		rows.append([card.display_name, line])
	return rows


func _ch_tools() -> Dictionary:
	var entries: Array = [
		{"title": "굴리는 도구", "art": &"tool_swap", "tone": Color("86d94f"), "chips": ["증강으로 교체"],
			"summary": "처음엔 [b]기본 주사위[/b](1~6칸). 증강의 [b]판정 도구 교체[/b]로 오른쪽 도구 중 하나로 바꿀 수 있어요.",
			"rows": [["한 방", "친치로 · 777 슬롯"], ["안정", "윷 · 야추"], ["짜릿함", "러시안 룰렛 · 블랙잭"]],
			"points": ["오른쪽 카드를 누르면 족보와 칸 수 표가 나와요", "파워 게이지는 연출일 뿐, 결과는 공정해요"],
			"tip": "러시안 룰렛은 [b]멈추기[/b] 버튼이 생명이에요."},
	]
	for definition: AugmentDef in _augments(GameEnums.AugmentCategory.TOOL_SWAP):
		var tool_id: StringName = definition.payload
		var rules: Dictionary = MainBoard.TOOL_RULES.get(tool_id, {})
		var card: Array = MainBoard.TOOL_CARDS.get(tool_id, ["", Color.WHITE, "", ""])
		var data: Dictionary = {"title": ToolRegistry.create(tool_id).display_name, "augment": definition.augment_id, "texture": AugmentArt.load_first(AugmentArt.tool_candidates(tool_id)), "icon": &"dice",
			"tone": Color("9775fa"), "summary": GameData.text("dice", tool_id, "desc", str(card[2])), "rows": rules.get("rows", [])}
		if rules.has("note"):
			data["note"] = rules["note"]
		if str(card[3]) != "":
			data["chips"] = [str(card[3])]
		entries.append(data)
	return {"title": "도구", "entries": entries, "wide": true}


## 증강 표에서 한 종류의 증강만 (표 순서대로).
static func _augments(category: GameEnums.AugmentCategory) -> Array[AugmentDef]:
	var result: Array[AugmentDef] = []
	for definition: AugmentDef in AugmentRegistry.all():
		if definition.category == category:
			result.append(definition)
	return result


func _ch_pawns() -> Dictionary:
	var entries: Array = [
		{"title": "진화와 필살기", "art": &"pawn_ability", "tone": Color("f08aa8"), "chips": ["7계열", "필살기 1회"],
			"summary": "증강의 [b]기물 지급[/b]으로 기본 말 하나를 오른쪽 기물로 진화시켜요.",
			"rows": _family_rows(),
			"points": ["보드 위 말에는 한 글자 라벨이 붙어요", "필살기는 내 프로필 카드에서 굴리기 전에 눌러요", "잡혀서 출발선으로 가도 필살기는 되살아나지 않아요"]},
	]
	for definition: AugmentDef in _augments(GameEnums.AugmentCategory.PAWN_EVOLUTION):
		var kind: GameEnums.PawnKind = definition.payload
		var unit: int = definition.units[0]
		var sub: GameEnums.PawnSubType = PawnCatalog.sub_type_of(kind, unit)
		# 구분선 위 패시브(둘이면 줄 나눔), 아래 필살기 (이름 꼬리표 + 설명). [패시브]·[필살기] 머리말은 쓰지 않는다.
		var rows: Array = []
		var passive: String = PawnCatalog.passive_lines(kind, unit)
		if passive != "":
			rows.append([passive])
		var skill: StringName = PawnCatalog.SKILL_IDS.get(sub, &"")
		if skill != &"":
			rows.append([PawnCatalog.skill_name(skill), PawnCatalog.skill_text(skill)])
		var chips: Array = [PawnCatalog.display_set_name(kind)]
		if sub == GameEnums.PawnSubType.CHESS_PAWN:
			# 폰은 반환점에서 퀸이 된다: 승급한 뒤의 능력을 퀸 그림과 함께 보여 준다
			var queen: GameEnums.PawnSubType = GameEnums.PawnSubType.CHESS_QUEEN
			rows.append([_pawn_texture(queen, kind), "퀸 승급 후", "%s\n반환점(%d번) 이상을 밟는 순간 영구 승급 (잡혀도 퀸 유지)" % [PawnCatalog.split_passive(PawnCatalog.SUB_ABILITIES[queen]), BoardSpec.halfway_tile]])
			chips.append("퀸 승급")
		entries.append({"title": PawnCatalog.unit_label(kind, unit).split(":")[-1], "augment": definition.augment_id, "texture": _pawn_texture(sub, kind), "icon": &"crown",
			"tone": Color("20c997"), "chips": chips, "summary": PAWN_LINES.get(kind, ""), "rows": rows})
	return {"title": "말", "entries": entries, "wide": true}


## 전체 설명용: 계열마다 대표 그림 + 이름 + 한 줄 소개.
func _family_rows() -> Array:
	var rows: Array = []
	for kind: GameEnums.PawnKind in PawnCatalog.EVOLVABLE_SETS:
		rows.append([_pawn_texture(PawnCatalog.SUB_TYPES[kind][0], kind), PawnCatalog.display_set_name(kind), PAWN_LINES.get(kind, "")])
	return rows


## 계열 한 줄 소개.
const PAWN_LINES: Dictionary = {
	GameEnums.PawnKind.YUT: "잡으면 재굴림, 만나면 자동으로 업혀요.",
	GameEnums.PawnKind.CHESS: "폰은 반환점에서 퀸으로 승급. 기물마다 움직임 보너스가 달라요.",
	GameEnums.PawnKind.JANGGI: "말을 넘고, 돌진하고, 땅을 흔드는 장기 기물.",
	GameEnums.PawnKind.MONOPOLY: "필살기 호텔·워프·카드로 판을 굴리는 모노폴리 말.",
	GameEnums.PawnKind.GO: "흑돌은 홀수 눈금 +1칸, 백돌은 방어막.",
	GameEnums.PawnKind.SHOGI: "반환점을 지나면 승급(나리)해 더 강해져요.",
	GameEnums.PawnKind.ARCADE: "킹 체커·루도·8번 공·스타 카트·지뢰찾기 공병.",
}


## 세부 기물 그림 (투명 여백을 잘라 낸 아틀라스).
static func _pawn_texture(sub: Variant, kind: GameEnums.PawnKind) -> Texture2D:
	var root: String = PawnArt.ROOT
	var key: String = GameEnums.PawnSubType.keys()[int(sub)]
	var paths: Array[String] = [root + key + ".png"]
	if kind == GameEnums.PawnKind.YUT:
		paths.append(root + "YUT.png")
	paths.append(root + str(AugmentArt.PAWN_FILES.get(kind, "PAWN_DEFAULT")) + ".png")
	var sprite: Dictionary = PawnArt.load_sprite(paths)
	if sprite.is_empty():
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = sprite["texture"]
	atlas.region = sprite["region"]
	return atlas


func _ch_cards() -> Dictionary:
	var entries: Array = [
		{"title": "카드 쓰는 법", "art": &"card_law", "tone": Color("f0c14e"), "chips": ["손패 최대 7장"],
			"summary": "빵집·증강에서 얻은 카드를 [b]보드판으로 끌어다 놓아[/b] 써요.",
			"rows": [["방어 (파랑)", "공격받으면 팝업에서 발동 여부를 물어봐요"], ["즉발 (노랑)", "굴리기 전에 바로 효과"], ["함정 (보라)", "칸을 골라 숨겨 깔기, 코너 전용 4종"], ["소환 (분홍)", "상단 코너에 1마리, 말을 잡을 때까지 계속 전진해요"]],
			"tip": "일기토 데스매치는 [b]상대 프로필이나 말 위에[/b] 놓으면 그 상대와 붙어요. 종목은 6종 중 무작위!"},
	]
	for card_id: StringName in CardRegistry.DECK_COMPOSITION.keys():
		var card: BaseCard = CardRegistry.get_card(card_id)
		var tone: Color = Color("f0c14e")
		var when: String = "굴리기 전 (내 턴 시작)"
		var how: String = "보드에 끌어 놓기"
		match card.category:
			GameEnums.CardCategory.COUNTER:
				tone = Color("74c0fc")
				when = "피격 시 (내가 공격받았을 때)"
				how = "발동 여부를 묻는 팝업에서 [발동]"
			GameEnums.CardCategory.TRAP:
				tone = Color("b197fc")
				how = "보드에 끌어 놓고 %s 고르기" % ("코너" if card.corner_only else "칸")
			GameEnums.CardCategory.SUMMON:
				tone = Color("f08aa8")
		var quote: String = GameData.text("cards", card_id, "parody_quote")
		var data: Dictionary = {"title": card.display_name, "card": card_id, "texture": TextureCache.fetch("res://assets/cards/%s.png" % card_id), "icon": &"book", "tone": tone,
			"chips": [MainBoard.CARD_CATEGORY_NAMES[card.category], "%d장" % int(CardRegistry.DECK_COMPOSITION[card_id])],
			"summary": MainBoard.card_summary(card_id).replace("\n", " "),
			"rows": [["언제", when], ["방법", how]]}
		if quote != "":
			data["note"] = "“%s”" % quote
		if CardSkin.SELF_RISK.has(card_id):
			(data["rows"] as Array).append(["주의", CardSkin.SELF_RISK[card_id]])  # 카드 앞면에는 경고 아이콘
		if card_id == &"ACT_09":
			# 일기토 데스매치: 6종 미니게임 중 하나가 무작위로 뽑힌다
			for game: int in DuelRules.GAME_COUNT:
				(data["rows"] as Array).append([DuelRules.game_title(game), DuelRules.GAME_RULES[game]])
		entries.append(data)
	return {"title": "카드", "entries": entries, "wide": true}


func _ch_laws() -> Dictionary:
	var entries: Array = [
		{"title": "증강과 법전", "art": &"card_law", "tone": Color("ffa94d"), "chips": ["3라운드마다", "법전 4칸"],
			"summary": "1·4·7라운드처럼 [b]3라운드마다[/b] 모두가 증강 3장 중 하나를 골라요. 법전의 교칙은 모두 [b]특수 승리 조건[/b]이에요.",
			"rows": [["기물 지급", "말 하나를 새 기물로 진화 (도감 → 말)"], ["도구 교체", "굴리는 도구 바꾸기 (도감 → 도구)"], ["특수 승리", "법전에 새 승리 조건 (3라운드부터)"], ["카드 패키지", "생떼 카드 여러 장 (도감 → 범용)"], ["범용 보급", "기물 변이 · 전군 돌연변이 · 필살기 리필 (도감 → 범용)"], ["초증강", "하이리스크 하이리턴 (도감 → 초증강)"]],
			"points": ["차례가 끝날 때 교칙을 달성해 있으면 [b]바로 다음 순위로 졸업[/b], 그 교칙은 사라져요 (같은 교칙을 여럿이 채우면 레이스에서 앞선 한 명만)", "새 교칙이 들어오면 가장 오래된 교칙이 밀려나요", "증강 카드마다 한 번 다시 뽑기"],
			"tip": "법전 슬롯에 마우스를 올리면 모두의 진행도가 보여요. [color=#d6336c][b][위험!][/b][/color] 표시를 견제하세요!"},
	]
	for definition: AugmentDef in _augments(GameEnums.AugmentCategory.LAW_ENACT):
		var law: VictoryLaw = LawRegistry.create(String(definition.payload)) as VictoryLaw
		if law == null:
			continue
		var counting: String = "법전에 있는 동안만 세요" if VictoryLaw.SESSION_KEYS.has(law.stat_key) else "게임 내내 쌓여요"
		entries.append({"title": law.law_name, "augment": definition.augment_id, "law_id": law.law_id, "texture": TextureCache.fetch("res://content_trickcal/illustrations/laws/%s.png" % law.law_id), "icon": &"book",
			"tone": Color("ffd43b"), "chips": ["목표 %d%s" % [law.goal(), law.unit()]], "summary": law.condition_text(),
			"rows": [["판정", "차례가 끝날 때마다, 달성했으면 바로 졸업하고 교칙은 사라져요"], ["기록", counting], ["이의 있음!", "기록을 0으로 되돌릴 수 %s" % ("있어요" if law.resettable() else "없어요")]]})
	return {"title": "법전", "entries": entries, "wide": true}


## 범용: 생떼 카드 패키지와 범용 보급 (법전 장에서 따로 뺐다).
func _ch_general() -> Dictionary:
	var entries: Array = [
		{"title": "카드 패키지와 범용 보급", "art": &"card_law", "tone": Color("74c0fc"), "chips": ["증강 라운드", "누구나"],
			"summary": "판을 뒤집지는 않지만 [b]손패와 기물을 든든하게[/b] 채워 주는 증강이에요.",
			"rows": [["카드 패키지", "생떼 카드 여러 장 (방어·함정만 주는 보급도)"], ["범용 보급", "기물 변이 · 전군 돌연변이 · 필살기 리필"]],
			"points": ["필살기를 이미 쓴 기물이 있으면 리필이 이득이에요", "손패는 최대 장수를 넘으면 더 받지 못해요"]},
	]
	for definition: AugmentDef in _augments(GameEnums.AugmentCategory.CARD_PACKAGE):
		entries.append(_augment_entry(definition, &"gear"))
	for definition: AugmentDef in _augments(GameEnums.AugmentCategory.UTILITY):
		entries.append(_augment_entry(definition, &"gear"))
	return {"title": "범용", "entries": entries, "wide": true}


## 증강 카드 한 장을 도감 항목으로: 첫 줄은 요약, 나머지 ◆ 줄은 항목 점.
static func _augment_entry(definition: AugmentDef, icon: StringName) -> Dictionary:
	var info: Dictionary = MainBoard.augment_card_info(definition, null, 1)
	var lines: Array = str(info["desc"]).split("\n")
	return {"title": str(info["title"]), "augment": definition.augment_id, "texture": info.get("art"), "icon": icon, "tone": info["color"],
		"chips": [str(info["category"])], "summary": str(lines[0]).trim_prefix("◆ "), "points": lines.slice(1).map(func(line: String) -> String: return line.trim_prefix("◆ "))}


## 초증강: 하이리스크 하이리턴. 판을 한 번에 뒤집을 수 있지만 내게도 화살이 돌아올 수 있는 증강들.
func _ch_super() -> Dictionary:
	var entries: Array = [
		{"title": "하이리스크 하이리턴", "art": &"card_law", "tone": Color("ffd43b"), "chips": ["초증강", "%d종" % SuperAugments.ALL_IDS.size()],
			"summary": "초증강은 [b]판을 한 번에 뒤집는[/b] 증강이에요. 크게 얻는 대신 [b]내 말도 다칠 수 있어요[/b].",
			"rows": [["한 방", "판 뒤집기 · 저격수의 표적"], ["도박", "주사위 도박사 · 악마의 계약"], ["강탈", "도적단 대습격 · 빵집 털이 · 공산주의 재분배"], ["난장판", "폭주 기관차 · 강제 캐슬링 · 광란의 지뢰밭 · 강제 연대책임"], ["질주", "아우토반 니트로: 선두 말이 코너까지 직진, 길을 막은 칸은 전부 장외 사출"]],
			"points": ["폭주 기관차는 내 말도 가리지 않아요", "강제 연대책임은 선두와 꼴찌 말의 운명을 묶어요", "조건이 안 맞는 초증강은 드래프트에 나오지 않아요"],
			"tip": "질 것 같을 때가 초증강을 고를 때예요. [b]역전은 한 번이면 충분[/b]하니까요!"},
	]
	for definition: AugmentDef in _augments(GameEnums.AugmentCategory.SUPER_GAMBLE):
		entries.append(_augment_entry(definition, &"star"))
	return {"title": "초증강", "entries": entries, "wide": true}


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

	static func _join_dash(tiles: Array) -> String:
		var parts: Array[String] = []
		for tile: Variant in tiles:
			parts.append(str(tile))
		return "·".join(parts)

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
			_dashed(from_tile, int(BoardSpec.portal_warp_targets[from_tile]), Color("2f9aa3"))
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
				fill = Color("c8eef0")
				edge = Color("2f9aa3")
			elif BoardSpec.dash_tiles.has(index):
				fill = Color("ffd3e2")
				edge = Color("d9577f")
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
			label = L10n.t(label)
			var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
			draw_string(font, center + Vector2(-width / 2.0, label_size * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, Color("3a2f1f"))
		# 안쪽 범례
		var legend: Array = [[Color("86d94f"), "출발 · 결승"], [Color("b6ea8c"), "코너 (코너 전용 함정)"], [Color("ffe48a"), "반환점 (승급 기준)"], [Color("ffd98a"), "빵집 (카드 1장)"], [Color("c8eef0"), "옷장 (%s)" % _warp_text(BoardSpec.portal_warp_targets)], [Color("ffd3e2"), "부스터 발판 (%s번, 딱 멈추면 +%d칸)" % [_join_dash(BoardSpec.dash_tiles), GameEnums.DASH_STEPS]]]
		var origin := Vector2(92, 118)
		for index: int in legend.size():
			var spot: Vector2 = origin + Vector2(0, index * 30.0)
			var swatch := StyleBoxFlat.new()
			swatch.bg_color = legend[index][0]
			swatch.border_color = Color("8a7a45")
			swatch.set_border_width_all(2)
			swatch.set_corner_radius_all(5)
			draw_style_box(swatch, Rect2(spot, Vector2(20, 20)))
			draw_string(font, spot + Vector2(28, 16), L10n.t(legend[index][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("3a2f1f"))

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
