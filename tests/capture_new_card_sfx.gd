## Preview only: remote-only cards reach the real announcement cue dispatcher.
## No card registry, deck, hand or gameplay mutation is introduced.
extends "res://tests/capture_darts_integration.gd"
func _run() -> void:
	MatchTelemetry.test_sender=func(_url:String,_body:PackedByteArray,_type:String)->void:pass
	_board._on_draft_auto_pressed();await settle(15);quiet()
	_board.instant_roll_for_test=false
	var state_before:=TurnSnapshot.capture(_board.state).data
	var rng_before:int=_board.state.rng.state
	var deck_before:Dictionary=CardRegistry.DECK_COMPOSITION.duplicate(true)
	for row:Array in [[&"ACT_18",&"meddle"],[&"ACT_19",&"meddle"],[&"ACT_20",&"meddle"],[&"CNT_08",&"sword_cut"]]:
		var preview:=CenterContainer.new();preview.set_meta("card_preview_id",row[0])
		var label:=Label.new();label.text="효과음 연결 미리보기: "+String(row[0]);preview.add_child(label)
		Sfx._last_play_ms.erase(row[1])
		_board._announce("카드 발동","카드 발동!","",Color.GOLD,preview,0.5,true,{"key":"card"})
		await settle(6)
		_expect(Sfx._last_play_ms.has(row[1]),String(row[0])+" reaches its audio cue only when real announcement starts")
		_board._announcer.cancel();await settle(3)
	for id:StringName in [&"bounty_mark",&"meddle"]:
		Sfx._last_play_ms.erase(id);var before:int=Sfx._next
		Sfx.play(id);Sfx.play(id)
		_expect(Sfx._next==before+1,String(id)+" concurrent UI refreshes do not stack duplicate sounds")
	_expect(TurnSnapshot.capture(_board.state).data==state_before and _board.state.rng.state==rng_before and CardRegistry.DECK_COMPOSITION==deck_before,"preview cues do not register cards or change gameplay/RNG")
	var board:MainBoard=_board;_board=null;board.queue_free();await settle(5)
	for failure:String in _failures:printerr("NEW_CARD_SFX_FAIL ",failure)
	print("NEW_CARD_SFX_NATIVE ",_failures.size()," failures")
	MatchTelemetry.test_sender=Callable();quit(0 if _failures.is_empty() else 1)
