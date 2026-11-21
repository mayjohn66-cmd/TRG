# File: res://core_engine/tools/tool_icecream.gd
# Class: class_name ToolIceCream
# Role: 아이스크림 (TRPG 확장) - 한 입 베어 물면 막대에 칸이 드러난다. 드러난 칸 수(1~6)만큼 전진하고, 막대에 "한번 더!"가 적혀 있으면 3칸 전진 + 아이스크림이 다시 채워져 한 번 더 굴린다
class_name ToolIceCream
extends BaseJudgmentTool

## 막대에 드러나는 칸 수 1~6의 가중치 (합 85). 나머지 15는 "한번 더!".
const SPACE_WEIGHTS: Array[int] = [14, 16, 16, 16, 12, 11]
const AGAIN_WEIGHT: int = 15
const AGAIN_STEPS: int = 3


func _init() -> void:
	tool_id = &"DICE_ICECREAM"
	display_name = "아이스크림"


func roll(rng: RandomNumberGenerator) -> RollResult:
	var pick: int = rng.randi_range(1, 100)
	var acc: int = 0
	for i: int in SPACE_WEIGHTS.size():
		acc += SPACE_WEIGHTS[i]
		if pick <= acc:
			return of_spaces(i + 1)
	return of_again()


static func of_spaces(spaces: int) -> RollResult:
	return RollResult.make(&"DICE_ICECREAM", spaces, {"spaces": spaces, "again": false})


static func of_again() -> RollResult:
	var result: RollResult = RollResult.make(&"DICE_ICECREAM", AGAIN_STEPS, {"spaces": AGAIN_STEPS, "again": true})
	result.reroll = true
	return result


static func caption(details: Dictionary, steps: int) -> String:
	if bool(details.get("again", false)):
		return "막대에 한번 더! → %d칸 + 새 아이스크림" % steps
	return "막대에 %d칸 → %d칸" % [int(details.get("spaces", steps)), steps]
