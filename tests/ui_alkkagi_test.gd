extends SceneTree
var started := false
var failures: Array[String] = []

func _process(_delta: float) -> bool:
	if not started:
		started = true
		run()
	return false

func check(value: bool,message: String) -> void:
	if not value:
		failures.append(message)

func frames(count: int) -> void:
	for index: int in count:
		await process_frame

func capture(name: String) -> void:
	var directory := OS.get_environment("ALKKAGI_CAPTURE_DIR")
	if directory=="":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(name+".png"))

func arrange(state: GameState) -> PlayerPawn:
	state.clear_npcs()
	for pawn: PlayerPawn in state.pawns:
		pawn.reset_to_start()
		pawn.skill_used = false
	var shooter: PlayerPawn = state.get_pawn(11)
	shooter.kind = GameEnums.PawnKind.GO
	shooter.unit_no = 1
	shooter.has_left_start = true
	shooter.current_tile_idx = 12
	for pair: Vector2i in [Vector2i(21,13),Vector2i(31,14),Vector2i(41,15),Vector2i(12,2)]:
		var pawn: PlayerPawn = state.get_pawn(pair.x)
		pawn.has_left_start = true
		pawn.current_tile_idx = pair.y
	var guarded: PlayerPawn = state.get_pawn(41)
	guarded.kind = GameEnums.PawnKind.GO
	guarded.unit_no = 2
	guarded.shield = true
	return shooter

