extends Node2D

const ART := preload("res://assets/fx/emergency_repair/doll.png")
const DURATION := 1.65
var elapsed := 0.0
var pace := 1.0


func _process(delta: float) -> void:
	elapsed = minf(elapsed + delta * pace, DURATION)
	modulate.a = minf(elapsed / 0.18, (DURATION - elapsed) / 0.22)
	queue_redraw()


func busy() -> bool:
	return elapsed < DURATION


func _draw() -> void:
	draw_texture_rect(ART, Rect2(-88, -125, 176, 196), false)
	var repaired := clampf((elapsed - 0.25) / 0.9, 0.0, 1.0)
	var patch := StyleBoxFlat.new()
	patch.bg_color = Color("f4dec5")
	patch.set_corner_radius_all(5)
	if repaired > 0:
		draw_style_box(patch, Rect2(-12, -2, 24, 48 * repaired))
	for i: int in 7:
		if float(i) / 7.0 > repaired:
			break
		var y := float(i) * 6.0
		draw_line(Vector2(-8, y - 2), Vector2(8, y + 2), Color("a64675"), 2.4, true)
		draw_line(Vector2(-8, y + 2), Vector2(8, y - 2), Color("f49ac0"), 1.6, true)
	if repaired > 0.0 and repaired < 1.0:
		var tip := Vector2(sin(elapsed * 38.0) * 18.0, 48 * repaired)
		var thread := PackedVector2Array([Vector2(0, 48 * repaired), tip + Vector2(22, -32), tip + Vector2(38, -19), tip])
		draw_polyline(thread, Color("ed82b3"), 2.0, true)
		draw_line(tip, tip + Vector2(9, -24), Color("646978"), 3.5, true)
		draw_line(tip, tip + Vector2(9, -24), Color("f4fbff"), 1.4, true)
