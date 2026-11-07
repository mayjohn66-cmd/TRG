## 다른 사람이 덱에서 카드를 뽑을 때 뒷면(노란 테두리) 카드가 프로필로 날아가지 않는다.
## 내 손패로 오는 카드와, 빼앗기·빵집처럼 출발지가 있는 카드는 그대로 날아간다.
extends "res://tests/ui_fx_test.gd"
var checks := 0


func _expect(ok: bool, message: String) -> void:
	checks += 1
	super._expect(ok, message)


func settle(n: int = 4) -> void:
	for i: int in n:
		await process_frame


func _run() -> void:
	MatchTelemetry.test_sender = func(_url: String, _body: PackedByteArray, _type: String) -> void: pass
	_board._on_draft_auto_pressed()
	await settle(10)
	_board._announcer.cancel()
	_board._reset_presentation()
	_board._close_opening()
	_board._close_draft_overlay()
	_board._close_augment_review()
	_board._draw_fx.clear()
	await settle()
	var fx: CardDrawFX = _board._draw_fx
	var me: int = _board._dock_owner()
	var other: int = 2 if me != 2 else 3
	# 1) 남이 덱에서 뽑음: 날아가는 카드가 없다
	_board.state.give_card(other, &"ACT_02")
	_board._fly_drawn_card(other, &"ACT_02")
	await settle(2)
	_expect(not fx.busy() and fx.in_flight == 0, "남이 덱에서 뽑으면 프로필로 날아가는 카드가 없다")
	_expect(fx.get_children().filter(func(c: Node) -> bool: return c.name == "DrawnCard").is_empty(), "날아가는 카드 노드도 만들지 않는다")
	# 2) 내가 뽑음: 손패로 날아온다
	_board.state.give_card(me, &"ACT_02")
	_board._fly_drawn_card(me, &"ACT_02")
	_expect(fx.busy(), "내가 뽑는 카드는 그대로 날아온다")
	fx.clear()
	await settle()
	# 3) 빼앗김(출발지가 프로필): 그대로 날아간다
	_board._steal_from = me
	_board.state.give_card(other, &"ACT_03")
	_board._fly_drawn_card(other, &"ACT_03")
	_expect(fx.busy(), "빼앗은 카드는 빼앗긴 사람 프로필에서 날아간다")
	fx.clear()
	await settle()
	MatchTelemetry.test_sender = Callable()
	var board: MainBoard = _board
	_board = null
	board.queue_free()
	await settle()
	for failure: String in _failures:
		printerr("REMOTE_DRAW_FAIL ", failure)
	print("REMOTE_DRAW ", checks, " assertions; ", _failures.size(), " failures")
	quit(0 if _failures.is_empty() else 1)
