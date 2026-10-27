## Presentation coordinates only, using the shipping canvas stretch and phone aspects.
extends SceneTree

var board: MainBoard
var failures: Array[String] = []
var errors: Dictionary = {}
var measurements := 0
var phone := Vector2i(844,390)

func _initialize() -> void:
	run.call_deferred()

func frames(count: int = 2) -> void:
	for index: int in count: await process_frame

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func near(label: String, actual: Vector2, expected: Vector2) -> void:
	var pixels := actual.distance_to(expected)*float(root.size.x)/root.get_visible_rect().size.x
	measurements += 1
	errors[label] = maxf(float(errors.get(label,0)),pixels)
	check(pixels<1.1,"%s offset %.2f screen px at %s" % [label,pixels,str(root.size)])

func capture(label: String) -> void:
	var folder := OS.get_environment("MOBILE_FX_CAPTURE_DIR")
	if folder.is_empty(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))

func window(size: Vector2i) -> void:
	root.size = size
	await frames()
	if board!=null: board.layout_for(root.get_visible_rect().size)

func fixture() -> void:
	board = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	board.instant_roll_for_test = true
	root.add_child(board)
	await frames()
	board._bot.set_enabled(false)
	board.manager.set_process(false)
	board.ai_mode = false
	board.pacing_enabled = false
	board._close_opening()
	board._on_draft_auto_pressed()
	await frames()
	board._reset_presentation()
	board._close_draft_overlay()
	board._close_augment_review()
	board._announcer.cancel()
	board.set_process(false)
	board.state.clear_npcs()
	for pawn: PlayerPawn in board.state.pawns: pawn.reset_to_start()
	for pair: Vector2i in [Vector2i(11,3),Vector2i(21,10),Vector2i(31,18),Vector2i(41,23)]:
		var pawn := board.state.get_pawn(pair.x)
		pawn.has_left_start = true
		pawn.current_tile_idx = pair.y
	board._refresh_all()
	board._roll_button.hide()
	board._roll_pad.hide()
	board.layout_for(root.get_visible_rect().size)
	await frames()

func stage(path: String) -> Node2D:
	var effect: Node2D = (load("res://scenes/"+path+".gd") as GDScript).new()
	board.add_child(effect)
	return effect

func drop(effect: Node) -> void:
	if effect.has_method("cancel"): effect.cancel()
	elif is_instance_valid(effect): effect.queue_free()
	await frames()
	board._announcer.cancel()
	board._refresh_all()
	board._roll_button.hide()
	board._roll_pad.hide()

func run() -> void:
	create_timer(100).timeout.connect(func() -> void: printerr("MOBILE_FX_FAIL timeout"); quit(1))
	root.content_scale_size = Vector2i(1366,768)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	await window(phone)
	await fixture()
	var rng_before := board.state.rng.state
	var clock_before := Engine.time_scale
	print("MOBILE_VIEWPORT ",root.size," logical=",root.get_visible_rect().size," board_offset=",board._off_center)
	await castling()
	await bakery()
	await bond()
	await bang()
	await gambler()
	await card_paths()
	await floor_and_focus()
	await world_and_profiles()
	await train_and_nitro()
	await duel_fit()
	check(board.state.rng.state==rng_before and Engine.time_scale==clock_before,"coordinate changes do not alter simulation RNG or the global clock")
	print("MOBILE_FX_MEASUREMENTS ",measurements," ",JSON.stringify(errors))
	board.queue_free()
	await frames()
	if failures.is_empty():
		print("MOBILE_FX_OK")
		quit(0)
	else:
		for failure: String in failures: printerr("MOBILE_FX_FAIL: "+failure)
		quit(1)

func castling() -> void:
	await window(phone)
	var effect := stage("castling_stage")
	var poses: Array = []
	for id: int in [11,21]:
		poses.append({"pawn":id,"position":board._pawn_views[id].position,"tile":board.state.get_pawn(id).current_tile_idx})
	effect.play(board,[{"kind":"castling_pose","pawns":poses}],1.0)
	effect.set_process(false)
	for size: Vector2i in [phone,Vector2i(740,360),phone]:
		await window(size)
		effect.elapsed = 1.0
		effect._process(0)
		for item: Dictionary in effect.pawns:
			near("castling source mark",effect.to_global(item.from),board._pawn_layer.to_global(item.from))
			var view: Node2D = item.view.get_ref()
			near("castling orbit and pawn",effect.to_global(view.position),view.global_position)
		await capture("castling_%d" % size.x)
	await drop(effect)

