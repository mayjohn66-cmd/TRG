## Stock-only core checks; do not run the unrelated v1.1 suites.
extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	BoardSpec.apply(24)
	var probe := TestV11Content.new()
	probe.tree = self
	for method: String in ["test_stock_chart_events_and_price_walk","test_stock_delisting_ejects_the_lead_pawn_and_ends_the_turn"]:
		probe.current_test = method
		probe.call(method)
		probe.cleanup()
	probe.current_test = "latest_four_are_real_prices"
	var rng := RandomNumberGenerator.new()
	rng.seed = 88
	var tool := ToolStockChart.new()
	var expected: Array[int] = [ToolStockChart.BASE_PRICE]
	var previous_payload: Dictionary = {}
	var previous_copy: Dictionary = {}
	for i: int in 30:
		var result := tool.roll(rng)
		expected.append(int(result.details.price))
		if expected.size()>4: expected.pop_front()
		probe.check_eq(tool.history,expected,"tool keeps exactly the latest actual price records")
		probe.check_eq(result.details.history,expected,"roll payload is bounded to the same four records")
		probe.check_eq(previous_payload,previous_copy,"new rolls cannot mutate earlier published payloads")
		previous_payload = result.details
		previous_copy = result.details.duplicate(true)
	for failure: String in probe.failures: printerr("STOCK_CORE_FAIL ",failure)
	print("STOCK_CORE ",probe.assertions," assertions; ",probe.failures.size()," failures")
	quit(0 if probe.failures.is_empty() else 1)
