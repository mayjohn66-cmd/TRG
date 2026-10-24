## SUPER_07 only. The engine owns the permutation; this stage moves actual views.
extends Node2D

const LIFT_START := 0.30
const SPIN_START := 0.74
const LAND_START := 1.94
const TOTAL_TIME := 2.92
const GOLD := Color("ffd267")
var elapsed := 0.0
var phase: StringName = &"mark"
var pace := 1.0
var pawns: Array[Dictionary] = []
var _complete := false
var _board_ref: WeakRef
var _generation := 0
var _center := Vector2.ZERO
var _radius := Vector2(110,58)
var _angle := 0.0
var _last_tick := -1
var _last_phase: StringName = &""

func play(board: MainBoard, changes: Array, speed: float) -> void:
	name = "CastlingStage"
	z_index = 14
	_board_ref = weakref(board)
	_generation = board._fx_generation
	pace = clampf(speed,0.35,2.0)
	_center = board._board_center()+Vector2(0,-16)
	for change: Dictionary in changes:
		if change.get("kind")!="castling_pose":
			continue
		for pose: Dictionary in change.pawns:
			var view: Node2D = board._pawn_views.get(int(pose.pawn))
			if view==null:
				continue
			board._kill_fx(view)
			pawns.append({"id":int(pose.pawn),"view":weakref(view),"from":view.position,"to":pose.position,"tile":int(pose.tile),"z":view.z_index,"scale":view.scale,"rotation":view.rotation,"tint":view.modulate,"landed":false,"color":view.modulate})
	_radius = Vector2(clampf(75.0+pawns.size()*5.0,100,150),clampf(43.0+pawns.size()*2.4,55,79))
	if pawns.size()<2:
		_complete = true
	_update_pose(board)

func _process(delta: float) -> void:
	if _board_ref==null or _complete:
		return
	var board: MainBoard = _board_ref.get_ref()
	if board==null or board._fx_generation!=_generation:
		cancel()
		return
	elapsed += delta/pace
	phase = &"mark" if elapsed<LIFT_START else (&"lift" if elapsed<SPIN_START else (&"spin" if elapsed<LAND_START else &"land"))
	if phase!=_last_phase:
		_last_phase = phase
		if phase==&"lift": Sfx.play(&"launch",-5.0)
		if phase==&"land": Sfx.play(&"good",-6.0)
	_update_pose(board)
	if phase==&"spin":
		var tick := int(_angle/(TAU/maxi(8,pawns.size()*2)))
		if tick!=_last_tick:
			_last_tick = tick
			Sfx.play(&"roulette_tick",-10.0)
	queue_redraw()
	if elapsed>=TOTAL_TIME:
		_restore(false)
		_complete = true
		set_process(false)

func _slot(index: int, angle: float) -> Vector2:
	var theta := index*TAU/maxi(1,pawns.size())-PI/2+angle
	return _center+Vector2(cos(theta),sin(theta))*_radius

func _land_time(index: int) -> float:
	return LAND_START+index*0.20/maxi(1,pawns.size()-1)

func _update_pose(board: MainBoard) -> void:
	var lift := smoothstep(LIFT_START,SPIN_START,elapsed)
	var spin := clampf((elapsed-SPIN_START)/(LAND_START-SPIN_START),0,1)
	_angle = TAU*2.0*(1.0-pow(1.0-spin,3.0))
	for index: int in pawns.size():
		var item: Dictionary = pawns[index]
		var view: Node2D = item.view.get_ref()
		if view==null:
			continue
		var landing := smoothstep(_land_time(index),_land_time(index)+0.48,elapsed)
		var slot := _slot(index,_angle)
		view.position = (item.from as Vector2).lerp(slot,lift)+Vector2(0,-36*sin(lift*PI))
		if elapsed>=LAND_START:
			view.position = slot.lerp(item.to,landing)+Vector2(0,-54*sin(landing*PI))
		view.z_index = 24+int((view.position.y-_center.y)*0.02)
		view.rotation = float(item.rotation)+0.055*sin(_angle+index)*lift*(1-landing)
		var bounce := sin(clampf((elapsed-_land_time(index)-0.48)/0.16,0,1)*PI)
		view.scale = (item.scale as Vector2)*Vector2(1.0+0.07*lift*(1-landing)+0.08*bounce,1.0+0.07*lift*(1-landing)-0.08*bounce)
		if landing>=1.0 and not bool(item.landed):
			item.landed = true
			Sfx.play(&"toy_click",-10.0)
			board._fx_hints.erase(int(item.id))

