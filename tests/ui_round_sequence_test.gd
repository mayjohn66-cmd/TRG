extends SceneTree
# File: tests/ui_round_sequence_test.gd
# Role: 증강 라운드 -> 라운드 시작 순서 검증 (실제 판, 봇 3명). 아래 순서가 한 번도 뒤집히지 않아야 한다:
#       [증강 확인 창이 뜨며 고른 증강이 기록에 적힘] -> [확인 창 닫힘] -> [고른 증강의 즉시 효과 연출(초증강 등)] -> [N라운드 시작! 배너] -> [1번 플레이어가 행동 가능]
#       초증강 2종(지뢰밭: 함정 설치 연출 여러 개, 빵집 털이: 말 워프 연출)으로 본다.

var board: MainBoard = null
var failures: Array[String] = []
var _started: bool = false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		printerr("UI_ROUND_SEQ_FAIL: " + message)


func _run() -> void:
	for super_id: StringName in [&"SUPER_04", &"SUPER_05"]:
		await _scenario(super_id)
	if failures.is_empty():
		print("UI_ROUND_SEQUENCE_OK: review logs -> review closed -> augment effects -> round banner -> first turn")
	quit(0 if failures.is_empty() else 1)


func _scenario(super_id: StringName) -> void:
	if board != null:
		board.queue_free()
		await process_frame
	board = load("res://scenes/main_board.tscn").instantiate()
	root.add_child(board)
	var manager: TurnManager = board.manager
	var times: Dictionary = {}
	var effect_steps: Array[int] = []
	# 시각 대신 프레임 번호로 잰다: 확인 창을 닫고 배너를 띄우는 일은 같은 프레임 안에서 차례로 일어난다.
	var clock: Array[int] = [0]
	var now: Callable = func() -> int: return clock[0]
	board._announcer.entry_started.connect(func(_serial: int) -> void:
		if str(board._announcer._current.get("tag", "")) == "라운드" and not times.has("banner"):
			times["banner"] = now.call())
	var last_label: String = ""
	var picked: bool = false
	var review_seen: bool = false
	var deadline: int = Time.get_ticks_msec() + 40000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		clock[0] += 1
		if board.presentation_label != last_label:
			last_label = board.presentation_label
			if review_seen and not times.has("banner"):
				effect_steps.append(now.call())
		var review_open: bool = board._review_overlay != null and is_instance_valid(board._review_overlay)
		if review_open and not review_seen:
			review_seen = true
			times["review_open"] = now.call()
			times["log_lines_at_review"] = board._action_log.line_count()
			board._on_review_confirm()
		if review_seen and not review_open and not times.has("review_closed"):
			times["review_closed"] = now.call()
		if not picked and manager.current_state == TurnManager.State.PHASE_ROUND_START and manager.draft_pending_players().has(1) and not board._intro_blocks():
			(manager._draft_offers[1] as Array)[0] = super_id
			board._act(&"pick_augment", {"player_id": 1, "index": 0})
			picked = true
		if times.has("banner") and manager.current_player_id() == 1 and (manager.current_state == TurnManager.State.PHASE_TURN_BEGIN or manager.current_state == TurnManager.State.PHASE_ROLL_WAIT) and not board._ui_busy():
			times["first_turn"] = now.call()
			break
	var label: String = String(super_id)
	expect(picked and review_seen, "%s: 증강을 고르고 확인 창이 떴다" % label)
	expect(int(times.get("log_lines_at_review", 0)) >= 4, "%s: 확인 창이 뜰 때 네 사람이 고른 증강이 기록에 적혀 있다 (%d줄)" % [label, int(times.get("log_lines_at_review", 0))])
	expect(times.has("review_closed") and times.has("banner") and times.has("first_turn"), "%s: 확인 창 닫힘·라운드 배너·첫 차례가 모두 왔다 %s" % [label, str(times)])
	if times.has("review_closed") and times.has("banner") and times.has("first_turn"):
		# 확인 창 닫힘은 다음 프레임 첫머리에 알아챈다(닫기와 배너가 같은 프레임의 봇 행동 안에서 차례로 일어난다): 1프레임 차이는 같은 순간이다.
		expect(int(times["review_closed"]) <= int(times["banner"]) + 1, "%s: 라운드 배너는 확인 창이 닫힌 뒤 %s" % [label, str(times)])
		if super_id == &"SUPER_04":
			expect(not effect_steps.is_empty(), "%s: 확인 창 뒤 라운드 배너 전에 초증강 효과(지뢰 설치) 연출이 재생된다" % label)
		for at: int in effect_steps:
			expect(at <= int(times["banner"]), "%s: 효과 연출(%d프레임)이 라운드 배너(%d프레임)보다 먼저" % [label, at, int(times["banner"])])
		expect(int(times["banner"]) <= int(times["first_turn"]), "%s: 첫 차례는 라운드 배너 뒤" % label)
