## A seekable board-space intro for the Belatien shop victory.
extends Control

const CARROT: Texture2D = preload("res://assets/fx/law_fx/victory_prints/bad_carrot_prop.png")
const WITCH: Texture2D = preload("res://assets/fx/law_fx/victory_prints/bad_carrot_witch.png")
const COUNT := 6
const DROP_TIME := 0.30
const FLIGHT_AT := 1.39
const IMPACT_AT := 1.97
const INTRO_SECONDS := 2.48
## 이 무대가 도는 동안 배경을 어둡게 하는 정도 (LawVictoryPrelude가 읽는다).
const DIM_TARGET := 0.58
const DIM_RAMP_END := 0.95  ## 어두워지기를 마치는 시각
const FADE_SECONDS := 0.38
const SETTLE_AT := 3.02
const STACK: Array[Vector2] = [
	Vector2(-89, 11), Vector2(17, 20), Vector2(95, 7),
	Vector2(-47, -27), Vector2(55, -29), Vector2(5, -67),
]
const TILTS: Array[float] = [0.27, -0.26, 0.16, 0.54, -0.12, 0.27]
const SPRAY: Array[Vector2] = [
	Vector2(-260, -175), Vector2(144, -285), Vector2(605, -130),
	Vector2(-110, -355), Vector2(451, -350), Vector2(300, -412),
]
var _focus: Vector2
var _source_view: Vector2
var _time := 0.0
var _witch: TextureRect
var _flight_center: Vector2


func setup(focus: Vector2, source_view: Vector2) -> void:
	name = "BadCarrotStage"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus = focus
	_source_view = source_view
	var crop := AtlasTexture.new()
	crop.atlas = WITCH
	crop.region = PaintedFx.region(WITCH)
	_witch = TextureRect.new()
	_witch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_witch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_witch.stretch_mode = TextureRect.STRETCH_SCALE
	_witch.texture = crop
	var print_material := ShaderMaterial.new()
	print_material.shader = preload("res://scenes/bad_carrot_silhouette.gdshader")
	_witch.material = print_material
	_witch.hide()
	add_child(_witch)


static func drop_at(index: int) -> float:
	return 0.39 + 0.225 * index


func seek(time: float, view: Vector2) -> void:
	if _time == time and size == view:
		return
	_time = time
	size = view
	var ratio := minf(size.x / 1366.0, size.y / 768.0)
	_pose_flight(_pile_center(ratio), ratio)
	queue_redraw()


func _pile_center(ratio: float) -> Vector2:
	return _focus * size / _source_view + Vector2(0.0, 58.0) * ratio


func _draw() -> void:
	var ratio := minf(size.x / 1366.0, size.y / 768.0)
	var pile := _pile_center(ratio)
	var handoff := smoothstep(INTRO_SECONDS, INTRO_SECONDS + FADE_SECONDS, _time)
	var impact_time := maxf(_time - IMPACT_AT, 0.0)
	var contact := smoothstep(0.14, 0.38, _time) * (1.0 - smoothstep(0.0, 0.34, impact_time))
	PaintedFx.stamp(self, PaintedFx.DUST, pile + Vector2(0.0, 37.0) * ratio,
		Vector2(365.0, 48.0) * ratio, Color(0.15, 0.06, 0.28, contact * 0.72))
	for index: int in COUNT:
		var land := drop_at(index)
		var fall := clampf(inverse_lerp(land - DROP_TIME, land, _time), 0.0, 1.0)
		if fall <= 0.0:
			continue
		var air := 1.0 - fall * fall
		var bounce := sin(smoothstep(land, land + 0.16, _time) * PI) * 9.0
		var launch := maxf(impact_time - index * 0.012, 0.0)
		var hue := 0.91 + float(index % 3) * 0.045
		var opacity := smoothstep(0.0, 0.17, fall) * (1.0 - smoothstep(0.45, 0.90, launch)) * (1.0 - handoff)
		var at := STACK[index] + Vector2(air * (42.0 if index % 2 == 0 else -38.0), -286.0 * air - bounce)
		at += SPRAY[index] * launch + Vector2(0.0, 420.0 * launch * launch)
		var angle := TILTS[index] - air * 0.48 + launch * (7.0 if index % 2 == 0 else -8.0)
		PaintedFx.stamp(self, CARROT, pile + at * ratio, Vector2(150.0, 100.0) * ratio,
			Color(hue, hue, hue, opacity), angle)
	if _time >= IMPACT_AT:
		var flash := 1.0 - smoothstep(0.0, 0.25, impact_time)
		PaintedFx.stamp(self, PaintedFx.IMPACT, pile - Vector2(6.0, 18.0) * ratio,
			Vector2(250.0, 128.0) * ratio, Color(1.0, 0.71, 0.25, flash), -0.31)
	if _witch.visible:
		var trail := 1.0 - smoothstep(INTRO_SECONDS - 0.10, SETTLE_AT, _time)
		PaintedFx.stamp(self, PaintedFx.WAKE, _flight_center + Vector2(-211.0, 115.0) * ratio,
			Vector2(480.0, 36.0) * ratio, Color(0.73, 0.47, 1.0, trail * 0.66), -0.25)


func _pose_flight(pile: Vector2, ratio: float) -> void:
	_witch.visible = _time >= FLIGHT_AT
	if not _witch.visible:
		return
	var approach := Vector2(size.x * -0.21, pile.y + 89.0 * ratio)
	var strike := pile + Vector2(-225.0, -51.0) * ratio
	var at := approach.lerp(strike, clampf(inverse_lerp(FLIGHT_AT, IMPACT_AT, _time), 0.0, 1.0))
	var growth := 0.0
	if _time >= IMPACT_AT:
		var progress := clampf(inverse_lerp(IMPACT_AT, SETTLE_AT, _time), 0.0, 1.0)
		growth = 1.0 - pow(1.0 - progress, 2.5)
		at = strike.lerp(size * Vector2(0.385, 0.46), growth)
		# Carry the flyby upward while making room for the winner on the right.
		at.y -= sin(progress * PI) * 64.0 * ratio
	_flight_center = at
	_witch.size = Vector2(545.0, 371.0).lerp(Vector2(680.0, 463.0), growth) * ratio
	_witch.position = at - _witch.size * 0.5
	(_witch.material as ShaderMaterial).set_shader_parameter("print_scale", ratio)
