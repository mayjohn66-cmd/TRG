# File: res://core_engine/board/witch_potions.gd
# Class: class_name WitchPotions
# Role: 벨라티엔 왕국의 마녀의 가마솥 발판. 딱 멈춘 말의 주인이 물약을 끓이면 그 종류에 따라 랜덤한 효과가 붙는다 (GameState.rng로 뽑아 모든 참가자가 같은 결과).
#       모나티엄 자판기와 달리 나쁜 물약도 나온다 (좋은 것 3종 60% / 나쁜 것 2종 40%). 효과는 모두 기존 부품 재사용:
#       다음 굴림 보너스(corner_buff) · 즉시 전진/후진(이어지는 이동) · 방어(ward) · 다음 굴림 감소(roll_penalty).
class_name WitchPotions
extends RefCounted

## [{id, name, text, good}] — 같은 확률로 뽑는다.
const POTIONS: Array[Dictionary] = [
	{"id": &"power", "name": "힘의 물약", "text": "다음 굴림 +3칸", "good": true},
	{"id": &"swift", "name": "신속의 물약", "text": "지금 바로 +2칸 전진", "good": true},
	{"id": &"guard", "name": "보호의 물약", "text": "잡기·함정 1회 방어", "good": true},
	{"id": &"frog", "name": "개구리 물약", "text": "다음 굴림 -2칸", "good": false},
	{"id": &"boom", "name": "폭발 물약", "text": "펑! 뒤로 2칸", "good": false},
]
const POWER_STEPS: int = 3
const SWIFT_STEPS: int = 2
const FROG_STEPS: int = 2
const BOOM_STEPS: int = 2


static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for potion: Dictionary in POTIONS:
		result.append(potion["id"])
	return result


static func def_of(id: StringName) -> Dictionary:
	for potion: Dictionary in POTIONS:
		if potion["id"] == id:
			return potion
	return {}


static func name_of(id: StringName) -> String:
	return str(def_of(id).get("name", ""))


static func text_of(id: StringName) -> String:
	return str(def_of(id).get("text", ""))


static func is_good(id: StringName) -> bool:
	return bool(def_of(id).get("good", false))


static func pick(state: GameState) -> StringName:
	return POTIONS[state.rng.randi_range(0, POTIONS.size() - 1)]["id"]


## 물약을 마셔 즉시 적용되는 효과 (전진·후진은 follow_up_steps로 호출한 쪽이 이어서 처리한다).
static func apply(state: GameState, mover: PlayerPawn, potion: StringName, report: MoveReport) -> void:
	match potion:
		&"power":
			state.corner_buff[mover.owner_id] = maxi(int(state.corner_buff.get(mover.owner_id, 0)), POWER_STEPS)  # 겹쳐도 큰 쪽만 (코너 버프와 같은 규칙)
		&"guard":
			mover.ward = true
		&"frog":
			state.roll_penalty[mover.owner_id] = maxi(int(state.roll_penalty.get(mover.owner_id, 0)), FROG_STEPS)  # 다음 눈금 -2 (최소 1칸)
	report.cauldron_potion = potion


## 이어지는 이동 칸 수: + 앞으로, - 뒤로, 0 없음.
static func follow_up_steps(potion: StringName) -> int:
	match potion:
		&"swift":
			return SWIFT_STEPS
		&"boom":
			return -BOOM_STEPS
	return 0
