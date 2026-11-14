## Real MainBoard buy-button actions, using searched RNG seeds for five outcomes.
extends "res://tests/capture_darts_integration.gd"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(capture_out.path_join("stock-frames"))
	RenderingServer.frame_post_draw.connect(_save_stock_frame)

func _save_stock_frame() -> void:
	if recording:
		root.get_texture().get_image().save_webp(capture_out.path_join("stock-frames/frame-%04d.webp" % recorded_frames),true,0.97)
		recorded_frames += 1

func _make_tool(before: int) -> ToolStockChart:
	var tool := ToolStockChart.new()
	tool.price = before
	tool.history.assign([6,4,8,before])
	return tool

func _seed_for(kind: String,before: int) -> int:
	for seed_value: int in 2000:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var result := _make_tool(before).roll(rng)
		var event := StringName(result.details.event)
		if kind=="limit_up" and event==&"limit_up": return seed_value
		if kind=="delisted" and event==&"delisted": return seed_value
		if event!=&"": continue
		var delta := int(result.details.price)-before
		if (kind=="up" and delta>0) or (kind=="down" and delta<0) or (kind=="flat" and delta==0): return seed_value
	return -1

func _run() -> void:
	MatchTelemetry.test_sender = func(_url: String,_body: PackedByteArray,_type: String) -> void: pass
	_board._on_draft_auto_pressed()
	await settle(15)
	quiet()
	var manager: TurnManager = _board.manager
	var state: GameState = _board.state
	var me := _board.local_player_id
	manager.event_received.connect(func(kind: StringName,data: Dictionary) -> void:
		if kind==&"roll_resolved": observed.append(data["result"]))
	_board.instant_roll_for_test = false
	recording = true
	var names := ["up","down","flat","limit_up","delisted"]
	var only := OS.get_environment("STOCK_CAPTURE_ONLY")
	if only in names: names = [only]
	for kind: String in names:
		manager.current_turn_index = manager.player_order.find(me)
		manager.change_state(TurnManager.State.PHASE_TURN_BEGIN)
		quiet()
		var before := 8 if kind=="down" else 6
		state.tools[me] = _make_tool(before)
		_board._fx_busy = false
		_board._refresh_all()
		await settle(10)
		var chosen_seed := _seed_for(kind,before)
		_expect(chosen_seed>=0,"searched seed exists for "+kind)
		state.rng.seed = chosen_seed
		await click(_board._roll_button)
		var intro_frame := roundi(StockChartView.LIVE_AT*0.6*30.0)
		var live_frame := roundi((StockChartView.LIVE_AT+(StockChartView.DRAW_TIME-StockChartView.LIVE_AT)*0.5)*30.0)
		var result_frame := roundi((StockChartView.STAMP_AT+0.35)*30.0)
		await settle(intro_frame)
		await snap("stock-"+kind+"-enter")
		_expect(_board._presenter._stock_view.announcement_text().begins_with("오늘의 주식은."),"animated-dot announcement visible before tick")
		await settle(live_frame-intro_frame)
		await snap("stock-"+kind+"-live")
		_expect(not _board._presenter._stock_view.settled,"stock outcome is not revealed during live tape")
		await settle(result_frame-live_frame)
		await snap("stock-"+kind+"-result")
		_expect(_board._presenter._stock_view.settled,"stock result settles for "+kind)
		var outcome: Dictionary = observed[-1]
		_expect(_board._presenter.last_display==StockChartView.caption(outcome.details,outcome.steps),"native caption equals actual roll")
		print("STOCK_CHART_NATIVE ",kind," ",JSON.stringify(outcome))
		await settle(roundi((StockChartView.TOTAL_TIME+0.30)*30.0)-result_frame)
		_expect(not _board._presenter.active and not _board._fx_busy,"stock presentation releases controls")
	recording = false
	for failure: String in _failures: printerr("STOCK_CHART_FAIL ",failure)
	print("STOCK_CHART_NATIVE ",recorded_frames," frames; ",_failures.size()," failures")
	MatchTelemetry.test_sender = Callable()
	quit(0 if _failures.is_empty() and observed.size()==names.size() else 1)
