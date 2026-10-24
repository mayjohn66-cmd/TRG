## SUPER_03 visuals only. The engine has already reset the offering and awarded +N.
extends Node2D

const OFFER_END := 0.68
const CONSUME_END := 1.38
const ARRIVAL := 2.02
const TOTAL_TIME := 2.78
const CRIMSON := Color("f04465")
const VIOLET := Color("b467ee")
var elapsed := 0.0
var pace := 1.0
var phase: StringName = &"offering"
var player_id := -1
var pawn_id := -1
var ignited := false
var _complete := false
var _board_ref: WeakRef
var _view_ref: WeakRef
var _generation := 0
var _saved: Dictionary = {}
var _rest: Dictionary = {}
var _origin := Vector2.ZERO
var _goal := Vector2.ZERO
var _target := Vector2.ZERO
var _seal: Label
var _bonus: Label
var _last_phase: StringName = &""

func play(board: MainBoard, owner: int, offering: int, speed: float, result: Dictionary = {}) -> void:
	name = "DevilContractStage"
	z_index = 16
	_board_ref = weakref(board)
	_generation = board._fx_generation
	player_id = owner
	pawn_id = offering
	pace = clampf(speed,0.35,2.0)
	_rest = result
	var view: Node2D = board._pawn_views[pawn_id]
	board._kill_fx(view)
	_view_ref = weakref(view)
	_saved = {"z":view.z_index,"scale":view.scale,"rotation":view.rotation,"modulate":view.modulate}
	view.z_index = 18
	board._super_hidden[_hidden_key()] = get_instance_id()
	board._refresh_super_marks()
	_seal = _label("계약 성립",29,Color("ffd5b6"))
	_bonus = _label("영구 가속 +%d" % SuperAugments.devil_bonus(),24,Color("ffb1c4"))
	_update_pose(board)

func _hidden_key() -> String:
	return "%d:%s" % [player_id,SuperAugments.DEVIL]

