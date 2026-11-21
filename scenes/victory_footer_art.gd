## One full-width caption outline shared by the posters and the trap-card sweep.
extends RefCounted
static func top_y(x: float) -> float:
	return lerpf(0.69,0.64,x/0.59) if x<=0.59 else lerpf(0.64,0.80,(x-0.59)/0.41)
static func edge(view: Vector2, drop: float = 0.0) -> PackedVector2Array:
	var points:=PackedVector2Array()
	for i: int in 49:
		var x:=float(i)/48
		points.append(Vector2(x*view.x,(top_y(x)+drop)*view.y)+(Vector2(0,sin(float(i)*3.7)*0.9+cos(float(i)*1.3)*0.55)*view.y/768.0))
	return points
static func body(view: Vector2, drop: float = 0.0) -> PackedVector2Array:
	var points:=edge(view,drop)
	points.append(Vector2(view.x,view.y*1.40));points.append(Vector2(0,view.y*1.40))
	return points
