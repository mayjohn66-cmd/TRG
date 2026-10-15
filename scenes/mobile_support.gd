# File: res://scenes/mobile_support.gd
# Class: class_name MobileSupport
# Role: 모바일 브라우저 대응 보조 계층. 세로 화면이면 "가로로 돌려 주세요" 안내를 덮어 가리고, 터치·웹 환경에서는 [전체화면] 버튼(가능하면 가로 고정까지)을 보여 준다
class_name MobileSupport
extends CanvasLayer

const COLOR_GOLD: Color = Color("ffd43b")

var overlay: ColorRect = null
var fullscreen_button: Button = null
## 전체화면 버튼이 놓일 위치 (논리 좌표 1366x768 기준). add_child 전에 정한다.
var button_position: Vector2 = Vector2(1260, 12)


static func is_touch_device() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("web_android") or OS.has_feature("web_ios")


## 창이 세로(높이 > 너비)인가.
static func is_portrait(window_size: Vector2i) -> bool:
	return window_size.y > window_size.x


func _ready() -> void:
	layer = 100
	overlay = ColorRect.new()
	overlay.color = Color("0d1018")
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var turn := Label.new()
	turn.text = "화면을 가로로 돌려 주세요"
	turn.add_theme_font_size_override("font_size", 40)
	turn.add_theme_color_override("font_color", COLOR_GOLD)
	turn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(turn)
	var hint := Label.new()
	hint.text = "이 게임은 가로 화면에 맞춰져 있습니다."
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color("adb5bd"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	fullscreen_button = Button.new()
	fullscreen_button.text = "전체화면"
	fullscreen_button.position = button_position
	fullscreen_button.size = Vector2(92, 30)
	fullscreen_button.add_theme_font_size_override("font_size", 13)
	fullscreen_button.visible = is_touch_device()
	fullscreen_button.pressed.connect(toggle_fullscreen)
	add_child(fullscreen_button)
	refresh(DisplayServer.window_get_size())


func _process(_delta: float) -> void:
	refresh(DisplayServer.window_get_size())


## 창 크기에 맞춰 세로 안내를 켜고 끈다.
func refresh(window_size: Vector2i) -> void:
	if overlay != null:
		overlay.visible = is_portrait(window_size)


## 전체화면을 켜고 끈다. 웹에서는 가로 화면 고정도 시도한다 (브라우저가 막으면 조용히 무시).
func toggle_fullscreen() -> void:
	var is_full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if is_full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if OS.has_feature("web") and not is_full:
		JavaScriptBridge.eval("try { screen.orientation.lock('landscape').catch(function(){}); } catch (e) {}")
