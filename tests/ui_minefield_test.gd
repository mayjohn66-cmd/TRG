## SUPER_04 only, through the actual engine and deferred draft queue.
extends "res://tests/ui_super_fx_test.gd"

var seen: Array[StringName] = []
var shots: Dictionary = {}
var stage_started := false
var checked_end := false
var stagger_seen := false
var rng_at_stage := 0
var targets: Array[int] = []
var card_events := 0
var observe := true

func _run() -> void:
	GameSession.mode = GameSession.MODE_AI
	GameSession.pace_scale = 1.0
	await _check(SuperAugments.MINEFIELD)
	_expect(seen==[&"warning",&"plant",&"armed"],"Warning, planting and armed handoff appear in order")
	_expect(stagger_seen,"Mines land one at a time instead of simultaneously")
	_expect(checked_end,"The completed stage leaves only the normal trap tiles")
	_expect(card_events==SuperAugments.minefield_trap_cards(),"Only the engine grants the configured trap card count")
	observe = false
	await _check_scheduling_and_cancel()
	if _failures.is_empty():
		print("UI_MINEFIELD_OK")
		quit(0)
	else:
		for failure: String in _failures:
			printerr("UI_MINEFIELD_FAIL: "+failure)
		quit(1)

func _stage(effect: StringName) -> void:
	super._stage(effect)
	_board.ai_mode = false
	_board._bot.set_enabled(false)
	_board.manager.set_process(false)
	_board.state.card_drawn.connect(func(owner: int, _card: StringName) -> void:
		if observe and owner==1:
			card_events += 1)

func _process(_delta: float) -> bool:
	if not observe or _board==null or not is_instance_valid(_board):
		return false
	var stage: Node2D = _board.get_node_or_null("MinefieldStage")
	if stage!=null:
		if not stage_started:
			stage_started = true
			rng_at_stage = _board.state.rng.state
			targets.assign(stage.tiles)
			_expect(targets.size()==SuperAugments.minefield_count(),"Only the engine-selected mine tiles are animated")
			_expect(not stage.artwork.is_empty(),"Planting uses the existing illustrated mine")
			_expect(stage._floor.get_parent()==_board._board_layer,"Warning ink stays on the floor below board pieces")
		if not seen.has(stage.phase):
			seen.append(stage.phase)
		if stage.landed.size()==1 and targets.size()>1:
			stagger_seen = true
		_expect(_board.state.rng.state==rng_at_stage,"Presentation never consumes simulation RNG")
		_expect(not _board._draw_fx.busy(),"Trap-card delivery waits for planting to finish")
		_board._refresh_tiles()
		for tile: int in targets:
			var attachments: Array = _board.state.board.get_tile(tile).attachments
			_expect(attachments.size()==1 and attachments[0] is TrapMine and attachments[0].owner_id==1,"No duplicate mine is created by the visuals")
			_expect(attachments[0].is_hidden_trap,"The presentation preserves hidden-trap rules")
			var view: BoardSkin.Tile = _board._tile_views[tile]
			if not stage.armed.has(tile):
				_expect(_board._trap_pending.has(tile) and not view.trap_on,"Pending mines remain hidden until armed, including across UI refresh")
			else:
				_expect(not _board._trap_pending.has(tile) and view.trap_on,"Only an armed mine hands off to the regular trap tile")
		if stage.elapsed>0.31 and stage.phase==&"warning":
			capture("warning")
		if stage.elapsed>stage.WARNING_END+stage.DROP_TIME-0.04:
			capture("impact")
		if stage.elapsed>stage.arm_time(0)-0.10:
			capture("bury")
		if stage.phase==&"armed":
			capture("armed")
	elif stage_started and not checked_end:
		checked_end = true
		_expect(_board._board_layer.get_node_or_null("MinefieldFloorInk")==null,"Temporary warning ink is removed after completion")
		for tile: int in targets:
			_expect(not _board._trap_pending.has(tile),"All completed mine holds are released")
			_expect(not _board._structure_views.has(tile),"Hidden mines do not become persistent public mine models")
	return false

func _check_scheduling_and_cancel() -> void:
	_board = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	root.add_child(_board)
	var guard := 0
	while (not _board._draft_open or _board._intro_blocks()) and guard<2400:
		guard += 1
		await process_frame
	_stage(SuperAugments.MINEFIELD)
	_board._super_changes.clear()
	_board._draft_deferred.clear()
	SuperAugments.apply(SuperAugments.MINEFIELD,_board.state,1)
	var placed: Array[int] = []
	for change: Dictionary in _board._super_changes:
		if change.get("kind")=="place":
			placed.append(int(change.tile))
	_expect(placed.size()==SuperAugments.minefield_count(),"The rule chooses the configured mine count")
	var reveal_steps: Array = _board._draft_deferred.filter(func(entry: Dictionary) -> bool: return entry.has("trap_tile"))
	_expect(reveal_steps.size()==placed.size(),"Generic trap reveal steps are tagged before the super stage takes ownership")
	# Preserve another pick's reveal, even if it happens to refer to the same tile.
	_board._draft_deferred.append({"step":func() -> void: pass,"pawn":-1,"pick":999,"trap_tile":placed[0]})
	var augment_id: StringName = &""
	for definition: AugmentDef in AugmentRegistry.all():
		if definition.category==GameEnums.AugmentCategory.SUPER_GAMBLE and definition.payload==SuperAugments.MINEFIELD:
			augment_id = definition.augment_id
	_board._on_super_picked(1,augment_id)
	reveal_steps = _board._draft_deferred.filter(func(entry: Dictionary) -> bool: return entry.has("trap_tile"))
	_expect(reveal_steps.size()==1 and int(reveal_steps[0].pick)==999,"Only this pick's duplicate trap effects are removed")
	_board._reset_presentation()
	for interrupted_at: float in [0.25,1.05,1.90]:
		var stage := SuperFX.MINEFIELD_STAGE.new()
		_board.add_child(stage)
		stage.play(_board,placed,1.0)
		stage.elapsed = interrupted_at
		await process_frame
		await process_frame
		_board._reset_presentation()
		_board._trap_pending[placed[0]] = true
		await process_frame
		await process_frame
		await process_frame
		_expect(not is_instance_valid(stage),"Reset cancels warnings, moving mines and arming")
		_expect(_board._board_layer.get_node_or_null("MinefieldFloorInk")==null,"Reset removes all temporary floor artwork")
		_expect(_board._trap_pending.has(placed[0]),"A cancelled stage preserves a newer tile reveal hold")
		_expect(not _board._trap_pending.has(placed[1]),"The cancelled stage releases its own remaining tile holds")
		_board._trap_pending.erase(placed[0])
	await _drop_board()

func capture(label: String) -> void:
	var folder := OS.get_environment("MINEFIELD_CAPTURE_DIR")
	if folder=="" or shots.has(label):
		return
	shots[label] = true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))
