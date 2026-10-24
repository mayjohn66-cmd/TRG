# File: res://scenes/stage_blackjack.gd
# Class: class_name BlackjackStage
# Role: 블랙잭 21 딜러의 중앙 오픈 스테이지. 받은 카드와 합계(-10 = 이동 칸수)를 크게 보여 주고 [히트]/[스탠드]를 누른다. 21은 블랙잭, 22 이상은 버스트. 연출만 담당하며 판정은 엔진(ToolBlackjack)이 한다
class_name BlackjackStage
extends Control

signal start_pressed
signal hit_pressed
signal stand_pressed

const STAGE_SIZE: Vector2 = Vector2(620.0, 290.0)
const DEAL_SECONDS: float = 0.2
const CARD_SIZE := Vector2(78.0, 112.0)


var cards: Array[int] = []
var started: bool = false
var can_act: bool = false
var active: bool = false
var instant: bool = false

var _title: Label = null
var _row: HBoxContainer = null
var _total_label: Label = null
var _start_button: Button = null
var _hit_button: Button = null
var _stand_button: Button = null
var _result_text: String = ""
var _result_color: Color = UiSkin.INK


func _init() -> void:
	custom_minimum_size = STAGE_SIZE
	size = STAGE_SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS


func _ready() -> void:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", UiSkin.panel("panel", 12.0))
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_title = _label("블랙잭 21 딜러", 18, UiSkin.GREEN)
	_title.position = Vector2(0.0, 10.0)
	_title.size = Vector2(STAGE_SIZE.x, 26.0)
	add_child(_title)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 8)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.position = Vector2(10.0, 42.0)
	_row.size = Vector2(STAGE_SIZE.x - 20.0, 116.0)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	_total_label = _label("", 30, UiSkin.INK)
	_total_label.position = Vector2(0.0, 166.0)
	_total_label.size = Vector2(STAGE_SIZE.x, 40.0)
	add_child(_total_label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.position = Vector2(10.0, 224.0)
	buttons.size = Vector2(STAGE_SIZE.x - 20.0, 50.0)
	add_child(buttons)
	_start_button = _button("카드 받기", true, 320.0)
	_start_button.pressed.connect(func() -> void: start_pressed.emit())
	buttons.add_child(_start_button)
	_hit_button = _button("히트 (카드 1장 더 뽑기)", false, 290.0)
	_hit_button.pressed.connect(func() -> void:
		if can_act and started and not active:
			hit_pressed.emit())
	buttons.add_child(_hit_button)
	_stand_button = _button("스탠드 (현재 0칸 이동 확정)", true, 290.0)
	_stand_button.pressed.connect(func() -> void:
		if can_act and started and not active:
			stand_pressed.emit())
	buttons.add_child(_stand_button)
	_refresh()


func _label(text: String, size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String, action: bool, width: float) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 46.0)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	UiSkin.button(button, action, 10.0, 6.0)
	return button


## 엔진 상태에 화면을 맞춘다. acting은 지금 내가 조작할 차례인가.
func sync(tool: ToolBlackjack, acting: bool) -> void:
	can_act = acting
	if active:
		return
	if tool != null and tool.has_pending_state():
		started = true
		cards.assign(tool.cards)
	elif not started and _result_text == "":
		cards = []
	_refresh()


## 새 차례가 되면 지난 결과를 지우고 처음 화면으로 돌린다.
func reset() -> void:
	cards = []
	started = false
	active = false
	_result_text = ""
	_refresh()


