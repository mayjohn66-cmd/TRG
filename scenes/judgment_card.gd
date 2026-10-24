## Illustrated 2D card. Its two sides are independent nodes; hidden faces do
## not leak through the back. RollPresenter owns deal/flip timing.
class_name JudgmentCard
extends PanelContainer

const BACK_CLIP: Shader = preload("res://assets/ui/trickcal/judgment_cards/card_back_clip.gdshader")
var model: Dictionary = {}
var face_up: bool = false
var _front: Control
var _back: TextureRect
var _border: Color


func configure(data: Dictionary, card_size: Vector2) -> void:
	model = data
	custom_minimum_size = card_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_border = Color("8bb35c") if model.tool == &"HOLDEM" else (Color("cf7883") if model.tool == &"DICE_HWATU" else Color("ad8bd5"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff8e6")
	style.border_color = _border
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.set_content_margin_all(3)
	style.shadow_color = Color(0.12, 0.17, 0.08, 0.22)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 3)
	add_theme_stylebox_override("panel", style)
	_front = Control.new()
	_front.name = "CardFront"
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_front)
	_back = TextureRect.new()
	_back.name = "CardBack"
	_back.texture = JudgmentCardArt.texture(model.back)
	_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_back.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var clip := ShaderMaterial.new()
	clip.shader = BACK_CLIP
	_back.material = clip
	add_child(_back)
	_front.resized.connect(_layout_front)
	set_face_up(false)


func set_face_up(value: bool) -> void:
	face_up = value
	_front.visible = value
	_back.visible = not value


func _layout_front() -> void:
	for child: Node in _front.get_children():
		_front.remove_child(child)
		child.queue_free()
	if model.tool == &"HOLDEM":
		_layout_poker()
	elif model.tool == &"DICE_HWATU":
		_layout_hwatu()
	elif JudgmentCardArt.TAROT.has(model.fate):
		_layout_tarot()


func _layout_poker() -> void:
	var rank: String = model.rank
	var ink: Color = Color("c64e66") if int(model.suit) in [1, 2] else Color("36543c")
	_text(rank, Rect2(0.04, 0.015, 0.27, 0.18), 17, ink)
	_art(model.art, Rect2(0.07, 0.17, 0.18, 0.12))
	var bottom: Label = _text(rank, Rect2(0.69, 0.805, 0.27, 0.18), 17, ink)
	bottom.pivot_offset = bottom.size / 2.0
	bottom.rotation = PI
	var number: int = 1 if rank == "A" else int(rank)
	if number > 0:
		for centre: Vector2 in JudgmentCardArt.pip_positions(number):
			var span: float = 0.48 if number == 1 else 0.23
			var y: float = 0.24 + centre.y * 0.51
			_art(model.art, Rect2(centre.x - span / 2.0, y - span * 0.32, span, span * 0.64))
	else:
		_text(rank, Rect2(0.23, 0.29, 0.54, 0.3), 36, ink)
		_art(model.art, Rect2(0.28, 0.59, 0.44, 0.28))


func _layout_hwatu() -> void:
	_text("%d월" % int(model.month), Rect2(0.08, 0.035, 0.84, 0.16), 17, Color("743a43"))
	_art(model.art, Rect2(0.04, 0.22, 0.92, 0.54))
	var kind: StringName = model.type
	var colors: Dictionary = {&"gwang":Color("c59227"), &"yeol":Color("4a8250"), &"tti":Color("c64e66"), &"pi":Color("62747b")}
	var label: Label = _text(JudgmentCardArt.TYPE_NAMES[kind], Rect2(0.13, 0.795, 0.74, 0.16), 16, colors[kind])
	var badge := StyleBoxFlat.new()
	badge.bg_color = colors[kind].lightened(0.83)
	badge.border_color = colors[kind].lightened(0.35)
	badge.set_border_width_all(1)
	badge.set_corner_radius_all(7)
	label.add_theme_stylebox_override("normal", badge)


func _layout_tarot() -> void:
	var info: Array = JudgmentCardArt.TAROT[model.fate]
	_text(info[0], Rect2(0.10, 0.025, 0.80, 0.15), 16, Color("7d579d"))
	_art(model.art, Rect2(0.03, 0.20, 0.94, 0.53))
	_text(info[1], Rect2(0.035, 0.76, 0.93, 0.20), 11 if str(info[1]).length() > 5 else 14, Color("67467e"))


func _text(value: String, rect: Rect2, font_px: int, ink: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = rect.position * _front.size
	label.size = rect.size * _front.size
	label.add_theme_font_size_override("font_size", font_px)
	label.add_theme_color_override("font_color", ink)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.add_child(label)
	return label


func _art(asset: String, rect: Rect2) -> void:
	var picture := TextureRect.new()
	picture.texture = JudgmentCardArt.texture(asset)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.position = rect.position * _front.size
	picture.size = rect.size * _front.size
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.add_child(picture)
