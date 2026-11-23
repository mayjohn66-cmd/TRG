# File: res://scenes/rulebook.gd
# Class: class_name Rulebook
# Role: 규칙 도감. 왼쪽 목록은 [기본 규칙]과 [도감] 두 묶음의 장들.
#       기본 규칙 장은 내용을 모두 펼친 읽는 쪽(장 설명 + 항목 칸들을 위에서 아래로),
#       도감 장은 같은 모양의 카드 격자(그림·이름·한 줄 요약)이고 카드를 누르면 가운데 상세 창이 뜬다 ([이전]·[다음]으로 넘긴다).
#       도구 규칙표·기물 능력·카드·교칙·보드판 문구는 실제 데이터(TOOL_RULES·PawnCatalog·CardRegistry·VictoryLaw·BoardCatalog)에서 읽어 온다.
class_name Rulebook
extends Control

## 기록 코드를 불러왔다 (허브의 #태그·닉네임·법전 수 배지를 다시 그린다).
signal records_imported

const INK: Color = Color("6b4a2a")
const DARK_INK: Color = Color("3a2f1f")
const GOLD: Color = Color("c98a14")
const FRAME: Color = Color("bfe9d8")
const FRAME_EDGE: Color = Color("5fc9a0")
const TEAL: Color = Color("7cc4b4")
const TEAL_DARK: Color = Color("2f6f66")
const VISUALS = preload("res://scenes/rulebook_visuals.gd")
const BOARD_PREVIEW_DIR: String = "res://assets/ui/trickcal/board_preview/"

## 장 (왼쪽 목록 순서). 0~3은 기본 규칙(읽는 쪽), 4~10은 도감(카드 격자 + 상세 창).
const TAB_NAMES: Array[String] = ["시작하기", "한 턴", "잡기", "특수 칸", "보드판", "도구", "말", "카드", "법전", "보급", "초증강"]
const TAB_ART: Array[StringName] = [&"start", &"turn", &"capture", &"board", &"board", &"roll", &"pawn_ability", &"play_card", &"lawbook", &"supply", &"super"]
const GROUP_NAMES: Array[String] = ["기본 규칙", "도감"]
## 묶음마다 첫 장의 번호.
const GROUP_STARTS: Array[int] = [0, 4]
## 법전 장 (메뉴의 법전 수집 배지가 바로 연다).
const LAW_SPREAD: int = 8
const BOARD_SPREAD: int = 4
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
const STAGE: Vector2 = Vector2(1366.0, 768.0)
## 왼쪽 목록 폭, 책(오른쪽 큰 판)의 위치.
const LIST_X: float = 24.0
const LIST_W: float = 196.0
const BOOK_X: float = 236.0
const BOOK_Y: float = 100.0
const BOOK_BOTTOM: float = 22.0
## 도감 카드 한 장의 최소 높이와 그림 크기.
const CARD_H: float = 112.0
const CARD_ART: float = 84.0
## 상세 창 큰 그림 크기.
const HERO: Vector2 = Vector2(168, 168)
const CARD_FACE: Vector2 = Vector2(180, 252)

## 현재 장 번호(0부터)와 고른 항목 (-1이면 없음: 상세 창이 닫혀 있다).
var spread: int = 0
var entry: int = -1
## 상세 창에 장 설명(overview)을 띄웠는가 (도감 장의 [기본 설명]).
var showing_overview: bool = false
## 지금 장의 내용 ({"title", "intro", "overview", "entries", "catalog"}).
var _content: Dictionary = {}
## 오른쪽 목록의 항목 칸 (도감은 카드 버튼, 기본 규칙은 읽는 쪽의 항목 칸). 순서는 entries와 같다.
var _tiles: Array[Control] = []
var _list_buttons: Array[Button] = []
var _stage: Control = null
var _book: Panel = null
var _list_box: VBoxContainer = null
var _list_scroll: ScrollContainer = null
var _chapter_title: Label = null
var _chapter_intro: Label = null
var _overview_button: Button = null
var _collection_chip: Label = null
var _right_scroll: ScrollContainer = null
var _right_holder: VBoxContainer = null
## 상세 창.
var _modal: Control = null
var _modal_dim: ColorRect = null
var _modal_panel: PanelContainer = null
var _detail_title: Label = null
var _detail_scroll: ScrollContainer = null
var _detail_holder: VBoxContainer = null
var _detail_count: Label = null
var _prev_button: Button = null
var _next_button: Button = null
var _variant_row: HBoxContainer = null
## [기록 백업/복구] 미니 팝업.
var _save_popup: PanelContainer = null
var _save_notice: Label = null
var _code_field: LineEdit = null
## 끌어서 스크롤 (마우스·손가락 모두): 카드 위에서 시작해도 스크롤되고, 움직이지 않고 떼면 그 카드를 연다.
var _drag_scroll: ScrollContainer = null
var _drag_start := Vector2.ZERO
var _drag_top := 0
var _drag_entry := -1
var _drag_finger := -1
var _drag_moved := false
var _dismiss_finger := -2


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
	# 뒤쪽 화면이 비치지 않게: 흐리게 번진 화면 위에 어두운 막(0.75)
	var dim := ColorRect.new()
	dim.name = "BookDim"
	dim.color = Color(0, 0, 0, 0.75)
	dim.material = _blur_material()
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
	_build_header()
	_build_list()
	_build_book()
	_build_modal()
	_build_save_tools()
	resized.connect(_fit_book)
	_fit_book()


## 폰 가로 화면처럼 넓으면 책을 오른쪽으로 넓힌다 (세로 768 기준 좌표는 그대로).
func _fit_book() -> void:
	if _stage == null or _book == null:
		return
	var width := maxf(STAGE.x, size.x)
	_stage.custom_minimum_size.x = width
	_book.size = Vector2(width - BOOK_X - 24.0, STAGE.y - BOOK_Y - BOOK_BOTTOM)
	var backup := _stage.get_node_or_null("SaveBackup") as Control
	if backup != null:
		backup.position.x = width - 304.0
	if _save_popup != null:
		_save_popup.position.x = width - 430.0
	_modal.size = Vector2(width, STAGE.y)
	_layout_modal()
	if not _content.is_empty():
		_rebuild_tiles()


func spread_count() -> int:
	return TAB_NAMES.size()


## 장 번호가 속한 묶음 (0: 기본 규칙, 1: 도감).
static func group_of(index: int) -> int:
	var group: int = 0
	for start_index: int in GROUP_STARTS.size():
		if index >= GROUP_STARTS[start_index]:
			group = start_index
	return group


func is_catalog() -> bool:
	return group_of(spread) == 1


## 지금 장의 항목 수.
func entry_count() -> int:
	return (_content.get("entries", []) as Array).size()


func close() -> void:
	queue_free()


# ---------------------------------------------------------------------------
# 틀: 머리글, 왼쪽 장 목록, 책(장 머리 + 목록), 상세 창, 기록 백업
# ---------------------------------------------------------------------------

static func _box(bg: Color, border: Color, border_width: int, radius: int, shadow: int = 0, margin: int = 0, shadow_color: Color = Color(0, 0, 0, 0.25)) -> StyleBox:
	if bg.a > 0.01 and border_width == 0 and shadow == 0:
		return VISUALS.panel(bg, radius, margin)
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.shadow_color = shadow_color
	box.shadow_size = shadow
	box.set_content_margin_all(margin)
	box.anti_aliasing = true
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
	image.texture = VISUALS.texture(role) if VISUALS.has(role) else ART[role] as Texture2D
	image.custom_minimum_size = extent
	image.size = extent
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image


## 한 줄 글 칸: 번역으로 길어지면 칸 폭에 맞을 때까지 글자를 줄인다 (min_px까지, 그래도 넘치면 말줄임). 칸 크기·언어가 바뀌면 다시 맞춘다.
static func _shrink_to_fit(label: Label, max_px: int, min_px: int) -> void:
	var fit := func() -> void:
		if not is_instance_valid(label) or label.size.x <= 1.0:
			return
		var font: Font = label.get_theme_font("font")
		var text: String = L10n.t(label.text) if label.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED else label.text
		var px: int = max_px
		while px > min_px and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > label.size.x:
			px -= 1
		label.add_theme_font_size_override("font_size", px)
	label.resized.connect(fit)
	label.ready.connect(fit)


static func _label(text: String, size_px: int, color: Color = DARK_INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _build_header() -> void:
	var back := Button.new()
	back.name = "CloseBook"
	back.focus_mode = Control.FOCUS_NONE
	HubArt.button(back, &"round_button", 72)
	var chevron := HubArt.icon(&"next")
	chevron.flip_h = true
	chevron.set_anchors_preset(Control.PRESET_FULL_RECT)
	chevron.offset_left = 14
	chevron.offset_top = 12
	chevron.offset_right = -14
	chevron.offset_bottom = -12
	back.add_child(chevron)
	back.pressed.connect(close)
	_place(back, Vector2(28, 16), Vector2(72, 72))
	var title := HubKit.outlined("규칙 도감", 44, Color.WHITE, Color("3a3250"), 10)
	title.name = "BookTitle"
	_place(title, Vector2(114, 22), Vector2(360, 60))


## 왼쪽 장 목록: 묶음 제목([기본 규칙]·[도감]) 아래에 장 버튼. 아이콘은 버튼 안 왼쪽, 이름은 그 오른쪽.
func _build_list() -> void:
	_list_scroll = ScrollContainer.new()
	_list_scroll.name = "ChapterList"
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_place(_list_scroll, Vector2(LIST_X, BOOK_Y), Vector2(LIST_W, STAGE.y - BOOK_Y - BOOK_BOTTOM))
	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 6)
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.add_child(_list_box)
	for index: int in TAB_NAMES.size():
		var group: int = GROUP_STARTS.find(index)
		if group != -1:
			var heading := HubKit.outlined(GROUP_NAMES[group], 19, Color("fff3c4"), Color("3a3250"), 6)
			heading.name = "Group%d" % group
			heading.custom_minimum_size = Vector2(0, 28 if group == 0 else 36)
			heading.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			_list_box.add_child(heading)
		var button := Button.new()
		button.name = "Tab%d" % index
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(LIST_W - 4.0, 44)
		button.pressed.connect(show_spread.bind(index))
		var icon := _art(TAB_ART[index], Vector2(34, 34))
		icon.name = "Icon"
		icon.position = Vector2(10, 5)
		button.add_child(icon)
		var plate := _label(TAB_NAMES[index], 19, Color.WHITE)
		plate.name = "Plate"
		plate.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plate.position = Vector2(54, 0)
		plate.size = Vector2(LIST_W - 64.0, 44)
		plate.clip_text = true
		plate.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_shrink_to_fit(plate, 19, 13)
		button.add_child(plate)
		_list_box.add_child(button)
		_list_buttons.append(button)


