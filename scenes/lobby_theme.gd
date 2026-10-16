# File: res://scenes/lobby_theme.gd
# Class: class_name LobbyTheme
# Role: 시작 메뉴·로비 화면이 함께 쓰는 밝은 민트/청록 테마 부품. 구름무늬 배경, 위·아래 청록 띠(뒤로가기·제목·규칙 / 이름·설정), 굵은 카드형 모드 버튼, 이중 테두리 큰 버튼, 팝업 틀, 규칙·설정 팝업을 만든다
class_name LobbyTheme
extends RefCounted

const TEAL: Color = Color("008f6b")
const TEAL_DARK: Color = Color("006b50")
const MINT: Color = Color("ecfff0")
const MINT_EDGE: Color = Color("5fc9a6")
const INPUT_BG: Color = Color("eeffa8")
const BLUE: Color = Color("00708f")
const BLUE_PALE: Color = Color("efeeff")
const PINK: Color = Color("dc6699")
const PINK_PALE: Color = Color("ffeef0")
const CREAM: Color = Color("ffe9b8")
const CREAM_EDGE: Color = Color("d9b97a")
const INK: Color = Color("1b4d3e")
const INK_SOFT: Color = Color("3d6b5c")
const BAR_HEIGHT: float = 34.0
const RULES_TEXT: String = """목표: 내 말 4개를 먼저 완주시키면 승리합니다.
턴 진행: 카드/함정 사용 -> 판정 도구 굴리기 -> 이동할 말 고르기 -> 정산(개입 카드).
판정 도구: 주사위·룰렛·홀덤·화투·마작·타로 등 도구마다 규칙이 다르고, 카드에 규칙표가 나옵니다.
기물: 말마다 고유 능력과 1회용 필살기가 있고, 증강 드래프트(3라운드마다)로 기물·도구·교칙·카드를 얻습니다.
카드: 굴리기 전에 턴당 1장만 쓸 수 있습니다. 피해를 입으면 [바이츠 더 더스트]로 되돌릴 수 있습니다.
교칙: 가운데 법전은 4슬롯이고 가득 차면 가장 오래된 교칙이 밀려납니다.
메뉴: 게임 중 ESC 또는 우측 상단 [메뉴]에서 설정·나가기를 고릅니다."""


static func style(bg: Color, border: Color, border_width: int, radius: int, shadow: int = 0, margin: int = 0, shadow_color: Color = Color(0, 0, 0, 0.22)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.shadow_color = shadow_color
	box.shadow_size = shadow
	box.set_content_margin_all(margin)
	return box


static func label(text: String, size_px: int, color: Color = INK) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", size_px)
	item.add_theme_color_override("font_color", color)
	return item


## 구름무늬 민트 배경 (잔물결 소음 + 부드러운 그라데이션). 부모의 가장 아래에 깔린다.
static func add_background(parent: Control, greener: bool = false) -> void:
	var base := ColorRect.new()
	base.color = Color("a8e6cf") if not greener else Color("8fd35a")
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(base)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.006
	noise.fractal_octaves = 3
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color("7fdcbd") if not greener else Color("b4ee6e"), Color("c7f6e6") if not greener else Color("eaffd0"), Color("f1fffa")])
	ramp.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.color_ramp = ramp
	texture.width = 512
	texture.height = 384
	var clouds := TextureRect.new()
	clouds.texture = texture
	clouds.stretch_mode = TextureRect.STRETCH_SCALE
	clouds.set_anchors_preset(Control.PRESET_FULL_RECT)
	clouds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(clouds)


## 위쪽 청록 띠: [뒤로가기] 제목 ............ [규칙]. 반환: {"bar", "back", "title", "right"}
static func add_top_bar(parent: Control, title_text: String, on_back: Callable, right_text: String, on_right: Callable) -> Dictionary:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	bar.add_theme_stylebox_override("panel", style(TEAL, TEAL_DARK, 0, 0, 0, 3))
	parent.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	bar.add_child(row)
	var back := pale_button("", on_back, 14)
	back.custom_minimum_size = Vector2(100, 0)
	back.name = "BackButton"
	var arrow := ArrowIcon.new()
	arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(arrow)
	row.add_child(back)
	var title := label(title_text, 17, Color.WHITE)
	title.name = "BarTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	var right := pale_button(right_text, on_right, 14)
	right.custom_minimum_size = Vector2(180, 0)
	right.name = "RulesButton"
	row.add_child(right)
	return {"bar": bar, "back": back, "title": title, "right": right}


