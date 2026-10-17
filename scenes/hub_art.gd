## 로비 전용 개별 이미지. 글씨와 클릭 처리는 기존 UI 노드가 담당한다.
class_name HubArt
extends RefCounted

const ART: Dictionary = {
	&"practice": preload("res://assets/ui/trickcal/hub/UI_HUB_PRACTICE.tres"),
	&"friend": preload("res://assets/ui/trickcal/hub/UI_HUB_FRIEND.tres"),
	&"match": preload("res://assets/ui/trickcal/hub/UI_HUB_MATCH.tres"),
	&"tip": preload("res://assets/ui/trickcal/hub/UI_HUB_TIP.tres"),
	&"rules": preload("res://assets/ui/trickcal/hub/UI_HUB_RULES.tres"),
	&"settings": preload("res://assets/ui/trickcal/hub/UI_HUB_SETTINGS.tres"),
	&"next": preload("res://assets/ui/trickcal/hub/UI_HUB_NEXT.tres"),
	&"mode_green": preload("res://assets/ui/trickcal/hub/UI_HUB_MODE_GREEN.tres"),
	&"mode_blue": preload("res://assets/ui/trickcal/hub/UI_HUB_MODE_BLUE.tres"),
	&"mode_pink": preload("res://assets/ui/trickcal/hub/UI_HUB_MODE_PINK.tres"),
	&"tip_plate": preload("res://assets/ui/trickcal/hub/UI_HUB_TIP_PLATE.tres"),
	&"icon_disc": preload("res://assets/ui/trickcal/hub/UI_HUB_ICON_DISC.tres"),
	&"round_button": preload("res://assets/ui/trickcal/hub/UI_HUB_ROUND_BUTTON.tres"),
}
static var _skin_cache: Dictionary = {}


static func icon(role: StringName) -> TextureRect:
	var image := TextureRect.new()
	image.name = "HubArt_" + String(role)
	image.set_meta("hub_art_role", role)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	image.texture = ART[role] as Texture2D
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image


## 높이를 먼저 맞춘 뒤 중앙만 늘려 모서리와 선 굵기를 보존한다.
## PNG 원본은 바꾸지 않고 표시용 텍스처를 높이별로 한 번만 준비한다.
static func skin(role: StringName, height: int, margin: float = 0.0) -> StyleBoxTexture:
	var key: String = "%s:%d" % [role, height]
	if not _skin_cache.has(key):
		var source: AtlasTexture = ART[role] as AtlasTexture
		var pixels: Image = source.atlas.get_image().get_region(Rect2i(source.region))
		var width: int = maxi(height, roundi(float(pixels.get_width()) * float(height) / float(pixels.get_height())))
		pixels.resize(width, height, Image.INTERPOLATE_LANCZOS)
		pixels.generate_mipmaps()
		_skin_cache[key] = ImageTexture.create_from_image(pixels)
	var box := StyleBoxTexture.new()
	box.texture = _skin_cache[key] as Texture2D
	box.set_texture_margin_all(float(height) * 0.48)
	box.set_content_margin_all(margin)
	return box


static func button(item: Button, role: StringName, height: int) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var box: StyleBoxTexture = skin(role, height)
		box.modulate_color = {
			"normal": Color.WHITE,
			"hover": Color(1.07, 1.07, 1.07),
			"pressed": Color(0.90, 0.90, 0.90),
			"disabled": Color(0.70, 0.70, 0.70, 0.65),
		}[state]
		item.add_theme_stylebox_override(state, box)
	item.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