## 책: 연한 청록 테두리 판 하나. 위쪽에 장 머리(제목·한 줄 설명·[기본 설명]), 아래에 스크롤 목록.
func _build_book() -> void:
	_book = Panel.new()
	_book.name = "Book"
	_book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_theme_stylebox_override("panel", _box(Color("f6efd8"), FRAME_EDGE, 6, 30, 14, 0, Color(0, 0, 0, 0.4)))
	_place(_book, Vector2(BOOK_X, BOOK_Y), Vector2(STAGE.x - BOOK_X - 24.0, STAGE.y - BOOK_Y - BOOK_BOTTOM))
	var column := VBoxContainer.new()
	column.name = "BookColumn"
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 26
	column.offset_right = -18
	column.offset_top = 18
	column.offset_bottom = -16
	column.add_theme_constant_override("separation", 12)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(column)
	var head := HBoxContainer.new()
	head.name = "ChapterHead"
	head.add_theme_constant_override("separation", 14)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(texts)
	_chapter_title = _label("", 30, Color("4a3520"))
	_chapter_title.name = "ChapterTitle"
	texts.add_child(_chapter_title)
	_chapter_intro = _label("", 17, INK)
	_chapter_intro.name = "ChapterIntro"
	_chapter_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chapter_intro.max_lines_visible = 2
	_chapter_intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(_chapter_intro)
	_collection_chip = _label("", 16, Color("7a5a10"))
	_collection_chip.name = "LawCount"
	_collection_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_collection_chip.add_theme_stylebox_override("normal", _box(Color("fff0b8"), Color("e0b23a"), 2, 14, 0, 8))
	head.add_child(_collection_chip)
	_overview_button = LobbyTheme.small_button("기본 설명", func() -> void: show_overview(), &"teal", 17)
	_overview_button.name = "OverviewButton"
	_overview_button.custom_minimum_size = Vector2(128, 44)
	_overview_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_overview_button)
	var rule := ColorRect.new()
	rule.color = Color(0.55, 0.42, 0.25, 0.25)
	rule.custom_minimum_size = Vector2(0, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)
	_right_scroll = ScrollContainer.new()
	_right_scroll.name = "CatalogScroll"
	_right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_right_scroll)
	_right_holder = VBoxContainer.new()
	_right_holder.name = "ChapterBody"
	_right_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_holder.add_theme_constant_override("separation", 14)
	_right_scroll.add_child(_right_holder)


## 상세 창: 책 위를 어둡게 덮고 가운데 큰 종이. 위에 그림·제목·꼬리표·요약, 아래 스크롤에 표·요점, 맨 아래 [이전]·n/N·[다음]·[닫기].
func _build_modal() -> void:
	_modal = Control.new()
	_modal.name = "EntryModal"
	_modal.size = STAGE
	_modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal.visible = false
	_stage.add_child(_modal)
	_modal_dim = ColorRect.new()
	_modal_dim.name = "ModalDim"
	_modal_dim.color = Color(0.05, 0.04, 0.08, 0.6)
	_modal_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.add_child(_modal_dim)
	_modal_panel = PanelContainer.new()
	_modal_panel.name = "EntryPage"
	_modal_panel.add_theme_stylebox_override("panel", _box(Color("fbf4df"), Color("8a6a4a"), 6, 26, 16, 22, Color(0, 0, 0, 0.45)))
	_modal.add_child(_modal_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_modal_panel.add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	column.add_child(top)
	_detail_title = _label("", 30, Color("4a3520"))
	_detail_title.name = "EntryTitle"
	_detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(_detail_title)
	_variant_row = HBoxContainer.new()
	_variant_row.name = "BoardVariants"
	_variant_row.add_theme_constant_override("separation", 6)
	top.add_child(_variant_row)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.name = "EntryDetailScroll"
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_detail_scroll)
	_detail_holder = VBoxContainer.new()
	_detail_holder.name = "EntryDetail"
	_detail_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_holder.add_theme_constant_override("separation", 12)
	_detail_scroll.add_child(_detail_holder)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(bottom)
	_prev_button = LobbyTheme.small_button("◀ 이전", func() -> void: _step_entry(-1), &"teal", 18)
	_prev_button.name = "PrevEntry"
	_prev_button.custom_minimum_size = Vector2(130, 48)
	bottom.add_child(_prev_button)
	_detail_count = _label("", 18, INK)
	_detail_count.name = "EntryCount"
	_detail_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_count.custom_minimum_size = Vector2(90, 0)
	bottom.add_child(_detail_count)
	_next_button = LobbyTheme.small_button("다음 ▶", func() -> void: _step_entry(1), &"teal", 18)
	_next_button.name = "NextEntry"
	_next_button.custom_minimum_size = Vector2(130, 48)
	bottom.add_child(_next_button)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(40, 0)
	bottom.add_child(gap)
	var close_entry := LobbyTheme.small_button("닫기", func() -> void: show_entry(-1), &"gray", 18)
	close_entry.name = "CloseEntry"
	close_entry.custom_minimum_size = Vector2(130, 48)
	bottom.add_child(close_entry)


## 상세 창은 책 판을 거의 다 덮는 크기 (넓은 화면이면 너무 넓어지지 않게 1080까지).
func _layout_modal() -> void:
	if _modal_panel == null:
		return
	var width := maxf(STAGE.x, size.x)
	var extent := Vector2(minf(1080.0, width - 160.0), STAGE.y - 70.0)
	_modal_panel.position = Vector2((width - extent.x) * 0.5, 35.0)
	_modal_panel.size = extent
	_modal_panel.custom_minimum_size = extent


## 위 오른쪽 [기록 백업/복구]. 누르면 링크 복사·코드 입력 팝업을 연다.
## 링크를 눌러 접속하기만 하면 기록이 이어진다 (PlayerSave.apply_url_params). 코드 입력은 보조 수단.
func _build_save_tools() -> void:
	var backup: Button = LobbyTheme.small_button("기록 백업/복구", _toggle_save_popup, &"teal", 17)
	backup.name = "SaveBackup"
	backup.clip_text = true
	backup.icon = MetaIcon.law_icon()
	backup.add_theme_constant_override("h_separation", 10)
	for state: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		backup.add_theme_color_override(state, Color.WHITE)
	_place(backup, Vector2(1062, 30), Vector2(280, 46))
	_save_popup = PanelContainer.new()
	_save_popup.name = "SavePopup"
	_save_popup.z_index = 20
	_save_popup.add_theme_stylebox_override("panel", LobbyTheme.style(LobbyTheme.MINT, LobbyTheme.TEAL, 3, 18, 8, 12))
	_save_popup.visible = false
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_save_popup.add_child(column)
	var link: Button = LobbyTheme.small_button("내 전용 링크 복사", _copy_share_link, &"teal", 17)
	link.name = "CopyShareLink"
	link.clip_text = true
	link.custom_minimum_size = Vector2(380, 44)
	column.add_child(link)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	_code_field = LineEdit.new()
	_code_field.name = "ShortCodeField"
	_code_field.placeholder_text = "4BGC-A51F"
	_code_field.max_length = 40
	_code_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_field.custom_minimum_size = Vector2(0, 40)
	MobileSupport.attach_native_text_input(_code_field, "기록 코드")
	_code_field.add_theme_font_size_override("font_size", 16)
	_code_field.text_submitted.connect(func(text: String) -> void: apply_save_code(text))
	row.add_child(_code_field)
	var apply: Button = LobbyTheme.small_button("코드 입력", func() -> void: apply_save_code(_code_field.text), &"blue", 15)
	apply.name = "ApplyShortCode"
	apply.custom_minimum_size = Vector2(110, 40)
	row.add_child(apply)
	_save_notice = Label.new()
	_save_notice.name = "SaveNotice"
	_save_notice.add_theme_font_size_override("font_size", 14)
	_save_notice.add_theme_color_override("font_color", LobbyTheme.INK)
	_save_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_save_notice.custom_minimum_size = Vector2(380, 0)
	_save_notice.visible = false
	column.add_child(_save_notice)
	_place(_save_popup, Vector2(936, 80), Vector2(406, 0))


func _toggle_save_popup() -> void:
	_save_popup.visible = not _save_popup.visible
	if _save_popup.visible:
		_save_popup.reset_size()


## 팝업 안내 줄: 비어 있으면 숨겨 팝업 밑이 비지 않게 한다.
func _set_notice(text: String) -> void:
	_save_notice.text = text
	_save_notice.visible = text != ""
	_save_popup.reset_size()


## [내 기록 전용 링크 복사]: ?s=짧은코드&n=닉네임 링크를 클립보드에 넣는다.
func _copy_share_link() -> void:
	MetaIcon.copy_to_clipboard(PlayerSave.share_url())
	_set_notice("링크를 복사했어요! 누르기만 하면 이어져요 (%s)" % PlayerSave.short_code())


## 짧은 코드(4BGC-A51F, 닉네임#4BGC-A51F)나 예전 긴 코드를 불러온다: 성공하면 #태그·닉네임·도장이 바로 바뀐다. 성공하면 true.
func apply_save_code(code: String) -> bool:
	if code.strip_edges().is_empty():
		return false
	if not PlayerSave.import_any(code):
		_set_notice("코드를 확인해 주세요 (예: 4BGC-A51F)")
		return false
	GameSession.reload_from_save()
	_set_notice("기록을 불러왔어요 (#%s)" % GameSession.player_tag())
	if _code_field != null:
		_code_field.text = ""
	if not _content.is_empty():
		_content = _chapter(spread)
		_rebuild_tiles()
		_refresh_head()
	records_imported.emit()
	return true


