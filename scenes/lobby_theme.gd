# File: res://scenes/lobby_theme.gd
# Class: class_name LobbyTheme
# Role: 시작 메뉴·로비 공통 부품. 무작위 풍경 배경, 위·아래 띠, 모드 카드, 버튼과 팝업을 만든다.
class_name LobbyTheme
extends RefCounted

const BACKGROUND_SCRIPT: Script = preload("res://scenes/lobby_background.gd")

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


## 제공된 풍경 4장 중 1장 + 배경 전용 약한 블러. 시작 메뉴와 방 로비에 공통 적용.
static func add_background(parent: Control, _greener: bool = false) -> void:
	var background: Control = BACKGROUND_SCRIPT.new()
	background.name = "LobbyBackground"
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(background)


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


## 굵은 모드 카드 한 장: 큰 제목 / 색 띠(오른쪽 정렬 글씨) / 작은 설명. kind: &"blue"(놀이터) / &"green"(친선 줘팸터) / &"pink"(익명 줘팸터)
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
	Rulebook.open(parent)


## 설정 팝업(화면·소리 + 기본값으로 되돌리기).
static func show_settings(parent: Control) -> void:
	var parts: Dictionary = popup(parent, 520.0)
	var overlay: Control = parts["overlay"]
	var box: VBoxContainer = parts["box"]
	box.add_child(label("설정", 26, TEAL))
	add_settings_controls(box, INK)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	var reset := big_button("기본값으로", func() -> void:
		reset_settings()
		overlay.queue_free()
		show_settings(parent), 18, Color("6c757d"))
	reset.name = "ResetSettings"
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(reset)
	var close := big_button("닫기", overlay.queue_free, 20)
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(close)


## 설정 화면 공통 내용: [화면] 전체화면·화면 흔들림·배터리 절약 / [소리] 전체·효과음·배경음악. 시작 화면 팝업과 게임 메뉴가 같이 쓴다.
static func add_settings_controls(box: Container, ink: Color) -> void:
	box.add_child(_section_label("화면", ink))
	_add_switch(box, ink, "FullscreenSwitch", "전체화면", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, func(on: bool) -> void:
		if on != (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN):
			MobileSupport.toggle_fullscreen())
	_add_switch(box, ink, "ShakeSwitch", "화면 흔들림", GameSession.screen_shake, func(on: bool) -> void:
		GameSession.screen_shake = on
		GameSession.save_settings())
	_add_switch(box, ink, "BatterySwitch", "배터리 절약 (초당 30프레임)", GameSession.battery_saver, func(on: bool) -> void:
		GameSession.battery_saver = on
		GameSession.apply_frame_limit()
		GameSession.save_settings())
	box.add_child(_section_label("소리", ink))
	add_audio_controls(box, ink)


## [기본값으로]: 소리·화면 설정을 처음 값으로 되돌리고 바로 적용한다.
static func reset_settings() -> void:
	GameSession.reset_settings()
	Sfx.apply_settings()


static func _section_label(text: String, ink: Color) -> Label:
	var item: Label = label(text, 15, ink)
	item.modulate = Color(1, 1, 1, 0.65)
	return item


## 한 줄: [이름 ........ 스위치]. 누르면 바로 적용된다.
static func _add_switch(box: Container, ink: Color, switch_name: String, title: String, value: bool, on_toggled: Callable) -> void:
	var switch := CheckButton.new()
	switch.name = switch_name
	switch.text = title
	switch.button_pressed = value
	style_switch(switch, ink)
	switch.toggled.connect(func(on: bool) -> void:
		on_toggled.call(on)
		Sfx.play(&"ui_click"))
	box.add_child(switch)


## 설정 화면 스위치 모양(글자 색·크기, 초록/회색 스위치 그림).
static func style_switch(switch: CheckButton, ink: Color) -> void:
	switch.add_theme_font_size_override("font_size", 16)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		switch.add_theme_color_override(key, ink)
	for key: String in ["checked", "checked_mirrored"]:
		switch.add_theme_icon_override(key, _switch_icon(true))
	for key: String in ["unchecked", "unchecked_mirrored"]:
		switch.add_theme_icon_override(key, _switch_icon(false))


static var _switch_icons: Dictionary = {}


