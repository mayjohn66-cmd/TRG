## 판정 도구 터치로 고르기 (1.3.1): 실제 보드에서 [굴리기]를 누르면 뒷면 고르기 창이 뜨고, 고른 자리로 굴림이 나간다.
## 시간이 지나 엔진이 자동으로 굴리면 창이 닫히고, 고르기 없는 도구·컴퓨터 차례에는 창이 뜨지 않는다.
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


func run() -> void:
	create_timer(120).timeout.connect(func() -> void: printerr("TOOL_PICK_FAIL timeout"); quit(1))
	root.size = Vector2i(1366, 768)
	await fixture()
	check(board.manager.current_state == TurnManager.State.PHASE_TURN_BEGIN, "차례 시작 상태에서 시험한다 (지금 %s)" % board.manager.current_state)
	# 1) 타로: 창이 뜨고 5장 중 고른 자리가 뒤집힌다
	await give(&"DICE_TAROT")
	board._on_roll_pressed()
	await frames()
	var modal: ToolPickModal = board.tool_pick_modal()
	check(modal != null and modal.is_inside_tree(), "타로는 [굴리기]를 누르면 고르기 창이 뜬다")
	check(rolls.is_empty(), "고르기 전에는 굴리지 않는다")
	if modal != null:
		check(modal.z_index > board._roll_button.z_index,"선택창이 굴리기 버튼보다 위에 표시된다")
		check(modal.item_count() == 5, "타로 뒷면 5장")
		board._on_roll_pressed()  # 창이 떠 있는 동안 다시 눌러도 굴리지 않는다
		await frames()
		check(rolls.is_empty(), "창이 떠 있으면 [굴리기]를 다시 눌러도 그대로")
		var item: Control = modal.find_child("PickItem3", true, false)
		check(item != null, "뒷면 자리 노드")
		if item != null:
			var press := InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.pressed = true
			item.gui_input.emit(press)
		await create_timer(0.5).timeout
		await frames()
		check(board.tool_pick_modal() == null, "다 고르면 창이 닫힌다")
		check(rolls.size() == 1, "고르면 한 번 굴린다 (지금 %d번)" % rolls.size())
		if rolls.size() == 1:
			check((rolls[0]["details"] as Dictionary).get("picked", []) == [3], "고른 자리가 결과에 실린다")
			check(int(rolls[0]["details"].get("flipped", -1)) == 3, "타로는 고른 카드가 뒤집힌다")
	# 다음 차례로 넘겨 다시 시험한다
	await next_turn()
	# 2) 화투: 2장을 골라야 굴린다, 같은 자리를 다시 누르면 취소
	rolls.clear()
	await give(&"DICE_HWATU")
	board._on_roll_pressed()
	await frames()
	modal = board.tool_pick_modal()
	check(modal != null and modal.item_count() == 3, "화투는 뒷면 3장 (1.3.1) (state %s busy %s banner %s intro %s pres %s fx %s ann %s beat %s)" % [board.manager.current_state, board._ui_busy(), board._turn_banner_pending(), board._intro_blocks(), board._presentation_active(), board._fx_busy, board._announcer.holding(), Time.get_ticks_msec() < board._beat_until_msec])
	if modal != null:
		modal.pick(1)
		modal.pick(1)
		check(modal.picks().is_empty(), "같은 자리를 다시 누르면 고르기 취소")
		modal.pick(2)
		check(rolls.is_empty() and board.tool_pick_modal() != null, "1장만 고르면 아직 굴리지 않는다")
		# 3) 고르는 중에 시간이 지나 엔진이 자동으로 굴리면 창이 닫힌다
		board.manager.force_timeout()
		await frames()
		check(board.tool_pick_modal() == null, "시간 초과로 자동 굴림이 나가면 창이 닫힌다")
		check(rolls.size() == 1 and not (rolls[0]["details"] as Dictionary).has("picked"), "자동 굴림은 고르기 없이 평소대로")
	# 4) 고르기 없는 도구는 바로 굴린다
	await next_turn()
	rolls.clear()
	await give(&"D6")
	board._on_roll_pressed()
	await frames()
	check(board.tool_pick_modal() == null and rolls.size() == 1, "주사위는 창 없이 바로 굴린다")
	# 5) 터치 배치: 창이 화면 안에 들어간다
	await next_turn()
	MobileSupport.force_touch = true
	await give(&"DICE_TAROT")
	board._on_roll_pressed()
	await frames(4)
	modal = board.tool_pick_modal()
	check(modal != null and modal.item_count() == 5, "터치 배치 타로 뒷면 5장")
	if modal != null:
		var panel: Control = modal.find_child("PickPanel", true, false)
		var rect: Rect2 = panel.get_global_rect()
		check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(rect), "터치 배치에서도 창이 화면 안 (%s)" % rect)
	MobileSupport.force_touch = false
	if failures.is_empty():
		print("UI tool pick test passed")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)
