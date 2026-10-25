## Only SUPER_05: successful/empty victims, local/remote delivery, full-hand returns.
extends "res://tests/ui_super_fx_test.gd"

var shots: Dictionary = {}
var seen: Array[StringName] = []
var started := false
var ended := false
var observing := true
var thief := 1
var full_hand := false
var rng_before := 0
var hands_before_visual: Dictionary = {}
var grants: Array[Dictionary] = []
var planned_jobs: Array[Dictionary] = []
var delivered := 0
var saw_local_face := false
var saw_remote_back := false
var checked_sources: Array[int] = []
var visits: Array[int] = []
var cutin_finished := false

func _run() -> void:
	GameSession.mode = GameSession.MODE_AI
	GameSession.pace_scale = 1.0
	await _check(SuperAugments.RAID)
	_expect(started and ended,"Raid owns the reserved reward stream from start to finish")
	_expect(visits==[2,4],"Only actual successful victims are raided; an empty hand is skipped")
	_expect(saw_local_face,"Local stolen cards use the real reveal and hand delivery")
	_expect(delivered==3,"Support and stolen cards each arrive once")
	_expect(seen.has(&"cutin") and seen.has(&"arrive") and seen.has(&"snatch") and seen.has(&"finish"),"Cut-in, arrival, snatch and escape stages are visible")
	await _edge_case(2,false,false)
	_expect(saw_remote_back,"A remote receiver's cards remain face down")
	await _edge_case(2,true,false)
	await _edge_case(1,false,true)
	await _edge_case(1,false,true,true)
	if _failures.is_empty():
		print("UI_RAID_OK")
		quit(0)
	else:
		for failure: String in _failures:
			printerr("UI_RAID_FAIL: "+failure)
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
	# Two victims have cards; P3 is empty. Unique IDs expose ordering mistakes.
	(_board.state.hands[1] as Array).append(&"ACT_02")
	(_board.state.hands[2] as Array).append(&"ACT_02")
	(_board.state.hands[4] as Array).append(&"ACT_02")
	if full_hand:
		(_board.state.hands[thief] as Array).clear()
		for _index: int in GameEnums.MAX_HAND_SIZE:
			(_board.state.hands[thief] as Array).append(&"ACT_02")
	_board._refresh_hands()
	_board.state.card_drawn.connect(func(owner: int, card: StringName) -> void:
		grants.append({"player":owner,"id":card}))
	_board._draw_fx.landed.connect(func(_owner: int, _local: bool) -> void: delivered += 1)

func _process(_delta: float) -> bool:
	if not observing or _board==null or not is_instance_valid(_board):
		return false
	var stage: Node2D = _board.get_node_or_null("RaidStage")
	if stage!=null:
		if not started:
			started = true
			rng_before = _board.state.rng.state
			hands_before_visual = _board.state.hands.duplicate(true)
			planned_jobs.assign(stage.jobs)
			_expect(not stage.artwork.is_empty(),"The raid uses the existing illustrated robber")
			if full_hand:
				_expect(stage.jobs.is_empty() and stage.victims.is_empty(),"A full recipient invents neither rewards nor successful victims")
				_expect(int(_board._draw_fx.pending.get(1,0))==0,"Restored local victim cards do not retain fake arrival reservations")
		if not seen.has(stage.phase):
			seen.append(stage.phase)
		if stage.phase==&"cutin":
			_expect(stage.launched.is_empty() and not _board._draw_fx.busy(),"The cut-in clears before any reward or theft launches")
			_expect(is_instance_valid(stage._cutin) and stage._cutin.visible,"The raid owns a visible cut-in during its opening")
			if stage.phase_time>0.30 and stage.phase_time<0.80:
				capture("cutin_impact")
			if stage.phase_time>0.94:
				capture("cutin_exit")
		else:
			cutin_finished = true
			_expect(not is_instance_valid(stage._cutin),"No cut-in remains over the theft or delivery")
		_expect(_board.state.rng.state==rng_before,"Presentation consumes no simulation RNG")
		_expect(_board.state.hands==hands_before_visual,"Presentation changes no hand contents")
		if stage.phase==&"snatch" and not stage.current.is_empty():
			_expect(cutin_finished,"Theft follows the finished cut-in")
			var source := int(stage.current.source)
			if not visits.has(source):
				visits.append(source)
			_expect(source!=3,"An empty hand is never shown losing a card")
			if stage.phase_time>0.10:
				capture("snatch_p%d" % source)
		var draw: Dictionary = _board._draw_fx._current
		if not draw.is_empty():
			_expect(int(draw.player)==thief,"Only the actual receiver is shown receiving raid rewards")
			_expect(draw.id==stage.current.id,"The shown card matches the exact successful grant")
			var source := int(stage.current.source)
			if not checked_sources.has(stage._index):
				checked_sources.append(stage._index)
				if source>=0:
					_expect(not bool(draw.from_deck) and (draw.origin as Vector2).distance_to(_board._profile_center(source))<0.1,"A stolen card leaves its real victim's profile")
				else:
					_expect(bool(draw.from_deck),"The summon reward comes from the table-side deck")
			if bool(draw.local) and bool(draw.face):
				saw_local_face = true
				capture("local_reveal")
			if not bool(draw.local):
				_expect(not bool(draw.face),"Other players' card identities stay hidden")
				saw_remote_back = true
			if source>=0 and float(draw.time)>0.16:
				capture("stolen_flight_p%d" % source)
		if stage.phase==&"finish":
			_expect(stage.completed==stage.jobs.size() and stage.launched.size()==stage.jobs.size(),"Every claimed reward launches and lands once")
	elif started and not ended:
		ended = true
		_expect(not _board._draw_fx.busy() and int(_board._draw_fx.pending.get(thief,0))==0,"No card delivery or reservation remains after the raid")
	return false

