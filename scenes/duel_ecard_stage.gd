## Simple symbol cards. Hidden picks stay face-down until both cards turn together.
class_name DuelEcardStage
extends Control

signal finished

const FONT: Font = preload("res://assets/fonts/game_ui_font.tres")
const QUEEN: Texture2D = preload("res://assets/ui/trickcal/duel/ecard/queen.svg")
const CITIZEN: Texture2D = preload("res://assets/ui/trickcal/duel/ecard/citizen.svg")
const REBEL: Texture2D = preload("res://assets/ui/trickcal/duel/ecard/rebel.svg")
const INK := Color("493951")
const GOLD := Color("f3c764")
const FACE_AT := 0.48
const DISCARD_AT := 1.72
const CARD_SIZE := Vector2(112, 144)
var arena: DuelArena
var ready_seats: Array[int] = []
var revealed: Dictionary = {}
var result: Dictionary = {}
var pending: Dictionary = {}
var active := false
var elapsed := 0.0
var counts_applied := false
var round_number := 1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func reset_round() -> void:
	round_number = DuelRules.ECARD_CITIZENS - DuelRules.ecard_count(arena.setup_data, true, 1) + 1
	ready_seats.clear()
	revealed.clear()
	result.clear()
	pending.clear()
	elapsed = 0.0
	active = false
	counts_applied = false
	queue_redraw()

func mark_ready(seat: int) -> void:
	if not ready_seats.has(seat): ready_seats.append(seat)
	queue_redraw()

func play_reveal(data: Dictionary) -> void:
	result = data.duplicate(true)
	pending = (data["picks"] as Dictionary).duplicate()
	revealed.clear()
	elapsed = 0.0
	counts_applied = false
	active = true
	Sfx.play(&"card_throw", -6.0)
	queue_redraw()

func cancel() -> void:
	var was_active := active
	active = false
	if was_active: finished.emit()

func _process(delta: float) -> void:
	if not active: return
	elapsed += delta
	if elapsed >= FACE_AT and revealed.is_empty():
		revealed = pending.duplicate()
		Sfx.play(&"card_impact", -5.0)
	if elapsed >= DISCARD_AT and not counts_applied:
		counts_applied = true
		# Only the engine's public remaining counts reach the next selection.
		if result.has("ecard_hands"):
			arena.setup_data["hands"] = (result["ecard_hands"] as Array).duplicate(true)
		if int(result["winner"]) == -1: Sfx.play(&"card_throw", -8.0)
	if elapsed >= DuelRules.ECARD_REVEAL_TIME:
		active = false
		finished.emit()
	queue_redraw()

func symbol(seat: int, value: int) -> Texture2D:
	return CITIZEN if value == DuelRules.ECARD_CITIZEN else (QUEEN if seat == arena.challenger else REBEL)

func card_name(seat: int, value: int) -> String:
	return "시민" if value == DuelRules.ECARD_CITIZEN else ("여왕" if seat == arena.challenger else "반란군")

