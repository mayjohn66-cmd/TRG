## SUPER_06 only: soul ignition and an authoritative boost/overheat result hold.
extends Node2D

const ACTIVATE_TIME := 1.30
const IGNITE_TIME := 0.86
const RESULT_TIME := 1.05
const GOLD := Color("ffd267")
var mode: StringName = &"activate"
var phase: StringName = &"charge"
var elapsed := 0.0
var pace := 1.0
var generation := 0
var player_id := -1
var values: Dictionary = {}
var ignited := false
var _complete := false
var _board_ref: WeakRef
var _target_ref: WeakRef
var _saved_tint := Color.WHITE
var _restored := false
var _anchor := Vector2.ZERO
var _title: Label
var _formula: Label
var _art: Dictionary = {}
var _accent_played := false

func play(board: MainBoard, kind: StringName, owner: int, data: Dictionary, anchor: Vector2, target: Control, speed: float) -> void:
	mode = kind
	name = "GamblerStage" if mode==&"activate" else "GamblerResult"
	z_index = 32
	_board_ref = weakref(board)
	generation = board._fx_generation
	player_id = owner
	values = data.duplicate()
	pace = clampf(speed,0.35,2.0)
	_anchor = board.get_global_transform().affine_inverse()*anchor
	_art = PawnArt.load_sprite(["res://assets/fx/gambler/soul_flame.png"])
	if mode==&"activate":
		board._super_hidden[_key()] = get_instance_id()
		board._refresh_super_marks()
		_title = _label("이동 ×%d" % SuperAugments.gambler_multiplier(),34,GOLD)
		_formula = _label("",22,GOLD)
		Sfx.play(&"charge",-6.0)
	else:
		_title = _label("×%d!" % int(values.get("multiplier",2)) if mode==&"boost" else "과열!",46,GOLD if mode==&"boost" else Color("ff916e"))
		var formula := "%d ×%d → %d" % [int(values["from"]),int(values.multiplier),int(values.to)] if mode==&"boost" and values.has("from") else ("0칸" if mode==&"overheat" else "")
		_formula = _label(formula,26,Color("fff0cc") if mode==&"boost" else Color("d2d0cd"))
		if target!=null:
			_target_ref = weakref(target)
			_saved_tint = target.modulate
			target.set_meta("gambler_tint_owner",get_instance_id())
		Sfx.play(&"charge",-9.0)
	_update_labels(board)

func _key() -> String:
	return "%d:%s" % [player_id,SuperAugments.GAMBLER]

