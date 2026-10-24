# File: res://scenes/mobile_support.gd
# Class: class_name MobileSupport
# Role: 모바일 브라우저 대응 보조 계층. 세로 화면이면 "가로로 돌려 주세요" 안내를 덮어 가린다. 전체화면 전환은 설정 화면 스위치(toggle_fullscreen)와 웹 세로 안내 터치가 맡는다 (화면 구석의 작은 [전체화면] 버튼은 없앴다)
class_name MobileSupport
extends CanvasLayer

const COLOR_GOLD: Color = Color("ffd43b")

var overlay: ColorRect = null


static func is_touch_device() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("web_android") or OS.has_feature("web_ios")


## true면 터치 기기처럼 큰 버튼 배치를 쓴다 (헤드리스 화면 테스트용).
static var force_touch: bool = false
## 터치 배치에서 버튼의 최소 높이 (기준 해상도 1366x768 픽셀). 폰 가로 화면에서는 약 0.5배로 줄어 보이므로 손가락 크기(약 44pt)에 맞춰 크게 잡는다.
const TOUCH_BUTTON_HEIGHT: float = 48.0


## 큰 터치 버튼 배치를 쓸 것인가.
static func touch_mode() -> bool:
	return force_touch or is_touch_device()


## 터치용으로 버튼을 다듬는다: 손가락이 살짝 미끄러져도 눌리도록 누르는 순간 반응하고(ACTION_MODE_BUTTON_PRESS), 최소 높이를 키운다.
static func touch_button(button: BaseButton, min_height: float = TOUCH_BUTTON_HEIGHT) -> void:
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, min_height)
	if button.size.y < min_height:
		button.size.y = min_height


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
	refresh(DisplayServer.window_get_size())


func _process(_delta: float) -> void:
	refresh(DisplayServer.window_get_size())


## 터치 한 번이 두 번 눌림으로 들어오는 것을 막는다: 모바일 브라우저는 터치 뒤에 같은 자리의 마우스 클릭을 한 번 더 흘려보내므로
## (배속이 1 -> 3 -> 2처럼 두 칸씩 넘어가고, 메뉴가 열렸다 바로 닫혔다), 짧은 시간 안에 거의 같은 자리에서 다시 들어온 누름은 버린다.
func _input(event: InputEvent) -> void:
	if not touch_mode():
		return
	if accept_press(event, Time.get_ticks_msec()):
		return
	get_viewport().set_input_as_handled()


## 터치 뒤에 브라우저가 덧붙이는 마우스 누름인지 가려낸다 (테스트가 시각을 넣어 직접 부를 수 있다). 받아들이면 true, 버릴 중복이면 false.
## 엔진이 터치를 흉내 낸 마우스 누름(device = DEVICE_ID_EMULATION)은 정상 입력이라 그대로 두고, 터치 직후 같은 자리의 "진짜" 마우스 누름만 버린다.
const DUPLICATE_PRESS_MSEC: int = 600
const DUPLICATE_PRESS_DISTANCE: float = 60.0
var _last_touch_msec: int = -100000
var _last_touch_at: Vector2 = Vector2(-9999, -9999)


func accept_press(event: InputEvent, now_msec: int) -> bool:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			_last_touch_msec = now_msec
			_last_touch_at = touch.position
		return true
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse == null or mouse.device == InputEvent.DEVICE_ID_EMULATION:
		return true
	return not (now_msec - _last_touch_msec < DUPLICATE_PRESS_MSEC and mouse.position.distance_to(_last_touch_at) < DUPLICATE_PRESS_DISTANCE)


## 창 크기에 맞춰 세로 안내를 켜고 끈다.
func refresh(window_size: Vector2i) -> void:
	if overlay != null:
		overlay.visible = is_portrait(window_size)


## 전체화면을 켜고 끈다. 웹에서는 가로 화면 고정도 시도한다 (브라우저가 막으면 조용히 무시).
static func toggle_fullscreen() -> void:
	var is_full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if is_full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if OS.has_feature("web") and not is_full:
		JavaScriptBridge.eval("try { screen.orientation.lock('landscape').catch(function(){}); } catch (e) {}")
