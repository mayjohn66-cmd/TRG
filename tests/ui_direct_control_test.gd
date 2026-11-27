## 판정 도구 직접 조작 2차 (1.3.1): 룰렛 끌어 돌리기(모바일 보정)·슬롯 릴 직접 멈추기·다트 끌어 던지기·복권 직접 긁기.
## 결과(그림·칸)는 엔진이 정한 그대로이고, 손을 대지 않으면 저절로 진행한다.
extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func frames(count: int = 2) -> void:
	for index: int in count:
		await process_frame


func run() -> void:
	create_timer(120).timeout.connect(func() -> void: printerr("DIRECT_CONTROL_FAIL timeout"); quit(1))
	roulette()
	darts()
	await slot()
	await scratch()
	await presenter_flow()
	if failures.is_empty():
		print("UI direct control test passed")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func roulette() -> void:
	check(RollPad.fling_power(0.0, 3.0, 0.1, false) == RollPad.ONE_CLICK_POWER, "톡 누르면 예전처럼 원클릭 세기")
	check(RollPad.fling_power(1.0, 40.0, 0.6, false) < 0.0, "PC: 천천히 돌리다 놓으면 던지지 않는다")
	check(RollPad.fling_power(12.0, 80.0, 0.3, false) > 0.5, "PC: 빠르게 돌려 놓으면 던진다")
	check(RollPad.fling_power(1.0, 18.0, 0.4, true) > 0.0, "모바일: 조금만 착 튕겨도 돈다")
	check(RollPad.fling_power(0.3, 15.0, 0.5, true) > 0.0, "모바일: 짧게 끌기만 해도 돈다")
	check(RollPad.fling_power(9.0, 60.0, 0.2, true) >= RollPad.fling_power(9.0, 60.0, 0.2, false), "모바일은 같은 속도에 세기를 더 준다")


func darts() -> void:
	check(MainBoard.dart_throw_released(Vector2(100, 200), Vector2(104, 140), 300, false), "PC: 위로 60px 끌면 던진다")
	check(not MainBoard.dart_throw_released(Vector2(100, 200), Vector2(104, 180), 300, false), "PC: 조금만 끌면 안 던진다")
	check(not MainBoard.dart_throw_released(Vector2(100, 200), Vector2(200, 150), 300, false), "옆으로 끈 것은 던지기가 아니다")
	check(not MainBoard.dart_throw_released(Vector2(100, 200), Vector2(100, 260), 300, true), "아래로 당기기만 하면 안 던진다")
	check(MainBoard.dart_throw_released(Vector2(100, 200), Vector2(100, 182), 300, true), "모바일: 위로 18px만 착 튕겨도 던진다")
	check(MainBoard.dart_throw_released(Vector2(100, 200), Vector2(100, 189), 120, true), "모바일: 짧고 빠른 튕김도 던진다")


func slot() -> void:
	var values: Array[int] = [5, 2, 5]
	var machine := SlotMachine3D.new()
	root.add_child(machine)
	await frames()
	machine.manual = true
	machine.begin(values, 0.5)
	machine.apply_time(0.2)
	check(machine.awaiting_stop(), "직접 멈추기: 처음에는 세 릴 모두 돈다")
	check(not machine.request_stop(), "너무 이르면 멈추지 않는다")
	machine.apply_time(1.4)
	check(not machine.stopped[0], "누르기 전에는 원래 멈추는 시각(1.1초)이 지나도 계속 돈다")
	check(machine.request_stop(), "첫 번째 릴 멈춤")
	machine.apply_time(1.5)
	check(not machine.request_stop(), "바로 이어 누르면 간격(0.18초) 전에는 받지 않는다")
	machine.apply_time(1.65)
	check(machine.request_stop(), "두 번째 릴 멈춤")
	# 세 번째 릴은 누르지 않는다: 3초 뒤 저절로 선다
	var t: float = 1.65
	while t < 12.0 and machine.awaiting_stop():
		t += 0.05
		machine.apply_time(t)
	check(not machine.awaiting_stop() and t < 5.2, "누르지 않은 릴은 저절로 선다 (%.2f초)" % t)
	var end: float = machine.total_time()
	check(end < 8.0, "멈춘 뒤 연출 길이가 정해진다")
	machine.apply_time(end)
	check(machine.settled, "다 선 뒤 결과 표시")
	check(machine.displayed_values() == values, "릴이 엔진이 정한 그림에 선다 %s" % [machine.displayed_values()])
	for symbol: int in 6:
		machine.begin([symbol, (symbol + 3) % 6, symbol] as Array[int], 0.5)
		for when: float in [0.9, 2.37, 3.1]:
			machine.apply_time(when)
			machine.request_stop()
		machine.apply_time(machine.total_time())
		check(machine.displayed_values() == [symbol, (symbol + 3) % 6, symbol], "언제 눌러도 정한 그림에 선다 (%d)" % symbol)
	machine.queue_free()


