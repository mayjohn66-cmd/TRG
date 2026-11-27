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
const INK: Color = Color("1b4d3e")
const PROP = preload("res://scenes/tool_pick_prop.gd")
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
var _motions: Dictionary = {}
var _progress: HBoxContainer
var _touch_mouse_until := 0
var revealing := false

## Reveal the two chosen cards in their original holders; the third stays face down.
func reveal_result(result: Dictionary) -> void:
	revealing=true
	var details: Dictionary=result.get("details",{})
	var values: Array=details.get("cards",[])
	for slot: int in mini(_picks.size(),values.size()):
		var face:=_items[_picks[slot]].get_node("Face") as Control
		var flip:=create_tween()
		flip.tween_property(face,"scale:x",0.0,.13)
		await flip.finished
		for child: Node in face.get_children():
			face.remove_child(child)
			child.queue_free()
		var card:=JudgmentCard.new()
		card.configure(JudgmentCardArt.hwatu(int(values[slot])),face.size)
		card.size=face.size
		face.add_child(card)
		card.set_face_up(true)
		flip=create_tween()
		flip.tween_property(face,"scale:x",1.06,.13)
		Sfx.play(&"card_pick",-7)
		await flip.finished
	_status.text=L10n.t(str(details.get("label","")))+" · "+L10n.tf("%d칸 전진!",[int(result.get("steps",0))])
	await get_tree().create_timer(1.1).timeout


