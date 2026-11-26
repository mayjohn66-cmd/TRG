# File: res://scenes/tool_pick_modal.gd
# Class: class_name ToolPickModal
# Role: 판정 도구 "터치로 고르기" 창 (1.3.1). 뒷면 카드·패·막대·쿠키 등을 늘어놓고 플레이어가 직접 골라 뒤집는다.
#       확률은 엔진이 평소처럼 정하므로(ToolPick) 어느 것을 골라도 같다: 고른 자리를 굴림 행동의 "pick"으로 보낸다.
#       시간이 지나 엔진이 자동으로 굴리면 MainBoard가 창을 닫는다.
class_name ToolPickModal
extends Control

## 고르기가 끝났다 (고른 자리 번호들, 고른 순서).
signal picked(indices: Array[int])

const GOLD: Color = Color("ffd43b")
const INK: Color = Color("f8f9fa")
## 도구 -> 뒷면 모양: card(그림 뒷면) / tile(마작 패) / stick(오미쿠지 막대) / icon(도구 그림)
const LOOKS: Dictionary = {
	&"DICE_TAROT": {"kind": "card", "back": "backs/TAROT_BACK", "size": Vector2(96, 156), "title": "타로 카드를 한 장 고르세요", "item": "카드"},
	&"DICE_HWATU": {"kind": "card", "back": "backs/HWATU_BACK", "size": Vector2(78, 124), "title": "화투패 세 장 중 두 장을 뒤집으세요", "item": "패"},
}
const LIFT: float = 16.0

var tool_id: StringName = &""
var _choose: int = 1
var _picks: Array[int] = []
var _items: Array[Control] = []
var _done: bool = false
var _status: Label = null


## 이 도구로 창을 만든다 (부모에 넣기 전에 부른다).
func setup(id: StringName) -> void:
	tool_id = id
	name = "ToolPickModal"
	_choose = ToolPick.choose_of(id)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.name = "PickPanel"
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = Color("131826")
	box_style.border_color = GOLD
	box_style.set_border_width_all(4)
	box_style.set_corner_radius_all(18)
	box_style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", box_style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var look: Dictionary = LOOKS.get(id, LOOKS[&"DICE_TAROT"])
	var title := _label(L10n.t(str(look["title"])), MobileSupport.text_px(22), GOLD)
	title.name = "PickTitle"
	column.add_child(title)
	var row := HBoxContainer.new()
	row.name = "PickRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14 if MobileSupport.touch_mode() else 10)
	column.add_child(row)
	var item_size: Vector2 = look["size"] * (1.25 if MobileSupport.touch_mode() else 1.0)
	for index: int in ToolPick.count_of(id):
		var item := _make_item(look, item_size, index)
		row.add_child(item)
		_items.append(item)
	_status = _label("", MobileSupport.text_px(15), Color("ced4da"))
	_status.name = "PickStatus"
	column.add_child(_status)
	_refresh_status()
	MobileSupport.fit_touch_scale(panel, 1.6)


## 자리 하나를 고른다 (터치·클릭과 테스트가 같은 길을 쓴다). 다 고르면 picked를 낸다.
func pick(index: int) -> void:
	if _done or index < 0 or index >= _items.size():
		return
	if _picks.has(index):
		_picks.erase(index)  # 다시 누르면 고르기 취소
	elif _picks.size() < _choose:
		_picks.append(index)
		Sfx.play(&"card_pick")
	_refresh_items()
	_refresh_status()
	if _picks.size() == _choose:
		_done = true
		var chosen: Array[int] = _picks.duplicate()
		var timer: SceneTreeTimer = get_tree().create_timer(0.28) if is_inside_tree() else null
		if timer == null:
			picked.emit(chosen)
			return
		timer.timeout.connect(func() -> void:
			if is_instance_valid(self):
				picked.emit(chosen))


func picks() -> Array[int]:
	return _picks.duplicate()


func item_count() -> int:
	return _items.size()


func _make_item(look: Dictionary, item_size: Vector2, index: int) -> Control:
	var holder := Control.new()
	holder.name = "PickItem%d" % index
	holder.custom_minimum_size = item_size + Vector2(0, LIFT)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var face := Control.new()
	face.name = "Face"
	face.size = item_size
	face.position = Vector2(0, LIFT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(face)
	var kind: String = str(look["kind"])
	match kind:
		"card":
			face.add_child(_frame(item_size, Color("2b2f3a"), Color("e9ecef"), 8))
			var art := TextureRect.new()
			art.texture = JudgmentCardArt.texture(str(look["back"]))
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			art.position = Vector2(3, 3)
			art.size = item_size - Vector2(6, 6)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			face.add_child(art)
		"tile":
			face.add_child(_frame(item_size, Color("2f9e44"), Color("fff3bf"), 10))
			var inner := _frame(item_size - Vector2(14, 14), Color("37b24d"), Color("d3f9d8"), 7)
			inner.position = Vector2(7, 7)
			face.add_child(inner)
		"stick":
			var wood := _frame(item_size, Color("d9a066"), Color("8c5a2b"), 12)
			face.add_child(wood)
			var tip := _frame(Vector2(item_size.x, item_size.y * 0.18), Color("e03131"), Color("8c5a2b"), 12)
			face.add_child(tip)
		_:
			var art := TextureRect.new()
			art.texture = TextureCache.fetch("res://content_trickcal/illustrations/dice/%s.png" % str(look["icon"]))
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			art.size = item_size
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			face.add_child(art)
	var mark := _frame(item_size + Vector2(8, 8), Color(0, 0, 0, 0), GOLD, 12, 4)
	mark.name = "Mark"
	mark.position = Vector2(-4, -4)
	mark.visible = false
	face.add_child(mark)
	holder.gui_input.connect(func(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT) or (touch != null and touch.pressed):
			holder.accept_event()
			pick(index))
	holder.mouse_entered.connect(func() -> void: _hover(index, true))
	holder.mouse_exited.connect(func() -> void: _hover(index, false))
	return holder


func _hover(index: int, on: bool) -> void:
	if _done or _picks.has(index) or index >= _items.size():
		return
	var face: Control = _items[index].get_node("Face")
	face.position.y = LIFT - (6.0 if on else 0.0)


func _refresh_items() -> void:
	for index: int in _items.size():
		var face: Control = _items[index].get_node("Face")
		var chosen: bool = _picks.has(index)
		face.position.y = 0.0 if chosen else LIFT
		(face.get_node("Mark") as Control).visible = chosen
		face.modulate = Color.WHITE if chosen or _picks.size() < _choose else Color(0.55, 0.55, 0.6)


func _refresh_status() -> void:
	if _status == null:
		return
	var look: Dictionary = LOOKS.get(tool_id, {})
	_status.text = L10n.tf("%d / %d %s 골랐어요", [_picks.size(), _choose, L10n.t(str(look.get("item", "")))])


func _frame(frame_size: Vector2, fill: Color, edge: Color, radius: int, width: int = 3) -> Panel:
	var panel := Panel.new()
	panel.size = frame_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _label(text: String, px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