# ---------------------------------------------------------------------------
# 입력: 끌어서 스크롤, 상세 창 바깥 누르면 닫기, 키보드
# ---------------------------------------------------------------------------

func _inside(control: Control, point: Vector2) -> bool:
	return control.is_visible_in_tree() and Rect2(Vector2.ZERO, control.size).has_point(control.get_global_transform_with_canvas().affine_inverse() * point)


func _modal_open() -> bool:
	return _modal != null and _modal.visible


func _scroll_at(point: Vector2) -> ScrollContainer:
	if _save_popup != null and _save_popup.visible:
		return null
	var panes: Array = [_detail_scroll] if _modal_open() else [_right_scroll, _list_scroll]
	for scroll: ScrollContainer in panes:
		if not _inside(scroll, point):
			continue
		if _inside(scroll.get_v_scroll_bar(), point):
			return null  # 스크롤 막대는 원래대로 쓴다
		return scroll
	return null


func _clear_scroll_drag() -> void:
	_drag_scroll = null
	_drag_entry = -1
	_drag_finger = -1
	_drag_moved = false


## 스크롤 칸 안의 누름은 도감이 직접 맡는다: 끌면 스크롤만 하고(카드가 열리지 않는다), 움직이지 않고 떼면 그 카드를 연다.
## 상세 창이 떠 있으면 창 바깥을 눌렀다 떼면 닫는다 (뒤 화면은 눌리지 않는다).
func _input(event: InputEvent) -> void:
	if event is InputEventKey and MobileSupport.text_input_active(self):
		return
	var point: Vector2
	var pressed := false
	var released := false
	var motion := false
	var finger := -1
	if event is InputEventScreenTouch:
		point = event.position
		finger = event.index
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenDrag:
		point = event.position
		finger = event.index
		motion = true
	elif event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		point = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseMotion:
		point = event.position
		motion = true
	else:
		return
	if _dismiss_finger != -2:
		if finger == _dismiss_finger and released:
			var dismiss := not _inside(_modal_panel, point)
			if event is InputEventScreenTouch and event.canceled:
				dismiss = false
			_dismiss_finger = -2
			if dismiss:
				show_entry(-1)
		get_viewport().set_input_as_handled()
		return
	if _modal_open() and not _inside(_modal_panel, point) and _drag_scroll == null:
		if pressed:
			_dismiss_finger = finger
		get_viewport().set_input_as_handled()
		return
	if _drag_scroll != null and finger != _drag_finger:
		get_viewport().set_input_as_handled()
		return
	if pressed:
		var scroll := _scroll_at(point)
		if scroll == null:
			return
		_drag_scroll = scroll
		_drag_finger = finger
		_drag_start = point
		_drag_top = scroll.scroll_vertical
		_drag_entry = -1
		_drag_moved = false
		if scroll == _right_scroll and is_catalog():
			for index: int in _tiles.size():
				if _inside(_tiles[index], point):
					_drag_entry = index
					break
		elif scroll == _list_scroll:
			for index: int in _list_buttons.size():
				if _inside(_list_buttons[index], point):
					_drag_entry = index
					break
	elif _drag_scroll != null:
		if motion:
			var distance := point - _drag_start
			var screen_distance := get_viewport().get_screen_transform().basis_xform(distance)
			if screen_distance.length() > 8.0:
				_drag_moved = true
			if _drag_moved:
				var local_distance := _drag_scroll.get_global_transform_with_canvas().affine_inverse().basis_xform(distance)
				_drag_scroll.scroll_vertical = _drag_top - roundi(local_distance.y)
		elif released:
			var scroll := _drag_scroll
			var pick := _drag_entry
			var moved := _drag_moved
			_clear_scroll_drag()
			var canceled: bool = event is InputEventScreenTouch and event.canceled
			if not moved and not canceled:
				if scroll == _list_scroll and pick >= 0 and _inside(_list_buttons[pick], point):
					show_spread(pick)
				elif scroll == _right_scroll and pick >= 0 and pick < _tiles.size() and _inside(_tiles[pick], point):
					show_entry(pick)
				elif not moved:
					_click_through(scroll, point)
	else:
		return
	get_viewport().set_input_as_handled()


## 스크롤 칸 안의 다른 버튼(상세 창의 보드 넘기기 등)은 움직이지 않고 뗐을 때 눌린 것으로 친다.
func _click_through(scroll: ScrollContainer, point: Vector2) -> void:
	for node: Node in scroll.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button.is_visible_in_tree() and not button.disabled and _inside(button, point):
			button.pressed.emit()
			return


## 뒤 화면을 흐리게 번지게 하고 어둡게 덮는 셰이더 (색의 알파가 어두운 정도).
static func _blur_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * 3.0;
	vec3 sum = vec3(0.0);
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			sum += texture(screen_texture, SCREEN_UV + vec2(float(x), float(y)) * px).rgb;
		}
	}
	COLOR = vec4(mix(sum / 25.0, vec3(0.0), COLOR.a), 1.0);
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


## 키보드: 좌우는 상세 창이 떠 있으면 이전·다음 항목, 아니면 이전·다음 장. 위아래는 장. Esc는 창 → 도감 순서로 닫는다.
func _unhandled_key_input(event: InputEvent) -> void:
	if MobileSupport.text_input_active(self):
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_RIGHT:
			if _modal_open(): _step_entry(1)
			else: show_spread(spread + 1)
		KEY_LEFT:
			if _modal_open(): _step_entry(-1)
			else: show_spread(spread - 1)
		KEY_DOWN: show_spread(spread + 1)
		KEY_UP: show_spread(spread - 1)
		KEY_ESCAPE:
			if _modal_open(): show_entry(-1)
			else: close()
		_: return
	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# 장 바꾸기
# ---------------------------------------------------------------------------

## 장을 연다. entry_index를 주면 그 항목을 바로 연다 (도감은 상세 창, 기본 규칙은 그 칸으로 스크롤).
func show_spread(index: int, entry_index: int = -1) -> void:
	if not is_node_ready():
		# 아직 트리에 붙기 전 (부모가 화면 밖): 붙으면 연다
		ready.connect(show_spread.bind(index, entry_index), CONNECT_ONE_SHOT)
		return
	_dismiss_finger = -2
	_clear_scroll_drag()
	spread = clampi(index, 0, spread_count() - 1)
	_content = _chapter(spread)
	entry = -1
	showing_overview = false
	_modal.visible = false
	_rebuild_tiles()
	_refresh_head()
	_right_scroll.scroll_vertical = 0
	for index2: int in _list_buttons.size():
		_paint_list_button(_list_buttons[index2], index2 == spread)
	if entry_index >= 0:
		show_entry(entry_index)


func _paint_list_button(button: Button, selected: bool) -> void:
	var back := VISUALS.panel(Color("fffdf2") if selected else TEAL, 18)
	button.add_theme_stylebox_override("normal", back)
	var hover: StyleBoxTexture = back.duplicate()
	hover.modulate_color = Color.WHITE if selected else TEAL.lightened(0.15)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", back)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var plate: Label = button.get_node("Plate")
	plate.add_theme_color_override("font_color", TEAL_DARK if selected else Color.WHITE)
	plate.add_theme_color_override("font_outline_color", Color(0.1, 0.35, 0.3, 0.9))
	plate.add_theme_constant_override("outline_size", 0 if selected else 5)


## 장 머리: 제목, 한 줄 설명, (도감) [기본 설명] 버튼, (법전) 수집 수.
func _refresh_head() -> void:
	_chapter_title.text = str(_content.get("title", ""))
	_chapter_intro.text = L10n.t(_plain(str(_content.get("intro", ""))))
	_overview_button.visible = is_catalog() and not (_content.get("overview", {}) as Dictionary).is_empty()
	_collection_chip.visible = spread == LAW_SPREAD
	if spread == LAW_SPREAD:
		_collection_chip.text = L10n.tf("수집 %d/%d", [PlayerSave.law_count(), LawRegistry.ALL_IDS.size()])


## BBCode 강조([b]…[/b] 등)를 뗀 맨 글.
static func _plain(text: String) -> String:
	var regex := RegEx.create_from_string("\\[/?[a-z]+(=[^\\]]*)?\\]")
	return regex.sub(text, "", true)


func _rebuild_tiles() -> void:
	for child: Node in _right_holder.get_children():
		_right_holder.remove_child(child)
		child.queue_free()
	_tiles.clear()
	if is_catalog():
		_build_catalog_grid()
	else:
		_build_article()


# ---------------------------------------------------------------------------
# 기본 규칙: 읽는 쪽 (장 설명 칸 + 항목 칸을 위에서 아래로, 모두 펼친 채)
# ---------------------------------------------------------------------------

func _build_article() -> void:
	var overview: Dictionary = _content.get("overview", {})
	if not overview.is_empty():
		_right_holder.add_child(_section(overview, true))
	var entries: Array = _content.get("entries", [])
	# 항목 칸은 두 줄로 (넓은 화면에서 한 줄이 너무 길지 않게)
	var grid := GridContainer.new()
	grid.name = "EntryGrid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for data: Dictionary in entries:
		var section: Control = _section(data, false)
		section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(section)
		_tiles.append(section)
	_right_holder.add_child(grid)


## 읽는 쪽의 칸 하나: 왼쪽 그림, 오른쪽 제목·꼬리표·요약, 그 아래 표·요점·꿀팁.
func _section(data: Dictionary, wide: bool) -> Control:
	var tone: Color = data.get("tone", Color("5fc1e8"))
	var panel := PanelContainer.new()
	panel.name = "Section_" + str(data.get("title", ""))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _box(Color("fffdf6"), tone.lightened(0.25), 3, 20, 0, 16))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	column.add_child(_hero(data, Vector2(110, 110) if wide else Vector2(84, 84), 24 if wide else 21))
	for node: Control in _body(data):
		column.add_child(node)
	return panel


# ---------------------------------------------------------------------------
# 도감: 카드 격자 (그림 + 이름 + 한 줄 요약). 누르면 상세 창.
# ---------------------------------------------------------------------------

func _grid_columns() -> int:
	var width: float = _right_scroll.size.x if _right_scroll.size.x > 100.0 else _book.size.x - 44.0
	return clampi(int(width / 270.0), 2, 5)


