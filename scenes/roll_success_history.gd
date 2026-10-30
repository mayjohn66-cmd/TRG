## Success presentation layered on the existing public-outcome history.
class_name RollSuccessHistory
extends "res://scenes/roll_history.gd"

var success_count := 0
var _success: RollSuccessDisplay

func _ready() -> void:
	super._ready()
	_success = RollSuccessDisplay.new()
	var column: Node = _rows.get_parent()
	column.add_child(_success)
	column.move_child(_success,_rows.get_index()+1)
	_success.hide()

func clear() -> void:
	super.clear()
	success_count = 0
	if _success != null: _success.clear()

func arm(turn: int, player: int, tool: StringName) -> void:
	super.arm(turn,player,tool)
	if _success != null: _success.configure(tool)


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
	# Reroll awards can arrive on a Yacht confirmation without appending a row.
	var award := _is_success(result,confirm)
	if award: success_count += 1
	last_result = result.duplicate(true)
	_refresh(award if RollSuccessDisplay.supports(tool_id) else appended)
	# Blackjack draws stay in its compact hand; only a 21 earns a trophy.
	visible = not RollSuccessDisplay.supports(tool_id) or success_count>0 or bool(result.get("ends_turn",false))

func _is_success(result: Dictionary, confirmation: bool) -> bool:
	if not RollSuccessDisplay.supports(tool_id) or bool(result.get("ends_turn",false)): return false
	var details: Dictionary = result.get("details",{})
	if tool_id == &"REVOLVER":
		return not confirmation and not bool(details.get("fired",false))
	return bool(result.get("reroll",false))

func uses_success_markers() -> bool:
	return RollSuccessDisplay.supports(tool_id)

func _refresh(animate_latest: bool = false) -> void:
	for row: Node in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	var heading := L10n.tf("%d회 굴림",[entries.size()])
	if uses_success_markers(): heading = L10n.tf("%d회 성공",[success_count])
	_header.text = "P%d" % player_id if tool_id==&"REVOLVER" else "P%d · %s" % [player_id,heading]
	_tool_icon.texture = AugmentArt.load_first(AugmentArt.tool_candidates(tool_id))
	_rows.visible = not uses_success_markers()
	_success.visible = uses_success_markers() and success_count>0
	if uses_success_markers(): _success.set_count(success_count,animate_latest)
	if tool_id==&"REVOLVER": _success.set_revolver_amount(int(last_result.get("steps",0)),animate_latest)
	for index: int in range(maxi(0,entries.size()-MAX_VISIBLE),entries.size()) if not uses_success_markers() else []:
		var latest := index==entries.size()-1
		var row := _label(24,entries[index].tone)
		var tint := Color.WHITE
		if latest:
			tint = Color("ffd6ca") if entries[index].tone==BAD else (Color("fff0bb") if entries[index].tone==AGAIN else Color("e0f0cf"))
		row.add_theme_stylebox_override("normal",_plaque_style(tint))
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.max_lines_visible = 2
		var ink_stamp := tool_id==&"YUT" and str(entries[index].text) in ["윷","모"]
		if ink_stamp:
			row.set_meta("ink_stamp",true)
			row.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
			row.add_theme_font_size_override("font_size",42)
			row.add_theme_color_override("font_color",Color("ad3445") if str(entries[index].text)=="윷" else Color("337354"))
			row.clip_text = false
			row.autowrap_mode = TextServer.AUTOWRAP_OFF
			row.text = L10n.t(entries[index].text)
			row.rotation = deg_to_rad(-7.0 if str(entries[index].text)=="윷" else 5.0)
			var ink := ShaderMaterial.new()
			ink.shader = preload("res://scenes/roll_ink.gdshader")
			row.material = ink
		else:
			row.text = "%d  %s" % [index+1,L10n.t(entries[index].text)]
		_rows.add_child(row)
		if latest and animate_latest:
			row.modulate.a = 0.25
			row.scale = Vector2(1.8,1.8) if ink_stamp else Vector2(0.94,0.94)
			var attach := row.create_tween().set_parallel()
			attach.tween_property(row,"modulate:a",1.0,0.15)
			if ink_stamp:
				var slam := row.create_tween()
				slam.tween_property(row,"scale",Vector2(0.9,0.9),0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				slam.tween_property(row,"scale",Vector2.ONE,0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			else:
				attach.tween_property(row,"scale",Vector2.ONE,0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if bool(last_result.get("ends_turn",false)):
		_footer.text = L10n.t("턴 종료")
	elif bool(last_result.get("reroll",false)):
		_footer.text = ""
	elif bool(last_result.get("can_continue",false)):
		_footer.text = L10n.tf("%d칸 누적",[int(last_result.get("steps",0))]) if tool_id==&"REVOLVER" else L10n.t("계속 도전 가능")
	else:
		_footer.text = L10n.tf("%d칸 확정",[int(last_result.get("steps",0))])
	_footer.visible = not bool(last_result.get("reroll",false)) and not (tool_id==&"REVOLVER" and bool(last_result.get("can_continue",false)))
	_footer.add_theme_color_override("font_color",BAD if bool(last_result.get("ends_turn",false)) else UiSkin.INK)
	set_width(custom_minimum_size.x,true)
	reset_size()

func set_width(width: float, force: bool = false) -> void:
	super.set_width(width,force)
	if _rows == null: return
	for row: Control in _rows.get_children():
		if row.has_meta("ink_stamp"):
			row.custom_minimum_size = Vector2(floorf((width-16.0)/3.0),52)
			row.pivot_offset = row.custom_minimum_size*0.5
			var font := row.get_theme_font("font")
			var glyph_width := font.get_string_size(row.text,HORIZONTAL_ALIGNMENT_LEFT,-1,42).x
			row.add_theme_font_size_override("font_size",mini(42,int(42.0*(row.custom_minimum_size.x-4.0)/maxf(glyph_width,1.0))))
		else:
			row.custom_minimum_size = Vector2(floorf((width-16.0)/3.0) if _wide else width,34)
	reset_size()
