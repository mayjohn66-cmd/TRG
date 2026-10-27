## SUPER_08: Erpin enters, causes a commotion, escapes with bread, then delivers real rewards.
extends Node2D

const ART = preload("res://scenes/bakery_art.gd")
const SPOT_TIME := 0.28
const DASH_END := 0.84
const APPROACH_END := 1.44
const ENTER_END := 1.80
const RUMMAGE_END := 3.02
const HAUL_END := 4.00
const FINISH_TIME := 0.32
const IMPACTS := [0.10,0.34,0.65,0.97]
const GOLD := Color("ffd267")
const BACKGROUND_DIM := 0.78
var phase: StringName = &"spot"
var elapsed := 0.0
var phase_time := 0.0
var pace := 1.0
var player_id := -1
var tile := -1
var pawn_id := -1
var jobs: Array[Dictionary] = []
var launched: Array[Dictionary] = []
var completed := 0
var artwork: Dictionary = {}
var commotions := 0
var _complete := false
var _board_ref: WeakRef
var _view_ref: WeakRef
var _generation := 0
var _at := Vector2.ZERO
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _shop_at := Vector2.ZERO
var _door := Vector2.ZERO
var _actor_at := Vector2.ZERO
var _actor_alpha := 0.0
var _actor_height := 88.0
var _shop_offset := Vector2.ZERO
var _shop_angle := 0.0
var _saved: Dictionary = {}
var _restored := false
var _current := -1
var _bread_haul: Sprite2D

func play(board: MainBoard, owner: int, changes: Array, speed: float) -> void:
	name = "BakeryStage"
	z_index = 35  # The pawn's relocation stays behind the cutaway's dimming layer.
	_board_ref = weakref(board)
	_generation = board._fx_generation
	player_id = owner
	pace = clampf(speed,0.35,2.0)
	artwork = {"texture":ART.MOVE,"model":"Minimi_Erpin"}
	for change: Dictionary in changes:
		if change.get("kind")=="bakery_scene":
			tile = int(change.tile)
			pawn_id = int(change.pawn)
			_to = change.position
			jobs.assign(change.jobs)
	_at = board._tile_center(tile) if tile>=0 else board._board_center()
	_from = board._tile_center(GameEnums.GOAL_TILE)
	_shop_at = board._board_center()+Vector2(-12,100)
	# Measured against the painted doorway's dark opening and doorstep.
	_door = _shop_at+Vector2(30,-34)
	var view: Node2D = board._pawn_views.get(pawn_id)
	if view!=null:
		board._kill_fx(view)
		_view_ref = weakref(view)
		_saved = {"scale":view.scale,"rotation":view.rotation,"z":view.z_index,"tint":view.modulate}
		view.position = _from
		view.hide()
	_bread_haul = Sprite2D.new()
	_bread_haul.texture = ART.BREAD_HAUL
	_bread_haul.region_enabled = true
	_bread_haul.region_rect = Rect2(ART.BREAD_REGION.position*ART.BREAD_HAUL.get_size(),ART.BREAD_REGION.size*ART.BREAD_HAUL.get_size())
	_bread_haul.hide()
	add_child(_bread_haul)
	board._refresh_hands()
	Sfx.play(&"charge",-9.0)

func _process(delta: float) -> void:
	if _board_ref==null or _complete:
		return
	var board: MainBoard = _board_ref.get_ref()
	if board==null or board._fx_generation!=_generation:
		cancel()
		return
	elapsed += delta/pace
	phase_time += delta/pace
	match phase:
		&"spot":
			if elapsed>=SPOT_TIME:
				_set_phase(&"dash")
				Sfx.play(&"hop",-4.0)
		&"dash":
			if elapsed>=DASH_END:
				_set_phase(&"approach")
				_restore(false)
		&"approach":
			if elapsed>=APPROACH_END:
				_set_phase(&"enter")
				Sfx.play(&"bakery_door",-11.0,0.02)
		&"enter":
			if elapsed>=ENTER_END:
				_set_phase(&"rummage")
		&"rummage":
			while commotions<IMPACTS.size() and elapsed-ENTER_END>=float(IMPACTS[commotions]):
				Sfx.play(&"bakery_rummage",-7.0,0.05)
				commotions += 1
				if commotions==IMPACTS.size():
					board.screen_shake(2.5,0.10*pace)
			if elapsed>=RUMMAGE_END:
				_set_phase(&"escape")
				Sfx.play(&"dash",-8.0)
		&"escape":
			if elapsed>=HAUL_END:
				_next_reward(board)
		&"deliver":
			if not board._draw_fx.busy():
				completed += 1
				_next_reward(board)
		&"finish":
			if phase_time>=FINISH_TIME:
				_complete = true
				set_process(false)
	_update_pose()
	queue_redraw()

func _set_phase(next_phase: StringName) -> void:
	phase = next_phase
	phase_time = 0.0

func _next_reward(board: MainBoard) -> void:
	_current += 1
	if _current>=jobs.size():
		_set_phase(&"finish")
		Sfx.play(&"good",-7.0)
		return
	var job: Dictionary = jobs[_current]
	var origin := board.get_global_transform()*_at if tile>=0 else Vector2(INF,INF)
	board._launch_drawn_card(int(job.player),job.id,bool(job.local),int(job.index),origin,jobs.size()>1)
	launched.append(job.duplicate(true))
	_set_phase(&"deliver")

