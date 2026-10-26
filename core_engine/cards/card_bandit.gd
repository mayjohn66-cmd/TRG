# File: res://core_engine/cards/card_bandit.gd
# Class: class_name CardBandit
# Role: SUM_01 사료스탕스 출동 - 상단 코너(맨 위 꼭짓점·반환점)에 소환하면 보드에 남아 정방향으로 3~6칸씩(소환 직후·라운드 종료마다) 전진하고, 말을 만나면 그 칸의 말을 모두 사출하고 사라진다. 중립 기물은 한 번에 하나만
class_name CardBandit
extends BaseCard


func _init() -> void:
	card_id = &"SUM_01"
	display_name = "사료스탕스 출동"
	category = GameEnums.CardCategory.SUMMON
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


func needs_tile() -> bool:
	return true


## params: {"tile": 상단 코너(반환점)}
func can_play(state: GameState, _player_id: int, params: Dictionary) -> bool:
	return SweepCommand.can_summon(state) and SweepCommand.spawn_tiles().has(int(params.get("tile", -1)))


func create_command(_state: GameState, player_id: int, params: Dictionary) -> GameCommand:
	return SweepCommand.new(player_id, int(params["tile"]), card_id)
