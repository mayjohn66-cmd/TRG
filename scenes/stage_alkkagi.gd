## Aiming and presentation only. PawnSkills remains the authority for hits and landing.
class_name AlkkagiStage
extends Control

signal shot_requested(angle: float, power: float)
signal cancel_requested
signal contact(pawn_id: int)
signal pose_changed
signal finished

const DESIGN := Vector2(960,660)
const FIELD := Rect2(70,122,480,480)
var projector: Callable
var unprojector: Callable
var screen_scale: Callable
const MAX_PULL := 150.0
var mode: StringName = &"idle"
var pieces: Array[Dictionary] = []
var shooter_id: int = -1
var origin := Vector2.ZERO
var stone := Vector2.ZERO
var endpoint := Vector2.ZERO
var landing: int = -1
var power: float = 0.0
var angle: float = 0.0
var dragging := false
var preview: Dictionary = {}
var impacts: Array[int] = []
var contact_times: Dictionary = {}
var elapsed := 0.0
var flight_seconds := 1.0
var hold_seconds := 0.0
var pace := 1.0
var shakes := 0.0
var _clock := 0.0
var _drag_start := Vector2.ZERO
var _previewer: Callable
var _hits: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _trail: Array[Vector2] = []
var _out_time := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	resized.connect(func() -> void:
		if mode==&"aim":
			dragging = false
			power = 0.0
			stone = origin
			preview.clear()
			queue_redraw())

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and mode==&"aim":
		dragging = false
		power = 0.0
		stone = origin
		preview.clear()
		queue_redraw()

static func snapshot(state: GameState, pawn: PlayerPawn, colors: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: PlayerPawn in state.pawns:
		if not item.has_left_start or item.is_finished or item.carrier != null or item.current_tile_idx == GameEnums.GOAL_TILE:
			continue
		result.append({"id":item.entity_id,"owner":item.owner_id,"pos":BoardLayout.tile_norm(item.current_tile_idx),"color":colors[item.owner_id],"black":item.sub_type()==GameEnums.PawnSubType.BADUK_BLACK,"immune":MoveExecutor.is_capture_immune(state,item),"slot":item.slot})
	return result

func open_aim(items: Array[Dictionary], id: int, calculate: Callable) -> void:
	cancel()
	pieces = items.duplicate(true)
	shooter_id = id
	_previewer = calculate
	for piece: Dictionary in pieces:
		if int(piece.id)==id:
			origin = piece.pos
	stone = origin
	power = 0.0
	angle = (Vector2.ONE/2.0-origin).angle()
	var nearest := INF
	for piece: Dictionary in pieces:
		if int(piece.id)!=id and not bool(piece.immune) and piece.owner!=_shooter_owner():
			var distance: float = origin.distance_to(piece.pos)
			if distance<nearest:
				nearest = distance
				angle = ((piece.pos as Vector2)-origin).angle()
	preview.clear()
	impacts.clear()
	mode = &"aim"
	show()
	queue_redraw()

func cancel() -> void:
	mode = &"idle"
	dragging = false
	_previewer = Callable()
	_sparks.clear()
	_trail.clear()
	_hits.clear()
	shakes = 0.0
	hide()

func _shooter_owner() -> int:
	for piece: Dictionary in pieces:
		if int(piece.id)==shooter_id:
			return int(piece.owner)
	return -1

func layout_scale() -> float:
	return float(screen_scale.call()) if screen_scale.is_valid() else minf(size.x/DESIGN.x,size.y/DESIGN.y)*0.94

func layout_origin() -> Vector2:
	return (size-DESIGN*layout_scale())/2.0

func to_screen(point: Vector2) -> Vector2:
	if projector.is_valid():
		return projector.call(point)
	return get_global_transform()*(layout_origin()+(FIELD.position+point*FIELD.size)*layout_scale())

func _local_pointer(point: Vector2) -> Vector2:
	return point

func _cancel_rect() -> Rect2:
	return Rect2(size.x/2.0+150.0*layout_scale(),size.y-48.0*layout_scale(),100.0*layout_scale(),36.0*layout_scale())

func handle_input(event: InputEvent) -> bool:
	if mode!=&"aim":
		return false
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		cancel_requested.emit()
		return true
	var point := Vector2.ZERO
	var press := false
	var release := false
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
			cancel_requested.emit()
			return true
		if event.button_index!=MOUSE_BUTTON_LEFT:
			return true
		point = _local_pointer(event.position)
		press = event.pressed
		release = not press
	elif event is InputEventScreenTouch:
		if event.index!=0:
			return true
		if event.canceled:
			dragging = false
			power = 0.0
			stone = origin
			preview.clear()
			queue_redraw()
			return true
		point = _local_pointer(event.position)
		press = event.pressed
		release = not press
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		if dragging:
			update_pull(_local_pointer(event.position))
		return true
	else:
		return false
	if press:
		if _cancel_rect().has_point(point):
			cancel_requested.emit()
		elif point.distance_to(to_screen(origin))<=36.0*layout_scale():
			dragging = true
			_drag_start = point
			update_pull(point)
	elif release and dragging:
		update_pull(point)
		dragging = false
		if power>=0.08:
			shot_requested.emit(angle,power)
		else:
			stone = origin
			power = 0.0
			preview.clear()
	queue_redraw()
	return true

func update_pull(point: Vector2) -> void:
	var pull := (_drag_start-point)/maxf(layout_scale(),0.01)
	power = clampf(pull.length()/MAX_PULL,0.0,1.0)
	if pull.length()>1.0:
		if unprojector.is_valid():
			angle = ((unprojector.call(_drag_start) as Vector2)-(unprojector.call(point) as Vector2)).angle()
		else:
			angle = pull.angle()
	stone = origin
	if _previewer.is_valid():
		preview = _previewer.call(angle,power)
	queue_redraw()

func play_shot(items: Array[Dictionary], id: int, shot: Dictionary, shot_power: float, speed: float) -> void:
	cancel()
	pieces = items.duplicate(true)
	shooter_id = id
	origin = shot["from"]
	endpoint = shot["to"]
	stone = origin
	landing = int(shot["landing"])
	power = shot_power
	pace = clampf(speed,0.5,2.0)
	elapsed = 0.0
	hold_seconds = 0.0
	_out_time = 0.0
	impacts.clear()
	contact_times.clear()
	_hits.clear()
	flight_seconds = lerpf(0.85,1.25,origin.distance_to(endpoint))
	var direction := (endpoint-origin).normalized()
	var distance := maxf(origin.distance_to(endpoint),0.001)
	for piece: Dictionary in pieces:
		if not (shot["hits"] as Array).has(int(piece.id)):
			continue
		var delta: Vector2 = piece.pos-origin
		var along := delta.dot(direction)
		var side := absf(delta.cross(direction))
		var contact_distance := maxf(0.0,along-sqrt(maxf(0.0,PawnSkills.SHOT_HIT_RADIUS*PawnSkills.SHOT_HIT_RADIUS-side*side)))
		var fraction := clampf(contact_distance/distance,0.0,1.0)
		_hits.append({"id":int(piece.id),"fraction":fraction,"pos":piece.pos,"time":-1.0,"direction":(direction+((piece.pos as Vector2)-Vector2.ONE/2.0).normalized()*0.6).normalized()})
	_hits.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.fraction)<float(b.fraction))
	mode = &"slide"
	Sfx.play(&"yut_clack",-5.0,0.02,1.4)
	pose_changed.emit()
	show()
	queue_redraw()