func _build_catalog_grid() -> void:
	var grid := GridContainer.new()
	grid.name = "EntryGrid"
	grid.columns = _grid_columns()
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var entries: Array = _content.get("entries", [])
	for index: int in entries.size():
		var card: Button = _entry_card(entries[index])
		card.pressed.connect(show_entry.bind(index))
		grid.add_child(card)
		_tiles.append(card)
	_right_holder.add_child(grid)


## 도감 카드: 왼쪽 그림, 오른쪽 이름(한 줄)과 한 줄 요약(두 줄까지, 넘치면 말줄임).
func _entry_card(data: Dictionary) -> Button:
	var tone: Color = data.get("tone", Color("5fc1e8"))
	var button := Button.new()
	button.name = "Entry_" + str(data["title"])
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(220, CARD_H)
	button.tooltip_text = _plain(str(data.get("brief", data.get("summary", ""))))
	var normal := _box(tone.lightened(0.8), tone.lightened(0.1), 3, 18, 0, 0)
	var hover := _box(Color.WHITE, tone, 3, 18, 4, 0, Color(0, 0, 0, 0.18))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -12
	row.offset_top = 12
	row.offset_bottom = -12
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	var art_extent := Vector2(CARD_ART, CARD_ART)
	var art: Control = _card_picture(data, art_extent, tone)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(art)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 4)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	var name_label := _label(str(data["title"]), 19, Color("3a2a18"))
	name_label.name = "EntryName"
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size = Vector2(60, 0)
	_shrink_to_fit(name_label, 19, 12)
	texts.add_child(name_label)
	var brief := _label(_plain(str(data.get("brief", data.get("summary", "")))), 15, Color("6b5a40"))
	brief.name = "EntryBrief"
	brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief.max_lines_visible = 2
	brief.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	brief.set_meta("ellipsis_ok", true)  # 두 줄에서 일부러 자른다 (전체 문장은 툴팁·상세 창)
	brief.custom_minimum_size = Vector2(60, 0)
	texts.add_child(brief)
	# 특수 승리 법전으로 졸업해 본 교칙: 작은 [달성 ★] 도장 (영구 기록)
	if data.has("law_id") and PlayerSave.has_law(str(data["law_id"])):
		var stamp := _label("달성 완료 ★", 13, Color("8a3a0a"))
		stamp.name = "CollectionStamp"
		stamp.add_theme_stylebox_override("normal", _box(Color("ffe48a"), Color("e0a23a"), 2, 10, 0, 4))
		stamp.position = Vector2(8, 6)
		button.add_child(stamp)
	if bool(data.get("risk", false)):
		var warn := _label("주의", 13, Color.WHITE)
		warn.name = "RiskBadge"
		warn.add_theme_stylebox_override("normal", _box(Color("d6336c"), Color("a61e4d"), 2, 10, 0, 4))
		warn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
		button.add_child(warn)
	return button


## 카드·상세의 그림: 둥근 네모 판에 담는다 (카드 그림이면 손패 카드 앞면 그림 그대로).
func _card_picture(data: Dictionary, extent: Vector2, tone: Color) -> Control:
	return _rounded_art(_picture(data, extent), extent, int(extent.x * 0.2), tone)


# ---------------------------------------------------------------------------
# 상세 창
# ---------------------------------------------------------------------------

## 도감 카드 하나를 상세 창으로 연다. -1이면 닫는다. 기본 규칙 장이면 그 칸으로 스크롤만 한다.
func show_entry(index: int) -> void:
	_dismiss_finger = -2
	_clear_scroll_drag()
	var entries: Array = _content.get("entries", [])
	entry = clampi(index, -1, entries.size() - 1)
	showing_overview = false
	if not is_catalog():
		_modal.visible = false
		if entry >= 0 and entry < _tiles.size():
			_scroll_to(_tiles[entry])
		return
	if entry == -1:
		_modal.visible = false
		return
	_open_detail(entries[entry])


## 도감 장의 [기본 설명]: 장 설명(overview)을 상세 창으로.
func show_overview() -> void:
	var overview: Dictionary = _content.get("overview", {})
	if overview.is_empty():
		return
	entry = -1
	showing_overview = true
	_open_detail(overview)


func _step_entry(delta: int) -> void:
	if not _modal_open() or entry_count() == 0:
		return
	if showing_overview:
		show_entry(0 if delta > 0 else entry_count() - 1)
		return
	show_entry(wrapi(entry + delta, 0, entry_count()))


func _scroll_to(target: Control) -> void:
	await get_tree().process_frame
	if is_instance_valid(target) and is_instance_valid(_right_scroll):
		_right_scroll.ensure_control_visible(target)


func _open_detail(data: Dictionary) -> void:
	for child: Node in _detail_holder.get_children():
		_detail_holder.remove_child(child)
		child.queue_free()
	for child: Node in _variant_row.get_children():
		_variant_row.remove_child(child)
		child.queue_free()
	_detail_title.text = str(data["title"])
	_detail_holder.add_child(_hero(data, HERO, 0))
	for node: Control in _body(data):
		_detail_holder.add_child(node)
	var many: bool = entry_count() > 1
	_prev_button.visible = many
	_next_button.visible = many
	_detail_count.text = "" if showing_overview else "%d / %d" % [entry + 1, entry_count()]
	if data.has("augment") and _has_board_variant(AugmentRegistry.get_def(data["augment"])):
		_build_variant_row(data)
	_detail_scroll.scroll_vertical = 0
	_layout_modal()
	_modal.visible = true
	_stage.move_child(_modal, -1)
	if _save_popup != null:
		_stage.move_child(_save_popup, -1)


## 보드마다 바뀌는 특수 승리(식권 → 보드별 교칙): 보드 이름 버튼으로 다른 보드의 판을 본다.
func _build_variant_row(data: Dictionary) -> void:
	var shown: int = _shown_variant_board(data)
	for index: int in BoardCatalog.ids().size():
		var board_id: StringName = BoardCatalog.ids()[index]
		var button: Button = _pill_button(BoardCatalog.name_of(board_id), index == shown)
		button.pressed.connect(_show_variant.bind(data, index))
		button.name = "Variant_%s" % board_id
		button.tooltip_text = L10n.t("%s 보기" % BoardCatalog.name_of(board_id))
		_variant_row.add_child(button)


## 고른 것만 진한 청록으로 채운 알약 버튼 (보드별 판 고르기).
func _pill_button(text: String, selected: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 38)
	button.add_theme_font_size_override("font_size", 15)
	var fill: Color = Color("2f8f80") if selected else Color("fffdf2")
	var ink: Color = Color.WHITE if selected else TEAL_DARK
	for state: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, ink)
	button.add_theme_stylebox_override("normal", _box(fill, Color("2f8f80"), 2, 19, 0, 12))
	button.add_theme_stylebox_override("hover", _box(fill.lightened(0.1) if selected else Color("e3f6ef"), Color("2f8f80"), 2, 19, 0, 12))
	button.add_theme_stylebox_override("pressed", _box(fill.darkened(0.1), Color("2f8f80"), 2, 19, 0, 12))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


## 상세 창의 보드 버튼: 그 보드의 판 문구·그림으로 이 항목을 바꿔 다시 그린다 (격자 카드도 같이 바뀐다).
func _show_variant(data: Dictionary, board_index: int) -> void:
	var count: int = BoardCatalog.ids().size()
	data["variant_step"] = wrapi(board_index - _current_board_index(), 0, count)
	data["variant_flipped"] = int(data["variant_step"]) != 0
	var law_id: String = str(data.get("law_id", ""))
	if law_id != "" and VictoryLaw.DEFS.has(law_id):
		VictoryLaw.preview_board = _shown_board_id(data)
		var law: VictoryLaw = LawRegistry.create(law_id) as VictoryLaw
		data["texture"] = AugmentArt.load_first(AugmentArt.law_candidates(law_id))
		data["title"] = law.law_name
		data["summary"] = law.condition_text()
		data["brief"] = law.condition_text()
		VictoryLaw.preview_board = &""
	var tile_index: int = (_content.get("entries", []) as Array).find(data)
	if tile_index != -1 and tile_index < _tiles.size():
		var old: Control = _tiles[tile_index]
		var fresh: Button = _entry_card(data)
		fresh.pressed.connect(show_entry.bind(tile_index))
		var parent: Node = old.get_parent()
		parent.add_child(fresh)
		parent.move_child(fresh, old.get_index())
		_tiles[tile_index] = fresh
		old.queue_free()
	_open_detail(data)


## 보드 넘기기: BoardCatalog의 보드 순서대로 돈다.
## 이 증강이 보드마다 바꿔 쓰는 특수 승리인가.
static func _has_board_variant(definition: AugmentDef) -> bool:
	return definition != null and definition.category == GameEnums.AugmentCategory.LAW_ENACT and VictoryLaw.has_board_variant(str(definition.payload))


## 지금 판의 보드 번호 (BoardCatalog 순서).
static func _current_board_index() -> int:
	return maxi(BoardCatalog.ids().find(BoardSpec.board_id), 0)


## 이 항목이 지금 보여 주는 보드 번호 (지금 보드판 설정 기준 + variant_step만큼 다음 보드).
static func _shown_variant_board(data: Dictionary) -> int:
	return (_current_board_index() + int(data.get("variant_step", 0))) % BoardCatalog.ids().size()


## 이 항목이 지금 보여 주는 보드 id.
static func _shown_board_id(data: Dictionary) -> StringName:
	return BoardCatalog.ids()[_shown_variant_board(data)]


## 항목에 보일 카드 정보: 다른 보드의 판을 보는 중이면 그 판 문구로 만든다 (끝나면 지금 보드 문구로 되돌린다).
static func _card_info_for_tile(definition: AugmentDef, data: Dictionary) -> Dictionary:
	if int(data.get("variant_step", 0)) == 0 or not _has_board_variant(definition):
		return MainBoard.augment_card_info(definition, null, 1)
	VictoryLaw.preview_board = _shown_board_id(data)
	AugmentRegistry.apply_board_variants()
	var info: Dictionary = MainBoard.augment_card_info(definition, null, 1)
	VictoryLaw.preview_board = &""
	AugmentRegistry.apply_board_variants()
	return info


