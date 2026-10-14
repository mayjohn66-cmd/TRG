# File: res://core_engine/rules/laws/law_goal_threshold.gd
# Class: class_name LawGoalThreshold
# Role: LAW_08 결승선 문턱 높이기 - 결승선 통과 시 눈금이 남으면 남은 만큼 뒤로 튕겨 나옴
class_name LawGoalThreshold
extends BaseLaw


func _init() -> void:
	law_id = &"LAW_08"
	display_name = "결승선 문턱 높이기"
	description = "결승선 통과 시 눈금이 남으면 남은 만큼 뒤로 튕겨 나옴."


func apply(stage: GameEnums.HookStage, ctx: RuleContext) -> void:
	if stage == GameEnums.HookStage.PATH_PREPARE:
		ctx.goal_bounce = true
