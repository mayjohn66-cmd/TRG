## Draws the fortune already chosen by the rules engine.
class_name OmikujiView
extends Control

const SIZE := Vector2(420, 300)
const SHAKE_END := 0.92
const DRAW_AT := 0.96
const REVEAL_AT := 1.52
const TOTAL_TIME := 2.52
const FOLD_AT := 1.99
const TIE_AT := 2.35
const WRAP_AT := 2.63
const TIED_AT := 2.86
const ROPE_X := 52.0
const ROPE_SLOTS := 9
const GREAT_TOTAL_TIME := 3.10
const INK := Color("422822")
const PAPER := Color("fff0cd")
const CINNABAR := Color("a73532")
const FONT: Font = preload("res://assets/fonts/game_ui_font.tres")
const TUBE: Texture2D = preload("res://assets/fx/judgment/omikuji_tube.png")

var settled := false
var _t := 0.0
var _label := "길"
var _key: StringName = &"good"
var _ticket := 1
var _tied_count := 0
var _paper := StyleBoxFlat.new()
var _stick := StyleBoxFlat.new()


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.bg_color = PAPER
	_paper.border_color = INK
	_paper.set_border_width_all(2)
	_paper.set_corner_radius_all(6)
	_paper.shadow_color = Color(0.14, 0.08, 0.07, 0.32)
	_paper.shadow_size = 6
	_paper.shadow_offset = Vector2(3, 5)
	_stick.bg_color = Color("edbb73")
	_stick.border_color = INK
	_stick.set_border_width_all(2)
	_stick.set_corner_radius_all(3)


func begin(details: Dictionary, tied_count: int = 0) -> void:
	_tied_count = tied_count
	_key = StringName(details.get("fortune", &"good"))
	_label = str(details.get("label", "길"))
	_ticket = int(details.get("ticket", 1))
	apply_time(0.0)


static func caption(details: Dictionary, steps: int) -> String:
	return ToolOmikuji.caption(details, steps)


func apply_time(t: float) -> void:
	_t = t
	settled = t >= REVEAL_AT
	queue_redraw()


func _draw() -> void:
	_draw_rope()
	for index: int in range(maxi(0, _tied_count - ROPE_SLOTS + int(_key == &"great")), _tied_count):
		_draw_paper_knot(_knot_slot(index), index, _knot_angle(index), 0.74)
	draw_set_transform(Vector2.ZERO)
	var entry := ease(clampf(_t / 0.22, 0.0, 1.0), 0.36)
	var shake := clampf(inverse_lerp(0.16, SHAKE_END, _t), 0.0, 1.0)
	var swing := sin(shake * TAU * 3.0) * sin(shake * PI)
	var stick_rise := ease(clampf((_t - DRAW_AT) / 0.30, 0.0, 1.0), 0.34)
	var center := Vector2(141.0 + swing * 9.0, 190.0 - (1.0 - entry) * 20.0)
	draw_set_transform(Vector2(142, 252), 0.0, Vector2(1, 0.24))
	draw_circle(Vector2.ZERO, 57.0, Color(0.19, 0.10, 0.07, 0.23), true, -1.0, true)

	var lean := 0.17 * swing - 0.13 * stick_rise
	draw_set_transform(center, lean, Vector2.ONE)
	var body_size := TUBE.get_size() * (171.0 / TUBE.get_height())
	var body := Rect2(Vector2(-body_size.x * 0.5, -110.0), body_size)
	draw_texture_rect(TUBE, body, false)
	var tube_label := L10n.t("점괘")
	if tube_label.length() == 2:
		_draw_text(tube_label[0], Vector2(0, -20), 20, INK)
		_draw_text(tube_label[1], Vector2(0, 6), 20, INK)
	else:
		_draw_text(tube_label, Vector2(0, -7), 20, INK, 31.0)
	if stick_rise > 0.0:
		_draw_stick(Vector2(0, -95), stick_rise)
	draw_set_transform(Vector2.ZERO)
	_draw_ticket()


func _draw_stick(hole: Vector2, rise: float) -> void:
	var visible_length := 73.0 * rise
	var top := hole - Vector2(0, visible_length)
	draw_style_box(_stick, Rect2(top - Vector2(6, 0), Vector2(12, visible_length)))
	draw_line(top + Vector2(-3, 3), hole + Vector2(-3, -1), Color("ffd69c"), 1, true)
	if visible_length > 18.0:
		draw_line(top + Vector2(-4, 7), top + Vector2(4, 7), CINNABAR, 4, true)
	if rise > 0.8:
		_draw_text("%02d" % _ticket, top + Vector2(0, 29), 9, INK)