func _update_pose() -> void:
	var jump := smoothstep(SPOT_TIME,DASH_END,elapsed)
	var view: Node2D = _view_ref.get_ref() if _view_ref!=null else null
	if view!=null and not _restored:
		# The cutaway owns the action; don't show a second pawn leaping behind it.
		view.visible = false
		view.z_index = 27
		view.position = _from.lerp(_to,jump)+Vector2(0,-115*sin(jump*PI))
		view.rotation = sin(jump*PI)*0.18
		view.scale = (_saved.scale as Vector2)*(1.0+0.12*sin(jump*PI))
	_actor_alpha = 0.0
	_actor_height = 88.0
	_shop_offset = Vector2.ZERO
	_shop_angle = 0.0
	if phase in [&"spot",&"dash",&"approach"]:
		var run := smoothstep(DASH_END,APPROACH_END,elapsed)
		_actor_at = (_shop_at+Vector2(-210,12)).lerp(_door+Vector2(0,25),run)
		_actor_alpha = smoothstep(SPOT_TIME,DASH_END,elapsed)
	elif phase==&"enter":
		var enter := smoothstep(APPROACH_END,ENTER_END,elapsed)
		_actor_at = (_door+Vector2(0,25)).lerp(_door+Vector2(0,-9),enter)
		_actor_height = lerpf(88,65,enter)
		_actor_alpha = 1-smoothstep(0.55,0.98,enter)
	elif phase==&"rummage":
		for impact: float in IMPACTS:
			var age := elapsed-ENTER_END-impact
			if age>=0 and age<0.24:
				var kick := pow(1-age/0.24,2)
				_shop_offset += Vector2(sin(age*90)*4,-sin(age*55)*2)*kick
				_shop_angle += sin(age*65)*0.018*kick
	elif phase==&"escape":
		var escape := clampf((elapsed-RUMMAGE_END)/(HAUL_END-RUMMAGE_END),0,1)
		var emerge := smoothstep(0,0.23,escape)
		var flee := pow(clampf((escape-0.16)/0.84,0,1),1.35)
		_actor_at = _door.lerp(_shop_at+Vector2(240,32),flee)
		_actor_height = lerpf(65,88,emerge)
		_actor_alpha = emerge*(1-smoothstep(0.85,1,escape))
	_bread_haul.visible = phase==&"escape" and _actor_alpha>0.01
	var carry_scale := _actor_height/88.0
	var bob := ART.move_bob(elapsed-DASH_END,_actor_height)
	_bread_haul.position = _actor_at+Vector2(18*carry_scale,-31*carry_scale+bob)
	_bread_haul.scale = Vector2.ONE*(54.0*carry_scale/_bread_haul.region_rect.size.x)
	_bread_haul.rotation = 0.06
	_bread_haul.modulate.a = _actor_alpha

func _floor_glint(at: Vector2, tint: Color) -> void:
	PaintedFx.stamp(self,PaintedFx.RIPPLE,at,Vector2(76,37),tint)

func _draw() -> void:
	if tile<0:
		return
	var fade := 1.0-smoothstep(0,FINISH_TIME,phase_time) if phase==&"finish" else 1.0
	var reveal := smoothstep(0,SPOT_TIME,elapsed)
	var story := reveal*(1-smoothstep(HAUL_END-0.14,HAUL_END+0.22,elapsed))
	if story>0.001:
		draw_rect(get_viewport_rect(),Color(0.025,0.022,0.035,BACKGROUND_DIM*story))
		ART.storefront(self,_shop_at+_shop_offset,280,story,_shop_angle)
	if elapsed<HAUL_END:
		_floor_glint(_at,Color(GOLD,0.55*reveal))
	# The character is absent inside, then emerges from the same doorway.
	if _actor_alpha>0.001:
		var running := phase in [&"approach",&"enter",&"escape"]
		ART.erpin(self,_actor_at,elapsed-DASH_END,_actor_height,_actor_alpha*story,running,1,0.06 if phase==&"escape" else 0.0)
	if phase==&"rummage":
		for index: int in IMPACTS.size():
			var age := elapsed-ENTER_END-float(IMPACTS[index])
			if age>=0 and age<0.48:
				var u := age/0.48
				var side := -1.0 if index%2==0 else 1.0
				var at := _door+Vector2(side*(10+u*42),-17-u*23)
				ART.flour(self,at,lerpf(10,38,u),sin(u*PI)*0.8*story,side*u*0.5)
	if phase==&"escape":
		var age := elapsed-RUMMAGE_END
		if age<0.50:
			var u := age/0.50
			ART.flour(self,_door+Vector2(-8-u*20,-8),18+u*39,(1-u)*0.6*story,-u*0.2)
		for index: int in 3:
			var u := clampf((age-0.25-index*0.09)/0.34,0,1)
			if u>0 and u<1:
				ART.flour(self,_actor_at+Vector2(-27-index*12,2),7+u*12,sin(u*PI)*0.4*story,-0.3)
	if phase==&"finish":
		_floor_glint(_at,Color(GOLD,fade*0.35))

func _restore(cancelled: bool) -> void:
	if _restored and not cancelled:
		return
	_restored = true
	var view: Node2D = _view_ref.get_ref() if _view_ref!=null else null
	var board: MainBoard = _board_ref.get_ref() if _board_ref!=null else null
	if view!=null:
		view.position = _to
		view.visible = true
		view.scale = _saved.scale
		view.rotation = float(_saved.rotation)
		view.z_index = int(_saved.z)
		view.modulate = _saved.tint
		if cancelled and board!=null:
			var pawn: PlayerPawn = board.state.get_pawn(pawn_id)
			if pawn!=null:
				view.position = board._pawn_position(pawn)
				view.visible = pawn.has_left_start and not pawn.is_finished and pawn.carrier==null
	if board!=null:
		board._fx_hints.erase(pawn_id)

func cancel() -> void:
	_restore(true)
	_complete = true
	queue_free()

func _exit_tree() -> void:
	if not _complete:
		_restore(true)
