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
const VISUALS = preload("res://scenes/rulebook_visuals.gd")
const BOARD_PREVIEW_DIR: String = "res://assets/ui/trickcal/board_preview/"
const DARK_INK: Color = Color("3a2f1f")
## 법전 장 (도감 묶음의 법전 탭)과 보드판 장, 카드 장.
const LAW_SPREAD: int = 8
const BOARD_SPREAD: int = 4
const CARD_SPREAD: int = 7
const TAB_NAMES: Array[String] = ["시작하기", "한 턴", "잡기", "특수 칸", "보드판", "도구", "말", "카드", "법전", "보급", "초증강"]
const TAB_ART: Array[StringName] = [&"start", &"turn", &"capture", &"board", &"board", &"roll", &"pawn_ability", &"play_card", &"lawbook", &"supply", &"super"]
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
## 위쪽 두 탭이 묶는 장: 기본 규칙(0~3: 시작하기·한 턴·잡기·특수 칸), 도감(4~10: 보드판·도구·말·카드·법전·보급·초증강).
const GROUP_NAMES: Array[String] = ["기본 규칙", "도감"]
## 위쪽 탭(묶음)마다 첫 장의 번호: 기본 규칙 0~3, 도감 4~10.
const GROUP_STARTS: Array[int] = [0, 4]
const STAGE: Vector2 = Vector2(1366.0, 768.0)
## Leave breathing room beyond the painted frame and shadow, without resizing entries.
const BOOK_SHIFT_X := -24.0

## 현재 장 번호(0부터).
var spread: int = 0
var _stage: Control = null
var _left_holder: VBoxContainer = null
var _right_holder: Container = null
var _right_scroll: ScrollContainer = null
var _left_scroll: ScrollContainer = null
var _book_outer: Panel = null
var _drag_scroll: ScrollContainer = null
var _drag_start := Vector2.ZERO
var _drag_top := 0
var _drag_entry := -1
var _drag_variant_button: Button = null
var _drag_finger := -1
var _drag_moved := false
var _notebook_title: Label = null
var _list_buttons: Array[Button] = []
var _group_tabs: Array[Button] = []
var _save_notice: Label = null
var _code_field: LineEdit = null
var _page_label: Label = null
var _list_box: VBoxContainer = null
## 왼쪽 노트(항목 설명) 묶음. 기본 규칙 탭에서는 왼쪽에 늘 보이고, 도감 탭에서는 카드를 누를 때만 가운데 팝업으로 뜬다.
var _notebook_root: Control = null
var _notebook_page: Control = null
var _note_leather: Panel = null
var _note_paper: Control = null
var _note_column: VBoxContainer = null
var _dismiss_finger := -2
var _book_inset: Panel = null
var _popup_dim: Panel = null
var _popup_close: Button = null
## 도감 상세 창의 [◀ 이전]·[다음 ▶].
var _prev_entry: Button = null
var _next_entry: Button = null
## 도감 탭 위쪽 한 줄 요약 배너.
var _summary_banner: PanelContainer = null
var _summary_label: Label = null
var _medal: Control = null
var _ribbon: Control = null
## [기록 백업/복구] 미니 팝업.
var _save_popup: PanelContainer = null
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
## 도감 기본 격자 영역. 실제 너비는 화면에 맞추며 터치에서는 증강을 3열로 키운다.
const GRID_POS: Vector2 = Vector2(256+BOOK_SHIFT_X, 188)
const GRID_SIZE: Vector2 = Vector2(1046, 526)
const GRID_COLUMNS: int = 4
const COMPACT_TILE_SCALE: float = 0.9
## 도감 탭 장(보드판~초증강)마다 위쪽 한 줄 요약 (법전은 수집 수가 붙는다).
const BANNERS: Dictionary = {
	4: "[보드판] 보드판마다 빵집 자리·옷장 자리에 서는 칸이 달라요.",
	5: "[판정 도구] 도구마다 족보가 달라요. 증강의 [도구 교체]로 바꿔 굴려요.",
	6: "[말] 증강의 [기물 지급]으로 기본 말을 진화시켜요. 말마다 상시 능력과 1회 필살기가 있어요.",
	7: "[카드] 빵집·증강에서 얻은 카드를 보드로 끌어다 놓아 써요. 손패는 최대 7장이에요.",
	8: "[특수 승리 법전] 3라운드마다 등장하며, 조건 달성 후 내 턴이 끝나면 즉시 다음 순위로 레이스를 졸업합니다!",
	9: "[보급 증강] 패시브·즉발 발동·범용 보급·카드 보급을 색상과 분류 이름으로 구분해요.",
	10: "[초증강] 판을 한 번에 뒤집는 하이리스크 하이리턴. 경고 표시는 내 말도 사출될 수 있다는 뜻이에요.",
}


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
	# 뒤쪽 로비(팁 띠·버튼)가 비치지 않게: 흐리게 번진 화면 위에 어두운 막(0.75)
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
	_build_book()
	_build_header()
	_build_list()
	_build_notebook()
	_build_cards_area()
	_build_ribbon()
	_build_save_tools()
	resized.connect(_fit_book)
	_fit_book()


## Use the available landscape width, including the extra canvas on phones.
func _fit_book() -> void:
	if _stage == null or _book_inset == null:
		return
	var width := maxf(STAGE.x, size.x)
	_stage.custom_minimum_size.x = width
	_book_outer.size.x = width - 210.0
	_book_inset.size.x = width - 246.0
	var backup := _stage.get_node_or_null("SaveBackup") as Control
	if backup != null: backup.position.x = width - 310.0+BOOK_SHIFT_X
	var book_center := _book_outer.position.x+_book_outer.size.x*0.5
	for index: int in _group_tabs.size():
		_group_tabs[index].position.x = book_center-165.0+index*170.0
	_summary_banner.size.x = width - 320.0
	if not _content.is_empty(): _apply_group_layout(group_of(spread))


func _inside(control: Control, point: Vector2) -> bool:
	return control.is_visible_in_tree() and Rect2(Vector2.ZERO,control.size).has_point(control.get_global_transform_with_canvas().affine_inverse()*point)


func _scroll_at(point: Vector2) -> ScrollContainer:
	if _save_popup != null and _save_popup.visible: return null
	for scroll: ScrollContainer in [_left_scroll,_right_scroll]:
		if scroll == _right_scroll and group_of(spread)==1 and entry>=0: continue
		if not _inside(scroll,point): continue
		# Keep the actual scrollbar available for mouse/keyboard users.
		if _inside(scroll.get_v_scroll_bar(),point): return null
		return scroll
	return null


func _clear_scroll_drag() -> void:
	_drag_scroll = null
	_drag_entry = -1
	_drag_variant_button = null
	_drag_finger = -1
	_drag_moved = false


## Own only presses inside the book's scroll panes. Child buttons cannot
## activate on release after a swipe, and native/emulated touch never scroll twice.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and MobileSupport.text_input_active(self):return
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
		if event.button_index != MOUSE_BUTTON_LEFT: return
		point = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseMotion:
		point = event.position
		motion = true
	else: return
	# Own an outside tap through release so it cannot click behind the modal.
	if _dismiss_finger != -2:
		if finger==_dismiss_finger and released:
			var dismiss := not _inside(_notebook_page,point)
			if event is InputEventScreenTouch and event.canceled: dismiss = false
			_dismiss_finger = -2
			if dismiss: show_entry(-1)
		get_viewport().set_input_as_handled()
		return
	if group_of(spread)==1 and entry>=0 and not _inside(_notebook_page,point) and _drag_scroll==null:
		if pressed: _dismiss_finger = finger
		get_viewport().set_input_as_handled()
		return
	if _drag_scroll != null and finger != _drag_finger:
		get_viewport().set_input_as_handled()
		return
	if pressed:
		var scroll := _scroll_at(point)
		if scroll == null: return
		_drag_scroll = scroll
		_drag_finger = finger
		_drag_start = point
		_drag_top = scroll.scroll_vertical
		_drag_entry = -1
		_drag_moved = false
		if scroll == _right_scroll:
			for index: int in _tiles.size():
				if _inside(_tiles[index],point):
					_drag_entry = index
					var switch_button := _tiles[index].get_node_or_null("BoardVariantButton") as Button
					if switch_button != null and _inside(switch_button, point):
						_drag_variant_button = switch_button
					break
	elif _drag_scroll != null:
		if motion:
			var distance := point-_drag_start
			var screen_distance := get_viewport().get_screen_transform().basis_xform(distance)
			if screen_distance.length()>8.0: _drag_moved = true
			if _drag_moved:
				var local_distance := _drag_scroll.get_global_transform_with_canvas().affine_inverse().basis_xform(distance)
				_drag_scroll.scroll_vertical = _drag_top-roundi(local_distance.y)
		elif released:
			var pick := _drag_entry
			var tap := not _drag_moved and pick>=0 and _inside(_tiles[pick],point)
			if event is InputEventScreenTouch and event.canceled: tap = false
			var switch_button := _drag_variant_button
			_clear_scroll_drag()
			if tap:
				if switch_button == null:
					show_entry(pick)
				elif is_instance_valid(switch_button) and _inside(switch_button, point):
					switch_button.pressed.emit()
	else: return
	get_viewport().set_input_as_handled()


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


func _unhandled_key_input(event: InputEvent) -> void:
	if MobileSupport.text_input_active(self):return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_RIGHT:
			if group_of(spread) == 1 and entry >= 0: show_entry(wrapi(entry + 1, 0, entry_count()))
			else: show_spread(spread + 1)
		KEY_LEFT:
			if group_of(spread) == 1 and entry >= 0: show_entry(wrapi(entry - 1, 0, entry_count()))
			else: show_spread(spread - 1)
		KEY_DOWN: show_entry(entry + 1)
		KEY_UP: show_entry(entry - 1)
		KEY_ESCAPE:
			if group_of(spread)==1 and entry>=0: show_entry(-1)
			else: close()
		_: return
	get_viewport().set_input_as_handled()


func close() -> void:
	queue_free()


func spread_count() -> int:
	return TAB_NAMES.size()


# ---------------------------------------------------------------------------
# 틀: 책 테두리, 머리글, 왼쪽 항목 줄, 노트, 카드 칸, 화살표, 리본
# ---------------------------------------------------------------------------

