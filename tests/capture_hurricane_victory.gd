## LAW_09 art preview only. Never adds the law/cards to the live registry or hands.
extends "res://tests/capture_darts_integration.gd"
func _run() -> void:
	MatchTelemetry.test_sender = func(_url: String, _body: PackedByteArray, _type: String) -> void: pass
	_board._on_draft_auto_pressed()
	await settle(15)
	quiet()
	_board.instant_roll_for_test=false
	var tip := _board.get_node_or_null("FirstMatchTip") as CanvasLayer
	if tip!=null:tip.hide()
	# A populated local fixture makes the actual pieces/installed traps visible.
	for i:int in 8:
		var pawn:PlayerPawn=_board.state.pawns[i]
		pawn.place_at((i*BoardSpec.side/2+2) % (BoardSpec.side*4))
		pawn.has_left_start=true
	for tile:int in [3,7,13,19]:_board.state.place_attachment(tile,TrapDomino.new(1))
	quiet();_board._trap_pending.clear();_board._refresh_all()
	var snapshot:=TurnSnapshot.capture(_board.state).data
	var rng_before:int=_board.state.rng.state
	var laws:Array[String]=LawRegistry.ALL_IDS.duplicate()
	await settle(12)
	var originals:Array[CanvasItem]=[]
	for pawn:PlayerPawn in _board.state.pawns:
		if pawn.has_left_start and not pawn.is_finished:originals.append(_board._pawn_views[pawn.entity_id])
	var original_visibility:Array[bool]=[]
	for item:CanvasItem in originals:original_visibility.append(item.visible)
	var board_frame:Transform2D=_board._board_layer.get_transform()
	var plate_frame:Transform2D=_board._plate.get_transform()
	var board_visible:bool=_board._board_layer.visible
	var plate_visible:bool=_board._plate.visible
	var center:Vector2=_board.get_global_transform_with_canvas()*(_board._surface_project(Vector2.ONE*0.5)+_board._off_center)
	var layer:=CanvasLayer.new()
	layer.layer=90
	_board.add_child(layer)
	var cut:=VictoryCutscene.new()
	layer.add_child(cut)
	cut.setup(VictoryCutscene.MODE_LAW,Color("b8d6c0"),AvatarCombatArt.texture(&"avatar_01",&"victory"),null,"","","베루·사리·메죵 3종을 모아 자기 차례 종료","에르핀")
	cut.set_spots([center])
	cut.set_law_context("LAW_09",center,&"avatar_01","에르핀",1)
	var storm = cut._prelude._hurricane
	storm.set_board_context(_board)
	_expect(storm._debris.size()==originals.size()+4,"actual pawn and four installed-trap visuals copied")
	_expect(storm.find_child("HurricaneTrioPrint",true,false)==null,"trio print reserved, absent from this cinematic")
	var hits:Array[int]=[0,0,0,0]
	cut.confirmed.connect(func() -> void:hits[0]+=1)
	cut.prelude_impact.connect(func() -> void:hits[1]+=1)
	cut.impact.connect(func() -> void:hits[2]+=1)
	cut.completed.connect(func() -> void:hits[3]+=1)
	cut.play()
	recording=true
	var captured:Dictionary={}
	for i:int in 330:
		await process_frame
		var seconds:float=cut._time/cut._pace
		if seconds>=0.43 and not captured.has("confirm"):
			captured.confirm=true;await snap("01-hurricane-confirmed")
		if seconds>=cut._spot_len+0.49 and not captured.has("storm"):
			captured.storm=true
			_expect(not storm.landed and originals[0].visible==original_visibility[0],"objects stay in place before center contact")
			await snap("02-hurricane-descends")
		if seconds>=cut._spot_len+0.75 and not captured.has("strike"):
			captured.strike=true
			_expect(storm.landed and not originals[0].visible,"objects launch after center strike")
			_expect(_board._board_layer.visible==board_visible and _board._plate.visible==plate_visible,"board visibility unchanged during strike")
			_expect(storm.contact_point.distance_to(storm.focus)<0.1,"hurricane anchored at exact projected board center")
			_expect((storm._tornado.position+storm._tornado.size*Vector2(0.5,0.96)).distance_to(storm.contact_point)<0.1,"tornado dust base meets board center without sideways drift")
			for entry:Dictionary in storm._tiles:_expect(not entry.node.trap_on,"installed trap visual lifted at impact")
			await snap("03-center-impact")
		if seconds>=cut._spot_len+1.10 and not captured.has("scatter"):
			captured.scatter=true
			_expect(_board._board_layer.get_transform()==board_frame and _board._plate.get_transform()==plate_frame,"board never lifts or flips")
			await snap("04-pawns-and-traps-scatter")
		if cut._main_time()>=0.5 and not captured.has("handoff"):
			captured.handoff=true;await snap("05-same-hurricane-handoff")
		if cut._main_time()>=2.1 and not captured.has("poster"):
			captured.poster=true;await snap("06-hurricane-victory")
		if not cut.active:break
	recording=false
	_expect(captured.size()==6,"descent, center strike, scattering, continuous hurricane and finale recorded")
	for i:int in originals.size():_expect(originals[i].visible==original_visibility[i],"board visibility restored on completion")
	for entry:Dictionary in storm._tiles:_expect(entry.node.trap_on and entry.node.trap_icon==entry.icon,"trap visual restored on completion")
	_expect(hits==[1,1,1,1],"each cue and completion occurs once")
	_expect(cut.headline_text()=="HURRICANE\nFORCE","unique headline")
	_expect(LawRegistry.ALL_IDS==laws and not LawRegistry.ALL_IDS.has("LAW_09"),"preview never registers new gameplay law")
	_expect(not CardRegistry.DECK_COMPOSITION.has(&"ACT_18"),"preview never enables cards or changes deck")
	_expect(TurnSnapshot.capture(_board.state).data==snapshot and _board.state.rng.state==rng_before,"preview changes no hands/gameplay or RNG")
	var before:Array[int]=hits.duplicate()
	cut.play(0.5)
	await settle(2)
	cut.cancel()
	cut.cancel()
	_expect(hits[0]==before[0] and hits[1]==before[1] and hits[2]==before[2] and hits[3]==before[3]+1,"early cancel completes once without invented impacts")
	cut.play(0.5)
	await settle(30)
	_expect(storm.landed and not originals[0].visible and _board._board_layer.visible,"2x replay reaches object flight with stationary board")
	cut.cancel()
	for i:int in originals.size():_expect(originals[i].visible==original_visibility[i],"mid-flight cancel restores original pawn visibility")
	for entry:Dictionary in storm._tiles:_expect(entry.node.trap_on and entry.node.trap_icon==entry.icon,"mid-flight cancel restores trap visual")
	layer.queue_free()
	await settle(3)
	var board:MainBoard=_board;_board=null;board.queue_free()
	await settle(5)
	for failure:String in _failures:printerr("HURRICANE_FAIL ",failure)
	print("HURRICANE_NATIVE ",_failures.size()," failures; frames=",recorded_frames)
	MatchTelemetry.test_sender=Callable()
	quit(0 if _failures.is_empty() else 1)

