# File: res://core_engine/tools/tool_tarot.gd
# Class: class_name ToolTarot
# Role: 점성술사의 타로 덱 - 메이저 아르카나 5장 중 한 장이 뒤집혀 운명대로 전진한다 (광대 -2 또는 +7 / 전차 6 / 운명의 수레바퀴 4 + 한 번 더 / 매달린 남자 1 + 다음 굴림 +8 예약 / 세계 9). 걷기 전용 판정 도구
class_name ToolTarot
extends BaseJudgmentTool

const FATES: Array[StringName] = [&"fool", &"chariot", &"wheel", &"hanged", &"world"]
const FATE_NAMES: Dictionary = {
	&"fool": "0. 광대 (The Fool)", &"chariot": "VII. 전차 (The Chariot)", &"wheel": "X. 운명의 수레바퀴",
	&"hanged": "XII. 매달린 남자 (The Hanged Man)", &"world": "XXI. 세계 (The World)",
}
const FOOL_BACK: int = -2
const FOOL_LEAP: int = 7
const CHARIOT_STEPS: int = 6
const WHEEL_STEPS: int = 4
const HANGED_STEPS: int = 1
const WORLD_STEPS: int = 9
const BLESSING_STEPS: int = 8

## 매달린 남자가 예약한 다음 굴림 보너스 칸수. 다음에 굴릴 때 한 번 더해지고 사라진다.
var tarot_next_bonus: int = 0


func _init() -> void:
	tool_id = &"DICE_TAROT"
	display_name = "점성술사의 타로 덱"


func roll(rng: RandomNumberGenerator) -> RollResult:
	var fate: StringName = FATES[rng.randi_range(0, FATES.size() - 1)]
	return roll_fate(fate, rng)


## 운명을 정해 놓고 굴린다 (테스트가 직접 부른다). 광대의 양극단은 rng로 정한다.
func roll_fate(fate: StringName, rng: RandomNumberGenerator) -> RollResult:
	var steps: int = 0
	var reroll: bool = false
	var leap: bool = false
	match fate:
		&"fool":
			leap = rng.randi_range(0, 1) == 1
			steps = FOOL_LEAP if leap else FOOL_BACK
		&"chariot": steps = CHARIOT_STEPS
		&"wheel":
			steps = WHEEL_STEPS
			reroll = true
		&"hanged": steps = HANGED_STEPS
		&"world": steps = WORLD_STEPS
	var details: Dictionary = {"fate": fate, "name": FATE_NAMES[fate], "flipped": rng.randi_range(0, FATES.size() - 1), "fool_leap": leap}
	# 이전에 예약된 축복은 이번 굴림에 한 번 더해진다.
	if tarot_next_bonus > 0:
		steps += tarot_next_bonus
		details["bonus"] = tarot_next_bonus
		tarot_next_bonus = 0
	if fate == &"hanged":
		tarot_next_bonus = BLESSING_STEPS
		details["blessing_booked"] = BLESSING_STEPS
	var result: RollResult = RollResult.make(tool_id, steps, details)
	result.reroll = reroll
	return result
