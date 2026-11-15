## Centered square choice panel. Values remain opaque to the UI.
extends Control
signal selected(value: Variant)
signal canceled

var board: MainBoard
var heading := ""
var options: Array[Dictionary] = []
var columns_hint := 1
var panel: Panel
var title_label: Label
var scroll: ScrollContainer
var content: Control
var grid: GridContainer
var cancel_button: Button
var cards: Array[Dictionary] = []
var committed := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.name = "ChoiceDim"
	dim.color = Color(0,0,0,0.48)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = Panel.new()
	panel.name = "ChoicePanel"
	panel.add_theme_stylebox_override("panel",board._style(Color("182235"),Color("ffdb79"),3,18,8,0))
	add_child(panel)
	title_label = board._make_label(heading,24,Color("ffdf85"))
	title_label.name = "ChoiceTitle"
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.max_lines_visible = 2
	title_label.clip_text = true
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(title_label)
	scroll = ScrollContainer.new()
	scroll.name = "ChoiceScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	panel.add_child(scroll)
	content = Control.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	grid = GridContainer.new()
	grid.name = "ChoiceGrid"
	content.add_child(grid)
	for i: int in options.size():
		var option: Dictionary = options[i]
		var button: Button = board._make_button(str(option["label"]),pick.bind(i),20)
		button.name = "Choice_"+str(i)
		button.clip_text = true
		button.focus_mode = Control.FOCUS_ALL
		button.disabled = bool(option.get("disabled",false))
		if button.disabled:
			button.add_theme_stylebox_override("disabled",board._style(Color("d8d6c4"),Color("858f8d"),2,18,8,0))
		button.tooltip_text = str(option["label"])
		# Keep the complete accessible/button text while wrapped labels render it.
		for key: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color","font_outline_color"]:
			button.add_theme_color_override(key,Color.TRANSPARENT)
		button.add_theme_constant_override("outline_size",0)
		grid.add_child(button)
		var portrait := Panel.new()
		portrait.name = "PortraitMask"
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		button.add_child(portrait)
		var face := TextureRect.new()
		face.texture = option.get("portrait",null)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.visible = face.texture != null
		var pawn: PlayerPawn = option.get("pawn",null)
		portrait.visible = face.visible or pawn != null
		portrait.add_child(face)
		face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var token: PawnToken = null
		if pawn != null:
			token = board._token_in(portrait,pawn,MainBoard.PLAYER_COLORS[pawn.owner_id],Vector2.ZERO,1.0)
		var label := board._make_label(str(option.get("name",option["label"])),22,UiSkin.INK)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.max_lines_visible = 2 if portrait.visible else 4
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.clip_text = true
		button.add_child(label)
		var detail := board._make_label(str(option.get("detail","")),15,Color("526374"))
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		detail.clip_text = true
		detail.visible = not detail.text.is_empty()
		button.add_child(detail)
		cards.append({"button":button,"face":face,"portrait":portrait,"token":token,"label":label,"detail":detail})
	cancel_button = board._make_button(L10n.tr_ui("btn.cancel"),cancel,20)
	cancel_button.name = "ChoiceCancel"
	panel.add_child(cancel_button)
	get_viewport().size_changed.connect(fit_window)
	fit_window()
	fit_window.call_deferred() # Container/text minimum sizes settle after first layout.
	for entry: Dictionary in cards:
		if not (entry["button"] as Button).disabled:
			(entry["button"] as Button).grab_focus.call_deferred()
			break

func pick(index: int) -> void:
	if committed or bool(options[index].get("disabled",false)): return
	committed = true
	selected.emit(options[index]["value"])

func cancel() -> void:
	if committed: return
	committed = true
	canceled.emit()

