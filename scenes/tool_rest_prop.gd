# File: res://scenes/tool_rest_prop.gd
# Class: class_name ToolRestProp
# Role: 굴리기 전, 내 판정 도구가 굴리기 버튼 위 보드에 놓여 있는 소품 (1.3.1). 주사위·친치로 그릇·윷·슬롯·카드 더미·마작 패·
#       오미쿠지 통·아이스크림·쿠키·캡슐 기계·해적 통·복권·주식 차트를 실제 연출 그림 그대로 작게 세워 둔다 (밑에 그림자).
#       굴림 연출의 첫 장면·쉬는 장면을 한 번 그려 두고 3D 화면 갱신은 멈춘다 (기다리는 동안 그리기 비용이 없다).
#       자체 소품이 있는 도구(룰렛 원판·리볼버 패드·다트 과녁·야추·블랙잭·핀볼 무대)는 표시하지 않는다.
class_name ToolRestProp
extends Control

## 소품의 표시 높이 (기준 해상도 px). 너비는 그림 비율대로.
const HEIGHT: float = 112.0
## 도구 -> 소품 종류
const KINDS: Dictionary = {
	&"D6": "dice", &"CHINCHIRO": "dice", &"YUT": "yut", &"SLOT_777": "slot",
	&"HOLDEM": "cards", &"DICE_HWATU": "cards", &"DICE_TAROT": "cards", &"DICE_MAHJONG": "tiles",
	&"DICE_OMIKUJI": "view", &"DICE_ICECREAM": "view", &"DICE_COOKIE": "view", &"DICE_CAPSULE": "view",
	&"DICE_PIRATE": "view", &"DICE_SCRATCH": "view", &"DICE_STOCK": "view",
}
const CARD_BACKS: Dictionary = {&"HOLDEM": "backs/POKER_BACK", &"DICE_HWATU": "backs/HWATU_BACK", &"DICE_TAROT": "backs/TAROT_BACK"}

var tool_id: StringName = &""
var _holder: Control = null
var _freeze_frames: int = 0


static func supports(id: StringName) -> bool:
	return KINDS.has(id)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## 이 도구의 소품을 만든다 (같은 도구면 그대로 둔다).
func show_tool(id: StringName) -> void:
	if id == tool_id and _holder != null:
		return
	tool_id = id
	if _holder != null:
		_holder.queue_free()
		_holder = null
	if not supports(id):
		size = Vector2.ZERO
		return
	_holder = Control.new()
	_holder.name = "Prop"
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)
	var content: Control = _make(id)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(content)
	_pose(id, content)  # 3D 화면은 트리에 들어간 뒤에 자세를 잡는다
	var natural: Vector2 = content.size if content.size != Vector2.ZERO else content.custom_minimum_size
	var factor: float = (HEIGHT * {"dice": 1.45, "cards": 0.85}.get(str(KINDS[id]), 1.0)) / maxf(natural.y, 1.0)  # 주사위 화면은 여백이 넓다
	content.scale = Vector2.ONE * factor
	size = natural * factor
	_holder.size = size
	queue_redraw()
	# 쉬는 장면을 몇 프레임 그린 뒤 3D 화면 갱신을 멈춘다 (텍스처는 마지막 그림을 유지한다)
	_freeze_frames = 3
	set_process(true)


func _process(_delta: float) -> void:
	_freeze_frames -= 1
	if _freeze_frames > 0:
		return
	set_process(false)
	if _holder != null:
		for viewport: Node in _holder.find_children("*", "SubViewport", true, false):
			(viewport as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED


func _draw() -> void:
	if size == Vector2.ZERO or str(KINDS.get(tool_id, "dice")) in ["dice", "yut", "view"]:
		return  # 주사위·윷 3D 화면과 소품 연출 화면은 자체 바닥·그림자가 있다
	# 보드에 놓인 느낌: 바닥 그림자
	var center := Vector2(size.x * 0.5, size.y * 0.92)
	draw_set_transform(center, 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, size.x * 0.34, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO)


func _make(id: StringName) -> Control:
	match str(KINDS[id]):
		"dice": return DiceRoll3D.new()
		"yut": return YutThrow3D.new()
		"slot": return SlotMachine3D.new()
		"cards": return _card_stack(str(CARD_BACKS[id]))
		"tiles": return _tile_stack()
	match id:
		&"DICE_OMIKUJI": return OmikujiView.new()
		&"DICE_ICECREAM": return IceCreamView.new()
		&"DICE_COOKIE": return FortuneCookieView.new()
		&"DICE_CAPSULE": return CapsuleGachaView.new()
		&"DICE_PIRATE": return PirateBarrelView.new()
		&"DICE_SCRATCH": return ScratchTicketView.new()
	return StockChartView.new()


## 쉬는 장면: 주사위·윷은 굴러 멈춘 모습, 슬롯·소품 연출은 첫 장면.
func _pose(id: StringName, content: Control) -> void:
	match str(KINDS[id]):
		"dice":
			(content as DiceRoll3D).begin(4 if id == &"CHINCHIRO" else 6, 0.5, id)
			(content as DiceRoll3D).apply_time(3.0)
		"yut":
			(content as YutThrow3D).begin(3, 0.5)
			(content as YutThrow3D).apply_time(YutThrow3D.TOTAL_TIME)
		"slot":
			(content as SlotMachine3D).begin([5, 5, 5], 0.5)
			(content as SlotMachine3D).apply_time(0.0)
		"view":
			content.call("begin", {})
			content.call("apply_time", 0.3 if id == &"DICE_ICECREAM" else 0.0)  # 아이스크림은 막대가 들어온 뒤


## 카드 더미: 뒷면 3장을 살짝 비껴 쌓는다.
func _card_stack(back: String) -> Control:
	var box := Control.new()
	box.size = Vector2(150, 150)
	for index: int in 3:
		var card := TextureRect.new()
		card.texture = JudgmentCardArt.texture(back)
		card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		card.size = Vector2(76, 112)
		card.pivot_offset = card.size * 0.5
		card.position = Vector2(30 + index * 9, 22 - index * 4)
		card.rotation = deg_to_rad(-10 + index * 8)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(card)
	return box


## 마작 패 3개를 세워 둔다 (초록 뒷면).
func _tile_stack() -> Control:
	var box := Control.new()
	box.size = Vector2(170, 120)
	for index: int in 3:
		var tile := Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color("37b24d")
		style.border_color = Color("fff3bf")
		style.set_border_width_all(4)
		style.border_width_bottom = 12
		style.set_corner_radius_all(9)
		tile.add_theme_stylebox_override("panel", style)
		tile.size = Vector2(46, 66)
		tile.position = Vector2(14 + index * 50, 30)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tile)
	return box
