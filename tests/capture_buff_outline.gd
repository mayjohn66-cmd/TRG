extends "res://tests/capture_darts_integration.gd"

func _run() -> void:
	MatchTelemetry.test_sender=func(_url:String,_body:PackedByteArray,_type:String)->void:pass
	_board._on_draft_auto_pressed();await settle(15);quiet()
	var me:int=_board.local_player_id
	_board.manager.current_turn_index=_board.manager.player_order.find(me)
	_board.state.permanent_roll_bonus.clear();_board.state.gambler_round.clear()
	_board._super_hidden.clear();_board._refresh_all();quiet();await settle(12)
	var profile:Control=_board._profiles[me].panel
	var tool:Control=_board._tool_board
	var profile_size:=profile.size
	var tool_size:=tool.size
	await snap("01-normal-borders")
	_board.state.permanent_roll_bonus[me]=3
	var state_before:=TurnSnapshot.capture(_board.state).data
	var rng_before:int=_board.state.rng.state
	_board._refresh_super_marks();await settle(8)
	var rim:Control=profile.get_node_or_null("SuperFlame")
	var tool_rim:Control=tool.get_node_or_null("SuperFlame")
	_expect(rim!=null and tool_rim!=null,"buff colors both profile and current judgment card")
	if rim!=null and tool_rim!=null:
		_expect(rim.get_script()==tool_rim.get_script(),"profile and tool share one outline component")
		_expect(rim.get_global_rect().is_equal_approx(profile.get_global_rect()) and tool_rim.get_global_rect().is_equal_approx(tool.get_global_rect()),"outline matches outer UI bounds rather than content inset")
		_expect(profile.size==profile_size and tool.size==tool_size,"outline adds no layout minimum or margin")
		_expect(rim.mouse_filter==Control.MOUSE_FILTER_IGNORE and tool_rim.mouse_filter==Control.MOUSE_FILTER_IGNORE,"outline allows existing buttons and profile input")
	await snap("02-permanent-buff-outline")
	var resting:=profile.scale
	profile.scale=resting*0.94;profile.rotation=0.04;await settle(3)
	_expect(rim.get_global_transform().is_equal_approx(profile.get_global_transform()),"outline follows profile reaction scale and rotation")
	profile.scale=resting;profile.rotation=0.0;await settle(3)
	var expanded:bool=_board._tool_expanded
	await click(_board._tool_toggle);await settle(6)
	_expect(_board._tool_expanded!=expanded,"existing details button remains clickable through colored outline")
	_expect(tool_rim.get_global_rect().is_equal_approx(tool.get_global_rect()),"tool outline follows expanded details")
	await snap("03-expanded-tool-outline")
	if _board._tool_expanded!=expanded:
		await click(_board._tool_toggle);await settle(6)
	_expect(TurnSnapshot.capture(_board.state).data==state_before and _board.state.rng.state==rng_before,"outline and details interaction change no game state or RNG")
	_board.state.gambler_round[me]=_board.state.round_number
	_board._refresh_super_marks();await settle(3)
	_expect(rim.colors.size()==4 and profile.get_node("SuperFlame")==rim,"coexisting buffs reuse the outline without duplicate layers")
	_board.state.permanent_roll_bonus.clear();_board.state.gambler_round.clear()
	_board._refresh_super_marks();await settle(4)
	_expect(profile.get_node_or_null("SuperFlame")==null and tool.get_node_or_null("SuperFlame")==null,"clearing buffs immediately restores normal UI borders")
	await snap("04-normal-borders-restored")
	var board:MainBoard=_board;_board=null;board.queue_free();await settle(5)
	for failure:String in _failures:printerr("BUFF_OUTLINE_FAIL ",failure)
	print("BUFF_OUTLINE_NATIVE ",_failures.size()," failures")
	MatchTelemetry.test_sender=Callable();quit(0 if _failures.is_empty() else 1)