func fit_window() -> void:
	var view: Vector2 = get_viewport_rect().size
	var pixels: Vector2 = Vector2(get_window().size)
	var units: float = view.x/maxf(pixels.x,1.0)
	var side_px: float = maxf(200.0,minf(560.0,minf(pixels.x-32,pixels.y-32)))
	var side: float = side_px*units
	var large: bool = side_px >= 480.0
	var pad: float = (16.0 if large else 12.0)*units
	var gap: float = (12.0 if large else 10.0)*units
	var head: float = (64.0 if large else 52.0)*units
	var footer: float = (48.0 if large else 44.0)*units
	panel.size = Vector2.ONE*side
	panel.position = (view-panel.size)*0.5
	title_label.position = Vector2(pad,pad)
	title_label.add_theme_font_size_override("font_size",roundi((24.0 if large else 18.0)*units))
	title_label.size = Vector2(side-2*pad,head)
	scroll.position = Vector2(pad,pad+head+gap)
	scroll.size = Vector2(side-2*pad,side-2*pad-head-footer-2*gap)
	var cols: int = mini(maxi(options.size(),1),3 if columns_hint >= 3 else 2)
	var rows: int = ceili(float(options.size())/cols)
	var shown_rows: int = clampi(rows,1,2)
	var cell: float = minf((scroll.size.x-16*units-(cols-1)*gap)/cols,(scroll.size.y-(shown_rows-1)*gap)/shown_rows)
	grid.columns = cols
	grid.add_theme_constant_override("h_separation",roundi(gap))
	grid.add_theme_constant_override("v_separation",roundi(gap))
	var grid_width: float = cols*cell+(cols-1)*gap
	var row_offset: float = maxf(0.0, (scroll.size.y - cell) * 0.5) if rows == 1 else 0.0
	grid.position = Vector2(maxf(0.0, (scroll.size.x - grid_width) * 0.5), row_offset)
	grid.size = Vector2(grid_width,maxi(rows,1)*cell+maxi(rows-1,0)*gap)
	content.custom_minimum_size = Vector2(0, grid.size.y + row_offset)
	for entry: Dictionary in cards:
		var button: Button = entry["button"]
		button.custom_minimum_size = Vector2.ONE*cell
		var face: TextureRect = entry["face"]
		var portrait: Panel = entry["portrait"]
		var label: Label = entry["label"]
		var detail: Label = entry["detail"]
		var inset: float = (8.0 if large else 6.0)*units
		var label_font: int = roundi((22.0 if large else (14.0 if detail.visible else 16.0))*units)
		label.add_theme_font_size_override("font_size",label_font)
		detail.add_theme_font_size_override("font_size",roundi((15.0 if large else 12.0)*units))
		detail.max_lines_visible = 3 if large else 2
		var detail_lines: int = mini(3,detail.text.count("\n")+1)
		var detail_height: float = ((22.0 if large else 17.0)*detail_lines+4.0)*units if detail.visible else 0.0
		var top: float = inset
		var name_height: float = cell-2*inset-detail_height
		if portrait.visible:
			# Center the portrait/name as one compact group, rather than pinning a
			# tiny face to the top and centering the name in all remaining space.
			var lines: int = 2 if label.text.length()>8 else 1
			name_height = label_font*1.4*lines
			var face_gap: float = (9.0 if large else 5.0)*units
			var detail_gap: float = 3.0*units if detail.visible else 0.0
			var face_side: float = minf(cell*0.48,cell-2*inset-name_height-detail_height-face_gap-detail_gap)
			var group_height: float = face_side+face_gap+name_height+detail_gap+detail_height
			portrait.position = Vector2((cell-face_side)/2,(cell-group_height)/2)
			portrait.size = Vector2.ONE*face_side
			var frame := StyleBoxFlat.new()
			frame.bg_color = Color("fff6d3")
			frame.set_corner_radius_all(roundi(face_side*0.24))
			frame.anti_aliasing = true
			portrait.add_theme_stylebox_override("panel",frame)
			var token: PawnToken = entry["token"]
			if token != null:
				token.position = Vector2(face_side*0.5,face_side*0.80)
				token.scale = Vector2.ONE*face_side/52.0
			top = portrait.position.y+face_side+face_gap
		label.position = Vector2(inset,top)
		label.size = Vector2(cell-2*inset,name_height)
		detail.position = Vector2(inset,top+name_height+(3.0*units if portrait.visible and detail.visible else 0.0))
		detail.size = Vector2(cell-2*inset,detail_height)
	cancel_button.position = Vector2(pad,side-pad-footer)
	cancel_button.size = Vector2(side-2*pad,footer)
	cancel_button.add_theme_font_size_override("font_size",roundi(20*units))
