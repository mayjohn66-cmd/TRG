# File: res://core_engine/cards/card_ghost.gd
# Class: class_name CardGhost
# Role: SUM_02 와구와구 유령 - 상단 코너(오른쪽 위·반환점) 한 곳에 소환하면 보드에 남아 역방향으로 3~6칸씩(소환 직후·라운드 종료마다) 전진하고, 말을 만나면 그 칸의 말을 모두 사출하고 사라진다. 중립 기물은 한 번에 하나만
class_name CardGhost
extends BaseCard


func _init() -> void:
	card_id = &"SUM_02"
	display_name = "와구와구 유령"
	category = GameEnums.CardCategory.SUMMON
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


func needs_tile() -> bool:
	return true


## params: {"tile": 상단 코너}
func can_play(state: GameState, _player_id: int, params: Dictionary) -> bool:
	return SweepCommand.can_summon(state) and SweepCommand.spawn_tiles().has(int(params.get("tile", -1)))


func create_command(_state: GameState, player_id: int, params: Dictionary) -> GameCommand:
	return SweepCommand.new(player_id, int(params["tile"]), card_id)
