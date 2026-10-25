## SUPER_08 only: one pawn launch and the successful, reserved reward stream.
extends "res://tests/ui_super_fx_test.gd"

var shots: Dictionary = {}
var seen: Array[StringName] = []
var started := false
var ended := false
var observing := true
var receiver := 1
var no_waiting := false
var full_hand := false
var rng_before := 0
var hand_snapshot: Dictionary = {}
var planned: Array[Dictionary] = []
var delivered := 0
var grants: Array[Dictionary] = []
var saw_face := false
var saw_back := false

func _run() -> void:
	GameSession.mode = GameSession.MODE_AI
	GameSession.pace_scale = 1.0
	await _check(SuperAugments.BAKERY)
	_expect(started and ended and delivered==4 and grants.size()==4,"Three rewards and the bakery arrival reward each land once")
	_expect(saw_face and seen==[&"spot",&"dash",&"approach",&"enter",&"rummage",&"escape",&"deliver",&"finish"],"Local rewards follow entry, the indoor commotion and escape")
	await _edge(2,true,false,false)
	_expect(saw_back and delivered==3,"No waiting pawn: only three real remote rewards, face down")
	await _edge(1,false,true,false)
	_expect(delivered==0 and grants.is_empty(),"A full hand invents no reward cards")
	await _edge(1,false,false,true)
	if _failures.is_empty():
		print("UI_BAKERY_OK")
		quit(0)
	else:
		for failure: String in _failures:
			printerr("UI_BAKERY_FAIL: "+failure)
		quit(1)

func _stage(effect: StringName) -> void:
	super._stage(effect)
	_board.ai_mode = true
	_board.local_player_id = 1
	_board._bot.set_enabled(false)
	_board.manager.set_process(false)
	_board._super_changes.clear()
	for owner: int in _board.state.player_ids:
		(_board.state.hands[owner] as Array).clear()
	if full_hand:
		for index: int in GameEnums.MAX_HAND_SIZE:
			(_board.state.hands[receiver] as Array).append(&"ACT_02")
	if no_waiting:
		for pawn: PlayerPawn in _board.state.pawns_of(receiver):
			pawn.has_left_start = true
			pawn.current_tile_idx = 7+pawn.slot*2
			_board._pawn_views[pawn.entity_id].position = _board._pawn_position(pawn)
			_board._pawn_views[pawn.entity_id].show()
	_board._refresh_hands()
	_board.state.card_drawn.connect(func(owner: int,id: StringName) -> void: grants.append({"player":owner,"id":id}))
	_board._draw_fx.landed.connect(func(_owner: int,_local: bool) -> void: delivered += 1)

func _process(_delta: float) -> bool:
	if not observing or _board==null or not is_instance_valid(_board):
		return false
	var stage: Node2D = _board.get_node_or_null("BakeryStage")
	if stage!=null:
		if not started:
			started = true
			rng_before = _board.state.rng.state
			hand_snapshot = _board.state.hands.duplicate(true)
			planned.assign(stage.jobs)
			_expect(stage.artwork.get("model")=="Minimi_Erpin","The extracted original minimi replaces the static avatar cutout")
			_expect((stage.pawn_id==-1)==no_waiting,"A launch exists only for an actual waiting pawn")
			_expect(stage.jobs.size()==grants.size(),"Only successfully granted cards are reserved")
		if not seen.has(stage.phase):
			seen.append(stage.phase)
		_expect(_board.state.rng.state==rng_before and _board.state.hands==hand_snapshot,"Presentation changes neither RNG nor granted hands")
		if stage.elapsed<stage.HAUL_END:
			_expect(stage.launched.is_empty(),"Rewards wait until Erpin has escaped")
		if stage.phase==&"rummage":
			_expect(stage._actor_alpha==0.0,"Erpin is completely inside during the commotion")
		if stage.phase==&"escape":
			_expect(stage.commotions==4,"All four indoor impacts happen before the escape")
			if stage.phase_time>0.48:
				capture("escape_mid")
		if stage.phase_time>0.14 and receiver==1 and not full_hand:
			capture(String(stage.phase))
		var draw: Dictionary = _board._draw_fx._current
		if not draw.is_empty():
			_expect(not bool(draw.from_deck) and (draw.origin as Vector2).distance_to(_board.get_global_transform()*stage._at)<0.1,"A bakery reward comes from the actual bakery tile")
			_expect(int(draw.player)==receiver and draw.id==stage.jobs[stage._current].id,"The shown card is the exact successful grant")
			if bool(draw.local) and bool(draw.face):
				saw_face = true
				capture("reward_face")
			if not bool(draw.local):
				saw_back = true
				_expect(not bool(draw.face),"Other players' reward faces stay hidden")
	elif started and not ended:
		ended = true
		_expect(delivered==planned.size(),"All reserved rewards land once")
		_expect(not _board._draw_fx.busy() and int(_board._draw_fx.pending.get(receiver,0))==0,"No hidden hand reservation remains")
	return false

func _edge(owner: int, no_pawn: bool, is_full: bool, cancel: bool) -> void:
	receiver = owner
	no_waiting = no_pawn
	full_hand = is_full
	started = false
	ended = false
	delivered = 0
	planned.clear()
	grants.clear()
	seen.clear()
	_board = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	root.add_child(_board)
	var guard := 0
	while (not _board._draft_open or _board._intro_blocks()) and guard<2400:
		guard += 1
		await process_frame
	_stage(SuperAugments.BAKERY)
	_board._draft_deferred.clear()
	SuperAugments.apply(SuperAugments.BAKERY,_board.state,receiver)
	_board._on_super_picked(receiver,SuperAugments.BAKERY)
	_expect(_board._draft_deferred.all(func(entry: Dictionary) -> bool: return not entry.has("draw_job")),"Bakery rewards do not replay as duplicate generic draws")
	_board._draft_open = false
	_board._release_draft_deferred()
	var start := Time.get_ticks_msec()
	while _board._presentation_active() and Time.get_ticks_msec()-start<12000:
		await process_frame
		if cancel and _board._draw_fx.busy():
			var hand := _board.state.hands.duplicate(true)
			observing = false
			_board._reset_presentation()
			await process_frame
			await process_frame
			_expect(_board.get_node_or_null("BakeryStage")==null and not _board._draw_fx.busy() and _board._draw_fx.pending.is_empty(),"Reset clears both the stage and undelivered reservations")
			_expect(_board.state.hands==hand,"Visual reset never duplicates or undoes grants")
			break
	if not cancel:
		_expect(ended and not _board._presentation_active(),"The edge-case presentation finishes")
	await _drop_board()
	observing = true

func capture(label: String) -> void:
	var folder := OS.get_environment("BAKERY_CAPTURE_DIR")
	if folder.is_empty() or shots.has(label):
		return
	shots[label] = true
	_save.call_deferred(folder,label)

func _save(folder: String,label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))
