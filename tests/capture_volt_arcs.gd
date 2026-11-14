extends "res://tests/capture_buff_styles.gd"

func _run() -> void:
	MatchTelemetry.test_sender=func(_url:String,_body:PackedByteArray,_type:String)->void:pass
	_board._on_draft_auto_pressed();await settle(15);quiet()
	var tip:=_board.get_node_or_null("FirstMatchTip") as CanvasLayer
	if tip!=null:tip.hide()
	me=_board.local_player_id
	_board.manager.current_turn_index=_board.manager.player_order.find(me)
	_clear_sources();_board._refresh_all();quiet();await settle(12)
	UtilityAugments.apply(UtilityAugments.MOVE_PLUS,_board.state,me)
	await _capture_style("volt",SuperFX.BUFF_VOLT)
	var rim:Control=(_board._profiles[me].panel as Control).get_node("SuperFlame")
	var tool:Control=_board._tool_board.get_node("SuperFlame")
	_expect(rim._arcs!=null and tool._arcs!=null,"both UI outlines have actual discharge paths")
	_expect(rim._arcs.mouse_filter==Control.MOUSE_FILTER_IGNORE and tool._arcs.mouse_filter==Control.MOUSE_FILTER_IGNORE,"discharge paths never intercept UI input")
	var snapshot:=TurnSnapshot.capture(_board.state).data
	var rng_before:int=_board.state.rng.state
	rim._time=1.0;tool._time=1.0;await settle(2)
	_expect(not rim._arcs.discharge_visible() and not tool._arcs.discharge_visible(),"quiet interval between short discharges")
	await snap("01-quiet-blue-rim")
	rim._time=2.45;tool._time=2.45;await settle(2)
	_expect(rim._arcs.discharge_visible() and tool._arcs.discharge_visible(),"short bent paths activate on both outlines")
	await snap("02-bent-electric-arcs")
	var expanded:bool=_board._tool_expanded
	await click(_board._tool_toggle);await settle(4)
	_expect(_board._tool_expanded!=expanded and tool._arcs.size==_board._tool_board.size,"details remain clickable and discharge follows resized panel")
	if _board._tool_expanded!=expanded:await click(_board._tool_toggle)
	_expect(TurnSnapshot.capture(_board.state).data==snapshot and _board.state.rng.state==rng_before,"discharge timing and UI interaction consume no state or RNG")
	_board.state.gambler_round[me]=_board.state.round_number;_board._refresh_super_marks()
	_expect(rim.effects==5 and rim._arcs.visible,"Supa Volt paths remain alongside red fire")
	_clear_sources();await settle(3)
	_expect((_board._profiles[me].panel as Control).get_node_or_null("SuperFlame")==null and _board._tool_board.get_node_or_null("SuperFlame")==null,"clearing buff removes paths with outline")
	var board:MainBoard=_board;_board=null;board.queue_free();await settle(5)
	for failure:String in _failures:printerr("VOLT_ARCS_FAIL ",failure)
	print("VOLT_ARCS_NATIVE ",_failures.size()," failures; frames=",recorded_frames)
	MatchTelemetry.test_sender=Callable();quit(0 if _failures.is_empty() else 1)
