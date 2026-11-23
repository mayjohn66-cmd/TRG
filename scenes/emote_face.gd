class_name EmoteFace
extends Control

const STICKERS := {
	&"joy": preload("res://content_trickcal/illustrations/ui/emotes/joy.png"),
	&"flustered": preload("res://content_trickcal/illustrations/ui/emotes/flustered.png"),
	&"sad": preload("res://content_trickcal/illustrations/ui/emotes/sad.png"),
}
const OUTLINE_RADIUS := 1.1
const OUTLINE_TINT := Color("544c32")

var face: StringName = &"joy"


func _init(kind: StringName = &"joy", extent: float = 40.0) -> void:
	face = kind
	custom_minimum_size = Vector2(extent, extent)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _draw() -> void:
	var sticker: Texture2D = STICKERS.get(face, STICKERS[&"joy"])
	var source_size := sticker.get_size()
	var available_size := size - Vector2.ONE * OUTLINE_RADIUS * 2.0
	var scale_factor := minf(available_size.x / source_size.x, available_size.y / source_size.y)
	var fitted_size := source_size * scale_factor
	var bounds := Rect2((size - fitted_size) * 0.5, fitted_size)
	for step: int in 8:
		var offset := Vector2.from_angle(TAU * step / 8.0) * OUTLINE_RADIUS
		draw_texture_rect(sticker, Rect2(bounds.position + offset, fitted_size), false, OUTLINE_TINT)
	draw_texture_rect(sticker, bounds, false)
