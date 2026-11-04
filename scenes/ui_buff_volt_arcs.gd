## Short bent discharge paths ride the existing UI rim. No full-rim flashing.
extends Control
var effect_time:=0.0
var radius:=14.0
var _was_active:=false

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func advance(clock:float,enabled:bool) -> void:
	effect_time=clock
	visible=enabled
	var active:=enabled and fposmod(effect_time,2.35)<0.56
	if active or _was_active:queue_redraw()
	_was_active=active

func discharge_visible() -> bool:
	return visible and fposmod(effect_time,2.35)<0.56

func _draw() -> void:
	var age:=fposmod(effect_time,2.35)
	if age>=0.56 or size.x<1.0 or size.y<1.0:return
	var alpha:=smoothstep(0.0,0.05,age)*(1.0-smoothstep(0.42,0.56,age))
	var cycle:=floori(effect_time/2.35)
	var shape:=floori(age*14.0)
	var r:=minf(radius,minf(size.x,size.y)*0.5)
	var total:=2.0*(size.x+size.y-4.0*r)+TAU*r
	var corner:float=(size.x-2.0*r+PI*r*0.25)/total
	var canvas_frame:=get_global_transform_with_canvas()
	var to_local:=canvas_frame.affine_inverse()
	var safe:=get_viewport_rect().grow(-3.0)
	for arc:int in 2:
		var center:float=fposmod(corner+arc*0.5+float(cycle%2)*0.17,1.0)
		var span:float=minf(128.0,total*0.22)
		var points:=PackedVector2Array()
		for j:int in 13:
			var q:float=float(j)/12.0
			var u:float=fposmod(center+(q-0.5)*span/total,1.0)
			var base:=_perimeter(u,r)
			var before:=_perimeter(fposmod(u-0.0005,1.0),r)
			var after:=_perimeter(fposmod(u+0.0005,1.0),r)
			var normal:Vector2=(after-before).normalized().orthogonal()
			var zig:float=0.0
			if j>0 and j<12:
				zig=sin(float(j*19+arc*37+shape*13+cycle*7))*6.0
				if j%3==1:zig*=1.5
			var screen:Vector2=canvas_frame*(base+normal*zig)
			screen.x=clampf(screen.x,safe.position.x,safe.end.x)
			screen.y=clampf(screen.y,safe.position.y,safe.end.y)
			points.append(to_local*screen)
		draw_polyline(points,Color(0.03,0.35,0.95,alpha*0.32),5.0,true)
		draw_polyline(points,Color(0.06,0.72,1.0,alpha),2.7,true)
		draw_polyline(points,Color(0.82,0.98,1.0,alpha*0.95),0.9,true)

func _perimeter(u:float,r:float) -> Vector2:
	var horizontal:float=size.x-2.0*r
	var vertical:float=size.y-2.0*r
	var quarter:float=PI*r*0.5
	var lengths:Array[float]=[horizontal,quarter,vertical,quarter,horizontal,quarter,vertical,quarter]
	var distance:float=u*(2.0*(horizontal+vertical)+TAU*r)
	for part:int in 8:
		if distance<=lengths[part]:
			match part:
				0:return Vector2(r+distance,0)
				2:return Vector2(size.x,r+distance)
				4:return Vector2(size.x-r-distance,size.y)
				6:return Vector2(0,size.y-r-distance)
				_:
					var centers:Array[Vector2]=[Vector2(size.x-r,r),Vector2(size.x-r,size.y-r),Vector2(r,size.y-r),Vector2(r,r)]
					var corner:int=(part-1)/2
					var angle:float=-PI*0.5+float(corner)*PI*0.5+distance/maxf(r,0.01)
					return centers[corner]+Vector2.from_angle(angle)*r
		distance-=lengths[part]
	return Vector2(r,0)
