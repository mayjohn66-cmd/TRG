## Comic trading board. One presenter clock, no RNG or rule changes.
class_name StockChartView
extends Control

const SIZE := Vector2(520,300)
const LIVE_AT := 0.85
const DRAW_TIME := 1.65
const STAMP_AT := 1.80
const TOTAL_TIME := 2.85
const ANNOUNCEMENT_BODY := "오늘의 주식은"
const ANNOUNCEMENT := ANNOUNCEMENT_BODY + "..."
const DOT_INTERVAL := 0.20
const UP := Color("48d6a8")
const DOWN := Color("ff6276")
const GOLD := Color("ffdb62")
const INK := Color("151e2c")
const PAPER := Color("fff4d9")
const GRID := Color(0.80,0.89,0.92,0.13)
const DISPLAY_FONT: Font = preload("res://assets/fonts/result/bangers.ttf")
const EVENT_FONT: Font = preload("res://assets/fonts/ONE-Mobile-POP.otf")

var history: Array[int] = []
var event: StringName = &""
var settled := false
var _t := 0.0
var _font: Font
var _before := ToolStockChart.BASE_PRICE
var _price := ToolStockChart.BASE_PRICE
var _delta := 0

func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

func begin(details: Dictionary) -> void:
	history.clear()
	for value: Variant in details.get("history",[ToolStockChart.BASE_PRICE]): history.append(int(value))
	# Legacy snapshots can contain seven points. Read only the latest four.
	while history.size()>ToolStockChart.HISTORY_SIZE: history.pop_front()
	_before = int(details.get("before",history[-2] if history.size()>1 else ToolStockChart.BASE_PRICE))
	_price = int(details.get("price",history[-1] if not history.is_empty() else _before))
	_delta = int(details.get("delta",_price-_before))
	if history.is_empty(): history.append(_before)
	if history.size()<2: history.push_front(_before)
	event = StringName(details.get("event",&""))
	settled = false
	_t = 0.0
	queue_redraw()

func apply_time(t: float) -> void:
	_t = maxf(t,0.0)
	settled = _t >= STAMP_AT
	queue_redraw()

static func caption(details: Dictionary, steps: int) -> String:
	match StringName(details.get("event",&"")):
		ToolStockChart.EVENT_LIMIT_UP: return "대폭등! (Bull Market) · %d칸 전진" % steps
		ToolStockChart.EVENT_DELISTED: return "대폭락! (Bear Market)\n이동 없이 선두 말 사출"
	var delta := int(details.get("delta",0))
	return "주가 %d (%s%d) · %d칸 전진" % [int(details.get("price",steps)),"+" if delta>=0 else "",delta,steps]

func progress() -> float:
	var p := clampf((_t-LIVE_AT)/(DRAW_TIME-LIVE_AT),0.0,1.0)
	return p*p*(3.0-2.0*p)

func displayed_price() -> int:
	return _price if settled else roundi(lerpf(float(_before),float(_price),progress()))

func announcement_text() -> String:
	if _t>=LIVE_AT: return ""
	var dots := int(floor(_t/DOT_INTERVAL))%3+1
	return ANNOUNCEMENT_BODY + ".".repeat(dots)

func historical_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	for index: int in range(history.size()-1): points.append(_point(index,float(history[index]),_plot()))
	return points

func _plot() -> Rect2:
	return Rect2(Vector2(44,98),size-Vector2(66,132))

func _point(index: int,value: float,rect: Rect2) -> Vector2:
	var count := maxi(history.size()-1,1)
	return Vector2(rect.position.x+rect.size.x*float(index)/count,rect.end.y-rect.size.y*clampf(value/14.0,0.0,1.0))

func tip_position() -> Vector2:
	var last := history.size()-1
	if last<1: return _plot().get_center()
	var rect := _plot()
	var from := _point(last-1,float(_before),rect)
	var to := _point(last,float(_price),rect)
	var p := progress()
	var tip := from.lerp(to,p)
	if event==ToolStockChart.EVENT_LIMIT_UP:
		tip.y = lerpf(tip.y,rect.position.y-15.0,smoothstep(0.76,1.0,p))
	return tip

func _tone() -> Color:
	if event==ToolStockChart.EVENT_LIMIT_UP: return GOLD
	if event==ToolStockChart.EVENT_DELISTED: return DOWN
	return UP if _price>_before else (DOWN if _price<_before else GOLD)

func _text(text: String,at: Vector2,px: int,color: Color,font: Font=null,outline: int=0) -> void:
	var face: Font = font if font!=null else _font
	if outline>0: draw_string_outline(face,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,px,outline,INK)
	draw_string(face,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,px,color)

