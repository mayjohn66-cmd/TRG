# File: res://core_engine/cards/card_tower.gd
# Class: class_name CardTower
# Role: ACT_07 XVI. 무너지는 탑 (The Tower) - 말이 가장 많이 모인 타일에 벼락을 내려 모든 말을 업기 해제하고 앞뒤 1~2칸으로 뿔뿔이 흩어 놓는다 (내 턴 굴리기 전)
class_name CardTower
extends BaseCard


func _init() -> void:
	card_id = &"ACT_07"
	display_name = "XVI. 무너지는 탑"
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


func could_play(state: GameState, player_id: int) -> bool:
	return TarotEffects.tower_target(state, player_id) != -1


func can_play(state: GameState, player_id: int, _params: Dictionary) -> bool:
	return TarotEffects.tower_target(state, player_id) != -1


func create_command(_state: GameState, player_id: int, _params: Dictionary) -> GameCommand:
	return TowerCommand.new(player_id)
