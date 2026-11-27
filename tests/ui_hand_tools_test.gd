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
	rigid_counter()
	await dice_hop_in_place()
	await fixture()
	await warmup()
	await pirate_buttons()
	await holdem_exchange()
	await yacht_case()
	await gated_take_out_labels()
	await blackjack_table()
	take_out_labels()
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
		check(not presenter._title.visible, "%s 도구 이름표는 띄우지 않는다" % id)
		var target: Vector2 = presenter._place_target
		if RollPresenter.DROP_TOOLS.has(id):
			# 꺼내기 도구 (1.3.1): 미리 놓여 있지 않다가 바로 위에서 제 크기로 쿵 떨어진다
			check(presenter.placing_time == 0.0 and presenter._dropping and is_equal_approx(presenter.scale.x, 1.0), "%s 위에서 떨어진다" % id)
			check(presenter.position.y < target.y - 300.0 and is_equal_approx(presenter.position.x, target.x), "%s 바로 위에서 출발한다" % id)
		else:
			check(presenter.placing_time == 0.0 and presenter.scale.x < 0.6, "%s 작게 들린 채 출발한다" % id)
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


## 1.3.1: 보드에 놓여 있던 주사위(소품)가 그 자리에서 튀어 오르며 구르고, 그 바로 앞에 내려앉는다 (멀리서 날아오지 않는다).
func dice_hop_in_place() -> void:
	var host := Control.new()
	host.size = Vector2(1366, 768)
	root.add_child(host)
	var presenter := RollPresenter.new()
	host.add_child(presenter)
	await frames()
	presenter.toss_from = Vector2(683, 720)
	presenter.hop_from = Vector2(683, 250)
	presenter.hop_scale = 0.7
	var prop := DiceRoll3D.new()
	host.add_child(prop)
	prop.begin(6, 0.5)
	prop.apply_time(3.0)
	presenter.hop_pose = prop.die_pose()
	var result: Dictionary = {"tool_id": &"D6", "steps": 4, "details": {"face": 4}}
	presenter.play(&"D6", result, 0.5)
	var view: Control = presenter._dice_3d
	var body: Vector2 = view.get_global_transform() * (view.size / 2.0)
	check(presenter._hopping and body.distance_to(Vector2(683, 250)) < 2.0, "주사위는 소품 자리에서 출발한다 (%s)" % str(body))
	check(is_equal_approx(presenter.scale.x, 0.7) and presenter.modulate.a == 1.0, "소품 크기 그대로, 흐려졌다 나타나지 않는다")
	check(presenter._dice_3d.die_pose().basis.get_rotation_quaternion().is_equal_approx(prop.die_pose().basis.get_rotation_quaternion()), "첫 자세가 소품 주사위와 같다")
	var top: float = 0.0
	while presenter.active:
		top = maxf(top, presenter.toss_height)
		await process_frame
	body = view.get_global_transform() * (view.size / 2.0)
	check(body.distance_to(Vector2(683, 250) + RollPresenter.HOP_DRIFT) < 3.0, "튄 자리 바로 앞에 내려앉는다 (%s)" % str(body))
	check(top > 20.0 and top < RollPresenter.TOSS_HEIGHT * 0.7, "판 위에서 통통 튀는 높이 (%.1f)" % top)
	presenter.cancel()
	host.queue_free()
	await frames()


