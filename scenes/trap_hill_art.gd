## Hand-inked 2D ridges shared by the trap-card stage and its final printed backdrop.
extends RefCounted
const RIDGE_AT:=0.16
const RIDGE_SECONDS:=0.70

static func ridge_y(layer: int, x: float) -> float:
	match layer:
		0:return 0.59-0.105*exp(-pow((x-0.19)/0.19,2))-0.080*exp(-pow((x-0.80)/0.22,2))+sin(x*8.0)*0.010
		1:return 0.72-0.120*exp(-pow((x-0.65)/0.26,2))-0.064*exp(-pow((x-0.02)/0.29,2))+sin(x*7.0)*0.012
		_:return 0.88-0.135*exp(-pow((x-0.47)/0.35,2))-0.060*exp(-pow((x-0.95)/0.22,2))

static func slope(layer: int, x: float) -> float:
	return (ridge_y(layer,x+0.001)-ridge_y(layer,x-0.001))/0.002

static func reveal(t: float, layer: int) -> float:
	return smoothstep(RIDGE_AT+float(layer)*0.07,RIDGE_AT+float(layer)*0.07+RIDGE_SECONDS,t)

static func _ridge(canvas: CanvasItem, view: Vector2, layer: int, amount: float, fill: Color, ink: Color, detail: float = 1.0) -> void:
	if amount<=0:return
	var points:=PackedVector2Array()
	var complete:=PackedVector2Array()
	var ended:=false
	for i: int in 161:
		var x:=float(i)/160.0
		# A small irregular ink edge avoids a mechanically perfect curve.
		var grain:=(sin(float(i)*1.71)+sin(float(i)*3.21))*view.y*0.00065*detail
		var point:=Vector2(x*view.x,ridge_y(layer,x)*view.y+grain)
		complete.append(point)
		if x<=amount:points.append(point)
		elif not ended:
			points.append(Vector2(amount*view.x,ridge_y(layer,amount)*view.y+grain));ended=true
	var land:=complete.duplicate();land.append(view);land.append(Vector2(0,view.y))
	fill.a*=smoothstep(0.70,1.0,amount)
	if fill.a>0:canvas.draw_colored_polygon(land,fill)
	if points.size()>1:canvas.draw_polyline(points,ink,2.2*view.y/768.0,true)
	# Short contour strokes follow the hill; they are sparse, contained and deterministic.
	for i: int in range(4,155,9):
		var x:=float(i)/160.0
		if x>=amount:break
		var at:=Vector2(x*view.x,ridge_y(layer,x)*view.y+10*view.y/768.0)
		var tangent:=Vector2(1,slope(layer,x)*view.y/view.x).normalized()
		if detail>0.01:canvas.draw_line(at,at+tangent*(16+float(i%4)*4)*view.y/768.0,Color(ink,ink.a*0.28*detail),view.y/768.0,true)

static func native(canvas: CanvasItem, view: Vector2, t: float, detail: float = 1.0) -> void:
	var open:=smoothstep(0.0,0.30,t)
	for i: int in 48:
		var u:=float(i)/47.0
		var color:=Color("262132").lerp(Color("75606c"),u*u)
		color.a=open
		canvas.draw_rect(Rect2(0,view.y*float(i)/48.0,view.x,view.y/48.0+1),color)
	var fills: Array[Color]=[Color("89838f"),Color("b4a9b3"),Color("e2d5d8")]
	for layer: int in 3:
		var amount:=reveal(t,layer)
		var ink:=Color("d4c6d1").lerp(Color("403448"),smoothstep(0.70,1.0,amount))
		_ridge(canvas,view,layer,amount,fills[layer],ink,detail)

static func poster(canvas: CanvasItem, view: Vector2, ink: Color, accent: Color, paper: Color) -> void:
	for layer: int in 3:
		var shade:=paper.lerp(accent,0.09+float(layer)*0.05)
		_ridge(canvas,view,layer,1.0,shade,Color(ink,0.16+float(layer)*0.06))
