## Aiming and presentation only. PawnSkills remains the authority for hits and landing.
class_name AlkkagiStage
extends Control

signal shot_requested(angle: float, power: float)
signal cancel_requested
signal contact(pawn_id: int)
signal finished

const DESIGN := Vector2(960,660)
const FIELD := Rect2(70,122,480,480)
const RADIUS := 18.0 # Two stones together match PawnSkills.SHOT_HIT_RADIUS in board coordinates.
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
	mouse_filter = Control.MOUSE_FILTER_STOP
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
	angle = 0.0
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

func layout_scale() -> float:
	return minf(size.x/DESIGN.x,size.y/DESIGN.y)*0.94

func layout_origin() -> Vector2:
	return (size-DESIGN*layout_scale())/2.0

func to_screen(point: Vector2) -> Vector2:
	return get_global_transform()*(layout_origin()+(FIELD.position+point*FIELD.size)*layout_scale())

func _local_pointer(point: Vector2) -> Vector2:
	return (get_global_transform().affine_inverse()*point-layout_origin())/layout_scale()

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
		if Rect2(632,560,260,52).has_point(point):
			cancel_requested.emit()
		elif Rect2(24,78,572,562).has_point(point):
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
	var pull := _drag_start-point
	power = clampf(pull.length()/MAX_PULL,0.0,1.0)
	if pull.length()>1.0:
		angle = pull.angle()
	stone = origin-Vector2.from_angle(angle)*power*0.045
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
	mode = &"pull"
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
		queue_redraw()
		return
	var dt := delta/pace
	elapsed += dt
	var direction := (endpoint-origin).normalized()
	if mode==&"pull":
		stone = origin-direction*0.045*sin(minf(elapsed/0.22,1.0)*PI/2.0)
		if elapsed>=0.22:
			mode = &"slide"
			elapsed = 0.0
			Sfx.play(&"yut_clack",-5.0,0.02,1.4)
	elif mode==&"slide":
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
		cancel()
		finished.emit()
	queue_redraw()

func _text(at: Vector2,text: String,px: int,color: Color=Color("fff2cf")) -> void:
	draw_string(CardSkin.FONT,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,px,color)

func _panel(rect: Rect2,fill: Color,edge: Color,radius: int=14) -> void:
	draw_style_box(CardSkin.style(fill,edge,2,radius),rect)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.02,0.025,0.04,0.8))
	var shake := Vector2.ZERO
	if GameSession.screen_shake and shakes>0.0:
		shake = Vector2(sin(_clock*78.0),cos(_clock*63.0))*shakes*3.2
	draw_set_transform(layout_origin()+shake,0.0,Vector2.ONE*layout_scale())
	_panel(Rect2(Vector2.ZERO,DESIGN),Color("222b31"),Color("e8c680"),22)
	_text(Vector2(36,48),"흑돌 필살기 · 알까기",30)
	_text(Vector2(630,48),"당겨서 조준 · 놓아서 발사",17,Color("b8cbd1"))
	_panel(Rect2(26,80,568,558),Color("674526"),Color("a8753f"),16)
	_panel(Rect2(34,88,552,542),Color("e6b974"),Color("f8d99e"),12)
	for line: int in 17:
		var y := 98.0+line*31.0
		draw_line(Vector2(42,y),Vector2(578,y+5.0),Color(0.5,0.3,0.12,0.10),1.0,true)
	for index: int in 9:
		var offset := float(index)/8.0*FIELD.size.x
		draw_line(FIELD.position+Vector2(offset,0),FIELD.position+Vector2(offset,FIELD.size.y),Color("99703e"),1.0,true)
		draw_line(FIELD.position+Vector2(0,offset),FIELD.position+Vector2(FIELD.size.x,offset),Color("99703e"),1.0,true)
	for x: float in [0.25,0.5,0.75]:
		for y: float in [0.25,0.5,0.75]:
			draw_circle(FIELD.position+Vector2(x,y)*FIELD.size,3.0,Color("805329"),true,-1,true)
	if mode==&"aim" and dragging and not preview.is_empty():
		_draw_aim()
	for index: int in _trail.size():
		var alpha := (1.0-float(index)/10.0)*0.15
		draw_circle(FIELD.position+_trail[index]*FIELD.size,RADIUS*0.8,Color(0.1,0.08,0.06,alpha),true,-1,true)
	for piece: Dictionary in pieces:
		if int(piece.id)==shooter_id:
			continue
		var at: Vector2 = piece.pos
		var alpha := 1.0
		for hit: Dictionary in _hits:
			if int(hit.id)==int(piece.id) and float(hit.time)>=0.0:
				var age := maxf(0.0,(elapsed if mode!=&"done" else _out_time+0.65)-float(hit.time))
				at += (hit.direction as Vector2)*(1.0-exp(-age*4.2))*0.65
				alpha = 1.0-smoothstep(0.28,0.6,age)
		_draw_stone(at,bool(piece.black),piece.color,alpha,bool(piece.immune),int(piece.slot))
	_draw_stone(stone,true,Color("ffdd84"),1.0,false,0)
	if mode==&"aim":
		var center := FIELD.position+origin*FIELD.size
		draw_arc(center,RADIUS+7.0,0,TAU,64,Color("fff0b6"),2.5,true)
	for spark: Dictionary in _sparks:
		var age: float = spark.age
		if age>0.32:
			continue
		var at: Vector2 = FIELD.position+(spark.pos as Vector2)*FIELD.size
		for ray: int in 8:
			var dir := Vector2.from_angle(ray*TAU/8.0)
			draw_line(at+dir*(12.0+age*35.0),at+dir*(24.0+age*80.0),Color(1,0.96,0.75,1.0-age/0.32),3.0,true)
	_draw_sidebar()
	draw_set_transform(Vector2.ZERO)

