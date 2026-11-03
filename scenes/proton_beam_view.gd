# File: res://scenes/proton_beam_view.gd
# Class: class_name ProtonBeamView
# Role: SUM_03 롤링 양성자빔의 보드 위 모습 - 하늘에서 내리꽂힌 보라·하늘빛 빛 기둥과 바닥의 이글거리는 원.
#       그림은 한 번만 그린다 (평소 일렁임은 modulate 트윈이라 매 프레임 다시 그리지 않는다: 30프레임 기기 부담 X).
#       강림(descend) 동안만 기둥 길이를 바꿔 가며 다시 그리고, 소멸(fade_out)은 가늘어지며 위로 걷힌다.
class_name ProtonBeamView
extends Node2D

const HEIGHT: float = 230.0
const OUTER: Color = Color(0.55, 0.35, 1.0, 0.28)
const MID: Color = Color(0.95, 0.45, 1.0, 0.55)
const EDGE: Color = Color(0.55, 0.85, 1.0, 0.85)
const CORE: Color = Color(1.0, 0.97, 1.0, 0.95)
const FONT: Font = preload("res://assets/fonts/game_ui_font.tres")

## 0~1: 기둥이 위에서부터 내려온 정도 (강림 연출). 평소에는 1.
var drop: float = 1.0:
	set(value):
		drop = clampf(value, 0.0, 1.0)
		queue_redraw()
		if _glow != null:
			_glow.queue_redraw()
## 남은 이동 라운드 (기둥 아래 라벨).
var rounds_left: int = 3
var _shimmer: Tween = null


## 바깥 빛 번짐: 가산 합성(ADD)이라 보드 위에서 빛처럼 겹쳐 밝아진다. 심·라벨은 본체가 보통 합성으로 그린다.
var _glow: Node2D = null


func _ready() -> void:
	_glow = Node2D.new()
	_glow.name = "Glow"
	_glow.show_behind_parent = true
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = additive
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	_start_shimmer()


func configure(rounds: int) -> void:
	if rounds == rounds_left:
		return
	rounds_left = rounds
	queue_redraw()


## 하늘에서 빛 기둥이 내리꽂힌다 (그동안만 다시 그린다). 끝나면 finished 콜백 없이 평소 일렁임으로 돌아간다.
func descend(duration: float = 0.45) -> Tween:
	visible = true
	drop = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "drop", 1.0, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	return tween


## 수명이 다하면 가늘어지며 위로 걷히고 사라진다 (스스로 queue_free).
func fade_out(duration: float = 0.7) -> void:
	if _shimmer != null:
		_shimmer.kill()
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale:x", 0.05, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(queue_free)


func _start_shimmer() -> void:
	_shimmer = create_tween().set_loops()
	_shimmer.tween_property(self, "modulate", Color(1.15, 1.05, 1.2, 1.0), 0.18)
	_shimmer.tween_property(self, "modulate", Color(0.9, 0.9, 1.0, 0.92), 0.22)


func _exit_tree() -> void:
	if _shimmer != null:
		_shimmer.kill()


func _draw() -> void:
	var top: float = -HEIGHT
	var bottom: float = lerpf(top, 0.0, drop)  # 위에서부터 내려오는 기둥의 아래 끝
	if drop >= 0.98:
		_ellipse(Vector2(0, 2), Vector2(26, 9), Color(1.0, 0.8, 1.0, 0.7))
		_ellipse(Vector2(0, 1), Vector2(14, 4.5), CORE)
	# 기둥: 분홍 → 하늘빛 테두리 → 흰 심 (바깥 보라 번짐은 _draw_glow)
	draw_rect(Rect2(-16, top, 32, bottom - top), MID)
	draw_rect(Rect2(-11, top, 4, bottom - top), EDGE)
	draw_rect(Rect2(7, top, 4, bottom - top), EDGE)
	draw_rect(Rect2(-7, top, 14, bottom - top), CORE)
	if drop >= 0.98:
		# 기둥을 감는 번개 (위치 고정 - 일렁임은 modulate가 맡는다)
		for i: int in 4:
			var y0: float = top + 24.0 + i * 50.0
			var side: float = -1.0 if i % 2 == 0 else 1.0
			var bolt := PackedVector2Array([Vector2(side * 12, y0), Vector2(side * 21, y0 + 10), Vector2(side * 14, y0 + 19), Vector2(side * 23, y0 + 31)])
			draw_polyline(bolt, Color(0.85, 0.97, 1.0, 0.95), 2.0, true)
		var text: String = L10n.t("양성자빔 · %dR") % rounds_left
		var width: float = 84.0
		var origin := Vector2(-width / 2.0, 24.0)
		draw_rect(Rect2(origin + Vector2(0.0, -11.0), Vector2(width, 15.0)), Color(0.12, 0.02, 0.18, 0.85))
		draw_string(FONT, origin, text, HORIZONTAL_ALIGNMENT_CENTER, width, 11, Color("f3d9ff"))


## 가산 합성 번짐: 넓은 보라 기둥 두 겹 + 바닥의 빛 웅덩이.
func _draw_glow() -> void:
	var top: float = -HEIGHT
	var bottom: float = lerpf(top, 0.0, drop)
	_glow.draw_rect(Rect2(-34, top, 68, bottom - top), Color(0.35, 0.15, 0.7, 0.35))
	_glow.draw_rect(Rect2(-24, top, 48, bottom - top), Color(0.6, 0.25, 0.85, 0.4))
	if drop >= 0.98:
		for ring: int in 3:
			var radius := Vector2(58 - ring * 14, 20 - ring * 5)
			var points := PackedVector2Array()
			for i: int in 28:
				var angle: float = TAU * float(i) / 28.0
				points.append(Vector2(cos(angle) * radius.x, 2.0 + sin(angle) * radius.y))
			_glow.draw_colored_polygon(points, Color(0.55, 0.25, 0.8, 0.28))


func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i: int in 24:
		var angle: float = TAU * float(i) / 24.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
