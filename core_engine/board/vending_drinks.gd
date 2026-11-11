# File: res://core_engine/board/vending_drinks.gd
# Class: class_name VendingDrinks
# Role: 모나티엄 도시의 자판기 발판. 딱 멈춘 말의 주인이 음료수를 뽑으면 그 종류에 따라 랜덤한 버프가 붙는다 (GameState.rng로 뽑아 모든 참가자가 같은 결과).
#       효과는 모두 기존 부품 재사용: 다음 굴림 보너스(corner_buff) · 즉시 전진 · 방어(ward) · 카드 1장.
class_name VendingDrinks
extends RefCounted

## [{id, name, text}] — 같은 확률로 뽑는다.
const DRINKS: Array[Dictionary] = [
	{"id": &"energy", "name": "에너지 드링크", "text": "다음 굴림 +3칸"},
	{"id": &"coffee", "name": "아메리카노", "text": "다음 굴림 +2칸"},
	{"id": &"soda", "name": "탄산음료", "text": "지금 바로 +2칸 전진"},
	{"id": &"ion", "name": "이온음료", "text": "잡기·함정 1회 방어"},
	{"id": &"milk", "name": "우유", "text": "생떼 카드 1장"},
]
const ENERGY_STEPS: int = 3
const COFFEE_STEPS: int = 2
const SODA_STEPS: int = 2


static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for drink: Dictionary in DRINKS:
		result.append(drink["id"])
	return result


static func def_of(id: StringName) -> Dictionary:
	for drink: Dictionary in DRINKS:
		if drink["id"] == id:
			return drink
	return {}


static func name_of(id: StringName) -> String:
	return str(def_of(id).get("name", ""))


static func text_of(id: StringName) -> String:
	return str(def_of(id).get("text", ""))


static func pick(state: GameState) -> StringName:
	return DRINKS[state.rng.randi_range(0, DRINKS.size() - 1)]["id"]


## 다음 굴림 보너스를 쌓는다 (겹쳐도 큰 쪽만: 코너 버프와 같은 규칙).
static func grant_roll_bonus(state: GameState, player_id: int, steps: int) -> void:
	state.corner_buff[player_id] = maxi(int(state.corner_buff.get(player_id, 0)), steps)


## 음료를 마셔 즉시 적용되는 효과 (전진 follow-up은 호출한 쪽이 이어서 처리한다). 카드는 report.drawn_card에 싣는다.
static func apply(state: GameState, mover: PlayerPawn, drink: StringName, report: MoveReport) -> void:
	match drink:
		&"energy":
			grant_roll_bonus(state, mover.owner_id, ENERGY_STEPS)
		&"coffee":
			grant_roll_bonus(state, mover.owner_id, COFFEE_STEPS)
		&"ion":
			mover.ward = true
		&"milk":
			var card_id: StringName = state.draw_card(mover.owner_id)
			if card_id != &"" and report.drawn_card == &"":
				report.drawn_card = card_id
	report.vending_drink = drink
