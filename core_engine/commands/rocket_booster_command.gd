# File: res://core_engine/commands/rocket_booster_command.gd
# Class: class_name RocketBoosterCommand
# Role: ACT_04 실행 - 이번 턴 첫 굴림 결과에 더할 보너스(roll_bonus)를 예약한다
class_name RocketBoosterCommand
extends GameCommand

const BONUS: int = 4


func _init(acting_player: int = -1) -> void:
	super()
	sender_id = acting_player
	command_name = "RocketBooster"


func _run() -> void:
	state.roll_bonus += CardRegistry.param(&"ACT_04", BONUS)  # cards_table.csv ACT_04 param_1
