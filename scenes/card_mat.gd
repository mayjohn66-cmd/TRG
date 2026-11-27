# File: res://scenes/card_mat.gd
# Class: class_name CardMat
# Role: 카드형 판정 도구(타로·화투·텍사스 홀덤)를 쓰는 동안 판 가운데에 펼치는 카드 매트 (1.3.1 임시 구현).
#       말려 있던 매트가 가운데에서 좌우로 펼쳐지고(unroll), 끝나면 다시 말려 들어간다(roll_up). 매트 밖 보드는 살짝 어둡게 덮는다.
#       카드가 놓일 자리(slots)를 점선 테두리로 미리 그려 "여기에 놓인다"를 글 없이 보여 준다.
#       공용 짧은 섬유 텍스처를 세 색상으로 착색한다. 테두리·문양·카드 자리는 코드로 유지한다.
#       결과·난수와는 상관없다 (그림만).
class_name CardMat
extends Control

const FABRIC: Texture2D = preload("res://assets/ui/trickcal/card_mats/v1/felt-neutral.webp")
const WOOD: Texture2D = preload("res://assets/ui/trickcal/card_mats/v1/wood-oak.webp")
## Stable board-space grain: unrolling reveals cloth instead of stretching it.
const FABRIC_TILE_PIXELS := 320.0

