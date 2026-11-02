## 엘리아스 주식 차트 (v1.1) 결과 연출: 최근 주가 선이 그려지고 마지막 등락이 오르면 초록·내리면 빨강으로 이어진다.
## 상한가는 선이 천장을 뚫고 [상한가!] 도장, 상장폐지는 선이 바닥으로 꺾이며 차트가 회색으로 굳고 [상장폐지] 도장.
## 시계 하나(apply_time)로 그린다. 결과(주가·사건)는 엔진이 정한 것을 그대로 보여 줄 뿐이다.
class_name StockChartView
extends Control

const SIZE := Vector2(420, 250)
## 선을 그리는 시간 / 도장이 찍히는 시각 / 끝 (초).
const DRAW_TIME: float = 0.9
const STAMP_AT: float = 1.0
const TOTAL_TIME: float = 1.9
const UP := Color("2f9e44")
const DOWN := Color("e03131")
const GRID := Color(1, 1, 1, 0.12)

var history: Array[int] = []
var event: StringName = &""
var settled: bool = false
var _t: float = 0.0
var _font: Font = null


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func begin(details: Dictionary) -> void:
	history.clear()
	for value: Variant in details.get("history", [ToolStockChart.BASE_PRICE]):
		history.append(int(value))
	if history.size() < 2:
		history.push_front(int(details.get("before", ToolStockChart.BASE_PRICE)))
	event = StringName(details.get("event", &""))
	settled = false
	_t = 0.0
	queue_redraw()


func apply_time(t: float) -> void:
	_t = t
	if t >= STAMP_AT:
		settled = true
	queue_redraw()


static func caption(details: Dictionary, steps: int) -> String:
	match StringName(details.get("event", &"")):
		ToolStockChart.EVENT_LIMIT_UP: return "상한가! %d칸 전진" % steps
		ToolStockChart.EVENT_DELISTED: return "상장폐지! 이동 없이 선두 말 사출"
	var delta: int = int(details.get("delta", 0))
	return "주가 %d (%s%d) · %d칸 전진" % [int(details.get("price", steps)), "+" if delta >= 0 else "", delta, steps]


func _point(index: int, value: int, rect: Rect2) -> Vector2:
	var count: int = maxi(history.size() - 1, 1)
	var x: float = rect.position.x + rect.size.x * float(index) / float(count)
	var y: float = rect.end.y - rect.size.y * clampf(float(value) / float(ToolStockChart.MAX_PRICE + 2), 0.0, 1.0)
	return Vector2(x, y)


func _draw() -> void:
	if _font == null:
		_font = get_theme_default_font()
	var rect := Rect2(Vector2(36, 18), size - Vector2(54, 44))
	var dead: bool = event == ToolStockChart.EVENT_DELISTED and _t >= STAMP_AT
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.08, 0.13, 0.94), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color("ffd43b") if not dead else Color("868e96"), false, 3.0)
	for level: int in [0, 3, 6, 9, 12]:
		var y: float = _point(0, level, rect).y
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), GRID if level != ToolStockChart.BASE_PRICE else Color(1, 1, 1, 0.3), 1.0)
		draw_string(_font, Vector2(6, y + 5), str(level), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.5))
	if history.size() < 2:
		return
	# 이전 구간은 바로 보이고, 마지막 구간이 DRAW_TIME 동안 이어진다
	var last: int = history.size() - 1
	var grow: float = clampf(_t / DRAW_TIME, 0.0, 1.0)
	for index: int in range(1, last):
		var a: Vector2 = _point(index - 1, history[index - 1], rect)
		var b: Vector2 = _point(index, history[index], rect)
		draw_line(a, b, Color(0.8, 0.85, 0.95, 0.55), 3.0, true)
	var from: Vector2 = _point(last - 1, history[last - 1], rect)
	var to: Vector2 = _point(last, history[last], rect)
	if event == ToolStockChart.EVENT_LIMIT_UP:
		to.y = lerpf(to.y, -40.0, clampf((_t - DRAW_TIME * 0.6) / 0.4, 0.0, 1.0))  # 천장을 뚫는다
	var tip: Vector2 = from.lerp(to, grow)
	var rising: bool = history[last] >= history[last - 1] and event != ToolStockChart.EVENT_DELISTED
	var ink: Color = (UP if rising else DOWN) if not dead else Color("868e96")
	draw_line(from, tip, ink, 5.0, true)
	draw_circle(tip, 7.0, ink)
	if _t >= STAMP_AT and event != &"":
		var stamp: String = "상한가!" if event == ToolStockChart.EVENT_LIMIT_UP else "상장폐지"
		var pop: float = clampf((_t - STAMP_AT) / 0.15, 0.0, 1.0)
		var px: int = int(lerpf(64.0, 40.0, pop))
		var color: Color = Color("ffe066") if event == ToolStockChart.EVENT_LIMIT_UP else Color("ff6b6b")
		var width: float = _font.get_string_size(L10n.t(stamp), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var at := Vector2((size.x - width) * 0.5, size.y * 0.5 + px * 0.35)
		draw_string_outline(_font, at, L10n.t(stamp), HORIZONTAL_ALIGNMENT_LEFT, -1, px, 10, Color("15111c"))
		draw_string(_font, at, L10n.t(stamp), HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
