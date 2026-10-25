## SUPER_12: two real pawns, separate growing chains, one clasp, shared fate pulse.
extends Node2D

const FOCUS = preload("res://assets/fx/bond_focus.gdshader")
const REACH_AT := 0.22
const LOCK_AT := 0.82
const TOTAL_TIME := 1.68
const RESOLVE_TIME := 0.86
const RED := Color("ef766c")
const DARK := Color("542b3b")
const GOLD := Color("ffe0a5")
var phase: StringName = &"mark"
var elapsed := 0.0
var pace := 1.0
var mode: StringName = &"bind"
var a_id := -1
var b_id := -1
var locked := false
var _complete := false
var _board_ref: WeakRef
var _generation := 0
var _saved: Dictionary = {}
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _veil: ColorRect
var _light: ShaderMaterial
var _restored := false
var _lock_box: StyleBoxFlat

func play(board: MainBoard, pair: Dictionary, speed: float) -> void:
	name = "BondStage"
	z_index = 35
	_board_ref = weakref(board)
	_generation = board._fx_generation
	pace = clampf(speed,0.35,2.0)
	a_id = int(pair.get("a",-1))
	b_id = int(pair.get("b",-1))
	mode = pair.get("mode",&"bind")
	var inverse := board.get_global_transform().affine_inverse()
	for id: int in [a_id,b_id]:
		var view: Node2D = board._pawn_views.get(id)
		if view==null:
			_complete = true
			_restore()
			return
		_saved[id] = view.z_index
		view.z_index = 36
	_from = pair.get("from",inverse*board._pawn_views[a_id].global_position)+Vector2(0,3)
	_to = pair.get("to",inverse*board._pawn_views[b_id].global_position)+Vector2(0,3)
	_veil = ColorRect.new()
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.z_index = -1
	_light = ShaderMaterial.new()
	_light.shader = FOCUS
	_veil.material = _light
	add_child(_veil)
	_lock_box = StyleBoxFlat.new()
	_lock_box.set_border_width_all(2)
	_lock_box.set_corner_radius_all(3)
	_update_veil()
	Sfx.play(&"charge" if mode==&"bind" else &"toy_click",-10.0)

func _process(delta: float) -> void:
	if _board_ref==null or _complete:
		return
	var board: MainBoard = _board_ref.get_ref()
	if board==null or board._fx_generation!=_generation:
		cancel()
		return
	elapsed += delta/pace
	if mode==&"bind":
		phase = &"mark" if elapsed<REACH_AT else (&"reach" if elapsed<LOCK_AT else (&"lock" if elapsed<1.05 else &"pulse"))
		if elapsed>=LOCK_AT and not locked:
			locked = true
			Sfx.play(&"slam",-8.0)
			board.screen_shake(3.0,0.12*pace)
			board._refresh_super_marks()
	else:
		phase = &"transfer" if elapsed<0.50 else &"echo"
		if elapsed>=0.50 and not locked:
			locked = true
			Sfx.play(&"good" if mode==&"finish" else &"thud",-10.0)
	_update_veil()
	queue_redraw()
	if elapsed>=(TOTAL_TIME if mode==&"bind" else RESOLVE_TIME):
		_restore()
		_complete = true
		set_process(false)

func _update_veil() -> void:
	_veil.size = get_viewport_rect().size
	_light.set_shader_parameter("frame_size",_veil.size)
	_light.set_shader_parameter("first",_from+Vector2(0,-16))
	_light.set_shader_parameter("second",_to+Vector2(0,-16))
	var duration := TOTAL_TIME if mode==&"bind" else RESOLVE_TIME
	_light.set_shader_parameter("strength",smoothstep(0,0.16,elapsed)*(1-smoothstep(duration-0.25,duration,elapsed)))

func _point(u: float, sag: float) -> Vector2:
	return _from.lerp(_to,u)+Vector2(0,sin(u*PI)*sag)