func make_choice(value: int, seat: int, callback: Callable) -> Button:
	var count := DuelRules.ecard_count(arena.setup_data, seat == arena.challenger, value)
	var button := arena.board._make_button("", callback, 20, Color("3b4766"), 12)
	button.name = "SpecialChoice" if value == 0 else "CitizenChoice"
	button.tooltip_text = "%s %d장" % [card_name(seat, value), count]
	button.custom_minimum_size = Vector2(146, 132)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_top = 6
	column.offset_left = 8
	column.offset_right = -8
	column.offset_bottom = -6
	column.add_theme_constant_override("separation", 0)
	button.add_child(column)
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = symbol(seat, value)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(84, 84)
	column.add_child(icon)
	var label := arena.board._make_label("%s ×%d" % [card_name(seat, value), count], 22, INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_constant_override("outline_size", 0)
	column.add_child(label)
	return button

func _text(text: String, at: Vector2, px: int, color: Color = INK) -> void:
	var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(FONT, at + Vector2(-width / 2, px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)

func _card(rect: Rect2, seat: int, value: int, face: bool, alpha: float = 1.0) -> void:
	var large := rect.size.y > 90
	var tint := Color("f9edcf") if value == 0 and seat == arena.challenger else (Color("e9efe4") if value == 1 else Color("e7edf1"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff8e8") if face else Color("665775")
	style.bg_color.a = alpha
	style.border_color = Color("c9a76f", alpha)
	style.set_border_width_all(3 if large else 2)
	style.set_corner_radius_all(10 if large else 7)
	style.shadow_color = Color("3a2d38", alpha * 0.13)
	style.shadow_size = 3 if large else 1
	style.shadow_offset = Vector2(0, 2)
	draw_style_box(style, rect)
	if rect.size.x < 24: return
	var inset := 6.0 if large else 4.0
	var keyline := StyleBoxFlat.new()
	keyline.bg_color = Color(tint if face else Color("736382"), alpha * 0.4)
	keyline.border_color = Color("dcccaa" if face else "c5b08a", alpha * 0.65)
	keyline.set_border_width_all(1)
	keyline.set_corner_radius_all(6 if large else 4)
	draw_style_box(keyline, rect.grow(-inset))
	if face:
		var icon_size := minf(rect.size.x - (14 if large else 6), rect.size.y - (43 if large else 6))
		var icon_center := Vector2(rect.get_center().x, rect.position.y + 9 + icon_size / 2) if large else rect.get_center()
		draw_texture_rect(symbol(seat, value), Rect2(icon_center - Vector2.ONE * icon_size / 2, Vector2.ONE * icon_size), false, Color(1, 1, 1, alpha))
		if large and rect.size.x > 70:
			var divider_y := rect.end.y - 34
			draw_line(Vector2(rect.position.x + 14, divider_y), Vector2(rect.end.x - 14, divider_y), Color("c4b394", alpha * 0.65), 1, true)
			_text(card_name(seat, value), Vector2(rect.get_center().x, rect.end.y - 19), 19, Color(INK, alpha))
	else:
		var center := rect.get_center()
		var radius := minf(rect.size.x * 0.28, 28)
		draw_polyline(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center - Vector2(radius, 0), center + Vector2(0, -radius)]), Color(GOLD, alpha * 0.5), 1.5, true)
		_text("E", center, 26 if large else 16, Color(GOLD, alpha))

func _draw() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e5d8bf")
	style.border_color = Color("af9875")
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	draw_style_box(style, Rect2(Vector2.ZERO, size))
	_text("%d번째 승부" % round_number, Vector2(size.x / 2, 26), 19)
	for index: int in 2:
		var seat := arena.challenger if index == 0 else arena.defender
		var x := size.x * (0.25 if index == 0 else 0.75)
		_text(arena._seat_name(seat), Vector2(x, 26), 21)
		var face := revealed.has(seat)
		var value := int(revealed.get(seat, 0))
		var center := Vector2(x, 119)
		var alpha := 1.0
		if face and int(result["winner"]) == -1:
			var t := smoothstep(1.25, DISCARD_AT, elapsed)
			center += Vector2((-1 if index == 0 else 1) * 78, 72) * t
			alpha = 1.0 - t
		var width := CARD_SIZE.x
		if active and elapsed >= 0.28 and elapsed < 0.68:
			width *= maxf(absf((elapsed - FACE_AT) / 0.20), 0.025)
		if active or ready_seats.has(seat) or face:
			if face and int(result["winner"]) == seat:
				draw_circle(center, 76, Color("fff3b0", 0.5))
			_card(Rect2(center - Vector2(width / 2, CARD_SIZE.y / 2), Vector2(width, CARD_SIZE.y)), seat, value, face, alpha)
		else:
			draw_rect(Rect2(center - CARD_SIZE / 2, CARD_SIZE), Color("b8a78c", 0.4), false, 2)
		var special := DuelRules.ecard_count(arena.setup_data, index == 0, 0)
		var citizens := DuelRules.ecard_count(arena.setup_data, index == 0, 1)
		var hand_count := special + citizens
		_text("남은 패 %d장 · 버린 시민 %d장" % [hand_count, DuelRules.ECARD_CITIZENS - citizens], Vector2(x, 213), 16)
		var left := x - float(hand_count) * 21
		for card: int in hand_count:
			_card(Rect2(Vector2(left + card * 42, 231), Vector2(34, 45)), seat, 0 if card < special else 1, true)
	if not revealed.is_empty():
		if int(result["winner"]) == -1:
			_text("시민 무승부", Vector2(size.x / 2, 101), 22)
			_text("버리고 다시!", Vector2(size.x / 2, 133), 19)
		else:
			_text("하극상!" if result["decided_by"] == &"upset" else "승부!", Vector2(size.x / 2, 101), 26)
			_text("%s 승리" % arena._seat_name(int(result["winner"])), Vector2(size.x / 2, 137), 18)
