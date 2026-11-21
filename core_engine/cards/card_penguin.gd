# File: res://core_engine/cards/card_penguin.gd
# Class: class_name CardPenguin
# Role: ACT_21 펭짱 8호 - 내 턴 시작에 쓰는 공격 카드. 내 말 하나를 출발점으로 정하고 각도·세기를 잡으면 펭귄이 알까기처럼 날아가 부딪힌 적 말을 모두 출발선으로 날려 버린다
class_name CardPenguin
extends BaseCard


func _init() -> void:
	card_id = &"ACT_21"
	display_name = "펭짱 8호"
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


func needs_pawn() -> bool:
	return true


func could_play(state: GameState, player_id: int) -> bool:
	return not PenguinCommand.origins(state, player_id).is_empty()


## params: {"pawn_id": 출발점 내 말, "angle": 라디안, "power": 0~1}
func can_play(state: GameState, player_id: int, params: Dictionary) -> bool:
	var pawn: PlayerPawn = state.get_pawn(int(params.get("pawn_id", -1)))
	return pawn != null and PenguinCommand.origins(state, player_id).has(pawn) and params.has("angle") and params.has("power") and not is_nan(float(params["angle"]))


func create_command(_state: GameState, player_id: int, params: Dictionary) -> GameCommand:
	return PenguinCommand.new(player_id, int(params["pawn_id"]), float(params["angle"]), float(params["power"]))
