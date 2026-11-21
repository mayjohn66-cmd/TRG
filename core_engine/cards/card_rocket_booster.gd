# File: res://core_engine/cards/card_rocket_booster.gd
# Class: class_name CardRocketBooster
# Role: ACT_04 긴급 로켓 부스터 - 굴리기 전에 쓰면 이번 턴 첫 굴림 결과에 +3을 더한다
class_name CardRocketBooster
extends BaseCard


func _init() -> void:
	card_id = &"ACT_04"
	display_name = "고출력 로켓 부스터"
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


func create_command(_state: GameState, player_id: int, _params: Dictionary) -> GameCommand:
	return RocketBoosterCommand.new(player_id)
