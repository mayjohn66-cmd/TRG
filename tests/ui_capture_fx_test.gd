## Only the capture overlay: painted assets, all attack kinds, hold and cleanup.
extends SceneTree

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void: _run.call_deferred()

func _expect(ok: bool, note: String) -> void:
	_checks += 1
	if not ok: _failures.append(note)

func _capture(tag: String) -> void:
	var folder := OS.get_environment("CAPTURE_FX_DIR")
	if folder.is_empty(): return
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(folder.path_join(tag + ".png")) == OK, "Saved " + tag)

func _run() -> void:
	root.size = Vector2i(1366, 768)
	root.content_scale_size = root.size
	var background := ColorRect.new()
	background.color = Color("d6e7aa")
	background.size = Vector2(root.size)
	root.add_child(background)
	var cutin := CaptureCutin.new()
	root.add_child(cutin)
	_expect(cutin._motion_brush != null and cutin._pierce != null and cutin._magic != null, "All painted accent textures load")
	_expect(cutin._motion_brush.get_width() <= 1024 and cutin._pierce.get_width() <= 1024 and cutin._magic.get_width() <= 1024, "Runtime texture sizes are bounded")
	_expect(cutin.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Overlay does not leave an input blocker")
	var impacts: Array[bool] = []
	cutin.impact.connect(func() -> void: impacts.append(true))
	var scale_before := Engine.time_scale
	var ids := AvatarCatalog.ids()
	for index: int in ids.size():
		var avatar: StringName = ids[index]
		cutin.cancel()
		impacts.clear()
		_expect(cutin.enqueue(avatar, ids[(index + 3) % ids.size()], 1, 2), "Enqueue " + str(avatar))
		cutin.set_process(false)  # Sample the production renderer at exact visual beats.
		cutin._process(0.10)
		_expect(impacts.is_empty(), "No early impact for " + str(avatar))
		cutin._process(0.09)
		var held := CaptureCutin.trail_time(cutin.elapsed)
		cutin._process(0.04)
		_expect(CaptureCutin.trail_time(cutin.elapsed) == held, "Painted trails freeze with the actors for " + str(avatar))
		_expect(impacts.size() == 1, "One impact across the held pose for " + str(avatar))
		_expect(cutin._attack != null and cutin._hit != null, "Original character poses load for " + str(avatar))
		await process_frame
		if index in [0, 1, 4, 6]:
			await _capture("capture-" + str(CaptureCutin.impact_kind(avatar)))
		cutin._process(0.24)
		_expect(CaptureCutin.trail_time(cutin.elapsed) > held, "Paint resumes after the hold for " + str(avatar))
		cutin._process(CaptureCutin.DURATION)
		_expect(not cutin.busy() and not cutin.visible and not cutin.is_processing(), "Overlay finishes cleanly for " + str(avatar))
	_expect(Engine.time_scale == scale_before, "The cutscene never changes the simulation clock")
	for extent: Vector2i in [Vector2i(1024, 768), Vector2i(1920, 800)]:
		root.size = extent
		root.content_scale_size = extent
		background.size = Vector2(extent)
		await process_frame
		cutin.enqueue(&"avatar_07", &"avatar_02", 1, 2)
		cutin.set_process(false)
		cutin._process(0.23)
		await process_frame
		var caption := CaptureCutin.caption_rect(cutin.size, cutin._strike_region.size.x / cutin._strike_region.size.y, 1.08)
		_expect(Rect2(Vector2.ZERO, cutin.size).encloses(caption), "Caption fits " + str(extent))
		cutin.cancel()
		_expect(not cutin.busy() and not cutin.visible, "Cancel clears the accents at " + str(extent))
	cutin.queue_free()
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("UI_CAPTURE_FX_OK: %d checks" % _checks)
		quit(0)
	else:
		for failure: String in _failures: printerr("UI_CAPTURE_FX_FAIL: " + failure)
		quit(1)