func bakery() -> void:
	await window(phone)
	var effect := stage("bakery_stage")
	effect.play(board,1,[{"kind":"bakery_scene","tile":10,"pawn":11,"position":board._pawn_position_at(board.state.get_pawn(11),10),"jobs":[]}],1.0)
	effect.set_process(false)
	for size: Vector2i in [phone,Vector2i(740,360)]:
		await window(size)
		effect.elapsed = 2.1
		effect.phase = &"rummage"
		effect._update_pose()
		var tile: Control = board._tile_views[10]
		near("bakery tile marker",effect.to_global(effect._at),tile.get_global_transform()*(tile.size*0.5))
		near("bakery storefront center",effect.to_global(effect._shop_at),board.get_global_transform()*(board._board_center()+Vector2(-12,100)))
		await capture("bakery_%d" % size.x)
	await drop(effect)

func bond() -> void:
	await window(phone)
	var effect := stage("bond_stage")
	effect.play(board,{"a":11,"b":21,"mode":&"bind"},1.0)
	effect.set_process(false)
	for size: Vector2i in [phone,Vector2i(740,360)]:
		await window(size)
		effect.elapsed = 0.95
		effect._process(0)
		near("bond first cuff",effect.to_global(effect._from-Vector2(0,3)),board._pawn_views[11].global_position)
		near("bond second cuff",effect.to_global(effect._to-Vector2(0,3)),board._pawn_views[21].global_position)
		await capture("bond_%d" % size.x)
	await drop(effect)

func bang() -> void:
	await window(phone)
	var effect := stage("bang_stage")
	effect.play(board,1,21,1.0)
	effect.set_process(false)
	var target: Node2D = board._pawn_views[21]
	for size: Vector2i in [phone,Vector2i(740,360),phone]:
		await window(size)
		effect.elapsed = 0.3
		effect._process(0)
		near("bang target",effect.to_global(effect._at),target.to_global(Vector2(0,-18)))
		check(effect._veil.size.is_equal_approx(root.get_visible_rect().size),"bang dimmer covers current mobile viewport")
		await capture("bang_%d" % size.x)
	effect.elapsed = effect.HIT_AT+0.01
	effect._process(0)
	await window(Vector2i(740,360))
	effect._process(0)
	near("bang resized tracer endpoint",effect._tracer.get_global_transform()*Vector2(effect._tracer.size.x,12),effect.to_global(effect._at))
	await capture("bang_impact_740")
	await drop(effect)

func gambler() -> void:
	await window(phone)
	var target: Control = board._tool_board
	var anchor := target.get_global_transform()*(target.size*0.5)
	var effect := stage("gambler_fx")
	effect.play(board,&"overheat",1,{},anchor,target,1.0)
	effect.set_process(false)
	for size: Vector2i in [phone,Vector2i(740,360)]:
		await window(size)
		effect.elapsed = 0.5
		effect._process(0)
		near("gambler target anchor",effect.to_global(effect._anchor),target.get_global_transform()*(target.size*0.5))
		await capture("gambler_%d" % size.x)
	await drop(effect)

func floor_and_focus() -> void:
	await window(phone)
	var mine := stage("minefield_stage")
	var targets: Array[int] = [3,10]
	mine.play(board,targets,1.0)
	mine.set_process(false)
	var sniper := stage("sniper_stage")
	sniper.play(board,1,21,1.0,{"position":board._pawn_views[21].position})
	sniper.set_process(false)
	for size: Vector2i in [phone,Vector2i(740,360)]:
		await window(size)
		mine._process(0)
		sniper._process(0)
		var tile: Control = board._tile_views[3]
		near("mine tile anchor",mine.to_global(mine._target(board,3)),tile.get_global_transform()*(tile.size*0.5))
		near("sniper focus",sniper.to_global(sniper._at+Vector2(0,20)),board._pawn_views[21].global_position)
	await drop(sniper)
	await drop(mine)

func card_paths() -> void:
	var draw := board._draw_fx
	draw.set_process(false)
	for local: bool in [false,true]:
		await window(phone)
		draw.clear()
		board._launch_drawn_card(1 if local else 2,&"ACT_02",local,0,Vector2(INF,INF))
		for size: Vector2i in [phone,Vector2i(740,360)]:
			await window(size)
			draw._apply_card(0)
			var card: Control = draw._current.card
			near("card deck origin",card.get_global_transform()*(card.size*0.5),draw.deck_position)
			if local:
				draw._apply_card(CardDrawFX.POP_TIME+CardDrawFX.TAKE_TIME+CardDrawFX.FLIP_HALF*2+0.10)
				near("card reveal center",card.get_global_transform()*(card.size*0.5),draw.reveal_position)
			else:
				draw._apply_card(CardDrawFX.POP_TIME+CardDrawFX.OTHER_FLY_TIME)
				near("card remote destination",card.get_global_transform()*(card.size*0.5),board._profile_center(2))
				check(not draw._current.face,"remote card stays face down on mobile")
			await capture("card_%s_%d" % ["local" if local else "remote",size.x])
	for origin_provider: Callable in [board._profile_center.bind(2),board._tile_card_origin.bind(10)]:
		await window(phone)
		draw.clear()
		board._launch_drawn_card(1,&"ACT_02",true,0,origin_provider.call(),false,origin_provider)
		for size: Vector2i in [phone,Vector2i(740,360)]:
			await window(size)
			draw._apply_card(0)
			var card: Control = draw._current.card
			near("card theft and bakery origin",card.get_global_transform()*(card.size*0.5),origin_provider.call())
	draw.clear()
	draw.set_process(true)

