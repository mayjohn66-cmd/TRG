# File: res://core_engine/commands/wheel_of_fortune_command.gd
# Class: class_name WheelOfFortuneCommand
# Role: ACT_08 X. 운명의 수레바퀴 - 내 가장 뒤처진 보드 위 말과 가장 앞선 적 말의 위치를 강제로 맞바꾼다. 내 말이 보드 위에 없으면 가장 앞선 적 말을 4칸 후퇴시킨다. 스냅샷으로 undo 가능
class_name WheelOfFortuneCommand
extends GameCommand

## 실행 뒤 UI가 읽는다: "swap"(맞바꿈) 또는 "retreat"(후퇴), 관련 말 ID.
var outcome: StringName = &""
var mine_id: int = -1
var enemy_id: int = -1


func _init(acting_player: int = -1) -> void:
	super()
	sender_id = acting_player
	command_name = "WheelOfFortune"


func can_execute(_ctx: RuleContext) -> bool:
	return state != null and TarotEffects.leading_enemy(state, sender_id) != null


func _run() -> void:
	var enemy: PlayerPawn = TarotEffects.leading_enemy(state, sender_id)
	var mine: PlayerPawn = TarotEffects.trailing_own(state, sender_id)
	enemy_id = enemy.entity_id
	if mine == null:
		outcome = &"retreat"
		MoveExecutor.retreat(state, enemy, TarotEffects.WHEEL_RETREAT)
		state.wheel_turned.emit(sender_id, -1, enemy_id, &"retreat")
		return
	outcome = &"swap"
	mine_id = mine.entity_id
	state.swap_stacks(mine, enemy)
	state.wheel_turned.emit(sender_id, mine_id, enemy_id, &"swap")
