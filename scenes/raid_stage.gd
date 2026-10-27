## SUPER_05: cue the actual reward stream, never grant or fabricate cards.
extends Node2D

const CUTIN = preload("res://scenes/raid_cutin.gd")
const INTRO_TIME := 0.14
const SNATCH_TIME := 0.22
const END_TIME := 0.30
var elapsed := 0.0
var phase_time := 0.0
var pace := 1.0
var phase: StringName = &"cutin"
var player_id := -1
var jobs: Array[Dictionary] = []
var launched: Array[Dictionary] = []
var victims: Array[int] = []
var completed := 0
var current: Dictionary = {}
var artwork: Dictionary = {}
var _complete := false
var _board_ref: WeakRef
var _generation := 0
var _index := -1
var _cutin: Control
var _cutin_layer: CanvasLayer
var _impact_played := false
var _exit_played := false

func play(board: MainBoard, owner: int, rewards: Array[Dictionary], speed: float) -> void:
	name = "RaidStage"
	z_index = 24 # Below the existing card reveal; above profiles and the board.
	_board_ref = weakref(board)
	_generation = board._fx_generation
	player_id = owner
	jobs.assign(rewards)
	pace = clampf(speed,0.35,2.0)
	artwork = PawnArt.load_sprite(["res://content_trickcal/illustrations/pawns/NPC_ROBBER.png"])
	for job: Dictionary in jobs:
		if int(job.source)>=0 and int(job.source)!=player_id and not victims.has(int(job.source)):
			victims.append(int(job.source))
	board._refresh_hands()
	_cutin_layer = CanvasLayer.new()
	_cutin_layer.name = "RaidCutinPresentation"
	_cutin_layer.layer = 55
	add_child(_cutin_layer)
	_cutin = CUTIN.new()
	_cutin_layer.add_child(_cutin)
	Sfx.play(&"dash",-7.0)

func _process(delta: float) -> void:
	if _board_ref==null:
		return
	var board: MainBoard = _board_ref.get_ref()
	if board==null or board._fx_generation!=_generation:
		queue_free()
		return
	elapsed += delta/pace
	phase_time += delta/pace
	match phase:
		&"cutin":
			_cutin.seek(phase_time)
			if phase_time>=CUTIN.IMPACT_AT and not _impact_played:
				_impact_played = true
				Sfx.play(&"card_impact",-4.0)
				Sfx.play(&"cutin_slash",-10.0,0.0)
			if phase_time>=CUTIN.EXIT_AT and not _exit_played:
				_exit_played = true
				Sfx.play(&"card_throw",-6.0)
			if phase_time>=CUTIN.DURATION:
				_cutin_layer.queue_free()
				_cutin = null
				_set_phase(&"arrive")
		&"arrive":
			if phase_time>=INTRO_TIME:
				_next()
		&"support",&"snatch":
			if phase_time>=(SNATCH_TIME if phase==&"snatch" else 0.10):
				var source := int(current.source)
				var origin := board._profile_center(source) if source>=0 and source!=player_id else Vector2(INF,INF)
				board._launch_drawn_card(int(current.player),current.id,bool(current.local),int(current.index),origin,jobs.size()>1)
				launched.append(current.duplicate(true))
				if phase==&"snatch":
					Sfx.play(&"toy_click",-4.0)
				_set_phase(&"deliver")
		&"deliver":
			if not board._draw_fx.busy():
				completed += 1
				_next()
		&"finish":
			if phase_time>=END_TIME:
				_complete = true
				set_process(false)
	queue_redraw()

func _set_phase(next_phase: StringName) -> void:
	phase = next_phase
	phase_time = 0.0

func _next() -> void:
	_index += 1
	if _index>=jobs.size():
		current = {}
		_set_phase(&"finish")
		return
	current = jobs[_index]
	_set_phase(&"snatch" if int(current.source)>=0 and int(current.source)!=player_id else &"support")

