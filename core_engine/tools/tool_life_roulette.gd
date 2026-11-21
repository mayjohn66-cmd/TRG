# File: res://core_engine/tools/tool_life_roulette.gd
# Class: class_name ToolLifeRoulette
# Role: 인생게임 회전 룰렛 - [1~10] 균등 추첨, 7 당첨 시 7칸 이동 + 재굴림
class_name ToolLifeRoulette
extends BaseJudgmentTool

const JACKPOT_FACE: int = 7


func _init() -> void:
	tool_id = &"LIFE_ROULETTE"
	display_name = "인생게임 회전 룰렛"


func roll(rng: RandomNumberGenerator) -> RollResult:
	var face: int = rng.randi_range(1, 10)
	var result: RollResult = RollResult.make(tool_id, face, {"face": face})
	result.reroll = face == JACKPOT_FACE
	return result
