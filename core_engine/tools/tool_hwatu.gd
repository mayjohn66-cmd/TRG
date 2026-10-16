# File: res://core_engine/tools/tool_hwatu.gd
# Class: class_name ToolHwatu
# Role: 화투 패 - 패 2장 족보로 칸수를 정한다 (망통 0칸 턴 종료 / 끗 2~4칸 / 땡·광땡 6~8칸). 한 번에 끝나는 단순한 판정이며 고/스톱은 없다
class_name ToolHwatu
extends BaseJudgmentTool

const CARD_COUNT: int = 48
## 1·3·8·11·12월의 첫 번째 패가 광이다.
const GWANG_MONTHS: Array[int] = [1, 3, 8, 11, 12]

## 테스트·시나리오용: 비어 있지 않으면 난수 대신 이 패들을 순서대로 뽑는다.
var forced_draws: Array[int] = []
var cards: Array[int] = []


func _init() -> void:
	tool_id = &"DICE_HWATU"
	display_name = "화투 패"


## 패 2장을 뒤집어 족보대로 칸수를 정한다. 망통이면 0칸에 턴 종료.
func roll(rng: RandomNumberGenerator) -> RollResult:
	cards = [_draw(rng, []), 0]
	cards[1] = _draw(rng, [cards[0]])
	var hand: Dictionary = evaluate(cards)
	var steps: int = int(hand["steps"])
	var details: Dictionary = {"cards": cards.duplicate(), "new_cards": cards.duplicate(), "hand": hand["id"], "label": hand["label"]}
	var result: RollResult = RollResult.make(tool_id, steps, details)
	if steps <= 0:
		result.ends_turn = true
	return result


func _draw(rng: RandomNumberGenerator, taken: Array) -> int:
	if not forced_draws.is_empty():
		return forced_draws.pop_front()
	var card: int = rng.randi_range(0, CARD_COUNT - 1)
	while taken.has(card):
		card = rng.randi_range(0, CARD_COUNT - 1)
	return card


## 패 번호(0~47) -> 월(1~12). 한 달에 4장이다.
static func month_of(card: int) -> int:
	return card / 4 + 1


static func is_gwang(card: int) -> bool:
	return card % 4 == 0 and GWANG_MONTHS.has(month_of(card))


## 패의 종류: 광 / 열끗(yeol) / 띠(tti) / 피(pi). 한 달의 0번 패는 광(광이 있는 달) 또는 열끗, 1번 열끗, 2번 띠, 3번 피.
static func card_type(card: int) -> StringName:
	match card % 4:
		0: return &"gwang" if is_gwang(card) else &"yeol"
		1: return &"yeol"
		2: return &"tti"
	return &"pi"


## 패 2장 족보: {"id": StringName, "steps": 칸수, "label": 이름}.
static func evaluate(pair: Array) -> Dictionary:
	var a: int = int(pair[0])
	var b: int = int(pair[1])
	var month_a: int = month_of(a)
	var month_b: int = month_of(b)
	if is_gwang(a) and is_gwang(b):
		return {"id": &"gwang_ttaeng", "steps": 8, "label": "광땡"}
	if month_a == month_b:
		if month_a == 10:
			return {"id": &"jang_ttaeng", "steps": 8, "label": "장땡"}
		return {"id": &"ttaeng", "steps": 7 if month_a >= 5 else 6, "label": "%d땡" % month_a}
	var points: int = (month_a + month_b) % 10
	if points == 0:
		return {"id": &"mangtong", "steps": 0, "label": "망통"}
	return {"id": &"kkeut", "steps": 2 if points <= 3 else (3 if points <= 6 else 4), "label": "%d끗" % points}


## 패 이름: "3월 광", "7월 띠" 같은 표기.
static func card_name(card: int) -> String:
	var type_names: Dictionary = {&"gwang": "광", &"yeol": "열끗", &"tti": "띠", &"pi": "피"}
	return "%d월 %s" % [month_of(card), type_names[card_type(card)]]
