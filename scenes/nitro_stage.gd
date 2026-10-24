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
var _glow: PaintLayer
var _foreground: PaintLayer
var _light_texture: GradientTexture2D

## Child layers share the world camera and disappear with this stage.
## Additive light sits behind the real pawn; crisp contact sparks sit in front.
class PaintLayer extends Node2D:
	var stage: Node2D
	var glow := false
	func _draw() -> void:
		if is_instance_valid(stage):
			if glow:
				stage._draw_glow(self)
			else:
				stage._draw_foreground(self)


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
	_glow = PaintLayer.new()
	_glow.name = "NitroGlow"
	_glow.stage = self
	_glow.glow = true
	_glow.z_index = -1
	var light_material := CanvasItemMaterial.new()
	light_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = light_material
	add_child(_glow)
	_foreground = PaintLayer.new()
	_foreground.name = "NitroContact"
	_foreground.stage = self
	_foreground.z_index = 8
	add_child(_foreground)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,0.24,0.62,1.0])
	gradient.colors = PackedColorArray([Color(1,1,1,0.75),Color(1,1,1,0.46),Color(1,1,1,0.10),Color(1,1,1,0)])
	_light_texture = GradientTexture2D.new()
	_light_texture.width = 128
	_light_texture.height = 128
	_light_texture.gradient = gradient
	_light_texture.fill = GradientTexture2D.FILL_RADIAL
	_light_texture.fill_from = Vector2(0.5,0.5)
	_light_texture.fill_to = Vector2(1.0,0.5)
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
	_glow.queue_redraw()
	_foreground.queue_redraw()
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
	var ignition := smoothstep(0,0.18,elapsed)*(1-smoothstep(end,end+0.18,elapsed))
	# Uneven tongues and rising embers read as fire rather than a fixed crown.
	for index: int in 9:
		var x := (index-4)*4.5
		var height := (25+sin(elapsed*24+index*2.1)*8+cos(elapsed*17-index)*5)*ignition
		var base := foot+Vector2(x,2+absf(x)*0.08)
		_flame(base,Vector2.UP+Vector2(sin(elapsed*8+index)*0.14,0),height,5.2,ignition,elapsed*23+index)
	for index: int in 11:
		var rise := fposmod(elapsed*0.85+index*0.137,1.0)
		var at := foot+Vector2(sin(index*2.3+rise*4)*21,-7-rise*48)
		draw_line(at+Vector2(0,3+rise*3),at,Color(CYAN,sin(rise*PI)*0.8*ignition),1.5,true)
	# A tapered, flowing wake retains the floor grid without resembling rails.
	if distance>1:
		var trail := _partial(distance)
		draw_polyline(trail,Color(BLUE,0.16*fade),25,true)
		for d: int in range(0,int(distance),10):
			var at := _sample(d)
			var forward := _heading(d)
			var side := forward.orthogonal()
			var heat := 0.30+0.70*pow(clampf(float(d)/maxf(distance,1),0,1),0.7)
			if d%20==0:
				draw_line(at-side*9,at+side*9,Color(CYAN,0.25*fade*heat),1.2,true)
			for sign: int in [-1,1]:
				var base := at+side*(8+sin(d*0.12-elapsed*15)*1.5)*sign
				_flame(base,Vector2.UP-forward*0.65,(13+sin(elapsed*29+d)*6)*heat,4.8,fade*heat,elapsed*28+d)
		for sign: int in [-1,1]:
			var ribbon := PackedVector2Array()
			for d: int in range(0,int(distance)+1,5):
				ribbon.append(_sample(d)+_heading(d).orthogonal()*sign*(7+sin(d*0.08-elapsed*24)*2))
			if ribbon.size()>1:
				draw_polyline(ribbon,Color(CYAN,0.6*fade),1.8,true)
	if phase==&"dash":
		for offset: int in 4:
			var behind := distance-(offset+1)*19.0
			if behind>0 and not artwork.is_empty():
				var region: Rect2 = artwork.region
				var size: Vector2 = region.size*minf(26.0/region.size.x,31.0/region.size.y)*_goal_scale
				draw_texture_rect_region(artwork.texture,Rect2(_sample(behind)+Vector2(-size.x/2,-size.y),size),region,Color(_body_color,0.27-offset*0.055))
		_flame(foot-heading*7,-heading,56+sin(elapsed*43)*9,10,1,elapsed*37)
	if arrived:
		var age := _impact_visual_age()
		var u := clampf(age/0.58,0,1) if blocked>=0 else clampf((elapsed-end)/END_TIME,0,1)
		var at := points[-1]
		# Two expanding ground-pressure arcs spread out when the held hit releases.
		for index: int in 2:
			var ring := PackedVector2Array()
			var radius := 19+u*(82+index*24)
			for step: int in 65:
				var angle := step*TAU/64.0
				ring.append(at+Vector2(cos(angle),sin(angle)*0.48)*radius)
			draw_polyline(ring,Color(CYAN,(1-u)*(0.65-index*0.2)),2.5-index,true)

