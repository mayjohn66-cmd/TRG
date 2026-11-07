## Cues follow a visible presentation clock. Static poses never call advance().
## Every player belongs to its scene and is stopped on cancellation or hiding.
class_name PresentationAudio
extends RefCounted
var _owner:WeakRef
var _cues:Array[Dictionary]=[]
var _seen:Dictionary={}
var _players:Array[Dictionary]=[]

func start(owner:CanvasItem,cues:Array[Dictionary]=[]) -> void:
	cancel();_owner=weakref(owner);_cues=cues.duplicate(true);_seen.clear()

static func cue(at:float,event:StringName,db:float=0.0,until:float=-1.0) -> Dictionary:
	return {"at":at,"event":event,"db":db,"until":until}

func fire(event:StringName,db:float=0.0,loop:bool=false) -> AudioStreamPlayer:
	var owner:CanvasItem=_owner.get_ref() as CanvasItem if _owner!=null else null
	if owner==null or not owner.is_inside_tree() or not owner.is_visible_in_tree():return null
	if not Sfx.enabled() or GameSession.audio_muted or GameSession.sfx_muted:return null
	var now:int=Time.get_ticks_msec()
	if Sfx.MIN_INTERVAL_MS.has(event) and now-int(Sfx._last_play_ms.get(event,-10000))<int(Sfx.MIN_INTERVAL_MS[event]):return null
	var stream:AudioStream=Sfx._stream_for(event)
	if stream==null:return null
	if loop:
		stream=stream.duplicate() as AudioStream
		if stream is AudioStreamOggVorbis:stream.loop=true
	Sfx.apply_settings()
	var player:=AudioStreamPlayer.new();player.name="Cue_"+String(event)
	player.bus=Sfx.BUS_SFX;player.stream=stream;player.volume_db=db
	owner.add_child(player);player.play()
	Sfx._last_play_ms[event]=now
	_players.append({"player":player,"until":-1.0,"db":db})
	if not loop:player.finished.connect(player.queue_free,CONNECT_ONE_SHOT)
	return player

static func one_shot(owner:CanvasItem,event:StringName,db:float=0.0) -> void:
	var audio:=PresentationAudio.new();audio.start(owner);audio.fire(event,db)

static func stop_tree(owner:Node) -> void:
	for node:Node in owner.find_children("Cue_*","AudioStreamPlayer",true,false):
		var player:=node as AudioStreamPlayer;player.stop();player.queue_free()

func advance(seconds:float) -> void:
	var owner:CanvasItem=_owner.get_ref() as CanvasItem if _owner!=null else null
	if owner==null or not owner.is_visible_in_tree():cancel();return
	for voice:Dictionary in _players:
		if is_instance_valid(voice.player) and float(voice.until)>0.0:
			voice.player.volume_db=float(voice.db)+linear_to_db(clampf((float(voice.until)-seconds)/0.18,0.0001,1.0))
		if is_instance_valid(voice.player) and float(voice.until)>=0.0 and seconds>=float(voice.until):
			voice.player.stop();voice.player.queue_free()
	for i:int in _cues.size():
		var entry:Dictionary=_cues[i]
		if _seen.has(i) or seconds<float(entry.at):continue
		_seen[i]=true
		# A jump/skip never dumps all missed impacts into a single frame.
		if seconds-float(entry.at)>0.25:continue
		var player:=fire(entry.event,float(entry.db),float(entry.until)>float(entry.at))
		if player!=null:_players[-1].until=entry.until

func cancel() -> void:
	for voice:Dictionary in _players:
		if is_instance_valid(voice.player):voice.player.stop();voice.player.queue_free()
	_players.clear();_cues.clear();_seen.clear()

static func victory_plan(id:String,offset:float,finale:float,confirm:bool) -> Array[Dictionary]:
	var cues:Array[Dictionary]=[]
	if confirm:cues.append(cue(0.28,&"law_confirm"))
	match id:
		"LAW_01":cues.append(cue(offset+0.54,&"sword_plant"))
		"LAW_02":
			for i:int in 6:cues.append(cue(offset+0.18+i*0.34,&"ticket_rustle"))
			cues.append(cue(offset+3.20,&"ticket_join"))
		"LAW_03":
			for i:int in 5:cues.append(cue(offset+0.82+i*0.21,&"trap_embed",-2.0))
			cues.append(cue(offset+3.08,&"hero_impact"))
		"LAW_04":cues.append(cue(offset+0.54,&"casino_win"))
		"LAW_05":
			cues.append(cue(offset+0.08,&"magic_draw"))
			cues.append(cue(offset+1.10,&"magic_complete"))
		"LAW_06":cues.append(cue(offset+1.58,&"pawn_fall"))
		"LAW_07":
			for i:int in 3:cues.append(cue(offset+0.3+i*0.45,&"die_rain",-2.0))
			cues.append(cue(offset+2.05,&"magic_complete",-4.0))
		"LAW_08":
			for i:int in 3:cues.append(cue(offset+0.54+i*0.24,&"sword_cut"))
			cues.append(cue(offset+1.95,&"hero_impact"))
		"LAW_09":
			cues.append(cue(offset+0.02,&"hurricane_wind",-2.0,offset+2.55))
			cues.append(cue(offset+0.66,&"hero_impact",-2.0))
		"FINISH":cues.append(cue(offset+1.95,&"race_skid"))
	if finale>=0.0:cues.append(cue(offset+finale,&"magic_complete",-7.0))
	return cues