func _label(text: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",tint)
	label.add_theme_color_override("font_outline_color",Color("310e26"))
	label.add_theme_constant_override("outline_size",6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 5
	add_child(label)
	label.reset_size()
	label.pivot_offset = label.size/2.0
	return label

func _process(delta: float) -> void:
	if _board_ref==null:
		return
	var board: MainBoard = _board_ref.get_ref()
	if board==null or board._fx_generation!=_generation:
		queue_free()
		return
	elapsed += delta/pace
	phase = &"offering" if elapsed<OFFER_END else (&"consume" if elapsed<CONSUME_END else (&"transfer" if elapsed<ARRIVAL else &"ignite"))
	if phase!=_last_phase:
		_last_phase = phase
		match phase:
			&"offering": Sfx.play(&"charge",-6.0)
			&"consume": Sfx.play(&"revenge_ignite",-5.0)
			&"transfer": Sfx.play(&"warp",-7.0)
			&"ignite":
				ignited = true
				_release_mark(board)
				board._refresh_super_marks()
				Sfx.play(&"skill_ult",-5.0)
	_update_pose(board)
	queue_redraw()
	if elapsed>=TOTAL_TIME:
		_complete = true
		set_process(false)

func _update_pose(board: MainBoard) -> void:
	_origin = board._board_center()+Vector2(0,35)
	_goal = board._pawn_layer.transform*(board._tile_center(GameEnums.GOAL_TILE)+Vector2(0,38))
	var profile := board._profile_center(player_id)
	_target = board.get_global_transform().affine_inverse()*profile if profile.is_finite() else _origin+Vector2(140,0)
	var view: Node2D = _view_ref.get_ref()
	if view!=null:
		var offering := smoothstep(0.05,OFFER_END,elapsed)
		var consume := smoothstep(OFFER_END+0.12,CONSUME_END,elapsed)
		var position_on_board := _goal.lerp(_origin+Vector2(0,-38),offering)+Vector2(0,-44*sin(offering*PI))
		position_on_board = position_on_board.lerp(_origin+Vector2(0,9),consume)
		view.position = board._pawn_layer.transform.affine_inverse()*position_on_board
		view.visible = elapsed<CONSUME_END
		view.scale = (_saved.scale as Vector2)*Vector2(1.0-0.88*consume,1.0+0.24*sin(consume*PI)-0.88*consume)
		view.rotation = -0.12*sin(offering*PI)+0.18*sin(consume*PI)
		view.modulate = Color.WHITE.lerp(Color(1.5,0.32,0.58),consume)
		view.modulate.a = smoothstep(0.0,0.10,elapsed)*(1.0-smoothstep(0.72,1.0,consume))
	var sealed := smoothstep(CONSUME_END,CONSUME_END+0.14,elapsed)
	var fade := 1.0-smoothstep(TOTAL_TIME-0.25,TOTAL_TIME,elapsed)
	_seal.position = _origin+Vector2(0,-120)-_seal.size/2.0
	_seal.scale = Vector2.ONE*(1.0+0.18*(1.0-sealed))
	_seal.modulate.a = sealed*fade
	_bonus.position = _target+Vector2(0,-94)-_bonus.size/2.0
	_bonus.modulate.a = smoothstep(ARRIVAL,ARRIVAL+0.13,elapsed)*fade

func _ellipse(at: Vector2, radius: Vector2, color: Color, width: float = 2.0, angle: float = 0.0) -> void:
	var points := PackedVector2Array()
	for index: int in 65:
		var a := float(index)/64.0*TAU+angle
		points.append(at+Vector2(cos(a),sin(a))*radius)
	draw_polyline(points,color,width,true)

func _draw() -> void:
	if _board_ref==null:
		return
	var board: MainBoard = _board_ref.get_ref()
	if board==null:
		return
	var fade := 1.0-smoothstep(ARRIVAL,TOTAL_TIME,elapsed)
	var open := smoothstep(0.0,0.32,elapsed)*fade
	draw_rect(Rect2(Vector2.ZERO,board.size),Color(0.06,0.01,0.09,0.46*open))
	# An ellipse anchors the seal to the board surface instead of a flat UI circle.
	for index: int in range(6,0,-1):
		_ellipse(_origin,Vector2(67+index*3,26+index),Color(0.68,0.12,0.34,0.035*open),float(index*3))
	draw_set_transform(_origin,0,Vector2(1,0.4))
	draw_circle(Vector2.ZERO,67,Color(0.10,0.025,0.13,0.93*open))
	draw_set_transform(Vector2.ZERO)
	_ellipse(_origin,Vector2(70,28),Color(CRIMSON,open),3.0)
	_ellipse(_origin,Vector2(56,22.4),Color(VIOLET,open*0.8),1.4)
	var star := PackedVector2Array()
	for index: int in 6:
		var angle := -PI/2.0+index*TAU*2.0/5.0+elapsed*0.18
		star.append(_origin+Vector2(cos(angle)*49,sin(angle)*19.6))
	draw_polyline(star,Color(CRIMSON,open*0.55),1.4,true)
	for index: int in 10:
		var angle := index*TAU/10.0-elapsed*0.35
		var point := _origin+Vector2(cos(angle)*62,sin(angle)*24.8)
		draw_line(point,point+Vector2(cos(angle)*5,sin(angle)*2),Color(1,0.70,0.64,open),2.0,true)
	# Restrained embers rise into the offering, with no simulation RNG.
	for index: int in 12:
		var t := fposmod(elapsed*0.75+index/12.0,1.0)
		var angle := index*2.4+elapsed*1.4
		var point := _origin+Vector2(cos(angle)*60*(1-t),-t*100+sin(angle)*16*(1-t))
		draw_circle(point,1.3+1.3*sin(t*PI),Color(VIOLET.lerp(CRIMSON,t),sin(t*PI)*open))
	var scroll_alpha := smoothstep(0.36,OFFER_END,elapsed)*fade
	_draw_contract(_origin+Vector2(91,-61),scroll_alpha)
	if elapsed>=CONSUME_END and elapsed<ARRIVAL:
		for index: int in 22:
			var u := clampf((elapsed-CONSUME_END)/(ARRIVAL-CONSUME_END)-index*0.012,0.0,1.0)
			var at := _energy_position(smoothstep(0.0,1.0,u))
			var alpha := (1.0-index/22.0)*smoothstep(0.0,0.12,u)
			draw_circle(at,9.0*(1.0-index/25.0),Color(CRIMSON.lerp(VIOLET,index/22.0),alpha*0.65))
			draw_circle(at,2.7,Color(1,0.87,0.72,alpha))
	if ignited:
		var u := clampf((elapsed-ARRIVAL)/0.48,0,1)
		_ellipse(_target,Vector2(42,28).lerp(Vector2(143,95),u),Color(CRIMSON,(1-u)*0.9),3*(1-u)+1)
		for index: int in 9:
			var direction := Vector2.from_angle(index*TAU/9.0-PI/2)
			draw_line(_target+direction*(28+u*52),_target+direction*(40+u*70),Color(VIOLET,(1-u)*0.8),3.0,true)

func _energy_position(u: float) -> Vector2:
	var source := _origin+Vector2(0,-18)
	var bend := (source+_target)/2.0+Vector2(0,-125)
	return source.lerp(bend,u).lerp(bend.lerp(_target,u),u)

func _draw_contract(at: Vector2, alpha: float) -> void:
	draw_set_transform(at,-0.10)
	var paper := Rect2(-29,-42,58,82)
	draw_rect(paper.grow(2),Color(0.26,0.12,0.08,alpha))
	draw_rect(paper,Color(1.0,0.84,0.60,alpha))
	for y: float in [-42.0,40.0]:
		draw_line(Vector2(-33,y+3),Vector2(33,y+3),Color(0.45,0.23,0.12,alpha),9,true)
		draw_line(Vector2(-33,y),Vector2(33,y),Color(1,0.76,0.44,alpha),7,true)
	for y: float in [-25.0,-17.0,-9.0]:
		draw_line(Vector2(-18,y),Vector2(18 if y!=-17.0 else 7,y),Color(0.45,0.24,0.18,alpha*0.65),2,true)
	var seal := smoothstep(CONSUME_END-0.12,CONSUME_END+0.08,elapsed)
	var s := 1.0+0.8*(1-seal)
	draw_set_transform(at+Vector2(0,17),-0.10,Vector2.ONE*s)
	draw_circle(Vector2.ZERO,15,Color(0.50,0.035,0.12,alpha*seal))
	draw_circle(Vector2(0,-1),11,Color(CRIMSON,alpha*seal))
	for side: float in [-1.0,1.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(side*5,-6),Vector2(side*10,-15),Vector2(side*11,-3)]),Color(CRIMSON,alpha*seal))
		draw_line(Vector2(side*3,-2),Vector2(side*7,-4),Color(0.25,0.02,0.06,alpha*seal),2,true)
	draw_arc(Vector2(0,1),5,0.2,PI-0.2,10,Color(0.25,0.02,0.06,alpha*seal),1.6,true)
	draw_set_transform(Vector2.ZERO)

func _release_mark(board: MainBoard) -> void:
	var owner: Variant = board._super_hidden.get(_hidden_key())
	if owner is int and owner==get_instance_id():
		board._super_hidden.erase(_hidden_key())

func _exit_tree() -> void:
	var board: MainBoard = _board_ref.get_ref() if _board_ref!=null else null
	if board!=null:
		_release_mark(board)
	var view: Node2D = _view_ref.get_ref() if _view_ref!=null else null
	if view==null:
		return
	view.z_index = int(_saved.z)
	view.scale = _saved.scale
	view.rotation = float(_saved.rotation)
	view.modulate = _saved.modulate
	if _complete and _rest.has("rest_position"):
		# Preserve this pick's result until later queued effects get their own turn.
		view.position = _rest.rest_position
		view.visible = bool(_rest.rest_visible)
		return
	if board!=null and board.state!=null:
		var pawn: PlayerPawn = board.state.get_pawn(pawn_id)
		if pawn!=null:
			view.position = board._pawn_position(pawn)
			view.visible = pawn.has_left_start and not pawn.is_finished and pawn.carrier==null
