extends "res://tests/capture_darts_integration.gd"
var me:int
var rolls:Array[Dictionary]=[]

func _run() -> void:
	MatchTelemetry.test_sender=func(_url:String,_body:PackedByteArray,_type:String)->void:pass
	_board._on_draft_auto_pressed();await settle(15);quiet()
	var tip:=_board.get_node_or_null("FirstMatchTip") as CanvasLayer
	if tip!=null:tip.hide()
	me=_board.local_player_id
	_board.instant_roll_for_test=false
	_board.manager.event_received.connect(func(kind:StringName,data:Dictionary)->void:
		if kind==&"roll_resolved":rolls.append(data.result))
	await _fresh(&"D6")
	var button:Button=_board._roll_button
	_expect(button.visible and not button.disabled and button.size==Vector2(120,120),"real roll button keeps its size and enabled state")
	var snapshot:=TurnSnapshot.capture(_board.state).data
	var rng_before:int=_board.state.rng.state
	recording=true;await settle(15);await snap("01-normal")
	var point:Vector2=button.get_global_transform_with_canvas()*(button.size*0.5)
	var move:=InputEventMouseMotion.new();move.position=point;root.push_input(move,true)
	await settle(12);await snap("02-hover")
	var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.position=point;press.pressed=true
	root.push_input(press,true);await settle(12);await snap("03-pressed")
	_expect(button.is_pressed() and rolls.is_empty(),"recessed art appears on real pointer down before click activation")
	_expect(TurnSnapshot.capture(_board.state).data==snapshot and _board.state.rng.state==rng_before,"normal hover and pressed art consume no state or RNG")
	press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.position=point;press.pressed=false
	root.push_input(press,true);await settle(22);await snap("04-real-roll")
	_expect(rolls.size()==1 and rolls[0].tool_id==&"D6","one real click produces one authoritative roll")
	recording=false
	await _fresh(&"D6")
	button.disabled=true;_board.set_process(false);await settle(3)
	await snap("05-disabled");await click(button);await settle(3)
	_expect(rolls.size()==1,"disabled painted button cannot roll")
	_board.set_process(true);await _fresh(&"D6");button.release_focus()
	var key:=InputEventKey.new();key.keycode=KEY_SPACE;key.physical_keycode=KEY_SPACE;key.pressed=true
	root.push_input(key,true);await settle(1)
	key=InputEventKey.new();key.keycode=KEY_SPACE;key.physical_keycode=KEY_SPACE;key.pressed=false
	root.push_input(key,true);await settle(12)
	_expect(rolls.size()==2,"space shortcut still produces one roll")
	for id:StringName in [&"HOLDEM",&"SLOT_777",&"DICE_PINBALL",&"DICE_DARTS"]:
		await _fresh(id);await snap("tool-"+str(id))
		_expect(button.visible and not button.disabled,"%s action button is actually visible in its ready state"%id)
		var font:=button.get_theme_font("font")
		var pixels:int=button.get_theme_font_size("font_size")
		for line:String in button.text.split("\n"):
			_expect(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x<=button.size.x*0.72+1.0,"%s label stays inside painted face"%id)
		_expect(pixels>=14 and button.get_child_count()>=1,"%s preserves readable live label"%id)
	var board:MainBoard=_board;_board=null;board.queue_free();await settle(5)
	for failure:String in _failures:printerr("ROLL_ART_FAIL ",failure)
	print("ROLL_ART_NATIVE ",_failures.size()," failures; frames=",recorded_frames)
	MatchTelemetry.test_sender=Callable();quit(0 if _failures.is_empty() else 1)

func _fresh(id:StringName) -> void:
	quiet();_board._presenter.cancel();_board._fx_busy=false
	_board._beat_until_msec=0;_board._fx_until_msec=0
	_board.manager.current_turn_index=_board.manager.player_order.find(me)
	_board.state.tools[me]=ToolRegistry.create(id)
	_board.manager.change_state(TurnManager.State.PHASE_TURN_BEGIN)
	quiet();_board._refresh_all();await settle(12)
