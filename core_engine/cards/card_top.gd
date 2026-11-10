# File: res://core_engine/cards/card_top.gd
# Class: class_name CardTop
# Role: SUM_04 황금장방형 팽이 - 상단 코너(반환점)에 팽이를 소환한다. 팽이는 라운드가 끝날 때마다 가장 가까운 적 말 쪽으로 한 칸씩 다가가고, 말이 있는 칸에 부딪히면 그 칸의 모든 말을 날려 버리고 사라진다. 중립 기물은 한 번에 하나만
class_name CardTop
extends BaseCard


func _init() -> void:
	card_id = &"SUM_04"
	display_name = "황금장방형 팽이"
	category = GameEnums.CardCategory.SUMMON
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


func needs_tile() -> bool:
	return true


func could_play(state: GameState, _player_id: int) -> bool:
	return SweepCommand.can_summon(state)


## params: {"tile": 상단 코너(반환점)}
func can_play(state: GameState, _player_id: int, params: Dictionary) -> bool:
	return SweepCommand.can_summon(state) and SweepCommand.spawn_tiles().has(int(params.get("tile", -1)))


func create_command(_state: GameState, player_id: int, params: Dictionary) -> GameCommand:
	return SweepCommand.new(player_id, int(params["tile"]), card_id)
