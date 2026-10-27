## SUPER_09: close on the real target, hold lock, trace one shot and release.
## Only presentation time is slowed; the game clock and RNG are never touched.
extends Node2D

const LOCK_START := 0.56
const SHOT_AT := 1.02
const HIT_AT := 1.07
const TOTAL_TIME := 1.23
const RED := Color("ff655c")
const GOLD := Color("ffe4a2")
const FOCUS_SHADER := preload("res://assets/fx/sniper_focus.gdshader")
const TRACER_SHADER := preload("res://assets/fx/bang_tracer.gdshader")
var phase: StringName = &"acquire"
var elapsed := 0.0
var pace := 1.0
var target_id := -1
var fired := false
var hit_started := false
var _complete := false
var _board_ref: WeakRef
var _view_ref: WeakRef
var _generation := 0
var _at := Vector2.ZERO
var _source := Vector2.ZERO
var _saved: Dictionary = {}
var _restored := false
var _lock_played := false
var _veil: ColorRect
var _light: ShaderMaterial
var _tracer: ColorRect
var _tracer_material: ShaderMaterial

func play(board: MainBoard, player_id: int, target: int, speed: float, pose: Dictionary) -> void:
	name = "SniperStage"
	z_index = 35
	_board_ref = weakref(board)
	_generation = board._fx_generation
	transform = board._pawn_layer.transform
	pace = clampf(speed,0.35,2.0)
	target_id = target
	var view: Node2D = board._pawn_views.get(target_id)
	if view==null:
		_complete = true
		return
	board._kill_fx(view)
	_view_ref = weakref(view)
	_saved = {"position":view.position,"scale":view.scale,"rotation":view.rotation,"tint":view.modulate,"z":view.z_index,"visible":view.visible}
	_at = (pose.get("position",view.position) as Vector2)+Vector2(0,-20)
	view.position = _at+Vector2(0,20)
	view.z_index = 36
	var origin := board._profile_center(player_id)
	var local_origin := to_local(origin) if origin.is_finite() else _at+Vector2(-240,100)
	_source = _at+_at.direction_to(local_origin)*220.0
	_veil = ColorRect.new()
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.z_index = -1
	_light = ShaderMaterial.new()
	_light.shader = FOCUS_SHADER
	_veil.material = _light
	add_child(_veil)
	_tracer = ColorRect.new()
	_tracer.name = "SniperTracer"
	_tracer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tracer.visible = false
	_tracer_material = ShaderMaterial.new()
	_tracer_material.shader = TRACER_SHADER
	_tracer.material = _tracer_material
	add_child(_tracer)
	_update_veil(board)
	Sfx.play(&"charge",-10.0)

func _process(delta: float) -> void:
	if _board_ref==null or _complete:
		return
	var board: MainBoard = _board_ref.get_ref()
	if board==null or board._fx_generation!=_generation:
		cancel()
		return
	transform = board._pawn_layer.transform
	elapsed += delta/pace
	phase = &"acquire" if elapsed<LOCK_START else (&"locked" if elapsed<SHOT_AT else &"impact")
	if elapsed>=LOCK_START and not _lock_played:
		_lock_played = true
		Sfx.play(&"toy_click",-8.0)
	if elapsed>=SHOT_AT and not fired:
		fired = true
		Sfx.play(&"shot",-5.0)
	if elapsed>=HIT_AT and not hit_started:
		hit_started = true
		board.screen_shake(4.5,0.12*pace)
	var view: Node2D = _view_ref.get_ref()
	if view!=null:
		var hit := clampf((elapsed-HIT_AT)/0.14,0,1) if hit_started else 0.0
		var recoil := sin(hit*PI)
		view.scale = (_saved.scale as Vector2)*Vector2(1+0.13*recoil,1-0.10*recoil)
		view.modulate = (_saved.tint as Color).lerp(Color(1.8,1.5,1.15),recoil*0.65)
	_update_veil(board)
	_update_tracer()
	queue_redraw()
	if elapsed>=TOTAL_TIME:
		_restore(false)
		_complete = true
		set_process(false)

