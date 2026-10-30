# File: res://core_engine/cards/card_counter.gd
# Class: class_name CardCounter
# Role: 방어 카드 7종(CNT_01~07). 내가 공격(잡기·공격 카드·함정)을 당했을 때 방어 팝업에서 낸다. 이번 턴의 공격 기록(GameState.attack_log) 하나를 골라 되돌리거나 되갚는다
class_name CardCounter
extends BaseCard

const CAPTURE: StringName = &"capture"
const CARD: StringName = &"card"
const TRAP: StringName = &"trap"
## 카드 ID -> [이름, 막을 수 있는 공격 종류들]
const DEFS: Dictionary = {
	&"CNT_01": ["바이츠 더 더스트", [CAPTURE, CARD, TRAP]],
	&"CNT_02": ["거울의 힘", [CAPTURE]],
	&"CNT_03": ["UDO 리버스 카드", [CARD]],
	&"CNT_04": ["감나빗!", [CAPTURE, CARD]],
	&"CNT_05": ["싸이크론", [TRAP]],
	&"CNT_06": ["교단의 칙령", [TRAP]],
	&"CNT_07": ["도굴꾼", [TRAP]],
}
## 싸이크론으로 함정을 부순 뒤 전진하는 칸 수 (cards_table.csv CNT_05 param_1).
const CYCLONE_STEPS: int = 3


func _init(id: StringName = &"CNT_01") -> void:
	card_id = id
	display_name = str(DEFS[id][0])
	category = GameEnums.CardCategory.COUNTER
	playable_phases = []  # 단계로 쓰는 카드가 아니다: 피격 팝업(방어 대기)에서만 낸다 (TurnManager._play_counter)


static func is_counter(id: StringName) -> bool:
	return DEFS.has(id)


## 이 방어 카드가 이 공격 기록에 쓸 수 있는가.
static func answers(state: GameState, id: StringName, entry: Dictionary) -> bool:
	if not DEFS.has(id) or entry.is_empty() or bool(entry["countered"]):
		return false
	if not (DEFS[id][1] as Array).has(entry["kind"]):
		return false
	if id == &"CNT_02":
		var attacker: PlayerPawn = state.get_pawn(int(entry.get("attacker_pawn", -1)))
		return attacker != null and attacker.has_left_start and not attacker.is_finished
	return true


## 이 플레이어가 이 카드로 받아칠 수 있는 이번 턴의 공격 기록들.
static func open_attacks(state: GameState, player_id: int, id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in state.attack_log:
		if int(entry["victim"]) == player_id and answers(state, id, entry):
			result.append(entry)
	return result


func could_play(state: GameState, player_id: int) -> bool:
	return not open_attacks(state, player_id, card_id).is_empty()


## params: {"attack": 공격 기록 ID}
func can_play(state: GameState, player_id: int, params: Dictionary) -> bool:
	var entry: Dictionary = state.get_attack(int(params.get("attack", -1)))
	return not entry.is_empty() and int(entry["victim"]) == player_id and answers(state, card_id, entry)


func create_command(_state: GameState, player_id: int, params: Dictionary) -> GameCommand:
	if card_id == &"CNT_01":
		var rewind := RollbackCommand.new(player_id)
		rewind.ends_turn = true
		return rewind
	return CounterCommand.new(player_id, card_id, int(params["attack"]))
