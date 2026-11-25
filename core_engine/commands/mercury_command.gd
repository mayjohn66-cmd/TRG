# File: res://core_engine/commands/mercury_command.gd
# Class: class_name MercuryCommand
# Role: ACT_26 수은 가드 실행 - 내 말 하나에 수은 보호막(mercury)을 씌운다: 공격 카드 사출을 1회 막고 사라진다
class_name MercuryCommand
extends GameCommand

var pawn_id: int = -1


func _init(acting_player: int = -1, target_pawn: int = -1) -> void:
	super()
	sender_id = acting_player
	pawn_id = target_pawn
	command_name = "Mercury"


func can_execute(_ctx: RuleContext) -> bool:
	if state == null:
		return false
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	return pawn != null and CardMercury.targets(state, sender_id).has(pawn)


func _run() -> void:
	state.get_pawn(pawn_id).mercury = true
	state.mercury_applied.emit(pawn_id)
