# File: res://scenes/mobile_support.gd
# Class: class_name MobileSupport
# Role: 모바일 브라우저 대응 보조 계층. 세로 화면이면 "가로로 돌려 주세요" 안내를 덮어 가린다.
#       터치 기기에서는 버튼 근처(TOUCH_SLOP px 안)를 눌러도 가장 가까운 버튼이 눌리게 누름을 버튼 안쪽으로 옮겨 준다 (버튼 그림 크기는 그대로). 전체화면 전환은 설정 화면 스위치(toggle_fullscreen)와 웹 세로 안내 터치가 맡는다 (화면 구석의 작은 [전체화면] 버튼은 없앴다)
class_name MobileSupport
extends CanvasLayer

const COLOR_GOLD: Color = Color("ffd43b")

var overlay: ColorRect = null


static var _touch_cache: int = -1


## 손가락이 주 입력인 기기(폰·태블릿)인가. 웹에서는 터치 화면 노트북·데스크톱 크롬처럼 터치를 '지원만' 하는 PC를 빼려고
## 주 포인터가 굵은지(pointer: coarse)를 본다: PC는 큰 터치 배치(전체 확대로 글씨가 흐려진다) 대신 원래 크기로 선명하게 그린다.
static func is_touch_device() -> bool:
	if OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	if OS.has_feature("web"):
		if _touch_cache == -1:
			_touch_cache = 1 if bool(JavaScriptBridge.eval("!!(window.matchMedia && window.matchMedia('(pointer: coarse)').matches)")) else 0
		return _touch_cache == 1
	return DisplayServer.is_touchscreen_available()


## true면 터치 기기처럼 큰 버튼 배치를 쓴다 (헤드리스 화면 테스트용).
static var force_touch: bool = false

## Global game shortcuts must leave focused native/web text editors alone.
static func text_input_active(context: Node) -> bool:
	var focus:=context.get_viewport().gui_get_focus_owner()
	if focus is LineEdit and (focus as LineEdit).editable:return true
	if focus is TextEdit and (focus as TextEdit).editable:return true
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("(()=>{const e=document.activeElement;const tag=e?.tagName?.toLowerCase();return tag==='input'||tag==='textarea'||!!e?.isContentEditable;})()"))
	return false
## 터치 배치에서 버튼의 최소 높이 (기준 해상도 1366x768 픽셀). 폰 가로 화면에서는 약 0.5배로 줄어 보이므로 손가락 크기(약 44pt)에 맞춰 크게 잡는다.
const TOUCH_BUTTON_HEIGHT: float = 48.0


## 큰 터치 버튼 배치를 쓸 것인가.
static func touch_mode() -> bool:
	return force_touch or is_touch_device()


## 터치 기기에서 작은 글씨를 키운다 (폰 가로 화면은 기준 해상도의 약 0.5배로 보여 12~16px 글이 읽기 힘들다).
## 큰 글씨(18px 이상)와 PC는 그대로. 상자 크기는 바꾸지 않으므로 글이 들어갈 자리가 있는 곳에만 쓴다.
const TOUCH_TEXT_SCALE: float = 1.2


static func text_px(px: int, cap: int = 18) -> int:
	if not touch_mode() or px >= cap:
		return px
	return mini(cap, roundi(px * TOUCH_TEXT_SCALE))


## 터치 기기에서 화면 가운데 뜨는 창을 화면 높이·너비 안에서 최대 max_scale배로 키운다 (창 크기가 바뀔 때마다 다시 맞춘다).
## 폰 가로 화면은 기준 해상도의 약 0.5배로 보여 창 글씨가 작다. 가운데 정렬된 창에만 쓴다 (가운데를 기준으로 커진다). 부모 컨테이너에 넣은 뒤 부른다.
static func fit_touch_scale(panel: Control, max_scale: float) -> void:
	if not touch_mode():
		return
	# 부모 컨테이너가 자식을 배치할 때마다 scale을 1로 되돌리므로, 배치가 끝난 직후(sort_children)에 다시 키운다.
	var holder: Container = panel.get_parent() as Container
	if holder != null:
		holder.sort_children.connect(func() -> void: _fit_scale(panel, max_scale))
	var refit := func() -> void: _fit_scale.call_deferred(panel, max_scale)
	panel.resized.connect(refit)
	panel.tree_entered.connect(refit)


