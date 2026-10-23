# File: res://scenes/language_toggle.gd
# Class: class_name LanguageToggle
# Role: 상단 띠의 [🌐 KR / EN] 언어 토글. 누르면 KR ↔ EN이 바로 바뀌고(모든 화면 글자가 그 자리에서 다시 번역된다) 설정에 저장된다.
#       지구본은 글꼴에 이모지가 없어 직접 그린 아이콘이고, 지금 언어 쪽 글자 아래에 밑줄을 긋는다.
class_name LanguageToggle
extends Button

const ICON_SIZE: int = 22
const ACCENT: Color = Color("ffe066")

static var _globe: Texture2D = null


## 버튼 하나를 만든다. font_size·색은 놓일 띠에 맞춘다.
static func create(font_size: int = 14, ink: Color = Color.WHITE) -> LanguageToggle:
	var button := LanguageToggle.new()
	button.name = "LanguageToggle"
	button.text = "KR / EN"
	button.icon = globe_icon()
	button.expand_icon = false
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, ink)
	button.add_theme_color_override("icon_normal_color", ink)
	button.add_theme_color_override("icon_hover_color", ink)
	button.add_theme_color_override("icon_pressed_color", ink)
	button.add_theme_constant_override("h_separation", 6)
	button.custom_minimum_size = Vector2(118, 0)
	return button


func _ready() -> void:
	var ink: Color = get_theme_color("font_color")  # 버튼 스킨이 정한 글자색에 지구본도 맞춘다
	for state: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		add_theme_color_override(state, ink)
	pressed.connect(_on_pressed)
	L10n.on_changed(_refresh)
	_refresh()


func _on_pressed() -> void:
	L10n.toggle_language()
	GameSession.language = L10n.current_lang
	GameSession.save_settings()
	AugmentRegistry.reload()
	Sfx.play(&"ui_click")


func _refresh() -> void:
	if not is_inside_tree():
		return
	tooltip_text = "언어: 한국어 ↔ English"  # 영어 화면에서는 자동 번역된다
	queue_redraw()


## 지금 언어(KR 또는 EN) 글자 아래 밑줄.
func _draw() -> void:
	var font: Font = get_theme_font("font")
	var font_size: int = get_theme_font_size("font_size")
	var full: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var icon_width: float = float(ICON_SIZE + get_theme_constant("h_separation"))
	var start_x: float = (size.x - (full + icon_width)) / 2.0 + icon_width
	var active: String = "EN" if L10n.current_lang == "en" else "KR"
	var before: String = text.substr(0, text.find(active))
	var x0: float = start_x + font.get_string_size(before, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var width: float = font.get_string_size(active, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var y: float = size.y / 2.0 + font_size * 0.62
	draw_line(Vector2(x0, y), Vector2(x0 + width, y), ACCENT, 2.5, true)


## 지구본 아이콘 (흰 선, 버튼 글자색으로 물든다).
static func globe_icon() -> Texture2D:
	if _globe != null:
		return _globe
	var scale: int = 4  # 크게 그린 뒤 줄여 부드러운 선을 얻는다
	var side: int = ICON_SIZE * scale
	var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
	var center := Vector2(side, side) / 2.0
	var radius: float = side * 0.44
	var stroke: float = side * 0.075
	for y: int in side:
		for x: int in side:
			var p := Vector2(x + 0.5, y + 0.5) - center
			var d: float = p.length()
			var ink: float = 0.0
			ink = maxf(ink, 1.0 - absf(d - radius) / stroke)  # 바깥 원
			if d < radius:
				ink = maxf(ink, 1.0 - absf(p.y) / (stroke * 0.8))  # 적도
				ink = maxf(ink, 1.0 - absf(p.x) / (stroke * 0.8))  # 가운데 경선
				for lat: float in [-0.5, 0.5]:  # 위·아래 위선
					ink = maxf(ink, 1.0 - absf(p.y - radius * lat) / (stroke * 0.7))
				var half_width: float = radius * 0.5 * sqrt(maxf(0.0, 1.0 - pow(p.y / radius, 2.0)))
				ink = maxf(ink, 1.0 - absf(absf(p.x) - half_width) / (stroke * 0.8))  # 양쪽 경선 (타원)
			image.set_pixel(x, y, Color(1, 1, 1, clampf(ink, 0.0, 1.0)))
	image.resize(ICON_SIZE, ICON_SIZE, Image.INTERPOLATE_LANCZOS)
	_globe = ImageTexture.create_from_image(image)
	return _globe
