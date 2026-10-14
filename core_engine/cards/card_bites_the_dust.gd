# File: res://core_engine/cards/card_bites_the_dust.gd
# Class: class_name CardBitesTheDust
# Role: ACT_05 바이츠 더 더스트 - 말이 잡히거나 함정을 밟은 직후, 이번 턴 시작 시점(TurnSnapshot)으로 보드를 롤백
class_name CardBitesTheDust
extends BaseCard


func _init() -> void:
	card_id = &"ACT_05"
	display_name = "바이츠 더 더스트"
	playable_phases = [TurnManager.State.PHASE_RESOLUTION]


func can_play(state: GameState, player_id: int, _params: Dictionary) -> bool:
	return state.turn_snapshot != null and state.hurt_players.has(player_id)


func create_command(_state: GameState, player_id: int, _params: Dictionary) -> GameCommand:
	return RollbackCommand.new(player_id)
