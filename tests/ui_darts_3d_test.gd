extends SceneTree
var checks := 0
var failures: Array[String] = []

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var view := DartBoardView.new()
	view.hide()
	root.add_child(view)
	await process_frame
	expect(not view.is_processing(), "idle view does not run a clock")
	expect(view._viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "hidden viewport sleeps")
	expect(view.mouse_filter == Control.MOUSE_FILTER_IGNORE, "3D view does not intercept board/card input")
	view.show()
	view.set_aiming(true)
	expect(view.is_processing(), "aim starts clock")
	expect(view._viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "visible aim renders")
	view._process(0.37)
	expect(view._camera.position.is_equal_approx(Vector3(0, 0, 8.5)), "aim camera stays frontal")
	for spin: float in [0.0, 0.19, 0.51, 0.99]:
		view._spin = spin
		view._aim_radius = 0.67
		view._present()
		var aim := view.current_aim()
		var local_hit := DartBoardView.hit_point(aim[0], aim[1], 0.0)
		var world_hit := view._board.transform * local_hit
		expect(Vector2(world_hit.x, world_hit.y).distance_to(Vector2(0, 1.34)) < 0.00001, "spinning visible target maps to engine aim")
	view.hide()
	var clock := view._clock
	await process_frame
	await process_frame
	expect(is_equal_approx(view._clock, clock), "hidden aim freezes")
	expect(view._viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "hidden aim stops rendering")
	view.show()
	for wedge: int in 12:
		for radius: float in [0.02, 0.25, 0.50, 0.70, 0.93]:
			var angle := (wedge + 0.5) / 12.0
			var hit := ToolDarts.score(radius, angle)
			var details := hit.duplicate()
			details.merge({"radius": radius, "angle": angle})
			view.begin(details)
			expect(not view.is_processing() and not view._reticle.visible, "result uses presenter clock only")
			view.apply_time(DartBoardView.FLIGHT_TIME - 0.01)
			expect(not view.settled and view._dart.position.z > DartBoardView.TIP_Z, "dart approaches before score reveal")
			view.apply_time(DartBoardView.FLIGHT_TIME)
			var expected := DartBoardView.hit_point(radius, angle)
			expect(view.settled and view._dart.position.distance_to(expected) < 0.00001, "embedded dart matches authoritative point")
			view.apply_time(0.53)
			expect(view._dart.position.distance_to(expected) < 0.00001, "wobble never slides tip")
			view.apply_time(DartBoardView.TOTAL_TIME)
			expect(view._dart.position.distance_to(expected) < 0.00001, "final point remains exact")
			expect(DartBoardView.caption(details, hit["steps"]) == ToolDarts.hit_text(details, hit["steps"]), "caption matches engine score")
	expect(is_equal_approx(DartBoardView.FACE_Z - DartBoardView.TIP_Z, 0.215), "needle visibly penetrates approved depth")
	view.set_aiming(true)
	expect(not view._dart.visible and view._reticle.visible and not view.settled, "next throw resets hit visuals")
	view.queue_free()
	await process_frame
	var preconfigured := DartBoardView.new()
	preconfigured.begin({"radius": 0.50, "angle": 0.375})
	root.add_child(preconfigured)
	preconfigured.apply_time(1.0)
	expect(preconfigured._dart.visible and preconfigured.settled, "result can be configured before ready")
	preconfigured.queue_free()
	await process_frame
	for failure: String in failures: printerr("DARTS_3D_FAIL ", failure)
	print("DARTS_3D ", checks, " assertions; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