static func _box(bg: Color, border: Color, border_width: int, radius: int, shadow: int = 0, margin: int = 0, shadow_color: Color = Color(0, 0, 0, 0.25)) -> StyleBox:
	if bg.a>0.01:
		return VISUALS.panel(bg,radius,margin)
	# Transparent selection/clip outlines stay exact to their live content bounds.
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.shadow_color = shadow_color
	box.shadow_size = shadow
	box.set_content_margin_all(margin)
	return box


## 노트 부품은 노트 묶음(_notebook_root) 안에 둔다 (도감 탭에서 통째로 가운데 팝업으로 옮긴다).
func _place_note(node: Control, pos: Vector2, node_size: Vector2) -> void:
	node.position = pos
	node.size = node_size
	_notebook_page.add_child(node)


func _place(node: Control, pos: Vector2, node_size: Vector2) -> void:
	node.position = pos
	node.size = node_size
	_stage.add_child(node)


## 한 줄 글 칸: 번역으로 길어지면 칸 폭에 맞을 때까지 글자를 줄인다 (min_px까지, 그래도 넘치면 말줄임).
static func _shrink_to_fit(label: Label, max_px: int, min_px: int) -> void:
	var fit := func() -> void:
		if not is_instance_valid(label) or label.size.x <= 1.0:
			return
		var font: Font = label.get_theme_font("font")
		var text: String = L10n.t(label.text)
		var px: int = max_px
		while px > min_px and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > label.size.x:
			px -= 1
		label.add_theme_font_size_override("font_size", px)
	label.resized.connect(fit)
	label.ready.connect(fit)


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


## 연한 청록 테두리의 큰 책 틀 두 겹과 그 안의 크림색 바탕.
func _build_book() -> void:
	var outer := Panel.new()
	_book_outer = outer
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_theme_stylebox_override("panel", _box(Color("e9f7ee"), FRAME, 12, 40, 18, 0, Color(0, 0, 0, 0.45)))
	_place(outer, Vector2(186+BOOK_SHIFT_X, 108), Vector2(1156, 634))
	var edge := Panel.new()
	_book_inset = edge
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.add_theme_stylebox_override("panel", _box(Color("f3ecd2"), FRAME_EDGE, 4, 30))
	_place(edge, Vector2(204+BOOK_SHIFT_X, 126), Vector2(1120, 598))


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


## 위 오른쪽의 법전 아이콘 + [기록 백업/복구]. 누르면 링크 복사·코드 입력 팝업을 연다.
## 링크를 눌러 접속하기만 하면 기록이 이어진다 (PlayerSave.apply_url_params). 코드 입력은 보조 수단.
func _build_save_tools() -> void:
	var backup: Button = LobbyTheme.small_button("기록 백업/복구", _toggle_save_popup, &"teal", 17)
	backup.name = "SaveBackup"
	backup.clip_text = true
	backup.icon = MetaIcon.law_icon()
	backup.add_theme_constant_override("h_separation", 10)
	for state: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		backup.add_theme_color_override(state, Color.WHITE)
	_place(backup, Vector2(1056, 28), Vector2(280, 46))
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
	_place(_save_popup, Vector2(930, 80), Vector2(406, 0))


func _toggle_save_popup() -> void:
	_save_popup.visible = not _save_popup.visible
	if _save_popup.visible:
		_save_popup.reset_size()


## 팝업 안내 줄: 비어 있으면 숨겨 팝업 밑이 비지 않게 한다.
func _set_notice(text: String) -> void:
	_save_notice.text = text
	_save_notice.visible = text != ""
	_save_popup.reset_size()


## [내 기록 전용 링크 복사]: ?s=짧은코드&n=닉네임 링크를 클립보드에 넣는다 (카톡 나에게 보내기·메모에 두었다가 누르면 이어진다).
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
	if _content.get("entries", []) is Array and not (_content.get("entries", []) as Array).is_empty():
		_rebuild_tiles()
	records_imported.emit()
	return true


## 왼쪽 세로 항목 줄: 현재 탭의 장 4개. 고른 항목은 흰 알약에 점선 느낌의 초록 테두리.
func _build_list() -> void:
	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 8)
	_list_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_list_box, Vector2(28, 148), Vector2(196, 560))  # 도감 묶음 7장(보드판~초증강)이 들어간다
	for index: int in TAB_NAMES.size():
		var button := Button.new()
		button.name = "Tab%d" % index
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(196, 66)
		button.pressed.connect(show_spread.bind(index))
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var disc := Panel.new()
		disc.name = "Disc"
		disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		disc.position = Vector2(8, 7)  # 버튼 안쪽 왼쪽 (바깥으로 삐져나오지 않게)
		disc.size = Vector2(52, 52)
		button.add_child(disc)
		var icon := _art(TAB_ART[index], Vector2(40, 40))
		icon.position = Vector2(6, 6)
		disc.add_child(icon)
		var plate := Label.new()
		plate.name = "Plate"
		plate.text = TAB_NAMES[index]
		plate.add_theme_font_size_override("font_size", 22)
		plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plate.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.position = Vector2(64, 0)
		plate.size = Vector2(124, 66)
		plate.clip_text = true
		plate.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_shrink_to_fit(plate, 22, 13)
		button.add_child(plate)
		_list_box.add_child(button)
		_list_buttons.append(button)


func _build_notebook() -> void:
	_notebook_root = Control.new()
	_notebook_root.name = "NotebookRoot"
	_notebook_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notebook_root.size = STAGE
	_stage.add_child(_notebook_root)
	_popup_dim = Panel.new()
	_popup_dim.name = "NotebookPopupDim"
	# Reuse the inset's painted alpha contour and nine-slice corners, so the
	# dim follows the book edge instead of covering it with a square rectangle.
	var dim_skin: StyleBoxTexture = _book_inset.get_theme_stylebox("panel").duplicate()
	dim_skin.modulate_color = Color(0, 0, 0, 0.55)
	_popup_dim.add_theme_stylebox_override("panel", dim_skin)
	_popup_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup_dim.visible = false
	_notebook_root.add_child(_popup_dim)
	_notebook_page = Control.new()
	_notebook_page.name = "NotebookPage"
	_notebook_page.size = STAGE
	_notebook_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notebook_root.add_child(_notebook_page)
	var leather := Panel.new()
	_note_leather = leather
	leather.mouse_filter = Control.MOUSE_FILTER_IGNORE
	leather.add_theme_stylebox_override("panel", _box(LEATHER, LEATHER_DARK, 4, 22, 8, 0, Color(0, 0, 0, 0.35)))
	_place_note(leather, Vector2(256, 140), Vector2(552, 574))
	var paper := LinedPaper.new()
	_note_paper = paper
	_place_note(paper, Vector2(272, 156), Vector2(520, 542))
	var column := VBoxContainer.new()
	_note_column = column
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place_note(column, Vector2(290, 168), Vector2(484, 520))
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
	_left_scroll = scroll
	scroll.set_meta(MobileSupport.CUSTOM_DRAG_SCROLL, true)  # 도감은 스스로 끌기 스크롤을 한다
	scroll.name = "EntryDetailScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var detail_margin := MarginContainer.new()
	detail_margin.name = "DetailSafeMargins"
	detail_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_margin.add_theme_constant_override("margin_right", 14)
	detail_margin.add_theme_constant_override("margin_bottom", 12)
	scroll.add_child(detail_margin)
	_left_holder = VBoxContainer.new()
	_left_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_holder.add_theme_constant_override("separation", 10)
	detail_margin.add_child(_left_holder)
	var medal := _art(&"badge", Vector2(80, 96))
	medal.name = "RulebookBadge"
	_place_note(medal, Vector2(740, 124), Vector2(80, 96))
	_medal = medal
	_popup_close = LobbyTheme.small_button("닫기", func() -> void: show_entry(-1), &"gray", 16)
	_popup_close.name = "CloseEntry"
	_popup_close.visible = false
	_place_note(_popup_close, Vector2(708, 668), Vector2(84, 36))
	_prev_entry = LobbyTheme.small_button("◀ 이전", func() -> void: show_entry(wrapi(entry - 1, 0, entry_count())), &"teal", 22)
	_prev_entry.name = "PrevEntry"
	_prev_entry.visible = false
	_place_note(_prev_entry, Vector2.ZERO, Vector2(160, 64))
	_next_entry = LobbyTheme.small_button("다음 ▶", func() -> void: show_entry(wrapi(entry + 1, 0, entry_count())), &"teal", 22)
	_next_entry.name = "NextEntry"
	_next_entry.visible = false
	_place_note(_next_entry, Vector2.ZERO, Vector2(160, 64))


func _build_cards_area() -> void:
	# 도감 탭 위쪽 한 줄 요약 배너 (왼쪽 긴 설명 대신)
	_summary_banner = PanelContainer.new()
	_summary_banner.name = "SummaryBanner"
	_summary_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_summary_banner.add_theme_stylebox_override("panel", _box(Color("fff4d6"), GOLD, 2, 14, 0, 6))
	_summary_label = Label.new()
	_summary_label.name = "SummaryText"
	_summary_label.add_theme_font_size_override("font_size", 17)
	_summary_label.add_theme_color_override("font_color", Color("6b4a2a"))
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_summary_label.clip_text = true
	_summary_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_summary_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_summary_banner.add_child(_summary_label)
	_place(_summary_banner, Vector2(GRID_POS.x, 140), Vector2(GRID_SIZE.x, 40))
	_summary_banner.visible = false
	_right_scroll = ScrollContainer.new()
	_right_scroll.name = "CatalogScroll"
	_right_scroll.set_meta(MobileSupport.CUSTOM_DRAG_SCROLL, true)
	_right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_place(_right_scroll, Vector2(834+BOOK_SHIFT_X, 142), Vector2(468, 570))
	_right_holder = VBoxContainer.new()
	_right_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_holder.add_theme_constant_override("separation", 12)
	_right_scroll.add_child(_right_holder)


