## Public, already-revealed outcomes for the current tool/turn only.
class_name RollHistory
extends PanelContainer

const TRACKED: Array[StringName] = [&"YUT",&"REVOLVER",&"LIFE_ROULETTE",&"DICE_HWATU",&"DICE_MAHJONG",&"DICE_TAROT",&"DICE_YACHT",&"DICE_BLACKJACK"]
const WIDTH := 194.0
const MAX_VISIBLE := 6
const GOOD := Color("326d42")
const AGAIN := Color("8a5d12")
const BAD := Color("aa303f")
const PLAQUE_PATH := "res://assets/ui/trickcal/roll_history_v01/result_plaque.webp"
static var _plaque_texture: Texture2D

var turn_id := -1
var player_id := -1
var tool_id: StringName = &""
var entries: Array[Dictionary] = []
var last_result: Dictionary = {}
var _header: Label
var _rows: HFlowContainer
var _footer: Label
var _tool_icon: TextureRect
var _wide := false

func _ready() -> void:
	name = "RollHistory"
	z_index = 12
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation",4)
	add_child(column)
	var heading := HBoxContainer.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_theme_constant_override("separation",5)
	column.add_child(heading)
	_tool_icon = TextureRect.new()
	_tool_icon.custom_minimum_size = Vector2(28,28)
	_tool_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tool_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tool_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_edge := ShaderMaterial.new()
	icon_edge.shader = load("res://scenes/ui_art_edge.gdshader")
	icon_edge.set_shader_parameter("frame_size",Vector2(28,28))
	icon_edge.set_shader_parameter("edge_inset",0.5)
	_tool_icon.material = icon_edge
	heading.add_child(_tool_icon)
	_header = _label(17,UiSkin.INK)
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_theme_color_override("font_outline_color",Color("fff8df"))
	_header.add_theme_constant_override("outline_size",2)
	heading.add_child(_header)
	_rows = HFlowContainer.new()
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_theme_constant_override("h_separation",8)
	_rows.add_theme_constant_override("v_separation",3)
	column.add_child(_rows)
	_footer = _label(19,UiSkin.INK)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.add_theme_stylebox_override("normal",_plaque_style(Color.WHITE))
	column.add_child(_footer)
	set_width(WIDTH)
	hide()

## The generated source stays intact; crop transparent padding only for runtime nine-slicing.
static func _plaque_style(tint: Color) -> StyleBoxTexture:
	if _plaque_texture==null:
		var source: Texture2D = load(PLAQUE_PATH)
		var source_scale := source.get_size()/Vector2(2100,749)
		var crop := Rect2i((Vector2(9,167)*source_scale).floor(),(Vector2(2080,412)*source_scale).ceil())
		var pixels := source.get_image().get_region(crop)
		pixels.resize(323,64,Image.INTERPOLATE_LANCZOS)
		_plaque_texture = ImageTexture.create_from_image(pixels)
	var box := StyleBoxTexture.new()
	box.texture = _plaque_texture
	box.set_texture_margin_all(9)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	box.modulate_color = tint
	return box

