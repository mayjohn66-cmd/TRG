extends "res://tests/ui_counter_sequence_test.gd"

func _run() -> void:
	MatchTelemetry.test_sender = func(_url: String, _body: PackedByteArray, _type: String) -> void: pass
	await _scenario(&"CNT_08")
	if board != null:
		board._reset_presentation()
		board.queue_free()
		await process_frame
	print("BIGWOOD_NATIVE_COUNTER failures=", failures.size())
	MatchTelemetry.test_sender = Callable()
	quit(0 if failures.is_empty() else 1)
