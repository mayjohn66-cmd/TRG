# File: res://core_engine/cards/card_ghost.gd
# Class: class_name CardGhost
# Role: SUM_02 팩맨의 고스트 - 반환점(12번)에 고스트 NPC를 소환한다 (외곽 트랙을 역주행으로 3칸씩 순찰하며 마주친 말을 12번으로 연행)
class_name CardGhost
extends BaseCard


func _init() -> void:
	card_id = &"SUM_02"
	display_name = "팩맨의 고스트"
	category = GameEnums.CardCategory.SUMMON
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


func can_play(state: GameState, _player_id: int, _params: Dictionary) -> bool:
	return state.npcs.size() < GameEnums.MAX_NPCS


func create_command(_state: GameState, player_id: int, _params: Dictionary) -> GameCommand:
	return SpawnNpcCommand.new(player_id, GameEnums.HALFWAY_TILE, GameEnums.NpcBehavior.PATROL_REVERSE, &"SUM_02")