func _process(delta: float) -> void:
	_clock += delta
	if mode in [&"idle",&"aim"]:
		if visible:
			queue_redraw()
		return
	advance(delta)

## Local stage time only: hit-stop never stalls the host, networking or Engine.time_scale.
func advance(delta: float) -> void:
	if mode==&"idle" or mode==&"aim":
		return
	shakes = maxf(0.0,shakes-delta*6.0)
	for spark: Dictionary in _sparks:
		spark.age = float(spark.age)+delta
	if hold_seconds>0.0:
		hold_seconds = maxf(0.0,hold_seconds-delta)
		pose_changed.emit()
		queue_redraw()
		return
	var dt := delta/pace
	elapsed += dt
	var direction := (endpoint-origin).normalized()
	if mode==&"slide":
		var phase := clampf(elapsed/flight_seconds,0.0,1.0)
		var travel := 1.0-pow(1.0-phase,2.4)
		stone = origin.lerp(endpoint,travel)
		_trail.push_front(stone)
		if _trail.size()>10:
			_trail.pop_back()
		for hit: Dictionary in _hits:
			if float(hit.time)<0.0 and travel>=float(hit.fraction):
				hit.time = elapsed
				impacts.append(int(hit.id))
				contact_times[int(hit.id)] = elapsed
				_sparks.append({"pos":stone.lerp(hit.pos,0.5),"age":0.0})
				hold_seconds = 0.065
				shakes = 1.0
				Sfx.play(&"mahjong_tap",-1.0,0.025,1.22)
				contact.emit(int(hit.id))
				break
		if phase>=1.0 and impacts.size()==_hits.size():
			mode = &"settle"
			_out_time = elapsed
	elif mode==&"settle" and elapsed>=_out_time+0.65:
		mode = &"done"
		elapsed = 0.0
	elif mode==&"done" and elapsed>=0.45:
		pose_changed.emit()
		cancel()
		finished.emit()
	pose_changed.emit()
	queue_redraw()

func victim_pose(id: int) -> Dictionary:
	for hit: Dictionary in _hits:
		if int(hit.id)==id and float(hit.time)>=0.0:
			var time := elapsed if mode!=&"done" else _out_time+0.65
			var age := maxf(0.0,time-float(hit.time))
			return {"pos":(hit.pos as Vector2)+(hit.direction as Vector2)*(1.0-exp(-age*4.2))*0.9,
				"alpha":1.0-smoothstep(0.35,0.85,age),"rotation":age*7.0,"age":age}
	return {}