func _edge_case(receiver: int, is_full: bool, cancel: bool, cancel_cutin: bool = false) -> void:
	thief = receiver
	full_hand = is_full
	started = false
	ended = false
	planned_jobs.clear()
	grants.clear()
	visits.clear()
	checked_sources.clear()
	delivered = 0
	cutin_finished = false
	_board = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	root.add_child(_board)
	var guard := 0
	while (not _board._draft_open or _board._intro_blocks()) and guard<2400:
		guard += 1
		await process_frame
	_stage(SuperAugments.RAID)
	_board._draft_deferred.clear()
	_board._super_changes.clear()
	var initial_hands := _board.state.hands.duplicate(true)
	SuperAugments.apply(SuperAugments.RAID,_board.state,receiver)
	var definition_id: StringName = &""
	for definition: AugmentDef in AugmentRegistry.all():
		if definition.category==GameEnums.AugmentCategory.SUPER_GAMBLE and definition.payload==SuperAugments.RAID:
			definition_id = definition.augment_id
	_board._on_super_picked(receiver,definition_id)
	_expect(_board._draft_deferred.all(func(entry: Dictionary) -> bool: return not entry.has("draw_job")),"Raid deliveries and compensation returns do not replay as generic draws")
	if is_full:
		_expect(_board.state.hands==initial_hands,"Failed steals restore each original hand")
	_board._draft_open = false
	_board._release_draft_deferred()
	var t0 := Time.get_ticks_msec()
	while _board._presentation_active() and Time.get_ticks_msec()-t0<12000:
		await process_frame
		var live_stage := _board.get_node_or_null("RaidStage")
		var in_cutin: bool = live_stage!=null and live_stage.phase==&"cutin" and live_stage.phase_time>0.30
		if cancel and (in_cutin if cancel_cutin else _board._draw_fx.busy()):
			var snapshot := _board.state.hands.duplicate(true)
			observing = false
			_board._reset_presentation()
			for frame: int in 12:
				await process_frame
			_expect(_board.get_node_or_null("RaidStage")==null,"Reset removes the raid without delayed callbacks")
			_expect(not _board._draw_fx.busy() and _board._draw_fx.pending.is_empty(),"Reset clears active and future raid deliveries")
			_expect(_board.state.hands==snapshot,"Resetting visuals neither duplicates nor undoes card grants")
			break
	if not cancel:
		_expect(ended and not _board._presentation_active(),"Remote and full-hand raids finish normally")
		_expect(delivered==planned_jobs.size(),"Every successful remote reward arrives once; returned cards do not animate")
	await _drop_board()
	observing = true

func capture(label: String) -> void:
	var folder := OS.get_environment("RAID_CAPTURE_DIR")
	if folder=="" or shots.has(label):
		return
	shots[label] = true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))
