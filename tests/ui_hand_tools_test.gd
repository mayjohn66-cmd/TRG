## 판정 도구 직접 연출 3차 (1.3.1): 손으로 꺼내는 첫 장면(마작 패·과자통·아이스박스·오미쿠지)과 캡슐 레버, 홀덤 교환 창, 해적통 대기 화면.
## 결과는 엔진이 정한 그대로이고, 손대지 않으면 저절로 진행한다. 남이 굴린 것은 손 장면 없이 바로 연출한다.
extends SceneTree

var board: MainBoard
var failures: Array[String] = []
var rolls: Array[Dictionary] = []


func _initialize() -> void:
	run.call_deferred()


func frames(count: int = 2) -> void:
	for index: int in count:
		await process_frame


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func fixture() -> void:
	board = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	board.instant_roll_for_test = true
	root.add_child(board)
	await frames()
	board._bot.set_enabled(false)
	board.manager.set_process(false)
	board.pacing_enabled = false
	board._close_opening()
	board._on_draft_auto_pressed()
	await frames()
	board._reset_presentation()
	board._close_draft_overlay()
	board._close_augment_review()
	board._announcer.cancel()
	board.manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void:
		if kind == &"roll_resolved":
			rolls.append(data["result"]))
	await frames()


## 지금 차례인 사람에게 도구를 쥐여 주고 차례 시작 상태로 맞춘다.
func give(tool_id: StringName) -> void:
	board._reset_presentation()
	board._announcer.cancel()
	board._close_draft_overlay()
	board._close_augment_review()
	board._fx_busy = false  # 앞 시험의 굴림 연출(즉시 모드 아님)이 남긴 상태
	var roller: int = board.manager.current_player_id()
	board.local_player_id = roller
	board.state.tools[roller] = ToolRegistry.create(tool_id)
	board.instant_roll_for_test = false
	board._refresh_all()
	for _wait: int in 300:
		if not board._ui_busy():
			break
		await process_frame


## 다음 사람 차례 시작까지 엔진을 넘긴다 (연출은 즉시 모드로).
func next_turn() -> void:
	board.instant_roll_for_test = true
	var start_player: int = board.manager.current_player_id()
	for _step: int in 120:
		if board.manager.current_state == TurnManager.State.PHASE_TURN_BEGIN and board.manager.current_player_id() != start_player:
			break
		if board.manager.current_state == TurnManager.State.PHASE_ROUND_START:
			board._on_draft_auto_pressed()
		board._reset_presentation()
		board._announcer.cancel()
		board.manager.force_timeout()
		await frames()
		if board.manager.current_state == TurnManager.State.PHASE_MOVING_STEP:
			await create_timer(0.1).timeout  # 말이 한 칸씩 걷는 동안은 시간으로 기다린다
	print("NEXT_TURN state=", board.manager.current_state, " player=", board.manager.current_player_id())