func _build_ribbon() -> void:
	var ribbon := Ribbon.new()
	_ribbon = ribbon
	_place(ribbon, Vector2(560+BOOK_SHIFT_X, 706), Vector2(246, 56))
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
	if not is_node_ready():
		# 아직 트리에 붙기 전 (부모가 화면 밖): 붙으면 연다
		ready.connect(show_spread.bind(index, entry_index), CONNECT_ONE_SHOT)
		return
	_dismiss_finger = -2
	_clear_scroll_drag()
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
			var style := VISUALS.panel(Color("fbf4df") if active else Color("c9b98e"),16,4)
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
		var teal_back := VISUALS.panel(Color("f4fffa") if selected else TEAL,22)
		button.add_theme_stylebox_override("normal", teal_back)
		var teal_hover: StyleBoxTexture = teal_back.duplicate()
		teal_hover.modulate_color = Color.WHITE if selected else TEAL.lightened(0.12)
		button.add_theme_stylebox_override("hover", teal_hover)
		button.add_theme_stylebox_override("pressed", teal_back)
		disc.add_theme_stylebox_override("panel", VISUALS.disc(Color("fffdf0")))
		plate.add_theme_color_override("font_color", Color("2f6f66") if selected else Color.WHITE)
		plate.add_theme_color_override("font_outline_color", Color(0.1, 0.35, 0.3, 0.9))
		plate.add_theme_constant_override("outline_size", 0 if selected else 5)
	_apply_group_layout(group)
	_page_label.text = "%d / %d" % [spread + 1, spread_count()]


## 한 줄 요약이 길면 (영어·일본어) 글자를 17→12px까지 줄여 한 줄에 맞춘다. 그래도 넘치면 말줄임.
func _fit_summary(text: String) -> void:
	var font: Font = _summary_label.get_theme_font("font")
	var width: float = _summary_banner.size.x - 24.0
	var px: int = 17
	while px > 12 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
		px -= 1
	_summary_label.add_theme_font_size_override("font_size", px)


## 기본 규칙은 왼쪽 노트 + 오른쪽 좁은 칸 + 쪽 표시,
## 도감은 위쪽 한 줄 요약 + 화면에 맞춘 격자 (노트는 항목을 누를 때만 팝업).
func _apply_group_layout(group: int) -> void:
	var catalog: bool = group == 1
	_summary_banner.visible = catalog
	if catalog:
		var text: String = L10n.t(str(BANNERS.get(spread, "")))
		if spread == LAW_SPREAD:
			text = L10n.tf("%s (수집: %d/%d)", [text, PlayerSave.law_count(), LawRegistry.ALL_IDS.size()])
		_summary_label.text = text
		_fit_summary(text)
		_right_scroll.position = GRID_POS
		_right_scroll.size = Vector2(_book_inset.size.x-74.0,GRID_SIZE.y)
	else:
		_right_scroll.position = Vector2(834+BOOK_SHIFT_X, 142)
		_right_scroll.size = Vector2(_book_inset.size.x-652.0,570)
	_ribbon.visible = not catalog
	_layout_notebook()


## 노트 묶음: 기본 규칙이면 왼쪽 제자리, 도감이면 항목을 골랐을 때만 책 가운데 팝업 (뒤를 어둡게, 바깥을 누르거나 [닫기]로 닫는다).
func _layout_notebook() -> void:
	if _notebook_root == null:
		return
	var catalog: bool = group_of(spread) == 1
	var popup: bool = catalog and entry >= 0
	_notebook_root.visible = not catalog or popup
	# Grid selection outlines (z=6) and collection stamps (z=7) must stay
	# behind both the modal dim and the notebook, regardless of sibling order.
	_notebook_root.z_index = 10 if popup else 0
	_notebook_root.position = Vector2.ZERO
	_notebook_root.size = Vector2(_book_outer.size.x+210.0,STAGE.y)
	_popup_dim.visible = popup
	_popup_dim.position = _book_inset.position
	_popup_dim.size = _book_inset.size
	_popup_close.visible = popup
	_prev_entry.visible = popup and entry_count() > 1
	_next_entry.visible = popup and entry_count() > 1
	_list_box.z_index = 0
	if popup:
		var frame := Vector2(_book_outer.size.x+210.0,STAGE.y)
		var extent := Vector2(frame.x*0.88,frame.y-48.0)
		_notebook_page.position = (frame-extent)*0.5
		_notebook_page.size = extent
		_notebook_page.mouse_filter = Control.MOUSE_FILTER_STOP
		_note_leather.position = Vector2.ZERO
		_note_leather.size = extent
		_note_paper.position = Vector2(16,16)
		_note_paper.size = extent-Vector2(32,32)
		# Render fonts, card borders and paper at their final size, without
		# magnifying an already laid-out control tree.
		_note_column.position = Vector2(36,30)
		_note_column.scale = Vector2.ONE
		_note_column.size = extent-Vector2(72,142)
		_medal.position = Vector2(extent.x-104,16)
		_popup_close.position = extent-Vector2(192,96)
		_popup_close.size = Vector2(160,64)
		_next_entry.position = extent-Vector2(192+184,96)
		_prev_entry.position = extent-Vector2(192+184*2,96)
	else:
		_notebook_page.position = Vector2.ZERO
		_notebook_page.size = STAGE
		_notebook_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_note_leather.position = Vector2(256+BOOK_SHIFT_X,140)
		_note_leather.size = Vector2(552,574)
		_note_paper.position = Vector2(272+BOOK_SHIFT_X,156)
		_note_paper.size = Vector2(520,542)
		_note_column.position = Vector2(290+BOOK_SHIFT_X,168)
		_note_column.scale = Vector2.ONE
		_note_column.size = Vector2(484,520)
		_medal.position = Vector2(740+BOOK_SHIFT_X,124)  # 위쪽 [기본 규칙]·[도감] 탭 아래 (겹치지 않게)
		_popup_close.position = Vector2(708+BOOK_SHIFT_X,668)
		_popup_close.size = Vector2(84,36)
	_note_column.add_theme_constant_override("separation", 12 if popup else 6)
	_chapter_label.add_theme_font_size_override("font_size", 20 if popup else 15)
	_notebook_title.add_theme_font_size_override("font_size", 40 if popup else 30)
	# Keep the title away from the inset medal, including translated titles.
	_notebook_title.get_parent().custom_minimum_size.x = _note_column.size.x-160.0 if popup else 0.0
	_notebook_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if popup else TextServer.AUTOWRAP_OFF
	_notebook_title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_notebook_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notebook_title.custom_minimum_size.x = minf(720.0,_note_column.size.x-264.0) if popup else 0.0
	_popup_close.add_theme_font_size_override("font_size",22 if popup else 16)
	if popup:
		_notebook_root.get_parent().move_child(_notebook_root, -1)  # 격자 위에 뜬다


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
	_dismiss_finger = -2
	_clear_scroll_drag()
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
	_left_scroll.scroll_vertical = 0
	for tile_index: int in _tiles.size():
		_paint_tile(_tiles[tile_index], tile_index == entry)
	_layout_notebook()


func _rebuild_tiles() -> void:
	for child: Node in _right_holder.get_children():
		_right_holder.remove_child(child)
		child.queue_free()
	_tiles.clear()
	var wide: bool = bool(_content.get("wide", false))
	var catalog: bool = group_of(spread) == 1
	var grid := GridContainer.new()
	grid.name = "EntryGrid"
	grid.columns = (3 if MobileSupport.touch_mode() and spread!=CARD_SPREAD else GRID_COLUMNS) if catalog else (2 if wide else 3)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var entries: Array = _content.get("entries", [])
	for index: int in entries.size():
		var data: Dictionary = entries[index]
		var tile: Control = _picture_tile(data, show_entry.bind(index), catalog) if wide else _tile(data)
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
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	disc.add_theme_stylebox_override("panel", VISUALS.disc(Color.WHITE))
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


## 도감 그림 타일: 기존 카드 전체를 격자 칸 너비에 비례해 맞춘다.
## compact: 낮은 카드 (그림·제목·조건만, 아래 빈 공간 없이).
func _picture_tile(data: Dictionary, on_pick: Callable, compact: bool = false) -> Control:
	var holder := Control.new()
	holder.name = "Entry_" + str(data["title"])
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_size: Vector2
	var card_radius: int = 12
	if data.has("board_id"):
		var full_board: Vector2 = Vector2(MainBoard.AUGMENT_CARD_SIZE.x, MainBoard.AUGMENT_COMPACT_HEIGHT)
		card_size = full_board * (COMPACT_TILE_SCALE if compact else AUGMENT_TILE_SCALE)
		card_radius = 16
		var board_card: Button = _board_card(data, full_board)
		board_card.pressed.connect(on_pick)
		holder.add_child(board_card)
	elif data.has("augment"):
		var definition: AugmentDef = AugmentRegistry.get_def(data["augment"])
		var tile_scale: float = COMPACT_TILE_SCALE if compact else AUGMENT_TILE_SCALE
		var full: Vector2 = Vector2(MainBoard.AUGMENT_CARD_SIZE.x, MainBoard.AUGMENT_COMPACT_HEIGHT) if compact else MainBoard.AUGMENT_CARD_SIZE
		card_size = full * tile_scale
		card_radius = int(round(16.0 * tile_scale))  # 증강 카드 모서리(16)를 줄인 배율 그대로
		var card: Button = MainBoard.make_augment_card(_brief_info(_card_info_for_tile(definition, data), data), on_pick, tile_scale, true, compact)
		card.position = -full * (1.0 - tile_scale) / 2.0  # 가운데 기준으로 줄였으니 왼쪽 위를 맞춘다
		holder.add_child(card)
	else:
		card_size = CARD_TILE
		var face := Button.new()
		face.focus_mode = Control.FOCUS_NONE
		face.size = CARD_TILE
		var card_data: BaseCard = CardRegistry.get_card(data["card"])
		for state: String in ["normal", "hover", "pressed", "focus"]:
			face.add_theme_stylebox_override(state, CardSkin.frame(card_data.category, false, 12))  # 도감은 마우스를 올려도 그대로
		var body: Control = CardSkin.body(card_data, CARD_TILE, MainBoard.card_summary(data["card"]), MainBoard.category_label(card_data), true)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_child(body)
		face.pressed.connect(on_pick)
		holder.add_child(face)
	holder.custom_minimum_size = card_size
	if compact:
		var visual := holder.get_child(0) as Button
		visual.pivot_offset = visual.size*0.5
		holder.resized.connect(_fit_picture_tile.bind(holder,visual,visual.size))
	# 특수 승리 법전으로 졸업해 본 교칙: [달성 완료 ★] 도장 (영구 기록)
	if data.has("law_id") and PlayerSave.has_law(str(data["law_id"])):
		var stamp: PanelContainer = MetaIcon.stamp("달성 완료 ★", 18)
		stamp.add_theme_stylebox_override("panel",VISUALS.panel(Color("fff4d6"),12,8))
		stamp.position = Vector2(card_size.x * 0.5 - 64.0, card_size.y * 0.30)
		stamp.z_index = 7
		stamp.name = "CollectionStamp"
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
	# 오른쪽 위 공통 화살표로 다른 보드판의 법전을 본다.
	if data.has("augment") and _has_board_variant(AugmentRegistry.get_def(data["augment"])):
		var switch_button := Button.new()
		switch_button.name = "BoardVariantButton"
		switch_button.custom_minimum_size = Vector2(44, 44)
		switch_button.size = Vector2(44, 44)
		switch_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var tint := Color("ffe8a3")
		switch_button.add_theme_stylebox_override("normal", VISUALS.disc(tint))
		switch_button.add_theme_stylebox_override("hover", VISUALS.disc(tint.lightened(0.45)))
		switch_button.add_theme_stylebox_override("pressed", VISUALS.disc(tint.darkened(0.18)))
		var destination: String = L10n.t("%s 보기" % BoardCatalog.name_of(BoardCatalog.ids()[_next_variant_board(data)]))
		switch_button.tooltip_text = destination
		switch_button.accessibility_name = destination
		var icon := HubArt.icon(&"next")
		icon.name = "BoardVariantIcon"
		icon.position = Vector2(8, 8)
		icon.size = Vector2(28, 28)
		switch_button.add_child(icon)
		switch_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		switch_button.offset_left = -50.0
		switch_button.offset_right = -6.0
		switch_button.offset_top = 6.0
		switch_button.offset_bottom = 50.0
		switch_button.z_index = 8
		switch_button.pressed.connect(_flip_board_variant.bind(holder, data, on_pick, compact))
		holder.add_child(switch_button)
	return holder


