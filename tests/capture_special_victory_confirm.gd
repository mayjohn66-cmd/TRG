## Actual LAW_03 qualification -> existing MainBoard queue -> themed cinematic.
extends "res://tests/capture_darts_integration.gd"
const THEMES = preload("res://scenes/law_victory_theme.gd")
var checks := 0
func _expect(ok: bool, message: String) -> void:
	checks += 1
	super._expect(ok,message)
func _run() -> void:
	MatchTelemetry.test_sender = func(_url: String, _body: PackedByteArray, _type: String) -> void: pass
	_board._on_draft_auto_pressed()
	await settle(15)
	quiet()
	var owner: int = _board._dock_owner()
	_board.manager.current_turn_index = _board.manager.player_order.find(owner)
	_board.manager.change_state(TurnManager.State.PHASE_TURN_BEGIN)
	quiet()
	_board.state.rulebook.enqueue_law(LawRegistry.create("LAW_03"))
	for tile: int in [3,5,7,9,11]: _board.state.place_attachment(tile,TrapDomino.new(owner))
	quiet()
	_board.instant_roll_for_test = false
	_board._refresh_all()
	var tip := _board.get_node_or_null("FirstMatchTip") as CanvasLayer
	if tip != null: tip.hide()
	recording = true
	_board.manager._judge_special_victory(owner)
	_expect(_board.state.rank_reasons.get(owner)==&"LAW_03","authoritative real installation condition qualifies")
	var cut: VictoryCutscene
	for i: int in 120:
		cut = _board.find_child("VictoryCutscene",true,false) as VictoryCutscene
		if cut != null: break
		await process_frame
	_expect(cut != null,"qualified event enters restored themed cinematic")
	if cut==null:
		printerr("SPECIAL_VICTORY_FAIL no cinematic")
		quit(1)
		return
	var hits: Array[int]=[0,0,0]
	cut.confirmed.connect(func() -> void:hits[0]+=1)
	cut.prelude_impact.connect(func() -> void:hits[1]+=1)
	cut.impact.connect(func() -> void:hits[2]+=1)
	var snapshot := TurnSnapshot.capture(_board.state).data
	var rng_before: int = _board.state.rng.state
	var sampled: Dictionary={}
	for i: int in 420:
		await process_frame
		if not is_instance_valid(cut) or not cut.active: break
		var at: float = cut._time/cut._pace
		if at>=0.43 and not sampled.has("confirm"):
			sampled.confirm=true
			await snap("01-real-condition-confirmed")
		if at>=cut._spot_len+cut._intro_duration()*0.7 and not sampled.has("intro"):
			sampled.intro=true
			await snap("02-real-law-introduction")
		if cut._main_time()>=2.1 and not sampled.has("poster"):
			sampled.poster=true
			await snap("03-real-law-victory")
	recording = false
	_expect(sampled.size()==3,"confirmation, introduction and poster all appear in order")
	_expect(hits==[1,1,1],"confirmed/prelude/finale each fires exactly once")
	_expect(TurnSnapshot.capture(_board.state).data==snapshot and _board.state.rng.state==rng_before,"cinematic changes no simulation or RNG")
	_board._announcer.cancel()
	_board._reset_presentation()
	if _board._result_overlay!=null: _board._result_overlay.hide()
	# All eight law themes must remain legible and load with their dedicated fonts/props.
	for id: String in LawRegistry.ALL_IDS:
		var layer := CanvasLayer.new()
		layer.layer=90
		_board.add_child(layer)
		var sample := VictoryCutscene.new()
		layer.add_child(sample)
		var law := LawRegistry.create(id)
		sample.setup(VictoryCutscene.MODE_LAW,Color("ffd43b"),AvatarCombatArt.texture(&"avatar_01",&"victory"),null,"特","",law.description,"미리보기")
		sample.set_spots([Vector2(400,400),Vector2(750,250)])
		sample.set_law_context(id,Vector2(683,335),&"avatar_01","미리보기",1)
		sample.play()
		sample.set_process(false)
		sample._spot_view=-1
		sample._intro_view=-1
		sample.set_time(2.1)
		await settle(3)
		_expect(sample.headline_text()==THEMES.headline(id),id+" preserves unique headline")
		_expect(sample._headline.get_theme_font("font")!=null,id+" dedicated font loaded")
		await snap("theme-"+id)
		var finished: Array[int]=[0]
		sample.completed.connect(func() -> void:finished[0]+=1)
		sample.cancel()
		sample.cancel()
		_expect(finished[0]==1 and not sample.active,id+" cancel completes once")
		layer.queue_free()
		await settle(2)
	_board.enqueue_step(_board._play_victory_cutscene.bind(owner,1,&"LAW_05"))
	await settle(4)
	_expect(_board.get_node_or_null("VictoryCutsceneLayer")!=null,"live cinematic starts before cancellation")
	_board._reset_presentation()
	await settle(4)
	_expect(_board.get_node_or_null("VictoryCutsceneLayer")==null and not _board._presentation_active(),"board reset releases live cinematic layer and queue")
	var board: MainBoard = _board
	_board = null
	board.queue_free()
	await settle(6)
	for failure: String in _failures: printerr("SPECIAL_VICTORY_FAIL ",failure)
	print("SPECIAL_VICTORY_NATIVE ",checks," assertions; ",_failures.size()," failures; frames=",recorded_frames)
	MatchTelemetry.test_sender=Callable()
	quit(0 if _failures.is_empty() else 1)
