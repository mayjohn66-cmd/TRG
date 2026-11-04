## Targeted native mixer, scene cue lifecycle and independent voice controls.
## Run with --audio-driver Dummy; never uses the user's output device or saves.
extends SceneTree
var failures:Array[String]=[]
var checks:int=0
var capture:AudioEffectCapture
var host:Control
var out:=OS.get_environment("DARTS_CAPTURE_OUT")

func _initialize() -> void:_run.call_deferred()
func expect(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label)
func frames(n:int=2) -> void:
	for i:int in n:await process_frame
func quiet() -> void:
	for player:AudioStreamPlayer in Sfx._pool:player.stop()
	if Sfx._voice!=null:Sfx._voice.stop()
	PresentationAudio.stop_tree(host)
func peak_after(seconds:float=0.22) -> float:
	await create_timer(seconds).timeout
	var pcm:=capture.get_buffer(capture.get_frames_available());var peak:float=0.0
	for sample:Vector2 in pcm:peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
	expect(pcm.size()>0,"mixer produces PCM frames")
	return peak
func seen(events:Array) -> void:
	for event:Variant in events:expect(Sfx._last_play_ms.has(StringName(event)),"scene cue fired: "+String(event))

func _run() -> void:
	GameSession.audio_muted=false;GameSession.sfx_muted=false;GameSession.voice_muted=false
	GameSession.sfx_volume=1.0;GameSession.voice_volume=1.0;GameSession.master_volume=1.0
	Sfx.unlock();await frames(3);Sfx.apply_settings()
	host=Control.new();host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(host)
	capture=AudioEffectCapture.new();capture.buffer_length=1.0;AudioServer.add_bus_effect(0,capture)
	var entries:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/sfx/curated/manifest.json"))
	var tested:int=0
	for entry:Dictionary in entries:
		if not entry.has("loop_ready"):continue
		var id:=StringName(entry.event);quiet();capture.clear_buffer()
		var stream:AudioStream=Sfx._stream_for(id)
		expect(stream is AudioStreamOggVorbis and stream.get_length()>0.02,"file decodes: "+String(id))
		if stream is AudioStreamOggVorbis:expect(not stream.loop,"shared cue resource never loops: "+String(id))
		Sfx.play(id,0.0,0.0);var peak:float=await peak_after()
		expect(peak>0.0002 and peak<0.75,"non-silent unclipped mix: "+String(id))
		print("NEW_AUDIO_PCM ",id," peak=",peak);tested+=1
	expect(tested==40,"all 40 new files tested")
	quiet();await frames()
	# Static poses cannot make sound. Skipping never replays a backlog of impacts.
	var timeline:=PresentationAudio.new()
	for id:String in ["LAW_01","LAW_02","LAW_03","LAW_04","LAW_05","LAW_06","LAW_07","LAW_08","LAW_09","FINISH"]:
		var plan:=PresentationAudio.victory_plan(id,1.0,7.0,true);timeline.start(host,plan)
		for cue:Dictionary in plan:
			expect(Sfx.has_sound(cue.event),id+" has a real cue for its action")
		timeline.advance(100.0)
		expect(timeline._players.is_empty(),id+" jump skips stale cues")
		timeline.cancel()
	timeline.start(host,[PresentationAudio.cue(0.0,&"proton_hum",0.0,5.0)])
	timeline.advance(0.0);expect(timeline._players.size()==1,"owned loop begins")
	var loop:AudioStreamPlayer=timeline._players[0].player
	expect(loop.stream!=Sfx._stream_for(&"proton_hum") and loop.stream.loop,"loop uses a private stream copy")
	host.hide();timeline.advance(0.1);expect(not loop.playing,"hiding cancels owned loop");await frames();host.show()
	await _scenes()
	await _voice_settings()
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1);capture=null
	host.queue_free();await frames(3)
	for failure:String in failures:printerr("NEW_AUDIO_FAIL ",failure)
	print("NEW_CONTENT_AUDIO ",checks," assertions; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

func _scenes() -> void:
	quiet();Sfx._last_play_ms.clear()
	var roll:=RollPresenter.new();host.add_child(roll)
	roll.play(&"DICE_DARTS",{"steps":10,"details":{"radius":0.0,"angle":0.0,"bull":true}})
	await create_timer(0.90).timeout;seen(["dart_throw","dart_hit","dart_bull"]);roll.cancel()
	for event:StringName in [ToolStockChart.EVENT_LIMIT_UP,ToolStockChart.EVENT_DELISTED]:
		roll.play(&"DICE_STOCK",{"steps":20,"details":{"before":8,"price":20 if event==ToolStockChart.EVENT_LIMIT_UP else 0,"delta":12 if event==ToolStockChart.EVENT_LIMIT_UP else -8,"event":event,"history":[8,20]}})
		await create_timer(2.15).timeout;roll.cancel()
	seen(["stock_up","stock_down","stock_bull","stock_bear"]);roll.queue_free()
	var forge:=HammerForgeView.new();host.add_child(forge);forge.show_level(2,true)
	await create_timer(0.85).timeout;seen(["hammer_swing","hammer_hit","hammer_success"])
	forge.begin_break(2,1.0);await create_timer(0.9).timeout;seen(["hammer_break"]);forge.cancel();forge.queue_free()
	var fruit=(preload("res://scenes/cucumber_eat_fx.gd")).new();host.add_child(fruit)
	fruit.begin(PawnArt.load_sprite(["res://assets/board/structures/CUCUMBER_V01.png"]),Vector2(300,350),Vector2(400,300),90)
	await create_timer(1.25).timeout;expect(fruit._audio._seen.size()==3,"three real cucumber bites have three cues");fruit.cancel();fruit.queue_free()
	var beam:=ProtonBeamView.new();host.add_child(beam);beam.position=Vector2(650,400);beam.descend(0.20)
	await create_timer(0.35).timeout;seen(["proton_descend","proton_land","proton_hum"])
	var hum:AudioStreamPlayer=beam._hum;expect(is_instance_valid(hum) and hum.playing,"real landed beam owns its hum")
	beam.fade_out(0.3);await create_timer(0.4).timeout
	expect(not is_instance_valid(beam) and not is_instance_valid(hum),"beam disappearance frees hum")
	var cut:=VictoryCutscene.new();host.add_child(cut)
	cut.setup(VictoryCutscene.MODE_LAW,Color.GOLD,null,null,"특수 승리!","테스트","","테스트")
	cut.set_law_context("LAW_05",Vector2(650,350),&"avatar_01","테스트",1)
	cut.set_time(2.0);expect(cut._audio._players.is_empty(),"static victory sample is silent")
	cut.play(1.0);await create_timer(0.45).timeout;seen(["law_confirm"])
	cut.cancel();await frames();expect(cut._audio._players.is_empty(),"cancelling actual victory stops scene-owned audio");cut.queue_free()
	quiet();await frames()

func _voice_settings() -> void:
	var path:=AvatarCatalog.select_voice_path(&"avatar_01")
	expect(path!="" and Sfx.VOICE_GAINS.DB.size()==8,"eight voice gains mapped to original recordings")
	GameSession.sfx_muted=true;GameSession.voice_muted=false;Sfx.apply_settings();capture.clear_buffer()
	Sfx.play_voice(path);var full_peak:float=await peak_after(0.45)
	expect(full_peak>0.005 and Sfx._voice.bus==Sfx.BUS_VOICE,"voice is audible independently of SFX mute")
	quiet();GameSession.voice_volume=0.25;Sfx.apply_settings();capture.clear_buffer();Sfx.play_voice(path)
	var low_peak:float=await peak_after(0.45)
	expect(low_peak>0.0001 and low_peak<full_peak*0.40,"voice slider gain changes actual output")
	quiet();GameSession.voice_muted=true;GameSession.sfx_muted=false;Sfx.apply_settings();capture.clear_buffer();Sfx.play_voice(path)
	expect(await peak_after()<0.00001,"voice mute suppresses dialogue")
	capture.clear_buffer();Sfx.play(&"dart_hit",0,0);expect(await peak_after()>0.001,"SFX remains audible when voice is muted")
	quiet();GameSession.voice_muted=false;GameSession.voice_volume=0.60;GameSession.save_settings()
	GameSession.voice_volume=1.0;GameSession.load_settings()
	expect(is_equal_approx(GameSession.voice_volume,0.60) and not GameSession.voice_muted,"voice setting survives save/load")
	var panel:=VBoxContainer.new();panel.position=Vector2(80,80);panel.size=Vector2(600,250);host.add_child(panel)
	LobbyTheme.add_audio_controls(panel,Color.WHITE);await frames(4)
	var slider:=panel.find_child("VoiceVolume",true,false) as HSlider
	var mute:=panel.find_child("VoiceMute",true,false) as Button
	expect(slider!=null and mute!=null,"actual settings offer independent voice controls")
	var sfx_before:float=GameSession.sfx_volume;slider.value=0.30
	expect(is_equal_approx(GameSession.voice_volume,0.30) and is_equal_approx(GameSession.sfx_volume,sfx_before),"actual voice slider handler changes only voice")
	mute.button_pressed=true;expect(GameSession.voice_muted and AudioServer.is_bus_mute(AudioServer.get_bus_index(Sfx.BUS_VOICE)),"actual voice mute handler reaches its bus")
	mute.button_pressed=false;slider.drag_ended.emit(true)
	expect(Sfx._voice.playing,"voice slider release previews the selected character")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out.path_join("voice-controls-native.png"))
	panel.queue_free();quiet();await frames(2)
	LobbyTheme.show_settings(host);await frames(4)
	var overlay:=host.get_node("Popup") as Control
	var settings_panel:=overlay.get_child(1).get_child(0) as Control
	var bounds:Rect2=settings_panel.get_global_rect()
	expect(bounds.position.y>=0.0 and bounds.end.y<=root.size.y,"complete settings popup with voice row fits the viewport")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out.path_join("voice-settings-native.png"))
	overlay.queue_free();await frames(2)
	var config:=ConfigFile.new();config.set_value("game","sfx_volume",0.35);config.set_value("game","sfx_muted",true);config.save(GameSession.SETTINGS_PATH)
	GameSession.load_settings();expect(is_equal_approx(GameSession.voice_volume,0.35) and GameSession.voice_muted,"old saves inherit their previous SFX voice gain and mute")
	GameSession.reset_settings();expect(is_equal_approx(GameSession.voice_volume,0.8) and not GameSession.voice_muted,"reset restores voice defaults")
