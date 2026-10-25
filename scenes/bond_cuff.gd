## Small persistent metal cuff: both bonded pawns share the same pulse clock.
extends Node2D

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var pulse := 0.65+sin(Time.get_ticks_msec()*0.004)*0.18
	var ring := PackedVector2Array()
	for index: int in 41:
		var angle := index*TAU/40.0
		ring.append(Vector2(cos(angle)*18,sin(angle)*7+4))
	draw_polyline(ring,Color("632a37"),5,true)
	draw_polyline(ring,Color("ef766c",pulse),2.4,true)
	for sign: int in [-1,1]:
		var at := Vector2(sign*16,5)
		draw_circle(at,2.8,Color("7c3b42"))
		draw_circle(at+Vector2(-0.5,-0.5),1.2,Color("ffe0a5"))
	# A tiny pair of interlocking links differentiates this from ordinary tile halos.
	for index: int in 2:
		var link := PackedVector2Array()
		for step: int in 17:
			var angle := step*TAU/16.0
			link.append(Vector2(9+index*5+cos(angle)*4,9+sin(angle)*2.3))
		draw_polyline(link,Color("632a37"),3,true)
		draw_polyline(link,Color("ffd0a0",pulse),1.3,true)
