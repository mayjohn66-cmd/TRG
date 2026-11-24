# File: res://core_engine/commands/appease_command.gd
# Class: class_name AppeaseCommand
# Role: ACT_25 회유책 실행 - 이 플레이어의 밴·스킵·해킹을 모두 푼다 (이번 해킹 턴 표시는 TurnManager가 함께 지운다)
class_name AppeaseCommand
extends GameCommand


func _init(acting_player: int = -1) -> void:
	super()
	sender_id = acting_player
	command_name = "Appease"


func _run() -> void:
	state.banned_turns.erase(sender_id)
	state.rest_next_turn[sender_id] = false
	state.hacked_turns.erase(sender_id)
	state.appease_offer.erase(sender_id)