## 아래쪽 청록 띠: 내 이름(왼쪽) ... [설정](가운데). 반환: {"bar", "name", "center"}
static func add_bottom_bar(parent: Control, name_text: String, center_text: String, on_center: Callable) -> Dictionary:
	var bar := PanelContainer.new()
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_top = -BAR_HEIGHT
	bar.offset_bottom = 0.0
	bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	bar.add_theme_stylebox_override("panel", style(TEAL, TEAL_DARK, 0, 0, 0, 3))
	parent.add_child(bar)
	var row := HBoxContainer.new()
	bar.add_child(row)
	var name_label := label(name_text, 16, Color.WHITE)
	name_label.name = "PlayerName"
	name_label.custom_minimum_size = Vector2(300, 0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	var left_fill := Control.new()
	left_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left_fill)
	var center := pale_button(center_text, on_center, 14)
	center.custom_minimum_size = Vector2(180, 0)
	center.name = "SettingsButton"
	row.add_child(center)
	var right_fill := Control.new()
	right_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right_fill)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(300, 0)
	row.add_child(spacer)
	return {"bar": bar, "name": name_label, "center": center}


## 띠 위에 얹는 연한 민트색 둥근 버튼.
static func pale_button(text: String, callback: Callable, size_px: int = 14) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", size_px)
	button.add_theme_color_override("font_color", TEAL)
	button.add_theme_color_override("font_hover_color", TEAL_DARK)
	button.add_theme_stylebox_override("normal", style(MINT, MINT, 0, 8, 0, 2))
	button.add_theme_stylebox_override("hover", style(Color.WHITE, MINT, 0, 8, 0, 2))
	button.add_theme_stylebox_override("pressed", style(Color("d4f5e4"), MINT, 0, 8, 0, 2))
	button.add_theme_stylebox_override("disabled", style(Color("b9d9c9"), MINT, 0, 8, 0, 2))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if callback.is_valid():
		button.pressed.connect(callback)
	UiSkin.button(button, false, 2.0, 2.0)
	return button


## 이중 테두리(흰 줄 + 바깥 고리)의 굵은 둥근 버튼 ("탄생하기" 스타일).
static func big_button(text: String, callback: Callable, size_px: int = 34, fill: Color = TEAL, text_color: Color = MINT) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, maxi(size_px + 30, 56))
	button.add_theme_font_size_override("font_size", size_px)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.6))
	button.add_theme_stylebox_override("normal", style(fill, Color.WHITE, 3, 20, 4, 6, fill))
	button.add_theme_stylebox_override("hover", style(fill.lightened(0.12), Color.WHITE, 3, 20, 5, 6, fill))
	button.add_theme_stylebox_override("pressed", style(fill.darkened(0.15), Color.WHITE, 3, 20, 2, 6, fill))
	button.add_theme_stylebox_override("disabled", style(fill.lerp(Color("9aa5a0"), 0.6), Color(1, 1, 1, 0.7), 3, 20, 0, 6, fill))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if callback.is_valid():
		button.pressed.connect(callback)
	UiSkin.button(button, true, 6.0, 6.0)
	return button


## 크림색 시작 버튼 ("배틀 시작하기" 스타일).
static func cream_button(text: String, callback: Callable, size_px: int = 34) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, maxi(size_px + 30, 56))
	button.add_theme_font_size_override("font_size", size_px)
	button.add_theme_color_override("font_color", Color("5a5a5a"))
	button.add_theme_color_override("font_hover_color", Color("2b2b2b"))
	button.add_theme_color_override("font_disabled_color", Color("9a9a9a"))
	button.add_theme_stylebox_override("normal", style(CREAM, CREAM_EDGE, 4, 18, 0, 6))
	button.add_theme_stylebox_override("hover", style(Color("fff3d1"), CREAM_EDGE, 4, 18, 0, 6))
	button.add_theme_stylebox_override("pressed", style(Color("f0d9a0"), CREAM_EDGE, 4, 18, 0, 6))
	button.add_theme_stylebox_override("disabled", style(Color("e6dcc4"), Color("c9bc9d"), 4, 18, 0, 6))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if callback.is_valid():
		button.pressed.connect(callback)
	UiSkin.button(button, true, 6.0, 6.0)
	return button