func _impact_visual_age() -> float:
	var age := maxf(0,elapsed-DASH_START-dash_time)
	return minf(age,SLOW_TIME)*0.12+maxf(0,age-SLOW_TIME) if blocked>=0 else age

func _draw_glow(canvas: Node2D) -> void:
	if points.size()<2:
		return
	var end := DASH_START+dash_time
	var foot := _sample(distance)+Vector2(0,-13)
	var ignition := smoothstep(0,0.18,elapsed)*(1-smoothstep(end,end+0.14,elapsed))
	_soft_light(canvas,foot,34,Color(BLUE,0.35*ignition))
	_soft_light(canvas,foot+Vector2(0,8),19,Color(CYAN,0.35*ignition))
	if phase==&"dash":
		var trail := _partial(distance)
		canvas.draw_polyline(trail,Color(BLUE,0.18),36,true)
		canvas.draw_polyline(trail,Color(CYAN,0.24),13,true)
	if arrived and blocked>=0:
		var age := _impact_visual_age()
		var fade := 1-smoothstep(0.02,0.45,age)
		_soft_light(canvas,points[-1]+Vector2(0,-17),42+age*90,Color(CYAN,0.6*fade))

func _soft_light(canvas: Node2D, at: Vector2, radius: float, tint: Color) -> void:
	canvas.draw_texture_rect(_light_texture,Rect2(at-Vector2.ONE*radius,Vector2.ONE*radius*2),false,tint)

func _draw_foreground(canvas: Node2D) -> void:
	if points.size()<2:
		return
	var heading := _heading(distance)
	var foot := _sample(distance)
	# Short tapered slipstream streaks frame the pawn without covering its face.
	if phase==&"dash":
		var side := heading.orthogonal()
		var speed := clampf(distance/maxf(length,1),0,1)
		for index: int in 8:
			var shift := fposmod(elapsed*230+index*17,66.0)
			var at := foot-heading*shift+side*(19+(index%4)*4)*(1 if index%2==0 else -1)+Vector2(0,-13)
			var streak := PackedVector2Array([at,at-heading*(10+speed*30)-side*1.1,at-heading*(8+speed*24)+side*1.1])
			canvas.draw_colored_polygon(streak,Color(CYAN,0.45*speed))
	if not arrived or blocked<0:
		return
	var age := _impact_visual_age()
	var fade := 1-smoothstep(0.06,0.52,age)
	var hit := points[-1]+Vector2(0,-17)
	# A directional white-hot star holds during slow motion, then opens into shards.
	var star := PackedVector2Array()
	for index: int in 24:
		var angle := heading.angle()+index*TAU/24.0
		var radius := (26+sin(index*2.3)*7+age*55) if index%2==0 else 7.0+age*8
		star.append(hit+Vector2.from_angle(angle)*radius)
	canvas.draw_colored_polygon(star,Color(BLUE,0.45*fade))
	var flash := 1-smoothstep(0.0,0.065,age)
	canvas.draw_line(hit-heading*(23+age*90),hit+heading*(35+age*90),Color(0.9,1,1,0.8*flash),4,true)
	canvas.draw_line(hit-Vector2(0,24),hit+Vector2(0,21),Color(0.9,1,1,0.7*flash),3,true)
	for index: int in 22:
		var angle := heading.angle()+index*2.39996
		var ray := Vector2.from_angle(angle)
		var speed := 95+fposmod(index*37.0,120)
		var at := hit+ray*(11+age*speed)+heading*age*55+Vector2(0,age*age*70)
		var shard_length := 4+fposmod(index*11.0,9)*(1-age)
		var shard := PackedVector2Array([at+ray*shard_length,at+ray.orthogonal()*1.8,at-ray*3,at-ray.orthogonal()*1.8])
		canvas.draw_colored_polygon(shard,Color(Color("ddffff") if index%3==0 else CYAN,fade*0.9))
		if index%3==0:
			canvas.draw_line(at-ray*(7+age*30),at,Color(CYAN,fade*0.4),1.3,true)
	# The shared launch has one pressure burst, and every flying piece gets a wake.
	if launch_age>=0 and launch_age<0.32:
		var board: MainBoard = _board_ref.get_ref()
		if board==null:
			return
		var wake_alpha := 1-smoothstep(0.10,0.32,launch_age)
		for id: int in victims:
			var view: Node2D = board._pawn_views.get(id)
			if view==null or not view.visible:
				continue
			var direction: Vector2 = (view.position-(victims[id].position as Vector2)).normalized()
			var tip := view.position+Vector2(0,-12)
			canvas.draw_line(tip-direction*25,tip-direction*8,Color(CYAN,wake_alpha*0.7),2,true)

func _flame(base: Vector2, direction: Vector2, height: float, width: float, alpha: float, flicker: float) -> void:
	if height<0.3 or alpha<0.01:
		return
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
