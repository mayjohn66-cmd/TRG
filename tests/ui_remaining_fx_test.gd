## Only the changed shared toss accents; reuse existing result/landing/reset checks.
extends "res://tests/ui_fx_test.gd"

func _run() -> void:
	_board.instant_roll_for_test = true
	_board._close_opening()
	_board._on_draft_auto_pressed()
	for index: int in 4:
		await process_frame
	_board.ai_mode = false
	_board._bot.set_enabled(false)
	_board.manager.set_process(false)
	_board.pacing_enabled = false
	_board._announcer.cancel()
	_board._reset_presentation()
	_board._close_draft_overlay()
	_board._close_augment_review()
	await _test_board_toss()
	await _test_yut_throw()
	await _capture_contacts()
	_board.queue_free()
	await process_frame
	if _failures.is_empty():
		print("UI_REMAINING_FX_OK")
		quit(0)
	else:
		for failure: String in _failures:
			printerr("UI_REMAINING_FX_FAIL: "+failure)
		quit(1)

func _capture_contacts() -> void:
	var folder := OS.get_environment("REMAINING_FX_CAPTURE_DIR")
	if folder.is_empty(): return
	_board._announcer.cancel()
	_board._close_draft_overlay()
	_board._close_augment_review()
	_board.set_process(false)
	_board._roll_button.hide()
	_board._roll_pad.hide()
	await process_frame
	var presenter: RollPresenter = _board._presenter
	presenter.instant = false
	presenter.toss_from = _board._profile_center(1)
	presenter.play(&"D6",{"tool_id":&"D6","steps":5,"details":{"face":5}},0.8)
	presenter.set_process(false)
	await process_frame
	var at := RollPresenter.TOSS_CONTACTS[0]*RollPresenter.TOSS_LAND_TIME+0.07
	presenter._update(at)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("dice_contact.png"))
	presenter.cancel()
	presenter.play(&"YUT",{"steps":3,"details":{"face":3}},0.8)
	presenter.set_process(false)
	await process_frame
	presenter._update(RollPresenter.real_time(&"YUT",YutThrow3D.impact_time(1))+0.06)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("yut_contact.png"))
	presenter.cancel()
