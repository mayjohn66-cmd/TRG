# File: res://scenes/meta_icons.gd
# Class: class_name MetaIcon
# Role: 영구 기록(수집·정복) 표시용 작은 아이콘. 황금 왕관(정복)과 회색 자물쇠(미정복)는 승인된 PNG를 공유하고, 트로피는 기존 경로를 유지한다.
#       법전 수집 알약 버튼(pill)과 [달성 완료 ★] 도장(stamp)도 만든다.
class_name MetaIcon
extends Control

const GOLD: Color = Color("ffc928")
const GOLD_EDGE: Color = Color("a8670b")
const LOCK: Color = Color("9a98ab")
const LOCK_EDGE: Color = Color("5e5c70")
const STAMP_RED: Color = Color("d6336c")

var kind: StringName = &"crown"
static var _law_texture: Texture2D = null


## 허브와 도감의 수집 버튼이 같은 법전 이미지·크롭을 공유한다.
static func law_icon() -> Texture2D:
	if _law_texture == null:
		var source: Texture2D = TextureCache.fetch("res://assets/ui/trickcal/rulebook/v02/lawbook.png")
		var pixels: Image = source.get_image()
		if pixels.is_compressed():
			pixels.decompress()
		var crop := Rect2(Vector2(166, 134) / 1254.0, Vector2(939, 1007) / 1254.0)
		pixels = pixels.get_region(Rect2i(crop.position * source.get_size(), crop.size * source.get_size()))
		pixels.resize(24, 26, Image.INTERPOLATE_LANCZOS)
		_law_texture = ImageTexture.create_from_image(pixels)
	return _law_texture


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
			DifficultyArt.icon(self,DifficultyArt.CROWN,Rect2(Vector2.ZERO,size))
		&"lock":
			DifficultyArt.icon(self,DifficultyArt.LOCK,Rect2(Vector2.ZERO,size))
		&"trophy":
			var cup := PackedVector2Array([Vector2(w * 0.18, h * 0.08), Vector2(w * 0.82, h * 0.08), Vector2(w * 0.70, h * 0.50), Vector2(w * 0.30, h * 0.50)])
			draw_colored_polygon(cup, GOLD)
			draw_arc(Vector2(w * 0.18, h * 0.26), w * 0.13, PI * 0.5, PI * 1.5, 10, GOLD_EDGE, maxf(1.5, w * 0.07), true)
			draw_arc(Vector2(w * 0.82, h * 0.26), w * 0.13, -PI * 0.5, PI * 0.5, 10, GOLD_EDGE, maxf(1.5, w * 0.07), true)
			draw_rect(Rect2(Vector2(w * 0.44, h * 0.50), Vector2(w * 0.12, h * 0.24)), GOLD_EDGE)
			draw_rect(Rect2(Vector2(w * 0.26, h * 0.74), Vector2(w * 0.48, h * 0.16)), GOLD_EDGE)
			cup.append(cup[0])
			draw_polyline(cup, GOLD_EDGE, maxf(1.5, w * 0.06), true)


## [법전 + 글] 알약 버튼 (법전 수집 N/8).
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
	var icon := TextureRect.new()
	icon.name = "LawCollectionIcon"
	icon.texture = law_icon()
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.anchor_top = 0.5
	icon.anchor_bottom = 0.5
	icon.offset_left = 12
	icon.offset_right = 38
	icon.offset_top = -13
	icon.offset_bottom = 13
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