func _update_veil(board: MainBoard) -> void:
	var frame := get_viewport_rect().size
	_veil.position = to_local(Vector2.ZERO)
	_veil.size = frame / global_transform.get_scale().abs()
	var focus := get_global_transform()*_at
	_light.set_shader_parameter("frame_size",frame)
	_light.set_shader_parameter("focus",focus)
	_light.set_shader_parameter("strength",smoothstep(0,0.22,elapsed)*(1-smoothstep(HIT_AT,TOTAL_TIME,elapsed)))

func _update_tracer() -> void:
	var angle := _source.angle_to_point(_at)
	var length := _source.distance_to(_at)
	_tracer.position = _source-Vector2(0,12).rotated(angle)
	_tracer.rotation = angle
	_tracer.size = Vector2(maxf(length,1),24)
	_tracer.visible = fired and elapsed < HIT_AT+0.045
	_tracer_material.set_shader_parameter("age",maxf(0,elapsed-SHOT_AT))
	_tracer_material.set_shader_parameter("travel_time",HIT_AT-SHOT_AT)
	_tracer_material.set_shader_parameter("distance_px",maxf(length,1))

func _draw() -> void:
	if _view_ref==null:
		return
	var close := 1.0-pow(1.0-clampf(elapsed/LOCK_START,0,1),3.0)
	var radius := lerpf(96.0,30.0,close)
	var fade := smoothstep(0,0.12,elapsed)*(1-smoothstep(HIT_AT,HIT_AT+0.12,elapsed))
	var drift := Vector2(sin(elapsed*5)*7,cos(elapsed*6)*5)*(1-close)
	var center := _at+drift
	var tint := RED.lerp(GOLD,smoothstep(LOCK_START,SHOT_AT,elapsed)*0.4)
	# A quiet opening between each reticle quadrant keeps the pawn readable.
	for quadrant: int in 4:
		var angle := quadrant*PI/2+PI/12
		draw_arc(center,radius,angle,angle+PI/3,16,Color(tint,fade),2.2,true)
		var direction := Vector2.from_angle(quadrant*PI/2)
		draw_line(center+direction*(radius+4),center+direction*(radius+14),Color(tint,fade),2,true)
		draw_line(center+direction*9,center+direction*17,Color(GOLD,fade*0.8),1.5,true)
	if phase==&"locked":
		var u := clampf((elapsed-LOCK_START)/(SHOT_AT-LOCK_START),0,1)
		draw_arc(center,radius+5,-PI/2,-PI/2+TAU*u,40,Color(GOLD,fade*0.55),1.5,true)
	if hit_started:
		var u := clampf((elapsed-HIT_AT)/0.14,0,1)
		var alpha := 1-smoothstep(0.03,0.16,elapsed-HIT_AT)
		PaintedFx.stamp(self,PaintedFx.IMPACT,_at,Vector2.ONE*(34+u*42),Color(GOLD,alpha*0.9),_source.angle_to_point(_at))

func _restore(cancelled: bool) -> void:
	if _restored:
		return
	_restored = true
	var view: Node2D = _view_ref.get_ref() if _view_ref!=null else null
	if view!=null:
		view.scale = _saved.scale
		view.rotation = float(_saved.rotation)
		view.modulate = _saved.tint
		view.z_index = int(_saved.z)
		if cancelled:
			var board: MainBoard = _board_ref.get_ref() if _board_ref!=null else null
			var pawn: PlayerPawn = board.state.get_pawn(target_id) if board!=null else null
			if pawn!=null:
				view.position = board._pawn_position(pawn)
				view.visible = pawn.has_left_start and not pawn.is_finished and pawn.carrier==null

func cancel() -> void:
	_restore(true)
	_complete = true
	queue_free()

func _exit_tree() -> void:
	if not _complete:
		_restore(true)