## 보드판 카드: 증강 카드와 같은 크기의 둥근 판에 미리보기 그림 + 이름 + 고유 칸 이름.
func _board_card(data: Dictionary, full: Vector2) -> Button:
	var card := Button.new()
	card.name = "BoardCard"
	card.focus_mode = Control.FOCUS_NONE
	card.size = full
	var skin := VISUALS.panel(Color("d8eef8"), 16, 0)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		card.add_theme_stylebox_override(state, skin)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 14
	column.offset_right = -14
	column.offset_top = 14
	column.offset_bottom = -12
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var picture_size := Vector2(full.x - 28.0, 160.0)
	column.add_child(_rounded_art(_picture(data, picture_size), picture_size, 16, Color("5fc1e8")))
	var title := Label.new()
	title.text = str(data["title"])
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("1f4a63"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)
	var kinds := Label.new()
	kinds.text = " · ".join(PackedStringArray(data.get("kind_names", [])))
	kinds.add_theme_font_size_override("font_size", 18)
	kinds.add_theme_color_override("font_color", Color("3a6a80"))
	kinds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kinds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kinds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(kinds)
	return card


## 보드 넘기기 화살표: BoardCatalog의 보드 순서대로 돈다 (안내 문구는 "<보드 이름> 보기", 번역 행이 있어야 한다).
## 이 증강이 보드마다 바꿔 쓰는 특수 승리인가.
static func _has_board_variant(definition: AugmentDef) -> bool:
	return definition != null and definition.category == GameEnums.AugmentCategory.LAW_ENACT and VictoryLaw.has_board_variant(str(definition.payload))


## 지금 판의 보드 번호 (BoardCatalog 순서).
static func _current_board_index() -> int:
	return maxi(BoardCatalog.ids().find(BoardSpec.board_id), 0)


## 이 타일이 지금 보여 주는 보드 번호 (지금 보드판 설정 기준 + 화살표를 누른 횟수만큼 다음 보드).
static func _shown_variant_board(data: Dictionary) -> int:
	return (_current_board_index() + int(data.get("variant_step", 0))) % BoardCatalog.ids().size()


static func _next_variant_board(data: Dictionary) -> int:
	return (_shown_variant_board(data) + 1) % BoardCatalog.ids().size()


## 이 타일이 지금 보여 주는 보드 id.
static func _shown_board_id(data: Dictionary) -> StringName:
	return BoardCatalog.ids()[_shown_variant_board(data)]


## 도감 카드는 한 줄 요약만: 판정 도구의 작은 족보표(detail)와 기물의 필살기 줄(skill)은 빼고 (상세 창에 있다),
## 설명은 항목의 brief(교칙 조건·기물 패시브 첫 줄)가 있으면 그것으로.
static func _brief_info(info: Dictionary, data: Dictionary) -> Dictionary:
	var brief: Dictionary = info.duplicate()
	brief["detail"] = ""
	brief["skill"] = ""
	brief["skill_only"] = false
	if data.has("brief") and str(data["brief"]) != "":
		brief["desc"] = str(data["brief"])
	return brief


## 타일에 보일 카드 정보: 화살표로 뒤집었으면 다른 보드의 판 문구로 만든다 (끝나면 지금 보드 문구로 되돌린다).
static func _card_info_for_tile(definition: AugmentDef, data: Dictionary) -> Dictionary:
	if int(data.get("variant_step", 0)) == 0 or not _has_board_variant(definition):
		return MainBoard.augment_card_info(definition, null, 1)
	VictoryLaw.preview_board = _shown_board_id(data)
	AugmentRegistry.apply_board_variants()
	var info: Dictionary = MainBoard.augment_card_info(definition, null, 1)
	VictoryLaw.preview_board = &""
	AugmentRegistry.apply_board_variants()
	return info


## 화살표: 이 카드를 다른 보드의 판으로 바꿔 다시 그린다 (자리·선택 상태는 그대로, 오른쪽 설명 글도 같이 바뀐다).
func _flip_board_variant(holder: Control, data: Dictionary, on_pick: Callable, compact: bool) -> void:
	data["variant_step"] = (int(data.get("variant_step", 0)) + 1) % BoardCatalog.ids().size()
	data["variant_flipped"] = int(data["variant_step"]) != 0  # 지금 보드가 아닌 판을 보는 중 (옛 키, 테스트 호환)
	var law_id: String = str(data.get("law_id", ""))
	if law_id != "" and VictoryLaw.DEFS.has(law_id):
		VictoryLaw.preview_board = _shown_board_id(data)
		var law: VictoryLaw = LawRegistry.create(law_id) as VictoryLaw
		data["texture"] = AugmentArt.load_first(AugmentArt.law_candidates(law_id))
		VictoryLaw.preview_board = &""
		data["title"] = law.law_name
		data["summary"] = law.condition_text()
	var fresh: Control = _picture_tile(data, on_pick, compact)
	var parent: Node = holder.get_parent()
	var slot: int = holder.get_index()
	var tile_index: int = _tiles.find(holder)
	parent.add_child(fresh)
	parent.move_child(fresh, slot)
	if tile_index != -1:
		_tiles[tile_index] = fresh
		_paint_tile(fresh, tile_index == entry)
	holder.queue_free()
	if tile_index != -1 and tile_index == entry:
		show_entry(entry)  # 보고 있던 항목이면 오른쪽 설명도 새 이름·조건으로


## Scale the whole original face uniformly into its actual grid column.
## The minimum height follows that scale so rows and their hit areas match.
func _fit_picture_tile(holder: Control, visual: Button, full: Vector2) -> void:
	var factor := holder.size.x/full.x
	var extent := full*factor
	visual.scale = Vector2.ONE*factor
	visual.position = -full*(1.0-factor)*0.5
	holder.custom_minimum_size.y = extent.y
	var marker := holder.get_node_or_null("SelectedOutline") as Control
	if marker != null: marker.size = extent+Vector2.ONE*2.0
	var stamp := holder.get_node_or_null("CollectionStamp") as Control
	if stamp != null: stamp.position = Vector2(extent.x*0.5-64.0,extent.y*0.3)


func _paint_tile(tile: Control, selected: bool) -> void:
	if tile.has_meta("marker"):
		# Catalog entries are shown in a modal. Its background grid needs no
		# selection rectangle, which could otherwise overlap the detail artwork.
		(tile.get_meta("marker") as Control).visible = selected and group_of(spread) == 0
		return
	var button: Button = tile as Button
	var tone: Color = button.get_meta("tone")
	var normal := VISUALS.panel(Color.WHITE if selected else tone.lightened(0.62),20)
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxTexture = normal.duplicate()
	hover.modulate_color = Color.WHITE
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
	var mask_style := StyleBoxFlat.new()
	mask_style.bg_color = Color.WHITE
	mask_style.set_corner_radius_all(radius)
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
		if (absf(ratio - 1.0) < 0.12 or ratio > 1.25) and not _is_cutout(art.texture):
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED  # 배경까지 그린 일러스트(정사각·가로로 긴 보드판 미리보기)는 칸을 빈틈없이 채운다
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
	glyph.set_meta("legacy_rulebook_glyph",true)
	glyph.custom_minimum_size = extent
	glyph.size = extent
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return glyph


# ---------------------------------------------------------------------------
# 왼쪽 노트의 자세한 모습: 큰 그림 + 한 줄 요약 + 표 + 요점 + 꿀팁
# ---------------------------------------------------------------------------

func _detail(data: Dictionary) -> Array[Control]:
	var nodes: Array[Control] = []
	var enlarged := group_of(spread)==1 and entry>=0
	var hero_size := Vector2(288,288) if enlarged else HERO_ART
	var tone: Color = data.get("tone", Color("5fc1e8"))
	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation", 24 if enlarged else 14)
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if data.has("card"):
		var face := _card_face(data["card"],Vector2(320,448) if enlarged else CARD_FACE)
		face.set_meta("native_card_detail", true)
		hero.add_child(face)
	elif data.get("texture", null) != null or ART.has(data.get("art", &"")) or VISUALS.has(data.get("art", &"")):
		hero.add_child(_rounded_art(_picture(data,hero_size),hero_size,HERO_RADIUS,tone))
	else:
		var frame := PanelContainer.new()
		frame.custom_minimum_size = Vector2(132, 132)
		frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_theme_stylebox_override("panel", _box(tone.lightened(0.7), tone, 4, 24, 3, 8, Color(0, 0, 0, 0.15)))
		frame.add_child(_picture(data, Vector2(112, 112)))
		hero.add_child(frame)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 16 if enlarged else 8)
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
	for block: Dictionary in data.get("blocks", []):
		nodes.append(_block(block))
	var points: Array = data.get("points", [])
	if not points.is_empty():
		nodes.append(_points(points, tone))
	if data.has("note"):
		nodes.append(_rich("[color=#8a7a58]%s[/color]" % str(data["note"]), 15))
	if data.has("tip"):
		nodes.append(_tip(str(data["tip"])))
	if enlarged:
		for index: int in range(1,nodes.size()): side.add_child(nodes[index])
		_detail_native_type(hero)
		return [hero]
	return nodes