func _draw_ticket() -> void:
	var slide := clampf((_t - 1.24) / 0.33, 0.0, 1.0)
	if slide <= 0.0:
		return
	if _key == &"great" and _t >= TIE_AT:
		_draw_tied_ticket()
		return
	var open := ease(slide, 0.32)
	var pop := sin(slide * PI)
	var origin := Vector2(lerpf(166.0, 286.0, open), 142.0 - pop * 9.0)
	var tint := CINNABAR
	if _key == &"great":
		tint = Color("a65b16")
	elif _key in [&"bad", &"worst"]:
		tint = Color("544b78")
	var fold := smoothstep(FOLD_AT, TIE_AT, _t) if _key == &"great" else 0.0
	var folded_scale := Vector2(maxf(open, 0.05), 1.0) * Vector2(lerpf(1.0, 0.34, fold), lerpf(1.0, 0.23, fold))
	draw_set_transform(origin, -0.09 + 0.17 * (1.0 - open) - fold * 0.16, folded_scale)
	draw_style_box(_paper, Rect2(-64, -82, 128, 164))
	draw_rect(Rect2(-53, -71, 106, 142), tint, false, 2)
	draw_line(Vector2(-53, -37), Vector2(53, -37), tint, 1, true)
	draw_line(Vector2(-53, 38), Vector2(53, 38), tint, 1, true)
	if slide >= 0.58 and fold < 0.52:
		_draw_text("No. %02d" % _ticket, Vector2(0, -54), 15, tint)
		_draw_text(L10n.t(_label), Vector2(0, 1), 44, tint, 96.0)
		_draw_text(L10n.t("오미쿠지"), Vector2(0, 53), 13, tint)
	draw_set_transform(Vector2.ZERO)

	var spark := clampf((_t - REVEAL_AT) / 0.40, 0.0, 1.0)
	if _t >= REVEAL_AT and spark < 1.0:
		var rays := 9 if _key == &"great" else 5
		var light := Color("ffd46b") if _key == &"great" else tint.lightened(0.38)
		light.a = (1.0 - spark) * 0.86
		for index: int in rays:
			var direction := Vector2.from_angle(index * TAU / rays - 0.25)
			var at := origin + direction * Vector2(70 + 14 * spark, 87 + 12 * spark)
			draw_line(at, at + direction * (8 + 9 * (1.0 - spark)), light, 3, true)


func _draw_rope() -> void:
	var points := PackedVector2Array()
	for offset: int in range(0, 241, 8):
		var y := 26.0 + offset
		points.append(Vector2(_rope_x_at(y), y))
	draw_polyline(points, Color("59402c"), 4.6, true)
	draw_polyline(points, Color("cb9b5f"), 2.8, true)
	for index: int in range(1, points.size()):
		var at := points[index]
		at.y += sin(index * 2.1) * 1.6
		draw_line(at - Vector2(1.1, 1.2), at + Vector2(0.9, 0.6), Color(0.95, 0.80, 0.54, 0.55 + sin(index * 1.7) * 0.18), 1.0, true)


func _rope_x_at(y: float) -> float:
	return ROPE_X + sin((y - 26.0) / 240.0 * PI) * 5.0


func _knot_slot(index: int) -> Vector2:
	# Fill widely spaced spots first, then use the gaps on the same rope.
	var y := 52.0 + float((index * 2) % ROPE_SLOTS) * 23.0
	return Vector2(_rope_x_at(y), y)


func _knot_angle(index: int) -> float:
	return sin(index * 2.4 + 0.7) * 0.20


func _draw_tied_ticket() -> void:
	var travel := smoothstep(TIE_AT, WRAP_AT, _t)
	var tighten := smoothstep(WRAP_AT, TIED_AT, _t)
	var slot := _knot_slot(_tied_count)
	var at := Vector2(286, 142).lerp(slot, travel)
	at.y -= 22.0 * sin(travel * PI)
	var angle := lerpf(-0.25, _knot_angle(_tied_count), travel)
	_draw_paper_knot(at, _tied_count, angle, lerpf(0.69, 0.74, travel), tighten)


