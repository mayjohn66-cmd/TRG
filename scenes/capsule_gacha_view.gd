## 캡슐뽑기 연출 (임시 2D 그림): 코인이 투입구로 들어가고 -> 손잡이가 한 바퀴 돌고 -> 캡슐이 굴러 나와 -> 톡 열리며 미니어처가 나타난다.
## 규칙 엔진이 이미 정한 결과를 그릴 뿐이다. 플레이어는 [뽑기!] 버튼 한 번만 누르면 모든 동작이 자동으로 이어진다.
## 최종 그림이 오면 _draw_machine / _draw_capsule만 바꾸면 된다. 미니어처는 그 캐릭터의 승리 일러스트를 작게 세워 보여 준다.
class_name CapsuleGachaView
extends Control

const SIZE := Vector2(420, 300)
const COIN_AT := 0.10
const TURN_AT := 0.80
const TURN_END := 1.60
const DROP_AT := 1.65
const OPEN_AT := 2.30
const REVEAL_AT := 2.75
const TOTAL_TIME := 3.45
const INK := Color("3a3347")
const BODY := Color("f4f1f6")
const BODY_SHADE := Color("d8d2de")
const GLASS := Color(0.78, 0.9, 1.0, 0.45)
const FONT: Font = preload("res://assets/fonts/game_ui_font.tres")
const MACHINE_AT := Vector2(22, 14)
const PRIZE_X := 304.0

var settled := false
var _t := 0.0
var _name := ""
var _steps := 3
var _rarity: StringName = &"common"
var _rarity_name := ""
var _secret := false
var _color := Color("ffd43b")
var _art: Texture2D = null


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func begin(details: Dictionary, _kept: int = 0) -> void:
	_name = str(details.get("name", ""))
	_steps = int(details.get("steps", 3))
	_rarity = StringName(details.get("rarity", &"common"))
	_rarity_name = str(details.get("rarity_name", ""))
	_secret = bool(details.get("secret", false))
	_color = Color(str(details.get("color", "ffd43b")))
	_art = AvatarCombatArt.texture(StringName(details.get("avatar", &"avatar_01")), &"victory")
	apply_time(0.0)


static func caption(details: Dictionary, steps: int) -> String:
	return ToolCapsuleGacha.caption(details, steps)


func apply_time(t: float) -> void:
	_t = t
	settled = t >= REVEAL_AT
	queue_redraw()


func _draw() -> void:
	_draw_machine()
	_draw_coin()
	_draw_capsule()
	if _t >= OPEN_AT:
		_draw_prize()