## Larger live text replaces the old 1.4x subtree transform. CardSkin already
## builds its labels and shader geometry for the requested final card size.
func _detail_native_type(node: Control) -> void:
	if node.has_meta("native_card_detail"):
		return
	for key: String in ["font_size", "normal_font_size", "bold_font_size"]:
		if node.has_theme_font_size_override(key):
			node.add_theme_font_size_override(key, roundi(node.get_theme_font_size(key)*1.3))
	if node is Label and node.custom_minimum_size.x == 150.0:
		node.custom_minimum_size.x = 180.0
	for child: Node in node.get_children():
		if child is Control:
			_detail_native_type(child)


## 작은 묶음 (보드판의 고유 칸 설명): 그림 + 이름 + 꼬리표 + 요약, 아래 표.
func _block(block: Dictionary) -> Control:
	var tone: Color = block.get("tone", Color("5fc1e8"))
	var panel := PanelContainer.new()
	panel.name = "Block_" + str(block.get("title", ""))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _box(tone.lightened(0.82), tone, 2, 18, 0, 12))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation", 12)
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(hero)
	hero.add_child(_rounded_art(_picture(block, Vector2(72, 72)), Vector2(72, 72), 16, tone))
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 6)
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(side)
	var title := Label.new()
	title.text = str(block["title"])
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("4a3520"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(title)
	var chips := HFlowContainer.new()
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for chip_text: Variant in block.get("chips", []):
		chips.add_child(_chip(str(chip_text), tone))
	side.add_child(chips)
	var summary: RichTextLabel = _rich(str(block.get("summary", "")), 17, DARK_INK)
	summary.custom_minimum_size = Vector2(0, 0)
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_child(summary)
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
	chip.add_theme_stylebox_override("normal", _box(tone.darkened(0.12), tone.darkened(0.3), 0, 9, 0, 0))
	chip.get_theme_stylebox("normal").content_margin_left = 10
	chip.get_theme_stylebox("normal").content_margin_right = 10
	chip.get_theme_stylebox("normal").content_margin_top = 2
	chip.get_theme_stylebox("normal").content_margin_bottom = 2
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
		dot.add_theme_stylebox_override("panel", VISUALS.disc(tone))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(dot)
		var text: RichTextLabel = _rich(str(point), 17)
		text.custom_minimum_size = Vector2(0, 0)
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
	face.add_child(CardSkin.body(card,extent,MainBoard.card_summary(card_id),MainBoard.category_label(card),true))
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
	return content


# ---------------------------------------------------------------------------
# 내용 (장 10개). 장마다 항목 목록: title / tone / 그림(texture·art·number·icon) / chips / summary / rows / points / note / tip / extra
# ---------------------------------------------------------------------------

func _ch_start() -> Dictionary:
	return {"title": "시작하기", "entries": [
		{"title": "한눈에 보기", "art": &"start", "tone": Color("86d94f"), "chips": ["2~4인", "한 바퀴 레이스"],
			"summary": "말 [b]4개를 모두[/b] 한 바퀴 돌려 결승선(0번)에 먼저 넣는 레이스예요.",
			"rows": [["이기는 법", "말 4개 완주 → 먼저 해낸 순서로 1·2·3위"], ["특수 승리", "법전의 조건을 채운 채 내 차례가 끝나면 바로 졸업"], ["손패", "생떼 카드 최대 %d장" % GameEnums.MAX_HAND_SIZE], ["출발", "말 4개 모두 출발선(0번)에서"], ["판 길이", "%d라운드가 끝나면 남은 사람은 진행 순위로 확정" % PacingDirector.HARD_CAP_ROUND]],
			"tip": "처음이라면 [b]놀이터[/b]에서 컴퓨터와 한 판 해 보세요."},
		{"title": "완주와 순위", "art": &"finish", "tone": Color("86d94f"), "chips": ["서바이벌 순위"],
			"summary": "말이 0번을 [b]밟거나 넘으면[/b] 완주예요. 눈금이 남아도 괜찮아요. 4개 모두 완주하면 [b]순위 확정[/b]!",
			"rows": [["1·2·3위", "먼저 해낸 순서대로 (말 4개 완주 또는 특수 승리)"], ["같은 순간", "지금 차례인 사람이 먼저, 그다음 차례 순서"], ["마지막 한 명", "남은 사람이 한 명이 되면 그 사람이 꼴찌로 판이 끝나요"], ["라운드 상한", "완주한 말 수 → 결승까지 남은 거리 순으로 순위"]],
			"points": ["순위가 정해진 사람(졸업)은 말이 모두 빠지고, 깔아 둔 함정·호텔도 사라져요", "졸업한 사람의 차례와 증강 선택은 건너뛰어요"]},
		{"title": "말마다 능력", "art": &"pawn_ability", "tone": Color("f08aa8"), "chips": ["증강", "필살기 1회"],
			"summary": "증강으로 기본 말을 [b]체스·장기·쇼기·바둑·모노폴리…[/b] 말로 진화시켜요. 말마다 늘 켜진 능력(패시브)과 한 판에 한 번 쓰는 필살기가 있어요.",
			"points": ["필살기는 내 차례 시작에, 굴리기 전에 써요", "같은 기물은 두 번 받을 수 없어요", "보드 위 말에 마우스를 올리면 능력이 보여요", "자세한 건 [b]도감 → 말[/b]"]},
		{"title": "굴리는 도구", "art": &"tool_swap", "tone": Color("5fc1e8"), "chips": ["%d종" % (AugmentRegistry.SWAPPABLE_TOOLS.size() + 1)],
			"summary": "기본 주사위로 시작해 증강으로 [b]윷·룰렛·홀덤·슬롯·다트…[/b]로 바꿔요. 도구마다 칸 수와 족보가 달라요.",
			"points": ["0칸이 나오는 도구는 대부분 그대로 턴이 끝나요 (윷 낙·타로 광대 등)", "게임 중 오른쪽 카드에 지금 도구의 규칙표가 나와요", "카드·타로처럼 직접 골라 뒤집는 도구도 있어요", "자세한 건 [b]도감 → 도구[/b]"]},
		{"title": "카드와 법전", "art": &"card_law", "tone": Color("f0c14e"), "chips": ["생떼 카드", "특수 승리"],
			"summary": "함정을 깔고, 상대 말을 날리고, 법전의 특수 승리를 노려 판을 뒤집어요.",
			"rows": [["카드 얻기", "빵집(보드마다 편의점·마녀 상점) · 물 정령 · 증강 · 일부 기물 능력"], ["카드 쓰기", "내 차례에 굴리기 전 한 장 (방어 카드는 공격받을 때)"], ["법전", "증강으로 교칙을 올리면 모두에게 특수 승리 조건이 열려요 (최대 %d개)" % GameEnums.MAX_LAWS]],
			"points": ["법전 조건은 [b]내 차례가 끝날 때[/b] 채워져 있으면 특수 승리!", "교칙이 법전에 오른 순간부터 기록을 새로 세요"]},
	]}


func _ch_turn() -> Dictionary:
	var dash: String = _join_tiles(BoardSpec.dash_tiles)
	var first_draft: int = GameEnums.DRAFT_START
	var stages: Array[int] = TempoUp.STAGE_ROUNDS  # 기본 속도 기준 (스피드전은 MatchRules.SPEED_STAGE_ROUNDS)
	return {"title": "한 턴", "entries": [
		{"title": "한눈에 보기", "art": &"turn", "tone": Color("86d94f"), "chips": ["4단계"],
			"summary": "한 턴은 [b]카드 → 굴리기 → 말 고르기 → 정산[/b] 순서예요. 모두 한 번씩 하면 한 라운드예요.",
			"rows": [["① 카드", "굴리기 전에 한 장 (안 써도 돼요) · 필살기도 이때"], ["② 굴리기", "도구를 굴려 칸 수 결정"], ["③ 말 고르기", "그 칸 수만큼 움직일 말 선택"], ["④ 정산", "도착한 칸의 효과 · 잡기 · 업기"]],
			"points": ["친선전에서는 단계마다 제한 시간이 있고, 시간이 지나면 자동으로 진행돼요 (컴퓨터 대전은 제한 없음)", "라운드 끝에는 소환된 중립 기물이 움직여요"],
			"tip": "카드는 [b]굴리기 전에만[/b] 낼 수 있어요. 눈금을 보고 고민하려면 아껴 두세요."},
		{"title": "카드 한 장", "art": &"play_card", "number": 1, "tone": Color("f0c14e"), "chips": ["굴리기 전", "턴당 1장"],
			"summary": "카드를 [b]보드판 위로 끌어다 놓으면[/b] 발동해요. 한 차례에 한 장만 낼 수 있어요.",
			"points": ["함정·소환은 놓은 뒤 칸을 골라요", "일기토 데스매치는 상대 프로필이나 말 위에 놓아요", "방어 카드는 끌어 쓰지 않아요 (공격받을 때 팝업)", "밴에 걸리면 그 차례에는 카드·필살기를 못 써요"]},
		{"title": "굴리기", "art": &"roll", "number": 2, "tone": Color("86d94f"), "chips": ["스페이스"],
			"summary": "[b]굴리기[/b] 버튼(또는 스페이스)을 누르면 내 도구를 굴려요. 도구에 따라 직접 고르거나 조작할 수 있어요.",
			"rows": [["꾹 눌러 파워", "주사위·윷·친치로·야추·핀볼은 꾹 누르면 게이지, 떼면 던져요"], ["직접 고르기", "타로·화투·홀덤·마작·오미쿠지·쿠키·아이스크림·캡슐은 뒷면을 골라 뒤집어요"], ["직접 조작", "룰렛은 원판을 잡아 돌리고, 슬롯은 눌러 릴을 멈추고, 다트는 끌어 던지고, 복권은 손가락으로 긁어요"], ["이어 굴리기", "리볼버·야추·블랙잭·해적 룰렛은 멈출지 더 할지 골라요"]],
			"points": ["가만히 있으면 저절로 진행돼요", "굴리기 전에는 버튼 위에 내 도구가 놓여 있어요"]},
		{"title": "말 고르기", "art": &"choose_pawn", "number": 3, "tone": Color("5fc1e8"),
			"summary": "아래 말 카드나 보드 위의 말을 누르면 그 말이 눈금만큼 움직여요.",
			"points": ["말을 가리키면 도착 칸과 이동 거리 계산(기본 + 보너스)이 미리 보여요", "카드에 도착 결과가 미리 보여요 (잡기·빵집·워프·정령…)", "출발선의 말을 고르면 새로 출발해요"]},
		{"title": "정산", "art": &"resolve", "number": 4, "tone": Color("f08aa8"),
			"summary": "도착한 칸의 효과가 터져요. 공격받은 사람은 방어 카드로 받아칠지 고를 수 있어요.",
			"rows": [["적 말", "그 칸에 멈추면 잡기!"], ["내 말", "그 칸에 멈추면 업기 (함께 움직여요)"], ["특수 칸", "코너 · 부스터 발판 · 빵집 자리 · 옷장 자리 칸의 효과"], ["함정", "지나가거나 멈추면 그 함정이 발동해요"]],
			"points": ["보드마다 빵집 자리·옷장 자리의 칸이 달라요 ([b]도감 → 보드판[/b])"]},
		{"title": "보너스 이동", "art": &"bonus", "tone": Color("63e6be"), "chips": ["굴림은 앞으로만"],
			"summary": "굴림은 언제나 앞으로 가요. 여러 보너스로 더 멀리 튀어 나가요.",
			"rows": [["리벤지 부스터", "잡혀서 출발선으로 간 말이 다시 나올 때 +%d칸" % GameData.revenge_bonus()], ["부스터 발판", "%s번에 딱 멈추면 +%d칸" % [dash, GameData.dash_steps()]], ["코너", "딱 멈추면 다음 굴림 +1"], ["템포 업", "판이 길어지면 차례 첫 이동 +1~3칸"], ["재굴림", "윷말은 적을 잡으면 한 번 더"]],
			"points": ["뒤로 가는 건 불 정령·폭발 물약 같은 정해진 효과뿐이에요"]},
		{"title": "증강 라운드", "art": &"augment_round", "tone": Color("ffa94d"), "chips": ["%d라운드부터" % first_draft, "3라운드마다"],
			"summary": "%d·%d·%d라운드처럼 3라운드마다, 라운드 시작에 모두가 동시에 3장 중 하나를 골라요." % [first_draft, first_draft + 3, first_draft + 6],
			"rows": [["처음부터", "기물 진화 · 판정 도구 · 카드 패키지 · 보급"], ["%d라운드(과열)부터" % stages[0], "특수 승리 법전 같은 고급 증강"], ["%d라운드(광기)부터" % stages[1], "판을 뒤흔드는 초증강"]],
			"points": ["카드 자리마다 한 번씩 다시 뽑을 수 있어요", "1~%d라운드는 기본 주사위로 규칙을 익혀요" % (first_draft - 1), "자세한 건 [b]도감 → 법전·보급·초증강[/b]"]},
		{"title": "템포 업", "art": &"tempo", "tone": Color("ff6b6b"), "chips": ["%d·%d·%d라운드" % [stages[0], stages[1], stages[2]]],
			"summary": "판이 길어지면 [b]게임이 점점 빨라져요[/b]. 단계가 오르는 라운드 시작에 크게 경고해요.",
			"rows": [["%d라운드 · 과열" % stages[0], "차례 첫 이동 +1칸 · 리벤지 +6칸 · 고급 증강 등장 · 법전이 비어 있으면 1개 자동 제정"], ["%d라운드 · 광기" % stages[1], "차례 첫 이동 +2칸 · 리벤지 +8칸 · 초증강 등장"], ["%d라운드 · 대붕괴" % stages[2], "전원 차례 첫 이동 +3칸"]],
			"points": ["방 규칙 스피드전은 %d·%d·%d라운드에 올라요" % [MatchRules.SPEED_STAGE_ROUNDS[0], MatchRules.SPEED_STAGE_ROUNDS[1], MatchRules.SPEED_STAGE_ROUNDS[2]], "결승선은 [b]슬슬 지루한데...[/b] 보급을 쓸 때만 당겨져요 (체크무늬 칸)", "%d라운드가 끝나면 남은 사람은 진행 순위로 순위 확정" % PacingDirector.HARD_CAP_ROUND]},
	]}


## 특수 칸: 모든 보드판에 공통인 칸 (출발·코너·반환점·부스터 발판·함정). 보드마다 다른 칸은 도감 → 보드판.
func _ch_tiles() -> Dictionary:
	var make_board: Callable = func() -> Control:
		return _board_panel(BoardSpec.board_id)
	var kinds: Array = _board_kind_rows()
	return {"title": "특수 칸", "entries": [
		{"title": "한눈에 보기", "art": &"board", "tone": Color("86d94f"), "chips": ["%d칸" % BoardSpec.tile_count, "반시계"],
			"summary": "우하단 0번에서 출발해 반시계로 한 바퀴. 다시 0번이 [b]결승선[/b]이에요.", "extra": make_board,
			"points": ["특수 칸은 대부분 [b]딱 멈출 때만[/b] 작동해요 (지나가기만 하면 그대로)", "출발선(0번)에는 함정을 깔 수 없고, 잡기도 없어요", "그림은 지금 고른 보드판이에요"]},
		{"title": "코너", "art": &"corner", "tone": Color("2f8f4e"), "chips": [_join_tiles(BoardSpec.corner_tiles.slice(1)) + "번"],
			"summary": "딱 멈추면 [b]다음 굴림 결과 +1[/b]! 단, 이 칸에 함정이 있으면 버프 대신 함정이 발동해요.",
			"points": ["[b]코너 전용 함정[/b]만 설치할 수 있는 칸이에요", "워프·잡기로 자리를 옮겼으면 버프는 없어요", "버프는 겹쳐 쌓이지 않아요"]},
		{"title": "반환점", "art": &"halfway", "tone": Color("c98a14"), "chips": ["%d번" % BoardSpec.halfway_tile],
			"summary": "한 바퀴의 절반이에요. 여기를 지나면 말이 강해져요.",
			"rows": [["체스 폰", "반환점 이상에 닿으면 [b]퀸[/b]으로 영구 승진"], ["쇼기 말", "반환점 이상을 지나면 승급(나리)"], ["모노폴리 비행기", "반환점을 지날 때마다 카드 +1"]]},
		{"title": "부스터 발판", "art": &"boost", "tone": Color("2fb59a"), "chips": [_join_tiles(BoardSpec.dash_tiles) + "번"],
			"summary": "굴린 눈금으로 딱 멈추면 %d칸 더 날아가요." % GameData.dash_steps(),
			"points": ["날아간 칸에서 다시 발판을 밟아도 한 번 더 날지는 않아요", "날아가는 동안 지나치는 호텔에는 붙잡히지 않아요", "모노폴리 미니카는 발판을 밟으면 카드 +1"]},
		{"title": "함정 칸", "texture": TextureCache.fetch("res://assets/board/traps/HIDDEN.png"), "tone": Color("7a5cd6"), "chips": ["한 칸에 하나"],
			"summary": "함정이 깔린 칸은 [b]보라색[/b]으로 바뀌고 그 함정 그림이 보여요.",
			"points": ["상대가 숨긴 함정은 물음표로 보여요 (방 규칙으로 모두 공개할 수도 있어요)", "코너 함정은 누구에게나 공개되고 정해진 라운드가 지나면 사라져요", "코너·빵집 자리·옷장 자리·부스터 발판에는 일반 함정을 깔 수 없어요"]},
		{"title": "보드마다 다른 칸", "art": &"board", "tone": Color("5fc1e8"), "chips": ["빵집 자리 4곳", "옷장 자리 2곳"],
			"summary": "빵집 자리와 옷장 자리에는 [b]보드판마다 다른 칸[/b]이 서요.",
			"rows": kinds, "points": ["모노폴리 강아지는 이 칸들을 지나가기만 해도 카드 +1", "자세한 건 [b]도감 → 보드판[/b]"]},
	]}


## [보드 이름, 빵집 자리·옷장 자리 칸 이름] 표.
static func _board_kind_rows() -> Array:
	var rows: Array = []
	for board: Dictionary in BoardCatalog.available():
		var names: PackedStringArray = []
		for kind_id: StringName in BoardCatalog.board_kinds(board["id"]):
			names.append(str(BoardCatalog.tile_kind(kind_id)["name"]))
		rows.append([str(board["name"]), " · ".join(names)])
	return rows


## 보드판: 고를 수 있는 보드판마다 한 장 (미리보기 그림, 판 그림, 그 보드만의 칸 설명).
func _ch_boards() -> Dictionary:
	var entries: Array = [
		{"title": "보드판 고르기", "art": &"board", "tone": Color("5fc1e8"), "chips": ["%d종" % BoardCatalog.available().size()],
			"summary": "보드판마다 [b]빵집 자리·옷장 자리[/b]에 서는 칸이 달라요.", "rows": _board_kind_rows(),
			"points": ["컴퓨터 대전 시작 화면과 [방 규칙 설정]에서 고를 수 있어요", "판을 시작하면 모두 같은 보드판을 써요", "출발·코너·반환점·부스터 발판은 모든 보드판이 같아요 (기본 규칙 → 특수 칸)"]},
	]
	for board: Dictionary in BoardCatalog.available():
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
			"summary": str(board["desc"]), "kind_names": kind_names, "board_id": id,
			"extra": _board_panel.bind(id), "blocks": blocks})
	return {"title": "보드판", "entries": entries, "wide": true}


