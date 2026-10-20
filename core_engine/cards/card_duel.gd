# File: res://core_engine/cards/card_duel.gd
# Class: class_name CardDuel
# Role: ACT_09 일기토 데스매치 - 내 턴 시작에 상대 1명과 6종 랜덤 미니게임 결투(DuelRules)를 한다. 이긴 사람의 말은 +3칸 전진하고 진 사람의 선두 말은 출발선으로 장외 사출된다 (대상을 안 고르면 가장 앞선 상대)
class_name CardDuel
extends BaseCard


func _init() -> void:
	card_id = &"ACT_09"
	display_name = "일기토 데스매치"
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


func could_play(state: GameState, player_id: int) -> bool:
	return not DuelRules.targets(state, player_id).is_empty()


## params: {"target_player": int} (생략하면 가장 앞선 상대)
func can_play(state: GameState, player_id: int, params: Dictionary) -> bool:
	return DuelRules.targets(state, player_id).has(_target_of(state, player_id, params))


func create_command(state: GameState, player_id: int, params: Dictionary) -> GameCommand:
	return DuelCommand.new(player_id, _target_of(state, player_id, params))


func _target_of(state: GameState, player_id: int, params: Dictionary) -> int:
	var target: int = int(params.get("target_player", -1))
	return target if target != -1 else DuelRules.default_target(state, player_id)
