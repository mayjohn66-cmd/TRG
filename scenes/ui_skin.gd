## Text-free image skin. Content margins are explicit so skinning does not
## inherit the texture's 20px slice as a layout minimum.
class_name UiSkin
extends RefCounted

const INK: Color = Color("333333")
const SOFT: Color = Color("747c64")
const GREEN: Color = Color("5da530")
const PATH: String = "res://assets/ui/trickcal/"

static func panel(kind: String = "panel", margin: float = 10.0) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(PATH + kind + ".png") as Texture2D
	box.set_texture_margin_all(20.0)
	box.set_content_margin_all(margin)
	return box

static func button(item: Button, action: bool = false, horizontal: float = 12.0, vertical: float = 6.0) -> void:
	Sfx.bind_button(item)
	# 9-slice 조각마다 다른 밉 레벨을 고르면 작은 버튼 중앙에 사각 얼룩이 생긴다.
	item.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var prefix: String = "action" if action else "cancel"
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var texture_name: String = state if state in ["disabled", "focus"] else prefix + "_" + state
		var box: StyleBoxTexture = panel(texture_name, vertical)
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
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box: StyleBox = item.get_theme_stylebox(state)
		if not box is StyleBoxTexture or not box.has_meta("ui_button_texture"):
			continue
		var image_box := box as StyleBoxTexture
		var asset: String = str(box.get_meta("ui_button_texture"))
		var target: String = PATH + ("compact_" if compact else "") + asset + ".png"
		if image_box.texture.resource_path != target:
			image_box.texture = load(target) as Texture2D
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
