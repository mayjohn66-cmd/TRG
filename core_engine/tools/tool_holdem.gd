# File: res://core_engine/tools/tool_holdem.gd
# Class: class_name ToolHoldem
# Role: 텍사스 홀덤 딜러 - 52장 덱에서 5장 드로우 후 족보 비례 전진 (노페어 1, 원페어 3, 투페어 5, 트리플 7, 스트레이트 10, 플러시 이상 15)
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


func _init() -> void:
	tool_id = &"HOLDEM"
	display_name = "텍사스 홀덤 딜러"


func roll(rng: RandomNumberGenerator) -> RollResult:
	var cards: Array[int] = sample_distinct(rng, 52, 5)
	var hand: StringName = evaluate(cards)
	return RollResult.make(tool_id, steps_for(hand), {"cards": cards, "hand": hand})


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