static func _fit_scale(panel: Control, max_scale: float) -> void:
	if not is_instance_valid(panel) or panel.size.x <= 0.0 or panel.size.y <= 0.0 or not panel.is_inside_tree():
		return
	var view: Vector2 = panel.get_viewport_rect().size
	var fit: float = minf((view.y - 16.0) / panel.size.y, (view.x - 16.0) / panel.size.x)
	var factor: float = clampf(minf(max_scale, fit), 1.0, max_scale)
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(factor, factor)


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
	if not touch_mode() or _redirecting:
		return
	if not accept_press(event, Time.get_ticks_msec()):
		get_viewport().set_input_as_handled()
		return
	_snap_to_nearby_button(event)


## 터치 판정 넓히기: 버튼 그림은 그대로 두고, 버튼 밖 TOUCH_SLOP px 안을 누르면 가장 가까운 버튼을 누른 것으로 친다.
## 누른 자리가 이미 버튼(또는 입력 칸) 위면 그대로 두고, 그 자리를 덮은 창(대화 상자·딤)이 있으면 그 창 안의 버튼만 고른다.
## 누름을 옮겼으면 뗄 때도 같은 버튼 안으로 옮겨 클릭이 성립하게 한다.
const TOUCH_SLOP: float = 26.0
## 화면 위·아래 끝에 붙은 버튼(상단 띠의 뒤로·언어·규칙, 보드의 피드백·배속·메뉴, 하단 [설정])은 손가락이 화면 끝에 걸려
## 버튼 밖(안쪽)을 누르기 쉬우므로 더 넓게 잡는다.
const EDGE_SLOP: float = 48.0
const EDGE_BAND: float = 16.0
var _redirecting: bool = false
var _snap_offset: Vector2 = Vector2.ZERO
var _snapping: bool = false


func _snap_to_nearby_button(event: InputEvent) -> void:
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse == null or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if not mouse.pressed:
		if _snapping:
			_snapping = false
			_push_moved(mouse, mouse.position + _snap_offset)
		return
	_snapping = false
	var target: Variant = nearby_button_point(get_tree().root, mouse.position)
	if target == null:
		return
	_snap_offset = (target as Vector2) - mouse.position
	_snapping = true
	_push_moved(mouse, target)


func _push_moved(mouse: InputEventMouseButton, at: Vector2) -> void:
	var moved: InputEventMouseButton = mouse.duplicate()
	moved.position = at
	moved.global_position = at
	get_viewport().set_input_as_handled()
	_redirecting = true
	get_viewport().push_input(moved)
	_redirecting = false


