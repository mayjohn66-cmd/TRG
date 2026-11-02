# File: res://core_engine/cards/card_cucumber.gd
# Class: class_name CardCucumber
# Role: JNK_CUKE 오이 카드 (v1.1) - 모브 큐이의 오이를 밟으면 받는 먹통 카드. 낼 수 없고 손패 자리만 차지한다
class_name CardCucumber
extends BaseCard


func _init() -> void:
	card_id = &"JNK_CUKE"
	display_name = "오이 카드"
	playable_phases = []


func could_play(_state: GameState, _player_id: int) -> bool:
	return false


func can_play(_state: GameState, _player_id: int, _params: Dictionary) -> bool:
	return false


func create_command(_state: GameState, _player_id: int, _params: Dictionary) -> GameCommand:
	return null
