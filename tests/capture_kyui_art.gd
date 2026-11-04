## Native game and inspection gallery, using the real pawn/augment renderers.
extends "res://tests/capture_darts_integration.gd"

func _initialize() -> void:
	pass

func label(parent: Node,text: String,at: Vector2,box: Vector2,px: int) -> void:
	var view := Label.new()
	view.text = text
	view.position = at
	view.size = box
	view.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	view.add_theme_font_size_override("font_size",px)
	view.add_theme_color_override("font_color",Color("292a31"))
	parent.add_child(view)

func _run() -> void:
	MatchTelemetry.test_sender = func(_url: String,_body: PackedByteArray,_type: String) -> void: pass
	_board._on_draft_auto_pressed()
	await settle(15)
	quiet()
	_board.instant_roll_for_test = true
	var samples: Array[PlayerPawn] = []
	var tiles := [3,8,13,19]
	for player: int in [1,2,3,4]:
		var pawn: PlayerPawn = _board.state.pawns_of(player)[0]
		pawn.evolve(GameEnums.PawnKind.ARCADE,6)
		pawn.place_at(tiles[player-1])
		pawn.has_left_start = true
		pawn.skill_used = false
		samples.append(pawn)
	_board._refresh_all()
	_board._roll_button.hide()
	var tip := _board.get_node_or_null("FirstMatchTip") as CanvasLayer
	if tip != null: tip.hide()
	await settle(16)
	await snap("kyui-board")
	var texture: Texture2D = PawnArt.sprite(samples[0]).texture
	_expect(texture.resource_path.ends_with("MOB_KYUI_V01.png"),"native board uses the Cuee character")
	for pawn: PlayerPawn in samples:
		var token: PawnToken = _board._pawn_views[pawn.entity_id].find_child("Token",true,false) as PawnToken
		_expect(token!=null and token.artwork.texture==texture,"native owner token uses character sprite")
	# Exercise the existing skill action; artwork must survive its state refresh.
	_board.manager.current_turn_index = _board.manager.player_order.find(samples[0].owner_id)
	_board.manager.change_state(TurnManager.State.PHASE_TURN_BEGIN)
	quiet()
	var skill_events: Array = []
	_board.manager.event_received.connect(func(kind: StringName,data: Dictionary) -> void:
		if kind==&"skill_used": skill_events.append(data))
	_board._start_skill(samples[0])
	await settle(20)
	_expect(not skill_events.is_empty() and StringName(skill_events[0].get("skill",&""))==&"cucumber","native skill action succeeds")
	_expect(_board.state.board.get_tile(samples[0].current_tile_idx).attachments.any(func(item: TileAttachment) -> bool: return item is TrapCucumber),"native skill installs a cucumber")
	_expect(PawnArt.sprite(samples[0]).texture==texture,"skill state keeps character artwork")
	await snap("kyui-after-skill")
	_board.hide()
	if tip != null and is_instance_valid(tip): tip.hide()
	var gallery := Control.new()
	root.add_child(gallery)
	var paper := ColorRect.new()
	paper.color = Color("f5efdf")
	paper.size = Vector2(1366,768)
	gallery.add_child(paper)
	label(gallery,"큐이 · 트릭컬 리바이브 캐릭터 특징 반영",Vector2(25,24),Vector2(1316,50),31)
	var portrait := TextureRect.new()
	portrait.texture = ImageTexture.create_from_image(Image.load_from_file(capture_out.path_join("kyui-generated-source.png")))
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = Vector2(30,100)
	portrait.size = Vector2(510,565)
	gallery.add_child(portrait)
	label(gallery,"새 캐릭터 이미지",Vector2(40,685),Vector2(500,40),23)
	label(gallery,"게임 말 확대",Vector2(580,125),Vector2(350,42),24)
	# Inspection gallery omits ready bolts; the actual board capture keeps them.
	for pawn: PlayerPawn in samples: pawn.skill_used = true
	for i: int in 4:
		var token := PawnToken.new()
		token.configure(samples[i],MainBoard.PLAYER_COLORS[i+1])
		token.position = Vector2(604+i*88,365)
		token.scale = Vector2.ONE*2.6
		gallery.add_child(token)
	label(gallery,"보드 위 실제 크기",Vector2(580,425),Vector2(350,42),24)
	for i: int in 4:
		var token := PawnToken.new()
		token.configure(samples[i],MainBoard.PLAYER_COLORS[i+1])
		token.position = Vector2(645+i*62,535)
		gallery.add_child(token)
	var emblem := AugmentArt.make_texture(texture,180)
	emblem.position = Vector2(1030,245)
	gallery.add_child(emblem)
	label(gallery,"증강 이미지",Vector2(990,460),Vector2(260,42),24)
	label(gallery,"붉은 머리띠 · 갈색 단발 · 초록 눈 · 흰 날개 · 오이",Vector2(560,615),Vector2(750,80),19)
	await settle(16)
	await snap("kyui-game-preview")
	for failure: String in _failures: printerr("KYUI_ART_FAIL ",failure)
	print("KYUI_ART_NATIVE ",_failures.size()," failures")
	MatchTelemetry.test_sender = Callable()
	quit(0 if _failures.is_empty() else 1)
