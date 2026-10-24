## SUPER_10 owns both the lane cue and the real pawn's accelerated dash.
extends Node2D

const CHARGE_START := 0.26
const DASH_START := 0.52
const END_TIME := 0.28
const CYAN := Color("63e4ed")
const HOT := Color("ffae68")
var elapsed := 0.0
var phase: StringName = &"lane"
var pace := 1.0
var pawn_id := -1
var blocked := -1
var path: Array[int] = []
var points := PackedVector2Array()
var distance := 0.0
var length := 0.0
var dash_time := 0.42
var arrived := false
var artwork: Dictionary = {}
var _complete := false
var _board_ref: WeakRef
var _view_ref: WeakRef
var _generation := 0
var _saved: Dictionary = {}
var _goal_scale := 1.0
var _goal := false
var _body_color := Color.WHITE
var _restored := false
var _last_phase: StringName = &""

func play(board: MainBoard, dash: Dictionary, speed: float) -> void:
	name = "NitroStage"
	z_index = 18
	_board_ref = weakref(board)
	_generation = board._fx_generation
	pace = clampf(speed,0.35,2.0)
	pawn_id = int(dash.get("pawn",-1))
	blocked = int(dash.get("blocked",-1))
	path.assign(dash.get("path",[]))
	var view: Node2D = board._pawn_views.get(pawn_id)
	var pawn: PlayerPawn = board.state.get_pawn(pawn_id)
	if view==null or pawn==null or path.is_empty():
		_complete = true
		board._fx_skip_steps.erase(pawn_id)
		board._nitro_skips.erase(pawn_id)
		return
	board._kill_fx(view)
	_view_ref = weakref(view)
	_saved = {"scale":view.scale,"rotation":view.rotation,"tint":view.modulate,"z":view.z_index}
	view.visible = true
	view.z_index = 23
	points.append(view.position)
	for tile: int in path:
		points.append(board._tile_center(tile) if tile==GameEnums.GOAL_TILE else board._pawn_position_at(pawn,tile))
	for index: int in range(1,points.size()):
		length += points[index-1].distance_to(points[index])
	dash_time = clampf(0.26+length*0.0009,0.34,0.62)
	_goal_scale = float(dash.get("goal_scale",view.scale.x))
	_goal = path.back()==GameEnums.GOAL_TILE
	artwork = PawnArt.sprite(pawn)
	_body_color = MainBoard.PLAYER_COLORS[pawn.owner_id] if pawn.kind==GameEnums.PawnKind.BASIC else Color.WHITE
	Sfx.play(&"charge",-9.0)

func _process(delta: float) -> void:
	if _board_ref==null or _complete:
		return
	var board: MainBoard = _board_ref.get_ref()
	if board==null or board._fx_generation!=_generation:
		cancel()
		return
	elapsed += delta/pace
	var end := DASH_START+dash_time
	phase = &"lane" if elapsed<CHARGE_START else (&"charge" if elapsed<DASH_START else (&"dash" if elapsed<end else (&"impact" if blocked>=0 else &"brake")))
	if phase!=_last_phase:
		_last_phase = phase
		if phase==&"dash": Sfx.play(&"rocket",-6.0)
		if phase==&"impact":
			Sfx.play(&"thud",-5.0)
			board.screen_shake(6.0,0.16*pace)
		if phase==&"brake": Sfx.play(&"toy_click",-8.0)
	_update_pose()
	queue_redraw()
	if elapsed>=end+END_TIME:
		_restore(false)
		_complete = true
		set_process(false)

func _sample(at_distance: float) -> Vector2:
	var remaining := clampf(at_distance,0,length)
	for index: int in range(1,points.size()):
		var segment := points[index-1].distance_to(points[index])
		if remaining<=segment:
			return points[index-1].lerp(points[index],remaining/maxf(segment,0.001))
		remaining -= segment
	return points[-1]

func _heading(at_distance: float) -> Vector2:
	return (_sample(minf(at_distance+3,length))-_sample(maxf(at_distance-3,0))).normalized()

func _update_pose() -> void:
	var view: Node2D = _view_ref.get_ref()
	if view==null:
		return
	var u := clampf((elapsed-DASH_START)/dash_time,0,1)
	distance = length*u*u*u
	var heading := _heading(distance)
	var charge := smoothstep(CHARGE_START,DASH_START,elapsed) if elapsed<DASH_START else 0.0
	var settle := clampf((elapsed-DASH_START-dash_time)/END_TIME,0,1)
	view.position = _sample(distance)-heading*charge*5.0
	if u>=1.0:
		arrived = true
		view.position += heading*sin(settle*PI)*(2.0 if blocked>=0 else 5.0)
	view.rotation = -heading.x*(0.08*sin(u*PI)+0.06*charge)*(1-settle)
	var size := lerpf((_saved.scale as Vector2).x,_goal_scale,u)
	view.scale = Vector2(size,size)*Vector2(1+0.09*charge+0.08*sin(settle*PI),1-0.07*charge-0.07*sin(settle*PI))
	if _goal and arrived:
		view.modulate.a = 1-smoothstep(0.25,1.0,settle)