func scratch() -> void:
	var view := ScratchTicketView.new()
	root.add_child(view)
	await frames()
	view.manual = true
	view.begin({"winning": 1, "cells": [1, 2, 1], "gold": [false, false, true]})
	view.apply_time(ScratchTicketView.SCRATCH_START)
	check(not view.manual_complete(), "처음에는 은박이 그대로")
	var center_x: Array[float] = []
	for cell: int in 3:
		var rect: Rect2 = ScratchTicketView.TicketPrint.cell_rect(cell)
		center_x.append((rect.get_center().x - ScratchTicketView.TicketPrint.SIZE.x * 0.5) * ScratchTicketView.VIEW_PER_PRINT + ScratchTicketView.SIZE.x * 0.5)
	var mid_y: float = ScratchTicketView.SIZE.y * 0.5 + 10.0
	view.scratch_at(Vector2(center_x[0], mid_y), 60.0)
	var progress: Array[float] = view.manual_progress()
	check(progress[0] > 0.2 and progress[1] == 0.0 and progress[2] == 0.0, "문지른 칸만 벗겨진다 %s" % [progress])
	for cell: int in 3:
		for stroke: int in 6:
			view.scratch_at(Vector2(center_x[cell], mid_y), 40.0)
	check(view.manual_complete(), "세 칸을 다 긁으면 완료")
	view.queue_free()


func presenter_flow() -> void:
	var host := Control.new()
	host.size = Vector2(1366, 768)
	root.add_child(host)
	var presenter := RollPresenter.new()
	host.add_child(presenter)
	await frames()
	presenter.interactive = true
	var result: Dictionary = {"tool_id": &"SLOT_777", "steps": 8, "reroll": false, "ends_turn": false, "can_continue": false, "details": {"reels": [3, 3, 3]}}
	var done: Array[bool] = [false]
	var play_slot := func() -> void:
		await presenter.play(&"SLOT_777", result, 0.5)
		done[0] = true
	play_slot.call()
	await create_timer(0.3).timeout
	check(presenter.awaiting_input(), "내가 굴린 슬롯은 입력을 기다린다")
	check(presenter.mouse_filter == Control.MOUSE_FILTER_STOP, "기다리는 동안 화면이 누름을 받는다")
	await create_timer(0.6 + RollPresenter.DROP_TIME).timeout  # 1.3.1: 떨어져 놓인 다음에 릴이 돌기 시작한다
	for reel: int in 3:
		check(presenter.manual_tap(), "탭 %d번째: 릴 멈춤" % (reel + 1))
		await create_timer(0.3).timeout
	check(not presenter.awaiting_input(), "세 릴을 다 멈추면 입력을 그만 받는다")
	var waited: float = 0.0
	while not done[0] and waited < 6.0:
		await create_timer(0.1).timeout
		waited += 0.1
	check(done[0], "다 멈추면 연출이 끝난다")
	check(presenter.mouse_filter == Control.MOUSE_FILTER_IGNORE, "끝나면 누름을 다시 통과시킨다")
	# 복권: 다 긁으면 바로 공개, 남이 굴린 것(interactive 꺼짐)은 저절로
	presenter.interactive = true
	var ticket: Dictionary = {"tool_id": &"DICE_SCRATCH", "steps": 5, "reroll": false, "ends_turn": false, "can_continue": false, "details": {"winning": 0, "cells": [0, 0, 3], "gold": [false, false, false], "matches": 2}}
	done[0] = false
	var play_ticket := func() -> void:
		await presenter.play(&"DICE_SCRATCH", ticket, 0.5)
		done[0] = true
	play_ticket.call()
	await create_timer(0.6).timeout
	check(presenter.awaiting_input(), "내가 굴린 복권은 긁기를 기다린다")
	var view: ScratchTicketView = presenter.find_child("*", true, false) as ScratchTicketView
	for node: Node in presenter.find_children("*", "", true, false):
		if node is ScratchTicketView:
			view = node
	if view != null:
		for cell: int in 3:
			var rect: Rect2 = ScratchTicketView.TicketPrint.cell_rect(cell)
			var x: float = (rect.get_center().x - ScratchTicketView.TicketPrint.SIZE.x * 0.5) * ScratchTicketView.VIEW_PER_PRINT + ScratchTicketView.SIZE.x * 0.5
			for stroke: int in 8:
				view.scratch_at(Vector2(x, ScratchTicketView.SIZE.y * 0.5 + 10.0), 40.0)
	waited = 0.0
	while not done[0] and waited < 4.0:
		await create_timer(0.1).timeout
		waited += 0.1
	check(done[0] and waited < 2.5, "다 긁으면 곧바로 공개하고 끝난다 (%.1f초)" % waited)
	presenter.interactive = false
	done[0] = false
	play_ticket.call()
	await create_timer(0.6).timeout
	check(not presenter.awaiting_input(), "남이 굴린 복권은 동전이 긁는다")
	waited = 0.0
	while not done[0] and waited < 5.0:
		await create_timer(0.1).timeout
		waited += 0.1
	check(done[0], "자동 복권 연출도 끝난다")
	host.queue_free()
