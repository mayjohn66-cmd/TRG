# File: res://core_engine/cards/card_ghost.gd
# Class: class_name CardGhost
# Role: SUM_02 팩맨 - 상단 코너(오른쪽 위·반환점) 한 곳에 소환하면 역방향으로 3~6칸 달리며 길 위의 모든 말을 사출하고 사라진다
class_name CardGhost
extends BaseCard


func _init() -> void:
	card_id = &"SUM_02"
	display_name = "팩맨"
	category = GameEnums.CardCategory.SUMMON
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


func needs_tile() -> bool:
	return true


## params: {"tile": 상단 코너}
func can_play(_state: GameState, _player_id: int, params: Dictionary) -> bool:
	return SweepCommand.spawn_tiles().has(int(params.get("tile", -1)))


func create_command(_state: GameState, player_id: int, params: Dictionary) -> GameCommand:
	return SweepCommand.new(player_id, int(params["tile"]), card_id)
