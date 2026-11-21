extends "res://tests/ui_fx_test.gd"
## 결과 화면(최종 결과) 프레임 측정: 보드 평소 상태와 결과 연출·결과 만화 페이지의 프레임 시간·드로우 콜·노드 수를 잰다 (소프트웨어 렌더라 절대값보다 비교용).
func settle(n: int=4) -> void:
	for i: int in n:await process_frame
func quiet() -> void:
	_board._announcer.cancel();_board._reset_presentation();_board._close_opening();_board._close_draft_overlay();_board._close_augment_review()
	_board._announced_round=_board.state.round_number
	_board._bot.set_enabled(false);_board.manager.set_process(false)

func measure(label: String, seconds: float) -> void:
	var frames: Array[float] = []
	var last: int = Time.get_ticks_usec()
	var end: int = last + int(seconds * 1000000.0)
	var draw_calls: int = 0
	var objects: int = 0
	while Time.get_ticks_usec() < end:
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames.append(float(now - last) / 1000.0)
		last = now
		draw_calls = maxi(draw_calls, int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
		objects = maxi(objects, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	frames.sort()
	var total: float = 0.0
	for ms: float in frames:total+=ms
	var p95: float = frames[int(frames.size() * 0.95)] if frames.size() > 0 else 0.0
	print("PERF %-28s frames=%3d avg=%6.1fms p95=%6.1fms max=%6.1fms drawcalls<=%d nodes=%d" % [label, frames.size(), total / maxf(frames.size(), 1), p95, frames[-1] if frames.size() > 0 else 0.0, draw_calls, objects])

func _run() -> void:
	MatchTelemetry.test_sender=func(_url: String,_body: PackedByteArray,_type: String) -> void:pass
	_board._on_draft_auto_pressed();await settle(10);quiet();await settle()
	_board.manager.change_state(TurnManager.State.PHASE_TURN_BEGIN);quiet()
	_board.instant_roll_for_test=false;_board.pacing_enabled=true
	_board._refresh_all();await settle(20)
	await measure("board idle", 2.0)
	# 게임 종료 상태로 만든다
	var ids:Array=_board.state.player_ids
	for index:int in ids.size():
		if not _board.state.rankings.has(ids[index]):
			_board.state.rankings.append(ids[index]);_board.state.rank_reasons[ids[index]]=&"ALL_HOME" if index!=1 else &"LAW_01"
	_board.state.winner=int(ids[0])
	_board.manager.is_game_over=true
	_board._refresh_all();await settle(4)
	var before_nodes:int=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var t0:int=Time.get_ticks_usec()
	_board._show_result_overlay()
	await process_frame
	print("PERF show_result_overlay build+first frame: %.1fms nodes %d -> %d" % [float(Time.get_ticks_usec()-t0)/1000.0,before_nodes,int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	await measure("result comic intro 0-3s", 3.0)
	await measure("result 3-6s", 3.0)
	await measure("result 6-9s", 3.0)
	var report:=_board._result_overlay.find_child("ResultComicReport",true,false) if _board._result_overlay!=null else null
	print("PERF report visible=",report!=null and report.visible," comic nodes=",_board._result_overlay.find_children("*","",true,false).size() if _board._result_overlay!=null else -1)
	_board._reset_presentation();MatchTelemetry.test_sender=Callable()
	var board:=_board;_board=null;board.queue_free();await settle(8)
	print("PERF_DONE")
	quit(0)