func _draw_machine() -> void:
	var at := MACHINE_AT
	draw_rect(Rect2(at + Vector2(-4, 232), Vector2(168, 12)), Color(0.15, 0.1, 0.2, 0.2))  # 바닥 그림자
	# 아래 몸통
	draw_rect(Rect2(at + Vector2(6, 128), Vector2(148, 106)), BODY)
	draw_rect(Rect2(at + Vector2(6, 128), Vector2(148, 106)), INK, false, 3.0)
	draw_rect(Rect2(at + Vector2(6, 214), Vector2(148, 20)), BODY_SHADE)
	# 유리 돔 (안에 알록달록한 캡슐들)
	draw_circle(at + Vector2(80, 70), 66.0, GLASS)
	var shake := sin(clampf(inverse_lerp(TURN_AT, TURN_END, _t), 0.0, 1.0) * TAU * 3.0) * 2.0 if _t > TURN_AT and _t < TURN_END else 0.0
	var palette := [Color("ff8787"), Color("ffd43b"), Color("74c0fc"), Color("8ce99a"), Color("e599f7"), Color("ffa94d"), Color("a9e34b")]
	for i: int in 14:
		var angle := float(i) * 2.4
		var radius := 12.0 + float(i % 4) * 11.0
		var p := at + Vector2(80, 82) + Vector2(cos(angle) * radius * 1.3 + shake, sin(angle) * radius * 0.55)
		draw_circle(p, 9.0, palette[i % palette.size()])
		draw_arc(p, 9.0, 0.0, TAU, 14, INK, 1.5, true)
		draw_line(p + Vector2(-8, 0), p + Vector2(8, 0), Color(1, 1, 1, 0.55), 1.5, true)
	draw_arc(at + Vector2(80, 70), 66.0, 0.0, TAU, 40, INK, 3.0, true)
	draw_rect(Rect2(at + Vector2(20, 128), Vector2(120, 8)), BODY_SHADE)
	# 코인 투입구 + 손잡이 + 배출구
	draw_rect(Rect2(at + Vector2(24, 148), Vector2(34, 44)), Color("c9c3d1"))
	draw_rect(Rect2(at + Vector2(24, 148), Vector2(34, 44)), INK, false, 2.0)
	draw_rect(Rect2(at + Vector2(37, 156), Vector2(8, 22)), INK)  # 투입구
	var knob_center := at + Vector2(98, 170)
	var turn := ease(clampf(inverse_lerp(TURN_AT, TURN_END, _t), 0.0, 1.0), 0.4) * TAU * 1.0
	draw_circle(knob_center, 22.0, Color("ff8787"))
	draw_arc(knob_center, 22.0, 0.0, TAU, 24, INK, 3.0, true)
	for k: int in 2:
		var dir := Vector2.from_angle(turn + float(k) * PI)
		draw_line(knob_center - dir * 14.0, knob_center + dir * 14.0, Color("fff5f5"), 6.0, true)
	draw_circle(knob_center, 5.0, INK)
	draw_rect(Rect2(at + Vector2(68, 206), Vector2(52, 24)), Color("2b2433"))  # 배출구
	draw_rect(Rect2(at + Vector2(68, 206), Vector2(52, 24)), INK, false, 2.0)
	_text("1,000", at + Vector2(41, 140), 10, INK, 36.0)
	# 위쪽 뚜껑
	draw_rect(Rect2(at + Vector2(14, 4), Vector2(132, 14)), BODY)
	draw_rect(Rect2(at + Vector2(14, 4), Vector2(132, 14)), INK, false, 2.0)


func _draw_coin() -> void:
	if _t < COIN_AT or _t > TURN_AT:
		return
	var k := clampf((_t - COIN_AT) / (TURN_AT - COIN_AT - 0.1), 0.0, 1.0)
	var slot := MACHINE_AT + Vector2(41, 166)
	var from := slot + Vector2(-118, -52)
	var at := from.lerp(slot, ease(k, 0.5)) + Vector2(0, -sin(k * PI) * 34.0)
	var squash := absf(cos(k * TAU * 2.0))
	draw_set_transform(at, 0.0, Vector2(maxf(squash, 0.18), 1.0))
	draw_circle(Vector2.ZERO, 11.0, Color("ffd43b"))
	draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 20, INK, 2.0, true)
	draw_set_transform(Vector2.ZERO)


## 캡슐: 배출구에서 튀어나와 바닥으로 굴러가 톡 열린다.
func _draw_capsule() -> void:
	if _t < DROP_AT:
		return
	var drop := clampf((_t - DROP_AT) / 0.40, 0.0, 1.0)
	var roll := clampf((_t - DROP_AT - 0.2) / 0.5, 0.0, 1.0)
	var start := MACHINE_AT + Vector2(94, 222)
	var rest := Vector2(PRIZE_X, 238)
	var at := start.lerp(rest, ease(roll, 0.4)) + Vector2(0, -absf(sin(drop * PI * 1.5)) * 22.0 * (1.0 - roll))
	var open := clampf((_t - OPEN_AT) / 0.30, 0.0, 1.0)
	var spin := ease(roll, 0.4) * TAU
	var radius := 24.0
	if open <= 0.0:
		draw_set_transform(at - Vector2(0, radius), spin, Vector2.ONE)
		_draw_capsule_half(1.0)
		_draw_capsule_half(-1.0)
		draw_set_transform(Vector2.ZERO)
	else:
		var gap := open * 26.0
		draw_set_transform(at - Vector2(0, radius + gap), -0.12 * open, Vector2.ONE)
		_draw_capsule_half(1.0)
		draw_set_transform(at - Vector2(0, radius) + Vector2(0, 0), 0.0, Vector2.ONE)
		_draw_capsule_half(-1.0)
		draw_set_transform(Vector2.ZERO)
		if open < 1.0:
			var light := Color(1, 1, 1, 1.0 - open)
			for i: int in 8:
				var dir := Vector2.from_angle(i * TAU / 8.0)
				draw_line(at + Vector2(0, -radius) + dir * 30.0, at + Vector2(0, -radius) + dir * (40.0 + 14.0 * open), light, 3.0, true)


