# File: res://core_engine/cards/card_status.gd
# Class: class_name CardStatus
# Role: ACT_11 밑장빼기 / ACT_12 더 월드 / ACT_14 알고리즘 밴 / ACT_15 우노 스킵 - 턴 시작에 쓰는 상태 변화 즉발 카드
class_name CardStatus
extends BaseCard

const NAMES: Dictionary = {
	&"ACT_11": "밑장빼기",
	&"ACT_12": "더 월드",
	&"ACT_14": "알고리즘 밴",
	&"ACT_15": "우노 스킵",
}
## 밑장빼기로 고를 수 있는 칸 수.
const MIN_STEPS: int = 1
const MAX_STEPS: int = 6


func _init(id: StringName = &"ACT_11") -> void:
	card_id = id
	display_name = NAMES[id]
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


## 대상 플레이어를 골라야 하는 카드인가 (밴·스킵).
func needs_target() -> bool:
	return card_id == &"ACT_14" or card_id == &"ACT_15"


func could_play(state: GameState, player_id: int) -> bool:
	if needs_target():
		return not StatusCardCommand.targets(state, player_id).is_empty()
	if card_id == &"ACT_11":
		return not state.forced_roll.has(player_id)
	return not bool(state.extra_turns.get(player_id, false))


## params: 밴·스킵 {"target_player": int} / 밑장빼기 {"steps": 1~6}
func can_play(state: GameState, player_id: int, params: Dictionary) -> bool:
	if not could_play(state, player_id):
		return false
	if needs_target():
		return StatusCardCommand.targets(state, player_id).has(int(params.get("target_player", -1)))
	if card_id == &"ACT_11":
		var steps: int = int(params.get("steps", -1))
		return steps >= MIN_STEPS and steps <= MAX_STEPS
	return true


func create_command(_state: GameState, player_id: int, params: Dictionary) -> GameCommand:
	return StatusCardCommand.new(player_id, card_id, int(params.get("target_player", -1)), int(params.get("steps", 0)))
