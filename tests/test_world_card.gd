# File: res://tests/test_world_card.gd
# Class: class_name TestWorldCard
# Role: ACT_12 XI. The World!! (이번 턴이 끝나면 한 턴 더) - 턴이 끝나는 모든 길(이동·낙·제한시간·라운드 마지막 차례·처치로 얻는 추가 턴)에서 한 턴이 더 오는지 검증
class_name TestWorldCard
extends TestCase

const Phase := TurnManager.State


func _new_manager(player_count: int = 2) -> TurnManager:
	var manager := TurnManager.new()
	manager.boost_gimmicks = false
	manager.hotseat_mode = true
	manager.draft_enabled = false
	tree.root.add_child(manager)
	var ids: Array[int] = []
	for i: int in range(1, player_count + 1):
		ids.append(i)
	manager.start_game(ids, 4242)
	return manager


func _dispose(manager: TurnManager) -> void:
	tree.root.remove_child(manager)
	manager.free()


func _do(manager: TurnManager, player_id: int, action: StringName, params: Dictionary = {}) -> void:
	var payload: Dictionary = params.duplicate()
	payload["player_id"] = player_id
	manager.act(action, payload)


func _tool(manager: TurnManager, player_id: int, results: Array) -> void:
	manager.state.tools[player_id] = ScriptedTool.new(results)


## 평범한 한 차례: 카드(없으면 건너뜀) -> 굴리기 -> 말 고르기. 누구 차례든 first_pawn으로 움직인다.
func _play_turn(manager: TurnManager, player_id: int, steps: int) -> void:
	_tool(manager, player_id, [steps, steps])
	_do(manager, player_id, &"proceed")
	_do(manager, player_id, &"roll")
	_do(manager, player_id, &"select_pawn", {"pawn_id": player_id * 10 + 1})


func test_world_gives_one_more_turn_even_when_last_in_the_round() -> void:
	var manager: TurnManager = _new_manager()
	var state: GameState = manager.state
	_play_turn(manager, 1, 3)
	check_eq(state.current_player, 2, "P1이 끝나면 P2 차례")
	var round_before: int = state.round_number
	state.give_card(2, &"ACT_12")
	_do(manager, 2, &"play_card", {"card_id": &"ACT_12"})
	_play_turn(manager, 2, 2)
	check_eq(state.current_player, 2, "라운드 마지막 차례에 쓴 더 월드: P2가 한 번 더 한다")
	check_eq(state.round_number, round_before, "아직 같은 라운드 (중립 단계로 넘어가지 않았다)")
	check(not bool(state.extra_turns.get(2, false)), "쓴 효과는 소모된다")
	_play_turn(manager, 2, 2)
	check(state.current_player != 2 or state.round_number > round_before, "두 번째 차례가 끝나면 정상 진행")
	_dispose(manager)


func test_world_survives_a_roll_that_ends_the_turn() -> void:
	var manager: TurnManager = _new_manager()
	var state: GameState = manager.state
	state.give_card(1, &"ACT_12")
	_do(manager, 1, &"play_card", {"card_id": &"ACT_12"})
	var fall: RollResult = RollResult.make(&"SCRIPTED", 0)
	fall.ends_turn = true  # 윷 낙·타로 광대처럼 이동 없이 턴 종료
	_tool(manager, 1, [fall])
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	check_eq(state.current_player, 1, "낙으로 턴이 끝나도 더 월드의 한 턴이 온다")
	check_eq(manager.current_state, Phase.PHASE_TURN_BEGIN, "새 차례는 카드 단계부터")
	_dispose(manager)


func test_world_survives_timeouts_all_the_way() -> void:
	var manager: TurnManager = _new_manager()
	var state: GameState = manager.state
	state.give_card(1, &"ACT_12")
	_do(manager, 1, &"play_card", {"card_id": &"ACT_12"})
	_tool(manager, 1, [4, 4, 4])
	var guard: int = 0
	while state.current_player == 1 and state.round_number == 1 and guard < 20:
		manager.force_timeout()
		guard += 1
		if bool(state.extra_turns.get(1, false)) == false and guard > 1 and state.current_player == 1 and manager.current_state == Phase.PHASE_TURN_BEGIN:
			break  # 효과가 소모되고 같은 사람의 새 차례가 시작됐다
	check_eq(state.current_player, 1, "제한시간으로 흘러가도 더 월드의 한 턴이 온다")
	check(not bool(state.extra_turns.get(1, false)), "효과는 소모됐다")
	_dispose(manager)


func test_world_stacks_with_the_capture_extra_turn() -> void:
	var manager: TurnManager = _new_manager()
	var state: GameState = manager.state
	# P2 말을 P1 말 앞 3칸에 세워 두고 P1이 3칸으로 잡는다
	var victim: PlayerPawn = state.get_pawn(21)
	victim.has_left_start = true
	victim.current_tile_idx = 4
	var mover: PlayerPawn = state.get_pawn(11)
	mover.kind = GameEnums.PawnKind.YUT  # 처치로 추가 굴림을 얻는 것은 윷놀이 기물뿐이다
	mover.has_left_start = true
	mover.current_tile_idx = 1
	state.give_card(1, &"ACT_12")
	_do(manager, 1, &"play_card", {"card_id": &"ACT_12"})
	_play_turn(manager, 1, 3)
	check(state.get_pawn(21).current_tile_idx != 4 or not state.get_pawn(21).has_left_start, "P2 말을 잡았다")
	var turns_of_p1: int = 0
	var guard: int = 0
	while state.current_player == 1 and guard < 4:
		turns_of_p1 += 1
		_play_turn(manager, 1, 2)
		guard += 1
	check(turns_of_p1 >= 2, "처치 추가 굴림 + 더 월드의 한 턴이 모두 온다 (P1이 %d번 더)" % turns_of_p1)
	_dispose(manager)
