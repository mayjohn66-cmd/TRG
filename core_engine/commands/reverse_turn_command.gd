# File: res://core_engine/commands/reverse_turn_command.gd
# Class: class_name ReverseTurnCommand
# Role: ACT_01 실행 - 턴 진행 순서를 반대로 뒤집고 이동 방향 역주행 라운드를 1로 설정
class_name ReverseTurnCommand
extends GameCommand


func _init(acting_player: int = -1) -> void:
	player_id = acting_player
	command_name = &"ReverseTurn"


func _run(state: GameState) -> void:
	state.reverse_turn_order()
	state.reverse_move_rounds_left = 1
