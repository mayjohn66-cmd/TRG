## 스크래치 복권 연출 (임시 2D 그림): 위에 당첨 문양이 적힌 복권, 은박 칸 3개를 동전이 차례로 긁어 문양을 드러낸다.
## 당첨 문양과 같은 칸은 초록 테두리로, 황금 문양은 금색 바탕으로 빛난다. 문양은 포커 카드와 같은 ♠♥◆♣.
class_name ScratchTicketView
extends Control

const SIZE := Vector2(420, 300)
const SCRATCH_START := 0.30
const SCRATCH_EACH := 0.52
const REVEAL_AT := SCRATCH_START + SCRATCH_EACH * 3.0
const TOTAL_TIME := REVEAL_AT + 0.75
const FONT: Font = preload("res://assets/fonts/game_ui_font.tres")
const TICKET := Rect2(40, 30, 340, 240)
const PAPER := Color("fffaec")
const INK := Color("3c4678")
const FOIL := Color("bec3cd")
const GOLD := Color("ffd24a")
const MATCH := Color("2fb35a")
const SUIT_COLORS: Array[Color] = [Color("26262e"), Color("dc3246"), Color("dc3246"), Color("26262e")]

var settled := false
var _winning := 0
var _cells: Array = [0, 1, 2]
var _gold: Array = [false, false, false]
var _time := 0.0


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func begin(details: Dictionary) -> void:
	_winning = int(details.get("winning", 0))
	_cells = (details.get("cells", [0, 1, 2]) as Array).duplicate()
	_gold = (details.get("gold", [false, false, false]) as Array).duplicate()
	apply_time(0.0)


static func caption(details: Dictionary, steps: int) -> String:
	return ToolScratchLottery.caption(details, steps)


func apply_time(t: float) -> void:
	_time = t
	settled = t >= REVEAL_AT
	queue_redraw()


func _cell_rect(index: int) -> Rect2:
	var width := 92.0
	var gap := (TICKET.size.x - width * 3.0) / 4.0
	return Rect2(TICKET.position + Vector2(gap + index * (width + gap), 92.0), Vector2(width, 118.0))


## 칸 하나가 긁힌 정도 (0~1).
func _scratched(index: int) -> float:
	return clampf((_time - SCRATCH_START - index * SCRATCH_EACH) / (SCRATCH_EACH * 0.85), 0.0, 1.0)


func _draw() -> void:
	draw_style_box(_box(PAPER, INK, 6, 20), TICKET)
	var header := Rect2(TICKET.position + Vector2(18, 14), Vector2(TICKET.size.x - 36, 58))
	draw_style_box(_box(Color("ffd65a"), Color("d89a1e"), 3, 14), header)
	_text(L10n.t("당첨 문양"), header.position + Vector2(header.size.x * 0.36, header.size.y * 0.5), 22, Color("784010"))
	_text(ToolScratchLottery.SUITS[_winning], header.position + Vector2(header.size.x * 0.78, header.size.y * 0.5), 40, SUIT_COLORS[_winning])
	var coin := Vector2(-100, -100)
	for index: int in 3:
		var cell := _cell_rect(index)
		var shown := _scratched(index)
		var suit: int = int(_cells[index])
		var golden: bool = index < _gold.size() and bool(_gold[index])
		var matched: bool = suit == _winning
		draw_style_box(_box(GOLD if golden else Color.WHITE, Color("b4b4c8"), 3, 12), cell)
		_text(ToolScratchLottery.SUITS[suit], cell.get_center(), 62, Color("a8740e") if golden else SUIT_COLORS[suit])
		if golden:
			_text("★", cell.position + Vector2(cell.size.x - 16, 16), 18, Color("fff6c8"))
		# 은박: 위에서부터 긁혀 나간다
		if shown < 1.0:
			var cover := Rect2(cell.position + Vector2(0, cell.size.y * shown), Vector2(cell.size.x, cell.size.y * (1.0 - shown)))
			draw_style_box(_box(FOIL, Color("9196a5"), 3, 12), cover)
			for line: int in 5:
				var y := cover.position.y + 12.0 + line * 20.0
				if y < cover.end.y - 6.0:
					draw_line(Vector2(cover.position.x + 8, y + 6), Vector2(cover.end.x - 8, y), Color("d7dce4"), 4.0)
			if shown > 0.0:
				coin = Vector2(cell.position.x + cell.size.x * (0.5 + 0.35 * sin(_time * 26.0)), cover.position.y)
		if settled and matched:
			var glow := smoothstep(REVEAL_AT, REVEAL_AT + 0.2, _time)
			draw_style_box(_box(Color(0, 0, 0, 0), Color(MATCH, glow), 6, 14), cell.grow(5))
	if coin.x > 0.0:
		draw_circle(coin, 20.0, Color("ffc83c"))
		draw_arc(coin, 20.0, 0, TAU, 28, Color("aa6e14"), 4.0)
		draw_arc(coin, 12.0, 0, TAU, 20, Color("dc9620"), 3.0)


func _box(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	return box


func _text(value: String, center: Vector2, px: int, color: Color) -> void:
	var width := FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var at := center + Vector2(-width * 0.5, (FONT.get_ascent(px) - FONT.get_descent(px)) * 0.5)
	draw_string(FONT, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
