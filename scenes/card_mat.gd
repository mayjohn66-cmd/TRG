# File: res://scenes/card_mat.gd
# Class: class_name CardMat
# Role: 카드형 판정 도구(타로·화투·텍사스 홀덤)를 쓰는 동안 판 가운데에 펼치는 카드 매트 (1.3.1 임시 구현).
#       말려 있던 매트가 가운데에서 좌우로 펼쳐지고(unroll), 끝나면 다시 말려 들어간다(roll_up). 매트 밖 보드는 살짝 어둡게 덮는다.
#       카드가 놓일 자리(slots)를 점선 테두리로 미리 그려 "여기에 놓인다"를 글 없이 보여 준다.
#       그림 파일 없이 코드로만 그린다 (천 질감 = 결정적 난수 점, 테두리 = 선). 일러스트가 생기면 _draw_* 대신 텍스처를 깔면 된다.
#       결과·난수와는 상관없다 (그림만).
class_name CardMat
extends Control

## 도구별 매트 모양. 다듬을 때 여기 값부터 바꾸면 된다.
const STYLES: Dictionary = {
	&"DICE_TAROT": {"base": Color("3a1d5c"), "center": Color("54307f"), "edge": Color("d9b65c"), "fleck": Color("c9a7ff"), "pattern": "stars"},
	&"DICE_HWATU": {"base": Color("56624a"), "center": Color("66745a"), "edge": Color("3b4433"), "fleck": Color("8d9a7c"), "pattern": "blanket"},
	&"HOLDEM": {"base": Color("176142"), "center": Color("23845b"), "edge": Color("5b3a22"), "fleck": Color("2f9a6b"), "pattern": "felt"},
	## 스크래치 복권: 복권방 나무 계산대.
	&"DICE_SCRATCH": {"base": Color("7a5230"), "center": Color("8f6440"), "edge": Color("4a301c"), "fleck": Color("b08455"), "pattern": "wood"},
	## 야추 다이스: 매트 없이 어둡게만 (주사위 케이스가 따로 놓인다).
	&"DICE_YACHT": {"base": Color("000000"), "center": Color("000000"), "edge": Color("000000"), "fleck": Color("000000"), "pattern": "none"},
}
## 매트 크기 (보드 좌표 px). 카드 줄과 버튼이 들어가는 크기.
const MAT_SIZE: Vector2 = Vector2(820, 470)
const UNROLL_TIME: float = 0.38
const ROLL_UP_TIME: float = 0.26
## 매트 밖 보드를 덮는 어둠.
const DIM_ALPHA: float = 0.42

var tool_id: StringName = &"DICE_TAROT"
## 펼쳐진 정도 0~1 (가운데에서 좌우로).
var reveal: float = 0.0:
	set(value):
		reveal = clampf(value, 0.0, 1.0)
		queue_redraw()
## 카드가 놓일 자리 (이 노드 좌표). 점선 테두리로 그린다.
var slots: Array[Rect2] = []:
	set(value):
		slots = value
		queue_redraw()
## 매트 한가운데 (이 노드 좌표).
var mat_center: Vector2 = Vector2.ZERO:
	set(value):
		mat_center = value
		queue_redraw()
## 매트 배율 (터치 화면은 MainBoard가 1.25로: 손가락으로 누를 카드가 커진 만큼).
var mat_scale: float = 1.0:
	set(value):
		mat_scale = value
		queue_redraw()
## 카드 자리를 돌려주는 함수 (펼쳐져 있는 동안 매 프레임 읽어 slots를 맞춘다). 비어 있으면 slots 그대로.
var slot_source: Callable = Callable()
var _flecks: PackedVector2Array = PackedVector2Array()
var _tween: Tween = null


func _init() -> void:
	name = "CardMat"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 131
	for index: int in 520:
		_flecks.append(Vector2(rng.randf(), rng.randf()))


func _process(_delta: float) -> void:
	if reveal > 0.0 and slot_source.is_valid():
		var fresh: Array[Rect2] = slot_source.call()
		if fresh != slots:
			slots = fresh


func setup(id: StringName) -> void:
	tool_id = id if STYLES.has(id) else &"DICE_TAROT"
	queue_redraw()


## 가운데에서 좌우로 펼친다.
func unroll(delay: float = 0.0) -> void:
	_run(1.0, UNROLL_TIME, delay)
	Sfx.play(&"ticket_rustle", -8.0)


## 다시 말아 넣는다. 다 말리면 돌아온다.
func roll_up() -> void:
	if reveal <= 0.0:
		return
	_run(0.0, ROLL_UP_TIME, 0.0)
	Sfx.play(&"ticket_rustle", -10.0)
	var tween: Tween = _tween
	while tween != null and tween.is_valid() and tween.is_running() and is_inside_tree():
		await get_tree().process_frame  # 도중에 다시 펼치면(트윈이 끊기면) 기다림도 바로 끝난다


func _run(target: float, seconds: float, delay: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "reveal", target, seconds).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if target > 0.5 else Tween.EASE_IN)


func mat_rect() -> Rect2:
	var full: Vector2 = MAT_SIZE * mat_scale
	var width: float = full.x * maxf(reveal, 0.0)
	return Rect2(mat_center - Vector2(width, full.y) / 2.0, Vector2(width, full.y))


