# File: res://scenes/holdem_exchange_panel.gd
# Class: class_name HoldemExchangePanel
# Role: 텍사스 홀덤 교환 창 (1.3.1). 받은 5장을 앞면으로 늘어놓고, 바꿀 카드를 눌러 표시한 뒤 [교환하기] 또는 [그대로 확정]을 누른다.
#       교환은 남길 카드(keep: 5개 bool)를 굴림 행동에 실어 보내고, 새 카드와 최종 족보는 엔진이 정한다 (ToolHoldem).
class_name HoldemExchangePanel
extends Control

## 교환하기 (남길 카드 5개 bool).
signal exchange(keep: Array[bool])
## 교환하지 않고 확정.
signal stand

const GOLD: Color = Color("ffd43b")
const CARD_SIZE: Vector2 = Vector2(88, 128)
const LIFT: float = 18.0

var cards: Array[int] = []
var _marked: Array[bool] = []
var _items: Array[Control] = []
var _exchange_button: Button = null
var _hand_label: Label = null
var _touch_mouse_until: int = -1
var busy := true
var dealt := false
var _title: Label
var _dealer_deck: JudgmentCard
var _dim: ColorRect


func setup(hand: Array) -> void:
	name = "HoldemExchange"
	cards = []
	for card: Variant in hand:
		cards.append(int(card))
	_marked = []
	for index: int in cards.size():
		_marked.append(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim=JudgmentTableStyle.backdrop(self)
	var panel := PanelContainer.new()
	panel.name = "ExchangePanel"
	panel.custom_minimum_size.x=JudgmentTableStyle.WIDTH
	var style := JudgmentTableStyle.surface()
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var title := _label(L10n.t("바꿀 카드를 고르세요"), MobileSupport.text_px(20), JudgmentTableStyle.EDGE)
	_title=title
	column.add_child(title)
	_hand_label = _label("", MobileSupport.text_px(18), JudgmentTableStyle.TEXT)
	_hand_label.name = "HandLabel"
	column.add_child(_hand_label)
	var row := HBoxContainer.new()
	row.name = "CardRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	for index: int in cards.size():
		var holder := Control.new()
		holder.name = "ExchangeCard%d" % index
		holder.custom_minimum_size = CARD_SIZE + Vector2(0, LIFT)
		holder.mouse_filter = Control.MOUSE_FILTER_STOP
		holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var card := JudgmentCard.new()
		card.name = "Face"
		card.configure(JudgmentCardArt.poker(cards[index]), CARD_SIZE)
		card.set_face_up(true)
		card.position = Vector2(0, LIFT)
		card.size = CARD_SIZE
		holder.add_child(card)
		var tag := _label(L10n.t("교환"), MobileSupport.text_px(14), Color("1a1a1a"))
		tag.name = "SwapTag"
		var tag_style := StyleBoxFlat.new()
		tag_style.bg_color = Color("ff8787")
		tag_style.set_corner_radius_all(6)
		tag.add_theme_stylebox_override("normal", tag_style)
		tag.position = Vector2(CARD_SIZE.x * 0.5 - 26, 0)
		tag.size = Vector2(52, 22)
		tag.visible = false
		holder.add_child(tag)
		holder.gui_input.connect(func(event: InputEvent) -> void:
			var click: InputEventMouseButton = event as InputEventMouseButton
			var touch: InputEventScreenTouch = event as InputEventScreenTouch
			if touch != null:
				_touch_mouse_until = Time.get_ticks_msec() + 800
			elif click != null and Time.get_ticks_msec() < _touch_mouse_until:
				holder.accept_event()
				return
			if (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT) or (touch != null and touch.pressed):
				holder.accept_event()
				toggle(index))
		row.add_child(holder)
		_items.append(holder)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	column.add_child(buttons)
	_exchange_button = _button("ExchangeButton", Color("2b8a3e"))
	_exchange_button.pressed.connect(func() -> void:
		set_busy(true)
		exchange.emit(keep_mask()))
	buttons.add_child(_exchange_button)
	var stand_button := _button("StandButton", Color("37506b"))
	stand_button.text = L10n.t("그대로 확정")
	stand_button.pressed.connect(func() -> void:
		set_busy(true)
		stand.emit())
	buttons.add_child(stand_button)
	_refresh()
	MobileSupport.fit_touch_scale(panel, 1.5)
	panel.reset_size()
	panel.position = -panel.size * 0.5
	for item: Control in _items: item.get_node("Face").modulate.a=0
	set_busy(true)

func set_busy(value: bool) -> void:
	busy=value
	if _exchange_button!=null:
		_exchange_button.disabled=value or marked_count()==0
	var button:=find_child("StandButton",true,false) as Button
	if button!=null: button.disabled=value

func _process(_delta: float) -> void:
	if _dim!=null: JudgmentTableStyle.layout_backdrop(self,_dim)

## Deal onto these exact five table positions; the exchange UI never replaces them.
func play_deal() -> void:
	set_busy(true)
	await get_tree().process_frame
	await get_tree().process_frame
	if _dealer_deck==null:
		_dealer_deck=JudgmentCard.new()
		_dealer_deck.name="DealerDeck"
		_dealer_deck.configure(JudgmentCardArt.poker(0),CARD_SIZE)
		_dealer_deck.size=CARD_SIZE
		add_child(_dealer_deck)
		_dealer_deck.position=get_global_transform().affine_inverse()*_items[0].global_position+Vector2(240,-180)
		_dealer_deck.rotation=-.2
	for i: int in _items.size():
		var face:=_items[i].get_node("Face") as JudgmentCard
		face.set_face_up(false)
		face.modulate.a=1
		face.position=Vector2(240-i*(CARD_SIZE.x+10),-180)
		face.rotation=-.2
		Sfx.play(&"card_throw",-8)
		var tween:=create_tween().set_parallel(true)
		tween.tween_property(face,"position",Vector2(0,LIFT),.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(face,"rotation",0.0,.18)
		await tween.finished
		face.set_face_up(true)
	dealt=true
	set_busy(false)

## Selected cards slide back to the dealer; replacements arrive at the same slots.
func play_exchange(final_cards: Array, swapped: Array) -> void:
	set_busy(true)
	for index: Variant in swapped:
		var face:=_items[int(index)].get_node("Face") as JudgmentCard
		(_items[int(index)].get_node("SwapTag") as Control).hide()
		var take:=create_tween().set_parallel(true)
		take.tween_property(face,"position",Vector2(240-int(index)*(CARD_SIZE.x+10),-180),.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		take.tween_property(face,"rotation",.2,.28)
		take.tween_property(face,"modulate:a",0.0,.2).set_delay(.08)
		Sfx.play(&"card_pick",-8)
		await get_tree().create_timer(.12).timeout
	await get_tree().create_timer(.3).timeout
	cards.clear()
	for card: Variant in final_cards: cards.append(int(card))
	for index: Variant in swapped:
		var i:=int(index)
		var old:=_items[i].get_node("Face")
		_items[i].remove_child(old)
		old.queue_free()
		var face:=JudgmentCard.new()
		face.name="Face"
		face.configure(JudgmentCardArt.poker(cards[i]),CARD_SIZE)
		face.size=CARD_SIZE
		face.position=Vector2(240-i*(CARD_SIZE.x+10),-180)
		_items[i].add_child(face)
		face.set_face_up(false)
		Sfx.play(&"card_throw",-8)
		var deal:=create_tween()
		deal.tween_property(face,"position",Vector2(0,LIFT),.23).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await deal.finished
		face.set_face_up(true)
		Sfx.play(&"card_pick",-9)
	_marked.fill(false)
	_refresh()
	_title.text=L10n.t("최종 결과")
	_exchange_button.get_parent().modulate.a=0
	_hand_label.text=L10n.tf("최종 족보: %s (%d칸)",[L10n.t(str(MainBoard.HAND_NAMES.get(ToolHoldem.evaluate(cards),""))),ToolHoldem.steps_for(ToolHoldem.evaluate(cards))])
	await get_tree().create_timer(1.0).timeout
	busy=false


## 카드 하나의 교환 표시를 켜고 끈다 (터치·클릭과 테스트가 같은 길을 쓴다).
func toggle(index: int) -> void:
	if busy or index < 0 or index >= _marked.size():
		return
	_marked[index] = not _marked[index]
	Sfx.play(&"card_pick")
	_refresh()


## 남길 카드 (교환 표시가 없는 카드 = true).
func keep_mask() -> Array[bool]:
	var mask: Array[bool] = []
	for marked: bool in _marked:
		mask.append(not marked)
	return mask


func marked_count() -> int:
	return _marked.count(true)


func _refresh() -> void:
	for index: int in _items.size():
		var face: Control = _items[index].get_node("Face")
		face.position.y = 0.0 if _marked[index] else LIFT
		face.modulate = Color(0.62, 0.62, 0.68) if _marked[index] else Color.WHITE
		(_items[index].get_node("SwapTag") as Control).visible = _marked[index]
	var count: int = marked_count()
	_exchange_button.text = L10n.tf("%d장 교환하기", [count]) if count > 0 else L10n.t("교환하기")
	_exchange_button.disabled = count == 0
	var hand: StringName = ToolHoldem.evaluate(cards)
	_hand_label.text = L10n.tf("지금 족보: %s (%d칸)", [L10n.t(str(MainBoard.HAND_NAMES.get(hand, ""))), ToolHoldem.steps_for(hand)])


func _button(node_name: String, tone: Color) -> Button:
	var button := Button.new()
	button.name = node_name
	button.custom_minimum_size = Vector2(150, 46)
	button.add_theme_font_size_override("font_size", MobileSupport.text_px(18))
	for state_name: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = tone.lightened(0.12 if state_name == "hover" else 0.0).darkened(0.35 if state_name == "disabled" else 0.0)
		style.set_corner_radius_all(12)
		style.set_content_margin_all(8)
		if state_name == "focus":
			style.draw_center = false
		button.add_theme_stylebox_override(state_name, style)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_outline_color",Color.BLACK)
	button.add_theme_constant_override("outline_size",3)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))
	return button


func _label(text: String, px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", color)
	if color!=Color("1a1a1a"):
		label.add_theme_color_override("font_outline_color",Color.BLACK)
		label.add_theme_constant_override("outline_size",3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
