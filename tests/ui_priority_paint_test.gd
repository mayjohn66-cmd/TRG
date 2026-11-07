## Priority art integration: native texture contracts, actual revenge move,
## pooled flame cleanup and a sniper target under an offset/scaled pawn layer.
extends "res://tests/ui_super_fx_test.gd"

func _capture(tag: String) -> void:
	var folder := OS.get_environment("PRIORITY_CAPTURE_DIR")
	if folder.is_empty(): return
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(folder.path_join(tag+".png"))==OK,"Save "+tag)

func _run() -> void:
	for texture: Texture2D in [PaintedFx.FLAME,PaintedFx.IMPACT,PaintedFx.LIGHTNING]:
		_expect(texture.get_width()<=512 and texture.get_height()<=512,"Priority textures have bounded runtime size")
		var image := texture.get_image()
		_expect(image.get_pixel(0,0).a<0.01 and not image.is_empty(),"Actual sprite has transparent padding")
	for pair: Array in [[Vector2(80,20),Vector2(100,310)],[Vector2(500,80),Vector2(210,280)],[Vector2(40,350),Vector2(510,120)]]:
		var strike := PaintedFx.lightning(pair[0],pair[1],Color.RED)
		var top := strike.transform*(PaintedFx.LIGHTNING.get_size()*PaintedFx.LIGHTNING_TOP-strike.region_rect.position+strike.offset)
		var bottom := strike.transform*(PaintedFx.LIGHTNING.get_size()*PaintedFx.LIGHTNING_BOTTOM-strike.region_rect.position+strike.offset)
		_expect(top.distance_to(pair[0])<0.01 and bottom.distance_to(pair[1])<0.01,"Lightning core lands on both actual endpoints")
		strike.free()
	GameSession.mode = GameSession.MODE_AI
	GameSession.pace_scale = 1.0
	_board = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	_board.instant_roll_for_test = true
	root.add_child(_board)
	await process_frame
	_board._bot.set_enabled(false)
	_board.ai_mode = false
	_board.manager.set_process(false)
	_board.manager._draft_offers.clear()
	_board.manager._draft_picks.clear()
	_board.manager._begin_turn()
	_board._close_draft_overlay()
	_board._close_opening()
	_board._intro_pending = false
	_board._announcer.cancel()
	_board._announced_round = _board.state.round_number
	_board.pacing_enabled = false
	_board._reset_presentation()
	_board.state.boost_gimmicks = true
	_board.state.clear_npcs()
	for pawn: PlayerPawn in _board.state.pawns: pawn.reset_to_start()
	var pawn: PlayerPawn = _board.state.get_pawn(11)
	pawn.revenge_boost = true
	_board._refresh_all()
	_board.instant_roll_for_test = false
	await process_frame
	_expect(not _board.find_children("RevengeFire","Control",true,false).is_empty(),"Charged pawn shows the painted profile flame")
	await _capture("revenge-ready")
	var ctx := RuleContext.new()
	ctx.state = _board.state
	ctx.actor_id = 1
	ctx.dice_value = 7
	ctx.raw_roll = 7
	var bonus := MoveExecutor.revenge_bonus_of(pawn,_board.state)
	MoveExecutor.execute(_board.state,pawn,ctx)
	var rng := _board.state.rng.state
	var clock := Engine.time_scale
	var start := Time.get_ticks_msec()
	var saw_flame := false
	var captured := false
	while _board._presentation_active() and Time.get_ticks_msec()-start<12000:
		for node: Node in get_nodes_in_group(MainBoard.ONESHOT_FX_GROUP):
			if node.get_meta(FxPool.KIND_META,&"")==&"rocket_flame":
				saw_flame = true
				_expect(node is Sprite2D and node.texture==PaintedFx.FLAME,"Actual revenge move uses the flame cutout")
				if not captured and _board.presentation_label=="_play_rocket":
					captured = true
					await _capture("revenge-launch")
		_expect(_board.state.rng.state==rng and Engine.time_scale==clock,"Revenge rendering leaves game RNG and clock unchanged")
		await process_frame
	_expect(saw_flame and not _board._presentation_active(),"Revenge burst plays and releases the move queue")
	_expect(pawn.current_tile_idx==bonus+7 and not pawn.revenge_boost,"Existing booster then dice movement remains authoritative")
	await create_timer(0.6).timeout
	_expect(_board._fx_pool.idle_count(&"rocket_flame")>0,"Flames return to the bounded pool")
	var created := _board._fx_pool.created
	_board._rocket_puff(Vector2(600,300),Vector2.LEFT)
	_expect(_board._fx_pool.created==created,"A subsequent flame reuses the pool")
	_board.sweep_oneshot_fx(true)
	_board.instant_roll_for_test = true
	_board._rocket_puff(Vector2.ZERO)
	_expect(_board._fx_pool.created==created,"Effects-off allocates no rocket flames")
	_board.instant_roll_for_test = false
	# A resized/translated board must not separate the reticle, bullet and target.
	_board.set_process(false)
	var target: PlayerPawn = _board.state.get_pawn(21)
	target.has_left_start = true
	target.current_tile_idx = 12
	var view: Node2D = _board._pawn_views[21]
	view.position = _board._pawn_position(target)
	view.visible = true
	_board._pawn_layer.position += Vector2(70,30)
	_board._pawn_layer.scale = Vector2.ONE*1.12
	var stage := preload("res://scenes/sniper_stage.gd").new()
	_board.add_child(stage)
	stage.play(_board,1,21,1,{"position":view.position})
	stage.set_process(false)
	stage._process(stage.SHOT_AT+0.02)
	var expected := _board._pawn_layer.to_global(view.position+Vector2(0,-20))
	_expect(stage.to_global(stage._at).distance_to(expected)<0.1,"Sniper effect follows an offset/scaled target layer")
	_expect(stage._tracer.visible and stage._tracer.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Traveling tracer appears without blocking input")
	_expect(stage._veil.get_global_rect().grow(0.1).encloses(Rect2(Vector2.ZERO,root.get_visible_rect().size)),"Focus veil covers the viewport when offset: "+str(stage._veil.get_global_rect()))
	stage._process(0.12)
	_expect(not stage._tracer.visible,"Tracer expires after arrival")
	stage.cancel()
	await process_frame
	_expect(_board.get_node_or_null("SniperStage")==null,"Cancel clears the tracer and focus veil")
	await _drop_board()
	if _failures.is_empty():
		print("UI_PRIORITY_PAINT_OK")
		quit(0)
	else:
		for failure: String in _failures: printerr("UI_PRIORITY_PAINT_FAIL: "+failure)
		quit(1)
