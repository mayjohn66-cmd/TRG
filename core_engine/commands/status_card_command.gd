# File: res://core_engine/commands/status_card_command.gd
# Class: class_name StatusCardCommand
# Role: 상태만 바꾸는 즉발 카드 - ACT_11 밑장빼기(다음 굴림 결과 지정) / ACT_12 더 월드(추가 턴) / ACT_14 알고리즘 밴(2턴 카드·필살기·리롤 금지) / ACT_15 우노 스킵(대상의 다음 턴 건너뛰기)
class_name StatusCardCommand
extends GameCommand

const BAN_TURNS: int = 2

var card_id: StringName = &""
var target_player: int = -1
var steps: int = 0


func _init(acting_player: int = -1, id: StringName = &"", target: int = -1, chosen_steps: int = 0) -> void:
	super()
	sender_id = acting_player
	card_id = id
	target_player = target
	steps = chosen_steps
	command_name = "Status"


## 알고리즘 밴이 걸리는 대상의 턴 수 (cards_table.csv ACT_14 param_1).
static func ban_turns() -> int:
	return maxi(CardRegistry.param(&"ACT_14", BAN_TURNS), 1)


## 밴·스킵을 걸 수 있는 상대 (레이스에 남은 다른 플레이어).
static func targets(game: GameState, player_id: int) -> Array[int]:
	var result: Array[int] = []
	for other: int in game.player_ids:
		if other != player_id and not game.is_graduated(other):
			result.append(other)
	return result


func _run() -> void:
	match card_id:
		&"ACT_11":
			state.forced_roll[sender_id] = steps
		&"ACT_12":
			state.extra_turns[sender_id] = true
		&"ACT_14":
			state.record_effect(target_player, "ban", int(state.banned_turns.get(target_player, 0)))
			state.banned_turns[target_player] = ban_turns()
		&"ACT_15":
			state.record_effect(target_player, "rest", bool(state.rest_next_turn.get(target_player, false)))
			state.rest_next_turn[target_player] = true
