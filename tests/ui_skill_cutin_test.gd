## Only skill cutin timing, queueing, skip and cleanup.
extends SceneTree

var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures.append(note)

func run() -> void:
	var announcer := EventAnnouncer.new()
	root.add_child(announcer)
	announcer.set_process(false)
	var art := PawnArt.load_sprite(["res://content_trickcal/illustrations/pawns/CHESS_KNIGHT.png"])
	check(not art.is_empty(), "production knight cutout loads")
	if art.is_empty():
		quit(1)
		return
	var clock := Engine.time_scale
	var cutin := PawnSkillCutin.new()
	cutin.setup(art, Color("ef6974"))
	announcer.announce("필살기","필살기 발동!","",Color("ef6974"),cutin,1.3,true,{"key":"skill","sub":"기사의 맹세","cinematic":true})
	announcer._process(0.04)
	check(cutin._sprite.modulate.a == 0.0, "band leads the illustration")
	announcer._process(0.30)
	var held := cutin._sprite.position
	check(held.is_equal_approx(Vector2(65,-14)), "illustration reaches its held pose")
	check(is_equal_approx(announcer.scale.x,1.0), "cutin is not enlarged by the generic stamp slam")
	announcer._process(0.50)
	check(cutin._sprite.position.is_equal_approx(held), "held image stays still")
	var queued := PawnSkillCutin.new()
	queued.setup(art, Color("75a9e1"))
	announcer.announce("필살기","필살기 발동!","",Color("75a9e1"),queued,1.3,true,{"key":"skill","sub":"기사의 맹세","cinematic":true})
	check(queued._time == 0.0 and not queued.is_visible_in_tree(), "queued cutin does not run early")
	announcer._process(0.40)
	check(cutin._sprite.position.x > held.x and cutin._sprite.modulate.a < 1.0, "exit moves right and closes")
	announcer.skip_current()
	announcer._process(0.01)
	await process_frame
	check(not is_instance_valid(cutin), "skipped cutin is freed")
	check(queued._time == 0.0 and queued.is_visible_in_tree(), "next cutin starts at its entrance")
	announcer._process(0.35)
	announcer.cancel()
	await process_frame
	check(not announcer.active and not is_instance_valid(queued), "cancel removes current cutin")
	check(Engine.time_scale == clock, "presentation preserves simulation clock")
	announcer.instant = true
	var instant := PawnSkillCutin.new()
	instant.setup(art, Color.WHITE)
	announcer.announce("필살기","필살기 발동!","",Color.WHITE,instant,1.3,true,{"cinematic":true})
	check(not is_instance_valid(instant), "instant mode does not retain an image")
	for pace_duration: float in [0.325, 2.6]:
		var paced := PawnSkillCutin.new()
		paced.setup(art, Color.WHITE)
		paced.set_presentation_time(pace_duration * 0.5, pace_duration)
		check(paced._sprite.position.is_equal_approx(Vector2(65,-14)), "pace preserves held phase")
		paced.set_presentation_time(pace_duration * 0.95, pace_duration)
		check(paced._sprite.position.x > 65, "pace preserves directional exit")
		paced.free()
	announcer.queue_free()
	if failures.is_empty():
		print("SKILL_CUTIN_OK ", checks)
		quit()
	else:
		for failure: String in failures: push_error(failure)
		quit(1)
