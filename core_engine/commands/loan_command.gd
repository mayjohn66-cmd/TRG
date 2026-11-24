# File: res://core_engine/commands/loan_command.gd
# Class: class_name LoanCommand
# Role: ACT_24 피라 대출 실행 - 이번 굴림 보너스(roll_bonus)에 +9, 다음 내 턴 3번의 첫 굴림 -3칸을 예약한다 (이번 턴에는 갚지 않는다)
class_name LoanCommand
extends GameCommand


func _init(acting_player: int = -1) -> void:
	super()
	sender_id = acting_player
	command_name = "Loan"


func _run() -> void:
	state.roll_bonus += CardRegistry.param(&"ACT_24", CardLoan.BONUS)  # cards_table.csv ACT_24 param_1
	state.loan_debt[sender_id] = CardLoan.DEBT_TURNS
	state.loan_fresh[sender_id] = true  # 이번 턴의 굴림에서는 갚지 않는다
