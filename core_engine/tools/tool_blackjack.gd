# File: res://core_engine/tools/tool_blackjack.gd
# Class: class_name ToolBlackjack
# Role: 블랙잭 21 딜러 - 합계가 11~20이 되도록 시작 카드를 받고, 히트(roll)로 더 뽑거나 스탠드(cash_out)로 (합계-10)칸 전진한다. 정확히 21이면 11칸 + 한 번 더, 22 이상이면 버스트(0칸, 턴 종료)
class_name ToolBlackjack
extends BaseJudgmentTool

const MIN_START_TOTAL: int = 11
const BLACKJACK: int = 21
const STEPS_OFFSET: int = 10

## 뽑은 카드 (1=A, 2~10, 11=J, 12=Q, 13=K)
var cards: Array[int] = []
var _started: bool = false


func _init() -> void:
	tool_id = &"DICE_BLACKJACK"
	display_name = "블랙잭 21 딜러"


func has_pending_state() -> bool:
	return _started


## 시작이면 카드를 받아 합계를 11 이상으로 맞추고(에이스는 11, 21을 넘기면 1), 진행 중이면 히트(카드 1장 더)한다.
func roll(rng: RandomNumberGenerator) -> RollResult:
	if not _started:
		cards = []
		_started = true
		var dealt: Array[int] = []
		for i: int in 2:
			dealt.append(_draw(rng))
		while total_of(cards) < MIN_START_TOTAL:
			dealt.append(_draw(rng))
		return _after_draw(dealt, true)
	return _after_draw([_draw(rng)], false)


## 스탠드: 지금 합계 - 10칸으로 확정.
func cash_out() -> RollResult:
	if not _started:
		return null
	return _finish(false, false)


func _draw(rng: RandomNumberGenerator) -> int:
	var card: int = rng.randi_range(1, 13)
	cards.append(card)
	return card


func _after_draw(new_cards: Array[int], opening: bool) -> RollResult:
	var total: int = total_of(cards)
	if total > BLACKJACK:
		return _finish(false, true, new_cards)
	if total == BLACKJACK:
		return _finish(true, false, new_cards)
	var pending: RollResult = RollResult.make(tool_id, total - STEPS_OFFSET, {
		"cards": cards.duplicate(), "new_cards": new_cards, "total": total, "preview_steps": total - STEPS_OFFSET,
		"opening": opening, "blackjack": false, "bust": false, "confirmed": false,
	})
	pending.can_continue = true
	return pending


func _finish(blackjack: bool, bust: bool, new_cards: Array[int] = []) -> RollResult:
	var total: int = total_of(cards)
	var steps: int = 0 if bust else total - STEPS_OFFSET
	var result: RollResult = RollResult.make(tool_id, steps, {
		"cards": cards.duplicate(), "new_cards": new_cards, "total": total, "preview_steps": steps,
		"opening": false, "blackjack": blackjack, "bust": bust, "confirmed": true,
	})
	result.reroll = blackjack
	result.ends_turn = bust
	_started = false
	cards = []
	return result


## 카드 목록의 합계: 에이스는 11로 세고 21을 넘으면 1로 바꾼다. 그림 카드(J/Q/K)는 10.
static func total_of(hand: Array) -> int:
	var total: int = 0
	var aces: int = 0
	for card: Variant in hand:
		var rank: int = int(card)
		if rank == 1:
			aces += 1
			total += 11
		else:
			total += mini(rank, 10)
	while total > BLACKJACK and aces > 0:
		total -= 10
		aces -= 1
	return total


static func card_name(rank: int) -> String:
	return {1: "A", 11: "J", 12: "Q", 13: "K"}.get(rank, str(rank))