## 보드판 그림: 작은 판(번호·색 칸·옷장 이동선)과 범례. 범례는 판 밖에 두어 이동선과 겹치지 않는다 (넓으면 옆, 좁으면 아래).
func _board_panel(board_id: StringName) -> Control:
	var row := HFlowContainer.new()
	row.name = "BoardPanel"
	row.add_theme_constant_override("h_separation", 18)
	row.add_theme_constant_override("v_separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var board := MiniBoard.new()
	board.board_id = board_id
	board.custom_minimum_size = Vector2(340, 340)
	board.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(board)
	var legend := VBoxContainer.new()
	legend.add_theme_constant_override("separation", 8)
	legend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legend.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	legend.custom_minimum_size = Vector2(300, 0)
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
		text.custom_minimum_size = Vector2(0, 0)
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
			"rows": [["잡기", "멈춘 쪽이 잡아요 (보통은 스치기만 하면 안 잡혀요)"], ["업힌 말", "함께 업혀 있던 말도 같이 날아가요"], ["출발선(0번)", "안전 지대: 잡을 수 없어요"], ["내 말끼리", "잡지 않고 업어요"]],
			"points": ["킹 체커·거대 멜론처럼 지나가며 잡는 말도 있어요", "백돌 보호막·방어 카드로 막을 수 있어요"],
			"tip": "완주 직전에 잡히면 억울해요. 선두 말은 적 앞을 조심!"},
		{"title": "말의 기본", "art": &"pawn_basics", "tone": Color("5fc1e8"), "chips": ["말 4개", "굴린 만큼 전진"],
			"summary": "내 말은 모두 [b]4개[/b]. 처음엔 전부 출발선(0번)에서 기다려요.",
			"rows": [["출발", "굴림 눈금만큼 한 말을 골라 내보내요"], ["이동", "눈금만큼 반시계로 한 칸씩 전진해요"], ["잡기", "적 말 위에 멈추면 그 말은 출발선으로"], ["잡히면", "출발선으로 돌아가 다시 출발해요 (리벤지 부스터)"], ["완주", "0번을 밟거나 넘으면 끝. 4개 모두 완주하면 순위 확정"]],
			"points": ["말마다 능력과 필살기가 달라요 ([b]도감 → 말[/b])", "보드 위 말에 마우스를 올리면 상태가 보여요"]},
		{"title": "업기", "art": &"pawn_basics", "tone": Color("63e6be"), "chips": ["내 말끼리", "함께 이동"],
			"summary": "내 말이 선 칸에 도착하면 [b]업을지[/b] 물어봐요. 업으면 하나로 합쳐 함께 움직여요.",
			"rows": [["업으면", "한 번 굴려 여러 말이 함께 전진 · 함께 완주"], ["대신", "잡히면 업힌 말까지 한꺼번에 출발선으로"], ["업기 자석", "이동이 끝난 칸 바로 앞·뒤에 내 말이 있으면 한 칸 당겨 자동으로 합류"]],
			"points": ["출발선에서는 업지 않아요", "업지 않고 같은 칸에 따로 서 있으면 말마다 따로 판정해요"]},
		{"title": "리벤지 부스터", "art": &"bonus", "tone": Color("ff8787"), "chips": ["+%d칸" % GameData.revenge_bonus()],
			"summary": "잡혀서 출발선으로 날아간 말은 다음에 다시 출발할 때 %d칸 더 가요." % GameData.revenge_bonus(),
			"points": ["한 번 쓰면 꺼져요", "템포 업 과열 +6칸, 광기부터 +8칸으로 커져요", "출발 전이던 말·완주한 말은 받지 않아요"]},
		{"title": "공격 카드", "art": &"attack", "tone": Color("ff6b6b"), "chips": ["발동 경보", "막을 수 있음"],
			"summary": "카드 설명에 [b][공격 발동][/b]이 붙은 카드예요. 상대의 말이나 차례를 직접 노리고, 쓰면 먼저 [b]공격 카드 발동![/b] 경보가 뜨고 어떤 카드인지 공개돼요.",
			"rows": [["말 날리기", "상대 말을 출발선으로 사출해요 (그 말에 업힌 말도 함께)"], ["자리 흔들기", "말 위치를 바꾸거나 설치물을 부숴요"], ["차례 방해", "상대의 카드·필살기를 막거나, 차례를 건너뛰게 하거나, 자동으로 진행시켜요"]],
			"points": ["맞은 사람은 [b]공격 방어[/b]·[b]만능 방어[/b] 카드로 막을 수 있어요", "상대를 약하게 해도 공격이 아닌 [b][너프 발동][/b] 카드는 막을 수 없어요", "사출 면역(기억상실빔 라운드)·수은 보호막이 있으면 날아가지 않아요", "카드마다 자세한 효과는 [b]도감 → 카드[/b]"]},
		{"title": "방어 카드", "art": &"defense", "tone": Color("74c0fc"), "chips": ["4가지"],
			"summary": "공격받으면 [b]막을 수 있는 방어 카드가 있을 때만[/b] 쓸지 물어봐요. 막는 공격에 따라 네 가지로 나뉘어요.",
			"rows": [["잡기 방어", "적 말이 내 말을 잡을 때"], ["공격 방어", "공격 카드에 맞을 때"], ["함정 방어", "내 말이 남의 함정에 걸렸을 때"], ["만능 방어", "어떤 공격이든"]],
			"points": ["공격 하나에 방어 카드 한 장", "공격한 사람의 차례 안에서만 막을 수 있어요. [그냥 맞기]를 고르면 그 공격엔 다시 못 써요", "막으면 맞기 직전으로 돌아가요: 말 위치·출발 여부·업기·감옥·보호막과 그 공격으로 오른 기록", "내 함정·내 카드·초증강으로 입은 피해는 공격이 아니라서 막을 수 없어요", "알고리즘 밴에 걸려 있으면 방어 창이 열리지 않아요"]},
		{"title": "잡기 방어", "art": &"defense", "tone": Color("74c0fc"), "chips": ["잡기만"],
			"summary": "적 말이 내 말이 선 칸에 멈춰 [b]잡으려 할 때[/b] 써요. 막으면 내 말은 그 자리에 남아요.",
			"rows": [["막는 방법", "카드마다 달라요: 그냥 피하기 · 덤으로 카드 1장 · 잡으러 온 적 말을 출발선으로 되돌려 보내기"], ["업힌 말", "한 번 막으면 함께 잡히던 말도 모두 무사해요"]],
			"points": ["공격 카드·함정에는 쓸 수 없어요", "잡으러 온 말을 되돌려 보내는 카드는 그 말이 아직 보드 위에 있어야 써요"]},
		{"title": "공격 방어", "art": &"defense", "tone": Color("74c0fc"), "chips": ["공격 카드만"],
			"summary": "상대가 낸 [b]공격 카드[/b]에 맞았을 때 써요. 그 카드의 효과가 나에게 오지 않아요.",
			"rows": [["막는 방법", "카드마다 달라요: 그냥 피하기 · 덤으로 카드 1장 · 맞은 카드를 내 손패로 빼앗기 · 공격자에게 되돌려 주기"], ["되돌려 주기", "밴·스킵 같은 카드는 공격자가 그대로 받고, 그 밖의 공격은 공격자의 선두 말이 출발선으로"]],
			"points": ["잡기와 함정은 막지 못해요"]},
		{"title": "함정 방어", "art": &"defense", "tone": Color("74c0fc"), "chips": ["남의 함정"],
			"summary": "내 말이 [b]남이 깐 함정[/b]에 걸렸을 때 써요. 내 차례에 걸려도 쓸 수 있어요.",
			"rows": [["막는 방법", "카드마다 달라요: 함정을 부수고 더 전진 · 함정을 무효로 하고 설치자의 카드 빼앗기 · 그 함정 카드를 내 손패로"]],
			"points": ["내가 깐 함정에 내 말이 걸린 건 막을 수 없어요"]},
		{"title": "만능 방어", "art": &"defense", "tone": Color("74c0fc"), "chips": ["무엇이든"],
			"summary": "잡기·공격 카드·함정 [b]어떤 공격이든[/b] 막아요. 공격한 사람의 차례를 통째로 되감고 그 차례를 끝내요.",
			"points": ["되감아도 손패는 돌아오지 않아요", "순위가 정해졌다면 순위도 그때로 돌아가요"]},
		{"title": "함정 카드", "art": &"trap_card", "tone": Color("b197fc"), "chips": ["칸에 깔기", "한 칸에 하나"],
			"summary": "칸을 골라 깔아 두는 카드예요. 누가 깔았는지만 알려지고 [b]어떤 함정인지는 비밀[/b]!",
			"rows": [["일반 함정", "코너·빵집 자리·옷장 자리·부스터 발판·출발선을 뺀 칸에 숨겨서 깔아요"], ["코너 함정", "코너에만 깔고 누구에게나 공개돼요. 정해진 라운드가 지나면 사라져요"], ["걸리는 때", "함정마다 달라요: 멈춰야 걸리는 것, 지나가기만 해도 걸리는 것, 큰 눈금으로 지나갈 때만 걸리는 것"], ["몇 번", "대부분 한 번 걸리면 사라져요 (여러 번 남는 함정도 있어요)"]],
			"points": ["대부분 적 말에게만 걸리지만, 폭발·연쇄처럼 내 말까지 휘말리는 함정도 있어요", "걸린 사람은 [b]함정 방어[/b]·[b]만능 방어[/b] 카드로 막을 수 있어요", "카드마다 자세한 효과는 [b]도감 → 카드[/b]"]},
		{"title": "숨은 함정", "art": &"hidden_trap", "tone": Color("b197fc"),
			"summary": "상대가 깐 함정은 [b]물음표[/b]로만 보여요. 밟아 보기 전엔 몰라요.",
			"points": ["내 함정은 내 화면에서 그림이 보여요"]},
	]}


