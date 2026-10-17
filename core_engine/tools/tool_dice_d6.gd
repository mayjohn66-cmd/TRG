# File: res://core_engine/tools/tool_dice_d6.gd
# Class: class_name ToolDiceD6
# Role: 기본 주사위(D6) - [1~6] 균등 추첨
class_name ToolDiceD6
extends BaseJudgmentTool


func _init() -> void:
	tool_id = &"D6"
	display_name = "기본 주사위"


func roll(rng: RandomNumberGenerator) -> RollResult:
	var face: int = rng.randi_range(1, 6)
	return RollResult.make(tool_id, face, {"face": face})
