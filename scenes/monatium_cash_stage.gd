## The same six bundles carry from the board into the printed victory scene.
extends Control

const COUNT := 6
const FIRST_DROP_AT := 0.48
const DROP_INTERVAL := 0.35
const DROP_TIME := 0.34
const IMPACT_AT := FIRST_DROP_AT + DROP_INTERVAL * (COUNT - 1)
const INTRO_SECONDS := 3.16
const FADE_SECONDS := 0.43
const HANDOFF_SECONDS := 0.82
const BUNDLE_PATH := "res://assets/fx/law_fx/victory_prints/monatium_cash_v01.png"
const POSITIONS: Array[Vector2] = [
	Vector2(-150, 6), Vector2(8, 21), Vector2(145, 9),
	Vector2(-83, -49), Vector2(75, -52), Vector2(-9, -102),
]
const ANGLES: Array[float] = [-0.13, 0.07, 0.15, -0.09, 0.11, -0.055]
const COIN_ENDS: Array[Vector2] = [
	Vector2(-239, 79), Vector2(-208, 91), Vector2(-168, 97),
	Vector2(105, 100), Vector2(157, 94), Vector2(197, 81), Vector2(225, 66),
]

var _bundle: Texture2D
var _region := Rect2()
var _focus := Vector2.ZERO
var _source_view := Vector2.ONE
var _time := 0.0


func setup(focus: Vector2, source_view: Vector2) -> void:
	name = "MonatiumCashStage"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus = focus
	_source_view = source_view
	_bundle = TextureCache.fetch(BUNDLE_PATH)
	if _bundle != null:
		_region = PaintedFx.region(_bundle)


static func drop_at(index: int) -> float:
	return FIRST_DROP_AT + DROP_INTERVAL * index


func seek(time: float, view: Vector2) -> void:
	if time == _time and view == size:
		return
	_time = time
	size = view
	queue_redraw()


func _draw() -> void:
	if _bundle == null or _region.size.x <= 0.0:
		return
	var printed := smoothstep(INTRO_SECONDS, INTRO_SECONDS + HANDOFF_SECONDS, _time)
	var arrival := smoothstep(0.16, IMPACT_AT, _time)
	var start := _focus * size / _source_view + Vector2(0, size.y * 0.13)
	var center := start.lerp(size * Vector2(0.405, 0.565), printed)
	var ratio := minf(size.x / 1366.0, size.y / 768.0)
	var scale_factor := ratio * lerpf(0.91, 1.07, printed)
	var stamp_scale := Vector2.ONE * scale_factor

	draw_set_transform(center + Vector2(0, 78) * scale_factor, -0.018, Vector2(1, 0.19) * scale_factor)
	draw_circle(Vector2.ZERO, 249.0, Color(0.025, 0.052, 0.10, 0.30 * arrival), true, -1.0, true)

	var width := 226.0
	var bounds := Vector2(width, width * _region.size.y / _region.size.x)
	for index: int in COUNT:
		var land := drop_at(index)
		if _time < land - DROP_TIME:
			continue
		var descent := clampf(inverse_lerp(land - DROP_TIME, land, _time), 0.0, 1.0)
		var rebound := sin(smoothstep(land, land + 0.18, _time) * PI)
		var flight := 1.0 - descent * descent
		var at := POSITIONS[index] + Vector2((34.0 if index % 2 == 0 else -44.0) * flight, -320.0 * flight - rebound * 10.0)
		var angle := ANGLES[index] + (0.21 if index % 2 == 0 else -0.18) * flight
		draw_set_transform(center + at * scale_factor, angle, stamp_scale)
		draw_texture_rect_region(_bundle, Rect2(-bounds * 0.5, bounds), _region, Color(1.0, 1.0, 1.0, smoothstep(0.0, 0.18, descent)))
		_draw_contact(center + (POSITIONS[index] + Vector2(0, 29)) * scale_factor, scale_factor, land)
	_draw_coins(center, scale_factor, printed)
	draw_set_transform(Vector2.ZERO)


func _draw_contact(at: Vector2, scale_factor: float, land: float) -> void:
	if _time < land or _time >= land + 0.24:
		return
	var life := clampf(inverse_lerp(land, land + 0.24, _time), 0.0, 1.0)
	draw_set_transform(at, 0.0, Vector2.ONE * scale_factor)
	var color := Color(1.0, 0.84, 0.44, (1.0 - life) * 0.9)
	for side: float in [-1.0, 1.0]:
		for i: int in 3:
			var ray := Vector2(side * (0.75 + i * 0.11), -0.22 - i * 0.21).normalized()
			var origin := Vector2(side * 58.0, 1.0) + ray * life * 30.0
			draw_line(origin, origin + ray * (11.0 + i * 4.0), color, 2.6, true)


func _draw_coins(center: Vector2, scale_factor: float, printed: float) -> void:
	for index: int in COIN_ENDS.size():
		var launch := IMPACT_AT + 0.025 * index
		if _time < launch:
			continue
		var land := clampf(inverse_lerp(launch, launch + 0.49, _time), 0.0, 1.0)
		var at := Vector2(0, -65).lerp(COIN_ENDS[index], ease(land, 0.62))
		at.y -= sin(land * PI) * (102.0 + index * 8.0)
		var tilt := lerpf(0.32 + absf(cos(land * TAU * 1.35 + index)) * 0.68, 0.41, smoothstep(0.72, 1.0, land))
		var radius := 12.0 + float(index % 3) * 2.2
		draw_set_transform(center + at * scale_factor, lerpf(land * 1.7, float(index % 3 - 1) * 0.12, smoothstep(0.66, 1.0, land)), Vector2(1.0, tilt) * scale_factor)
		draw_circle(Vector2(0, 5), radius, Color("664328"), true, -1.0, true)
		draw_circle(Vector2(0, 2), radius, Color("bd7529"), true, -1.0, true)
		draw_circle(Vector2.ZERO, radius, Color("f8bd52"), true, -1.0, true)
		draw_arc(Vector2.ZERO, radius - 3.0, 0.0, TAU, 22, Color("ffec9f"), 1.7, true)
		if printed < 0.85:
			draw_line(Vector2(-3, 2), Vector2(3, -4), Color("fff1b5"), 2.2, true)