## 캡슐 반쪽 (+1 위 / -1 아래).
func _draw_capsule_half(side: float) -> void:
	var radius := 24.0
	var points := PackedVector2Array()
	for i: int in 17:
		var a := PI * float(i) / 16.0
		points.append(Vector2(cos(a) * radius, -sin(a) * radius * side))
	var tint := _color if side > 0.0 else Color("f8f9fa")
	draw_colored_polygon(points, tint)
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	draw_polyline(closed, INK, 2.5, true)
	if side > 0.0:
		draw_arc(Vector2(-6, -6), 14.0, PI * 1.05, PI * 1.5, 10, Color(1, 1, 1, 0.6), 3.0, true)


## 캡슐 안에서 나온 미니어처: 작은 받침 위에 캐릭터를 세우고 이름·등급·칸수를 보여 준다.
func _draw_prize() -> void:
	var k := ease(clampf((_t - OPEN_AT) / 0.45, 0.0, 1.0), 0.35)
	var base := Vector2(PRIZE_X, 238)
	var stand := base + Vector2(0, -2)
	draw_set_transform(stand, 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 40.0, Color(0.2, 0.15, 0.3, 0.3))
	draw_set_transform(Vector2.ZERO)
	draw_set_transform(base + Vector2(0, -4), 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, 38.0, _color.darkened(0.15))
	draw_arc(Vector2.ZERO, 38.0, 0.0, TAU, 28, INK, 3.0, true)
	draw_set_transform(Vector2.ZERO)
	if _art != null:
		var height := 112.0 * k
		var width := height * float(_art.get_width()) / float(_art.get_height())
		draw_texture_rect(_art, Rect2(base + Vector2(-width * 0.5, -height - 6.0), Vector2(width, height)), false)
	if _t >= REVEAL_AT:
		var glow := clampf((_t - REVEAL_AT) / 0.35, 0.0, 1.0)
		var tag_color := _color.darkened(0.25) if _rarity != &"secret" else Color("d9480f")
		_text(L10n.t(_name) + " " + L10n.t("미니어처"), Vector2(PRIZE_X, 26), 15, Color(INK, glow), 190.0)
		_text(L10n.t(_rarity_name), Vector2(PRIZE_X, 50), 14, Color(tag_color, glow), 100.0)
		_text(L10n.t("%d칸 전진!") % _steps, Vector2(PRIZE_X, 84), 28 if not _secret else 32, Color(Color("c2342f") if not _secret else Color("d9480f"), glow), 190.0)
		if _secret:
			var sparks := 8
			var light := Color("ffd46b")
			light.a = (1.0 - glow) * 0.9
			for i: int in sparks:
				var dir := Vector2.from_angle(i * TAU / sparks)
				draw_line(base + Vector2(0, -60) + dir * (50.0 + 20.0 * glow), base + Vector2(0, -60) + dir * (60.0 + 24.0 * glow), light, 3.0, true)


func _text(value: String, at: Vector2, px: int, color: Color, max_width: float = INF) -> void:
	var width := FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	if width > max_width:
		px = maxi(1, floori(px * max_width / width))
		width = FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var baseline := (FONT.get_ascent(px) - FONT.get_descent(px)) * 0.5
	draw_string(FONT, at + Vector2(-width * 0.5, baseline), value, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