func _partial(at_distance: float) -> PackedVector2Array:
	var result := PackedVector2Array([points[0]])
	var remaining := at_distance
	for index: int in range(1,points.size()):
		var segment := points[index-1].distance_to(points[index])
		if remaining<segment:
			result.append(points[index-1].lerp(points[index],remaining/maxf(segment,0.001)))
			break
		result.append(points[index])
		remaining -= segment
	return result

func _draw() -> void:
	if points.size()<2:
		return
	var end := DASH_START+dash_time
	var fade := 1-smoothstep(end,end+END_TIME,elapsed)
	var laid := _partial(length*smoothstep(0,CHARGE_START,elapsed))
	if laid.size()>1:
		draw_polyline(laid,Color(CYAN,0.12*fade),14,true)
		draw_polyline(laid,Color(CYAN,0.72*fade),2.5,true)
	# Directional chevrons flow down the actual path, in the board's projection.
	for index: int in maxi(1,int(length/38)):
		var d := fposmod(index*38.0+elapsed*92,length)
		var at := _sample(d)
		var heading := _heading(d)
		var side := heading.orthogonal()
		var arrow := PackedVector2Array([at-heading*5+side*5,at+heading*2,at-heading*5-side*5])
		draw_polyline(arrow,Color(CYAN,0.55*fade*smoothstep(0,CHARGE_START,elapsed)),2,true)
	if phase==&"dash":
		var heading := _heading(distance)
		var foot := _sample(distance)
		var normal := heading.orthogonal()
		for offset: int in 4:
			var behind := distance-(offset+1)*19.0
			if behind>0 and not artwork.is_empty():
				var region: Rect2 = artwork.region
				var size: Vector2 = region.size*minf(26.0/region.size.x,31.0/region.size.y)*_goal_scale
				draw_texture_rect_region(artwork.texture,Rect2(_sample(behind)+Vector2(-size.x/2,-size.y),size),region,Color(_body_color,0.27-offset*0.055))
		var flame := PackedVector2Array([foot+normal*7-heading*6,foot-heading*(38+sin(elapsed*55)*7)+normal*2,foot-heading*23-normal*5,foot-heading*7-normal*7])
		draw_colored_polygon(flame,Color(CYAN,0.65))
		draw_line(foot-heading*7,foot-heading*27,Color(1,0.96,0.76,0.85),3,true)
	if arrived:
		var u := clampf((elapsed-end)/END_TIME,0,1)
		var at := points[-1]
		var tint := HOT if blocked>=0 else Color("abf5db") if not _goal else Color("ffe69c")
		var ring := PackedVector2Array()
		for index: int in 41:
			var angle := index*TAU/40.0
			ring.append(at+Vector2(cos(angle)*28,sin(angle)*13)*(1+u*0.7))
		draw_polyline(ring,Color(tint,(1-u)*0.8),2.5,true)
		if blocked>=0:
			for index: int in 8:
				var ray := Vector2.from_angle(index*TAU/8.0)
				draw_line(at+Vector2(0,-17)+ray*(13+u*15),at+Vector2(0,-17)+ray*(31+u*23),Color(HOT,(1-u)*0.85),2.5,true)

func _restore(cancelled: bool) -> void:
	if _restored:
		return
	_restored = true
	var board: MainBoard = _board_ref.get_ref() if _board_ref!=null else null
	var view: Node2D = _view_ref.get_ref() if _view_ref!=null else null
	if view!=null:
		view.scale = Vector2.ONE*_goal_scale
		view.rotation = float(_saved.rotation)
		view.modulate = _saved.tint
		view.z_index = int(_saved.z)
		view.position = points[-1]
		if board!=null:
			var pawn: PlayerPawn = board.state.get_pawn(pawn_id)
			if pawn!=null and (cancelled or _goal):
				view.position = board._pawn_position(pawn)
				view.visible = pawn.has_left_start and not pawn.is_finished and pawn.carrier==null
	if board!=null:
		board._fx_skip_steps.erase(pawn_id)
		board._nitro_skips.erase(pawn_id)

func cancel() -> void:
	_restore(true)
	_complete = true
	queue_free()

func _exit_tree() -> void:
	if not _complete:
		_restore(true)