func _draw() -> void:
	if _complete or _saved.size()!=2:
		return
	var duration := TOTAL_TIME if mode==&"bind" else RESOLVE_TIME
	var alpha := smoothstep(0,0.13,elapsed)*(1-smoothstep(duration-0.24,duration,elapsed))
	var tint := GOLD if mode==&"finish" else RED
	var reach := smoothstep(REACH_AT,LOCK_AT,elapsed) if mode==&"bind" else 1.0
	var tension := smoothstep(LOCK_AT,1.02,elapsed) if mode==&"bind" else 1.0
	var sag := (1-tension)*26.0
	var count := clampi(int(_from.distance_to(_to)/12),6,70)
	for index: int in count:
		var u := (index+0.5)/float(count)
		# Each end grows independently; the empty centre never gets a bridging line.
		if mode==&"bind" and u>reach*0.5 and u<1-reach*0.5:
			continue
		var at := _point(u,sag)
		var forward := (_point(minf(1,u+0.01),sag)-_point(maxf(0,u-0.01),sag)).normalized()
		_link(at,forward,index%2==0,tint,alpha)
	for at: Vector2 in [_from,_to]:
		_cuff(at,tint,alpha,tension)
	if mode==&"bind":
		if locked:
			var age := elapsed-LOCK_AT
			_clasp(_point(0.5,sag)+Vector2(0,-7),alpha,age)
			var travel := clampf(age/0.40,0,1)
			for u: float in [0.5-travel*0.5,0.5+travel*0.5]:
				var at := _point(u,sag)
				draw_circle(at,5,Color(GOLD,alpha*0.35))
				draw_circle(at,2.0,Color(GOLD,alpha))
			if age>0.30:
				for at: Vector2 in [_from,_to]:
					_echo(at,tint,alpha,age-0.30)
	else:
		var travel := smoothstep(0.06,0.50,elapsed)
		for offset: int in 5:
			var trail := _point(maxf(0,travel-offset*0.025),0)
			draw_circle(trail,5-offset*0.6,Color(GOLD,alpha*(0.8-offset*0.13)))
		draw_circle(_point(travel,0),2.0,Color(1,0.98,0.9,alpha))
		if elapsed>=0.50:
			_echo(_to,tint,alpha,elapsed-0.50)

func _link(at: Vector2, forward: Vector2, open: bool, tint: Color, alpha: float) -> void:
	var side := forward.orthogonal()
	var link := PackedVector2Array()
	for index: int in 21:
		var angle := index*TAU/20.0
		link.append(at+forward*cos(angle)*7+side*sin(angle)*(3.6 if open else 1.4))
	draw_polyline(link,Color(DARK,alpha),4.2,true)
	draw_polyline(link,Color(tint,alpha),2.3,true)
	var highlight := PackedVector2Array()
	for index: int in 9:
		var angle := PI+index*PI/10.0
		highlight.append(at+forward*cos(angle)*7+side*sin(angle)*(3.6 if open else 1.4))
	draw_polyline(highlight,Color(GOLD,alpha*0.7),0.9,true)

func _cuff(at: Vector2, tint: Color, alpha: float, tension: float) -> void:
	var ring := PackedVector2Array()
	var radius := 22-tension*4
	for index: int in 41:
		var angle := index*TAU/40.0
		ring.append(at+Vector2(cos(angle)*radius,sin(angle)*radius*0.36))
	draw_polyline(ring,Color(DARK,alpha),6,true)
	draw_polyline(ring,Color(tint,alpha),3,true)
	for sign: int in [-1,1]:
		draw_circle(at+Vector2(radius*sign,0),2,Color(GOLD,alpha))

func _clasp(at: Vector2, alpha: float, age: float) -> void:
	var size := Vector2(17,16)*(1+sin(clampf(age/0.18,0,1)*PI)*0.18)
	var shackle := PackedVector2Array()
	for index: int in 17:
		var angle := PI+index*PI/16.0
		shackle.append(at+Vector2(cos(angle)*6,sin(angle)*7-4))
	draw_polyline(shackle,Color(GOLD,alpha),3,true)
	_lock_box.bg_color = Color(Color("c65355"),alpha)
	_lock_box.border_color = Color(GOLD,alpha)
	draw_style_box(_lock_box,Rect2(at-size*0.5,size))
	draw_circle(at,2,Color(DARK,alpha))
	draw_line(at,at+Vector2(0,4),Color(DARK,alpha),2,true)
	var flash := 1-smoothstep(0,0.16,age)
	for index: int in 6:
		var ray := Vector2.from_angle(index*TAU/6)
		draw_line(at+ray*15,at+ray*25,Color(GOLD,alpha*flash),2,true)

func _echo(at: Vector2, tint: Color, alpha: float, age: float) -> void:
	var ring := PackedVector2Array()
	var fade := 1-smoothstep(0,0.36,age)
	for index: int in 41:
		var angle := index*TAU/40.0
		ring.append(at+Vector2(cos(angle),sin(angle)*0.45)*(22+age*65))
	draw_polyline(ring,Color(tint,alpha*fade),2,true)

func _restore() -> void:
	if _restored:
		return
	_restored = true
	var board: MainBoard = _board_ref.get_ref() if _board_ref!=null else null
	if board!=null:
		for id: int in _saved:
			var view: Node2D = board._pawn_views.get(id)
			if view!=null and view.z_index==36:
				view.z_index = int(_saved[id])

func cancel() -> void:
	_restore()
	_complete = true
	queue_free()

func _exit_tree() -> void:
	_restore()
