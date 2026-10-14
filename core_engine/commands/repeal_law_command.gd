# File: res://core_engine/commands/repeal_law_command.gd
# Class: class_name RepealLawCommand
# Role: ACT_06 실행 - 중앙 법전의 지정 슬롯 교칙을 영구 삭제
class_name RepealLawCommand
extends GameCommand

var slot_index: int = -1


func _init(acting_player: int = -1, target_slot: int = -1) -> void:
	player_id = acting_player
	slot_index = target_slot
	command_name = &"RepealLaw"


func _run(state: GameState) -> void:
	state.rulebook.repeal_slot(slot_index)