## 작은 둥근 버튼 (슬롯 옆 [AI 봇으로 채우기] 같은 보조 버튼). tone: &"teal"/&"blue"/&"pink"/&"gray"
static func small_button(text: String, callback: Callable, tone: StringName = &"teal", size_px: int = 14) -> Button:
	var fill: Color = {&"teal": TEAL, &"blue": BLUE, &"pink": PINK, &"gray": Color("6b8f82")}.get(tone, TEAL)
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 34)
	button.add_theme_font_size_override("font_size", size_px)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.6))
	button.add_theme_stylebox_override("normal", style(fill, Color.WHITE, 2, 12, 0, 8))
	button.add_theme_stylebox_override("hover", style(fill.lightened(0.15), Color.WHITE, 2, 12, 0, 8))
	button.add_theme_stylebox_override("pressed", style(fill.darkened(0.2), Color.WHITE, 2, 12, 0, 8))
	button.add_theme_stylebox_override("disabled", style(fill.lerp(Color("9aa5a0"), 0.6), Color(1, 1, 1, 0.6), 2, 12, 0, 8))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if callback.is_valid():
		button.pressed.connect(callback)
	UiSkin.button(button, false, 8.0, 8.0)
	return button


## 굵은 모드 카드 한 장: 큰 제목 / 색 띠(오른쪽 정렬 글씨) / 작은 설명. kind: &"blue"(훈련) / &"green"(비밀 결투) / &"pink"(랜덤 결투)
static func card(node_name: String, title_text: String, band_text: String, sub_text: String, kind: StringName, callback: Callable) -> Button:
	var palette: Dictionary = {
		&"blue": {"bg": BLUE_PALE, "edge": BLUE, "title": BLUE, "band_bg": BLUE, "band_text": Color.WHITE, "sub": BLUE},
		&"green": {"bg": TEAL, "edge": Color.WHITE, "title": Color.WHITE, "band_bg": MINT, "band_text": TEAL, "sub": Color.WHITE},
		&"pink": {"bg": PINK_PALE, "edge": PINK, "title": PINK, "band_bg": PINK, "band_text": Color.WHITE, "sub": PINK},
	}[kind]
	var button := Button.new()
	button.name = node_name
	button.custom_minimum_size = Vector2(500, 178)
	button.focus_mode = Control.FOCUS_NONE
	var normal: StyleBoxFlat = style(palette["bg"], palette["edge"], 5, 34, 6, 0)
	if kind == &"green":
		normal.border_color = Color.WHITE
		normal.shadow_color = TEAL
		normal.shadow_size = 4
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = (palette["bg"] as Color).lightened(0.08)
	button.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = (palette["bg"] as Color).darkened(0.08)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.offset_left = 6
	column.offset_right = -6
	column.offset_top = 4
	column.offset_bottom = -4
	button.add_child(column)
	var head := label(title_text, 60, palette["title"])
	head.name = "CardTitle"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.0))
	column.add_child(head)
	var band := PanelContainer.new()
	band.add_theme_stylebox_override("panel", style(palette["band_bg"], palette["band_bg"], 0, 0, 0, 4))
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(band)
	var band_label := label(band_text, 26, palette["band_text"])
	band_label.name = "CardBand"
	band_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	band_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(band_label)
	var sub := label(sub_text, 22, palette["sub"])
	sub.name = "CardSub"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(sub)
	if callback.is_valid():
		button.pressed.connect(callback)
	return button


## 노란 연두색 입력창.
static func input_field(placeholder: String, size_px: int = 24, max_chars: int = 0) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.custom_minimum_size = Vector2(0, 46)
	edit.add_theme_font_size_override("font_size", size_px)
	edit.add_theme_color_override("font_color", TEAL)
	edit.add_theme_color_override("font_placeholder_color", Color(0, 0.56, 0.42, 0.45))
	edit.add_theme_color_override("caret_color", TEAL_DARK)
	edit.add_theme_stylebox_override("normal", style(INPUT_BG, Color("86a64a"), 2, 8, 0, 8))
	edit.add_theme_stylebox_override("focus", style(INPUT_BG, TEAL, 3, 8, 0, 8))
	edit.add_theme_stylebox_override("read_only", style(Color("dfe8c4"), Color("86a64a"), 2, 8, 0, 8))
	if max_chars > 0:
		edit.max_length = max_chars
	return edit


