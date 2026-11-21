## Text-free image skin. Content margins are explicit so skinning does not
## inherit the texture's 20px slice as a layout minimum.
class_name UiSkin
extends RefCounted

const INK: Color = Color("333333")
const SOFT: Color = Color("747c64")
const GREEN: Color = Color("5da530")
const PATH: String = "res://assets/ui/trickcal/"
const SIMPLE_CROPS: Dictionary = {
	"panel": Rect2(0.01515152, 0.02312600, 0.96810207, 0.95693780),
	"action": Rect2(0.01152074, 0.07034483, 0.97695853, 0.85103448),
	"secondary": Rect2(0.01244813, 0.07034483, 0.97464269, 0.84965517),
}
static var _simple_cache: Dictionary = {}

## Keep generated originals intact; prepare a display-size texture once per height.
static func _simple_texture(asset: String, height: int) -> Texture2D:
	var key: String = "%s:%d" % [asset, height]
	if not _simple_cache.has(key):
		var source: Texture2D = TextureCache.fetch(PATH + "simple_v01/" + asset + ".png")
		var crop: Rect2 = SIMPLE_CROPS[asset]
		var pixels: Image = source.get_image()
		var region := Rect2i(crop.position * Vector2(pixels.get_size()), crop.size * Vector2(pixels.get_size()))
		pixels = pixels.get_region(region)
		var width: int = maxi(height, roundi(float(pixels.get_width()) * height / pixels.get_height()))
		pixels.resize(width, height, Image.INTERPOLATE_LANCZOS)
		_simple_cache[key] = ImageTexture.create_from_image(pixels)
	return _simple_cache[key] as Texture2D

static func _simple_style(asset: String, height: int, margin: float) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = _simple_texture(asset, height)
	box.set_texture_margin_all(float(height) * 0.48)
	box.set_content_margin_all(margin)
	box.set_meta("ui_simple_asset", asset)
	box.set_meta("ui_simple_height", height)
	return box

static func panel(kind: String = "panel", margin: float = 10.0) -> StyleBoxTexture:
	if kind == "panel":
		return _simple_style("panel", 64, margin)
	var box := StyleBoxTexture.new()
	box.texture = TextureCache.fetch(PATH + kind + ".png")
	box.set_texture_margin_all(20.0)
	box.set_content_margin_all(margin)
	return box

static func button(item: Button, action: bool = false, horizontal: float = 12.0, vertical: float = 6.0) -> void:
	Sfx.bind_button(item)
	# 9-slice 조각마다 다른 밉 레벨을 고르면 작은 버튼 중앙에 사각 얼룩이 생긴다.
	item.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var prefix: String = "action" if action else "cancel"
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		if state == "focus":
			var focus := StyleBoxFlat.new()
			focus.draw_center = false
			focus.border_color = GREEN.darkened(0.25)
			focus.set_border_width_all(2)
			focus.set_content_margin_all(0)
			item.add_theme_stylebox_override(state, focus)
			continue
		var texture_name: String = state if state in ["disabled", "focus"] else prefix + "_" + state
		var box: StyleBoxTexture = _simple_style("action" if action else "secondary", 40, vertical)
		box.modulate_color = {"normal": Color.WHITE, "hover": Color(1.04, 1.04, 1.04), "pressed": Color(0.93, 0.93, 0.93), "disabled": Color(0.72, 0.72, 0.72, 0.7)}[state]
		box.set_meta("ui_button_texture", texture_name)
		box.set_content_margin(SIDE_LEFT, horizontal)
		box.set_content_margin(SIDE_RIGHT, horizontal)
		item.add_theme_stylebox_override(state, box)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		item.add_theme_color_override(key, INK)
	item.add_theme_color_override("font_disabled_color", Color("4d4d4c"))
	var fit_callback: Callable = _fit_button.bind(item)
	if not item.resized.is_connected(fit_callback):
		item.resized.connect(fit_callback)
	_fit_button(item)

## Short controls need smaller corners; the focus ring shares the face's
## bottom inset instead of tracing the outside edge of the shadow.
static func _fit_button(item: Button) -> void:
	var normal: StyleBox = item.get_theme_stylebox("normal")
	if not normal.has_meta("ui_button_texture"):
		return # A specialized skin, e.g. the circular roll button, took over.
	var compact: bool = item.size.y > 0.0 and item.size.y < 40.0
	var height: int = clampi(roundi(item.size.y), 24, 96) if item.size.y > 0.0 else 40
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box: StyleBox = item.get_theme_stylebox(state)
		if state == "focus" and box is StyleBoxFlat:
			(box as StyleBoxFlat).set_corner_radius_all(roundi(height * 0.30))
		if not box is StyleBoxTexture or not box.has_meta("ui_button_texture"):
			continue
		var image_box := box as StyleBoxTexture
		if image_box.has_meta("ui_simple_asset"):
			if int(image_box.get_meta("ui_simple_height")) != height:
				image_box.texture = _simple_texture(str(image_box.get_meta("ui_simple_asset")), height)
				image_box.set_texture_margin_all(float(height) * 0.48)
				image_box.set_meta("ui_simple_height", height)
			continue
		var asset: String = str(box.get_meta("ui_button_texture"))
		var target: String = PATH + ("compact_" if compact else "") + asset + ".png"
		if image_box.texture.resource_path != target:
			image_box.texture = TextureCache.fetch(target)
			image_box.set_texture_margin_all(14.0 if compact else 20.0)

static func title(label: Label) -> void:
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_stylebox_override("normal", panel("header", 6.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

static func bind_light_text(node: Node) -> void:
	if node.has_meta("ui_skin_text"):
		return
	node.set_meta("ui_skin_text", true)
	if node is Label:
		var label := node as Label
		label.add_theme_color_override("font_color", INK)
		label.add_theme_constant_override("outline_size", 0)
	elif node is CheckBox:
		for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
			(node as CheckBox).add_theme_color_override(key, INK)
	elif node is OptionButton:
		button(node as OptionButton)
	for child: Node in node.get_children():
		bind_light_text(child)
	node.child_entered_tree.connect(bind_light_text)