# ---------------------------------------------------------------------------
# 항목 내용 부품: 머리(그림 + 꼬리표 + 요약)와 몸(그림판·표·요점·덧말·꿀팁)
# ---------------------------------------------------------------------------

## 머리: 왼쪽 큰 그림(카드면 카드 앞면), 오른쪽 제목(title_px > 0일 때)·꼬리표·요약.
func _hero(data: Dictionary, extent: Vector2, title_px: int) -> Control:
	var tone: Color = data.get("tone", Color("5fc1e8"))
	var hero := HBoxContainer.new()
	hero.name = "Hero"
	hero.add_theme_constant_override("separation", 16)
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if data.has("card") and title_px == 0:
		hero.add_child(_card_face(data["card"], CARD_FACE))
	else:
		hero.add_child(_card_picture(data, extent, tone))
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(side)
	if title_px > 0:
		var title := _label(str(data["title"]), title_px, Color("4a3520"))
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		side.add_child(title)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for chip_text: Variant in data.get("chips", []):
		chips.add_child(_chip(str(chip_text), tone))
	if chips.get_child_count() > 0:
		side.add_child(chips)
	var summary: RichTextLabel = _rich(str(data.get("summary", "")), 20 if title_px == 0 else 18, DARK_INK)
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_child(summary)
	return hero


func _body(data: Dictionary) -> Array[Control]:
	var tone: Color = data.get("tone", Color("5fc1e8"))
	var nodes: Array[Control] = []
	if data.has("extra"):
		nodes.append((data["extra"] as Callable).call() as Control)  # 볼 때마다 새로 만든다 (지운 노드를 다시 붙이지 않게)
	var rows: Array = data.get("rows", [])
	if not rows.is_empty():
		nodes.append(_table(rows, tone))
	for block: Dictionary in data.get("blocks", []):
		nodes.append(_block(block))
	var points: Array = data.get("points", [])
	if not points.is_empty():
		nodes.append(_points(points, tone))
	if data.has("note"):
		nodes.append(_rich("[color=#8a7a58]%s[/color]" % str(data["note"]), 16))
	if data.has("tip"):
		nodes.append(_tip(str(data["tip"])))
	return nodes


## 작은 묶음 (보드판의 고유 칸 설명 등): 그림 + 이름 + 요약, 아래 표.
func _block(block: Dictionary) -> Control:
	var tone: Color = block.get("tone", Color("5fc1e8"))
	var panel := PanelContainer.new()
	panel.name = "Block_" + str(block.get("title", ""))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _box(tone.lightened(0.85), tone.lightened(0.2), 2, 18, 0, 14))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	column.add_child(_hero(block, Vector2(72, 72), 21))
	var rows: Array = block.get("rows", [])
	if not rows.is_empty():
		column.add_child(_table(rows, tone))
	return panel


## 둥근 알약 모양의 작은 꼬리표 (종류·시점 등).
func _chip(text: String, tone: Color) -> Control:
	var chip := Label.new()
	chip.text = text
	chip.add_theme_font_size_override("font_size", 15)
	chip.add_theme_color_override("font_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = tone.darkened(0.15)
	style.set_corner_radius_all(9)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	chip.add_theme_stylebox_override("normal", style)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return chip


## 두 칸 표: 왼쪽은 색 꼬리표(조건·이름), 오른쪽은 결과. 행 하나는 [왼쪽, 오른쪽], [한 칸] 또는 [그림, 왼쪽, 오른쪽].
func _table(rows: Array, tone: Color) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _box(Color("fffdf6"), tone.lightened(0.2), 2, 14, 0, 10))
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
			icon_holder.add_child(_picture({"texture": row[0]} if row[0] is Texture2D else {"icon": &"face", "tone": tone}, Vector2(44, 44)))
			line.add_child(icon_holder)
			cells = row.slice(1)
		if cells.size() == 1:
			var whole: RichTextLabel = _rich(str(cells[0]), 16, DARK_INK)
			whole.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(whole)
		else:
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
			var value: RichTextLabel = _rich(str(cells[1]), 16, DARK_INK)
			value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(value)
		column.add_child(line)
		if row_index < rows.size() - 1:
			var rule := ColorRect.new()
			rule.color = Color(tone, 0.25)
			rule.custom_minimum_size = Vector2(0, 2)
			rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
			column.add_child(rule)
	return panel


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
		dot.custom_minimum_size = Vector2(12, 12)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.add_theme_stylebox_override("panel", VISUALS.disc(tone))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(dot)
		var text: RichTextLabel = _rich(str(point), 17)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(text)
		column.add_child(line)
	return column


## 카드 항목의 큰 그림: 게임 손패와 같은 카드 앞면.
func _card_face(card_id: StringName, extent: Vector2 = CARD_FACE) -> Control:
	var card: BaseCard = CardRegistry.get_card(card_id)
	var face := PanelContainer.new()
	face.custom_minimum_size = extent
	face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_theme_stylebox_override("panel", CardSkin.frame(card.category, false, 14))
	face.add_child(CardSkin.body(card, extent, MainBoard.card_summary(card_id), MainBoard.category_label(card), true))
	return face


## 일러스트를 둥근 네모로 잘라 담는다: 둥근 판(clip_children)이 그림의 모서리를 가리고, 같은 둥글기의 외곽선을 덧그린다.
static func _rounded_art(picture: Control, extent: Vector2, radius: int, tone: Color) -> Control:
	var holder := Control.new()
	holder.name = "RoundedArt"
	holder.custom_minimum_size = extent
	holder.size = extent
	holder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mask := Panel.new()
	mask.name = "Mask"
	var mask_style := StyleBoxFlat.new()
	mask_style.bg_color = tone.lightened(0.72)
	mask_style.set_corner_radius_all(radius)
	mask_style.anti_aliasing = true
	mask.add_theme_stylebox_override("panel", mask_style)
	mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW  # 둥근 판 모양대로만 그림이 보인다
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(mask)
	var inset: float = 0.0
	var art: TextureRect = picture as TextureRect
	if art != null and art.texture != null:
		var ratio: float = float(art.texture.get_width()) / maxf(float(art.texture.get_height()), 1.0)
		if absf(ratio - 1.0) < 0.12 and not _is_cutout(art.texture):
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED  # 배경까지 그린 정사각 일러스트는 칸을 빈틈없이 채운다
		elif ratio > 1.25 and not _is_cutout(art.texture):
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED  # 가로로 긴 미리보기 그림도 칸을 채운다
		else:
			inset = extent.x * 0.1  # 배경이 투명한 오려 낸 그림은 외곽선에 닿지 않게 살짝 안쪽
	picture.custom_minimum_size = Vector2.ZERO
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	picture.offset_left = inset
	picture.offset_top = inset
	picture.offset_right = -inset
	picture.offset_bottom = -inset
	mask.add_child(picture)
	var outline := Panel.new()
	outline.name = "Outline"
	outline.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0), tone, 3, radius))
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
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		AugmentArt.apply_texture_style(image, texture, false)
		image.custom_minimum_size = extent
		image.size = extent
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return image
	if ART.has(data.get("art", &"")) or VISUALS.has(data.get("art", &"")):
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


## BBCode 문단 (갈색 잉크). [b]굵게[/b]는 형광펜 띠로 강조한다 (글꼴에 굵은체가 없어 뭉개지므로).
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
	label.custom_minimum_size = Vector2(200, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text.replace("[b]", "[bgcolor=#ffe45c99]").replace("[/b]", "[/bgcolor]")
	return label


## 노란 쪽지 팁 상자.
func _tip(text: String) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color("fff0b8"), Color("e0b23a"), 2, 12, 0, 10))
	panel.add_child(_rich("[b]꿀팁[/b]  " + text, 17))
	return panel


## 장 내용. 항목 목록의 첫 항목은 그 장의 설명(overview)으로 뺀다 (기본 규칙은 맨 위 큰 칸, 도감은 [기본 설명] 창).
## intro는 장 머리의 한 줄 설명 (없으면 overview 요약).
func _chapter(index: int) -> Dictionary:
	var content: Dictionary
	match index:
		0: content = _ch_start()
		1: content = _ch_turn()
		2: content = _ch_capture()
		3: content = _ch_tiles()
		4: content = _ch_boards()
		5: content = _ch_tools()
		6: content = _ch_pawns()
		7: content = _ch_cards()
		8: content = _ch_laws()
		9: content = _ch_general()
		_: content = _ch_super()
	var entries: Array = content["entries"]
	content["overview"] = entries.pop_front()
	if not content.has("intro"):
		content["intro"] = (content["overview"] as Dictionary).get("summary", "")
	return content
func _ch_start() -> Dictionary:
	return {"title": "시작하기", "entries": [
		{"title": "한눈에 보기", "art": &"start", "tone": Color("86d94f"), "chips": ["2~4인", "한 바퀴 레이스"],
			"summary": "말 [b]4개를 모두[/b] 결승선(0번)에 먼저 넣는 레이스예요.",
			"rows": [["이기는 법", "말 4개 완주 → 먼저 해낸 순서로 1·2·3위"], ["특수 승리", "법전의 조건을 라운드 끝까지 채우면 졸업"], ["손패", "생떼 카드 최대 7장"], ["출발", "말 4개 모두 출발선(0번)에서"]],
			"tip": "처음이라면 [b]놀이터[/b]에서 컴퓨터와 한 판 해 보세요."},
		{"title": "완주와 순위", "art": &"finish", "tone": Color("86d94f"),
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
			"points": ["카드는 빵집·증강에서 얻어요", "법전 조건은 내 차례가 끝날 때 달성해 있으면 특수 승리!"]},
	]}


