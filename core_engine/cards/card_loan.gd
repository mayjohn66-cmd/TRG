# File: res://core_engine/cards/card_loan.gd
# Class: class_name CardLoan
# Role: ACT_24 피라 대출 - 굴리기 전에 쓰면 이번 굴림 +9칸. 대신 다음 내 턴 3번 동안 첫 굴림이 -3칸 (최소 1칸)
class_name CardLoan
extends BaseCard

const BONUS: int = 9
const DEBT_TURNS: int = 3
const DEBT_STEPS: int = 3


func _init() -> void:
	card_id = &"ACT_24"
	display_name = "피라 대출"
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


## 이미 대출을 갚는 중이면 또 빌릴 수 없다.
func could_play(state: GameState, player_id: int) -> bool:
	return int(state.loan_debt.get(player_id, 0)) <= 0


func can_play(state: GameState, player_id: int, _params: Dictionary) -> bool:
	return could_play(state, player_id)


func create_command(_state: GameState, player_id: int, _params: Dictionary) -> GameCommand:
	return LoanCommand.new(player_id)
