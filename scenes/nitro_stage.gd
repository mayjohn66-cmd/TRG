## SUPER_10 owns ignition, close camera, impact slow motion and one simultaneous launch.
extends Node2D

const CHARGE_START := 0.24
const DASH_START := 0.60
const END_TIME := 0.28
const SLOW_TIME := 0.24
const FLIGHT_TIME := 0.74
const RECOVER_TIME := 0.24
const CYAN := Color("63e4ed")
const BLUE := Color("268bff")
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
var victims: Dictionary = {}
var launch_age := -1.0
var camera_weight := 0.0

func play(board: MainBoard, dash: Dictionary, speed: float) -> void:
	name = "NitroStage"
	z_index = 18
	_board_ref = weakref(board)
	_generation = board._fx_generation
	pace = clampf(speed,0.35,2.0)
	pawn_id = int(dash.get("pawn",-1))
	blocked = int(dash.get("blocked",-1))
	path.assign(dash.get("path",[]))
	victims = dash.get("victims",{})
	var view: Node2D = board._pawn_views.get(pawn_id)
	var pawn: PlayerPawn = board.state.get_pawn(pawn_id)
	if view==null or pawn==null or path.is_empty():
		_complete = true
		board._fx_skip_steps.erase(pawn_id)
		board._nitro_skips.erase(pawn_id)
		board._release_nitro_victims(victims.keys())
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
	for id: int in victims:
		var target: Node2D = board._pawn_views.get(id)
		if target!=null:
			board._kill_fx(target)
			target.position = victims[id].position
			target.visible = victims[id].visible
			target.z_index = 24
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
	var collision := blocked>=0
	var duration := SLOW_TIME+FLIGHT_TIME+RECOVER_TIME if collision else END_TIME
	if elapsed<CHARGE_START:
		phase = &"lane"
	elif elapsed<DASH_START:
		phase = &"charge"
	elif elapsed<end:
		phase = &"dash"
	elif not collision:
		phase = &"brake"
	elif elapsed<end+SLOW_TIME:
		phase = &"impact"
	elif elapsed<end+SLOW_TIME+FLIGHT_TIME:
		phase = &"eject"
	else:
		phase = &"recover"
	if phase!=_last_phase:
		_last_phase = phase
		if phase==&"dash": Sfx.play(&"rocket",-6.0)
		if phase==&"impact": Sfx.play(&"thud",-5.0)
		if phase==&"eject":
			board.screen_shake(7.0,0.18*pace)
			Sfx.play(&"rocket",-10.0)
		if phase==&"brake": Sfx.play(&"toy_click",-8.0)
	_update_pose()
	_update_victims(board,end)
	_update_camera(board,end,duration)
	queue_redraw()
	if elapsed>=end+duration:
		_restore(false)
		_complete = true
		set_process(false)

## All target views share this clock. The impact beat advances at 12% speed;
## release happens once for the whole tile, never through the serial kill queue.
func _update_victims(board: MainBoard, end: float) -> void:
	launch_age = elapsed-end-SLOW_TIME
	var heading := _heading(length)
	var side := heading.orthogonal()
	var index := 0
	var count := victims.size()
	for id: int in victims:
		var view: Node2D = board._pawn_views.get(id)
		var info: Dictionary = victims[id]
		if view==null:
			continue
		view.position = info.position
		view.scale = info.scale
		if elapsed>=end and launch_age<0:
			var slow := (elapsed-end)*0.12
			view.position += heading*slow*28
			view.scale = (info.scale as Vector2)*Vector2(1.12,0.90)
		elif launch_age>=0:
			var t := minf(launch_age,FLIGHT_TIME)
			var fan := (float(index)-(count-1)*0.5)*160.0
			view.position += (heading*460+side*fan+Vector2(0,-330))*t+Vector2(0,260)*t*t
			view.rotation = t*(8.0 if index%2==0 else -9.0)
			view.scale = (info.scale as Vector2)*(1+sin(t/FLIGHT_TIME*PI)*0.14)
			view.modulate.a = 1-smoothstep(FLIGHT_TIME*0.64,FLIGHT_TIME,t)
		view.visible = bool(info.visible) and launch_age<FLIGHT_TIME
		index += 1

