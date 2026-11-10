## 오미쿠지 뽑기통 임시 연출: 통이 흔들리고 막대가 나오며 점괘 종이가 펼쳐진다. 난수·규칙 없음.
class_name OmikujiView
extends Control

const SIZE := Vector2(420, 300)
const SHAKE_TIME := 1.0
const TOTAL_TIME := 2.1
const INK := Color("2b1d14")
const PAPER := Color("fff1d6")
const WOOD := Color("b5651d")
const RED := Color("d6453d")
const GOLD := Color("f2b705")

var settled := false
var _t := 0.0
var _label := "길"
var _key: StringName = &"good"
var _ticket := 1
var _font: Font = ThemeDB.fallback_font


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func begin(details: Dictionary) -> void:
	_key = StringName(details.get("fortune", &"good"))
	_label = str(details.get("label", "길"))
	_ticket = int(details.get("ticket", 1))
	settled = false
	apply_time(0.0)


static func caption(details: Dictionary, steps: int) -> String:
	return ToolOmikuji.caption(details, steps)


func apply_time(t: float) -> void:
	_t = t
	settled = t >= TOTAL_TIME
	queue_redraw()


func _draw() -> void:
	var c := Vector2(SIZE.x * 0.5, SIZE.y * 0.62)
	var shake: float = 0.0
	if _t < SHAKE_TIME:
		shake = sin(_t * 38.0) * 0.16 * (1.0 - _t / SHAKE_TIME * 0.4)
	# 막대: 흔들기 뒤 솟아오른다
	var rise: float = clampf((_t - SHAKE_TIME) / 0.4, 0.0, 1.0)
	draw_set_transform(c, shake, Vector2.ONE)
	if rise > 0.0:
		draw_rect(Rect2(-6, -100 - 70 * rise, 12, 90 + 70 * rise), Color("e9c46a"))
		draw_rect(Rect2(-6, -100 - 70 * rise, 12, 24), RED)
	# 통
	draw_rect(Rect2(-46, -70, 92, 120), WOOD)
	draw_rect(Rect2(-46, -70, 92, 12), WOOD.darkened(0.3))
	draw_rect(Rect2(-46, 38, 92, 12), WOOD.darkened(0.3))
	draw_rect(Rect2(-20, -20, 40, 40), PAPER)
	draw_string(_font, Vector2(-8, 8), "籤", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 점괘 종이
	var open: float = clampf((_t - SHAKE_TIME - 0.5) / 0.5, 0.0, 1.0)
	if open > 0.0:
		var w: float = 150.0 * open
		var r := Rect2(SIZE.x - 20.0 - w, 30.0, w, 190.0)
		draw_rect(r, PAPER)
		draw_rect(r, INK, false, 3.0)
		if open >= 1.0:
			var col: Color = GOLD if _key == &"great" else (RED if _key == &"worst" or _key == &"bad" else INK)
			draw_string(_font, Vector2(r.position.x + 20.0, r.position.y + 90.0), _label, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, col)
			draw_string(_font, Vector2(r.position.x + 20.0, r.position.y + 150.0), "No.%d" % _ticket, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK)
