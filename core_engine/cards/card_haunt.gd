# File: res://core_engine/cards/card_haunt.gd
# Class: class_name CardHaunt
# Role: ACT_18 방해령 베루 / ACT_19 방해령 사리 / ACT_20 방해령 메죵 - 턴 시작에 쓰는 방해령 삼총사. 단독 효과는 미미하지만 셋을 손패에 모으면 특수 승리(LAW_09)가 된다
class_name CardHaunt
extends BaseCard

const NAMES: Dictionary = {
	&"ACT_18": "방해령 베루",
	&"ACT_19": "방해령 사리",
	&"ACT_20": "방해령 메죵",
}


func _init(id: StringName = &"ACT_18") -> void:
	card_id = id
	display_name = NAMES[id]
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


## 말 1개를 고르는 카드인가 (베루·사리). 메죵은 적 플레이어를 고른다.
func needs_pawn() -> bool:
	return card_id == HauntCommand.BERU or card_id == HauntCommand.SARI


func needs_target() -> bool:
	return card_id == HauntCommand.MEJONG


func could_play(state: GameState, player_id: int) -> bool:
	match card_id:
		HauntCommand.BERU: return not HauntCommand.shove_targets(state, player_id).is_empty()
		HauntCommand.SARI: return not HauntCommand.pull_targets(state, player_id).is_empty()
	return not HauntCommand.penalty_targets(state, player_id).is_empty()


## params: 베루·사리 {"pawn_id": int} / 메죵 {"target_player": int}
func can_play(state: GameState, player_id: int, params: Dictionary) -> bool:
	if not could_play(state, player_id):
		return false
	match card_id:
		HauntCommand.BERU:
			var victim: PlayerPawn = state.get_pawn(int(params.get("pawn_id", -1)))
			return victim != null and victim.owner_id != player_id and HauntCommand.shove_targets(state, player_id).has(victim)
		HauntCommand.SARI:
			var mine: PlayerPawn = state.get_pawn(int(params.get("pawn_id", -1)))
			return mine != null and HauntCommand.pull_targets(state, player_id).has(mine)
	return HauntCommand.penalty_targets(state, player_id).has(int(params.get("target_player", -1)))


func create_command(_state: GameState, player_id: int, params: Dictionary) -> GameCommand:
	return HauntCommand.new(player_id, card_id, int(params.get("pawn_id", -1)), int(params.get("target_player", -1)))
