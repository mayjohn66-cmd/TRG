# File: res://core_engine/tools/tool_halli_galli.gd
# Class: class_name ToolHalliGalli
# Role: 할리갈리 적립기 - 기본 [1~3] + 과일 5개 달성 시 스페이스바 선입력으로 적립해 둔 보너스(+2씩 누적)를 합산해 전진
class_name ToolHalliGalli
extends BaseJudgmentTool

const FRUIT_TYPES: int = 4
const FACE_UP_CARDS: int = 4
const BONUS_PER_BELL: int = 2

## 바닥에 공개된 과일 종류별 총 개수.
var fruit_totals: Array[int] = [0, 0, 0, 0]
var bell_claimed: bool = false
## 적립된 보너스 칸수 (다음 굴림에서 소모).
var banked_bonus: int = 0


func _init() -> void:
	tool_id = &"HALLI_GALLI"
	display_name = "할리갈리 적립기"
	fruit_totals.resize(FRUIT_TYPES)


## 새 카드를 공개한다. 이전 공개 카드의 종 치기 기회는 사라진다.
func on_turn_begin(rng: RandomNumberGenerator) -> void:
	reveal_cards(rng)


func reveal_cards(rng: RandomNumberGenerator) -> void:
	fruit_totals.fill(0)
	for i: int in FACE_UP_CARDS:
		var fruit: int = rng.randi_range(0, FRUIT_TYPES - 1)
		fruit_totals[fruit] += rng.randi_range(1, 3)
	bell_claimed = false


func is_bell_ready() -> bool:
	return fruit_totals.has(5) and not bell_claimed


## 스페이스바 입력. 과일 5개 달성 상태에서 선입력하면 보너스 +2를 적립한다.
func press_bell() -> bool:
	if not is_bell_ready():
		return false
	bell_claimed = true
	banked_bonus += BONUS_PER_BELL
	return true


func roll(rng: RandomNumberGenerator) -> RollResult:
	var base: int = rng.randi_range(1, 3)
	var bonus: int = banked_bonus
	banked_bonus = 0
	return RollResult.make(tool_id, base + bonus, {"base": base, "bonus": bonus})
