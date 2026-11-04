extends "res://tests/capture_darts_integration.gd"
var segments:Dictionary={}
var me:int

func _run() -> void:
	MatchTelemetry.test_sender=func(_url:String,_body:PackedByteArray,_type:String)->void:pass
	_board._on_draft_auto_pressed();await settle(15);quiet()
	var tip:=_board.get_node_or_null("FirstMatchTip") as CanvasLayer
	if tip!=null:tip.hide()
	me=_board.local_player_id
	_board.manager.current_turn_index=_board.manager.player_order.find(me)
	_clear_sources();_board._refresh_all();quiet();await settle(12)
	_expect(bool(SuperAugments.apply(SuperAugments.GAMBLER,_board.state,me).ok),"actual gambler application succeeds")
	await _capture_style("gambler",SuperFX.BUFF_GAMBLER)
	_clear_sources()
	_board.state.pawns_of(me)[0].is_finished=true
	_expect(bool(SuperAugments.apply(SuperAugments.DEVIL,_board.state,me).ok),"actual devil application succeeds")
	quiet();await _capture_style("devil",SuperFX.BUFF_DEVIL)
	_clear_sources()
	_expect(bool(UtilityAugments.apply(UtilityAugments.MOVE_PLUS,_board.state,me).ok),"actual Supa Volt application succeeds")
	UtilityAugments.apply(UtilityAugments.MOVE_PLUS,_board.state,me)
	_expect(_board.state.permanent_roll_bonus[me]==2 and _board.state.utility_move_plus[me]==2,"stacked Volt bonus is recorded independently")
	await _capture_style("volt",SuperFX.BUFF_VOLT)
	_board.state.permanent_roll_bonus[me]+=SuperAugments.devil_bonus()
	SuperAugments.apply(SuperAugments.GAMBLER,_board.state,me)
	_board._refresh_super_marks();await settle(3)
	var rim:Control=(_board._profiles[me].panel as Control).get_node("SuperFlame")
	_expect(rim.effects==7 and rim.colors.size()==6,"three buffs coexist in one outline")
	_board.state.round_number+=1;_board._refresh_super_marks();await settle(2)
	_expect(rim.effects==6,"gambler expires while both permanent effects remain")
	_board._super_hidden["%d:%s"%[me,SuperAugments.DEVIL]]=true
	_board._refresh_super_marks();await settle(2)
	_expect(rim.effects==SuperFX.BUFF_VOLT,"unrevealed Devil does not hide independent Volt")
	_clear_sources();await settle(3)
	_expect((_board._profiles[me].panel as Control).get_node_or_null("SuperFlame")==null and _board._tool_board.get_node_or_null("SuperFlame")==null,"all outlines clear when no source remains")
	var file:=FileAccess.open(capture_out.path_join("segments.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(segments,"  "));file.close()
	var board:MainBoard=_board;_board=null;board.queue_free();await settle(5)
	for failure:String in _failures:printerr("BUFF_STYLES_FAIL ",failure)
	print("BUFF_STYLES_NATIVE ",_failures.size()," failures; frames=",recorded_frames)
	MatchTelemetry.test_sender=Callable();quit(0 if _failures.is_empty() else 1)

func _clear_sources() -> void:
	_board.state.permanent_roll_bonus.clear();_board.state.utility_move_plus.clear()
	_board.state.gambler_round.clear();_board._super_hidden.clear();_board._refresh_super_marks()

func _capture_style(key:String,expected:int) -> void:
	var snapshot:=TurnSnapshot.capture(_board.state).data
	var rng_before:int=_board.state.rng.state
	_board._refresh_super_marks();await settle(3)
	var profile:Control=_board._profiles[me].panel
	var rim:Control=profile.get_node_or_null("SuperFlame")
	var tool:Control=_board._tool_board.get_node_or_null("SuperFlame")
	_expect(rim!=null and tool!=null,"%s colors profile and tool"%key)
	if rim==null or tool==null:return
	_expect(rim.effects==expected and tool.effects==expected,"%s selects only its own effect"%key)
	_expect(rim.get_global_rect().is_equal_approx(profile.get_global_rect()) and tool.get_global_rect().is_equal_approx(_board._tool_board.get_global_rect()),"%s retains aligned outer bounds"%key)
	var start:int=recorded_frames
	recording=true;await settle(96);recording=false
	segments[key]={"start":start,"count":recorded_frames-start}
	await snap(key)
	_expect(TurnSnapshot.capture(_board.state).data==snapshot and _board.state.rng.state==rng_before,"%s animation consumes no game state or RNG"%key)
