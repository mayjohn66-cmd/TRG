# File: res://core_engine/cards/card_appease.gd
# Class: class_name CardAppease
# Role: ACT_25 회유책 - 밴·스킵·해킹이 걸린 채 내 차례가 오면 차례 시작에 [회유책 쓰기] 창이 뜨고, 쓰면 디버프를 모두 풀고 차례를 정상으로 진행한다.
#       밴(카드 금지) 중에도 이 카드만은 낼 수 있고, 이 카드는 그 턴에 낼 수 있는 카드 1장으로 세지 않는다. 디버프가 없으면 쓸 수 없다.
class_name CardAppease
extends BaseCard


func _init() -> void:
	card_id = &"ACT_25"
	display_name = "회유책"
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


## 이 플레이어에게 지금 풀 디버프가 있는가 (밴 남은 턴 · 미뤄 둔 스킵 · 이번 해킹 턴). manager가 없으면(단위 계산) 상태 값만 본다.
static func debuffed(state: GameState, player_id: int, manager: TurnManager = null) -> bool:
	if state.is_banned(player_id) or bool(state.rest_next_turn.get(player_id, false)) or int(state.hacked_turns.get(player_id, 0)) > 0:
		return true
	return manager != null and manager.is_hack_turn(player_id)


func could_play(state: GameState, player_id: int) -> bool:
	return debuffed(state, player_id) or int(state.appease_offer.get(player_id, 0)) > 0


func can_play(state: GameState, player_id: int, _params: Dictionary) -> bool:
	return could_play(state, player_id)


func create_command(_state: GameState, player_id: int, _params: Dictionary) -> GameCommand:
	return AppeaseCommand.new(player_id)
