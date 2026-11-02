## 제보(2026-11-02): 중립 기물(와구와구 유령·사료스탕스)이 움직이기 전에 깜빡였다.
## 라운드 끝 [중립 기물 출동!] 알림이 도는 동안 기물이 사라졌다가 달리기 직전에 다시 나타났다. 이제는 알림 동안 제자리에 그대로 있고,
## 달리는 그림이 생기는 바로 그 순간에 맞바꾼다. 말을 잡고 사라지는 기물도 다 달린 뒤에 치운다.
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
	_board.pacing_enabled = true


func _runner() -> Node:
	for child: Node in _board._pawn_layer.get_children():
		if child.name == "NpcRunner":
			return child
	return null


## 중립 기물 단계를 돌리며 프레임마다 점검한다: 그림이 안 보이는 프레임에는 달리는 그림이 반드시 있어야 한다 (둘 다 없는 프레임 = 깜빡임).
func _watch_phase(npc_id: int) -> Dictionary:
	var gaps: int = 0
	var saw_runner: bool = false
	var visible_before_runner: int = 0
	for i: int in 420:
		var view: Node2D = _board._npc_views.get(npc_id)
		var shown: bool = view != null and is_instance_valid(view) and view.visible
		var runner: Node = _runner()
		if runner != null:
			saw_runner = true
		if not shown and runner == null and not (saw_runner and view == null):
			gaps += 1
		if not saw_runner and shown:
			visible_before_runner += 1
		await process_frame
	return {"gaps": gaps, "saw_runner": saw_runner, "visible_before_runner": visible_before_runner}


func _run() -> void:
	MatchTelemetry.test_sender = func(_url: String, _body: PackedByteArray, _type: String) -> void: pass
	_board._on_draft_auto_pressed()
	await settle(10)
	quiet()
	var manager: TurnManager = _board.manager
	var state: GameState = _board.state
	manager.current_turn_index = manager.player_order.find(_board.local_player_id)
	manager.change_state(TurnManager.State.PHASE_TURN_BEGIN)
	quiet()
	var me: int = manager.current_player_id()
	for pawn: PlayerPawn in state.pawns:
		pawn.reset_to_start()

	# 1) 아무도 못 잡고 계속 전진: 알림이 도는 동안 그림이 그대로 보이고, 깜빡이는 프레임이 없다
	var ghost: NeutralNPC = state.spawn_npc(BoardSpec.halfway_tile, GameEnums.NpcBehavior.PATROL_REVERSE, me, &"SUM_02")
	_board._refresh_all()
	await settle()
	var ghost_id: int = ghost.entity_id
	_expect(_board._npc_views.has(ghost_id) and (_board._npc_views[ghost_id] as Node2D).visible, "소환된 기물이 보드에 보인다")
	manager._enter_neutral_npc_phase()
	var survived: Dictionary = await _watch_phase(ghost_id)
	_expect(bool(survived["saw_runner"]), "기물이 한 칸씩 달리는 그림이 나온다")
	_expect(int(survived["gaps"]) == 0, "알림~달리기 사이에 그림이 사라지는 프레임이 없다 (깜빡임 %d프레임)" % int(survived["gaps"]))
	_expect(int(survived["visible_before_runner"]) > 0, "달리기 전 [중립 기물 출동!] 알림이 도는 동안 기물이 제자리에 보인다")
	var view_after: Node2D = _board._npc_views.get(ghost_id)
	_expect(view_after != null and view_after.visible and not view_after.has_meta("npc_run"), "다 달린 뒤 그림이 도착 칸에 다시 보이고 달리기 표시는 풀린다")

	# 2) 말을 잡고 사라지는 기물: 달리는 동안 그림이 남아 있다가 다 달린 뒤에 치운다
	state.clear_npcs()
	_board._refresh_all()
	await settle()
	quiet()
	var victim: PlayerPawn = state.pawns_of(2 if me != 2 else 3)[0]
	victim.has_left_start = true
	victim.current_tile_idx = BoardSpec.halfway_tile - 2
	var catcher: NeutralNPC = state.spawn_npc(BoardSpec.halfway_tile, GameEnums.NpcBehavior.PATROL_REVERSE, me, &"SUM_02")
	_board._refresh_all()
	await settle()
	var catcher_id: int = catcher.entity_id
	manager._enter_neutral_npc_phase()
	var caught: Dictionary = await _watch_phase(catcher_id)
	_expect(state.get_npc(catcher_id) == null, "엔진: 기물이 적 말을 잡고 사라졌다")
	_expect(int(caught["gaps"]) == 0, "사라지는 기물도 달리기 전에 그림이 먼저 꺼지지 않는다 (깜빡임 %d프레임)" % int(caught["gaps"]))
	_expect(bool(caught["saw_runner"]) and int(caught["visible_before_runner"]) > 0, "잡는 기물도 알림 동안 제자리에 보이다가 달린다")
	_expect(not _board._npc_views.has(catcher_id), "다 달린 뒤에는 기물 그림이 치워진다 (남은 그림 없음)")

	_board._reset_presentation()
	MatchTelemetry.test_sender = Callable()
	var board: MainBoard = _board
	_board = null
	board.queue_free()
	await settle()
	for failure: String in _failures:
		printerr("NPC_BLINK_FAIL ", failure)
	print("NPC_BLINK ", checks, " assertions; ", _failures.size(), " failures")
	quit(0 if _failures.is_empty() else 1)