## 켜짐(초록 바탕, 손잡이 오른쪽) / 꺼짐(회색 바탕, 손잡이 왼쪽) 스위치 그림. 한 번 만들어 같이 쓴다.
static func _switch_icon(on: bool) -> Texture2D:
	if _switch_icons.has(on):
		return _switch_icons[on]
	var width: int = 52
	var height: int = 28
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var track: Color = Color("2fb36b") if on else Color("adb5bd")
	var radius: float = height / 2.0
	var knob := Vector2(width - radius if on else radius, radius)
	for y: int in height:
		for x: int in width:
			var point := Vector2(x + 0.5, y + 0.5)
			var nearest := Vector2(clampf(point.x, radius, width - radius), radius)
			var track_alpha: float = clampf(radius - point.distance_to(nearest) + 0.5, 0.0, 1.0)
			var knob_alpha: float = clampf(radius - 3.0 - point.distance_to(knob) + 0.5, 0.0, 1.0)
			var color: Color = track.lerp(Color.WHITE, knob_alpha)
			color.a = track_alpha
			image.set_pixel(x, y, color)
	var texture := ImageTexture.create_from_image(image)
	_switch_icons[on] = texture
	return texture


## 소리 설정(전체·효과음·배경음악: 이름 옆 음소거 버튼 + 같은 크기의 볼륨 바). 전체 음소거는 게임 화면 위쪽 [소리] 버튼과 같은 값이다.
static func add_audio_controls(box: Container, ink: Color) -> void:
	_add_volume_row(box, ink, "전체 음량", "MasterVolume", "MasterMute", GameSession.master_volume, GameSession.audio_muted,
		func(value: float) -> void: GameSession.master_volume = value,
		func(muted: bool) -> void: GameSession.audio_muted = muted, true)
	_add_volume_row(box, ink, "효과음 크기", "SfxVolume", "SfxMute", GameSession.sfx_volume, GameSession.sfx_muted,
		func(value: float) -> void: GameSession.sfx_volume = value,
		func(muted: bool) -> void: GameSession.sfx_muted = muted, true)
	_add_volume_row(box, ink, "배경음악 크기", "BgmVolume", "BgmMute", GameSession.bgm_volume, GameSession.bgm_muted,
		func(value: float) -> void: GameSession.bgm_volume = value,
		func(muted: bool) -> void: GameSession.bgm_muted = muted, false)


## 한 줄: [이름][음소거 버튼][볼륨 바]. 두 줄 모두 이름 칸 폭과 버튼 폭이 같아 바 크기가 똑같다.
static func _add_volume_row(box: Container, ink: Color, title: String, slider_name: String, mute_name: String, volume: float, muted: bool, set_volume: Callable, set_muted: Callable, click_on_release: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var name_label: Label = label(title, 16, ink)
	name_label.custom_minimum_size = Vector2(112.0, 0.0)
	row.add_child(name_label)
	var mute := Button.new()
	mute.name = mute_name
	mute.toggle_mode = true
	mute.text = "음소거"
	mute.custom_minimum_size = Vector2(74.0, 28.0)
	mute.add_theme_font_size_override("font_size", 13)
	mute.button_pressed = muted
	mute.modulate = Color(1.0, 0.7, 0.7) if muted else Color.WHITE
	row.add_child(mute)
	var slider := HSlider.new()
	slider.name = slider_name
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = volume
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(0.0, 28.0)
	slider.value_changed.connect(func(value: float) -> void:
		set_volume.call(value)
		GameSession.save_settings()
		Sfx.apply_settings())
	if click_on_release:
		slider.drag_ended.connect(func(_changed: bool) -> void: Sfx.play(&"ui_click"))
	row.add_child(slider)
	mute.toggled.connect(func(on: bool) -> void:
		set_muted.call(on)
		mute.modulate = Color(1.0, 0.7, 0.7) if on else Color.WHITE
		slider.modulate = Color(1, 1, 1, 0.45) if on else Color.WHITE
		GameSession.save_settings()
		Sfx.apply_settings())
	slider.modulate = Color(1, 1, 1, 0.45) if muted else Color.WHITE


## 위쪽 띠의 뒤로가기 화살표 (폰트에 없는 글자 대신 직접 그린다).
class ArrowIcon extends Control:
	func _draw() -> void:
		var middle: float = size.y / 2.0
		var left: float = size.x / 2.0 - 12.0
		var color: Color = TEAL
		draw_line(Vector2(left, middle), Vector2(left + 24.0, middle), color, 3.0, true)
		draw_line(Vector2(left, middle), Vector2(left + 8.0, middle - 7.0), color, 3.0, true)
		draw_line(Vector2(left, middle), Vector2(left + 8.0, middle + 7.0), color, 3.0, true)
