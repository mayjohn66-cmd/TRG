# File: res://core_engine/commands/repeal_law_command.gd
# Class: class_name RepealLawCommand
# Role: ACT_06 실행 - 중앙 법전에서 지정한 교칙(law_id)을 영구 삭제
class_name RepealLawCommand
extends GameCommand

var target_law_id: String = ""


func _init(acting_player: int = -1, law_id: String = "") -> void:
	player_id = acting_player
	target_law_id = law_id
	command_name = &"RepealLaw"


func _run(state: GameState) -> void:
	state.rulebook.remove_law_by_id(target_law_id)
