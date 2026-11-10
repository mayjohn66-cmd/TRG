## 아이스크림 임시 연출: 한 입 베어 물면 막대에 칸이 드러나거나 "한번 더!"가 나타나 아이스크림이 다시 채워진다. 난수·규칙 없음.
class_name IceCreamView
extends Control

const SIZE := Vector2(420, 300)
const BITE_AT := 0.7
const REFILL_AT := 1.5
const TOTAL_TIME := 2.2
const INK := Color("2b1d14")
const CREAM := Color("ffd9e8")
const CHOCO := Color("7b4a2d")
const STICK := Color("e9c46a")

var settled := false
var _t := 0.0
var _spaces := 1
var _again := false
var _font: Font = ThemeDB.fallback_font


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func begin(details: Dictionary) -> void:
	_spaces = int(details.get("spaces", 1))
	_again = bool(details.get("again", false))
	settled = false
	apply_time(0.0)


static func caption(details: Dictionary, steps: int) -> String:
	return ToolIceCream.caption(details, steps)


func apply_time(t: float) -> void:
	_t = t
	settled = t >= TOTAL_TIME
	queue_redraw()


func _draw() -> void:
	var bitten: bool = _t >= BITE_AT
	var refilled: bool = _again and _t >= REFILL_AT
	var body := Rect2(60, 40, 120, 170)
	if not bitten or refilled:
		draw_rect(body, CREAM)
		draw_rect(Rect2(60, 40, 120, 40), CHOCO)
	else:
		draw_rect(Rect2(60, 140, 120, 70), CREAM)  # 한 입 먹은 뒤
		for i: int in 3:
			draw_circle(Vector2(70 + i * 40, 140), 18.0, Color(0, 0, 0, 0))
	draw_rect(Rect2(110, 210, 20, 80), STICK)
	# 막대 눈금: 베어 문 뒤에 칸이 드러난다
	if bitten and not _again:
		var slots: int = clampi(_spaces, 1, 6)
		for i: int in 6:
			var r := Rect2(230 + (i % 3) * 52, 90 + (i / 3) * 70, 44, 56)
			draw_rect(r, STICK if i < slots else Color(1, 1, 1, 0.12))
			draw_rect(r, INK, false, 2.0)
	elif bitten and _again:
		draw_rect(Rect2(215, 100, 190, 90), STICK)
		draw_rect(Rect2(215, 100, 190, 90), INK, false, 3.0)
		draw_string(_font, Vector2(228, 160), "한번 더!", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color("d6453d"))