func _ch_turn() -> Dictionary:
	var dash: String = _join_tiles(BoardSpec.dash_tiles)
	return {"title": "한 턴", "entries": [
		{"title": "한눈에 보기", "art": &"turn", "tone": Color("86d94f"), "chips": ["4단계"],
			"summary": "한 턴은 [b]카드 → 굴리기 → 말 고르기 → 정산[/b] 순서예요.",
			"rows": [["① 카드", "굴리기 전에 한 장 (안 써도 돼요)"], ["② 굴리기", "도구를 굴려 칸 수 결정"], ["③ 말 고르기", "그 칸 수만큼 움직일 말 선택"], ["④ 정산", "도착한 칸의 효과가 터져요"]],
			"tip": "카드는 [b]굴리기 전에만[/b] 낼 수 있어요. 눈금을 보고 고민하려면 아껴 두세요."},
		{"title": "카드 한 장", "art": &"play_card", "number": 1, "tone": Color("f0c14e"), "chips": ["굴리기 전", "턴당 1장"],
			"summary": "카드를 [b]보드판 위로 끌어다 놓으면[/b] 발동해요.",
			"points": ["함정·소환은 놓은 뒤 칸을 골라요", "방어 카드는 끌어 쓰지 않아요 (공격받을 때 팝업)"]},
		{"title": "굴리기", "art": &"roll", "number": 2, "tone": Color("86d94f"), "chips": ["스페이스"],
			"summary": "[b]굴리기[/b] 버튼을 꾹 눌러 파워를 모으고 손을 떼요.",
			"points": ["룰렛은 원판을 잡아 돌리고, 리볼버는 방아쇠를 당겨요"]},
		{"title": "말 고르기", "art": &"choose_pawn", "number": 3, "tone": Color("5fc1e8"),
			"summary": "아래 말 카드나 보드 위의 말을 누르면 그 말이 움직여요.",
			"points": ["카드에 도착 결과가 미리 보여요 (잡기·빵집·워프…)"]},
		{"title": "정산", "art": &"resolve", "number": 4, "tone": Color("f08aa8"),
			"summary": "도착한 칸의 효과가 터져요. 공격받으면 방어 카드로 받아칠지 물어봐요.",
			"points": ["빵집이면 카드 1장, 옷장이면 순간이동", "적 말 위에 멈추면 잡기!"]},
		{"title": "보너스 이동", "art": &"bonus", "tone": Color("63e6be"), "chips": ["후퇴 없음"],
			"summary": "말은 절대 뒤로 가지 않아요. 대신 여러 보너스로 앞으로 튀어 나가요.",
			"rows": [["복수 부스터", "출발선으로 날아간 말이 다시 나올 때 +4칸"], ["부스터 발판", "%s번에 딱 멈추면 +3칸" % dash], ["재굴림", "윷말은 적을 잡으면 한 번 더"]]},
		{"title": "증강 라운드", "art": &"augment_round", "tone": Color("ffa94d"), "chips": ["3라운드마다"],
			"summary": "1·4·7라운드처럼 [b]3라운드마다[/b] 모두가 3장 중 하나를 골라요.",
			"points": ["1라운드는 기물 진화, 4라운드는 판정 도구·카드·기물 진화", "템포 업 1단계부터 고급 증강(법전), 2단계부터 초증강도 등장", "카드마다 한 번 다시 뽑기", "자세한 건 [b]도감 → 법전[/b]"]},
		{"title": "템포 업", "art": &"tempo", "tone": Color("ff6b6b"), "chips": ["8·14·20라운드"],
			"summary": "판이 길어지면 [b]게임이 점점 빨라져요[/b]. 단계가 오르는 라운드 시작 전에 크게 경고해요.",
			"rows": [["8라운드 · 과열", "차례 첫 이동 +1칸 · 리벤지 +6칸 · 초증강 확률 상승 · 법전이 비어 있으면 1개 자동 제정"], ["14라운드 · 광기", "차례 첫 이동 +2칸 · 리벤지 +8칸 · 법전 확률 상승"], ["20라운드 · 대붕괴", "전원 차례 첫 이동 +3칸"]],
			"points": ["결승선은 [범용] 결승선 당기기를 쓸 때만 당겨져요 (체크무늬 칸)", "25라운드가 끝나면 남은 사람은 진행 순위로 순위 확정"]},
	]}


## 특수 칸: 모든 보드판에 공통인 칸 (출발·코너·반환점·부스터 발판·함정). 보드마다 다른 칸은 도감 → 보드판.
func _ch_tiles() -> Dictionary:
	var make_board: Callable = func() -> Control:
		return _board_panel(BoardSpec.board_id)
	var kinds: Array = []
	for board: Dictionary in BoardCatalog.BOARDS:
		var names: PackedStringArray = []
		for kind_id: StringName in BoardCatalog.board_kinds(board["id"]):
			names.append(str(BoardCatalog.tile_kind(kind_id)["name"]))
		kinds.append([str(board["name"]), " · ".join(names)])
	return {"title": "특수 칸", "entries": [
		{"title": "한눈에 보기", "art": &"board", "tone": Color("86d94f"), "chips": ["%d칸" % BoardSpec.tile_count, "반시계"],
			"summary": "우하단 0번에서 출발해 반시계로 한 바퀴. 다시 0번이 [b]결승선[/b]이에요.", "extra": make_board,
			"points": ["특수 칸은 대부분 [b]딱 멈출 때만[/b] 작동해요", "그림은 지금 고른 보드판이에요"]},
		{"title": "코너", "art": &"corner", "tone": Color("2f8f4e"), "chips": [_join_tiles(BoardSpec.corner_tiles.slice(1)) + "번"],
			"summary": "딱 멈추면 [b]다음 굴림 결과 +1[/b]! 단, 이 칸에 함정이 있으면 버프 대신 함정이 발동해요.",
			"points": ["[b]코너 전용 함정[/b]만 설치할 수 있는 칸이에요"]},
		{"title": "반환점", "art": &"halfway", "tone": Color("c98a14"), "chips": ["%d번" % BoardSpec.halfway_tile],
			"summary": "여기를 지나면 체스 폰은 [b]퀸[/b]으로, 쇼기 말은 [b]승급[/b]해요."},
		{"title": "부스터 발판", "art": &"boost", "tone": Color("2fb59a"), "chips": [_join_tiles(BoardSpec.dash_tiles) + "번"],
			"summary": "딱 멈추면 [b]+3칸[/b] 더 날아가요."},
		{"title": "함정 칸", "texture": TextureCache.fetch("res://assets/board/traps/HIDDEN.png"), "tone": Color("7a5cd6"), "chips": ["한 칸에 하나"],
			"summary": "함정이 깔린 칸은 [b]보라색[/b]으로 바뀌고 그 함정 그림이 보여요.",
			"points": ["상대가 숨긴 함정은 물음표로 보여요", "코너 함정은 누구에게나 공개 · 3라운드 · 1회용", "코너·빵집·옷장·부스터 발판에는 일반 함정을 깔 수 없어요"]},
		{"title": "보드마다 다른 칸", "art": &"board", "tone": Color("5fc1e8"), "chips": ["빵집 자리 4곳", "옷장 자리 2곳"],
			"summary": "빵집 자리와 옷장 자리에는 [b]보드판마다 다른 칸[/b]이 서요.",
			"rows": kinds, "points": ["자세한 건 [b]도감 → 보드판[/b]"]},
	]}


## 보드판: 고를 수 있는 보드판마다 한 장 (미리보기 그림, 판 그림, 그 보드만의 칸 설명).
func _ch_boards() -> Dictionary:
	var entries: Array = [
		{"title": "보드판 고르기", "art": &"board", "tone": Color("5fc1e8"), "chips": ["%d종" % BoardCatalog.BOARDS.size()],
			"summary": "보드판마다 [b]빵집 자리·옷장 자리[/b]에 서는 칸이 달라요.",
			"points": ["컴퓨터 대전 시작 화면과 [방 규칙 설정]에서 고를 수 있어요", "판을 시작하면 모두 같은 보드판을 써요", "출발·코너·반환점·부스터 발판은 모든 보드판이 같아요 (기본 규칙 → 특수 칸)"]},
	]
	for board: Dictionary in BoardCatalog.BOARDS:
		var id: StringName = board["id"]
		var blocks: Array = []
		var kinds: Array[StringName] = BoardCatalog.board_kinds(id)
		var kind_names: Array = []
		for kind_id: StringName in kinds:
			blocks.append(_kind_block(kind_id, id))
			kind_names.append(str(BoardCatalog.tile_kind(kind_id)["name"]))
		var preview: String = "%s%s.webp" % [BOARD_PREVIEW_DIR, id]
		entries.append({"title": str(board["name"]), "texture": load(preview) if ResourceLoader.exists(preview) else null, "art": &"board", "tone": Color("5fc1e8"),
			"chips": ["%d칸" % int(board["tiles"])] + kind_names,
			"summary": str(board["desc"]), "brief": str(board["desc"]), "board_id": id,
			"extra": _board_panel.bind(id), "blocks": blocks})
	return {"title": "보드판", "entries": entries}


## 보드판 그림: 왼쪽 작은 판(번호·색 칸·옷장 이동선), 오른쪽 범례. 범례는 판 밖에 두어 이동선과 겹치지 않는다.
func _board_panel(board_id: StringName) -> Control:
	var row := HBoxContainer.new()
	row.name = "BoardPanel"
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var board := MiniBoard.new()
	board.board_id = board_id
	board.custom_minimum_size = Vector2(360, 360)
	board.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(board)
	var legend := VBoxContainer.new()
	legend.add_theme_constant_override("separation", 8)
	legend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legend.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for item: Array in MiniBoard.legend_of(board_id):
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var swatch := Panel.new()
		swatch.custom_minimum_size = Vector2(22, 22)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.add_theme_stylebox_override("panel", _box(item[0], (item[0] as Color).darkened(0.35), 2, 6))
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(swatch)
		var text: RichTextLabel = _rich(str(item[1]), 16, DARK_INK)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(text)
		legend.add_child(line)
	row.add_child(legend)
	return row


## 칸 종류 하나의 설명 묶음 (그 보드의 칸 번호 + 칸별 표: 워프·음료·물약·정령).
func _kind_block(kind_id: StringName, board_id: StringName) -> Dictionary:
	var kind: Dictionary = BoardCatalog.tile_kind(kind_id)
	var layout: Dictionary = BoardCatalog.layout_of(board_id)
	var book: Dictionary = kind["rulebook"]
	var block: Dictionary = {"title": str(kind["name"]), "art": book["art"], "tone": book["tone"],
		"chips": [_join_tiles(layout.get(str(kind.get("tiles_key", "bakery_tiles")), [])) + "번"], "summary": book["summary"]}
	match kind_id:  # 칸 종류별 상세 표 (그 칸의 규칙 데이터에서 만든다)
		&"portal": block["rows"] = _warp_rows(layout.get("portal_warp_targets", {}))
		&"vending": block["rows"] = _drink_rows()
		&"cauldron": block["rows"] = _potion_rows()
		&"spirit": block["rows"] = _spirit_rows()
	return block


