# File: res://scenes/emote_bubble.gd
# Class: class_name EmoteBubble
# Role: 감정 표현 말풍선 (클래시 로얄 이모트 같은 연출). 프로필 아바타 옆에서 통통 튀며 나타나 얼굴 아이콘(EmoteFace) + 한마디를 보여 주고, 잠시 뒤 줄어들며 사라진 다음 queue_free된다.
#       꼬리는 tail_dir 쪽(아래 = 아바타가 아래에 있음, 위 = 아바타가 위에 있음)을 향하고 tail_x(말풍선 안 x 좌표)에서 아바타를 가리킨다.
class_name EmoteBubble
extends Control

const PAD: Vector2 = Vector2(16.0, 10.0)
const TAIL: float = 14.0
const HOLD_SECONDS: float = 2.2

var emote_id: int = 0
## 꼬리 방향: 1이면 아래로(말풍선이 아바타 위), -1이면 위로(말풍선이 아바타 아래).
var tail_dir: int = 1
var tail_x: float = 40.0

var _emoji: EmoteFace = null
var _text: Label = null
var _box_size: Vector2 = Vector2.ZERO


func setup(id: int, pointing_down: bool) -> void:
	emote_id = id
	tail_dir = 1 if pointing_down else -1
	name = "EmoteBubble"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 70
	var entry: Dictionary = EmoteCatalog.entry(id)
	_emoji = EmoteFace.new(entry["face"], 42.0)
	add_child(_emoji)
	_text = Label.new()
	_text.text = str(entry["text"])
	_text.add_theme_font_size_override("font_size", 20)
	_text.add_theme_color_override("font_color", Color("2b2118"))
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_text)


## 글꼴은 트리에 들어간 뒤에야 테마를 따르므로 크기는 _ready에서 잰다 (MainBoard는 add_child 뒤에 배치한다).
func _ready() -> void:
	var emoji_size: Vector2 = _emoji.get_minimum_size()
	var text_size: Vector2 = _text.get_minimum_size()
	_box_size = Vector2(PAD.x * 2.0 + emoji_size.x + 8.0 + text_size.x, PAD.y * 2.0 + maxf(emoji_size.y, text_size.y))
	var top: float = TAIL if tail_dir < 0 else 0.0
	_emoji.position = Vector2(PAD.x, top + (_box_size.y - emoji_size.y) / 2.0)
	_text.position = Vector2(PAD.x + emoji_size.x + 8.0, top + (_box_size.y - text_size.y) / 2.0)
	size = Vector2(_box_size.x, _box_size.y + TAIL)
	tail_x = clampf(tail_x, 22.0, _box_size.x - 22.0)


## 꼬리 끝이 가리키는 점(이 말풍선의 좌표계). 배치할 때 이 점을 아바타에 맞춘다.
func tail_tip() -> Vector2:
	return Vector2(tail_x, size.y if tail_dir > 0 else 0.0)


## 통통 튀며 등장 -> 이모지가 한 번 더 튀고 -> HOLD_SECONDS 동안 머문 뒤 줄어들며 사라진다.
func play(pace: float = 1.0) -> void:
	pivot_offset = tail_tip()
	scale = Vector2(0.2, 0.2)
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.1)
	tween.parallel().tween_property(self, "scale", Vector2(1.12, 1.12), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12)
	_emoji.pivot_offset = _emoji.get_minimum_size() / 2.0
	tween.tween_property(_emoji, "rotation", -0.25, 0.08)
	tween.tween_property(_emoji, "rotation", 0.2, 0.1)
	tween.tween_property(_emoji, "rotation", 0.0, 0.08)
	tween.tween_interval(HOLD_SECONDS * maxf(pace, 0.3))
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.parallel().tween_property(self, "scale", Vector2(0.7, 0.7), 0.2)
	tween.tween_callback(queue_free)


func _draw() -> void:
	var top: float = TAIL if tail_dir < 0 else 0.0
	var box := Rect2(Vector2(0.0, top), _box_size)
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0, 0, 0, 0.28)
	shadow.set_corner_radius_all(18)
	draw_style_box(shadow, Rect2(box.position + Vector2(0, 4), box.size))
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("fffdf5")
	fill.border_color = Color("3b2a18")
	fill.set_border_width_all(3)
	fill.set_corner_radius_all(18)
	draw_style_box(fill, box)
	var base_y: float = box.end.y - 2.0 if tail_dir > 0 else box.position.y + 2.0
	var tip_y: float = size.y if tail_dir > 0 else 0.0
	var tail := PackedVector2Array([Vector2(tail_x - 11.0, base_y), Vector2(tail_x + 11.0, base_y), Vector2(tail_x, tip_y)])
	draw_colored_polygon(tail, Color("fffdf5"))
	draw_polyline(PackedVector2Array([Vector2(tail_x - 11.0, base_y), Vector2(tail_x, tip_y), Vector2(tail_x + 11.0, base_y)]), Color("3b2a18"), 3.0, true)