## 도구별 매트 모양. 다듬을 때 여기 값부터 바꾸면 된다.
const STYLES: Dictionary = {
	&"DICE_TAROT": {"base": Color("3a1d5c"), "center": Color("54307f"), "edge": Color("d9b65c"), "fleck": Color("c9a7ff"), "pattern": "stars"},
	&"DICE_HWATU": {"base": Color("56624a"), "center": Color("66745a"), "edge": Color("3b4433"), "fleck": Color("8d9a7c"), "pattern": "blanket"},
	&"HOLDEM": {"base": Color("176142"), "center": Color("23845b"), "edge": Color("5b3a22"), "fleck": Color("2f9a6b"), "pattern": "felt"},
	## 스크래치 복권: 복권방 나무 계산대.
	&"DICE_SCRATCH": {"base": Color("7a5230"), "center": Color("8f6440"), "edge": Color("4a301c"), "fleck": Color("b08455"), "pattern": "wood"},
	## 리치 마작: 자동탁 같은 진초록 펠트에 어두운 테.
	&"DICE_MAHJONG": {"base": Color("0f5132"), "center": Color("17693f"), "edge": Color("2b2118"), "fleck": Color("2a8a56"), "pattern": "felt"},
	## 블랙잭: 카지노 블랙잭 테이블 (짙은 청록 펠트·가죽 레일·안쪽 금선).
	&"DICE_BLACKJACK": {"base": Color("0d4f4a"), "center": Color("16706a"), "edge": Color("4a2a18"), "fleck": Color("23867f"), "pattern": "felt"},
	## 야추 다이스: 매트 없이 어둡게만 (주사위 케이스가 따로 놓인다).
	&"DICE_YACHT": {"base": Color("000000"), "center": Color("000000"), "edge": Color("000000"), "fleck": Color("000000"), "pattern": "none"},
	&"DICE_PINBALL": {"base": Color("000000"), "center": Color("000000"), "edge": Color("000000"), "fleck": Color("000000"), "pattern": "none"},  # 핀볼대가 직접 판 위에 놓인다
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
	texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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


## 나무 계산대처럼 단단한 판은 말리거나 접히지 않는다 (1.3.1): 화면 아래에서 들고 와 내려놓고, 끝나면 들어서 아래로 치운다.
const CARRY_DISTANCE: float = 520.0
const CARRY_IN_TIME: float = 0.42
const CARRY_OUT_TIME: float = 0.32


func is_rigid() -> bool:
	return str(STYLES[tool_id]["pattern"]) == "wood"


## 가운데에서 좌우로 펼친다 (단단한 판은 아래에서 들고 와 내려놓는다).
func unroll(delay: float = 0.0) -> void:
	if is_rigid():
		_run(1.0, CARRY_IN_TIME, delay)
		_tween.tween_callback(func() -> void: Sfx.play(&"thud", -8.0, 0.0, 1.1))  # 판을 내려놓는 쿵
		Sfx.play(&"card_pick", -10.0)
		return
	_run(1.0, UNROLL_TIME, delay)
	Sfx.play(&"ticket_rustle", -8.0)


## 다시 말아 넣는다. 다 말리면 돌아온다.
func roll_up() -> void:
	if reveal <= 0.0:
		return
	if is_rigid():
		_run(0.0, CARRY_OUT_TIME, 0.0)  # 살짝 들어 아래로 치운다
		Sfx.play(&"card_pick", -10.0)
	else:
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
	if is_rigid():
		# 판 모양은 그대로, 아래에서 올라오며(들고 오며) 자리를 잡는다
		return Rect2(mat_center - full / 2.0 + Vector2(0.0, (1.0 - reveal) * CARRY_DISTANCE), full)
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
	if minf(rect.size.x, rect.size.y) < 2.0: return
	var rigid: bool = is_rigid()
	var full := rect if rigid else Rect2(mat_center - MAT_SIZE * mat_scale / 2.0, MAT_SIZE * mat_scale)  # 단단한 판은 무늬도 판과 같이 움직인다
	# 그림자 → 바탕 → 가운데 밝은 기운 → 천 질감 → 무늬 → 테두리 → 카드 자리 → 말린 끝(두루마리)
	var held: float = (1.0 - reveal) if rigid else 0.0  # 들고 있는 동안에는 그림자가 판에서 떨어져 보인다
	_round_rect(rect.grow(6).grow_side(SIDE_BOTTOM, 6 + held * 28.0), Color(0, 0, 0, 0.35 * (1.0 - held * 0.5)), 26)
	if rigid:
		_round_rect(Rect2(rect.position + Vector2(0,12), rect.size), Color("674025"), 22)
	_round_rect(rect, style["base"], 22)
	_draw_fabric(rect,full,style)
	match str(style["pattern"]):
		"stars": _draw_stars(rect, full, style)
		"blanket": _draw_blanket(rect, style)
		"felt": _draw_felt(rect, full, style)
		"wood": _draw_wood(rect, style)
	if reveal > 0.85:
		for slot: Rect2 in slots:
			_dashed_rect(slot.grow(4), Color(1, 1, 1, 0.28 * (reveal - 0.85) / 0.15), 10)
	if reveal < 0.999 and not rigid:
		var roll_color: Color = Color(style["base"]).darkened(0.25)
		for side: float in [-1.0, 1.0]:
			var x: float = rect.get_center().x + side * rect.size.x / 2.0
			_round_rect(Rect2(x - 13, rect.position.y - 6, 26, rect.size.y + 12), roll_color, 13)
			draw_line(Vector2(x - 4, rect.position.y), Vector2(x - 4, rect.end.y), Color(1, 1, 1, 0.18), 3.0)


func _draw_fabric(rect: Rect2, full: Rect2, style: Dictionary) -> void:
	var wooden:=str(style["pattern"])=="wood"
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var radius := minf(22.0,minf(rect.size.x,rect.size.y)*.49)
	var centers: Array[Vector2] = [rect.position+Vector2(radius,radius),Vector2(rect.end.x-radius,rect.position.y+radius),rect.end-Vector2.ONE*radius,Vector2(rect.position.x+radius,rect.end.y-radius)]
	for corner: int in 4:
		for step: int in 7:
			var angle := PI+corner*PI*.5+step*PI/12.0
			var point := centers[corner]+Vector2.from_angle(angle)*radius
			points.append(point)
			uvs.append((point-full.position)/full.size if wooden else (point-full.position)/FABRIC_TILE_PIXELS)
	# The neutral cloth averages mid-gray. This tint restores the existing palette
	# while retaining the fine fiber highlights and depressions in one shared draw.
	var tint: Color = Color(style["base"]).lerp(Color(style["center"]),.45)
	tint=Color(tint.r*1.9,tint.g*1.9,tint.b*1.9,1)
	draw_polygon(points,PackedColorArray([Color.WHITE if wooden else tint]),uvs,WOOD if wooden else FABRIC)


## 타로: 보라 천과 가는 금실 봉제선.
func _draw_stars(rect: Rect2, full: Rect2, style: Dictionary) -> void:
	var gold: Color = style["edge"]
	for index: int in 40:
		var point: Vector2 = _flecks[index * 7]
		var at: Vector2 = full.position + Vector2(0.06 + point.x * 0.88, 0.08 + point.y * 0.84) * full.size
		# During the first/last unroll frames the visible strip is narrower than
		# the star inset. Do not pass a negative-size Rect2 to has_point().
		if rect.size.x > 28.0 and rect.size.y > 28.0 and rect.grow(-14).has_point(at):
			var radius: float = 2.0 + (index % 3) * 1.6
			draw_line(at - Vector2(radius, 0), at + Vector2(radius, 0), Color(gold, 0.55), 1.4)
			draw_line(at - Vector2(0, radius), at + Vector2(0, radius), Color(gold, 0.55), 1.4)
	_draw_binding(rect,style,8.0,Color(gold,.46))


## 화투: 담요와 같은 천으로 감싼 가장자리, 작은 휘갑치기.
func _draw_blanket(rect: Rect2, style: Dictionary) -> void:
	_draw_binding(rect,style,9.0,Color("c9c2a3",.34))


## 홀덤: 짙은 녹색 패브릭 바인딩과 낮은 대비의 실밥.
func _draw_felt(rect: Rect2, _full: Rect2, style: Dictionary) -> void:
	_draw_binding(rect,style,10.0,Color("b7bb8c",.3))


func _rounded_contour(rect: Rect2, radius: float) -> PackedVector2Array:
	var path:=PackedVector2Array()
	var r:=minf(radius,minf(rect.size.x,rect.size.y)*.49)
	var centers: Array[Vector2]=[rect.position+Vector2.ONE*r,Vector2(rect.end.x-r,rect.position.y+r),rect.end-Vector2.ONE*r,Vector2(rect.position.x+r,rect.end.y-r)]
	for corner: int in 4:
		for step: int in 7:
			path.append(centers[corner]+Vector2.from_angle(PI+corner*PI*.5+step*PI/12.0)*r)
	return path


## A textured cloth binding, not a flat frame. Shared fibers run through the
## narrow band; tiny staggered stitches follow its curved edge on all four sides.
func _draw_binding(rect: Rect2, style: Dictionary, width: float, thread: Color) -> void:
	if rect.size.x<=width*2+4 or rect.size.y<=width*2+4: return
	var outer:=_rounded_contour(rect.grow(-1),21)
	var inner:=_rounded_contour(rect.grow(-width),maxf(2,22-width))
	var ink: Color=Color(style["base"]).lerp(Color(style["edge"]),.38).darkened(.12)
	var full:=Rect2(mat_center-MAT_SIZE*.5,MAT_SIZE)
	for i: int in outer.size():
		var next: int=(i+1)%outer.size()
		var quad:=PackedVector2Array([outer[i],outer[next],inner[next],inner[i]])
		if Geometry2D.triangulate_polygon(quad).is_empty(): continue
		var uv:=PackedVector2Array()
		for point: Vector2 in quad: uv.append((point-full.position)/FABRIC_TILE_PIXELS)
		var tint:=Color(ink.r*1.9,ink.g*1.9,ink.b*1.9,1)
		draw_polygon(quad,PackedColorArray([tint]),uv,FABRIC)
	# A shallow crease where the bound edge presses into the pile.
	var crease:=_rounded_contour(rect.grow(-width+.8),maxf(2,22-width))
	crease.append(crease[0])
	draw_polyline(crease,Color(0,0,0,.14),1.0,true)
	var seam:=_rounded_contour(rect.grow(-width*.55),22-width*.55)
	var stitches:=PackedVector2Array()
	var stitch_shadows:=PackedVector2Array()
	var travelled:=0.0
	for i: int in seam.size():
		var start: Vector2=seam[i]
		var delta: Vector2=seam[(i+1)%seam.size()]-start
		var length:=delta.length()
		if length<.01: continue
		var direction:=delta/length
		var normal:=Vector2(-direction.y,direction.x)
		var offset:=fposmod(-travelled,8.5)
		while offset+3.0<length:
			var slip:=sin((travelled+offset)*.39)*.35
			var a:=start+direction*offset+normal*slip
			var b:=a+direction*2.8+normal*.65
			stitch_shadows.append_array(PackedVector2Array([a+Vector2(0,.65),b+Vector2(0,.65)]))
			stitches.append_array(PackedVector2Array([a,b]))
			offset+=8.5
		travelled+=length
	if not stitches.is_empty():
		draw_multiline(stitch_shadows,Color(0,0,0,.18),1.3,true)
		draw_multiline(stitches,thread,1.0,true)


## 스크래치 복권: 나무 결이 가로로 흐르는 계산대 상판과 어두운 모서리.
func _draw_wood(rect: Rect2, style: Dictionary) -> void:
	_round_outline(rect,Color("6b4529"),22,2.0)
	if rect.size.x>48 and rect.size.y>48:
		draw_line(rect.position+Vector2(24,2),Vector2(rect.end.x-24,rect.position.y+2),Color(1,.89,.65,.45),2.0,true)
		draw_line(Vector2(rect.position.x+24,rect.end.y-1),rect.end-Vector2(24,1),Color(style["edge"],.5),2.0,true)


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