func _draw() -> void:
	_font = get_theme_default_font()
	var intro := 1.0-pow(1.0-clampf(_t/0.18,0.0,1.0),3.0)
	var zoom := lerpf(0.94,1.0,intro)
	var age := maxf(_t-STAMP_AT,0.0)
	draw_set_transform(size*0.5*(1.0-zoom)+Vector2(0.0,10.0*(1.0-intro)),0.0,Vector2.ONE*zoom)
	var shape := PackedVector2Array([Vector2(0,12),Vector2(16,0),Vector2(size.x-10,0),Vector2(size.x,12),Vector2(size.x,size.y-12),Vector2(size.x-16,size.y),Vector2(10,size.y),Vector2(0,size.y-12)])
	var shadow := PackedVector2Array()
	for point: Vector2 in shape: shadow.append(point+Vector2(7,9))
	draw_colored_polygon(shadow,INK)
	draw_colored_polygon(shape,PAPER)
	var edge := shape.duplicate()
	edge.append(edge[0])
	draw_polyline(edge,INK,5.0,true)
	var face := Rect2(Vector2(9,9),size-Vector2(18,18))
	draw_rect(face,Color("213242") if not (settled and event==ToolStockChart.EVENT_DELISTED) else Color("303641"))
	for x: int in range(20,int(size.x)-15,10):
		for y: int in range(18,78,10): draw_circle(Vector2(x,y),0.8,Color(1,1,1,0.07))
	_text("ELIAS MARKET",Vector2(23,40),29,PAPER,DISPLAY_FONT)
	_text("NEXT TICK" if _t<LIVE_AT else ("LIVE TICKER" if not settled else "TRADE CONFIRMED"),Vector2(24,65),14,GOLD,DISPLAY_FONT)
	var quote := "%02d" % displayed_price()
	var quote_width := DISPLAY_FONT.get_string_size(quote,HORIZONTAL_ALIGNMENT_LEFT,-1,57).x
	_text(quote,Vector2(size.x-25-quote_width,64),57,PAPER if _t<LIVE_AT else _tone(),DISPLAY_FONT,3)
	draw_line(Vector2(21,79),Vector2(size.x-21,79),PAPER,2.0)
	var rect := _plot()
	for level: int in [0,3,6,9,12]:
		var y := _point(0,float(level),rect).y
		draw_line(Vector2(rect.position.x,y),Vector2(rect.end.x,y),GRID if level!=ToolStockChart.BASE_PRICE else Color(1,1,1,0.28),1.0)
		_text(str(level),Vector2(18,y+4),12,Color(0.87,0.93,0.93,0.6))
	for col: int in range(ToolStockChart.HISTORY_SIZE):
		var x := rect.position.x+rect.size.x*col/float(ToolStockChart.HISTORY_SIZE-1)
		draw_line(Vector2(x,rect.position.y),Vector2(x,rect.end.y),GRID,1.0)
	if history.size()<2: return
	var last := history.size()-1
	var previous := historical_points()
	# Completed records are present immediately, never traced again per roll.
	for i: int in range(1,previous.size()):
		draw_line(previous[i-1],previous[i],INK,7.0,true)
		draw_line(previous[i-1],previous[i],Color("a9bbca"),3.0,true)
	for point: Vector2 in previous: draw_circle(point,3.0,PAPER)
	var from := _point(last-1,float(_before),rect)
	var tip := tip_position()
	var tone := _tone()
	var area := PackedVector2Array([from,tip,Vector2(tip.x,rect.end.y),Vector2(from.x,rect.end.y)])
	if tip.x>from.x+1.0: draw_colored_polygon(area,Color(tone,0.10))
	if _t>=LIVE_AT:
		draw_line(from,tip,INK,10.0,true)
		draw_line(from,tip,tone,5.0,true)
		for dash: int in range(0,12):
			var x := rect.position.x+dash*rect.size.x/12.0
			draw_line(Vector2(x,tip.y),Vector2(x+8,tip.y),Color(tone,0.34),1.0)
		draw_circle(tip,9.0,INK)
		draw_circle(tip,6.5,PAPER)
		draw_circle(tip,3.7,tone)
	if settled:
		var delta_text := "%+d" % _delta if _delta!=0 else "0"
		_text("CLOSE  " + delta_text,Vector2(23,size.y-16),17,tone,DISPLAY_FONT)
	else:
		_text("WAITING..." if _t<LIVE_AT else "TRADING...",Vector2(23,size.y-16),17,PAPER,DISPLAY_FONT)
	_text("EL / 01",Vector2(size.x-75,size.y-16),15,Color(1,1,1,0.5),DISPLAY_FONT)
	var announcement := announcement_text()
	if not announcement.is_empty():
		# Reserve all three dots so the sentence never shifts as dots cycle.
		var width := EVENT_FONT.get_string_size(ANNOUNCEMENT,HORIZONTAL_ALIGNMENT_LEFT,-1,29).x
		_text(announcement,Vector2((size.x-width)*0.5,size.y*0.57),29,PAPER,EVENT_FONT,10)
	if settled and event!=&"": _event_stamp(age,tone)
	draw_set_transform(Vector2.ZERO)

func _event_stamp(age: float,tone: Color) -> void:
	var rising := event==ToolStockChart.EVENT_LIMIT_UP
	var title := "대폭등!" if rising else "대폭락!"
	var subtitle := "(Bull Market)" if rising else "(Bear Market)"
	var land := clampf(age/0.13,0.0,1.0)
	var relax := clampf((age-0.13)/0.15,0.0,1.0)
	var scale_factor := lerpf(1.65,0.92,land*land) if age<0.13 else lerpf(0.92,1.0,1.0-pow(1.0-relax,2.0))
	for line: int in 2:
		var text := title if line==0 else subtitle
		var font := EVENT_FONT if line==0 else DISPLAY_FONT
		var px := int((40.0 if line==0 else 29.0)*scale_factor)
		var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x
		var at := Vector2((size.x-width)*0.5,size.y*0.53+(0.0 if line==0 else 38.0))
		_text(text,at+Vector2(4,5),px,INK,font,12)
		draw_string_outline(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,px,12,PAPER)
		draw_string_outline(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,px,7,INK)
		draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,px,tone)
	if age<0.36:
		var center := Vector2(size.x*0.5,98.0 if event==ToolStockChart.EVENT_LIMIT_UP else size.y-33)
		for i: int in 8:
			var angle := -PI+float(i)*PI/7.0
			var v := Vector2(cos(angle),sin(angle))
			var dot := center+v*(24.0+age*170.0)
			draw_circle(dot,3.0*(1.0-age/0.36),PAPER)