func _spirit_rows() -> Array:
	var rows: Array = []
	for spirit: Dictionary in MountainSpirits.SPIRITS:
		rows.append([str(spirit["name"]), str(spirit["text"])])
	return rows


func _potion_rows() -> Array:
	var rows: Array = []
	for potion: Dictionary in WitchPotions.POTIONS:
		rows.append([str(potion["name"]), str(potion["text"])])
	return rows


func _drink_rows() -> Array:
	var rows: Array = []
	for drink: Dictionary in VendingDrinks.DRINKS:
		rows.append([str(drink["name"]), str(drink["text"])])
	return rows


func _warp_rows(targets: Dictionary) -> Array:
	var rows: Array = []
	for from_tile: int in targets.keys():
		rows.append(["%d번 옷장" % from_tile, "→ %d번으로" % int(targets[from_tile])])
	return rows


func _ch_capture() -> Dictionary:
	return {"title": "잡기", "entries": [
		{"title": "한눈에 보기", "art": &"capture", "tone": Color("f08aa8"),
			"summary": "적 말이 있는 칸에 [b]멈추면[/b] 그 말은 출발선으로 날아가요.",
			"rows": [["잡기", "멈춘 쪽이 잡아요 (스치기만 하면 안 잡혀요)"], ["출발선(0번)", "안전 지대: 잡을 수 없어요"], ["내 말끼리", "잡지 않아요"]],
			"tip": "완주 직전에 잡히면 억울해요. 선두 말은 적 앞을 조심!"},
		{"title": "말의 기본", "art": &"pawn_basics", "tone": Color("5fc1e8"), "chips": ["말 4개", "굴린 만큼 전진"],
			"summary": "내 말은 모두 [b]4개[/b]. 처음엔 전부 출발선(0번)에서 기다려요.",
			"rows": [["출발", "굴림 눈금만큼 한 말을 골라 내보내요"], ["이동", "눈금만큼 반시계로 한 칸씩 전진해요"], ["잡기", "적 말 위에 멈추면 그 말은 출발선으로"], ["잡히면", "출발선으로 돌아가 다시 출발해요 (리벤지 부스터 획득)"], ["완주", "0번에 닿으면 끝. 4개 모두 완주하면 순위 확정"]],
			"points": ["말마다 능력과 필살기가 달라요 ([b]도감 → 말[/b])", "보드 위 말에 마우스를 올리면 상태가 보여요"]},
		{"title": "공격 카드", "art": &"attack", "tone": Color("ff6b6b"), "chips": ["%d종" % MainBoard.ATTACK_CARDS.size(), "발동 경보"],
			"summary": "상대 말과 차례를 흔드는 카드예요. 쓰면 먼저 [b]공격 카드 발동![/b] 경보가 뜨고 어떤 카드인지 공개돼요.",
			"rows": _card_rows(MainBoard.ATTACK_CARDS),
			"tip": "공격은 상대가 [b]방어 카드[/b]로 막을 수 있어요."},
		{"title": "방어 카드", "art": &"defense", "tone": Color("74c0fc"), "chips": ["피격 시", "%d종" % _cards_of(GameEnums.CardCategory.COUNTER).size()],
			"summary": "내가 공격받으면 [b]방어 카드를 쓸지[/b] 팝업으로 물어봐요.",
			"rows": _card_rows(_cards_of(GameEnums.CardCategory.COUNTER)),
			"points": ["잡기·공격 카드·함정이 공격이에요", "그냥 맞기를 고르면 그 공격엔 다시 못 써요"]},
		{"title": "함정 카드", "art": &"trap_card", "tone": Color("b197fc"), "chips": ["칸에 깔기", "한 칸에 하나"],
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


## 카드 목록을 [이름, 한 줄 설명] 표로.
func _card_rows(card_ids: Array) -> Array:
	var rows: Array = []
	for card_id: Variant in card_ids:
		rows.append([CardRegistry.get_card(StringName(card_id)).display_name, _card_brief(StringName(card_id))])
	return rows


## 카드 한 줄 설명: 설명 앞의 [잡기 방어] 같은 머리표는 뗀다 (종류는 색·꼬리표로 보인다).
static func _card_brief(card_id: StringName) -> String:
	var line: String = MainBoard.card_summary(card_id).replace("\n", " ")
	for head: String in ["[방어] ", "[만능 방어] ", "[잡기 방어] ", "[공격 방어] ", "[함정 방어] "]:
		if line.begins_with(head):
			line = line.trim_prefix(head)
	return line


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
		var span: Array[int] = AugmentDef.tool_step_range(tool_id)
		if span.size() == 2:
			data["brief"] = "최소 %d칸 ~ 최대 %d칸" % [span[0], span[1]]
		entries.append(data)
	return {"title": "도구", "entries": entries}


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
		var brief: String = passive.split("\n")[0] if passive != "" else (PawnCatalog.skill_name(skill) if skill != &"" else "")
		entries.append({"title": PawnCatalog.unit_label(kind, unit).split(":")[-1], "augment": definition.augment_id, "texture": _pawn_texture(sub, kind), "icon": &"crown",
			"tone": Color("20c997"), "chips": chips, "summary": PAWN_LINES.get(kind, ""), "brief": brief, "rows": rows})
	return {"title": "말", "entries": entries}


## 전체 설명용: 계열마다 대표 그림 + 이름 + 한 줄 소개.
func _family_rows() -> Array:
	var rows: Array = []
	for kind: GameEnums.PawnKind in PawnCatalog.EVOLVABLE_SETS:
		rows.append([_pawn_texture(PawnCatalog.SUB_TYPES[kind][0], kind), PawnCatalog.display_set_name(kind), PAWN_LINES.get(kind, "")])
	return rows


## 계열 한 줄 소개.
const PAWN_LINES: Dictionary = {
	GameEnums.PawnKind.YUT: "잡으면 재굴림, 필살기는 주사위 한 번 더.",
	GameEnums.PawnKind.CHESS: "폰은 반환점에서 퀸으로 승급. 기물마다 움직임 보너스가 달라요.",
	GameEnums.PawnKind.JANGGI: "말을 넘고, 돌진하고, 땅을 흔드는 장기 기물.",
	GameEnums.PawnKind.MONOPOLY: "필살기 호텔·워프·카드로 판을 굴리는 모노폴리 말.",
	GameEnums.PawnKind.GO: "흑돌은 홀수 눈금 +1칸, 백돌은 방어막.",
	GameEnums.PawnKind.SHOGI: "반환점을 지나면 승급(나리)해 더 강해져요.",
	GameEnums.PawnKind.ARCADE: "킹 체커·루도·8번 공·스타 카트·지뢰찾기 공병.",
	GameEnums.PawnKind.TRPG: "전사·마법사·궁수·도적. 처치하면 레벨 업, 곧바로 추가 전진!",
	GameEnums.PawnKind.COLLECTIBLE: "코롯토, 치비구루미. 완주하면 수집 버프를 얻어요!",
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
		{"title": "카드 쓰는 법", "art": &"play_card", "tone": Color("f0c14e"), "chips": ["손패 최대 7장"],
			"summary": "빵집·증강에서 얻은 카드를 [b]보드판으로 끌어다 놓아[/b] 써요.",
			"rows": [["방어 (파랑)", "공격받으면 팝업에서 발동 여부를 물어봐요"], ["즉발 (노랑)", "굴리기 전에 바로 효과"], ["함정 (보라)", "칸을 골라 숨겨 깔기, 코너 전용 4종"], ["소환 (분홍)", "상단 코너에 1마리, 라운드마다 1~3칸 · 적을 잡으면 퇴장"]],
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
			"chips": [MainBoard.category_label(card), "%d장" % int(CardRegistry.DECK_COMPOSITION[card_id])],
			"summary": MainBoard.card_summary(card_id).replace("\n", " "), "brief": _card_brief(card_id),
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
	return {"title": "카드", "entries": entries}


func _ch_laws() -> Dictionary:
	var entries: Array = [
		{"title": "증강과 법전", "art": &"lawbook", "tone": Color("ffa94d"), "chips": ["3라운드마다", "법전 4칸"],
			"summary": "1·4·7라운드처럼 [b]3라운드마다[/b] 모두가 증강 3장 중 하나를 골라요. 법전의 교칙은 모두 [b]특수 승리 조건[/b]이에요.",
			"rows": [["기물 지급", "말 하나를 새 기물로 진화 (도감 → 말)"], ["도구 교체", "굴리는 도구 바꾸기 (도감 → 도구)"], ["특수 승리", "법전에 새 승리 조건 (3라운드부터)"], ["카드 패키지", "생떼 카드 여러 장 (도감 → 보급)"], ["범용 보급", "기물 변이 · 전군 돌연변이 · 필살기 리필 (도감 → 보급)"], ["초증강", "하이리스크 하이리턴 (도감 → 초증강)"]],
			"points": ["내 차례가 끝날 때 교칙 조건을 달성해 있으면 [b]특수 승리![/b] 그 교칙은 사라져요 (같은 교칙을 여럿이 채우면 레이스에서 앞선 한 명만). 단 [b]보드연성진[/b]은 조건 달성 후 다음 내 차례가 끝날 때까지 유지해야 해요", "새 교칙이 들어오면 가장 오래된 교칙이 밀려나요", "증강 카드마다 한 번 다시 뽑기"],
			"tip": "법전 슬롯에 마우스를 올리면 모두의 진행도가 보여요. [color=#d6336c][b][위험!][/b][/color] 표시를 견제하세요!"},
	]
	for definition: AugmentDef in _augments(GameEnums.AugmentCategory.LAW_ENACT):
		var law: VictoryLaw = LawRegistry.create(String(definition.payload)) as VictoryLaw
		if law == null:
			continue
		var counting: String = "법전에 있는 동안만 세요" if VictoryLaw.SESSION_KEYS.has(law.stat_key) else "게임 내내 쌓여요"
		entries.append({"title": law.law_name, "augment": definition.augment_id, "law_id": law.law_id, "texture": AugmentArt.load_first(AugmentArt.law_candidates(law.law_id)), "icon": &"book",
			"tone": Color("ffd43b"), "chips": ["목표 %d%s" % [law.goal(), law.unit()]], "summary": law.condition_text(), "brief": law.condition_text(),
			"rows": [["판정", "조건 달성 후 다음 내 차례가 끝날 때까지 유지하면 특수 승리! 교칙은 사라져요" if law.law_id == SpecialVictory.SIEGE_LAW else "내 차례가 끝날 때 조건을 달성해 있으면 특수 승리! 교칙은 사라져요"], ["기록", counting], ["이의 있음!", "기록을 0으로 되돌릴 수 %s" % ("있어요" if law.resettable() else "없어요")]]})
	return {"title": "법전", "entries": entries}


## 보급: 생떼 카드 패키지와 범용 보급.
func _ch_general() -> Dictionary:
	var entries: Array = [
		{"title": "보급 증강 분류", "art": &"supply", "tone": Color("74c0fc"), "chips": ["증강 라운드", "누구나"],
			"summary": "[b]색상과 분류 이름[/b]으로 효과를 구분해요.",
			"rows": [["패시브", "획득 후 유지되거나 조건에 따라 자동 발동"], ["즉발 발동", "증강 선택이 끝나면 보드·선택지에 바로 적용"], ["범용 보급", "기물 변이 · 전군 개조 · 필살기 재충전"], ["카드 보급", "생떼 카드를 손패에 추가"]],
			"points": ["필살기를 이미 쓴 기물이 있으면 리필이 이득이에요", "손패는 최대 장수를 넘으면 더 받지 못해요"]},
	]
	var supplies: Array[AugmentDef] = _augments(GameEnums.AugmentCategory.CARD_PACKAGE)
	supplies.append_array(_augments(GameEnums.AugmentCategory.UTILITY))
	for group: StringName in AugmentDef.SUPPLY_GROUPS:
		for definition: AugmentDef in supplies:
			if definition.display_group() == group:
				entries.append(_augment_entry(definition, &"gear"))
	return {"title": "보급", "entries": entries}


## 증강 카드 한 장을 도감 항목으로: 첫 줄은 요약, 나머지 ◆ 줄은 항목 점.
static func _augment_entry(definition: AugmentDef, icon: StringName) -> Dictionary:
	var info: Dictionary = MainBoard.augment_card_info(definition, null, 1)
	var lines: Array = str(info["desc"]).split("\n")
	return {"title": str(info["title"]), "augment": definition.augment_id, "texture": info.get("art"), "icon": icon, "tone": info["color"],
		"chips": [str(info["category"])], "summary": str(lines[0]).trim_prefix("◆ "), "brief": "\n".join(Array(lines).map(func(line: String) -> String: return line.trim_prefix("◆ "))), "points": lines.slice(1).map(func(line: String) -> String: return line.trim_prefix("◆ "))}


## 초증강: 하이리스크 하이리턴. 판을 한 번에 뒤집을 수 있지만 내게도 화살이 돌아올 수 있는 증강들.
func _ch_super() -> Dictionary:
	var entries: Array = [
		{"title": "하이리스크 하이리턴", "art": &"super", "tone": Color("ffd43b"), "chips": ["초증강", "%d종" % SuperAugments.ALL_IDS.size()],
			"summary": "초증강은 [b]판을 한 번에 뒤집는[/b] 증강이에요. 크게 얻는 대신 [b]내 말도 다칠 수 있어요[/b].",
			"rows": [["한 방", "판 뒤집기 · 저격수의 표적"], ["도박", "주사위 도박사 · 악마의 계약"], ["강탈", "도적단 대습격 · 빵집 털이 · 공산주의 재분배"], ["난장판", "폭주 기관차 · 강제 캐슬링 · 광란의 지뢰밭 · 강제 연대책임"], ["질주", "아우토반 니트로: 선두 말이 코너까지 직진, 길을 막은 칸은 전부 장외 사출"]],
			"points": ["폭주 기관차는 내 말도 가리지 않아요", "강제 연대책임은 선두와 꼴찌 말의 운명을 묶어요", "조건이 안 맞는 초증강은 드래프트에 나오지 않아요"],
			"tip": "질 것 같을 때가 초증강을 고를 때예요. [b]역전은 한 번이면 충분[/b]하니까요!"},
	]
	for definition: AugmentDef in _augments(GameEnums.AugmentCategory.SUPER_GAMBLE):
		var entry: Dictionary = _augment_entry(definition, &"star")
		if SuperAugments.SELF_RISK.has(StringName(str(definition.payload))):
			entry["rows"] = [["주의", SuperAugments.SELF_RISK_NOTE.trim_prefix("주의: ")]]
			entry["risk"] = true  # 도감 카드 오른쪽 위에 [주의]
		entries.append(entry)
	return {"title": "초증강", "entries": entries}


# ---------------------------------------------------------------------------
# 그림 부품
# ---------------------------------------------------------------------------

## 타일 번호 목록을 `4·10·14` 꼴로 이어 붙인다.
static func _join_tiles(tiles: Array) -> String:
	var parts: Array[String] = []
	for tile: Variant in tiles:
		parts.append(str(int(tile)))
	return "·".join(parts)


## 작은 보드판 그림: 보드 하나(board_id)의 배치(BoardCatalog.layout_of)를 사각 트랙으로 그리고 옷장 이동을 점선 화살표로 보여 준다.
## 칸 색은 칸 종류 데이터(legend_color)에서 읽는다. 범례는 legend_of로 따로 만든다 (판 안에 글을 쓰지 않는다).
class MiniBoard extends Control:
	const START := Color("86d94f")
	const CORNER := Color("b6ea8c")
	const HALFWAY := Color("ffe48a")
	const BOOST := Color("ffd3e2")
	const WARP_LINE := Color("2f9aa3")
	var board_id: StringName = &""

	func _layout() -> Dictionary:
		return BoardCatalog.layout_of(board_id if board_id != &"" else BoardSpec.board_id)

	## [색, 설명] 목록: 출발·코너·반환점·빵집 자리 칸·옷장 자리 칸·부스터 발판.
	static func legend_of(id: StringName) -> Array:
		var def: Dictionary = BoardCatalog.def_of(id)
		var layout: Dictionary = BoardCatalog.layout_of(id)
		var shop: Dictionary = BoardCatalog.tile_kind(def["shop"])
		var portal: Dictionary = BoardCatalog.PORTAL_KINDS.get(def["portal"], BoardCatalog.tile_kind(def["portal"]))
		var portal_text: String = str(portal["legend"])
		if bool(portal.get("warps", false)):
			var parts: Array[String] = []
			for from_tile: int in (layout.get("portal_warp_targets", {}) as Dictionary).keys():
				parts.append("%d → %d" % [from_tile, int(layout["portal_warp_targets"][from_tile])])
			portal_text = "%s (%s)" % [portal["name"], ", ".join(parts)]
		var items: Array = [[START, L10n.t("출발 · 결승")], [CORNER, L10n.t("코너 (코너 전용 함정)")], [HALFWAY, L10n.t("반환점 (승급 기준)")], [shop["legend_color"], L10n.t(str(shop["legend"]))]]
		if def["portal"] != def["shop"]:
			items.append([portal["legend_color"], L10n.t(portal_text)])
		return items + [[BOOST, L10n.tf("부스터 발판 (%s번, 딱 멈추면 +%d칸)", [Rulebook._join_tiles(layout["dash_tiles"]), GameEnums.DASH_STEPS])]]

	func _tile_pos(index: int) -> Vector2:
		var pad: float = size.x * 0.075
		return Vector2(pad, pad) + BoardLayout.tile_norm(index) * (size.x - pad * 2.0)

	func _fill_of(index: int, layout: Dictionary) -> Color:
		var def: Dictionary = BoardCatalog.def_of(board_id if board_id != &"" else BoardSpec.board_id)
		for slot: String in ["shop", "portal"]:
			var kind: Dictionary = BoardCatalog.tile_kind(def[slot])
			if (layout.get(str(kind.get("tiles_key", "bakery_tiles")), []) as Array).has(index):
				return kind["legend_color"]
		if (layout["dash_tiles"] as Array).has(index):
			return BOOST
		if index == 0:
			return START
		if index == int(layout["halfway_tile"]):
			return HALFWAY
		if (layout["corner_tiles"] as Array).has(index):
			return CORNER
		return Color("fffdf0")

	func _draw() -> void:
		var layout: Dictionary = _layout()
		draw_style_box(Rulebook.VISUALS.panel(Color("e8f5c8"), 22), Rect2(Vector2.ZERO, size))
		var font: Font = get_theme_default_font()
		var unit: float = size.x / 440.0
		var warps: Dictionary = layout.get("portal_warp_targets", {})
		for from_tile: int in warps.keys():
			_dashed(from_tile, int(warps[from_tile]), unit)
		for index: int in BoardSpec.tile_count:
			var center: Vector2 = _tile_pos(index)
			var corner: bool = (layout["corner_tiles"] as Array).has(index)
			var side: float = (44.0 if corner else 34.0) * unit
			var fill: Color = _fill_of(index, layout)
			draw_style_box(Rulebook.VISUALS.panel(fill, 9 if not corner else 12), Rect2(center - Vector2(side, side) / 2.0, Vector2(side, side)))
			var label: String = L10n.t("출발") if index == 0 else str(index)
			var px: int = int(round((15.0 if corner else 13.0) * unit))
			var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			draw_string(font, center + Vector2(-width / 2.0, px * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color("3a2f1f"))

	func _dashed(from_tile: int, to_tile: int, unit: float) -> void:
		var a: Vector2 = _tile_pos(from_tile)
		var b: Vector2 = _tile_pos(to_tile)
		draw_dashed_line(a, b, WARP_LINE, 3.5 * unit, 9.0 * unit, true)
		var dir: Vector2 = (b - a).normalized()
		var side: Vector2 = Vector2(-dir.y, dir.x)
		var tip: Vector2 = b - dir * 20.0 * unit
		draw_colored_polygon(PackedVector2Array([tip, tip - dir * 12.0 * unit + side * 7.0 * unit, tip - dir * 12.0 * unit - side * 7.0 * unit]), WARP_LINE)
