## The existing core fixture uses the legacy 24-tile layout; keep it isolated
## from the native board's live BoardSpec and run no unrelated suites.
extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	BoardSpec.apply(24)
	var probe := TestV11Content.new()
	probe.tree = self
	probe.current_test = "bounty_core"
	probe.test_bounty_marks_the_leading_enemy_and_pays_ten_on_capture()
	probe.cleanup()
	for failure: String in probe.failures: printerr("BOUNTY_FAIL ", failure)
	print("BOUNTY_CORE ", probe.assertions, " assertions; ", probe.failures.size(), " failures")
	quit(0 if probe.failures.is_empty() else 1)
