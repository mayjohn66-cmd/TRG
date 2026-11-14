## LAW_03 only: a fast sweep lays down the caption background before the portrait.
extends Control
const ENTER_AT:=0.0
const READY_AT:=0.62
const LAYER:=10
const FOOTER_ART=preload("res://scenes/victory_footer_art.gd")
var panel_rect:=Rect2()
var ink:=Color("17131d")
var accent:=Color("d33235")
var progress:=0.0
var ratio:=1.0
func _init() -> void:
	name="TrapCaptionSweep";mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=LAYER;set_process(false)
func seek(t: float, before: bool, leave: float, view: Vector2, _bounds: Rect2, dark: Color, color: Color) -> void:
	size=view;ratio=view.y/768.0;ink=dark;accent=color
	panel_rect=Rect2(0,view.y*0.64,view.x,view.y*0.36)
	var u:=clampf(t/READY_AT,0.0,1.0)
	progress=1.0-pow(1.0-u,3.0)
	position=Vector2.ZERO;visible=not before and t>0.0 and leave<1.0
	modulate.a=1.0-leave;queue_redraw()
func body_points() -> PackedVector2Array:
	return FOOTER_ART.body(size)
func _draw() -> void:
	var sweep_x:=size.x*1.12*progress
	var clip:=PackedVector2Array([Vector2.ZERO,Vector2(sweep_x,0),Vector2(sweep_x,size.y),Vector2(0,size.y)])
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(body_points(),clip):draw_colored_polygon(piece,ink)
	var revealed_edge:=PackedVector2Array()
	for point: Vector2 in FOOTER_ART.edge(size):
		if point.x<=sweep_x:revealed_edge.append(point)
	if revealed_edge.size()>1:draw_polyline(revealed_edge,Color(accent,0.70),2.5*ratio,true)
	# The bright leading edge crosses the entire band, leaving the ink behind.
	if progress<1.0:
		var y:=FOOTER_ART.top_y(clampf(sweep_x/maxf(size.x,1),0,1))*size.y
		draw_colored_polygon(PackedVector2Array([Vector2(sweep_x-24*ratio,y),Vector2(sweep_x,y),Vector2(sweep_x-12*ratio,size.y),Vector2(sweep_x-36*ratio,size.y)]),accent)