## 화면 전체를 어둡게 덮고 가운데에 민트색 둥근 팝업을 띄운다. 반환: {"overlay", "box"(내용을 담는 VBox)}. 바깥을 누르면 닫힌다.
static func popup(parent: Control, width: float = 480.0) -> Dictionary:
	var overlay := Control.new()
	overlay.name = "Popup"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 50
	var dim := ColorRect.new()
	dim.color = Color(0, 0.1, 0.07, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			overlay.queue_free())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	panel.add_theme_stylebox_override("panel", UiSkin.panel("panel", 22.0))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	parent.add_child(overlay)
	return {"overlay": overlay, "box": box}


## 규칙 안내 팝업.
static func show_rules(parent: Control) -> void:
	var parts: Dictionary = popup(parent, 620.0)
	var box: VBoxContainer = parts["box"]
	box.add_child(label("게임 규칙", 26, TEAL))
	var text := label(RULES_TEXT, 15, INK)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(570, 0)
	box.add_child(text)
	var close := big_button("닫기", (parts["overlay"] as Control).queue_free, 22)
	box.add_child(close)


## 설정 팝업(전체화면, 행동 사이 연출 멈춤, 보드 시점).
static func show_settings(parent: Control) -> void:
	var parts: Dictionary = popup(parent, 520.0)
	var box: VBoxContainer = parts["box"]
	box.add_child(label("설정", 26, TEAL))
	var fullscreen := big_button("전체화면 켜기/끄기", func() -> void: MobileSupport.toggle_fullscreen(), 20)
	box.add_child(fullscreen)
	var pacing := CheckBox.new()
	pacing.name = "PacingCheck"
	pacing.text = "행동 사이에 잠깐 멈춰 보여 주기 (턴 알림·이동 뒤 호흡)"
	pacing.button_pressed = GameSession.pacing_enabled
	pacing.add_theme_color_override("font_color", INK)
	pacing.add_theme_color_override("font_hover_color", INK)
	pacing.add_theme_color_override("font_pressed_color", INK)
	pacing.toggled.connect(func(enabled: bool) -> void:
		GameSession.pacing_enabled = enabled
		GameSession.save_settings())
	box.add_child(pacing)
	var pace_row := HBoxContainer.new()
	pace_row.add_theme_constant_override("separation", 8)
	box.add_child(pace_row)
	pace_row.add_child(label("연출 속도", 16, INK))
	var pace := OptionButton.new()
	pace.name = "PaceOption"
	pace.add_item("빠르게")
	pace.add_item("보통")
	pace.add_item("느리게")
	pace.select(0 if GameSession.pace_scale <= 1.2 else (2 if GameSession.pace_scale >= 2.1 else 1))
	pace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pace.item_selected.connect(func(index: int) -> void:
		GameSession.pace_scale = [GameSession.PACE_FAST, GameSession.PACE_NORMAL, GameSession.PACE_SLOW][index]
		GameSession.save_settings())
	pace_row.add_child(pace)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	row.add_child(label("보드 시점", 16, INK))
	var view := OptionButton.new()
	view.name = "ViewMode"
	view.add_item("탑뷰 (위에서 내려다봄)")
	view.add_item("기울인 탑뷰 (테이블)")
	view.select(GameSession.view_mode)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.item_selected.connect(func(index: int) -> void:
		GameSession.view_mode = index
		GameSession.save_settings())
	row.add_child(view)
	box.add_child(big_button("닫기", (parts["overlay"] as Control).queue_free, 22))


## 위쪽 띠의 뒤로가기 화살표 (폰트에 없는 글자 대신 직접 그린다).
class ArrowIcon extends Control:
	func _draw() -> void:
		var middle: float = size.y / 2.0
		var left: float = size.x / 2.0 - 12.0
		var color: Color = TEAL
		draw_line(Vector2(left, middle), Vector2(left + 24.0, middle), color, 3.0, true)
		draw_line(Vector2(left, middle), Vector2(left + 8.0, middle - 7.0), color, 3.0, true)
		draw_line(Vector2(left, middle), Vector2(left + 8.0, middle + 7.0), color, 3.0, true)
