## Restore presentation labels while preserving table goals and archived board data.
extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	MatchTelemetry.test_sender = func(_url: String, _body: PackedByteArray, _type: String) -> void: pass
	BoardSpec.apply(24)
	var laws := TestSpecialVictory.new()
	laws.tree=self
	laws.current_test="test_registry_makes_eight_victory_laws_with_table_goals"
	laws.test_registry_makes_eight_victory_laws_with_table_goals()
	laws.cleanup()
	var archive := preload("res://tests/test_live_hotfix.gd").new()
	archive.tree=self
	archive.current_test="test_special_win_archives_the_whole_board_and_law_before_retirement"
	archive.test_special_win_archives_the_whole_board_and_law_before_retirement()
	archive.cleanup()
	var failures: Array[String] = laws.failures+archive.failures
	for failure: String in failures: printerr("SPECIAL_CORE_FAIL ",failure)
	print("SPECIAL_CORE ",laws.assertions+archive.assertions," assertions; ",failures.size()," failures")
	MatchTelemetry.test_sender=Callable()
	quit(0 if failures.is_empty() else 1)

