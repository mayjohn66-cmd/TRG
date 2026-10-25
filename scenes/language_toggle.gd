# File: res://scenes/language_toggle.gd
# Class: class_name LanguageToggle
# Role: A / 文 번역 말풍선이 붙은 언어 선택 버튼. 한국어 / ENGLISH / 日本語 목록에서 고르면 바로 번역하고 저장한다.
#       언어 이름은 항상 원어로 표시하고, 모든 위치에서 같은 번역 아이콘을 쓴다.
class_name LanguageToggle
extends Button

const ICON_SIZE: int = 22
const ACCENT: Color = Color("ffe066")
const CARET_WIDTH: float = 14.0

static var _picker_font: FontVariation = null

static var _translation_icons: Dictionary = {}

var _menu: PopupMenu = null
## 넉넉한 허브 버튼에서는 화살표를 오른쪽 여백 중앙에 고정한다.
var trailing_caret: bool = false
## 컬러 일러스트 아이콘은 글자색을 곱하지 않는다.
var colored_icon: bool = true


## 버튼 하나를 만든다. font_size·색은 놓일 띠에 맞춘다.
static func create(font_size: int = 14, ink: Color = Color.WHITE) -> LanguageToggle:
	var button := LanguageToggle.new()
	button.name = "LanguageToggle"
	button.text = L10n.language_name()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # 언어 이름은 번역하지 않는다
	button.icon = translation_icon()
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
		add_theme_color_override(state, Color.WHITE if colored_icon else ink)
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
	if trailing_caret:
		x = size.x - 18.0
	var y: float = size.y / 2.0
	var half: float = font_size * 0.28
	var ink: Color = get_theme_color("font_color")
	draw_colored_polygon(PackedVector2Array([Vector2(x - half, y - half * 0.55), Vector2(x + half, y - half * 0.55), Vector2(x, y + half * 0.65)]), ACCENT if not trailing_caret and L10n.current_lang != L10n.DEFAULT_LANG else ink)


## 언어 이름 목록용 글꼴: Mochiy Pop One(가나·한자) + 게임 글꼴(한글).
## ONE 모바일 POP체는 한자 자리에 빈 글리프가 들어 있어(has_char는 참) 대체 글꼴로 넘어가지 않고 "日本語"가 빈칸이 된다. 그래서 Mochiy를 앞에 둔다.
static func picker_font() -> Font:
	if _picker_font == null:
		_picker_font = FontVariation.new()
		_picker_font.base_font = load(L10n.JA_FONT_PATH) as Font
		var chain: Array[Font] = [load("res://assets/fonts/ONE-Mobile-POP.otf") as Font, load("res://assets/fonts/NanumGothic-Regular.ttf") as Font]
		_picker_font.fallbacks = chain
	return _picker_font


## 모든 언어 버튼은 동일한 A / 文 번역 말풍선 이미지를 쓴다.
static func translation_icon(side: int = ICON_SIZE) -> Texture2D:
	if not _translation_icons.has(side):
		var pixels: Image = TextureCache.fetch("res://assets/ui/trickcal/hub/UI_HUB_TRANSLATION_V01.png").get_image()
		pixels.resize(side, side, Image.INTERPOLATE_LANCZOS)
		_translation_icons[side] = ImageTexture.create_from_image(pixels)
	return _translation_icons[side] as Texture2D