func _update_camera(board: MainBoard, end: float, duration: float) -> void:
	camera_weight = smoothstep(0,0.28,elapsed)*(1-smoothstep(end+duration-RECOVER_TIME,end+duration,elapsed))
	var zoom := 1.0+0.65*camera_weight
	var center := MainBoard.BOARD_ORIGIN+Vector2.ONE*MainBoard.BOARD_SIZE*0.5
	var focus := _sample(distance)+Vector2(0,-18)
	var offset := board._off_center+center*(1-zoom)+(center-focus)*zoom*0.65*camera_weight
	board._board_layer.scale = Vector2.ONE*zoom
	board._pawn_layer.scale = Vector2.ONE*zoom
	board._board_layer.position = offset
	board._pawn_layer.position = offset
	transform = board._pawn_layer.transform

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
	var duration := SLOW_TIME+FLIGHT_TIME+RECOVER_TIME if blocked>=0 else END_TIME
	var fade := 1-smoothstep(end+0.12,end+duration,elapsed)
	var heading := _heading(distance)
	var foot := _sample(distance)
	# Blue fire gathers around the actual pawn before any track appears.
	var ignition := smoothstep(0,0.18,elapsed)*(1-smoothstep(end,end+0.18,elapsed))
	draw_circle(foot+Vector2(0,-12),22+sin(elapsed*24)*2,Color(BLUE,0.12*ignition))
	for index: int in 7:
		var x := (index-3)*5.5
		var height := (29+sin(elapsed*31+index*2.1)*9)*ignition
		var base := foot+Vector2(x,1+absf(x)*0.1)
		_flame(base,Vector2.UP,height,5.4,ignition,elapsed*29+index)
	# The burning rails/grid only extends where the pawn has actually dashed.
	if distance>1:
		var trail := _partial(distance)
		draw_polyline(trail,Color(BLUE,0.12*fade),29,true)
		draw_polyline(trail,Color(CYAN,0.24*fade),14,true)
		for d: int in range(0,int(distance),12):
			var at := _sample(d)
			var forward := _heading(d)
			var side := forward.orthogonal()
			draw_line(at-side*9,at+side*9,Color(CYAN,0.35*fade),1.5,true)
			for sign: int in [-1,1]:
				var base := at+side*9*sign
				draw_line(base,base+forward*13,Color(BLUE,0.9*fade),3,true)
				_flame(base,Vector2.UP-forward*0.4,16+sin(elapsed*37+d)*7,4.4,fade,elapsed*35+d)
	if phase==&"dash":
		for offset: int in 4:
			var behind := distance-(offset+1)*19.0
			if behind>0 and not artwork.is_empty():
				var region: Rect2 = artwork.region
				var size: Vector2 = region.size*minf(26.0/region.size.x,31.0/region.size.y)*_goal_scale
				draw_texture_rect_region(artwork.texture,Rect2(_sample(behind)+Vector2(-size.x/2,-size.y),size),region,Color(_body_color,0.27-offset*0.055))
		_flame(foot-heading*7,-heading,48+sin(elapsed*53)*7,8,1,elapsed*43)
	if arrived:
		# The flash/rays barely advance during the slow beat, then burst outward.
		var age := elapsed-end
		var visual_age := minf(age,SLOW_TIME)*0.12+maxf(0,age-SLOW_TIME)
		var u := clampf(visual_age/(FLIGHT_TIME*0.75),0,1) if blocked>=0 else clampf(age/END_TIME,0,1)
		var at := points[-1]
		var tint := CYAN if blocked>=0 else Color("abf5db")
		var ring := PackedVector2Array()
		for index: int in 49:
			var angle := index*TAU/48.0
			ring.append(at+Vector2(cos(angle)*32,sin(angle)*16)*(1+u*2.3))
		draw_polyline(ring,Color(tint,(1-u)*0.9),3,true)
		if blocked>=0:
			var hit := at+Vector2(0,-17)
			for index: int in 12:
				var ray := Vector2.from_angle(index*TAU/12.0)
				draw_line(hit+ray*(10+u*35),hit+ray*(29+(index%3)*7+u*70),Color(CYAN,(1-u)*0.9),3,true)
			draw_circle(hit,11*(1-u),Color(0.86,1,1,(1-u)*0.8))

func _flame(base: Vector2, direction: Vector2, height: float, width: float, alpha: float, flicker: float) -> void:
	var side := direction.orthogonal()
	var shape := PackedVector2Array()
	for index: int in 9:
		var u := index/8.0
		var sway := sin(flicker+u*4.5)*width*u*0.75
		shape.append(base+direction*height*u+side*(sway-width*(1-u)*sqrt(1-u)))
	for index: int in range(7,-1,-1):
		var u := index/8.0
		var sway := sin(flicker+u*4.5)*width*u*0.75
		shape.append(base+direction*height*u+side*(sway+width*(1-u)*sqrt(1-u)))
	draw_colored_polygon(shape,Color(BLUE,alpha*0.72))
	var core := PackedVector2Array()
	for index: int in 7:
		var u := index/8.0
		core.append(base+direction*height*u+side*sin(flicker+u*4.5)*width*u*0.75)
	draw_polyline(core,Color(CYAN,alpha*0.9),width*0.6,true)

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
		board._release_nitro_victims(victims.keys())
		board._board_layer.scale = Vector2.ONE
		board._pawn_layer.scale = Vector2.ONE
		board._board_layer.position = board._off_center
		board._pawn_layer.position = board._off_center
		transform = board._pawn_layer.transform

func cancel() -> void:
	_restore(true)
	_complete = true
	queue_free()

func _exit_tree() -> void:
	if not _complete:
		_restore(true)
