# File: res://core_engine/tools/tool_holdem.gd
# Class: class_name ToolHoldem
# Role: 텍사스 홀덤 딜러 - 52장 덱에서 5장을 받고, 바꿀 카드를 골라 한 번 교환한 뒤 족보 비례 전진
#       (노페어 1, 원페어 3, 투페어 5, 트리플 7, 스트레이트 10, 플러시 이상 15).
#       1.3.1: 첫 굴림은 5장을 받는 이어 굴리기 상태(can_continue)이고, 두 번째 굴림(keep 인자 = 남길 카드 5개 bool)이 나머지를 새 카드로
#       바꿔 확정한다. 멈추기(cash_out)·시간 초과는 받은 5장 그대로 확정. 교환 카드는 받은 카드·버린 카드를 뺀 덱에서 GameState.rng로 뽑는다.
class_name ToolHoldem
extends BaseJudgmentTool

const STEPS_BY_HAND: Dictionary = {
	&"high_card": 1,
	&"one_pair": 3,
	&"two_pair": 5,
	&"three_kind": 7,
	&"straight": 10,
	&"flush": 15,
	&"full_house": 15,
	&"four_kind": 15,
	&"straight_flush": 15,
}


const HAND_SIZE: int = 5

## 지금 손에 든 5장 (받은 뒤 교환 전까지).
var cards: Array[int] = []
var _started: bool = false
var _keep: Array[bool] = []


func _init() -> void:
	tool_id = &"HOLDEM"
	display_name = "텍사스 홀덤 딜러"


func has_pending_state() -> bool:
	return _started


## 교환할 때 남길 카드 (5개 bool, true = 남긴다). 길이가 맞지 않으면 모두 바꾼다.
func set_keep(mask: Array) -> void:
	_keep = []
	for index: int in HAND_SIZE:
		_keep.append(index < mask.size() and bool(mask[index]))


## 처음이면 5장을 받는다(교환 대기). 이미 받았으면 남기지 않은 카드를 새 카드로 바꿔 확정한다.
func roll(rng: RandomNumberGenerator) -> RollResult:
	if not _started:
		cards = sample_distinct(rng, 52, HAND_SIZE)
		_started = true
		_keep = []
		var hand: StringName = evaluate(cards)
		var pending: RollResult = RollResult.make(tool_id, steps_for(hand), {"cards": cards.duplicate(), "hand": hand, "preview_steps": steps_for(hand), "confirmed": false})
		pending.can_continue = true
		return pending
	var before: Array[int] = cards.duplicate()
	var used: Array[int] = cards.duplicate()
	var exchanged: Array[int] = []
	for index: int in HAND_SIZE:
		if index < _keep.size() and _keep[index]:
			continue
		var card: int = rng.randi_range(0, 51)
		while used.has(card):
			card = rng.randi_range(0, 51)
		used.append(card)
		cards[index] = card
		exchanged.append(index)
	return _commit(before, exchanged)


## 교환하지 않고 받은 그대로 확정한다.
func cash_out() -> RollResult:
	if not _started:
		return null
	return _commit(cards.duplicate(), [] as Array[int])


func _commit(before: Array[int], exchanged: Array[int]) -> RollResult:
	var hand: StringName = evaluate(cards)
	var result: RollResult = RollResult.make(tool_id, steps_for(hand), {"cards": cards.duplicate(), "hand": hand, "before": before, "exchanged": exchanged, "confirmed": true})
	_started = false
	cards = []
	_keep = []
	return result


static func steps_for(hand: StringName) -> int:
	return STEPS_BY_HAND[hand]


## 카드 = 0..51. 랭크 = card % 13 (0=2 ... 12=A), 문양 = card / 13.
static func evaluate(cards: Array[int]) -> StringName:
	var rank_counts: Dictionary = {}
	var suits: Dictionary = {}
	for card: int in cards:
		var rank: int = card % 13
		rank_counts[rank] = int(rank_counts.get(rank, 0)) + 1
		suits[card / 13] = true
	var is_flush: bool = suits.size() == 1 and cards.size() == 5
	var ranks: Array = rank_counts.keys()
	ranks.sort()
	var is_straight: bool = false
	if ranks.size() == 5:
		is_straight = (int(ranks[4]) - int(ranks[0]) == 4) or ranks == [0, 1, 2, 3, 12]
	var pattern: Array = rank_counts.values()
	pattern.sort()
	pattern.reverse()
	if is_straight and is_flush:
		return &"straight_flush"
	if pattern[0] == 4:
		return &"four_kind"
	if pattern == [3, 2]:
		return &"full_house"
	if is_flush:
		return &"flush"
	if is_straight:
		return &"straight"
	if pattern[0] == 3:
		return &"three_kind"
	if pattern == [2, 2, 1]:
		return &"two_pair"
	if pattern[0] == 2:
		return &"one_pair"
	return &"high_card"