func mouse(stage: AlkkagiStage,point: Vector2,pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = pressed
	stage.handle_input(event)

func drag(stage: AlkkagiStage,point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	stage.handle_input(event)

func run() -> void:
	create_timer(40).timeout.connect(func() -> void: printerr("ALKKAGI_FAIL timeout");quit(1))
	var state := GameState.new()
	state.setup([1,2,3,4],12345)
	var shooter := arrange(state)
	var stage := AlkkagiStage.new()
	root.add_child(stage)
	await frames(2)
	stage.set_process(false)
	var calculate := func(angle: float,power: float) -> Dictionary: return PawnSkills.shot_result(state,shooter,angle,power)
	stage.open_aim(AlkkagiStage.snapshot(state,shooter,MainBoard.PLAYER_COLORS),11,calculate)
	var fired: Array = []
	stage.shot_requested.connect(func(angle: float,power: float) -> void: fired.append([angle,power]))
	var start := stage.to_screen(stage.origin)
	mouse(stage,start,true)
	drag(stage,start+Vector2(100,0)*stage.layout_scale())
	check(absf(absf(stage.angle)-PI)<0.001,"Dragging right aims left in board coordinates")
	check((stage.preview.hits as Array).has(21) and (stage.preview.hits as Array).has(31),"Preview finds the two aligned enemies")
	check(not (stage.preview.hits as Array).has(41) and not (stage.preview.hits as Array).has(12),"Preview excludes shielded and allied stones")
	mouse(stage,start+Vector2(100,0)*stage.layout_scale(),false)
	mouse(stage,start,false)
	check(fired.size()==1,"Release fires once; duplicate release is ignored")
	check(not shooter.skill_used and state.get_pawn(21).has_left_start,"Presentation and preview never mutate the game")
	var shot := calculate.call(PI,0.7) as Dictionary
	stage.play_shot(AlkkagiStage.snapshot(state,shooter,MainBoard.PLAYER_COLORS),11,shot,0.7,1.0)
	var saw_hold := false
	var frozen := false
	var previous_speed := -1.0
	var initial_speed := -1.0
	var slow_speed := -1.0
	for tick: int in 700:
		var before := stage.stone
		var was_hold := stage.hold_seconds>0.0
		stage.advance(1.0/120.0)
		if was_hold:
			saw_hold = true
			frozen = frozen or stage.stone==before
		if stage.mode==&"slide" and not was_hold:
			previous_speed = before.distance_to(stage.stone)
			if initial_speed<0.0:
				initial_speed = previous_speed
			slow_speed = previous_speed
		if stage.mode==&"idle":
			break
	check(stage.impacts==[21,31],"Contacts occur once each in spatial order")
	check(saw_hold and frozen and Engine.time_scale==1.0,"Local hit-stop freezes stones without changing global time")
	check(initial_speed>slow_speed and stage.stone.distance_to(shot.to)<0.001,"Stone decelerates and stops at the authoritative endpoint")
	check(stage.mode==&"idle" and not stage.visible,"Stage closes and releases presentation")
	stage.open_aim(AlkkagiStage.snapshot(state,shooter,MainBoard.PLAYER_COLORS),11,calculate)
	mouse(stage,start,true)
	mouse(stage,start+Vector2.ONE,false)
	check(fired.size()==1,"A tiny drag does not consume or fire the skill")
	var touch := InputEventScreenTouch.new()
	touch.position = start
	touch.pressed = true
	stage.handle_input(touch)
	touch.pressed = false
	touch.canceled = true
	stage.handle_input(touch)
	check(not stage.dragging and fired.size()==1,"OS-cancelled touch cannot fire")
	touch.canceled = false
	touch.pressed = true
	stage.handle_input(touch)
	var touch_drag := InputEventScreenDrag.new()
	touch_drag.position = start+Vector2(90,0)*stage.layout_scale()
	stage.handle_input(touch_drag)
	touch.position = touch_drag.position
	touch.pressed = false
	stage.handle_input(touch)
	check(fired.size()==2,"A normal touch drag and release submits one shot")
	var miss := calculate.call(PI/2.0,0.5) as Dictionary
	stage.play_shot(AlkkagiStage.snapshot(state,shooter,MainBoard.PLAYER_COLORS),11,miss,0.5,1.0)
	for tick: int in 700:
		stage.advance(1.0/120.0)
	check(stage.impacts.is_empty() and stage.mode==&"idle","A missed shot decelerates and closes without false contact")
	stage.cancel()
	stage.queue_free()
	await frames(1)
	GameSession.mode = GameSession.MODE_AI
	GameSession.pace_scale = 1.0
	var board: MainBoard = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	board.instant_roll_for_test = true
	root.add_child(board)
	await frames(4)
	board.ai_mode = false
	board._bot.set_enabled(false)
	board._on_draft_auto_pressed()
	board._announcer.cancel()
	board.pacing_enabled = false
	await frames(6)
	board._reset_presentation()
	board._announcer.cancel()
	board.manager.set_process(false)
	shooter = arrange(board.state)
	board.state.tools[1] = ToolRegistry.create(&"D6")
	board._refresh_all()
	board.instant_roll_for_test = false
	board._begin_aim(shooter)
	await frames(2)
	stage = board._alkkagi
	start = stage.to_screen(stage.origin)
	mouse(stage,start,true)
	drag(stage,start+Vector2(110,0)*stage.layout_scale())
	await capture("aim")
	if OS.get_environment("ALKKAGI_CAPTURE_DIR")!="":
		await frames(28)
		root.size = Vector2i(844,390)
		await frames(3)
		check(not stage.dragging and stage.power==0.0,"Resize cancels the held gesture without firing")
		var mobile_start := stage.to_screen(stage.origin)
		mouse(stage,mobile_start,true)
		drag(stage,mobile_start+Vector2(110,0)*stage.layout_scale())
		await capture("aim_mobile")
		root.size = Vector2i(1366,768)
		await frames(3)
	check(board._ui_busy(),"Aiming blocks other game actions")
	board._cancel_aim()
	check(board._aim_pawn==-1 and not stage.visible and not shooter.skill_used,"Cancel restores input without consuming the skill")
	board._begin_aim(shooter)
	mouse(stage,start,true)
	drag(stage,start+Vector2(110,0)*stage.layout_scale())
	mouse(stage,start+Vector2(110,0)*stage.layout_scale(),false)
	check(shooter.skill_used and not board.state.get_pawn(21).has_left_start,"Releasing submits one real engine skill")
	var saw_slide := false
	var saw_impact := false
	for frame: int in 1200:
		if stage.mode==&"slide" and not saw_slide:
			saw_slide = true
			await capture("slide")
		if stage.hold_seconds>0.0 and not saw_impact:
			saw_impact = true
			await capture("impact")
		if stage.mode==&"done":
			await capture("settle")
			break
		await process_frame
	check(saw_slide and saw_impact,"Real skill waits for the visible slide and contact stages")
	for frame: int in 1100:
		if not board._presentation_active() and stage.mode==&"idle":
			break
		await process_frame
	check(not board._presentation_active() and stage.mode==&"idle" and not stage.visible,"Alkkagi completes before the queued board settlement and captures finish")
	await capture("result")
	stage.play_shot(AlkkagiStage.snapshot(board.state,shooter,MainBoard.PLAYER_COLORS),11,shot,0.7,1.0)
	board._reset_presentation()
	check(stage.mode==&"idle" and not stage.visible,"Reset safely cancels an active stage")
	board.instant_roll_for_test = true
	board._capture_cutin.cancel()
	board._announcer.cancel()
	await frames(3)
	if failures.is_empty():
		print("ALKKAGI_OK")
	else:
		for failure: String in failures:
			printerr("ALKKAGI_FAIL "+failure)
	quit(0 if failures.is_empty() else 1)
