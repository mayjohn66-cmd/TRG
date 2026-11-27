extends SceneTree

var events: Array[StringName] = []
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func run() -> void:
	L10n.install()
	Sfx.test_event_observer=func(event: StringName, _db: float) -> void: events.append(event)
	for event: StringName in [&"paper_unfold",&"wrapper_tear",&"cookie_crack",&"stick_land"]:
		var sound:=Sfx.synth(event)
		check(sound!=null and sound.get_length()>0 and sound.get_length()<.3,"short cached audio exists: "+str(event))
		check(sound==Sfx.synth(event),"sound is cached: "+str(event))
	for fortune: StringName in [&"great",&"worst"]:
		var gate:=ToolHandGate.new()
		gate.setup(&"DICE_OMIKUJI",{"fortune":fortune,"ticket":1})
		root.add_child(gate)
		gate.set_process(false)
		events.clear()
		gate.draw()
		for frame: int in 90: gate._process(.04)
		check(events.count(&"omikuji_draw")==1,"draw sounds once")
		check(events.count(&"paper_unfold")==1,"unfold sounds once")
		check(events.count(&"good" if fortune==&"great" else &"bad")==1,"fortune result sounds once")
		check(events.count(&"ticket_rustle")== (2 if fortune==&"great" else 0),"only great fortune folds and ties")
		gate.free()
	var cookie:=ToolHandGate.new()
	cookie.setup(&"DICE_COOKIE",{"message":"천천히 가요","jackpot":true})
	root.add_child(cookie)
	cookie.set_process(false)
	events.clear()
	cookie.pick(0)
	for frame: int in 100: cookie._process(.04)
	check(events.count(&"cookie_crack")==1 and events.count(&"paper_unfold")==1,"cookie cracks and unfolds once")
	check(events.count(&"good")==1,"jackpot survives the direct-selection path")
	cookie.free()
	var ice:=IceboxPickArt.new()
	root.add_child(ice)
	ice.prepare_result({"again":true,"spaces":3})
	ice.take(0)
	ice.set_process(false)
	await create_timer(.6).timeout
	events.clear()
	for frame: int in 120: ice._process(.04)
	check(events.count(&"icecream_snap")==1,"one bite")
	check(events.count(&"icecream_reveal")==1 and events.count(&"good")==1,"stick reveal and extra turn")
	check(events.count(&"stick_land")==1,"winner stick lands once")
	ice.free()
	Sfx.test_event_observer=Callable()
	if failures.is_empty(): print("TOOL_AUDIO_OK")
	else:
		for message: String in failures: printerr("TOOL_AUDIO_FAIL ",message)
	quit(0 if failures.is_empty() else 1)