func _draw() -> void:
	if reveal <= 0.0:
		return
	draw_rect(Rect2(Vector2(-4000, -4000), Vector2(8000, 8000)), Color(0.02, 0.03, 0.05, DIM_ALPHA * reveal))
	var style: Dictionary = STYLES[tool_id]
	if str(style["pattern"]) == "none":
		return
	var rect: Rect2 = mat_rect()
	var full := Rect2(mat_center - MAT_SIZE * mat_scale / 2.0, MAT_SIZE * mat_scale)
	# 그림자 → 바탕 → 가운데 밝은 기운 → 천 질감 → 무늬 → 테두리 → 카드 자리 → 말린 끝(두루마리)
	_round_rect(rect.grow(6).grow_side(SIDE_BOTTOM, 6), Color(0, 0, 0, 0.35), 26)
	_round_rect(rect, style["base"], 22)
	var inner: Rect2 = rect.grow(-rect.size.x * 0.18 if rect.size.x > 80 else 0.0)
	_round_rect(Rect2(inner.position.x, rect.position.y + 40, inner.size.x, rect.size.y - 80), Color(style["center"], 0.55), 120)
	var fleck: Color = style["fleck"]
	for point: Vector2 in _flecks:
		var at: Vector2 = full.position + point * full.size
		if rect.has_point(at):
			draw_rect(Rect2(at, Vector2(2, 2)), Color(fleck, 0.18))
	match str(style["pattern"]):
		"stars": _draw_stars(rect, full, style)
		"blanket": _draw_blanket(rect, style)
		"felt": _draw_felt(rect, full, style)
		"wood": _draw_wood(rect, style)
	if reveal > 0.85:
		for slot: Rect2 in slots:
			_dashed_rect(slot.grow(4), Color(1, 1, 1, 0.28 * (reveal - 0.85) / 0.15), 10)
	if reveal < 0.999:
		var roll_color: Color = Color(style["base"]).darkened(0.25)
		for side: float in [-1.0, 1.0]:
			var x: float = rect.get_center().x + side * rect.size.x / 2.0
			_round_rect(Rect2(x - 13, rect.position.y - 6, 26, rect.size.y + 12), roll_color, 13)
			draw_line(Vector2(x - 4, rect.position.y), Vector2(x - 4, rect.end.y), Color(1, 1, 1, 0.18), 3.0)


## 타로: 보라 벨벳에 흩뿌린 별과 금실 두 줄 테두리.
func _draw_stars(rect: Rect2, full: Rect2, style: Dictionary) -> void:
	var gold: Color = style["edge"]
	for index: int in 40:
		var point: Vector2 = _flecks[index * 7]
		var at: Vector2 = full.position + Vector2(0.06 + point.x * 0.88, 0.08 + point.y * 0.84) * full.size
		if rect.grow(-14).has_point(at):
			var radius: float = 2.0 + (index % 3) * 1.6
			draw_line(at - Vector2(radius, 0), at + Vector2(radius, 0), Color(gold, 0.55), 1.4)
			draw_line(at - Vector2(0, radius), at + Vector2(0, radius), Color(gold, 0.55), 1.4)
	_round_outline(rect.grow(-10), gold, 18, 2.5)
	_round_outline(rect.grow(-17), Color(gold, 0.5), 14, 1.2)


## 화투: 군용 담요처럼 거친 털 질감과 휘갑치기 가장자리.
func _draw_blanket(rect: Rect2, style: Dictionary) -> void:
	var edge: Color = style["edge"]
	_round_outline(rect.grow(-6), edge, 20, 6.0)
	var step: float = 14.0
	var x: float = rect.position.x + 12
	while x < rect.end.x - 12:
		draw_line(Vector2(x, rect.position.y + 2), Vector2(x + 6, rect.position.y + 12), Color("c9c2a3", 0.7), 2.0)
		draw_line(Vector2(x, rect.end.y - 2), Vector2(x + 6, rect.end.y - 12), Color("c9c2a3", 0.7), 2.0)
		x += step
	for row: int in 3:
		var y: float = rect.position.y + rect.size.y * (0.25 + row * 0.25)
		draw_line(Vector2(rect.position.x + 20, y), Vector2(rect.end.x - 20, y), Color(0, 0, 0, 0.05), 10.0)


## 홀덤: 초록 펠트에 가죽 테두리(레일)와 안쪽 금색 선.
func _draw_felt(rect: Rect2, _full: Rect2, style: Dictionary) -> void:
	var leather: Color = style["edge"]
	_round_outline(rect.grow(-9), leather, 22, 18.0)
	_round_outline(rect.grow(-3), leather.lightened(0.25), 24, 2.0)
	_round_outline(rect.grow(-32), Color("e9c46a", 0.45), 60, 1.6)


## 스크래치 복권: 나무 결이 가로로 흐르는 계산대 상판과 어두운 모서리.
func _draw_wood(rect: Rect2, style: Dictionary) -> void:
	var grain: Color = Color(style["edge"], 0.22)
	for row: int in 14:
		var y: float = rect.position.y + 18.0 + row * (rect.size.y - 36.0) / 13.0
		var points := PackedVector2Array()
		for step: int in 13:
			var x: float = rect.position.x + 14.0 + step * (rect.size.x - 28.0) / 12.0
			points.append(Vector2(x, y + sin(step * 0.9 + row * 1.7) * 3.0))
		draw_polyline(points, grain, 2.0, true)
	_round_outline(rect.grow(-4), style["edge"], 22, 8.0)


func _round_rect(rect: Rect2, color: Color, radius: float) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(minf(radius, minf(rect.size.x, rect.size.y) / 2.0)))
	draw_style_box(box, rect)


func _round_outline(rect: Rect2, color: Color, radius: float, width: float) -> void:
	if rect.size.x <= width * 2.0 or rect.size.y <= width * 2.0:
		return
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = color
	box.set_border_width_all(int(width))
	box.set_corner_radius_all(int(minf(radius, minf(rect.size.x, rect.size.y) / 2.0)))
	draw_style_box(box, rect)


func _dashed_rect(rect: Rect2, color: Color, dash: float) -> void:
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for side: int in 4:
		draw_dashed_line(corners[side], corners[(side + 1) % 4], color, 2.0, dash)
