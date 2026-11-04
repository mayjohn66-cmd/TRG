## Actual ACT_16 use -> existing announcement -> one neuralizer pulse -> clear.
extends "res://tests/capture_darts_integration.gd"
const FLASH=preload("res://scenes/neuralizer_flash.gd")

func _run() -> void:
	MatchTelemetry.test_sender=func(_url:String,_body:PackedByteArray,_type:String)->void:pass
	_board._on_draft_auto_pressed();await settle(15);quiet()
	_board.instant_roll_for_test=false
	var owner:int=_board._dock_owner()
	_board.manager.current_turn_index=_board.manager.player_order.find(owner)
	_board.manager.change_state(TurnManager.State.PHASE_TURN_BEGIN);quiet()
	_board.state.hands[owner]=[&"ACT_16"]
	var tip:=_board.get_node_or_null("FirstMatchTip") as CanvasLayer
	if tip!=null:tip.hide()
	_board._skill_hint.hide();_board._refresh_all();await settle(5)
	var rng_before:int=_board.state.rng.state
	recording=true;await settle(12)
	_board.manager.act(&"play_card",{"player_id":owner,"card_id":&"ACT_16"})
	var snapshot:=TurnSnapshot.capture(_board.state).data
	_expect(_board.state.amnesia_active() and _board.state.hands[owner].is_empty(),"actual card consumed and original round immunity applied")
	var effect:Node
	var signals:Array[int]=[0]
	var captured:Dictionary={}
	for i:int in 120:
		await process_frame
		if effect==null:
			effect=_board.find_child("NeuralizerFlash",true,false)
			if effect!=null:effect.flashed.connect(func()->void:signals[0]+=1)
		if is_instance_valid(effect) and effect._surface!=null:
			if effect.time>=0.60 and not captured.has("charge"):
				captured.charge=true
				_expect(not effect.fired and effect._paint.get_shader_parameter("pulse")==0.0,"light gathers without an early flash")
				await snap("01-device-charges")
			if effect.time>=1.35 and not captured.has("ready"):
				captured.ready=true
				_expect(not effect.fired and effect._paint.get_shader_parameter("charge")>0.90,"more than a second of visible charging precedes flash")
				_expect(effect.charge_count==1,"charging cue begins exactly once")
				if is_instance_valid(effect._charge_audio):_expect(effect._charge_audio.stream.get_length()>=FLASH.FIRE_AT-FLASH.CHARGE_AT,"charge tone spans the anticipation interval")
				await snap("01b-charge-nearly-ready")
			if effect.time>=FLASH.FIRE_AT+0.03 and not captured.has("flash"):
				captured.flash=true
				_expect(effect._paint.get_shader_parameter("pulse")>0.80,"one bright white-blue pulse")
				var art:TextureRect=(effect._preview_ref.get_ref() as Control).find_child("CardArt",true,false)
				_expect((effect._paint.get_shader_parameter("bulb") as Vector2).distance_to(art.get_global_transform_with_canvas()*(art.size*FLASH.LAMP_UV))<0.1,"light stays on actual artwork bulb after stamp transforms")
				_expect(effect._surface.mouse_filter==Control.MOUSE_FILTER_IGNORE,"light intercepts no input")
				await snap("02-neuralizer-flash")
			if effect.time>=FLASH.FIRE_AT+0.35 and not captured.has("after"):
				captured.after=true;await snap("03-blue-afterglow")
		if captured.has("after") and not _board._announcer.active:break
	await settle(8);await snap("04-board-restored");recording=false
	_expect(captured.size()==4 and signals[0]==1,"long charge then one pulse and afterglow")
	_expect(_board.find_child("NeuralizerLightLayer",true,false)==null,"flash layer removed at notice end")
	_expect(TurnSnapshot.capture(_board.state).data==snapshot and _board.state.rng.state==rng_before,"flash changes no gameplay, immunity duration or RNG")
	# Queued extras do not flash before display; cancelling/resetting clears an active light.
	_board._announcer.cancel()
	_board._announce("카드 발동","앞선 알림","",Color.GOLD,null,0.6,true)
	var pending:Control=_board._make_card_preview(&"ACT_16")
	var queued:=FLASH.new();pending.add_child(queued);queued.setup(_board,_board._announcer,pending)
	_board._announce("카드 발동","카드 발동!","",Color.GOLD,pending,1.1,true,{"key":"card"})
	await settle(5)
	_expect(not queued.fired and queued._layer==null,"parked card emits no premature flash")
	_board._announcer.cancel();await settle(3)
	_expect(_board.find_child("NeuralizerLightLayer",true,false)==null,"queued cancellation leaves no light")
	var preview:Control=_board._make_card_preview(&"ACT_16")
	var reset_flash:=FLASH.new();preview.add_child(reset_flash);reset_flash.setup(_board,_board._announcer,preview)
	_board._announce("카드 발동","카드 발동!","",Color.GOLD,preview,1.1,true,{"key":"card"})
	await settle(15);_board._reset_presentation();await settle(3)
	_expect(_board.find_child("NeuralizerLightLayer",true,false)==null,"generation reset during light releases overlay")
	if is_instance_valid(reset_flash._charge_audio):_expect(not reset_flash._charge_audio.playing,"reset stops the owned charge tone")
	_board._announcer.cancel();await settle(2)
	_expect(not _board._announcer.holding(),"existing announcement cancellation releases input gate")
	var skipped:Control=_board._make_card_preview(&"ACT_16")
	var skipped_flash:=FLASH.new();skipped.add_child(skipped_flash);skipped_flash.setup(_board,_board._announcer,skipped)
	var skipped_signals:Array[int]=[0]
	skipped_flash.flashed.connect(func()->void:skipped_signals[0]+=1)
	_board._announce("카드 발동","카드 발동!","",Color.GOLD,skipped,1.1,true,{"key":"card"})
	await settle(3);_board._announcer.skip_current();await settle(4)
	_expect(skipped_signals[0]==0 and _board.find_child("NeuralizerLightLayer",true,false)==null,"skip before firing produces no delayed flash")
	var fast:Control=_board._make_card_preview(&"ACT_16")
	var fast_flash:=FLASH.new();fast.add_child(fast_flash);fast_flash.setup(_board,_board._announcer,fast)
	var fast_signals:Array[int]=[0]
	fast_flash.flashed.connect(func()->void:fast_signals[0]+=1)
	_board._announce("카드 발동","카드 발동!","",Color.GOLD,fast,0.35,true,{"key":"card"})
	_expect(float(_board._announcer._current.get("duration",0.0))>=FLASH.NOTICE_SECONDS,"short notice reserves readable charge time")
	await settle(30)
	_expect(fast_signals[0]==0 and fast_flash.charge_count==1,"fast setting does not skip anticipation")
	await settle(48)
	_expect(fast_signals[0]==1 and _board.find_child("NeuralizerLightLayer",true,false)==null,"charge floor still fires once and clears")
	var board:MainBoard=_board;_board=null;board.queue_free();await settle(5)
	for failure:String in _failures:printerr("NEURALIZER_FAIL ",failure)
	print("NEURALIZER_NATIVE ",_failures.size()," failures; frames=",recorded_frames)
	MatchTelemetry.test_sender=Callable();quit(0 if _failures.is_empty() else 1)
