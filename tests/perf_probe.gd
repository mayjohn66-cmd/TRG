## 성능 측정 도구 (CI에서 돌리지 않는다): 컴퓨터 4명이 연출을 켠 판을 두며 70ms를 넘긴 프레임과 그 직전 사건을 적는다.
## 실행: xvfb-run -a godot --rendering-driver opengl3 --audio-driver Dummy --path . -s res://tests/perf_probe.gd
## (xvfb는 소프트웨어 렌더라 절대값은 실제 기기보다 크다. 고치기 전후를 같은 환경에서 비교할 때 쓴다.)
extends SceneTree
var board: MainBoard
var events: Array[String] = []
var spikes: Array[Dictionary] = []
var last: int = 0
var start: int = 0
var frames: int = 0
var sum_ms: float = 0.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1366, 768)
	board = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	root.add_child(board)
	await process_frame
	board._bot.bot_players.assign([1, 2, 3, 4] as Array[int])
	board._bot.set_enabled(true)
	board.ai_mode = true
	Engine.time_scale = 2.0
	board.manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void:
		var extra: String = ""
		if data.has("card_id"): extra = ":" + str(data["card_id"])
		elif data.has("result"): extra = ":" + str((data["result"] as Dictionary).get("tool_id", ""))
		elif data.has("augment_id"): extra = ":" + str(data["augment_id"])
		events.append(str(kind) + extra)
		if events.size() > 4: events.pop_front())
	start = Time.get_ticks_msec()
	last = Time.get_ticks_usec()

func _process(_d: float) -> bool:
	if board == null:
		return false
	var now: int = Time.get_ticks_usec()
	var dt: float = (now - last) / 1000.0
	last = now
	frames += 1
	sum_ms += dt
	if frames > 30 and dt > 70.0:
		spikes.append({"ms": dt, "round": board.state.round_number if board.state else 0, "ev": " > ".join(PackedStringArray(events)), "pres": str(board._presenter._mode) if board._presenter and board._presenter.active else "-"})
	var over: bool = board.manager != null and board.manager.is_game_over
	if over or Time.get_ticks_msec() - start > 240000:
		print("PROF frames=", frames, " avg=", snappedf(sum_ms / frames, 0.1), "ms rounds=", board.state.round_number, " over=", over)
		spikes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.ms > b.ms)
		for s: Dictionary in spikes.slice(0, 40):
			print("SPIKE ", snappedf(s.ms, 1), "ms R", s.round, " pres=", s.pres, " | ", s.ev)
		print("SPIKE_COUNT ", spikes.size())
		return true
	return false
