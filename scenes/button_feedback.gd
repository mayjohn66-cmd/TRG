## Global, event-driven feedback for custom buttons not built by UiSkin.
## Keeps their art, semantic/selection colors, hitboxes and original style margins.
extends Node

class StateStyle extends StyleBox:
	var base: StyleBox
	var normal: StyleBox
	var shade: StyleBoxFlat
	var pressed := false
	var radius := 12

	func _get_minimum_size() -> Vector2:
		return base.get_minimum_size()

	func _get_style_margin(side: Side) -> float:
		var margin:=base.get_margin(side)
		var shift:=minf(2.0,base.get_margin(SIDE_BOTTOM)) if pressed else 0.0
		return margin+shift if side==SIDE_TOP else (margin-shift if side==SIDE_BOTTOM else margin)

	func _draw(canvas: RID, rect: Rect2) -> void:
		base.draw(canvas,rect)
		if rect.size.x>2 and rect.size.y>2: shade.draw(canvas,rect.grow(-1))

class Driver extends Node:
	var button: Button
	var pending := false
	var applying := false
	var original_modulate := Color.WHITE
	var tinted := false

	func _ready() -> void:
		button=get_parent() as Button
		button.theme_changed.connect(schedule)
		button.resized.connect(schedule)
		button.mouse_entered.connect(update_tint)
		button.mouse_exited.connect(update_tint)
		button.button_down.connect(update_tint)
		button.button_up.connect(update_tint)
		button.visibility_changed.connect(update_tint)
		# Disabled/toggle state changes also redraw without mouse movement.
		button.draw.connect(update_tint)
		schedule()

	func schedule() -> void:
		if applying or pending: return
		pending=true
		sync.call_deferred()

	func sync() -> void:
		pending=false
		if not is_instance_valid(button) or not button.is_inside_tree(): return
		var normal:=button.get_theme_stylebox("normal")
		if normal is StyleBoxEmpty:
			update_tint()
			return
		var radius:=roundi(minf(button.size.x,button.size.y)*.25)
		if button.size.x>0 and absf(button.size.x-button.size.y)<button.size.y*.15:
			radius=roundi(button.size.y*.5)
		elif normal is StyleBoxFlat:
			radius=(normal as StyleBoxFlat).corner_radius_top_left
		applying=true
		for state: String in ["hover","pressed","hover_pressed"]:
			var current:=button.get_theme_stylebox(state)
			if current.has_meta("ui_button_feedback"): continue
			if current is StateStyle and current.normal==normal and current.radius==radius: continue
			var base: StyleBox=current.base if current is StateStyle else current
			# An absent hover_pressed uses the button's actual pressed artwork.
			if state=="hover_pressed" and not button.has_theme_stylebox_override(state):
				base=button.get_theme_stylebox("pressed")
				if base is StateStyle: base=base.base
			var wrapper:=StateStyle.new()
			wrapper.base=base
			wrapper.normal=normal
			wrapper.radius=radius
			wrapper.pressed=state!="hover"
			wrapper.shade=StyleBoxFlat.new()
			wrapper.shade.set_corner_radius_all(maxi(0,radius-1))
			wrapper.shade.bg_color=Color(0,0,0,.075) if wrapper.pressed else Color(1,.94,.73,.12)
			if wrapper.pressed:
				wrapper.shade.border_color=Color(0,0,0,.28)
				wrapper.shade.border_width_top=3
				wrapper.shade.border_width_left=2
			button.add_theme_stylebox_override(state,wrapper)
		applying=false
		update_tint()

	## Transparent hit areas paint their real shape in child controls (profile,
	## avatar and illustrated cards). Tint that content instead of drawing a box.
	func update_tint() -> void:
		if not is_instance_valid(button): return
		var active:=button.is_visible_in_tree() and not button.disabled
		var transparent:=button.get_theme_stylebox("normal") is StyleBoxEmpty
		var down:=active and button.is_pressed()
		var hover:=active and button.is_hovered()
		if transparent and (down or hover):
			if not tinted: original_modulate=button.modulate
			tinted=true
			var target:=original_modulate*(Color(.84,.84,.82) if down else Color(1.1,1.08,1.03))
			if button.modulate!=target: button.modulate=target
		elif tinted:
			button.modulate=original_modulate
			tinted=false

func _ready() -> void:
	get_tree().node_added.connect(added)
	visit(get_tree().root)

func visit(node: Node) -> void:
	added(node)
	for child: Node in node.get_children(): visit(child)

func added(node: Node) -> void:
	if not node is Button or node.has_meta("global_button_feedback"): return
	node.set_meta("global_button_feedback",true)
	attach.call_deferred(node)

func attach(button: Button) -> void:
	if not is_instance_valid(button) or not button.is_inside_tree(): return
	var driver:=Driver.new()
	driver.name="ButtonFeedback"
	button.add_child(driver)