## 1.3.1: 나무 계산대(스크래치 복권)는 말리지 않는다. 들고 오는 동안에도 판 모양 그대로 아래에서 올라온다. 천 매트는 가로로 펼친다.
func rigid_counter() -> void:
	var mat := CardMat.new()
	mat.mat_center = Vector2(683, 335)
	mat.setup(&"DICE_SCRATCH")
	mat.reveal = 0.5
	var half: Rect2 = mat.mat_rect()
	check(mat.is_rigid() and is_equal_approx(half.size.x, CardMat.MAT_SIZE.x) and half.get_center().y > 335.0 + 100.0, "나무 판은 반쯤 왔을 때도 제 모양으로 아래에서 올라온다 (%s)" % str(half))
	mat.reveal = 1.0
	check(mat.mat_rect().get_center().distance_to(Vector2(683, 335)) < 0.5, "다 오면 판 가운데에 놓인다")
	mat.setup(&"DICE_TAROT")
	mat.reveal = 0.5
	check(not mat.is_rigid() and mat.mat_rect().size.x < CardMat.MAT_SIZE.x * 0.6, "천 매트는 가로로 펼친다")
	mat.free()


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
	await create_timer(1.2 + RollPresenter.DROP_TIME + 0.3).timeout  # 1.3.1: 놓인 다음 레버 쪽으로 다가가고 동전이 들어간다
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
	# 1.3.1: 꺼내기 전에는 판 위에 통이 없고 가운데 [꺼내기] 버튼만 있다
	check(board._pirate_idle == null or not board._pirate_idle.visible, "꺼내기 전에는 해적통이 없다")
	check(board._roll_button.is_visible_in_tree() and board._roll_button.text == "꺼내기", "[꺼내기] 버튼이 보인다 (%s)" % board._roll_button.text)
	await click(board._roll_button)
	await frames(4)
	check(rolls.is_empty(), "꺼내기만 하고 아직 칼을 꽂지 않는다")
	check(board._pirate_idle != null and board._pirate_idle.visible, "꺼내면 해적통이 판 위에 선다")
	check(not board._roll_button.visible, "꺼낸 뒤에는 버튼 대신 통의 구멍을 누른다")
	if board._pirate_idle == null:
		return
	await create_timer(0.6).timeout  # 떨어져 놓이는 연출
	var before: float = board._pirate_idle.user_yaw
	board._pirate_idle.spin(0.8)
	check(not is_equal_approx(before, board._pirate_idle.user_yaw), "끌면 통이 돈다")
	await frames(3)
	var target: int = -1
	for hole: int in ToolPirateRoulette.HOLES:
		var at: Vector2 = board._pirate_idle.hole_screen_point(hole)
		if at.is_finite() and board._pirate_idle.hole_at(at) == hole:
			target = hole
			break
	check(target >= 0, "앞쪽에 누를 수 있는 구멍이 있다")
	if target >= 0:
		await tap_pirate(board._pirate_idle.hole_screen_point(target))
		await create_timer(2.5).timeout
		await wait_idle()
		check(rolls.size() == 1, "구멍을 누르면 칼을 꽂는다")
		if rolls.size() == 1:
			var stuck: Array = rolls[0].get("details", {}).get("holes", [])
			check(not stuck.is_empty() and int(stuck[-1]) == target, "누른 구멍에 칼이 꽂힌다 (%s / %d)" % [str(stuck), target])
	await next_turn()