func _draw_stone(point: Vector2,black: bool,rim: Color,alpha: float,immune: bool,slot: int) -> void:
	if alpha<=0.0:
		return
	var at := FIELD.position+point*FIELD.size
	draw_circle(at+Vector2(2,5),RADIUS+2,Color(0.16,0.08,0.02,0.28*alpha),true,-1,true)
	draw_circle(at,RADIUS+1.5,Color(rim,alpha),true,-1,true)
	draw_circle(at,RADIUS,Color(Color("080b10") if black else Color("9b988e"),alpha),true,-1,true)
	for layer: int in 14:
		var t := float(layer)/14.0
		var shade := Color("11151b").lerp(Color("52616c"),t) if black else Color("c5c1af").lerp(Color("fffdef"),t)
		draw_circle(at+Vector2(-2,-3)*t,RADIUS*(1.0-t*0.83),Color(shade,alpha),true,-1,true)
	draw_arc(at+Vector2(-2,-3),11.0,PI*1.1,PI*1.7,18,Color(0.85,0.95,1.0,0.7*alpha),2.0,true)
	if slot>0:
		_text(at+Vector2(-4,5),str(slot),12,Color(0.25,0.23,0.2,alpha))
	if immune:
		draw_arc(at,RADIUS+5,0,TAU,32,Color(0.5,0.95,1,alpha*0.8),2,true)

func _draw_aim() -> void:
	var from := FIELD.position+origin*FIELD.size
	var target: Vector2 = FIELD.position+(preview["to"] as Vector2)*FIELD.size
	var length := from.distance_to(target)
	var dir := (target-from).normalized()
	var tint := Color("ffec9f") if (preview["hits"] as Array).is_empty() else Color("cb4935")
	for step: int in maxi(0,int((length-28.0)/17.0)):
		draw_circle(from+dir*(28.0+step*17.0),2.6,tint,true,-1,true)
	draw_arc(target,11,0,TAU,32,tint,2,true)
	draw_line(from,FIELD.position+stone*FIELD.size,Color("fff1c1"),5,true)
	var pull_end := from-dir*(35.0+power*48.0)
	draw_line(from-dir*25.0,pull_end,Color("e55540"),5,true)
	draw_circle(pull_end,8,Color("fff5d7"),true,-1,true)
	for piece: Dictionary in pieces:
		if (preview["hits"] as Array).has(int(piece.id)):
			draw_arc(FIELD.position+(piece.pos as Vector2)*FIELD.size,RADIUS+7.0,0,TAU,48,Color("c63b29"),3,true)

func _draw_sidebar() -> void:
	var aiming := mode==&"aim"
	_text(Vector2(632,122),"흑돌을 튕겨 보내세요" if aiming else ("정지 · 안착" if mode==&"done" else "탁!  알까기 슈팅"),25)
	_text(Vector2(632,163),"판 위를 누른 채 뒤로 당겨요." if aiming else "돌이 닿는 순간 상대를 밀어냅니다.",16,Color("c0d1d5"))
	_text(Vector2(632,190),"놓으면 반대 방향으로 발사!" if aiming else "",16,Color("c0d1d5"))
	_text(Vector2(632,251),"당기는 힘  %d%%" % int(power*100.0),22)
	_panel(Rect2(632,270,260,24),Color("10191f"),Color("607079"),8)
	if power>0.01:
		_panel(Rect2(635,273,254*power,18),Color("eea34a").lerp(Color("ed6351"),power),Color("ffdc8a"),6)
	for index: int in range(1,10):
		draw_line(Vector2(632+index*26,272),Vector2(632+index*26,292),Color(0.1,0.1,0.1,0.35),1)
	var hits: int = (preview.get("hits",[]) as Array).size() if aiming else impacts.size()
	_text(Vector2(632,345),("예상 명중  %d개" if aiming else "명중  %d개") % hits,26,Color("ffda85"))
	var target: int = int(preview.get("landing",-1)) if aiming else landing
	if target>=0:
		_text(Vector2(632,384),"안착  %d번 칸" % target,20,Color("b4d5c7"))
	_text(Vector2(632,455),"테두리 색은 플레이어 색상",15,Color("b8cbd1"))
	_text(Vector2(632,480),"푸른 보호막은 피격 면역",15,Color("b8cbd1"))
	if aiming:
		_panel(Rect2(632,560,260,52),Color("36464e"),Color("a4bac0"),10)
		_text(Vector2(700,594),"취소 · ESC",21)