## 이 도구로 창을 만든다 (부모에 넣기 전에 부른다).
func setup(id: StringName) -> void:
	tool_id = id
	name = "ToolPickModal"
	# Board-side roll actions/deck use z=30..40. Keep both the dim and hit
	# blocker above them so the live table cannot cover or steal a selection.
	z_index = JudgmentTableStyle.LAYER
	z_as_relative=false
	_choose = ToolPick.choose_of(id)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = JudgmentTableStyle.DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.name = "PickPanel"
	panel.custom_minimum_size.x=JudgmentTableStyle.WIDTH
	var box_style := JudgmentTableStyle.surface()
	panel.add_theme_stylebox_override("panel", box_style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	panel.add_child(column)
	var look: Dictionary = LOOKS.get(id, LOOKS[&"DICE_TAROT"])
	var title := _label(L10n.t(str(look["title"])),MobileSupport.text_px(20),JudgmentTableStyle.EDGE)
	title.name = "PickTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = 560
	var heading := PanelContainer.new()
	heading.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	heading.add_child(title)
	column.add_child(heading)
	var table := PanelContainer.new()
	table.name = "PickTable"
	table.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	column.add_child(table)
	var row := HBoxContainer.new()
	row.name = "PickRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14 if MobileSupport.touch_mode() else 10)
	table.add_child(row)
	var item_size: Vector2 = look["size"] * (1.25 if MobileSupport.touch_mode() else 1.0)
	for index: int in ToolPick.count_of(id):
		var item := _make_item(look, item_size, index)
		row.add_child(item)
		_items.append(item)
	_progress = HBoxContainer.new()
	_progress.name = "SelectionProgress"
	_progress.alignment = BoxContainer.ALIGNMENT_CENTER
	_progress.add_theme_constant_override("separation",10)
	column.add_child(_progress)
	for slot: int in _choose:
		var chip := _label(str(slot+1),18,Color("747c64"))
		chip.custom_minimum_size = Vector2(32,32)
		chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_theme_stylebox_override("normal",UiSkin.surface(Color("e9f5cf"),Color("bfd598"),1,16))
		_progress.add_child(chip)
	_status = _label("",MobileSupport.text_px(18),JudgmentTableStyle.TEXT)
	_status.name = "PickStatus"
	column.add_child(_status)
	_refresh_status()
	MobileSupport.fit_touch_scale(panel, 1.6)
	ready.connect(_deal,CONNECT_ONE_SHOT)


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
		_refresh_items()
		var chosen: Array[int] = _picks.duplicate()
		var timer: SceneTreeTimer = get_tree().create_timer(0.38) if is_inside_tree() else null
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
	holder.focus_mode = Control.FOCUS_ALL
	var face := Control.new()
	face.name = "Face"
	face.size = item_size
	face.position = Vector2(0, LIFT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.pivot_offset = item_size*0.5
	holder.add_child(face)
	var shadow := _frame(Vector2(item_size.x*0.82,10),Color(0.15,0.25,0.12,0.15),Color.TRANSPARENT,5,0)
	shadow.position = Vector2(item_size.x*0.09,item_size.y+LIFT-2)
	shadow.name = "ContactShadow"
	holder.add_child(shadow)
	holder.move_child(shadow,0)
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
			art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			face.add_child(art)
		"tile":
			face.add_child(_frame(item_size, Color("c5b68b"), Color("786c4c"), 10,2))
			var inner := _frame(item_size - Vector2(4,10),Color("fff4d8"),Color("e8d9ad"),9,2)
			inner.position = Vector2(0,-3)
			face.add_child(inner)
			var back := _frame(item_size-Vector2(14,24),Color("258971"),Color("145b48"),6,2)
			back.position = Vector2(5,4)
			face.add_child(back)
			var inset := _frame(item_size-Vector2(26,38),Color("42a78c"),Color("8bc9a5"),4,1)
			inset.position = Vector2(11,11)
			face.add_child(inset)
		"stick":
			var wood := _frame(Vector2(item_size.x*0.56,item_size.y),Color("eac18e"),Color("946538"),4,2)
			wood.position.x = item_size.x*0.22
			face.add_child(wood)
			var tip := _frame(Vector2(item_size.x*0.56,item_size.y*0.12),Color("ad4843"),Color("813f32"),3,1)
			tip.position.x = item_size.x*0.22
			face.add_child(tip)
			var sheen := _frame(Vector2(3,item_size.y*0.65),Color("f8dfad"),Color.TRANSPARENT,1,0)
			sheen.position = Vector2(item_size.x*0.31,item_size.y*0.22)
			face.add_child(sheen)
		_:
			if PROP.MODELS.has(tool_id):
				var prop := PROP.new()
				prop.name = "SelectionModel"
				prop.setup(tool_id,item_size,index)
				face.add_child(prop)
			else:
				# Reuse the actual roll illustration, including its thin wooden stick.
				var cream := IceCreamView.new()
				cream.name = "SelectionIceCream"
				face.add_child(cream)
				cream.begin({})
				cream.apply_time(0.3)
				cream.scale = Vector2.ONE*(item_size.y/220.0)
				cream.position = Vector2(item_size.x*0.5,0)-Vector2(210,30)*cream.scale
	var mark := _frame(item_size + Vector2(8,8),Color(0,0,0,0),Color("5da530"),12,3)
	mark.name = "Mark"
	mark.position = Vector2(-4, -4)
	mark.visible = false
	face.add_child(mark)
	var order := _label("",18,Color.WHITE)
	order.name = "PickOrder"
	order.size = Vector2(32,32)
	order.position = Vector2(item_size.x-18,-12)
	order.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	order.add_theme_stylebox_override("normal",UiSkin.surface(Color("008f6b"),Color("fff3c7"),2,16))
	order.visible = false
	face.add_child(order)
	holder.gui_input.connect(func(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch != null:
			_touch_mouse_until = Time.get_ticks_msec()+800
		elif click != null and Time.get_ticks_msec()<_touch_mouse_until:
			holder.accept_event()
			return
		if (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT) or (touch != null and touch.pressed):
			holder.accept_event()
			pick(index)
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]:
			holder.accept_event()
			pick(index))
	holder.mouse_entered.connect(func() -> void: _hover(index, true))
	holder.mouse_exited.connect(func() -> void: _hover(index, false))
	holder.focus_entered.connect(func() -> void: _hover(index,true))
	holder.focus_exited.connect(func() -> void: _hover(index,false))
	return holder


func _hover(index: int, on: bool) -> void:
	if _done or _picks.has(index) or index >= _items.size():
		return
	_move(index,LIFT-(8.0 if on else 0.0),1.04 if on else 1.0,Color.WHITE)


func _refresh_items() -> void:
	for index: int in _items.size():
		var face: Control = _items[index].get_node("Face")
		var chosen: bool = _picks.has(index)
		_move(index,0.0 if chosen else LIFT,1.06 if chosen else 1.0,Color.WHITE if not _done or chosen else Color(0.6,0.65,0.6,0.4))
		(face.get_node("Mark") as Control).visible = chosen
		var order: Label = face.get_node("PickOrder")
		order.visible = chosen
		order.text = str(_picks.find(index)+1)


func _refresh_status() -> void:
	if _status == null:
		return
	var look: Dictionary = LOOKS.get(tool_id, {})
	_status.text = L10n.tf("%d / %d %s 골랐어요", [_picks.size(), _choose, L10n.t(str(look.get("item", "")))])
	for index: int in _progress.get_child_count():
		var chip := _progress.get_child(index) as Label
		var filled := index<_picks.size()
		chip.text = "✓" if filled else str(index+1)
		chip.add_theme_color_override("font_color",Color.WHITE if filled else Color("747c64"))
		chip.add_theme_stylebox_override("normal",UiSkin.surface(Color("008f6b") if filled else Color("e9f5cf"),Color("5da530") if filled else Color("bfd598"),1,16))

func _deal() -> void:
	if not _picks.is_empty():
		_refresh_items()
		return
	for index: int in _items.size():
		var face := _items[index].get_node("Face") as Control
		face.position.y = LIFT+26
		face.modulate.a = 0
		var motion := create_tween().set_parallel(true)
		_motions[index] = motion
		motion.tween_property(face,"position:y",LIFT,0.26).set_delay(index*0.035).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		motion.tween_property(face,"modulate:a",1.0,0.18).set_delay(index*0.035)

func _move(index: int, height: float, factor: float, tint: Color) -> void:
	if _motions.has(index): (_motions[index] as Tween).kill()
	var face := _items[index].get_node("Face") as Control
	if not is_inside_tree():
		face.position.y = height
		face.scale = Vector2.ONE*factor
		face.modulate = tint
		return
	var motion := create_tween().set_parallel(true)
	_motions[index] = motion
	motion.tween_property(face,"position:y",height,0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_property(face,"scale",Vector2.ONE*factor,0.16)
	motion.tween_property(face,"modulate",tint,0.16)


func _frame(frame_size: Vector2, fill: Color, edge: Color, radius: int, width: int = 3) -> Panel:
	var panel := Panel.new()
	panel.size = frame_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiSkin.surface(fill,edge,width,radius)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _label(text: String, px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", color)
	if color in [Color.WHITE,JudgmentTableStyle.TEXT,JudgmentTableStyle.EDGE]:
		label.add_theme_color_override("font_outline_color",Color.BLACK)
		label.add_theme_constant_override("outline_size",3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
