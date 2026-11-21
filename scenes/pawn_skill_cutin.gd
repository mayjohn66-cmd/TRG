## A short, directional cutin driven by the announcer clock (including skip).
class_name PawnSkillCutin
extends Control

var _sprite: TextureRect
var _accent := Color("ef969d")
var _time: float = 0.0
var _duration: float = 1.3


func _init() -> void:
	name = "SkillCutin"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(320, 170)


func setup(art: Dictionary, color: Color) -> void:
	_accent = color.lightened(0.25)
	var atlas := AtlasTexture.new()
	atlas.atlas = art["texture"]
	atlas.region = art["region"]
	_sprite = TextureRect.new()
	_sprite.name = "PawnIllustration"
	_sprite.texture = atlas
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite.size = Vector2(190, 190)
	_sprite.pivot_offset = _sprite.size * 0.5
	add_child(_sprite)
	set_presentation_time(0.0, 1.3)


## One clock for band, illustration and text: no timers survive a skipped entry.
func set_presentation_time(time: float, duration: float) -> void:
	_time = time * 1.3 / maxf(duration, 0.001)
	_duration = 1.3
	time = _time
	if _sprite != null:
		var enter := clampf((time - 0.07) / 0.18, 0.0, 1.0)
		var leave := clampf((time - (_duration - 0.18)) / 0.18, 0.0, 1.0)
		var ease_in := 1.0 - pow(1.0 - enter, 3.0)
		_sprite.position = Vector2(lerpf(-180.0, 65.0, ease_in) + leave * leave * 420.0, -14.0)
		var settle := sin(enter * PI) * (1.0 - enter) * 0.08
		_sprite.scale = Vector2.ONE * (1.0 + settle)
		_sprite.modulate.a = clampf(enter * 3.0, 0.0, 1.0) * (1.0 - leave)
	queue_redraw()


func _draw() -> void:
	var enter := clampf(_time / 0.17, 0.0, 1.0)
	var leave := clampf((_time - (_duration - 0.18)) / 0.18, 0.0, 1.0)
	var opened := (1.0 - pow(1.0 - enter, 3.0)) * (1.0 - leave * leave)
	if opened <= 0.001:
		return
	var shift := lerpf(-160.0, 0.0, 1.0 - pow(1.0 - enter, 3.0)) + leave * leave * 600.0
	# Pointed ends and a slim double edge turn the old rectangle into a cutin strip.
	draw_set_transform(Vector2(160.0 + shift, 136.0), 0.0, Vector2(1.0, opened))
	var points := PackedVector2Array([Vector2(-475,-58),Vector2(437,-94),Vector2(475,54),Vector2(-437,90)])
	var ink := Color("18232c").lerp(_accent.darkened(0.7), 0.18)
	ink.a = 0.94 * (1.0 - leave)
	draw_colored_polygon(points, ink)
	var edge := Color(_accent, 0.85 * (1.0-leave))
	draw_polyline(PackedVector2Array([Vector2(-475,-64),Vector2(437,-100),Vector2(444,-74)]),edge,4.0,true)
	draw_polyline(PackedVector2Array([Vector2(-444,72),Vector2(-437,96),Vector2(475,60)]),edge,4.0,true)
	draw_line(Vector2(-443,-56),Vector2(396,-89),Color("fff3d1",0.65*(1.0-leave)),1.5,true)
	draw_line(Vector2(-398,86),Vector2(440,53),Color("fff3d1",0.5*(1.0-leave)),1.5,true)
	# Three short streaks only during the wipe; the held pose stays quiet.
	var motion := sin(enter * PI) if leave <= 0.0 else sin(leave * PI)
	for i: int in 3:
		var y := -36.0 + i*42.0
		draw_line(Vector2(-525.0-i*14,y),Vector2(-455.0+i*8,y-3.0),Color(_accent,motion*0.7),2.0,true)
	draw_set_transform(Vector2.ZERO)