## point(화면 좌표)를 옮겨 누를 버튼 안쪽 점. 옮길 필요가 없거나 가까운 버튼이 없으면 null (테스트가 직접 부른다).
static func nearby_button_point(root: Node, point: Vector2, slop: float = TOUCH_SLOP) -> Variant:
	var controls: Array[Control] = []
	_collect_controls(root, controls)
	# 화면 위에 그려지는 순서(캔버스 층 → 트리 순서)의 역순으로 본다: 맨 위 것이 누름을 받는다
	var ordered: Array = []
	for index: int in controls.size():
		ordered.append([_layer_of(controls[index]), index, controls[index]])
	ordered.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] if a[0] != b[0] else a[1] > b[1])
	var blocker: Control = null
	for entry: Array in ordered:
		var control: Control = entry[2]
		if control.mouse_filter != Control.MOUSE_FILTER_IGNORE and _screen_rect(control).has_point(point):
			blocker = control
			break
	if blocker != null and _is_pressable_area(blocker):
		return null  # 이미 버튼·입력 칸을 눌렀다
	var best: BaseButton = null
	var best_distance: float = INF
	var best_rect: Rect2 = Rect2()
	var screen: Rect2 = (root as Viewport).get_visible_rect() if root is Viewport else Rect2(Vector2.ZERO, Vector2(1366, 768))
	for entry: Array in ordered:
		var button: BaseButton = entry[2] as BaseButton
		if button == null or button.disabled or button.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		if blocker != null and not (blocker.is_ancestor_of(button) or (blocker.get_parent() != null and blocker.get_parent().is_ancestor_of(button))):
			continue  # 누른 자리를 덮은 창 밖(뒤)의 버튼은 고르지 않는다
		var rect: Rect2 = _screen_rect(button)
		if rect.size.x < 2.0 or rect.size.y < 2.0:
			continue
		var distance: float = _distance_to_rect(rect, point)
		var reach: float = EDGE_SLOP if (rect.position.y <= screen.position.y + EDGE_BAND or rect.end.y >= screen.end.y - EDGE_BAND) else slop
		if distance < reach and distance < best_distance:
			best_distance = distance
			best = button
			best_rect = rect
	if best == null:
		return null
	var inner: Rect2 = best_rect.grow(-minf(4.0, minf(best_rect.size.x, best_rect.size.y) / 4.0))
	return Vector2(clampf(point.x, inner.position.x, inner.end.x), clampf(point.y, inner.position.y, inner.end.y))


static func _collect_controls(node: Node, out: Array[Control]) -> void:
	for child: Node in node.get_children():
		if child is CanvasItem and not (child as CanvasItem).visible:
			continue
		if child is CanvasLayer and not (child as CanvasLayer).visible:
			continue
		if child is Control:
			out.append(child as Control)
		_collect_controls(child, out)


static func _layer_of(control: Control) -> int:
	var layer: CanvasLayer = control.get_canvas_layer_node()
	return layer.layer if layer != null else 0


static func _screen_rect(control: Control) -> Rect2:
	var xform: Transform2D = control.get_global_transform_with_canvas()
	return xform * Rect2(Vector2.ZERO, control.size)


static func _is_pressable_area(hit: Control) -> bool:
	var node: Node = hit
	while node != null and node is Control:
		if node is BaseButton or node is LineEdit or node is TextEdit or node is ScrollBar or node is Slider:
			return true
		# 스스로 누름을 받는 것(손패 카드 끌기·말 고르기 등)을 눌렀으면 옆 버튼으로 옮기지 않는다
		var area: Control = node
		if area.mouse_filter != Control.MOUSE_FILTER_IGNORE and (not area.gui_input.get_connections().is_empty() or (area.get_script() != null and (area.get_script() as Script).get_script_method_list().any(func(m: Dictionary) -> bool: return m["name"] == "_gui_input"))):
			return true
		node = node.get_parent()
	return false


static func _distance_to_rect(rect: Rect2, point: Vector2) -> float:
	var dx: float = maxf(maxf(rect.position.x - point.x, 0.0), point.x - rect.end.x)
	var dy: float = maxf(maxf(rect.position.y - point.y, 0.0), point.y - rect.end.y)
	return Vector2(dx, dy).length()


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
## 지금 전체화면인가 (웹은 페이지 전체화면 document.fullscreenElement).
static func is_fullscreen() -> bool:
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("!!document.fullscreenElement"))
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


static func toggle_fullscreen() -> void:
	if OS.has_feature("web"):
		# 웹은 페이지 전체를 전체화면으로: 16:9 캔버스와 바깥 연두색 칸이 그대로 유지된다 (캔버스만 전체화면이면 엔진이 검은 띠를 그린다).
		JavaScriptBridge.eval("try { if (document.fullscreenElement) { document.exitFullscreen(); } else { document.documentElement.requestFullscreen().then(function(){ try { screen.orientation.lock('landscape').catch(function(){}); } catch (e) {} }).catch(function(){}); } } catch (e) {}")
		return
	var is_full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if is_full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if OS.has_feature("web") and not is_full:
		JavaScriptBridge.eval("try { screen.orientation.lock('landscape').catch(function(){}); } catch (e) {}")