func _label(px: int, tone: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",px)
	label.add_theme_color_override("font_color",tone)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label

func clear() -> void:
	entries.clear()
	last_result.clear()
	turn_id = -1
	player_id = -1
	tool_id = &""
	if _rows != null:
		for row: Node in _rows.get_children():
			_rows.remove_child(row)
			row.queue_free()
	hide()

func arm(turn: int, player: int, tool: StringName) -> void:
	if turn_id==turn and player_id==player and tool_id==tool: return
	clear()
	turn_id = turn
	player_id = player
	tool_id = tool

func reveal(turn: int, player: int, result: Dictionary) -> void:
	if turn!=turn_id or player!=player_id or result.get("tool_id",&"")!=tool_id: return
	if not TRACKED.has(tool_id) and entries.is_empty() and not bool(result.get("reroll",false)) and not bool(result.get("ends_turn",false)) and not bool(result.get("can_continue",false)): return
	var details: Dictionary = result.get("details",{})
	var confirm := bool(details.get("voluntary",false))
	if tool_id==&"DICE_YACHT" and bool(details.get("confirmed",false)) and (details.get("rolled",[]) as Array).is_empty(): confirm = true
	if tool_id==&"DICE_BLACKJACK" and bool(details.get("confirmed",false)) and not bool(details.get("bust",false)) and not bool(details.get("blackjack",false)) and (details.get("new_cards",[]) as Array).is_empty(): confirm = true
	var appended := not confirm or entries.is_empty()
	if appended:
		entries.append({"text":_outcome(result),"tone":BAD if bool(result.get("ends_turn",false)) else (AGAIN if bool(result.get("reroll",false)) else GOOD),"success":tool_id==&"REVOLVER" and not bool(details.get("fired",false))})
	last_result = result.duplicate(true)
	# Blackjack already shows current hand, count and total in its fixed-size stage.
	if tool_id==&"DICE_BLACKJACK":
		hide()
		return
	_refresh(appended)
	show()

func _outcome(result: Dictionary) -> String:
	var details: Dictionary = result.get("details",{})
	match tool_id:
		&"YUT": return str(RollPresenter.YUT_NAMES.get(int(details.get("face",result.get("steps",0))),"?"))
		&"REVOLVER": return "실패" if bool(details.get("fired",false)) else "성공"
		&"DICE_BLACKJACK": return "BUST" if bool(details.get("bust",false)) else ("블랙잭" if bool(details.get("blackjack",false)) else L10n.tf("합계 %d",[int(details.get("total",0))]))
		&"DICE_TAROT": return str(details.get("name","광대"))
		&"DICE_YACHT",&"DICE_MAHJONG",&"DICE_HWATU": return str(details.get("label","?"))
	return L10n.tf("%d칸",[int(result.get("steps",0))])

func _refresh(animate_latest: bool = false) -> void:
	for row: Node in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	var heading := L10n.tf("%d회 굴림",[entries.size()])
	if tool_id==&"REVOLVER": heading = L10n.tf("%d회 성공",[entries.filter(func(item: Dictionary) -> bool: return item.success).size()])
	_header.text = "P%d · %s" % [player_id,heading]
	_tool_icon.texture = AugmentArt.load_first(AugmentArt.tool_candidates(tool_id))
	for index: int in range(maxi(0,entries.size()-MAX_VISIBLE),entries.size()):
		var latest := index==entries.size()-1
		var row := _label(24,entries[index].tone)
		var tint := Color.WHITE
		if latest:
			tint = Color("ffd6ca") if entries[index].tone==BAD else (Color("fff0bb") if entries[index].tone==AGAIN else Color("e0f0cf"))
		row.add_theme_stylebox_override("normal",_plaque_style(tint))
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.max_lines_visible = 2
		row.text = "%d  %s" % [index+1,L10n.t(entries[index].text)]
		_rows.add_child(row)
		if latest and animate_latest:
			row.modulate.a = 0.25
			row.scale = Vector2(0.94,0.94)
			var attach := row.create_tween().set_parallel()
			attach.tween_property(row,"modulate:a",1.0,0.15)
			attach.tween_property(row,"scale",Vector2.ONE,0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if bool(last_result.get("ends_turn",false)):
		_footer.text = L10n.t("턴 종료")
	elif bool(last_result.get("reroll",false)):
		_footer.text = L10n.t("한 번 더")
	elif bool(last_result.get("can_continue",false)):
		_footer.text = L10n.tf("%d칸 누적",[int(last_result.get("steps",0))]) if tool_id==&"REVOLVER" else L10n.t("계속 도전 가능")
	else:
		_footer.text = L10n.tf("%d칸 확정",[int(last_result.get("steps",0))])
	_footer.add_theme_color_override("font_color",BAD if bool(last_result.get("ends_turn",false)) else UiSkin.INK)
	set_width(custom_minimum_size.x,true)
	reset_size()

func set_width(width: float, force: bool = false) -> void:
	if not force and is_equal_approx(custom_minimum_size.x,width): return
	_wide = width>WIDTH+1.0
	custom_minimum_size.x = width
	size.x = width
	if _rows == null: return
	for row: Control in _rows.get_children():
		row.custom_minimum_size = Vector2(floorf((width-16.0)/3.0) if _wide else width,34)
	reset_size()
