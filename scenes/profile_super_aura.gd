## Persistent profile-only aura. Lives outside the card contents and uses no RNG.
extends Control

var colors: Array[Color] = []
var _time := 0.0
var _redraw_time := 0.0
var _rims: Array[StyleBoxFlat] = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# PanelContainer would fit an ordinary child inside its content margins.
	# Follow its outer transform instead, including profile reaction tweens.
	top_level = true
	for layer: int in 3:
		var rim := StyleBoxFlat.new()
		rim.draw_center = false
		rim.set_border_width_all([8,4,2][layer])
		rim.set_corner_radius_all(20+layer)
		_rims.append(rim)

func _ready() -> void:
	_sync_host()

func _sync_host() -> void:
	var host := get_parent() as Control
	if host==null:
		return
	var frame := host.get_global_transform()
	position = frame.origin
	scale = frame.get_scale()
	rotation = frame.get_rotation()
	size = host.size

func _process(delta: float) -> void:
	_sync_host()
	_time += delta
	_redraw_time += delta
	if is_visible_in_tree() and _redraw_time>=1.0/30.0:
		_redraw_time = 0.0
		queue_redraw()

func _palette(u: float) -> Color:
	# Pair each buff's core and edge tones; both buffs can coexist.
	var pairs := maxi(1,colors.size()/2)
	var index := int(floor(u*pairs))%pairs*2
	return colors[index].lerp(colors[mini(index+1,colors.size()-1)],0.5+0.5*sin(u*TAU+_time*0.7))

func _draw() -> void:
	if colors.is_empty() or size.x<1.0 or size.y<1.0:
		return
	var appear := smoothstep(0.0,0.38,_time)
	var breath := 0.5+0.5*sin(_time*2.1)
	var rect := Rect2(Vector2.ZERO,size).grow(2.0)
	for layer: int in 3:
		_rims[layer].border_color = Color(_palette(layer/3.0),appear*[0.09+breath*0.035,0.18,0.57+breath*0.12][layer])
		draw_style_box(_rims[layer],rect.grow((2-layer)*2.0))
	# Short light trails follow the rounded rim instead of flashing the whole card.
	for trail: int in 2:
		var points := PackedVector2Array()
		var u := fposmod(_time*0.075+trail*0.5,1.0)
		for step: int in 11:
			points.append(_perimeter(rect,fposmod(u-step*0.003,1.0)))
		draw_polyline(points,Color(_palette(u).lightened(0.4),0.65*appear),2.0,true)
	# A few curved tongues climb from the upper edge and upper sides. The face,
	# name and pawn counters remain clear; there are no interior particles.
	for index: int in 10:
		var cycle := fposmod(_time*(0.40+index%3*0.035)+index*0.173,1.0)
		var envelope := sin(cycle*PI)
		var x := lerpf(22.0,size.x-22.0,index/9.0)
		var base := Vector2(x,-2.0)
		if index==0 or index==9:
			base = Vector2(-2.0 if index==0 else size.x+2.0,size.y*0.40)
		var height := (11.0+7.0*sin(index*1.9+_time*1.4))*envelope
		var sway := sin(_time*2.8+index*1.7)*4.5
		var alpha := appear*envelope*0.65
		_tongue(base,3.8*envelope,height,sway,Color(_palette(index/10.0),alpha))
		_tongue(base,1.7*envelope,height*0.64,sway*0.65,Color(_palette(index/10.0).lightened(0.55),alpha*0.85))
	# Sparse, small embers lift away and fade before reaching other UI.
	for index: int in 6:
		var u := fposmod(_time*0.34+index*0.167,1.0)
		var at := Vector2(lerpf(18.0,size.x-18.0,index/5.0)+sin(u*4.0+index)*3.0,-5.0-u*18.0)
		draw_circle(at,1.1,Color(_palette(index/6.0).lightened(0.4),sin(u*PI)*0.55*appear))

func _tongue(base: Vector2, width: float, height: float, sway: float, tint: Color) -> void:
	if width<0.1 or height<0.1:
		return
	var points := PackedVector2Array()
	for step: int in 9:
		var u := step/8.0
		var center := base+Vector2(sway*u*u,-height*u)
		points.append(center-Vector2(width*(1-u)*(1+0.5*sin(u*PI)),0))
	for step: int in range(7,-1,-1):
		var u := step/8.0
		var center := base+Vector2(sway*u*u,-height*u)
		points.append(center+Vector2(width*(1-u)*(1+0.5*sin(u*PI)),0))
	draw_colored_polygon(points,tint)

func _perimeter(rect: Rect2, u: float) -> Vector2:
	# Four straight sections and quarter circles, with constant travel speed.
	var radius := minf(20.0,minf(rect.size.x,rect.size.y)*0.25)
	var lengths := [rect.size.x-2*radius,PI*radius/2,rect.size.y-2*radius,PI*radius/2,rect.size.x-2*radius,PI*radius/2,rect.size.y-2*radius,PI*radius/2]
	var d := u*(2*(rect.size.x+rect.size.y-4*radius)+TAU*radius)
	var origin := rect.position
	for part: int in 8:
		var span: float = lengths[part]
		if d<=span:
			match part:
				0: return origin+Vector2(radius+d,0)
				2: return origin+Vector2(rect.size.x,radius+d)
				4: return origin+Vector2(rect.size.x-radius-d,rect.size.y)
				6: return origin+Vector2(0,rect.size.y-radius-d)
				_:
					var centers := [Vector2(rect.size.x-radius,radius),Vector2(rect.size.x-radius,rect.size.y-radius),Vector2(radius,rect.size.y-radius),Vector2(radius,radius)]
					var corner := (part-1)/2
					var angle := -PI/2+corner*PI/2+d/radius
					return origin+centers[corner]+Vector2(cos(angle),sin(angle))*radius
		d -= span
	return origin+Vector2(radius,0)