## 엔진 결과를 카드 한 장씩 나눠 주는 연출로 보여 준다. 끝나면 돌아온다.
func play(result: Dictionary) -> void:
	var details: Dictionary = result["details"]
	var all_cards: Array = details["cards"]
	var fresh: Array = details["new_cards"]
	var confirmed: bool = bool(details.get("confirmed", false))
	var bust: bool = bool(details.get("bust", false))
	var blackjack: bool = bool(details.get("blackjack", false))
	_result_text = ""
	if instant or not is_inside_tree():
		cards.assign(all_cards)
		started = not confirmed
		_apply_result_text(confirmed, bust, blackjack, int(result["steps"]), int(details["total"]))
		_refresh()
		return
	active = true
	var known: int = all_cards.size() - fresh.size()
	cards.assign(all_cards.slice(0, known))
	started = true
	_refresh()
	for index: int in fresh.size():
		await get_tree().create_timer(DEAL_SECONDS).timeout
		if not is_instance_valid(self):
			return
		cards.append(int(fresh[index]))
		_refresh()
		var view: Control = _row.get_child(_row.get_child_count() - 1) as Control
		if view != null:
			view.modulate.a = 0.0
			view.position.y = -40.0
			var tween: Tween = view.create_tween().set_parallel(true)
			tween.tween_property(view, "modulate:a", 1.0, 0.12)
			tween.tween_property(view, "position:y", 0.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.25).timeout
	if not is_instance_valid(self):
		return
	started = not confirmed
	_apply_result_text(confirmed, bust, blackjack, int(result["steps"]), int(details["total"]))
	active = false
	_refresh()


func _apply_result_text(confirmed: bool, bust: bool, blackjack: bool, steps: int, total: int) -> void:
	if bust:
		_result_text = "BUST! (21 초과 - 0칸 이동 실패)  합계 %d" % total
		_result_color = Color("bf4941")
	elif blackjack:
		_result_text = "BLACKJACK! 21 → %d칸 + 한 번 더!" % steps
		_result_color = UiSkin.GREEN
	elif confirmed:
		_result_text = "스탠드: 합계 %d → %d칸 이동!" % [total, steps]
		_result_color = UiSkin.INK
	else:
		_result_text = ""


func _refresh() -> void:
	if _row == null:
		return
	# 카드 줄을 현재 카드로 다시 맞춘다 (이미 있는 카드는 그대로 두고 모자란 것만 더한다).
	while _row.get_child_count() > cards.size():
		var extra: Node = _row.get_child(_row.get_child_count() - 1)
		_row.remove_child(extra)
		extra.queue_free()
	while _row.get_child_count() < cards.size():
		var index: int = _row.get_child_count()
		var card := JudgmentCard.new()
		card.configure(_card_model(cards[index], index), CARD_SIZE)
		_row.add_child(card)
		card.set_face_up(true)
	for index: int in cards.size():
		var view: JudgmentCard = _row.get_child(index) as JudgmentCard
		var model: Dictionary = _card_model(cards[index], index)
		if view.model.id != model.id:
			view.model = model
			view._layout_front()
	var total: int = ToolBlackjack.total_of(cards)
	if started and not cards.is_empty():
		_total_label.text = "합계 %d  →  %d칸 전진" % [total, total - ToolBlackjack.STEPS_OFFSET]
		_total_label.add_theme_color_override("font_color", UiSkin.INK)
	elif _result_text != "":
		_total_label.text = _result_text
		_total_label.add_theme_color_override("font_color", _result_color)
	else:
		_total_label.text = "카드를 받아 합계 11~21을 만드세요 (합계 -10칸 전진)"
		_total_label.add_theme_color_override("font_color", UiSkin.INK)
	_total_label.add_theme_font_size_override("font_size", 30 if started and not cards.is_empty() else 20)
	_start_button.visible = not started
	_start_button.disabled = not can_act or active
	_hit_button.visible = started
	_stand_button.visible = started
	_hit_button.disabled = not (can_act and not active)
	_stand_button.disabled = not (can_act and not active)
	_stand_button.text = "스탠드 (현재 %d칸 이동 확정)" % (total - ToolBlackjack.STEPS_OFFSET)
	_title.text = "블랙잭 21 딜러 - 히트 또는 스탠드" if started and can_act else "블랙잭 21 딜러"


## Blackjack supplies ranks only (A=1); suits remain deterministic decoration.
## Adapt to the existing Hold'em art IDs (2=0 ... A=12), not the scoring rules.
static func _card_model(rank: int, index: int) -> Dictionary:
	var suit: int = int([3, 2, 1, 0][(rank + index) % 4])
	var face: int = 12 if rank == 1 else rank - 2
	return JudgmentCardArt.poker(suit * 13 + face)
