# File: res://core_engine/tools/tool_slot_777.gd
# Class: class_name ToolSlot777
# Role: 777 슬롯머신 - 릴 3개 결과 비례 전진 (꽝 1, 2개 일치 4, 3개 일치 8, 777 잭팟 20)
class_name ToolSlot777
extends BaseJudgmentTool

const SYMBOL_COUNT: int = 6
## 마지막 심볼이 '7'.
const SEVEN: int = SYMBOL_COUNT - 1
const STEPS_MISS: int = 1
const STEPS_PAIR: int = 4
const STEPS_TRIPLE: int = 8
const STEPS_JACKPOT: int = 20


func _init() -> void:
	tool_id = &"SLOT_777"
	display_name = "777 슬롯머신"


func roll(rng: RandomNumberGenerator) -> RollResult:
	var reels: Array[int] = []
	for i: int in 3:
		reels.append(rng.randi_range(0, SYMBOL_COUNT - 1))
	return RollResult.make(tool_id, steps_for(reels), {"reels": reels})


static func steps_for(reels: Array[int]) -> int:
	if reels[0] == reels[1] and reels[1] == reels[2]:
		return STEPS_JACKPOT if reels[0] == SEVEN else STEPS_TRIPLE
	if reels[0] == reels[1] or reels[1] == reels[2] or reels[0] == reels[2]:
		return STEPS_PAIR
	return STEPS_MISS