## 방어 카드가 막는 공격 (카드 설명 앞의 [잡기 방어]·[공격 방어]·[함정 방어]·[만능 방어] 꼬리표와 같다).
const COUNTER_KINDS: Dictionary = {
	&"CNT_01": "만능 방어: 어떤 공격이든",
	&"CNT_02": "잡기 방어: 적 말이 내 말을 잡을 때", &"CNT_08": "잡기 방어: 적 말이 내 말을 잡을 때", &"CNT_09": "잡기 방어: 적 말이 내 말을 잡을 때",
	&"CNT_03": "공격 방어: 공격 카드에 맞을 때", &"CNT_04": "공격 방어: 공격 카드에 맞을 때", &"CNT_10": "공격 방어: 공격 카드에 맞을 때", &"CNT_11": "공격 방어: 공격 카드에 맞을 때",
	&"CNT_05": "함정 방어: 내 말이 남의 함정에 걸렸을 때", &"CNT_06": "함정 방어: 내 말이 남의 함정에 걸렸을 때", &"CNT_07": "함정 방어: 내 말이 남의 함정에 걸렸을 때",
}


## 발동 카드 세부 종류의 뜻 (카드 장 상세 표).
const ACTIVATE_NOTES: Dictionary = {
	"공격 발동": "공격 경보가 뜨고 공격 방어로 막힐 수 있어요",
	"버프 발동": "내 말이나 내 굴림을 도와요",
	"너프 발동": "상대를 약하게 하지만 공격은 아니라서 막을 수 없어요",
	"기타 발동": "모두에게 걸리거나 걸린 상태를 풀어요",
}