func _profile_rect(board: MainBoard, owner: int) -> Rect2:
	if not board._profiles.has(owner):
		return Rect2()
	var panel: Control = board._profiles[owner].panel
	if not panel.is_visible_in_tree():
		return Rect2()
	var frame := get_global_transform().affine_inverse()*panel.get_global_transform()
	return frame*Rect2(Vector2.ZERO,panel.size)

func _border(rect: Rect2, tint: Color, alpha: float) -> void:
	if rect.size==Vector2.ZERO or alpha<=0.0:
		return
	var rim := StyleBoxFlat.new()
	rim.bg_color = Color(tint,alpha*0.10)
	rim.border_color = Color(tint,alpha*0.90)
	rim.set_border_width_all(3)
	rim.set_corner_radius_all(14)
	draw_style_box(rim,rect.grow(3))

func _robber(at: Vector2, alpha: float, scale_factor: float = 1.0) -> void:
	if artwork.is_empty() or alpha<=0.0:
		return
	var region: Rect2 = artwork.region
	var size := region.size*minf(58.0/region.size.x,64.0/region.size.y)*scale_factor
	draw_texture_rect_region(artwork.texture,Rect2(at+Vector2(-size.x/2.0,-size.y),size),region,Color(1,1,1,alpha))

func _draw() -> void:
	if _board_ref==null:
		return
	var board: MainBoard = _board_ref.get_ref()
	if board==null:
		return
	if phase==&"cutin":
		return
	var receiver := _profile_rect(board,player_id)
	if phase==&"arrive" or phase==&"finish":
		var amount := smoothstep(0.0,INTRO_TIME,phase_time) if phase==&"arrive" else 1.0-smoothstep(0.0,END_TIME,phase_time)
		_border(receiver,Color("a879dd") if phase==&"arrive" else Color("ffd06b"),amount*0.8)
		if phase==&"arrive":
			var at := board._board_center()+Vector2(0,26)
			_robber(at+Vector2(0,12*(1-amount)),amount,1.22)
		return
	if current.is_empty():
		return
	var source := int(current.source)
	var theft := source>=0 and source!=player_id
	var extracting := phase==&"snatch" or (phase==&"deliver" and phase_time<0.38)
	if theft and extracting:
		var victim := _profile_rect(board,source)
		if victim.size!=Vector2.ZERO:
			var inside := 1.0 if victim.get_center().x<board._board_center().x else -1.0
			var foot := Vector2(victim.end.x+24 if inside>0 else victim.position.x-24,victim.end.y-10)
			var enter := smoothstep(0.0,SNATCH_TIME,phase_time) if phase==&"snatch" else 1.0-smoothstep(0.10,0.38,phase_time)
			_border(victim,Color("d18bf0"),enter)
			_robber(foot+Vector2(-inside*18*(1-enter),-5*sin(enter*PI)),enter)
			# A brief curved gold swipe follows the card leaving this exact profile.
			if phase==&"deliver":
				var u := clampf(phase_time/0.32,0.0,1.0)
				var previous := victim.get_center()+Vector2(inside*u*25,-u*25)
				for index: int in range(1,12):
					var t := index/11.0
					var at := victim.get_center()+Vector2(inside*(t*72+u*25),-sin(t*PI)*18-u*25)
					PaintedFx.streak(self,previous,at,4.5*(1-t)+1.2,Color(1,0.78,0.33,(1-u)*0.70))
					previous = at
				PaintedFx.stamp(self,PaintedFx.FLECK,previous,Vector2(9,5)*(1-u),Color(1,0.92,0.69,(1-u)*0.8),-inside*0.4)
	if phase==&"deliver":
		var draw: Dictionary = board._draw_fx._current
		if not draw.is_empty():
			var card: Control = draw.card
			if card.get_meta("phase",&"") in [&"hand",&"deliver_back"]:
				_border(receiver,Color("ffd06b"),0.7)
