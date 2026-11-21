## SUPER_03 visuals only. The engine has already reset the offering and awarded +N.
extends Node2D

const OFFER_END := 0.68
const CONSUME_END := 1.38
const ARRIVAL := 2.02
const TOTAL_TIME := 2.78
const CRIMSON := Color("f04465")
const VIOLET := Color("b467ee")
const SCROLL_ART := preload("res://assets/fx/devil_contract/contract_scroll.png")
const WAX_ART := preload("res://assets/fx/devil_contract/devil_wax_seal.png")
const SIGIL_ART := preload("res://assets/fx/devil_contract/summoning_sigil.png")
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

func _draw() -> void:
	if _board_ref==null:
		return
	var board: MainBoard = _board_ref.get_ref()
	if board==null:
		return
	var fade := 1.0-smoothstep(ARRIVAL,TOTAL_TIME,elapsed)
	var open := smoothstep(0.0,0.32,elapsed)*fade
	draw_rect(Rect2(Vector2.ZERO,board.size),Color(0.06,0.01,0.09,0.46*open))
	# Wispy ground haze and a broken painted rim anchor the original sigil.
	PaintedFx.stamp(self,PaintedFx.SMOKE,_origin,Vector2(164,56),Color(0.10,0.025,0.13,0.7*open))
	PaintedFx.stamp(self,PaintedFx.RIPPLE,_origin,Vector2(172,65),Color(CRIMSON,0.34*open))
	# The native circular sprite is flattened onto the same board footprint.
	draw_set_transform(_origin,0,Vector2(1,0.4))
	draw_texture_rect(SIGIL_ART,Rect2(-81,-81,162,162),false,Color(1,1,1,open*0.86))
	draw_set_transform(Vector2.ZERO)
	# Restrained embers rise into the offering, with no simulation RNG.
	for index: int in 12:
		var t := fposmod(elapsed*0.75+index/12.0,1.0)
		var angle := index*2.4+elapsed*1.4
		var point := _origin+Vector2(cos(angle)*60*(1-t),-t*100+sin(angle)*16*(1-t))
		PaintedFx.stamp(self,PaintedFx.FLECK,point,Vector2(2.4,4.0+2*sin(t*PI)),Color(VIOLET.lerp(CRIMSON,t),sin(t*PI)*open),angle)
	var scroll_alpha := smoothstep(0.36,OFFER_END,elapsed)*fade
	_draw_contract(_origin+Vector2(91,-61),scroll_alpha)
	if elapsed>=CONSUME_END and elapsed<ARRIVAL:
		var travel := clampf((elapsed-CONSUME_END)/(ARRIVAL-CONSUME_END),0,1)
		for index: int in 18:
			var head := clampf(travel-index*0.014,0,1)
			var tail := maxf(head-0.025,0)
			var alpha := (1.0-index/18.0)*smoothstep(0.0,0.12,head)
			PaintedFx.streak(self,_energy_position(smoothstep(0,1,tail)),_energy_position(smoothstep(0,1,head)),10-index*0.35,Color(CRIMSON.lerp(VIOLET,index/18.0),alpha*0.8))
		var tip := _energy_position(smoothstep(0,1,travel))
		var heading := _energy_position(smoothstep(0,1,minf(travel+0.025,1)))-_energy_position(smoothstep(0,1,maxf(travel-0.025,0)))
		PaintedFx.flame(self,tip,-heading.normalized(),22,6,Color(VIOLET,0.85),elapsed*16)
		PaintedFx.stamp(self,PaintedFx.IMPACT,tip,Vector2.ONE*13,Color(1,0.87,0.72,0.9))
	if ignited:
		var u := clampf((elapsed-ARRIVAL)/0.48,0,1)
		PaintedFx.stamp(self,PaintedFx.RIPPLE,_target,Vector2(84,56).lerp(Vector2(286,190),u),Color(CRIMSON,(1-u)*0.75))
		for index: int in 9:
			var direction := Vector2.from_angle(index*TAU/9.0-PI/2)
			PaintedFx.stamp(self,PaintedFx.FLECK,_target+direction*(34+u*65),Vector2(3,9),Color(VIOLET,(1-u)*0.8),direction.angle()+u)

func _energy_position(u: float) -> Vector2:
	var source := _origin+Vector2(0,-18)
	var bend := (source+_target)/2.0+Vector2(0,-125)
	return source.lerp(bend,u).lerp(bend.lerp(_target,u),u)

func _draw_contract(at: Vector2, alpha: float) -> void:
	draw_set_transform(at,-0.10)
	draw_texture_rect(SCROLL_ART,Rect2(-39,-58.5,78,117),false,Color(1,1,1,alpha))
	var seal := smoothstep(CONSUME_END-0.12,CONSUME_END+0.08,elapsed)
	var s := 1.0+0.8*(1-seal)
	draw_set_transform(at+Vector2(0,15),-0.10,Vector2.ONE*s)
	draw_texture_rect(WAX_ART,Rect2(-20,-20,40,40),false,Color(1,1,1,alpha*seal))
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