func _draw_paper_knot(at: Vector2, index: int, angle: float, paper_scale: float, tighten: float = 1.0) -> void:
	draw_set_transform(at, angle, Vector2.ONE * paper_scale)
	var drape := sin(index * 2.8 + 0.4)
	# The ends start as one flat strip. One end hooks over the rope while the other drops through.
	var short_end := Vector2(-33, 0).lerp(Vector2(-24 - drape * 4.0, -24 + drape * 5.0), tighten)
	var short_fold := Vector2(-13, 0).lerp(Vector2(-9, -9), tighten)
	var long_fold := Vector2(13, 0).lerp(Vector2(16, 16), tighten)
	var long_end := Vector2(41, 0).lerp(Vector2(25 + drape * 5.0, 46 + drape * 7.0), tighten)
	var short_tail := PackedVector2Array([
		short_end + Vector2(-3, -7), short_end.lerp(short_fold, 0.44) + Vector2(-1, -6),
		short_fold + Vector2(2, -6), Vector2(4, -4), Vector2(-1, 6),
		short_fold + Vector2(-3, 7), short_end + Vector2(-3, 5), short_end + Vector2(-1, 1),
	])
	var long_tail := PackedVector2Array([
		Vector2(1, -6), long_fold + Vector2(5, -7),
		long_fold.lerp(long_end, 0.53) + Vector2(4, -4), long_end + Vector2(5, -3),
		long_end + Vector2(-2, 1), long_end + Vector2(-7, 2),
		long_fold.lerp(long_end, 0.48) + Vector2(-6, 3), long_fold + Vector2(-6, 3), Vector2(0, 6),
	])
	_draw_paper_fold(short_tail, Color("eee9df"))
	_draw_paper_fold(long_tail, Color("fff9eb"))
	draw_colored_polygon(PackedVector2Array([
		short_fold + Vector2(1, -5), Vector2(3, -3), Vector2(-2, 5), short_fold + Vector2(-2, 5),
	]), Color("d7cbbb"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(2, -5), long_fold + Vector2(4, -5), long_fold + Vector2(-5, 2), Vector2(1, 4),
	]), Color("e7dbca"))
	draw_line(short_end + Vector2(-1, -3), short_fold + Vector2(-1, 0), Color("d6cab8"), 1.0, true)
	draw_line(long_fold + Vector2(1, -3), long_end + Vector2(1, -2), Color("e6d8c1"), 1.0, true)
	var ink := Color(0.44, 0.39, 0.34, 0.45)
	for mark: int in range(6):
		var print_at := long_fold.lerp(long_end, 0.23 + mark * 0.105) + Vector2(-3, 1)
		var width := 2.2 + sin(mark * 2.4 + index) * 1.15
		draw_line(print_at, print_at + Vector2(width, -0.6), ink, 0.9, true)
		if mark % 2 == 0:
			draw_line(print_at + Vector2(3.2, -1.7), print_at + Vector2(4.7, -2.0), ink, 0.8, true)
	if tighten > 0.0:
		var wrap_top := Vector2(-8, -5).lerp(Vector2(-9, -10), tighten)
		var wrap_bottom := Vector2(7, 4).lerp(Vector2(7, 8), tighten)
		var wrap := PackedVector2Array([
			wrap_top, wrap_top + Vector2(12, -2), Vector2(10, 1),
			wrap_bottom, Vector2(-5, 7), Vector2(-11, 0),
		])
		_draw_paper_fold(wrap, Color("f8efdc"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-9, 0), Vector2(7, 2), wrap_bottom + Vector2(-1, -1), Vector2(-4, 6),
		]), Color("ddceba"))
		draw_line(wrap_top + Vector2(2, 4), Vector2(7, 1), Color("b8a78d"), 1.0, true)
		draw_line(wrap_top + Vector2(3, 2), Vector2(4, -1), Color("fff9ec"), 0.9, true)
	draw_set_transform(Vector2.ZERO)


func _draw_paper_fold(outline: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(outline, color)
	outline.append(outline[0])
	draw_polyline(outline, Color("806d58"), 1.25, true)


func _draw_text(value: String, at: Vector2, px: int, color: Color, max_width: float = INF) -> void:
	var width := FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	if width > max_width:
		px = maxi(1, floori(px * max_width / width))
		width = FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var baseline := (FONT.get_ascent(px) - FONT.get_descent(px)) * 0.5
	draw_string(FONT, at + Vector2(-width * 0.5, baseline), value, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
