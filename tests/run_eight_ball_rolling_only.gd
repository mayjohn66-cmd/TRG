extends SceneTree
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	BoardSpec.apply(24)
	var probe:=TestPawnRenewal.new();probe.tree=self
	probe.current_test="eight_ball_capture_followup"
	probe.test_eight_ball_rolls_three_more_after_a_kill();probe.cleanup()
	probe.current_test="eight_ball_actual_bank_shot"
	probe.test_eight_ball_bank_shot_dashes_to_the_nearest_enemy_ahead();probe.cleanup()
	for failure:String in probe.failures:printerr("EIGHT_BALL_FAIL ",failure)
	print("EIGHT_BALL_CORE ",probe.assertions," assertions; ",probe.failures.size()," failures")
	quit(0 if probe.failures.is_empty() else 1)
