extends SceneTree
# File: tests/ui_round_sequence_test.gd
# Role: 증강 라운드 -> 라운드 시작 순서 검증 (실제 판, 봇 3명). 아래 순서가 한 번도 뒤집히지 않아야 한다:
#       [증강 확인 창이 뜨며 고른 증강이 기록에 적힘] -> [확인 창 닫힘] -> [고른 증강의 즉시 효과 연출(초증강 등)] -> [N라운드 시작! 배너] -> [1번 플레이어가 행동 가능]
#       초증강 2종(지뢰밭: 함정 설치 연출 여러 개, 도적단)으로 본다. 굴리기 화면(버튼·야추 스테이지)은 그 연출이 다 끝난 뒤에만 뜨고, 카드를 끄는 동안 꺼진다.

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
	await _tempo_after_capture()
	if failures.is_empty():
		print("UI_ROUND_SEQUENCE_OK: review logs -> review closed -> augment effects -> round banner -> first turn")
	quit(0 if failures.is_empty() else 1)


## 굴리기 화면(버튼·패드·중앙 스테이지) 중 하나라도 보이는가.
func _roll_view_visible() -> bool:
	if board._roll_button.visible or board._roll_pad.visible:
		return true
	for stage: Control in [board._stage_yacht, board._stage_blackjack, board._stage_pinball]:
		if stage != null and stage.visible:
			return true
	return false


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
	var early_roll_view: Array[String] = []
	if super_id == &"SUPER_05":
		board.state.tools[1] = ToolYacht.new()  # 중앙 스테이지 도구(야추)도 같은 규칙인지 본다
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
		# 굴리기 화면은 앞선 연출(배너·연출 큐·확인 창)이 하나라도 남아 있으면 보이지 않는다
		var blocked: bool = board._presentation_active() or (board._announcer != null and board._announcer.holding()) or board._intro_blocks() or (board._review_overlay != null and is_instance_valid(board._review_overlay)) or board._turn_banner_pending()
		if blocked and _roll_view_visible() and early_roll_view.size() < 3:
			early_roll_view.append("frame %d state %d label %s" % [clock[0], manager.current_state, board.presentation_label])
		if not picked and manager.current_state == TurnManager.State.PHASE_ROUND_START and manager.draft_pending_players().has(1) and not board._intro_blocks():
			(manager._draft_offers[1] as Array)[0] = super_id
			board._act(&"pick_augment", {"player_id": 1, "index": 0})
			picked = true
		if times.has("banner") and manager.current_player_id() == 1 and (manager.current_state == TurnManager.State.PHASE_TURN_BEGIN or manager.current_state == TurnManager.State.PHASE_ROLL_WAIT) and not board._ui_busy():
			times["first_turn"] = now.call()
			break
	var label: String = String(super_id)
	expect(early_roll_view.is_empty(), "%s: 앞선 연출이 끝나기 전에는 굴리기 화면이 뜨지 않는다 %s" % [label, str(early_roll_view)])
	if times.has("first_turn"):
		await process_frame
		expect(_roll_view_visible(), "%s: 연출이 다 끝나면 굴리기 화면이 뜬다" % label)
		board._drag_active = true  # 카드를 집어 끄는 중
		await process_frame
		await process_frame
		expect(not _roll_view_visible(), "%s: 카드를 끄는 동안 굴리기 화면은 꺼진다" % label)
		board._drag_active = false
		await process_frame
		await process_frame
		expect(_roll_view_visible(), "%s: 카드 끌기를 그만두면 다시 뜬다" % label)
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


## 라운드 끝 처치(마지막 차례의 잡기)와 같은 순간에 템포 업이 오면: [처치 컷인 -> 장외 사출] 이 다 끝난 뒤에 템포 업 경고가 뜬다.
func _tempo_after_capture() -> void:
	if board != null:
		board.queue_free()
		await process_frame
	board = load("res://scenes/main_board.tscn").instantiate()
	board.instant_roll_for_test = true
	root.add_child(board)
	await process_frame
	await process_frame
	board._bot.set_enabled(false)
	board.manager._draft_offers.clear()
	board.manager._draft_picks.clear()
	board.manager.review_enabled = false
	board.manager._begin_turn()
	board._close_draft_overlay()
	board._close_opening()
	board._intro_pending = false
	board._announcer.cancel()
	board._announced_round = board.state.round_number
	board._reset_presentation()
	board._fx_until_msec = 0
	var state: GameState = board.state
	var mine: PlayerPawn = state.get_pawn(11)
	var enemy: PlayerPawn = state.get_pawn(21)
	mine.current_tile_idx = 1
	mine.has_left_start = true
	mine.step_history.assign([1])
	enemy.current_tile_idx = 2
	enemy.has_left_start = true
	enemy.step_history.assign([2])
	board._refresh_all()
	board._announcer.cancel()
	var clock: Array[int] = [0]
	var tempo_at: Array[int] = [-1]
	board._announcer.entry_started.connect(func(_serial: int) -> void:
		if str(board._announcer._current.get("tag", "")) == "템포 업" and tempo_at[0] == -1:
			tempo_at[0] = clock[0])
	var ctx := RuleContext.new()
	ctx.state = state
	ctx.actor_id = 1
	ctx.raw_roll = 1
	ctx.dice_value = 1
	board.instant_roll_for_test = false
	MoveExecutor.execute(state, mine, ctx)
	board._on_event(&"tempo_up", {"level": 1, "round": 10, "lines": ["모든 이동 +1칸"]})  # 같은 순간 라운드가 넘어가며 템포 업
	var cutin_at: int = -1
	var eject_done_at: int = -1
	var view: Node2D = board._pawn_views[21]
	var deadline: int = Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline and tempo_at[0] == -1:
		await process_frame
		clock[0] += 1
		if cutin_at == -1 and board._capture_cutin.active:
			cutin_at = clock[0]
		if cutin_at != -1 and eject_done_at == -1 and not board._capture_cutin.busy() and not board._fx_running(view) and not view.visible:
			eject_done_at = clock[0]
	expect(cutin_at != -1 and tempo_at[0] != -1, "템포 업: 처치 컷인과 템포 업 경고가 모두 나온다 (컷인 %d, 경고 %d)" % [cutin_at, tempo_at[0]])
	expect(eject_done_at != -1 and eject_done_at <= tempo_at[0], "템포 업 경고는 처치 컷인·장외 사출이 끝난 뒤 (컷인 %d, 사출 끝 %d, 경고 %d)" % [cutin_at, eject_done_at, tempo_at[0]])
	board.instant_roll_for_test = true
