extends SceneTree
var checks := 0
var failures: Array[String] = []

func expect(ok: bool,message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var view := StockChartView.new()
	root.add_child(view)
	var cases: Array[Dictionary] = [
		{"event":&"","before":6,"price":9,"delta":3,"history":[6,4,7,5,6,9]},
		{"event":&"","before":8,"price":5,"delta":-3,"history":[6,8,7,9,8,5]},
		{"event":&"","before":7,"price":7,"delta":0,"history":[6,8,7,7]},
		{"event":&"limit_up","before":7,"price":12,"delta":5,"history":[6,4,8,7,12]},
		{"event":&"delisted","before":5,"price":0,"delta":-5,"history":[6,8,5,0]},
	]
	for details: Dictionary in cases:
		var original := details.duplicate(true)
		view.begin(details)
		expect(not view.settled and view.displayed_price()==int(details.before),"new trade starts from previous price")
		var stored := view.historical_points()
		expect(view.history==details.history.slice(-4),"only the latest four values are displayed, including legacy history")
		expect(view.announcement_text()=="오늘의 주식은.","today announcement starts with one dot")
		view.apply_time(StockChartView.LIVE_AT*0.5)
		expect(is_zero_approx(view.progress()) and view.historical_points()==stored,"stored history stays fully drawn and motionless during announcement")
		expect(view.displayed_price()==int(details.before),"announcement does not reveal new price early")
		view.apply_time(StockChartView.LIVE_AT)
		expect(view.announcement_text().is_empty() and is_zero_approx(view.progress()),"announcement disappears before the last segment moves")
		view.apply_time(StockChartView.STAMP_AT-0.01)
		expect(not view.settled,"result cannot settle before reveal")
		view.apply_time(StockChartView.STAMP_AT)
		expect(view.settled and view.displayed_price()==int(details.price),"reveal lands on actual engine price")
		var end := view.tip_position()
		view.apply_time(StockChartView.TOTAL_TIME)
		expect(view.tip_position().is_equal_approx(end),"final line does not keep moving")
		var previous := view._point(view.history.size()-2,float(details.before),view._plot())
		var rising := int(details.price)>int(details.before)
		for frame: int in range(1,61):
			view.apply_time(StockChartView.LIVE_AT+(StockChartView.DRAW_TIME-StockChartView.LIVE_AT)*frame/60.0)
			var point := view.tip_position()
			expect(point.x>=previous.x-0.0001,"chart never jitters backwards horizontally")
			expect(point.y<=previous.y+0.0001 if rising else point.y>=previous.y-0.0001,"chart follows one direction without vertical wobble")
			previous = point
		view.apply_time(StockChartView.TOTAL_TIME)
		expect(original==details and view.history==details.history.slice(-4),"animation never rewrites source history")
		if details.event==&"limit_up":
			expect(end.y<view._plot().position.y,"limit-up breaks through plot ceiling")
		else:
			expect(view._plot().grow(0.01).has_point(end),"normal/delisted terminal point remains within plot")
		view.apply_time(0.0)
		expect(not view.settled and view.displayed_price()==int(details.before),"clock can rewind without sticky result")
	expect(not view.is_processing() and view.mouse_filter==Control.MOUSE_FILTER_IGNORE,"view uses presenter clock without blocking board input")
	expect(StockChartView.caption(cases[3],20).contains("대폭등! (Bull Market)"),"bull market uses requested wording")
	expect(StockChartView.caption(cases[4],0).contains("대폭락! (Bear Market)"),"bear market uses requested wording")
	view.begin(cases[0])
	for phase: int in 4:
		view.apply_time(phase*StockChartView.DOT_INTERVAL+0.01)
		expect(view.announcement_text()==StockChartView.ANNOUNCEMENT_BODY+".".repeat(phase%3+1),"announcement repeats one, two, three dots")
		expect(is_zero_approx(view.progress()) and view.displayed_price()==int(cases[0].before),"dots cannot start or reveal the price move")
	var presenter := RollPresenter.new()
	root.add_child(presenter)
	for details: Dictionary in [cases[0],cases[3],cases[4]]:
		var steps := 20 if details.event==&"limit_up" else int(details.price)
		presenter.play(&"DICE_STOCK",{"steps":steps,"details":details,"ends_turn":details.event==&"delisted"})
		presenter.set_process(false)
		presenter._update(StockChartView.STAMP_AT-0.01)
		expect(presenter._die_label.text.is_empty(),"presenter hides caption while the tape is live")
		presenter._update(StockChartView.STAMP_AT)
		expect(presenter.last_display==StockChartView.caption(details,steps),"presenter reveals exact caption")
		presenter.cancel()
		expect(not presenter.active and not presenter.visible,"cancel immediately releases presentation")
	presenter.queue_free()
	view.queue_free()
	await process_frame
	for failure: String in failures: printerr("STOCK_CHART_FAIL ",failure)
	print("STOCK_CHART ",checks," assertions; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