func _ellipse(at: Vector2, radius: Vector2, tint: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index: int in 65:
		var angle := index*TAU/64.0
		points.append(at+Vector2(cos(angle),sin(angle))*radius)
	draw_polyline(points,tint,width,true)

func _draw() -> void:
	if pawns.size()<2:
		return
	var appear := smoothstep(0,0.16,elapsed)
	var fade := 1.0-smoothstep(LAND_START,LAND_START+0.38,elapsed)
	var board: MainBoard = _board_ref.get_ref()
	if board==null:
		return
	# Thin roulette rim, individual pockets and a fixed pointer make slowing clear.
	var rim_alpha := appear*fade
	_ellipse(_center,_radius+Vector2(18,13),Color(GOLD,0.12*rim_alpha),9)
	_ellipse(_center,_radius+Vector2(18,13),Color(GOLD,0.65*rim_alpha),2)
	for index: int in pawns.size():
		var at := _slot(index,_angle)+Vector2(0,8)
		_ellipse(at,Vector2(18,8),Color(GOLD,rim_alpha*0.30),1.5)
	var pointer := _center+Vector2(0,-_radius.y-22)
	draw_colored_polygon(PackedVector2Array([pointer+Vector2(-7,-8),pointer+Vector2(7,-8),pointer+Vector2(0,3)]),Color(GOLD,rim_alpha))
	for index: int in pawns.size():
		var item: Dictionary = pawns[index]
		var player: PlayerPawn = board.state.get_pawn(int(item.id))
		var tint: Color = MainBoard.PLAYER_COLORS.get(player.owner_id,GOLD) if player!=null else GOLD
		var mark := (1.0-smoothstep(LIFT_START,SPIN_START,elapsed))*appear
		_ellipse(item.from,Vector2(21,9),Color(tint,mark*0.85),2)
		var t := clampf((elapsed-_land_time(index))/0.48,0,1)
		if elapsed>=LAND_START:
			var alpha := (1.0-smoothstep(TOTAL_TIME-0.22,TOTAL_TIME,elapsed))
			_ellipse(item.to,Vector2(24,11)*(1.0+0.25*sin(t*PI)),Color(tint,alpha*0.8),2.5)
			if bool(item.landed):
				var u := clampf((elapsed-_land_time(index)-0.48)/0.28,0,1)
				_ellipse(item.to,Vector2(24,11)*(1.0+u*0.8),Color(GOLD,(1-u)*0.6),2)

func _restore(cancelled: bool) -> void:
	var board: MainBoard = _board_ref.get_ref() if _board_ref!=null else null
	for item: Dictionary in pawns:
		var view: Node2D = item.view.get_ref()
		if view==null:
			continue
		view.z_index = int(item.z)
		view.scale = item.scale
		view.rotation = float(item.rotation)
		view.modulate = item.tint
		view.position = item.to
		if board!=null and is_instance_valid(board) and cancelled:
			var pawn: PlayerPawn = board.state.get_pawn(int(item.id))
			if pawn!=null:
				view.position = board._pawn_position(pawn)
		if board!=null:
			board._fx_hints.erase(int(item.id))

func cancel() -> void:
	if not _complete:
		_restore(true)
	_complete = true
	queue_free()

func _exit_tree() -> void:
	if not _complete:
		_restore(true)
