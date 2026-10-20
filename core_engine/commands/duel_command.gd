# File: res://core_engine/commands/duel_command.gd
# Class: class_name DuelCommand
# Role: ACT_09 일기토 데스매치 시작 - 결투 신청만 알리고(duel_requested), 종목 추첨·입력·승패·사출은 TurnManager의 결투 상태가 진행한다
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
