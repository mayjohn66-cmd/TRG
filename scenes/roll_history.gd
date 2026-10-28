## Public, already-revealed outcomes for the current tool/turn only.
class_name RollHistory
extends PanelContainer

const TRACKED: Array[StringName] = [&"YUT",&"REVOLVER",&"LIFE_ROULETTE",&"DICE_HWATU",&"DICE_MAHJONG",&"DICE_TAROT",&"DICE_YACHT",&"DICE_BLACKJACK"]
const WIDTH := 194.0
const MAX_VISIBLE := 6
const GOOD := Color("326d42")
const AGAIN := Color("8a5d12")
const BAD := Color("aa303f")

var turn_id := -1
var player_id := -1
var tool_id: StringName = &""
var entries: Array[Dictionary] = []
var last_result: Dictionary = {}
var _header: Label
var _rows: HFlowContainer
var _footer: Label
var _wide := false

func _ready() -> void:
	name = "RollHistory"
	z_index = 12
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel",UiSkin.panel("panel",10))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation",6)
	add_child(column)
	_header = _label(17,UiSkin.SOFT)
	column.add_child(_header)
	_rows = HFlowContainer.new()
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_theme_constant_override("h_separation",8)
	_rows.add_theme_constant_override("v_separation",3)
	column.add_child(_rows)
	_footer = _label(19,UiSkin.INK)
	column.add_child(_footer)
	set_width(WIDTH)
	hide()

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
	if not confirm or entries.is_empty():
		entries.append({"text":_outcome(result),"tone":BAD if bool(result.get("ends_turn",false)) else (AGAIN if bool(result.get("reroll",false)) else GOOD),"success":tool_id==&"REVOLVER" and not bool(details.get("fired",false))})
	last_result = result.duplicate(true)
	_refresh()
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

func _refresh() -> void:
	for row: Node in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	var heading := L10n.tf("%d회 굴림",[entries.size()])
	if tool_id==&"REVOLVER": heading = L10n.tf("%d회 성공",[entries.filter(func(item: Dictionary) -> bool: return item.success).size()])
	_header.text = "P%d · %s" % [player_id,heading]
	for index: int in range(maxi(0,entries.size()-MAX_VISIBLE),entries.size()):
		var row := _label(24,entries[index].tone)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.max_lines_visible = 2
		row.text = "%d  %s" % [index+1,L10n.t(entries[index].text)]
		_rows.add_child(row)
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
		row.custom_minimum_size = Vector2(floorf((width-20.0-16.0)/3.0) if _wide else width-20.0,28)
	reset_size()
