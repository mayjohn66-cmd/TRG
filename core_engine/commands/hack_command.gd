# File: res://core_engine/commands/hack_command.gd
# Class: class_name HackCommand
# Role: ACT_23 전문적 해킹 - 고른 상대의 다음 한 턴을 자동 진행으로 바꾼다 (TurnManager가 그 턴의 굴림·말 고르기를 직접 실행하고 카드는 쓰지 못한다). 말은 무작위로 고른다
class_name HackCommand
extends GameCommand

var target_player: int = -1


func _init(acting_player: int = -1, target: int = -1) -> void:
	super()
	sender_id = acting_player
	target_player = target
	command_name = "Hack"


func can_execute(_ctx: RuleContext) -> bool:
	return state != null and StatusCardCommand.targets(state, sender_id).has(target_player)


func _run() -> void:
	state.record_effect(target_player, "hack", int(state.hacked_turns.get(target_player, 0)))
	state.hacked_turns[target_player] = int(state.hacked_turns.get(target_player, 0)) + 1
	state.hack_applied.emit(sender_id, target_player)
