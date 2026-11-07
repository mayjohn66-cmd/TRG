## Real hand -> zoom -> drag -> tile choice -> summon -> round-end beam lifecycle.
extends "res://tests/capture_darts_integration.gd"
var me:int
var reports:Array[Dictionary]=[]
var stages:Dictionary={}

func pointer(point:Vector2,down:bool) -> void:
	var event:=InputEventMouseButton.new();event.position=point
	event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true)
	await process_frame

func move_pointer(point:Vector2) -> void:
	var event:=InputEventMouseMotion.new();event.position=point;root.push_input(event,true)
	await process_frame

func wait_idle() -> void:
	await settle(2)
	var ticks:int=0
	while ticks<360 and (_board._presentation_active() or _board._announcer.holding()):
		await process_frame;ticks+=1
	_expect(ticks<360,"card/NPC presentation drains without soft-lock")

func _run() -> void:
	MatchTelemetry.test_sender=func(_url:String,_body:PackedByteArray,_type:String)->void:pass
	_board._on_draft_auto_pressed();await settle(15);quiet()
	me=_board.local_player_id
	_board.manager.draft_enabled=false;_board.state.boost_gimmicks=false
	_board.manager.current_turn_index=_board.manager.player_order.find(me)
	_board.manager.change_state(TurnManager.State.PHASE_TURN_BEGIN);quiet()
	_board._beat_until_msec=0;_board._fx_until_msec=0
	for pawn:PlayerPawn in _board.state.pawns:pawn.reset_to_start()
	for seat:int in _board.state.hands:_board.state.hands[seat].clear()
	_board.state.hands[me]=[&"SUM_03"]
	_board.state.amnesia_round=-1;_board.instant_roll_for_test=false
	_board._refresh_all();await settle(12)
	var tip:=_board.get_node_or_null("FirstMatchTip") as CanvasLayer
	if tip!=null:tip.hide()
	_board.manager.event_received.connect(func(kind:StringName,data:Dictionary)->void:
		if kind==&"npc_phase_resolved":reports.append_array(data.reports))
	recording=true;stages["hand"]=recorded_frames;await settle(10)
	await snap("01-registered-card-in-hand")
	var hand:Control=_board._dock.get_child(0) as Control
	var card_point:Vector2=hand.get_global_transform_with_canvas()*Vector2(70,30)
	await move_pointer(card_point);await settle(7)
	card_point=hand.get_global_transform_with_canvas()*Vector2(70,40)
	await pointer(card_point,true);await pointer(card_point,false);await settle(6)
	_expect(_board._zoom_view!=null,"actual hand click opens registered card detail")
	if _board._zoom_view!=null:
		var art:TextureRect=_board._zoom_view.find_child("CardArt",true,false) as TextureRect
		_expect(art!=null and art.texture==TextureCache.fetch("res://assets/cards/SUM_03.png"),"card detail uses reserved trio image")
	stages["detail"]=recorded_frames;await snap("02-card-detail-with-rules");await settle(28)
	_board._close_zoom();await settle(3)
	hand=_board._dock.get_child(0) as Control
	card_point=hand.get_global_transform_with_canvas()*Vector2(70,35)
	await move_pointer(card_point);await pointer(card_point,true)
	await move_pointer(_board.get_global_transform_with_canvas()*_board._board_center())
	await settle(4);await pointer(_board.get_global_transform_with_canvas()*_board._board_center(),false)
	_expect(_board._tile_pick_active,"actual hand drag opens summon tile selection")
	stages["tile"]=recorded_frames;await snap("03-summon-target");await settle(10)
	var tile:Control=_board._tile_views[BoardSpec.halfway_tile] as Control
	await click(tile);await settle(2)
	_expect(_board.state.npcs.size()==1 and not (_board.state.hands[me] as Array).has(&"SUM_03"),"selected top tile consumes card and creates one NPC")
	if _board.state.npcs.is_empty():
		recording=false;print("PROTON_INTEGRATION ",_failures.size()," failures; no summon");quit(1);return
	var npc:NeutralNPC=_board.state.npcs[0]
	var id:int=npc.entity_id
	var beam:ProtonBeamView=_board._npc_views.get(id) as ProtonBeamView
	var beam_count:int=0
	for child:Node in _board._pawn_layer.get_children():
		if child is ProtonBeamView:beam_count+=1
	_expect(beam_count==1,"summon refresh creates exactly one beam presentation")
	_expect(beam!=null and npc.rounds_left==3,"real NPC uses approved three-round beam view")
	if _board._announcer.holding() and beam!=null:_expect(not beam.visible,"beam waits behind card announcement")
	stages["activation"]=recorded_frames;await snap("04-card-activation")
	await wait_idle();await settle(12)
	_expect(is_instance_valid(beam) and beam.visible and is_equal_approx(beam.drop,1.0),"summon naturally descends after card notice")
	_expect(beam.get_global_transform_with_canvas().origin.distance_to(_board._board_layer.get_global_transform_with_canvas()*_board._tile_center(BoardSpec.halfway_tile))<0.1,"real beam contact matches the actual top tile")
	stages["landed"]=recorded_frames;await snap("05-beam-landed");await settle(18)
	# Arrange hits using a copy of the authoritative RNG, never consume it for VFX.
	var oracle:=RandomNumberGenerator.new();oracle.state=_board.state.rng.state
	var direction:int=-1 if oracle.randi_range(0,1)==0 else 1
	var distance:int=oracle.randi_range(NpcSweep.BEAM_MIN,NpcSweep.BEAM_MAX)
	var start:int=npc.current_tile_idx
	var own:PlayerPawn=_board.state.pawns_of(me)[0]
	var enemy:PlayerPawn=_board.state.pawns_of(2 if me!=2 else 3)[0]
	for pair:Array in [[own,1],[enemy,3]]:
		var pawn:PlayerPawn=pair[0];pawn.evolve(GameEnums.PawnKind.BASIC,0)
		pawn.ward=false;pawn.turn_guard=false;pawn.shield=false
		pawn.place_at(posmod(start+direction*int(pair[1]),BoardSpec.tile_count));pawn.has_left_start=true
	var trap_tile:int=posmod(start+direction*2,BoardSpec.tile_count)
	_board.state.board.get_tile(trap_tile).add_attachment(TrapPit.new(enemy.owner_id))
	_board._refresh_all();await settle(4)
	stages["round1"]=recorded_frames;_board.manager._enter_neutral_npc_phase()
	await settle(6);await snap("06-round-end-beam-start")
	await wait_idle();await settle(8)
	_expect(not own.has_left_start and not enemy.has_left_start and _board.state.board.get_tile(trap_tile).attachments.is_empty(),"real round-end beam burns own/enemy pieces and trap")
	_expect(reports.size()==1 and reports[0].path.size()==distance and reports[0].direction==direction,"VFX uses the real random route and result")
	_expect(_board.state.get_npc(id)!=null and beam.rounds_left==2 and _board._beam_victims.is_empty() and _board._beam_trap_hold.is_empty(),"first round retains beam and releases visual holds")
	await snap("07-first-round-complete")
	for round_index:int in 2:
		stages["round%d"%(round_index+2)]=recorded_frames
		_board.manager._enter_neutral_npc_phase();await wait_idle();await settle(8)
		await snap("08-round-%d-complete"%(round_index+2))
	var fade_wait:int=0
	while is_instance_valid(beam) and fade_wait<100:await process_frame;fade_wait+=1
	_expect(_board.state.get_npc(id)==null and not is_instance_valid(beam) and not _board._npc_views.has(id),"third real round fades and fully removes the beam")
	await snap("09-lifetime-finished");await settle(8);recording=false
	# Cancelling queued descent/movement must leave the surviving NPC visible and settled.
	var again:NeutralNPC=_board.state.spawn_npc(BoardSpec.halfway_tile,GameEnums.NpcBehavior.CHASE_NEAREST,me,&"SUM_03")
	_board._refresh_all();await settle(2);_board._reset_presentation();await settle(3)
	var restored:ProtonBeamView=_board._npc_views.get(again.entity_id) as ProtonBeamView
	_expect(restored!=null and restored.visible and is_equal_approx(restored.drop,1.0),"cancelling summon restores a visible live beam")
	_board.manager._enter_neutral_npc_phase();await settle(4)
	var snapshot:=TurnSnapshot.capture(_board.state).data
	var rng_before:int=_board.state.rng.state
	_board._reset_presentation();await settle(4)
	_expect(_board._beam_victims.is_empty() and _board._beam_trap_hold.is_empty() and not restored.has_meta("npc_run"),"cancelling travel clears beam-owned holds and motion")
	_expect(restored.position.distance_to(_board._tile_center(again.current_tile_idx))<0.01 and TurnSnapshot.capture(_board.state).data==snapshot and _board.state.rng.state==rng_before,"cancel restores authoritative contact without state or RNG changes")
	var file:=FileAccess.open(capture_out.path_join("stages.json"),FileAccess.WRITE);file.store_string(JSON.stringify(stages,"  "));file.close()
	for failure:String in _failures:printerr("PROTON_INTEGRATION_FAIL ",failure)
	print("PROTON_INTEGRATION ",_failures.size()," failures; frames=",recorded_frames)
	var board:MainBoard=_board;_board=null;board.queue_free();await settle(5)
	MatchTelemetry.test_sender=Callable();quit(0 if _failures.is_empty() else 1)