func click(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		root.push_input(event)
		await frames()


func wait_idle() -> void:
	for _w: int in 600:
		if not board._ui_busy() and not board._fx_busy:
			break
		await process_frame


func run() -> void:
	create_timer(180).timeout.connect(func() -> void: printerr("HAND_TOOLS_FAIL timeout"); quit(1))
	root.size = Vector2i(1366, 768)
	await presenter_gates()
	await placed_on_board()
	await fixture()
	await warmup()
	await pirate_buttons()
	await holdem_exchange()
	if failures.is_empty():
		print("HAND_TOOLS_OK")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


## 1.3.1: 판 위에 놓는 도구는 굴린 사람 쪽에서 들고 와 보드 한가운데에 내려놓는다 (작게 들려 출발 → 제자리·제 크기로 착지).
func placed_on_board() -> void:
	var host := Control.new()
	host.size = Vector2(1366, 768)
	root.add_child(host)
	var presenter := RollPresenter.new()
	host.add_child(presenter)
	presenter.toss_from = Vector2(683, 700)
	await frames()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for id: StringName in [&"DICE_DARTS", &"SLOT_777"]:
		var result: Dictionary = ToolRegistry.create(id).roll(rng).to_dict()
		presenter.play(id, result, 0.5)
		check(presenter.placing_time == 0.0 and presenter.scale.x < 0.6, "%s 작게 들린 채 출발한다" % id)
		check(not presenter._title.visible, "%s 도구 이름표는 띄우지 않는다" % id)
		var target: Vector2 = presenter._place_target
		check(presenter.position.y > target.y, "%s 굴린 사람 쪽(아래)에서 출발한다" % id)
		for _wait: int in 120:
			if presenter.placing_time < 0.0:
				break
			await process_frame
		check(presenter.placing_time < 0.0 and presenter.scale == Vector2.ONE and presenter.position == target, "%s 제자리·제 크기로 내려앉는다" % id)
		check(presenter._ground_shadow != null and presenter._ground_shadow.visible, "%s 바닥 그림자가 깔린다" % id)
		presenter.cancel()
	host.queue_free()
	await frames()


func presenter_gates() -> void:
	var host := Control.new()
	host.size = Vector2(1366, 768)
	root.add_child(host)
	var presenter := RollPresenter.new()
	host.add_child(presenter)
	await frames()
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var done: Array[bool] = [false]
	for id: StringName in [&"DICE_MAHJONG", &"DICE_COOKIE", &"DICE_ICECREAM", &"DICE_OMIKUJI"]:
		var result: Dictionary = ToolRegistry.create(id).roll(rng).to_dict()
		presenter.interactive = true
		done[0] = false
		var play := func() -> void:
			await presenter.play(id, result, 0.5)
			done[0] = true
		play.call()
		await create_timer(0.5).timeout
		var gate: ToolHandGate = presenter.hand_gate()
		check(gate != null and presenter.awaiting_input(), "%s: 내가 굴리면 손으로 꺼내는 장면부터" % id)
		if gate == null:
			continue
		check(not done[0], "%s: 꺼내기 전에는 연출이 끝나지 않는다" % id)
		match id:
			&"DICE_MAHJONG":
				check(gate.item_count() == ToolHandGate.ROW_TILES, "마작: 뒷면 패 1열")
				gate.pick(4)
				gate.pick(4)
				gate.pick(9)
				check(gate.picks() == [4, 9] and gate.waiting(), "같은 패는 두 번 못 꺼낸다, 3개 전에는 계속 기다린다")
				gate.pick(0)
				check(not gate.waiting(), "3개를 꺼내면 끝")
			&"DICE_OMIKUJI":
				gate.shake()
				gate.shake()
				check(gate.shake_count() == 2 and gate.waiting(), "흔들기는 몇 번이든, 뽑기 전에는 기다린다")
				gate.draw()
				check(not gate.waiting(), "뽑기를 누르면 끝")
			_:
				gate.pick(1)
				check(not gate.waiting(), "%s: 하나 고르면 끝" % id)
		var waited: float = 0.0
		while not done[0] and waited < 7.0:
			await create_timer(0.1).timeout
			waited += 0.1
		check(done[0], "%s: 꺼낸 뒤 원래 연출이 끝까지 간다 (%.1f초)" % [id, waited])
	# 남이 굴린 것은 손 장면 없이
	presenter.interactive = false
	var other: Dictionary = ToolRegistry.create(&"DICE_COOKIE").roll(rng).to_dict()
	presenter.play(&"DICE_COOKIE", other, 0.5)
	await create_timer(0.3).timeout
	check(presenter.hand_gate() == null and not presenter.awaiting_input(), "남이 굴린 쿠키는 바로 연출")
	presenter.cancel()
	# 손대지 않으면 저절로
	presenter.interactive = true
	presenter.play(&"DICE_MAHJONG", ToolRegistry.create(&"DICE_MAHJONG").roll(rng).to_dict(), 0.5)
	await create_timer(0.3).timeout
	var idle_gate: ToolHandGate = presenter.hand_gate()
	if idle_gate != null:
		idle_gate.auto_finish()
		check(idle_gate.picks().size() == ToolHandGate.MAHJONG_PICKS and not idle_gate.waiting(), "오래 두면 남은 패를 저절로 꺼낸다")
	presenter.cancel()
	# 캡슐: 동전은 저절로, 레버는 끌어서 돌린다
	presenter.interactive = true
	done[0] = false
	var capsule: Dictionary = ToolRegistry.create(&"DICE_CAPSULE").roll(rng).to_dict()
	var play_capsule := func() -> void:
		await presenter.play(&"DICE_CAPSULE", capsule, 0.5)
		done[0] = true
	play_capsule.call()
	await create_timer(1.2).timeout
	check(presenter.capsule_gate_open() and presenter.awaiting_input(), "동전이 들어가면 레버 앞에서 기다린다")
	presenter.turn_capsule(0.5)
	await create_timer(0.3).timeout
	check(presenter.capsule_gate_open(), "반 바퀴로는 아직")
	presenter.manual_tap()
	presenter.manual_tap()
	await create_timer(0.2).timeout
	check(not presenter.capsule_gate_open(), "한 바퀴 다 돌리면 캡슐이 떨어진다 (스페이스 = 1/4 바퀴)")
	var waited_capsule: float = 0.0
	while not done[0] and waited_capsule < 6.0:
		await create_timer(0.1).timeout
		waited_capsule += 0.1
	check(done[0], "캡슐 연출이 끝까지 간다")
	host.queue_free()
	await frames()


func pirate_buttons() -> void:
	rolls.clear()
	await give(&"DICE_PIRATE")
	await wait_idle()
	check(board._pirate_idle != null and board._pirate_idle.visible, "해적통이 보드 위에 서 있다")
	check(board._roll_button.is_visible_in_tree() and not board._roll_button.disabled, "[칼 꽂기] 버튼이 보인다")
	if board._pirate_idle != null:
		var before: float = board._pirate_idle.user_yaw
		board._pirate_idle.spin(0.8)
		check(not is_equal_approx(before, board._pirate_idle.user_yaw), "끌면 통이 돈다")
	await click(board._roll_button)
	await create_timer(2.5).timeout
	await wait_idle()
	check(rolls.size() == 1, "첫 칼")
	if rolls.size() == 1 and bool(rolls[0].get("can_continue", false)):
		check(board._roll_button.is_visible_in_tree(), "칼을 꽂은 뒤에도 [칼 꽂기] 버튼이 보인다 (제보: 스페이스로만 반응)")
		check(board._pirate_idle != null and board._pirate_idle.visible, "꽂힌 칼을 단 채 통이 다시 선다")
		await click(board._roll_button)
		await create_timer(2.5).timeout
		check(rolls.size() == 2, "두 번째 칼도 버튼으로 꽂힌다 (지금 %d번)" % rolls.size())
	await next_turn()


func holdem_exchange() -> void:
	rolls.clear()
	await give(&"HOLDEM")
	await wait_idle()
	await click(board._roll_button)
	for _w: int in 600:
		if board.holdem_exchange_panel() != null:
			break
		await process_frame
	var panel: HoldemExchangePanel = board.holdem_exchange_panel()
	for _wait: int in 180:
		if panel==null or not panel.busy: break
		await process_frame
	check(panel != null and rolls.size() == 1, "5장을 받으면 교환 창이 뜬다")
	if panel == null:
		return
	check(not board._roll_button.visible and not board._stop_button.visible, "교환 중에는 굴리기·멈추기 버튼 대신 창의 버튼")
	board._roll_by_key()
	await frames()
	check(rolls.size() == 1, "스페이스로는 교환하지 않는다")
	check((panel.find_child("ExchangeButton", true, false) as Button).disabled, "고른 카드가 없으면 [교환하기]는 꺼져 있다")
	panel.toggle(0)
	panel.toggle(2)
	panel.toggle(2)
	check(panel.keep_mask() == [false, true, true, true, true], "누른 카드만 교환 표시 (다시 누르면 취소)")
	await click(panel.find_child("ExchangeButton", true, false))
	await create_timer(2.5).timeout
	check(rolls.size() == 2 and not bool(rolls[1].get("can_continue", true)), "교환하면 확정")
	if rolls.size() == 2:
		check(rolls[1]["details"]["exchanged"] == [0], "첫 카드만 바꿨다")
	check(board.holdem_exchange_panel() == null, "확정하면 창이 닫힌다")


func warmup() -> void:
	board.instant_roll_for_test = false
	board._start_tool_warmup()
	var warm: ToolWarmup = board.tool_warmup()
	check(warm != null, "판이 시작되면 도구 화면을 미리 그린다")
	if warm == null:
		return
	var waited: float = 0.0
	while warm.pending() > 0 and waited < 30.0:
		await create_timer(0.1).timeout
		waited += 0.1
	check(warm.pending() == 0 and warm.warmed_ids().size() == ToolWarmup.ORDER.size(), "4라운드 전에 다 그린다 (%.1f초, %s)" % [waited, warm.warmed_ids()])
	var presenter: RollPresenter = board._presenter
	check(presenter._slot_3d != null and presenter._pirate_view != null and presenter._capsule_view != null and presenter._yut_3d != null, "그린 화면은 실제 연출이 넘겨받는다")
	for view: Variant in [presenter._slot_3d, presenter._pirate_view]:
		if view != null:
			for viewport: Node in (view as Node).find_children("*", "SubViewport", true, false):
				check((viewport as SubViewport).render_target_update_mode == SubViewport.UPDATE_DISABLED or not (view as Control).is_visible_in_tree(), "넘겨받은 화면은 쓰기 전까지 그리지 않는다")
	# 판이 끝나면 지운다
	warm.clear()
	presenter.release_views()
	await frames()
	check(warm.warmed_ids().is_empty() and presenter._slot_3d == null and presenter._pirate_view == null, "판이 끝나면 미리 그린 화면을 지운다")
	board.instant_roll_for_test = true
