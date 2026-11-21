extends "res://tests/capture_melon_rolling.gd"
var focus:Node2D
var frame_centers:Array[Vector2]=[]
var bank_samples:int=0

func _save_frame() -> void:
	if recording and is_instance_valid(focus):frame_centers.append(focus.get_global_transform_with_canvas().origin)
	super._save_frame()

func _run() -> void:
	MatchTelemetry.test_sender=func(_url:String,_body:PackedByteArray,_type:String)->void:pass
	_board._on_draft_auto_pressed();await settle(15);quiet()
	_board.instant_roll_for_test=true;_board.state.boost_gimmicks=false
	var pawn:PlayerPawn=_board.state.pawns_of(_board.local_player_id)[0]
	for other:PlayerPawn in _board.state.pawns:other.reset_to_start()
	for seat:int in _board.state.hands:_board.state.hands[seat].clear()
	for tile:int in BoardSpec.tile_count:_board.state.board.get_tile(tile).attachments.clear()
	pawn.evolve(GameEnums.PawnKind.ARCADE,3);pawn.place_at(1);pawn.has_left_start=true
	_board.manager.current_turn_index=_board.manager.player_order.find(pawn.owner_id)
	_board.manager.change_state(TurnManager.State.PHASE_TURN_BEGIN);quiet()
	_board._refresh_all();await settle(12)
	focus=_board._pawn_views[pawn.entity_id]
	var token:PawnToken=focus.get_node("Bounce/Token")
	var bounce:Node2D=focus.get_node("Bounce")
	var tip:=_board.get_node_or_null("FirstMatchTip") as CanvasLayer
	if tip!=null:tip.hide()
	_expect(token.is_rolling_body() and not token.is_rolling_melon(),"8-ball uses grounded body rolling without becoming a melon")
	_expect(token.artwork.texture.resource_path.ends_with("POOL_8BALL.png"),"existing 8-ball image preserved")
	_board._roll_button.hide();_board._skill_hint.hide()
	await snap("01-eight-ball-ready")
	_board.instant_roll_for_test=false;recording=true;await settle(8)
	await roll_path(pawn,4,"02-normal-roll");await settle(10)
	var normal_end:int=recorded_frames
	_board.instant_roll_for_test=true
	pawn.place_at(2);pawn.skill_used=false
	var target:PlayerPawn=_board.state.pawns_of(2 if pawn.owner_id!=2 else 3)[0]
	target.evolve(GameEnums.PawnKind.BASIC,0);target.place_at(8);target.has_left_start=true
	target.shield=false;target.ward=false;target.turn_guard=false
	_board.manager.current_turn_index=_board.manager.player_order.find(pawn.owner_id)
	_board.manager.change_state(TurnManager.State.PHASE_TURN_BEGIN);quiet();_board._refresh_all()
	await settle(3);_board.instant_roll_for_test=false
	var destination:int=PawnSkills.bank_shot_path(_board.state,pawn).back()
	var followups:Array[int]=[]
	var followup:Callable=func(id:int,steps:int)->void:
		if id==pawn.entity_id:followups.append(steps)
	_board.state.capture_charge_started.connect(followup)
	_expect(_board.manager.can_use_skill(pawn.owner_id,pawn.entity_id),"real Bank Shot ready")
	var angle:float=token.melon_roll_angle
	_board.manager.act(&"use_skill",{"player_id":pawn.owner_id,"pawn_id":pawn.entity_id})
	var spinning:int=0
	while bank_samples<600 and (_board.manager.current_state==TurnManager.State.PHASE_MOVING_STEP or _board._presentation_active() or _board._fx_running(focus) or _board._announcer.holding()):
		await process_frame;bank_samples+=1
		_expect(bounce.position==Vector2.ZERO and bounce.scale==Vector2.ONE and bounce.rotation==0.0 and focus.rotation==0.0,"Bank Shot stays on ground; base and markers remain upright")
		if absf(wrapf(token.melon_roll_angle-angle,-PI,PI))>0.001:spinning+=1
		angle=token.melon_roll_angle
	_expect(bank_samples<600 and spinning>5,"Bank Shot visibly rotates and finishes")
	_expect(pawn.skill_used and not target.has_left_start,"Bank Shot still consumes skill and captures target")
	_expect(followups==[MoveExecutor.EIGHT_BALL_CHARGE] and pawn.current_tile_idx==destination+MoveExecutor.EIGHT_BALL_CHARGE,"capture still triggers the existing extra three rolling steps")
	_expect(focus.position.distance_to(_board._pawn_position(pawn))<0.01,"Bank Shot stops at authoritative destination")
	await snap("03-bank-shot-and-followup");await settle(12);recording=false
	_board.state.capture_charge_started.disconnect(followup)
	_board._play_hop(pawn.entity_id,focus.position+Vector2(100,0),focus.scale.x,12)
	await settle(2);_board._reset_presentation();_board._kill_fx(focus)
	var stopped:float=token.melon_roll_angle
	_board.instant_roll_for_test=true;_board._refresh_all();await settle(6)
	_expect(is_equal_approx(token.melon_roll_angle,stopped) and not _board._fx_running(focus),"cancel stops rolling and preserves settled body phase")
	_expect(focus.position.distance_to(_board._pawn_position(pawn))<0.01,"cancel restores real tile position")
	var coords:Array=[]
	for point:Vector2 in frame_centers:coords.append([point.x,point.y])
	var file:=FileAccess.open(capture_out.path_join("motion.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"normal_end":normal_end,"centers":coords},"  "));file.close()
	for failure:String in _failures:printerr("EIGHT_BALL_FAIL ",failure)
	print("EIGHT_BALL_NATIVE ",_failures.size()," failures; ",motion_checks+bank_samples," grounded samples; ",recorded_frames," frames")
	var board:MainBoard=_board;_board=null;board.queue_free();await settle(5)
	MatchTelemetry.test_sender=Callable();quit(0 if _failures.is_empty() else 1)
