# File: res://core_engine/cards/card_hack.gd
# Class: class_name CardHack
# Role: ACT_23 전문적 해킹 - 내 턴 시작에 쓰는 일반 카드. 지정한 상대의 다음 한 턴이 자동으로 진행되어 버린다 (자동 굴림 + 무작위 말 이동, 그 턴에는 카드·필살기를 쓰지 못한다)
class_name CardHack
extends BaseCard


func _init() -> void:
	card_id = &"ACT_23"
	display_name = "전문적 해킹"
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


func needs_target() -> bool:
	return true


func could_play(state: GameState, player_id: int) -> bool:
	return not StatusCardCommand.targets(state, player_id).is_empty()


## params: {"target_player": int}
func can_play(state: GameState, player_id: int, params: Dictionary) -> bool:
	return StatusCardCommand.targets(state, player_id).has(int(params.get("target_player", -1)))


func create_command(_state: GameState, player_id: int, params: Dictionary) -> GameCommand:
	return HackCommand.new(player_id, int(params.get("target_player", -1)))
