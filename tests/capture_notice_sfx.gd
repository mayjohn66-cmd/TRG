## Real notice pointer flow and actual mixer capture, always with Dummy audio.
extends "res://tests/capture_notice_button_art.gd"
var capture:AudioEffectCapture

func _mix_result(label:String,audible:bool=true) -> void:
	await create_timer(0.28).timeout
	var pcm:=capture.get_buffer(capture.get_frames_available())
	var peak:float=0.0
	for sample:Vector2 in pcm:peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
	expect(pcm.size()>0,label+" has mixer frames")
	expect(peak>0.0002 and peak<0.90 if audible else peak<0.00001,label+" mixer level / mute")
	print("NOTICE_SFX_PCM ",label," peak=",peak," frames=",pcm.size())

func _tap_at(point:Vector2) -> void:
	var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	root.push_input(event,true);await process_frame
	event=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT
	root.push_input(event,true);await process_frame

func _run() -> void:
	MatchTelemetry.test_sender=func(_url:String,_body:PackedByteArray,_type:String)->void:pass
	GameSession.nickname="효과음 확인";GameSession.audio_muted=false;GameSession.sfx_muted=false
	menu=(load("res://scenes/start_menu.tscn") as PackedScene).instantiate()
	menu.change_scene_enabled=false;root.add_child(menu);await settle(35);menu._show_step(2)
	GameSession.audio_muted=false;GameSession.sfx_muted=false;GameSession.sfx_volume=1.0
	Sfx.unlock();Sfx.apply_settings();await settle(3)
	if Sfx._bgm!=null:Sfx._bgm.stop()
	for voice:AudioStreamPlayer in Sfx._pool:voice.stop()
	capture=AudioEffectCapture.new();capture.buffer_length=1.0
	AudioServer.add_bus_effect(0,capture)
	var button:=menu.find_child("HubUpdates",true,false) as Button
	expect(button!=null and menu.find_child("TipBar",true,false)==null,"notice button exists without removed tip")
	if button==null:quit(1);return
	for event:StringName in [&"notice_open",&"notice_close"]:
		expect(Sfx.has_sound(event),String(event)+" has an actual file")
		var stream:AudioStream=Sfx._stream_for(event)
		expect(stream is AudioStreamOggVorbis and stream.get_length()>0.08 and stream.get_length()<0.25,String(event)+" decodes as short non-looping Vorbis")
		if stream is AudioStreamOggVorbis:expect(not stream.loop,String(event)+" does not loop")
	# Reapplying a skin must retain the explicit cue and never stack click sounds.
	Sfx.bind_button(button);Sfx.bind_button(button,&"notice_open")
	await hover(button);capture.clear_buffer();var before:int=Sfx._next
	await pointer(button,true);await pointer(button,false);await settle(2)
	var popup:=menu.find_child("UpdateNotesPopup",true,false) as Control
	expect(popup!=null and Sfx._next==before+1,"actual notice click opens popup with exactly one cue")
	expect(Sfx._last_play_ms.has(&"notice_open"),"open cue is the notice-specific event")
	await _mix_result("open")
	if popup==null:quit(1);return
	var close:=popup.find_child("NotesClose",true,false) as Button
	await hover(close);capture.clear_buffer();before=Sfx._next
	await pointer(close,true);await pointer(close,false);await settle(2)
	expect(not is_instance_valid(popup) and Sfx._next==before+1,"close button dismisses popup with exactly one cue")
	expect(Sfx._last_play_ms.has(&"notice_close"),"close cue is the notice-specific event")
	await _mix_result("close-button")
	await hover(button);await pointer(button,true);await pointer(button,false);await _mix_result("reopen")
	capture.clear_buffer();before=Sfx._next
	await _tap_at(Vector2(20,300));await settle(2)
	expect(menu.find_child("UpdateNotesPopup",true,false)==null and Sfx._next==before+1,"dim-background dismissal plays one close cue")
	await _mix_result("close-outside")
	GameSession.audio_muted=true;Sfx.apply_settings();capture.clear_buffer();before=Sfx._next
	await hover(button);await pointer(button,true);await pointer(button,false);await settle(2)
	expect(menu.find_child("UpdateNotesPopup",true,false)!=null and Sfx._next==before,"master mute keeps the notice usable without starting audio")
	await _mix_result("master-muted",false)
	await _tap_at(Vector2(20,300))
	GameSession.audio_muted=false;GameSession.sfx_muted=true;Sfx.apply_settings();capture.clear_buffer()
	await hover(button);await pointer(button,true);await pointer(button,false)
	await _mix_result("sfx-muted",false)
	await _tap_at(Vector2(20,300));GameSession.sfx_muted=false;Sfx.apply_settings()
	var legacy:=Button.new();Sfx.bind_button(legacy);Sfx.bind_button(legacy)
	capture.clear_buffer();before=Sfx._next;legacy.pressed.emit()
	expect(Sfx._next==before+1,"unchanged default buttons still emit one standard click")
	await _mix_result("legacy-click");legacy.free()
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1);capture=null
	menu.queue_free();await settle(4);MatchTelemetry.test_sender=Callable()
	for failure:String in failures:printerr("NOTICE_SFX_FAIL ",failure)
	print("NOTICE_SFX_NATIVE ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
