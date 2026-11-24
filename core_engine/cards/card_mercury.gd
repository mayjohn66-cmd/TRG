# File: res://core_engine/cards/card_mercury.gd
# Class: class_name CardMercury
# Role: ACT_26 수은 가드 - 내 턴 시작에 쓰는 일반 카드. 내 말 하나에 수은 보호막을 씌워 공격 카드에 의한 사출을 1회 막는다
#       (잡기·함정은 막지 않는다: 그건 긴급 엄폐). 이미 수은 보호막이 있는 말에는 쓸 수 없다.
class_name CardMercury
extends BaseCard


func _init() -> void:
	card_id = &"ACT_26"
	display_name = "수은 가드"
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


func needs_pawn() -> bool:
	return true


## 보호막을 씌울 수 있는 내 말: 보드 위에 나와 있고(출발선 대기·완주 제외) 업혀 있지 않으며 수은 보호막이 아직 없는 말.
static func targets(state: GameState, player_id: int) -> Array[PlayerPawn]:
	var result: Array[PlayerPawn] = []
	for pawn: PlayerPawn in state.pawns_of(player_id):
		if pawn.has_left_start and not pawn.is_finished and pawn.carrier == null and not pawn.mercury:
			result.append(pawn)
	return result


func could_play(state: GameState, player_id: int) -> bool:
	return not targets(state, player_id).is_empty()


## params: {"pawn_id": 내 말 ID}
func can_play(state: GameState, player_id: int, params: Dictionary) -> bool:
	var pawn: PlayerPawn = state.get_pawn(int(params.get("pawn_id", -1)))
	return pawn != null and targets(state, player_id).has(pawn)


func create_command(_state: GameState, player_id: int, params: Dictionary) -> GameCommand:
	return MercuryCommand.new(player_id, int(params.get("pawn_id", -1)))
