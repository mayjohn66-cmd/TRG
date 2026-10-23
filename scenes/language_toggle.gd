# File: res://scenes/language_toggle.gd
# Class: class_name LanguageToggle
# Role: 상단 띠의 [🌐 한국어 ▾] 언어 버튼. 누르면 한국어 / ENGLISH / 日本語 목록이 열리고, 고른 언어로 모든 화면 글자가 그 자리에서 다시 번역되며 설정에 저장된다.
#       버튼과 목록의 언어 이름은 늘 그 언어 글자 그대로 적는다 (어느 화면에서도 자기 언어를 찾을 수 있게). 지구본·펼침 화살표는 글꼴에 없어 직접 그린다.
class_name LanguageToggle
extends Button

const ICON_SIZE: int = 22
const ACCENT: Color = Color("ffe066")
const CARET_WIDTH: float = 14.0

static var _picker_font: FontVariation = null

static var _globe: Texture2D = null

var _menu: PopupMenu = null


## 버튼 하나를 만든다. font_size·색은 놓일 띠에 맞춘다.
static func create(font_size: int = 14, ink: Color = Color.WHITE) -> LanguageToggle:
	var button := LanguageToggle.new()
	button.name = "LanguageToggle"
	button.text = L10n.language_name()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # 언어 이름은 번역하지 않는다
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
	button.custom_minimum_size = Vector2(132, 0)
	return button


func _ready() -> void:
	var ink: Color = get_theme_color("font_color")  # 버튼 스킨이 정한 글자색에 지구본도 맞춘다
	for state: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		add_theme_color_override(state, ink)
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_menu = PopupMenu.new()
	_menu.name = "LanguageMenu"
	_menu.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_menu.add_theme_font_size_override("font_size", maxi(get_theme_font_size("font_size"), 16))
	_menu.add_theme_font_override("font", picker_font())
	for index: int in L10n.LANGUAGES.size():
		_menu.add_radio_check_item(L10n.language_name(L10n.LANGUAGES[index]), index)
	_menu.id_pressed.connect(_on_language_picked)
	add_child(_menu)
	pressed.connect(_on_pressed)
	L10n.on_changed(_refresh)
	_refresh()


## 언어 목록을 버튼 바로 아래에 연다.
func _on_pressed() -> void:
	Sfx.play(&"ui_click")
	_refresh()
	# MenuButton과 같은 방식: 버튼 화면 위치 바로 아래, 버튼 폭 이상
	var scale_y: float = get_global_transform().get_scale().y
	_menu.reset_size()
	_menu.position = Vector2i(get_screen_position() + Vector2(0.0, size.y * scale_y))
	_menu.size = Vector2i(maxi(roundi(size.x * get_global_transform().get_scale().x), _menu.size.x), 0)
	_menu.popup()


## 목록에서 언어를 골랐다: 바꾸고 저장한다 (모든 화면 글자가 그 자리에서 다시 번역된다).
func _on_language_picked(index: int) -> void:
	if index < 0 or index >= L10n.LANGUAGES.size():
		return
	pick_language(L10n.LANGUAGES[index])


## 언어를 바꾸고 설정에 저장한다 (설정 화면 목록도 같은 길을 쓴다).
static func pick_language(lang: String) -> void:
	if L10n.set_language(lang):
		GameSession.language = L10n.current_lang
		GameSession.save_settings()
	Sfx.play(&"ui_click")


func _refresh() -> void:
	if not is_inside_tree():
		return
	text = L10n.language_name()
	tooltip_text = L10n.t("언어")
	if _menu != null:
		for index: int in _menu.item_count:
			_menu.set_item_checked(index, L10n.LANGUAGES[index] == L10n.current_lang)
	queue_redraw()


## 글자 오른쪽에 펼침 화살표(▾)를 그린다. 글꼴에 없는 기호라 직접 그린다.
func _draw() -> void:
	var font: Font = get_theme_font("font")
	var font_size: int = get_theme_font_size("font_size")
	var full: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var icon_width: float = float(ICON_SIZE + get_theme_constant("h_separation"))
	var end_x: float = (size.x + full + icon_width) / 2.0
	var x: float = minf(end_x + 6.0, size.x - CARET_WIDTH * 0.5)
	var y: float = size.y / 2.0
	var half: float = font_size * 0.28
	var ink: Color = get_theme_color("font_color")
	draw_colored_polygon(PackedVector2Array([Vector2(x - half, y - half * 0.55), Vector2(x + half, y - half * 0.55), Vector2(x, y + half * 0.65)]), ACCENT if L10n.current_lang != L10n.DEFAULT_LANG else ink)


## 언어 이름 목록용 글꼴: Mochiy Pop One(가나·한자) + 게임 글꼴(한글).
## ONE 모바일 POP체는 한자 자리에 빈 글리프가 들어 있어(has_char는 참) 대체 글꼴로 넘어가지 않고 "日本語"가 빈칸이 된다. 그래서 Mochiy를 앞에 둔다.
static func picker_font() -> Font:
	if _picker_font == null:
		_picker_font = FontVariation.new()
		_picker_font.base_font = load(L10n.JA_FONT_PATH) as Font
		var chain: Array[Font] = [load("res://assets/fonts/ONE-Mobile-POP.otf") as Font, load("res://assets/fonts/NanumGothic-Regular.ttf") as Font]
		_picker_font.fallbacks = chain
	return _picker_font


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