func world_and_profiles() -> void:
	await window(phone)
	var view: Node2D = board._pawn_views[11]
	var fx := SuperFX.new(board)
	fx._ring(view.position,Color.GOLD,40,2,4.0)
	var ring: Node2D = board._pawn_layer.get_node("PaintedPressure")
	var panel: Control = board._profiles[1].panel
	var colors: Array[Color] = [Color.GOLD,Color.ORANGE]
	SuperFX.set_flame(panel,"MobileAuditAura",colors,true)
	var aura: Control = panel.get_node("MobileAuditAura")
	var spotlight: ColorRect = (load("res://scenes/pawn_stage_spotlight.gd") as GDScript).new()
	board.add_child(spotlight)
	spotlight.illuminate(board,view,Color.GOLD,8.0)
	for size: Vector2i in [phone,Vector2i(740,360)]:
		await window(size)
		aura._process(0)
		spotlight._update_light()
		near("shared pressure ring",ring.global_position,view.global_position)
		near("profile aura origin",aura.get_global_transform().origin,panel.get_global_transform().origin)
		near("profile aura corner",aura.get_global_transform()*aura.size,panel.get_global_transform()*panel.size)
		near("spotlight pawn",spotlight.get_global_transform()*spotlight.material.get_shader_parameter("foot"),view.global_position)
		check(spotlight.size.is_equal_approx(root.get_visible_rect().size),"spotlight veil resizes to mobile viewport")
		await capture("spotlight_%d" % size.x)
	spotlight.queue_free()
	ring.queue_free()
	SuperFX.set_flame(panel,"MobileAuditAura",[],true)
	await frames()

func train_and_nitro() -> void:
	await window(phone)
	var route: Array[int] = [3,4,5,6]
	var train := board._train_stage
	train.play(route,1.0,board._train_plane)
	train.set_process(false)
	train.elapsed = train.run_start+0.25
	train.mode = &"run"
	train.front_distance = 0.10
	train.laid_count = train.segments.size()
	for segment: Node3D in train.segments: segment.show()
	for size: Vector2i in [phone,Vector2i(740,360)]:
		await window(size)
		train._update_pose()
		board._train_camera_step()
		train.sync_projection()
		for norm: Vector2 in [Vector2(0,0),Vector2(0.5,0.5),Vector2(1,0.4)]:
			var pixel := train.camera.unproject_position(Vector3(norm.x,0,norm.y))
			near("train rail projection",train.image.to_global(pixel),board._pawn_layer.to_global(board._project(norm)))
		await capture("train_%d" % size.x)
	train.cancel()
	board._train_camera_step()
	board.layout_for(root.get_visible_rect().size)
	var nitro := stage("nitro_stage")
	nitro.play(board,{"pawn":11,"path":route,"blocked":-1,"victims":{}},1.0)
	nitro.set_process(false)
	for size: Vector2i in [phone,Vector2i(740,360)]:
		await window(size)
		nitro.elapsed = nitro.DASH_START+nitro.dash_time*0.4
		nitro._process(0)
		var view: Node2D = board._pawn_views[11]
		near("nitro pawn and flame",nitro.to_global(view.position),view.global_position)
		near("nitro glow layer",nitro._glow.to_global(view.position),view.global_position)
		await capture("nitro_%d" % size.x)
	await drop(nitro)

func duel_fit() -> void:
	await window(phone)
	var rng := RandomNumberGenerator.new()
	rng.seed = 37
	for game: int in [DuelRules.Game.RPS,DuelRules.Game.HALLI,DuelRules.Game.CURLING,DuelRules.Game.QUICKDRAW,DuelRules.Game.ECARD,DuelRules.Game.BARREL]:
		var arena := DuelArena.new()
		arena.setup(board,1,2,[],game,DuelRules.setup_game(game,rng))
		board.add_child(arena)
		arena.visible = true
		arena._begin_game()
		arena.set_process(false)
		await frames()
		for size: Vector2i in [phone,Vector2i(740,360)]:
			await window(size)
			arena._place()
			near("duel center",arena.get_global_transform()*(arena.size*0.5),board._board_center())
			var rect := arena.get_global_rect()
			check(root.get_visible_rect().grow(-8).encloses(rect),"mobile duel and its child effects fit screen bounds")
			await capture("duel_%d_%d" % [game,size.x])
		arena.queue_free()
		await frames()
