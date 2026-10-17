# File: res://core_engine/cards/card_bandit.gd
# Class: class_name CardBandit
# Role: SUM_01 카탄의 도적떼 - 원하는 타일에 도적 NPC를 소환한다 (라운드 종료 시 가장 가까운 말을 BFS로 추격해 카드 1장을 빼앗고 추방)
class_name CardBandit
extends BaseCard


func _init() -> void:
	card_id = &"SUM_01"
	display_name = "카탄의 도적떼"
	category = GameEnums.CardCategory.SUMMON
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


func needs_tile() -> bool:
	return true


func can_play(state: GameState, _player_id: int, params: Dictionary) -> bool:
	return state.board.is_valid_tile(int(params.get("tile", -1))) and state.npcs.size() < GameEnums.MAX_NPCS


func create_command(_state: GameState, player_id: int, params: Dictionary) -> GameCommand:
	return SpawnNpcCommand.new(player_id, int(params["tile"]), GameEnums.NpcBehavior.CHASE_NEAREST, &"SUM_01")