func _draw() -> void:
	if mode==&"idle":
		return
	var sc := layout_scale()
	var from := to_screen(origin)
	if mode==&"aim":
		draw_arc(from,25.0*sc,0,TAU,64,Color("fff5bf"),3.0*sc,true)
		if dragging:
			_draw_aim()
		else:
			draw_arc(from,(29.0+sin(_clock*5.0)*2.0)*sc,0,TAU,64,Color("83f7d5"),2.0*sc,true)
		var hint := "흑돌을 누르고 뒤로 당기세요 · 놓으면 발사"
		if dragging:
			hint = "뒤로 당겨 조준 · 놓으면 발사"
		var rect := Rect2(size.x/2.0-260.0*sc,size.y-48.0*sc,402.0*sc,36.0*sc)
		draw_style_box(CardSkin.style(Color("1f3038"),Color("b0d791"),2,12),rect)
		draw_string(CardSkin.FONT,rect.position+Vector2(14,24)*sc,L10n.t(hint),HORIZONTAL_ALIGNMENT_LEFT,-1, int(17*sc),Color("fff3cf"))
		var cancel_rect := _cancel_rect()
		draw_style_box(CardSkin.style(Color("36464e"),Color("a4bac0"),2,10),cancel_rect)
		draw_string(CardSkin.FONT,cancel_rect.position+Vector2(14,24)*sc,L10n.t("취소 ESC"),HORIZONTAL_ALIGNMENT_LEFT,-1,int(16*sc),Color.WHITE)
	for index: int in range(1,_trail.size()):
		PaintedFx.streak(self,to_screen(_trail[index]),to_screen(_trail[index-1]),(10.0-index*0.7)*sc,Color(1,0.9,0.55,(1.0-float(index)/10.0)*0.5))
	for spark: Dictionary in _sparks:
		var age: float = spark.age
		if age>0.26:
			continue
		var at := to_screen(spark.pos)
		PaintedFx.stamp(self,PaintedFx.IMPACT,at,Vector2.ONE*(36+age*100)*sc,Color(1,0.96,0.75,1.0-age/0.26),age*0.7)

func _draw_aim() -> void:
	var sc := layout_scale()
	var from := to_screen(origin)
	var dir := (to_screen(origin+Vector2.from_angle(angle)*0.1)-from).normalized()
	var normal := dir.orthogonal()
	var tint := Color("ffec55").lerp(Color("ff4b21"),0.35+power*0.65)
	var length := (76.0+power*104.0)*sc
	var width := (4.5+power*1.0)*sc
	var base := from+dir*22.0*sc
	var tip := from+dir*length
	var neck := tip-dir*18.0*sc
	# Unequal slats grow toward the head; gaps and yellow-to-red color carry the force cue.
	var shaft_length := base.distance_to(neck)
	var gap := 3.0*sc
	var available := (shaft_length-gap*5.0)*0.72
	var cursor := base
	for index: int in 5:
		var t := float(index)/5.0
		var segment_length := available*(0.4+index*0.3)/5.0
		var half_width := width*lerpf(0.6,1.0,t)
		var end := cursor+dir*segment_length
		var fill := Color("ffec55").lerp(tint,t)
		_draw_aim_shape(PackedVector2Array([cursor+normal*half_width,end+normal*half_width,end-normal*half_width,cursor-normal*half_width]),fill,sc)
		cursor = end+dir*gap
	var head_half_width := width*2.3
	_draw_aim_shape(PackedVector2Array([cursor+normal*width,neck+normal*width,neck+normal*head_half_width,tip,neck-normal*head_half_width,neck-normal*width,cursor-normal*width]),tint,sc)
	if not preview.is_empty():
		var target := to_screen(preview.to)
		var distance := from.distance_to(target)
		for step: int in maxi(0,int((distance-length-10.0*sc)/(15.0*sc))):
			draw_circle(from+dir*(length+10.0*sc+step*15.0*sc),2.6*sc,Color(tint,0.8),true,-1,true)
		draw_arc(target,10.0*sc,0,TAU,32,tint,2.0*sc,true)
	var pull_end := from-dir*power*MAX_PULL*sc
	if power>0.05:
		draw_line(from-dir*24.0*sc,pull_end,Color(1,1,0.8,0.75),3.0*sc,true)
		draw_circle(pull_end,6.0*sc,Color("fff5d7"),true,-1,true)

func _draw_aim_shape(polygon: PackedVector2Array, fill: Color, sc: float) -> void:
	draw_colored_polygon(polygon,fill)
	var outline := polygon.duplicate()
	outline.append(outline[0])
	draw_polyline(outline,Color(0.3,0.22,0.08,0.65),1.2*sc,true)