func tap_pirate(at: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	board._on_pirate_idle_input(down)
	await frames()
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = at
	board._on_pirate_idle_input(up)
	await frames()


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
	var deal_until: int = Time.get_ticks_msec() + 6000  # 섞기·나눠 주기는 실제 시간으로 흐른다 (1.3.1 판 위 셔플)
	while panel != null and panel.busy and Time.get_ticks_msec() < deal_until:
		await process_frame
	check(panel != null and rolls.size() == 1, "5장을 받으면 교환 창이 뜬다")
	if panel == null:
		return
	check(not board._roll_button.visible and not board._stop_button.visible, "교환 중에는 굴리기·멈추기 버튼 대신 창의 버튼")
	check(board._card_view_on and board._alkkagi_saved_view != -1, "카드 도구는 알까기 시점(펼친 판)으로 바꿔 판 위에 깐다")
	check(panel.on_board and is_zero_approx(panel._dim.color.a), "판 위에서는 어두운 막을 칠하지 않는다")
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
	check(not board._card_view_on and board._alkkagi_saved_view == -1 and is_zero_approx(board._alkkagi_camera), "확정하면 원래 시점으로 돌아온 뒤 말이 움직인다")


## 1.3.1 야추 주사위 케이스: 카드 시점으로 판 가운데에 놓이고, 고정한 주사위는 위 고정 칸으로, 확정하면 원래 시점으로.
func yacht_case() -> void:
	await next_turn()
	rolls.clear()
	await give(&"DICE_YACHT")
	var stage: YachtStage = board._stage_yacht
	for _w: int in 120:
		board._refresh_all()
		if stage.visible:
			break
		await process_frame
	check(stage.visible and board._card_view_on and board._card_view_tool == &"DICE_YACHT", "야추 케이스가 뜨면 카드 시점으로 들어간다")
	var case_center: Vector2 = stage.position + YachtStage.STAGE_SIZE / 2.0
	check(absf(case_center.x - board._card_table_center().x) < 12.0 and absf(case_center.y - board._card_table_center().y) < 80.0, "케이스는 판 가운데 (%s / %s)" % [case_center, board._card_table_center()])
	stage.start_pressed.emit()
	var until: int = Time.get_ticks_msec() + 4000
	while (stage.active or not stage.started) and Time.get_ticks_msec() < until:
		await process_frame
	check(stage.started and not stage.active, "주사위 5개가 컵에서 굴러 나온다")
	var felt_y: float = stage.dice_views[1].position.y
	stage._on_die_toggled(1)
	check(stage.kept[1] and stage.dice_views[1].position.y < felt_y - 60.0, "누른 주사위는 위 고정 칸으로 올라간다 (누르는 자리도 따라간다)")
	stage.confirm_pressed.emit()
	until = Time.get_ticks_msec() + 30000  # 헤드리스는 프레임이 느려 잠깐 보여 주기(0.6초)·시점 복귀가 오래 걸린다
	while (board._card_view_on or not is_zero_approx(board._alkkagi_camera)) and Time.get_ticks_msec() < until:
		await process_frame
	check(not board._card_view_on and is_zero_approx(board._alkkagi_camera), "확정하면 원래 시점으로 돌아온다")


## 1.3.1 블랙잭 테이블: 스테이지가 뜨면 카드 시점(블랙잭 매트), 끝나면 원래 시점으로.
func blackjack_table() -> void:
	await next_turn()
	await give(&"DICE_BLACKJACK")
	var stage: BlackjackStage = board._stage_blackjack
	for _w: int in 120:
		board._refresh_all()
		if stage.visible:
			break
		await process_frame
	check(stage.visible and board._card_view_on and board._card_view_tool == &"DICE_BLACKJACK", "블랙잭 테이블이 뜨면 카드 시점으로 들어간다")
	stage.start_pressed.emit()
	var until: int = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < until:
		var tool: BaseJudgmentTool = board.state.tools[board.manager.current_player_id()]
		if board.manager.current_state == TurnManager.State.PHASE_ROLL_WAIT and tool is ToolBlackjack and tool.has_pending_state() and not stage.active and not board._fx_busy:
			stage.stand_pressed.emit()
		if not board._card_view_on and is_zero_approx(board._alkkagi_camera):
			break
		await process_frame
	check(not board._card_view_on and is_zero_approx(board._alkkagi_camera), "블랙잭이 끝나면 원래 시점으로 돌아온다")


## 1.3.1: 꺼내 놓고 쓰는 도구(다트·해적·룰렛·리볼버)는 꺼내기 전에 가운데 [꺼내기] 버튼만 보인다.
func gated_take_out_labels() -> void:
	for id: StringName in MainBoard.GATED_TAKE_OUT:
		await next_turn()
		await give(id)
		board._refresh_all()
		await frames(3)
		check(board._roll_button.visible and board._roll_button.text == "꺼내기", "%s: 꺼내기 전 버튼은 [꺼내기] (%s)" % [id, board._roll_button.text.replace("\n", " ")])
		check(not board._roll_pad.visible, "%s: 꺼내기 전에는 원판·리볼버가 없다" % id)


## 1.3.1: 던지지 않는 도구는 굴리기 버튼이 [꺼내기], 던지는 도구는 그대로.
func take_out_labels() -> void:
	for id: StringName in MainBoard.TAKE_OUT_TOOLS:
		check(board._roll_button_label(ToolRegistry.create(id)) == "꺼내기", "%s 버튼은 [꺼내기]" % id)
	for id: StringName in [&"D6", &"CHINCHIRO", &"YUT"]:
		check(board._roll_button_label(ToolRegistry.create(id)) != "꺼내기", "%s는 던지는 도구라 그대로" % id)
	check(MainBoard.TAKE_OUT_TOOLS.has(&"DICE_DARTS"), "다트도 [꺼내기] (1.3.1: 꺼낸 과녁을 눌러 던진다)")


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
