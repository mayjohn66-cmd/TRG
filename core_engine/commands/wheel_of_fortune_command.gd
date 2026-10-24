# File: res://core_engine/commands/wheel_of_fortune_command.gd
# Class: class_name WheelOfFortuneCommand
# Role: ACT_08 X. 운명의 수레바퀴 - 내 가장 뒤처진 보드 위 말과 가장 앞선 적 말의 위치를 강제로 맞바꾼다. 내 말이 보드 위에 하나도 없으면 가장 앞선 적 말을 출발선으로 장외 사출시킨 뒤, 출발선에서 기다리던 내 말 하나를 그 자리에 놓는다
#       (기다리는 말도 없으면 사출만). 스냅샷으로 undo 가능
class_name WheelOfFortuneCommand
extends GameCommand

## 실행 뒤 UI가 읽는다: "swap"(맞바꿈) / "eject_place"(사출 + 내 대기 말을 그 자리에) / "eject"(사출만), 관련 말 ID.
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
		# 보드 위에 내 말이 없다: 선두 적 말을 장외 사출하고, 출발선에서 기다리던 내 말을 그 자리에 둔다
		var tile: int = enemy.current_tile_idx
		var history: Array[int] = enemy.step_history.duplicate()
		var waiting: PlayerPawn = TarotEffects.waiting_own(state, sender_id)
		state.send_to_start(enemy, sender_id)
		if waiting == null:
			outcome = &"eject"
			state.wheel_turned.emit(sender_id, -1, enemy_id, &"eject")
			return
		outcome = &"eject_place"
		mine_id = waiting.entity_id
		waiting.current_tile_idx = tile
		waiting.step_history.assign(history)  # 진행 방향·반환점 통과 기록도 그 자리의 것을 이어받는다
		waiting.has_left_start = true
		waiting.revenge_boost = false  # 출발선을 거치지 않고 바로 나가므로 복수 부스터는 쓰지 않는다
		state.sync_stack_position(waiting)
		state.wheel_turned.emit(sender_id, mine_id, enemy_id, &"eject_place")
		return
	outcome = &"swap"
	mine_id = mine.entity_id
	state.swap_stacks(mine, enemy)
	state.wheel_turned.emit(sender_id, mine_id, enemy_id, &"swap")
