## SUPER_08: actual pawn launch, Erpin's haul, then actual reserved rewards.
extends Node2D

const SPOT_TIME := 0.32
const DASH_END := 0.94
const HAUL_END := 1.40
const FINISH_TIME := 0.32
const GOLD := Color("ffd267")
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
var _complete := false
var _board_ref: WeakRef
var _view_ref: WeakRef
var _generation := 0
var _at := Vector2.ZERO
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _saved: Dictionary = {}
var _restored := false
var _current := -1
var _breads: Array[Sprite2D] = []

func play(board: MainBoard, owner: int, changes: Array, speed: float) -> void:
	name = "BakeryStage"
	z_index = 24
	_board_ref = weakref(board)
	_generation = board._fx_generation
	player_id = owner
	pace = clampf(speed,0.35,2.0)
	artwork = PawnArt.load_sprite(["res://content_trickcal/avatars/avatar_01/fullbody.png"])
	for change: Dictionary in changes:
		if change.get("kind")=="bakery_scene":
			tile = int(change.tile)
			pawn_id = int(change.pawn)
			_to = change.position
			jobs.assign(change.jobs)
	_at = board._tile_center(tile) if tile>=0 else board._board_center()
	_from = board._tile_center(GameEnums.GOAL_TILE)
	var view: Node2D = board._pawn_views.get(pawn_id)
	if view!=null:
		board._kill_fx(view)
		_view_ref = weakref(view)
		_saved = {"scale":view.scale,"rotation":view.rotation,"z":view.z_index,"tint":view.modulate}
		view.position = _from
		view.hide()
	var texture: Texture2D = BoardSkin.DECALS.bakery
	var ratio := texture.get_width()/1254.0
	var region := Rect2(Vector2(196,409)*ratio,Vector2(862,482)*ratio)
	var material := ShaderMaterial.new()
	material.shader = BoardSkin.FLAT_INK
	material.set_shader_parameter("ink",Color("d99b45"))
	for index: int in 4:
		var bread := Sprite2D.new()
		bread.texture = texture
		bread.region_enabled = true
		bread.region_rect = region
		bread.material = material
		bread.scale = Vector2.ONE*(28.0/region.size.x)
		bread.hide()
		add_child(bread)
		_breads.append(bread)
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
				_set_phase(&"haul")
				Sfx.play(&"thud",-6.0)
				_restore(false)
		&"haul":
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
		view.visible = elapsed>=SPOT_TIME
		view.z_index = 27
		view.position = _from.lerp(_to,jump)+Vector2(0,-115*sin(jump*PI))
		view.rotation = sin(jump*PI)*0.18
		view.scale = (_saved.scale as Vector2)*(1.0+0.12*sin(jump*PI))
	for index: int in _breads.size():
		var bread := _breads[index]
		var u := clampf((elapsed-DASH_END-index*0.045)/0.32,0,1)
		bread.visible = u>0 and u<1
		bread.position = _at.lerp(_at+Vector2(-56,-42),u)+Vector2((index-1.5)*18*sin(u*PI),-18-34*sin(u*PI))
		bread.rotation = (index-1.5)*0.4*u
		bread.modulate.a = sin(u*PI)

func _ellipse(at: Vector2, radius: Vector2, tint: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index: int in 49:
		var angle := index*TAU/48.0
		points.append(at+Vector2(cos(angle),sin(angle))*radius)
	draw_polyline(points,tint,width,true)

func _draw() -> void:
	if tile<0:
		return
	var fade := 1.0-smoothstep(0,FINISH_TIME,phase_time) if phase==&"finish" else 1.0
	var reveal := smoothstep(0,SPOT_TIME,elapsed)*fade
	_ellipse(_at,Vector2(35,17)*(1.0+sin(elapsed*4)*0.05),Color(GOLD,0.8*reveal),3)
	if elapsed<DASH_END:
		var u := clampf(elapsed/DASH_END,0,1)
		_ellipse(_at,Vector2(38,19)*(1.0+u*0.8),Color(GOLD,(1-u)*0.5),2)
	# Existing full-body Erpin cutout: a small, lively accomplice beside the tile.
	if not artwork.is_empty():
		var enter := smoothstep(SPOT_TIME,DASH_END,elapsed)
		var at := _at+Vector2(-66+12*(1-enter),-10-4*abs(sin(elapsed*7))*enter)
		var region: Rect2 = artwork.region
		var size := region.size*(92.0/region.size.y)
		draw_texture_rect_region(artwork.texture,Rect2(at+Vector2(-size.x/2,-size.y),size),region,Color(1,1,1,enter*fade))
		_ellipse(at+Vector2(0,3),Vector2(18,6),Color(0.35,0.22,0.08,enter*fade*0.25),2)
	if phase==&"haul":
		for index: int in 6:
			var angle := index*TAU/6.0
			var at := _at+Vector2(cos(angle)*42,sin(angle)*24-22)
			draw_line(at,at+Vector2(cos(angle),sin(angle))*9,Color(GOLD,sin(clampf(phase_time/0.46,0,1)*PI)*0.8),2,true)

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
