## 2026-11 주말 제보 핫픽스 2 (화면): 피드백 창 최상단 층, 차례가 넘어가면 BANG!·타일 고르기 정리, 슬림 선택 바, 굴리기 아래 필살기 안내.
extends "res://tests/ui_fx_test.gd"
var checks := 0


func _expect(ok: bool, message: String) -> void:
	checks += 1
	super._expect(ok, message)


func settle(n: int = 4) -> void:
	for i: int in n:
		await process_frame


func quiet() -> void:
	_board._announcer.cancel()
	_board._reset_presentation()
	_board._close_opening()
	_board._close_draft_overlay()
	_board._close_augment_review()
	_board._announced_round = _board.state.round_number
	_board._bot.set_enabled(false)
	_board.manager.set_process(false)
	_board.instant_roll_for_test = true
	_board.pacing_enabled = false
	_board.ai_mode = false


func _run() -> void:
	MatchTelemetry.test_sender = func(_url: String, _body: PackedByteArray, _type: String) -> void: pass
	_board._on_draft_auto_pressed()
	await settle(10)
	quiet()
	await settle()
	var manager: TurnManager = _board.manager
	manager.change_state(TurnManager.State.PHASE_TURN_BEGIN)
	quiet()
	var player: int = manager.current_player_id()
	var state: GameState = _board.state

	# 1) 피드백 창은 우선 창(10000)보다 위 층: 증강 선택·대상 선택이 떠도 [닫기]를 누를 수 있다
	var modal: FeedbackModal = _board._open_feedback("test")
	await settle()
	var layer: CanvasLayer = modal.find_child("FeedbackLayer", true, false) as CanvasLayer
	_expect(layer != null and layer.layer > 10000, "피드백 창은 증강 선택·우선 창 위의 전용 층에 그린다")
	_board._show_choice("대상", [{"label": "P2", "value": 2}] as Array[Dictionary], func(_v: Variant) -> void: pass)
	var choice_layer: CanvasLayer = _board._choice_overlay.get_parent() as CanvasLayer
	_expect(choice_layer != null and layer.layer > choice_layer.layer, "선택 창이 떠도 피드백 창이 위")
	_expect(_board.find_child("FeedbackModal", false, false) == modal, "피드백 창은 보드 바로 아래에서 찾을 수 있다 (중복으로 열리지 않음)")
	modal.close_modal()
	await settle()

	# 2) 슬림 선택 바: 보드 전체를 덮는 어두운 막이 없고 바깥 입력은 지나간다
	_expect(_board._choice_overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "선택 바 바깥은 보드 입력을 막지 않는다")
	var dims: Array = _board._choice_overlay.find_children("*", "ColorRect", true, false)
	_expect(dims.is_empty(), "보드를 어둡게 덮는 막이 없다")
	var bar: Control = _board._choice_overlay.find_child("ChoiceBarPanel", true, false) as Control
	_expect(bar != null and bar.position.y < 120.0 and bar.size.y < 140.0, "화면 위쪽의 낮은 바 (y=%.0f, h=%.0f)" % [bar.position.y if bar else -1.0, bar.size.y if bar else -1.0])
	_board._close_choice()

	# 3) BANG! 대상 고르기 중에 차례가 넘어가면 표식·안내 띠를 치운다
	state.hands[player] = [&"ACT_02"]
	var victim: int = player % 4 + 1
	var victim_pawn: PlayerPawn = state.pawns_of(victim)[0]
	victim_pawn.has_left_start = true
	victim_pawn.current_tile_idx = 9
	_board._refresh_all()
	await settle()
	_board._on_card_pressed(player, &"ACT_02")
	_expect(_board._snipe_pick and not _board._snipe_marks.is_empty() and _board._pick_banner.visible, "BANG! 대상 고르기가 열린다")
	manager.current_turn_index = manager.player_order.find(victim)  # 시간 초과·온라인 진행으로 차례가 넘어간 상황
	await settle(3)
	_expect(not _board._snipe_pick and _board._snipe_marks.is_empty() and not _board._pick_banner.visible and not _board._pick_cancel.visible,
		"차례가 넘어가면 BANG! 표식과 안내 띠가 사라진다")
	manager.current_turn_index = manager.player_order.find(player)

	# 4) 굴리기 아래 필살기 안내: 쓸 수 있는 필살기가 있으면 [필살기명!] 버튼과 한 줄 효과
	manager.change_state(TurnManager.State.PHASE_TURN_BEGIN)
	quiet()
	var units: Array[int] = [2, 3, 4, 1]
	for index: int in 4:
		var pawn: PlayerPawn = state.pawns_of(player)[index]
		pawn.kind = GameEnums.PawnKind.CHESS
		pawn.unit_no = units[index]
		pawn.has_left_start = true
		pawn.current_tile_idx = 3 + index * 3
		pawn.skill_used = false
	_board._refresh_all()
	await settle()
	_expect(_board._skill_hint.visible, "내 차례에 쓸 수 있는 필살기가 있으면 굴리기 아래에 안내가 뜬다")
	var hint_button: Button = _board._skill_hint.find_child("SkillHintButton", true, false) as Button
	var hint_effect: Label = _board._skill_hint.find_child("SkillHintEffect", true, false) as Label
	_expect(hint_button != null and hint_effect != null and hint_effect.text != "", "필살기 버튼과 한 줄 효과")
	_expect(_board._skill_hint.position.y > _board._roll_button.position.y, "굴리기 버튼 바로 아래")
	for pawn: PlayerPawn in state.pawns_of(player):
		pawn.skill_used = true
	_board._refresh_all()
	await settle()
	_expect(not _board._skill_hint.visible, "쓸 필살기가 없으면 안내를 숨긴다")

	_board._reset_presentation()
	_board._close_choice()
	MatchTelemetry.test_sender = Callable()
	var board: MainBoard = _board
	_board = null
	board.queue_free()
	await settle()
	for failure: String in _failures:
		printerr("HOTFIX2_UI_FAIL ", failure)
	print("HOTFIX2_UI ", checks, " assertions; ", _failures.size(), " failures")
	quit(0 if _failures.is_empty() else 1)