func _label(text: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",tint)
	label.add_theme_color_override("font_outline_color",Color("39210f"))
	label.add_theme_constant_override("outline_size",6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.reset_size()
	label.pivot_offset = label.size/2.0
	return label

func _process(delta: float) -> void:
	if _board_ref==null:
		return
	var board: MainBoard = _board_ref.get_ref()
	if board==null or board._fx_generation!=generation:
		cancel()
		return
	elapsed += delta/pace
	if mode==&"activate":
		phase = &"charge" if elapsed<0.58 else (&"transfer" if elapsed<IGNITE_TIME else &"ignite")
		if elapsed>=IGNITE_TIME and not ignited:
			ignited = true
			_release_mark(board)
			board._refresh_super_marks()
			Sfx.play(&"revenge_ignite",-5.0)
	else:
		phase = &"charge" if elapsed<0.20 else (&"burst" if elapsed<0.42 else &"settle")
		if elapsed>=0.20 and not _accent_played:
			_accent_played = true
			Sfx.play(&"win" if mode==&"boost" else &"bad",-5.0)
		if mode==&"overheat" and _target_ref!=null:
			var target: Control = _target_ref.get_ref()
			if target!=null and _owns_tint(target):
				var tint := _saved_tint.lerp(Color(0.32,0.30,0.29),smoothstep(0.10,0.42,elapsed))
				tint.a = target.modulate.a
				target.modulate = tint
	_update_labels(board)
	queue_redraw()
	if elapsed>=(ACTIVATE_TIME if mode==&"activate" else RESULT_TIME):
		_complete = true
		_restore_target()
		set_process(false)
		if mode!=&"activate":
			queue_free()

func _update_labels(board: MainBoard) -> void:
	var center := board._board_center() if mode==&"activate" else _anchor
	var total := ACTIVATE_TIME if mode==&"activate" else RESULT_TIME
	var alpha := smoothstep(0.0,0.12,elapsed)*(1.0-smoothstep(total-0.20,total,elapsed))
	var pop := 1.0+0.13*sin(clampf((elapsed-0.20)/0.22,0,1)*PI) if mode!=&"activate" else 1.0
	_title.position = center+Vector2(0,-108)-_title.size/2.0
	_title.scale = Vector2.ONE*pop
	_title.modulate.a = alpha
	_formula.position = center+Vector2(0,-68)-_formula.size/2.0
	_formula.modulate.a = alpha*smoothstep(0.20,0.34,elapsed)

func _spirit(at: Vector2, extent: float, alpha: float) -> void:
	if _art.is_empty() or alpha<=0.0:
		return
	var region: Rect2 = _art.region
	var size := region.size*extent/maxf(region.size.x,region.size.y)
	draw_texture_rect_region(_art.texture,Rect2(at-size/2.0,size),region,Color(1,1,1,alpha))

func _ring(at: Vector2, radius: Vector2, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index: int in 49:
		var angle := index*TAU/48.0
		points.append(at+Vector2(cos(angle),sin(angle))*radius)
	draw_polyline(points,color,width,true)

func _draw() -> void:
	if _board_ref==null:
		return
	var board: MainBoard = _board_ref.get_ref()
	if board==null:
		return
	if mode==&"activate":
		var center := board._board_center()+Vector2(0,8)
		var profile := board._profile_center(player_id)
		var target := board.get_global_transform().affine_inverse()*profile if profile.is_finite() else center
		var travel := smoothstep(0.58,IGNITE_TIME,elapsed)
		var at := center.lerp(target,travel)+Vector2(0,-60*sin(travel*PI))
		_spirit(at,lerpf(84,38,travel),smoothstep(0,0.18,elapsed)*(1.0-smoothstep(0.88,1.05,elapsed)))
		_ring(center+Vector2(0,44),Vector2(58,20)*(0.7+0.3*smoothstep(0,0.5,elapsed)),Color(GOLD,(1.0-travel)*0.6),2.0)
		if ignited and profile.is_finite():
			var u := smoothstep(IGNITE_TIME,ACTIVATE_TIME,elapsed)
			_ring(target,Vector2(45,30).lerp(Vector2(145,85),u),Color(GOLD,(1-u)*0.65),3.0)
		return
	var release := smoothstep(0.18,0.38,elapsed)
	var fade := 1.0-smoothstep(RESULT_TIME-0.22,RESULT_TIME,elapsed)
	var base := _anchor+Vector2(0,42)
	_ring(base,Vector2(46+release*28,17+release*9),Color(GOLD if mode==&"boost" else Color("ff684b"),fade*0.7),2.5)
	if mode==&"boost":
		_spirit(_anchor+Vector2(76,-20-7*sin(elapsed*7)),57,fade*release)
		for index: int in 9:
			var t := fposmod(elapsed*1.2+index/9.0,1.0)
			var at := _anchor+Vector2((index%2*2-1)*(40+t*24),22-t*65)
			draw_line(at,at+Vector2(8,-9),Color(GOLD,sin(t*PI)*fade*0.7),2.0,true)
	else:
		for index: int in 6:
			var u := clampf((elapsed-0.20-index*0.035)/0.74,0,1)
			var at := _anchor+Vector2(sin(index*2.5+u*2.0)*(16+u*22),-u*54)
			draw_circle(at,6+u*12,Color(0.23,0.22,0.21,sin(u*PI)*0.25*fade))

func _owns_tint(target: Control) -> bool:
	var owner: Variant = target.get_meta("gambler_tint_owner",null)
	return owner is int and owner==get_instance_id()

func _restore_target() -> void:
	if _restored:
		return
	_restored = true
	var target: Control = _target_ref.get_ref() if _target_ref!=null else null
	if target!=null and _owns_tint(target):
		target.modulate = Color(_saved_tint.r,_saved_tint.g,_saved_tint.b,target.modulate.a)
		target.remove_meta("gambler_tint_owner")
		if target is RollPresenter:
			target._augment_hold = 0.0
			if target._die_label!=null:
				target._die_label.show()

func _release_mark(board: MainBoard) -> void:
	var owner: Variant = board._super_hidden.get(_key())
	if owner is int and owner==get_instance_id():
		board._super_hidden.erase(_key())

func cancel() -> void:
	_complete = true
	_restore_target()
	queue_free()

func _exit_tree() -> void:
	_restore_target()
	var board: MainBoard = _board_ref.get_ref() if _board_ref!=null else null
	if board!=null and mode==&"activate":
		_release_mark(board)
