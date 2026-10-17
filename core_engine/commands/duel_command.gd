# File: res://core_engine/commands/duel_command.gd
# Class: class_name DuelCommand
# Role: ACT_09 운명의 가위바위보 결투 시작 - 결투 신청만 알리고(duel_requested), 손 고르기·승패·말 밀어내기는 TurnManager의 결투 상태가 입력을 받아 진행한다
class_name DuelCommand
extends GameCommand

var target_player: int = -1


func _init(acting_player: int = -1, defender: int = -1) -> void:
	super()
	sender_id = acting_player
	target_player = defender
	command_name = "Duel"


func can_execute(_ctx: RuleContext) -> bool:
	return state != null and DuelRules.targets(state, sender_id).has(target_player)


func _run() -> void:
	state.duel_requested.emit(sender_id, target_player)
