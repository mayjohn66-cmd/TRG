## Bites and replacement animation visualize the roll, without choosing its result.
class_name IceCreamView
extends Control

const SIZE := Vector2(420, 300)
const BITE_AT := 0.84
const REVEAL_AT := 1.20
const PUT_ASIDE_AT := 1.65
const STICK_LAND_AT := 2.08
const REFILL_AT := 2.17
const TOTAL_TIME := 2.65
const AGAIN_TOTAL_TIME := 3.04
const INK := Color("523426")
const BERRY := Color("a5374e")
const FONT: Font = preload("res://assets/fonts/game_ui_font.tres")
const BAR: Texture2D = preload("res://assets/fx/judgment/icecream_bar.png")
const BITE_MASK: Shader = preload("res://scenes/icecream_bite.gdshader")
const BODY_HEIGHT := 171.0
const CENTER := Vector2(210, 131)

var settled := false
var _t := 0.0
var _spaces := 1
var _again := false
var _parked_count := 0
var _bar := Sprite2D.new()
var _bite_material := ShaderMaterial.new()
var _stick := StyleBoxFlat.new()


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick.bg_color = Color("eac18e")
	_stick.border_color = INK
	_stick.set_border_width_all(2)
	_stick.set_corner_radius_all(13)
	_bite_material.shader = BITE_MASK
	_bar.texture = BAR
	_bar.material = _bite_material
	add_child(_bar)


func begin(details: Dictionary, parked_count: int = 0) -> void:
	_parked_count = parked_count
	_spaces = clampi(int(details.get("spaces", 1)), 1, 6)
	_again = bool(details.get("again", false))
	apply_time(0.0)


static func caption(details: Dictionary, steps: int) -> String:
	return ToolIceCream.caption(details, steps)


func apply_time(t: float) -> void:
	_t = t
	settled = t >= REVEAL_AT
	var bite := 0.0
	if t >= BITE_AT:
		bite = lerpf(0.77, 0.96, smoothstep(BITE_AT + 0.12, REVEAL_AT, t))
	var replaced := _again and t >= REFILL_AT
	var entry := ease(clampf(t / 0.25, 0.0, 1.0), 0.38)
	var pickup := _refill_progress()
	var recoil := _bite_recoil()
	var windup := sin(clampf(inverse_lerp(0.40, BITE_AT, t), 0.0, 1.0) * PI)
	_bar.visible = t < REVEAL_AT or replaced
	_bar.position = CENTER + Vector2(-9.0 * windup + 7.0 * recoil, -27.0 * (1.0 - entry) + 5.0 * recoil)
	_bar.rotation = -0.09 * windup + 0.055 * recoil
	var squash := Vector2(1.0 + 0.06 * recoil, 1.0 - 0.07 * recoil)
	_bar.scale = squash * (BODY_HEIGHT / BAR.get_height())
	if replaced:
		_bar.position = CENTER + Vector2(74, -58.0 * (1.0 - pickup))
		_bar.rotation = 0.18 * (1.0 - pickup)
		_bar.modulate.a = minf(pickup * 2.8, 1.0)
	else:
		_bar.modulate.a = entry
	_bite_material.set_shader_parameter("cut", 0.0 if replaced else bite)
	queue_redraw()


func _draw() -> void:
	var shift := _refill_progress() if _again else 0.0
	var start_shift := 28.0 * (1.0 - ease(clampf(_t / 0.25, 0.0, 1.0), 0.38))
	var put_aside := smoothstep(PUT_ASIDE_AT, STICK_LAND_AT, _t) if _again else 0.0
	var pile_angle := _pile_angle(_parked_count)
	var result_at := Vector2(CENTER.x, 193.0 - start_shift).lerp(_pile_position(_parked_count), put_aside)
	result_at.y -= sin(put_aside * PI) * 24.0
	var show_stamp := _t >= REVEAL_AT
	var recoil := _bite_recoil()
	if _parked_count > 0 or put_aside > 0.0:
		draw_set_transform(Vector2(93, 251), 0.0, Vector2(1.0, 0.12))
		var shadow := 0.25 if _parked_count > 0 else 0.25 * put_aside
		draw_circle(Vector2.ZERO, 75.0, Color(0.19, 0.10, 0.07, shadow), true, -1.0, true)
	for index: int in range(maxi(0, _parked_count - 8), _parked_count):
		_draw_stick(_pile_position(index), _pile_angle(index), true, true)
	_draw_stick(result_at + Vector2(7.0 * recoil, 5.0 * recoil), lerpf(0.03 * recoil, pile_angle, put_aside), show_stamp, _again)
	if shift > 0.0:
		_draw_stick(Vector2(CENTER.x + 74.0, 193.0 - 58.0 * (1.0 - shift)), 0.18 * (1.0 - shift), false)
	draw_set_transform(Vector2.ZERO)
	_draw_crumbs(CENTER + Vector2(0, 28))


func _pile_position(index: int) -> Vector2:
	return Vector2(107.0 + sin(index * 2.5) * 11.0, 238.0 - minf(index, 6) * 3.8 + sin(index * 3.9) * 3.0)


func _pile_angle(index: int) -> float:
	return -PI / 2.0 + sin(index * 2.4 + 0.65) * 0.27


func _draw_stick(at: Vector2, angle: float, result: bool, winner: bool = false) -> void:
	draw_set_transform(at, angle)
	draw_style_box(_stick, Rect2(-13, -87, 26, 145))
	draw_line(Vector2(-9, -70), Vector2(-9, 43), Color("d8a975"), 1.0, true)
	draw_line(Vector2(9, -69), Vector2(9, 41), Color("f7d6a6"), 1.0, true)
	if not result:
		return
	var value := L10n.t("한번 더!") if winner else L10n.tf("%d칸", [_spaces])
	var px := 18
	var width := FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var baseline := (FONT.get_ascent(px) - FONT.get_descent(px)) * 0.5
	draw_set_transform(at + Vector2(0.0, -24.0).rotated(angle), angle + PI / 2.0)
	draw_string(FONT, Vector2(-width * 0.5, baseline), value, HORIZONTAL_ALIGNMENT_LEFT, -1, px, BERRY if winner else INK)


func _draw_crumbs(origin: Vector2) -> void:
	if _t < BITE_AT or _t >= BITE_AT + 0.36:
		return
	var life := (_t - BITE_AT) / 0.36
	for index: int in 11:
		var direction := Vector2.from_angle(PI + index * 0.32)
		var speed := 28.0 + (index % 4) * 11.0
		var position := origin + direction * speed * ease(life, 0.52) + Vector2(0, life * life * 29)
		var color := Color("934f3c") if index % 3 == 0 else Color("ffd7e2")
		color.a = 1.0 - life
		draw_circle(position, (2.2 + index % 3) * (1.0 - life * 0.5), color, true, -1.0, true)


func _refill_progress() -> float:
	return ease(clampf((_t - REFILL_AT) / 0.37, 0.0, 1.0), 0.34)


func _bite_recoil() -> float:
	if _t < BITE_AT:
		return 0.0
	var elapsed := clampf((_t - BITE_AT) / 0.19, 0.0, 1.0)
	return (1.0 - elapsed) * (1.0 - elapsed)
