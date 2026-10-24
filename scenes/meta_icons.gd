# File: res://scenes/meta_icons.gd
# Class: class_name MetaIcon
# Role: 영구 기록(수집·정복) 표시용 작은 아이콘: 황금 왕관(정복) / 회색 자물쇠(미정복) / 트로피(법전 수집). 게임 글꼴에 이모지가 없어 직접 그린다.
#       법전 수집 알약 버튼(pill)과 [달성 완료 ★] 도장(stamp)도 만든다.
class_name MetaIcon
extends Control

const GOLD: Color = Color("ffc928")
const GOLD_EDGE: Color = Color("a8670b")
const LOCK: Color = Color("9a98ab")
const LOCK_EDGE: Color = Color("5e5c70")
const STAMP_RED: Color = Color("d6336c")

var kind: StringName = &"crown"


static func create(icon_kind: StringName, icon_size: Vector2) -> MetaIcon:
	var icon := MetaIcon.new()
	icon.kind = icon_kind
	icon.custom_minimum_size = icon_size
	icon.size = icon_size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func set_kind(icon_kind: StringName) -> void:
	if kind != icon_kind:
		kind = icon_kind
		queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	match kind:
		&"crown":
			var points := PackedVector2Array([
				Vector2(w * 0.08, h * 0.30), Vector2(w * 0.30, h * 0.55), Vector2(w * 0.50, h * 0.12),
				Vector2(w * 0.70, h * 0.55), Vector2(w * 0.92, h * 0.30), Vector2(w * 0.84, h * 0.86), Vector2(w * 0.16, h * 0.86)])
			draw_colored_polygon(points, GOLD)
			points.append(points[0])
			draw_polyline(points, GOLD_EDGE, maxf(1.5, w * 0.07), true)
			for x: float in [0.08, 0.50, 0.92]:
				draw_circle(Vector2(w * x, h * (0.12 if x == 0.50 else 0.30)), w * 0.07, GOLD_EDGE)
		&"lock":
			draw_arc(Vector2(w * 0.5, h * 0.42), w * 0.24, PI, TAU, 16, LOCK_EDGE, maxf(1.5, w * 0.10), true)
			var body := Rect2(Vector2(w * 0.16, h * 0.42), Vector2(w * 0.68, h * 0.50))
			draw_rect(body, LOCK)
			draw_rect(body, LOCK_EDGE, false, maxf(1.0, w * 0.06))
			draw_circle(Vector2(w * 0.5, h * 0.64), w * 0.07, LOCK_EDGE)
		&"trophy":
			var cup := PackedVector2Array([Vector2(w * 0.18, h * 0.08), Vector2(w * 0.82, h * 0.08), Vector2(w * 0.70, h * 0.50), Vector2(w * 0.30, h * 0.50)])
			draw_colored_polygon(cup, GOLD)
			draw_arc(Vector2(w * 0.18, h * 0.26), w * 0.13, PI * 0.5, PI * 1.5, 10, GOLD_EDGE, maxf(1.5, w * 0.07), true)
			draw_arc(Vector2(w * 0.82, h * 0.26), w * 0.13, -PI * 0.5, PI * 0.5, 10, GOLD_EDGE, maxf(1.5, w * 0.07), true)
			draw_rect(Rect2(Vector2(w * 0.44, h * 0.50), Vector2(w * 0.12, h * 0.24)), GOLD_EDGE)
			draw_rect(Rect2(Vector2(w * 0.26, h * 0.74), Vector2(w * 0.48, h * 0.16)), GOLD_EDGE)
			cup.append(cup[0])
			draw_polyline(cup, GOLD_EDGE, maxf(1.5, w * 0.06), true)


## [트로피 + 글] 알약 버튼 (법전 수집 N/8).
static func pill(node_name: String, text: String, on_press: Callable, font_px: int = 17) -> Button:
	var button := Button.new()
	button.name = node_name
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 46)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var box: StyleBoxFlat = LobbyTheme.style(Color("fff4d6") if state != "hover" else Color("fffbea"), GOLD_EDGE, 3, 23, 0, 0)
		box.content_margin_left = 46
		box.content_margin_right = 16
		button.add_theme_stylebox_override(state, box)
	button.text = text
	button.add_theme_font_size_override("font_size", font_px)
	button.add_theme_color_override("font_color", Color("6b3d05"))
	button.add_theme_color_override("font_hover_color", Color("6b3d05"))
	var icon: MetaIcon = create(&"trophy", Vector2(26, 26))
	icon.position = Vector2(12, 10)
	button.add_child(icon)
	if on_press.is_valid():
		button.pressed.connect(on_press)
	return button


## [달성 완료 ★] 도장: 살짝 기울어진 빨간 테두리 글.
static func stamp(text: String, font_px: int = 18) -> PanelContainer:
	var holder := PanelContainer.new()
	holder.name = "ClearedStamp"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.88)
	box.border_color = STAMP_RED
	box.set_border_width_all(3)
	box.set_corner_radius_all(8)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	holder.add_theme_stylebox_override("panel", box)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_px)
	label.add_theme_color_override("font_color", STAMP_RED)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(label)
	holder.rotation = deg_to_rad(-10.0)
	return holder


## 글을 클립보드에 복사한다 (웹은 브라우저 클립보드에도: 누른 순간이라 허락된다).
static func copy_to_clipboard(text: String) -> void:
	DisplayServer.clipboard_set(text)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try { navigator.clipboard.writeText(%s); } catch (e) {}" % JSON.stringify(text), true)