static func _counter_kind(card_id: StringName) -> String:
	return str(COUNTER_KINDS.get(card_id, "공격받았을 때"))


func _ch_tools() -> Dictionary:
	var entries: Array = [
		{"title": "굴리는 도구", "art": &"tool_swap", "tone": Color("86d94f"), "chips": ["증강으로 교체"],
			"summary": "처음엔 [b]기본 주사위[/b](1~6칸). 증강의 [b]판정 도구 교체[/b]로 오른쪽 도구 중 하나로 바꿀 수 있어요.",
			"rows": [["한 방", "친치로 · 777 슬롯"], ["안정", "윷 · 야추"], ["짜릿함", "러시안 룰렛 · 블랙잭"]],
			"points": ["오른쪽 카드를 누르면 족보와 칸 수 표가 나와요", "주사위·윷·친치로·야추·핀볼은 버튼을 꾹 눌러 세기를 모아 던져요"],
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
		var brief: String = passive.split("\n")[0] if passive != "" else (PawnCatalog.skill_name(skill) if skill != &"" else "")
		entries.append({"title": PawnCatalog.unit_label(kind, unit).split(":")[-1], "augment": definition.augment_id, "texture": _pawn_texture(sub, kind), "icon": &"crown",
			"tone": Color("20c997"), "chips": chips, "summary": PAWN_LINES.get(kind, ""), "brief": brief, "rows": rows})
	return {"title": "말", "entries": entries, "wide": true}


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
			"summary": "방어 카드를 뺀 모든 카드는 내 차례 [b]굴리기 전에[/b] 보드판으로 끌어다 놓아 써요. 카드 설명 맨 앞의 [b][ ] 머리표[/b]가 세부 종류예요.",
			"rows": [["방어 (파랑)", "공격받으면 팝업에서 쓸지 물어봐요 · 잡기·공격·함정·만능 방어"], ["발동 (노랑)", "놓으면 바로 효과 · 아래 네 종류"], ["공격 발동", "상대를 노려요. 공격 경보가 뜨고 [b]공격 방어[/b]로 막힐 수 있어요"], ["버프 발동", "내 말이나 내 굴림을 도와요"], ["너프 발동", "상대를 약하게 하지만 공격은 아니라서 막을 수 없어요"], ["기타 발동", "모두에게 걸리거나 걸린 상태를 풀어요"], ["함정 (보라)", "칸을 골라 숨겨 깔기 · 코너 함정은 코너에 공개로"], ["소환 (분홍)", "상단 코너에 중립 기물을 불러내요 · 라운드 끝마다 움직여요"]],
			"tip": "일기토 데스매치는 [b]상대 프로필이나 말 위에[/b] 놓으면 그 상대와 붙어요. 종목은 6종 중 무작위!"},
	]
	for card_id: StringName in CardRegistry.DECK_COMPOSITION.keys():
		var card: BaseCard = CardRegistry.get_card(card_id)
		var tone: Color = Color("f0c14e")
		# 쓰는 때(굴리기 전 / 공격받을 때)는 종류마다 같아 카드 쓰는 법 한 곳에만 적고, 카드마다는 세부 종류만 보여 준다 (1.3.1)
		var rows: Array = []
		match card.category:
			GameEnums.CardCategory.COUNTER:
				tone = Color("74c0fc")
				rows.append(["막는 공격", _counter_kind(card_id)])
			GameEnums.CardCategory.INSTANT:
				var kind: String = MainBoard.activate_kind(card_id)
				rows.append(["종류", "%s: %s" % [kind, ACTIVATE_NOTES.get(kind, "")]])
			GameEnums.CardCategory.TRAP:
				tone = Color("b197fc")
				rows.append(["방법", "보드에 끌어 놓고 %s 고르기" % ("코너" if card.corner_only else "칸")])
			GameEnums.CardCategory.SUMMON:
				tone = Color("f08aa8")
		var quote: String = GameData.text("cards", card_id, "parody_quote")
		var data: Dictionary = {"title": card.display_name, "card": card_id, "texture": TextureCache.fetch("res://assets/cards/%s.png" % card_id), "icon": &"book", "tone": tone,
			"chips": [MainBoard.category_label(card), "%d장" % int(CardRegistry.DECK_COMPOSITION[card_id])],
			"summary": MainBoard.card_summary(card_id).replace("\n", " "),
			"rows": rows}
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
		{"title": "증강과 법전", "art": &"lawbook", "tone": Color("ffa94d"), "chips": ["3라운드마다", "법전 4칸"],
			"summary": "%d·%d·%d라운드처럼 3라운드마다 모두가 증강 3장 중 하나를 골라요. 법전의 교칙은 모두 특수 승리 조건이에요." % [GameEnums.DRAFT_START, GameEnums.DRAFT_START + 3, GameEnums.DRAFT_START + 6],
			"rows": [["기물 지급", "말 하나를 새 기물로 진화 (도감 → 말)"], ["도구 교체", "굴리는 도구 바꾸기 (도감 → 도구)"], ["특수 승리", "법전에 새 승리 조건 (%d라운드 과열부터)" % TempoUp.STAGE_ROUNDS[0]], ["카드 패키지", "생떼 카드 여러 장 (도감 → 보급)"], ["범용 보급", "기물 변이 · 전군 돌연변이 · 필살기 리필 (도감 → 보급)"], ["초증강", "하이리스크 하이리턴 (도감 → 초증강)"]],
			"points": ["내 차례가 끝날 때 교칙 조건을 달성해 있으면 [b]특수 승리![/b] 그 교칙은 사라져요 (같은 교칙을 여럿이 채우면 레이스에서 앞선 한 명만). 단 [b]보드연성진[/b]은 조건 달성 후 다음 내 차례가 끝날 때까지 유지해야 해요", "새 교칙이 들어오면 가장 오래된 교칙이 밀려나요", "증강 카드마다 한 번 다시 뽑기"],
			"tip": "법전 슬롯에 마우스를 올리면 모두의 진행도가 보여요. [color=#d6336c][b][위험!][/b][/color] 표시를 견제하세요!"},
	]
	for definition: AugmentDef in _augments(GameEnums.AugmentCategory.LAW_ENACT):
		var law: VictoryLaw = LawRegistry.create(String(definition.payload)) as VictoryLaw
		if law == null:
			continue
		var counting: String = "법전에 있는 동안만 세요" if VictoryLaw.SESSION_KEYS.has(law.stat_key) else "게임 내내 쌓여요"
		entries.append({"title": law.law_name, "augment": definition.augment_id, "law_id": law.law_id, "texture": AugmentArt.load_first(AugmentArt.law_candidates(law.law_id)), "icon": &"book",
			"tone": Color("ffd43b"), "chips": ["목표 %d%s" % [law.goal(), law.unit()]], "summary": law.condition_text(),
			"rows": [["판정", "조건 달성 후 다음 내 차례가 끝날 때까지 유지하면 특수 승리! 교칙은 사라져요" if law.law_id == SpecialVictory.SIEGE_LAW else "내 차례가 끝날 때 조건을 달성해 있으면 특수 승리! 교칙은 사라져요"], ["기록", counting], ["이의 있음!", "기록을 0으로 되돌릴 수 %s" % ("있어요" if law.resettable() else "없어요")]]})
	return {"title": "법전", "entries": entries, "wide": true}


## 범용: 생떼 카드 패키지와 범용 보급 (법전 장에서 따로 뺐다).
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
	return {"title": "보급", "entries": entries, "wide": true}


## 증강 카드 한 장을 도감 항목으로: 첫 줄은 요약, 나머지 ◆ 줄은 항목 점.
static func _augment_entry(definition: AugmentDef, icon: StringName) -> Dictionary:
	var info: Dictionary = MainBoard.augment_card_info(definition, null, 1)
	var lines: Array = str(info["desc"]).split("\n")
	return {"title": str(info["title"]), "augment": definition.augment_id, "texture": info.get("art"), "icon": icon, "tone": info["color"],
		"chips": [str(info["category"])], "summary": str(lines[0]).trim_prefix("◆ "), "points": lines.slice(1).map(func(line: String) -> String: return line.trim_prefix("◆ "))}


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
			entry["rows"] = [["주의", SuperAugments.SELF_RISK_NOTE.trim_prefix("주의: ")]]  # 카드 왼쪽 위에는 경고 아이콘 (카드와 같은 방식)
		entries.append(entry)
	return {"title": "초증강", "entries": entries, "wide": true}


# ---------------------------------------------------------------------------
# 그림 부품: 줄 노트 종이, 월계수, 금 메달, 아래 리본
# ---------------------------------------------------------------------------

## 크림색 종이에 옅은 가로줄이 그어진 노트 쪽.
class LinedPaper extends Control:
	func _draw() -> void:
		draw_texture_rect(VISUALS.texture(&"paper"),Rect2(Vector2.ZERO,size),false)


## 타일 번호 목록을 `4·10·14` 꼴로 이어 붙인다.
static func _join_tiles(tiles: Array) -> String:
	var parts: Array[String] = []
	for tile: Variant in tiles:
		parts.append(str(int(tile)))
	return "·".join(parts)


## 책 아래쪽에 걸친 주황 리본 (쪽 번호가 올라간다).
class Ribbon extends Control:
	func _draw() -> void:
		draw_texture_rect(VISUALS.texture(&"ribbon"),Rect2(Vector2.ZERO,size),false)


# ---------------------------------------------------------------------------
# 미니 보드 그림
# ---------------------------------------------------------------------------

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
