# File: res://core_engine/cards/card_door.gd
# Class: class_name CardDoor
# Role: ACT_13 슈팡 특급 배송 - 반환점까지의 빈 칸을 골라 내 선두 말을 순간이동시킨다
class_name CardDoor
extends BaseCard


func _init() -> void:
	card_id = &"ACT_13"
	display_name = "슈팡 특급 배송"
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


func needs_tile() -> bool:
	return true


func could_play(state: GameState, player_id: int) -> bool:
	return DoorCommand.traveler(state, player_id) != null


## params: {"tile": int}
func can_play(state: GameState, player_id: int, params: Dictionary) -> bool:
	return could_play(state, player_id) and DoorCommand.is_target_tile(state, int(params.get("tile", -1)))


func create_command(_state: GameState, player_id: int, params: Dictionary) -> GameCommand:
	return DoorCommand.new(player_id, int(params["tile"]))
