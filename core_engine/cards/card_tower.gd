# File: res://core_engine/cards/card_tower.gd
# Class: class_name CardTower
# Role: ACT_07 XVI. 무너지는 탑 - 보드의 한 변을 골라 그 변의 설치물(호텔·함정)을 모두 무너뜨린다
class_name CardTower
extends BaseCard


func _init() -> void:
	card_id = &"ACT_07"
	display_name = "XVI. 무너지는 탑"
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


func could_play(state: GameState, _player_id: int) -> bool:
	for side: int in 4:
		if TowerCommand.has_attachments(state, side):
			return true
	return false


## params: {"side": 0~3}
func can_play(state: GameState, _player_id: int, params: Dictionary) -> bool:
	var side: int = int(params.get("side", -1))
	return side >= 0 and side < 4 and TowerCommand.has_attachments(state, side)


func create_command(_state: GameState, player_id: int, params: Dictionary) -> GameCommand:
	return TowerCommand.new(player_id, int(params["side"]))
